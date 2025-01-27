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
IPTABLES_PATH=$(which iptables 2>/dev/null)
HEAD=$(which head 2>/dev/null)
TAIL=$(which tail 2>/dev/null)
DATE=$(which date 2>/dev/null)
BASENAME=$(which basename 2>/dev/null)
CUT=$(which cut 2>/dev/null)

# 缓存数据以减少命令调用
ARP_CACHE=""
STATS_CACHE=""

# 检查必需命令
check_required_commands() {
    if [ -z "$IPTABLES_PATH" ]; then
        echo "错误: 未找到 iptables 命令"
        exit 1
    fi
    if [ -z "$GREP" ] || [ -z "$AWK" ]; then
        echo "错误: 基本文本处理命令缺失"
        exit 1
    fi
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

# 转换字节数为可读格式
format_bytes() {
  local bytes=$1
  if [ $bytes -gt 1073741824 ]; then  # 1GB
      echo "$(($bytes/1073741824))GB"
  elif [ $bytes -gt 1048576 ]; then    # 1MB
      echo "$(($bytes/1048576))MB"
  else
      echo "$(($bytes/1024))KB"
  fi
}

# 获取主机名
get_hostname() {
   local ip="$1"
   local line=$($GREP "$ip" /tmp/dnsmasq.leases)
   local hostname=$(echo "$line" | $AWK '{print $4}')
   local mac=$(echo "$line" | $AWK '{print $2}')
   
   # 如果主机名为空或 Unknown
   if [ -z "$hostname" ] || [ "$hostname" = "Unknown" ]; then
       case "${mac:0:8}" in
           # Apple 设备
           "d8:96:95"|"ac:cf:85"|"a8:bb:cf"|"68:d9:3c"|"f4:5c:89"|"88:66:a5") echo "Apple";;
           # Android 设备
           "44:d4:e0"|"00:e0:4c"|"40:40:a7"|"40:31:3c"|"54:f2:9f") echo "Android";;
           # 小米设备
           "f8:a7:c3"|"28:6c:07"|"7c:49:eb") echo "Xiaomi";;
           # 华为设备
           "48:46:c1"|"00:e0:fc"|"68:ab:bc") echo "Huawei";;
           *) echo "未知设备";;
       esac
       return
   fi
   
   # 如果是 * 或 wlan0 或者名字包含MAC地址,则使用MAC前缀识别
   if [ "$hostname" = "*" ] || [ "$hostname" = "wlan0" ] || echo "$hostname" | $GREP -q "[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}" ]; then
       case "${mac:0:8}" in
           # Apple 设备
           "d8:96:95"|"ac:cf:85"|"a8:bb:cf"|"68:d9:3c"|"f4:5c:89"|"88:66:a5") echo "Apple";;
           # Android 设备
           "44:d4:e0"|"00:e0:4c"|"40:40:a7"|"40:31:3c"|"54:f2:9f") echo "Android";;
           # 小米设备
           "f8:a7:c3"|"28:6c:07"|"7c:49:eb") echo "Xiaomi";;
           # 华为设备
           "48:46:c1"|"00:e0:fc"|"68:ab:bc") echo "Huawei";;
           *) echo "未知设备";;
       esac
   else
       # 取第一个空格前的内容作为主机名
       hostname=$(echo "$hostname" | $CUT -d' ' -f1)
       echo "$hostname"
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
  
  # 从缓存中获取MAC地址
  local mac=$(echo "$ARP_CACHE" | $GREP "$ip" | $HEAD -n 1 | $AWK '{print $4}')
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
  $IPTABLES_PATH -L STATS >/dev/null 2>&1 || {
      $IPTABLES_PATH -N STATS
      $IPTABLES_PATH -I FORWARD -j STATS
  }
  
  # 先获取缓存数据
  ARP_CACHE=$(arp -n)
  STATS_CACHE=$($IPTABLES_PATH -L STATS -nvx)
  
  # 开始创建JSON
  create_json_start
  # 统计
  TOTAL_UP=0
  TOTAL_DOWN=0
  FIRST=1
  
  # 从ARP缓存中获取IP列表
  for ip in $(echo "$ARP_CACHE" | $AWK '/[[:space:]]ether[[:space:]]/ {print $1}')
  do
      # 检查IP是否已有规则，没有则添加
      echo "$STATS_CACHE" | $GREP -q $ip || {
          $IPTABLES_PATH -A STATS -s $ip
          $IPTABLES_PATH -A STATS -d $ip
          # 更新缓存
          STATS_CACHE=$($IPTABLES_PATH -L STATS -nvx)
      }
      
      # 从缓存中获取流量数据
      UP=$(echo "$STATS_CACHE" | $GREP "$ip" | $HEAD -n 1 | $AWK '{print $2}')
      DOWN=$(echo "$STATS_CACHE" | $GREP "$ip" | $TAIL -n 1 | $AWK '{print $2}')
      
      UP=${UP:-0}
      DOWN=${DOWN:-0}
      
      TOTAL_UP=$((TOTAL_UP + UP))
      TOTAL_DOWN=$((TOTAL_DOWN + DOWN))
      
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
