#!/bin/sh
# 流量统计脚本
# 用途：统计局域网设备开机后的总流量

# 定义变量
JSON_FILE="/tmp/traffic_stats.json"

# 获取命令路径
PS=$(which ps 2>/dev/null)
GREP=$(which grep 2>/dev/null)
AWK=$(which awk 2>/dev/null)
KILL=$(which kill 2>/dev/null)
SLEEP=$(which sleep 2>/dev/null)
IPTABLES=$(which iptables 2>/dev/null)
HEAD=$(which head 2>/dev/null)
TAIL=$(which tail 2>/dev/null)
DATE=$(which date 2>/dev/null)
BASENAME=$(which basename 2>/dev/null)
CUT=$(which cut 2>/dev/null)
ARP=$(which arp 2>/dev/null)

# 缓存数据以减少命令调用
ARP_CACHE=""
STATS_CACHE=""

# 检查必需命令
check_required_commands() {
    has_error=0
    
    # 检查所有必要的命令
    for cmd in iptables ps grep awk cut kill sleep head tail basename date arp; do
        cmd_var=$(eval echo \$$(echo $cmd | tr 'a-z' 'A-Z'))
        if [ -z "$cmd_var" ]; then
            echo "错误: 未找到必要的命令: $cmd"
            has_error=1
        else
            echo "信息: 找到命令 $cmd: $cmd_var"
        fi
    done
    
    [ $has_error -eq 1 ] && exit 1
    echo "信息: 所有必需命令检查通过"
    return 0
}

# 检查目录
if [ ! -d "/tmp" ]; then
  echo "Error: /tmp directory not found"
  exit 1
fi

# 信号处理函数
cleanup() {
  exit 0
}
trap 'cleanup' INT TERM

# 检查是否已有相同脚本实例在运行
check_and_clean_process() {
    local script_name=$($BASENAME "$0")  # 获取当前脚本名称
    local current_pid=$$  # 获取当前脚本的进程ID

    # 查找当前脚本的运行实例
    local running_pids=$($PS w | $GREP "$script_name" | $GREP -v grep | $GREP -v "$current_pid" | $AWK '{print $1}')

    if [ ! -z "$running_pids" ]; then
        echo "发现正在运行的同脚本实例，正在清理..."
        for pid in $running_pids; do
            if $KILL -0 "$pid" 2>/dev/null; then
                echo "终止进程: $pid"
                $KILL "$pid" 2>/dev/null
                $SLEEP 1
            fi
        done
        echo "同脚本进程清理完成"
    else
        echo "没有发现其他运行的脚本实例。"
    fi
}

# 使用 awk 转换字节数为可读格式
format_bytes() {
    local bytes=$1
    echo "$($AWK -v bytes="$bytes" 'BEGIN {
        if (bytes >= 1073741824) 
            printf "%dGB", bytes/1073741824
        else if (bytes >= 1048576) 
            printf "%dMB", bytes/1048576
        else 
            printf "%dKB", bytes/1024
    }')"
}

# 获取设备类型
get_device_type() {
    local mac="$1"
    # 转换MAC地址为大写
    mac=$(echo "$mac" | tr 'a-z' 'A-Z')
    # 获取前3位(4个字符)作为制造商特征
    local prefix=$(echo "$mac" | cut -d':' -f1-2)
    
    case "$prefix" in
        # 手机/平板
        '94:65'|'34:C9'|'A4:74'|'48:01'|'84:A0'|\
        '28:6C'|'7C:49'|'64:CC'|'28:E3'|'0C:1D'|\
        'A4:3D'|'8C:0F'|'EC:51'|'70:47'|'90:63'|\
        '9C:A5'|'10:F6'|'14:23'|'18:E3'|'54:F2'|\
        '68:AB'|'A4:CF'|'7C:49'|'EE:71'|'BE:54'|\
        'E8:68'|'CA:CE'|'EC:FA'|'02:E6'|'10:D5'|\
        '80:7D'|'40:31')
            echo "移动设备"
            ;;
            
        # 网络与智能设备
        '18:FE'|'24:0A'|'60:01'|'68:C6'|'80:7D'|\
        'DC:4F'|'D4:36'|'B8:27'|'EC:FA'|'68:C6'|\
        '00:0F'|'00:40'|'58:69'|'60:31'|'9C:65'|\
        'EC:26'|'B0:BE'|'14:CF'|'54:C8'|'54:75')
            echo "智联设备"
            ;;
            
        # 计算机设备
        '00:05'|'00:1C'|'00:21'|'6C:4B'|'00:24'|\
        '1C:39'|'E0:DB'|'98:22'|'28:16'|'DC:21'|\
        '00:12'|'00:16'|'00:19'|'00:1B'|'00:1D'|\
        '00:25'|'08:00'|'3C:97'|'44:37'|'8C:16'|\
        'E0:DB')
            echo "电脑"
            ;;
            
        *)
            # 如果匹配不到，直接显示前两位MAC
            echo "设备($prefix)"
            ;;
    esac
}

# 设备判断:
get_hostname() {
   local ip="$1"
   local line=$($GREP "$ip" /tmp/dnsmasq.leases 2>/dev/null)
   local hostname=$(echo "$line" | $AWK '{print $4}' 2>/dev/null)
   local mac=$(echo "$line" | $AWK '{print $2}' 2>/dev/null)
   
   # 如果主机名为空或无效,使用设备类型
   if [ -z "$hostname" ] || [ "$hostname" = "Unknown" ] || [ "$hostname" = "*" ] || \
      [ "$hostname" = "wlan0" ] || echo "$hostname" | $GREP -q "^[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]" 2>/dev/null; then
       
       if [ ! -z "$mac" ]; then
           # 使用新的设备类型判断函数
           get_device_type "$mac"
       else
           echo "未知设备"
       fi
   else
       # 如果主机名有效，直接返回主机名
       echo "$hostname" | $CUT -d' ' -f1
   fi
}

# 创建JSON数组开始
create_json_start() {
  echo -n "{\"time\":\"$($DATE '+%Y-%m-%d %H:%M:%S')\",\"devices\":[" > $JSON_FILE
}

# 添加设备到JSON
add_device_json() {
  local ip="$1"
  local up="$2"
  local down="$3"
  local first="$4"
  
  # 修改MAC地址获取方式，处理 "at MAC地址 [ether]" 格式
  local mac=$(echo "$ARP_CACHE" | $AWK -v ip="$ip" '$0 ~ ip {gsub(/[()]/,"",$2); if($2==ip) {print $4}}')
  # 获取主机名
  local hostname=$(get_hostname "$ip")
  
  if [ "$first" != "1" ]; then
      echo -n "," >> $JSON_FILE
  fi
  
  echo -n "{\"ip\":\"$ip\",\"mac\":\"$mac\",\"hostname\":\"$hostname\",\"up_bytes\":$up,\"down_bytes\":$down,\"up_formatted\":\"$(format_bytes $up)\",\"down_formatted\":\"$(format_bytes $down)\"}" >> $JSON_FILE
}

# 创建JSON数组结束和添加总流量
create_json_end() {
  local total_up="$1"
  local total_down="$2"
  echo -n "],\"total\":{\"up_bytes\":$total_up,\"down_bytes\":$total_down,\"up_formatted\":\"$(format_bytes $total_up)\",\"down_formatted\":\"$(format_bytes $total_down)\"}}" >> $JSON_FILE
}

# 创建流量统计函数
traffic_stats() {
  # 检查STATS链是否存在，不存在则创建
  $IPTABLES -L STATS >/dev/null 2>&1 || {
      $IPTABLES -N STATS
      $IPTABLES -I FORWARD -j STATS
  }
  
  # 获取缓存数据
  ARP_CACHE=$($ARP -n)
  STATS_CACHE=$($IPTABLES -L STATS -nvx)
  
  # 开始创建JSON
  create_json_start
  
  # 统计
  TOTAL_UP=0
  TOTAL_DOWN=0
  FIRST=1

  # 修改IP地址提取方式，处理 "? (192.168.168.xxx)" 格式
  for ip in $(echo "$ARP_CACHE" | $AWK '/\[ether\]/ {gsub(/[()]/,"",$2); print $2}'); do
      # 检查IP是否已有规则，没有则添加
      if ! echo "$STATS_CACHE" | $GREP -q "$ip"; then
          $IPTABLES -A STATS -s $ip
          $IPTABLES -A STATS -d $ip
          # 更新缓存
          STATS_CACHE=$($IPTABLES -L STATS -nvx)
      fi
      
      # 从缓存中获取流量数据
      UP=$(echo "$STATS_CACHE" | $GREP "$ip" | $HEAD -n 1 | $AWK '{print $2}')
      DOWN=$(echo "$STATS_CACHE" | $GREP "$ip" | $TAIL -n 1 | $AWK '{print $2}')
      
      UP=${UP:-0}
      DOWN=${DOWN:-0}
      
      # 使用 awk 进行总流量累加
      TOTAL_UP=$($AWK -v up="$UP" -v total="$TOTAL_UP" 'BEGIN {print up + total}')
      TOTAL_DOWN=$($AWK -v down="$DOWN" -v total="$TOTAL_DOWN" 'BEGIN {print down + total}')
      
      # 添加到JSON
      add_device_json "$ip" "$UP" "$DOWN" "$FIRST"
      FIRST=0
  done
  
  # 完成JSON
  create_json_end "$TOTAL_UP" "$TOTAL_DOWN"
}

# 运行统计
check_required_commands  # 添加命令检查
check_and_clean_process  # 确保脚本只运行一个实例
traffic_stats
