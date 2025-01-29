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

# 获取主机名
get_hostname() {
   local ip="$1"
   local line=$($GREP "$ip" /tmp/dnsmasq.leases 2>/dev/null)
   local hostname=$(echo "$line" | $AWK '{print $4}' 2>/dev/null)
   local mac=$(echo "$line" | $AWK '{print $2}' 2>/dev/null)
   
   # 如果主机名为空、Unknown、*、wlan0或者是MAC地址格式
   if [ -z "$hostname" ] || [ "$hostname" = "Unknown" ] || [ "$hostname" = "*" ] || \
      [ "$hostname" = "wlan0" ] || echo "$hostname" | $GREP -q "^[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]" 2>/dev/null; then
       
       # 确保mac变量不为空且格式正确
       if [ ! -z "$mac" ] && echo "$mac" | $GREP -q "^[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]" 2>/dev/null; then
           # 获取 MAC 地址的前两个字节
           local mac_prefix=$(echo "$mac" | $AWK -F: '{print $1":"$2}' 2>/dev/null)
           
           case "$mac_prefix" in
               # PC设备 (包括各大品牌PC和网卡)
               00:14|00:24|00:1f|00:22|00:26|00:12|00:02|00:03|00:0c|\
               00:0e|00:11|00:13|00:1d|00:21|08:00|d4:be|5c:f9|00:16|\
               00:19|00:1a|00:1b|00:1c|00:23|00:25|10:00|10:1f|18:03|\
               3c:97|44:37|54:04|8c:16|e0:db) echo "PC";;

               # Apple 设备（包括 iPhone、iPad、Mac 等）
               00:88|00:db|04:15|04:1e|04:26|04:48|04:4b|04:52|04:54|\
               28:5a|34:ab|60:01|64:20|68:96|70:11|ac:bc|a8:bb|00:1c|\
               00:1e|00:23|04:0c|24:ab|40:30|44:2a|68:5b|78:31|78:4f|\
               80:be|88:53|88:66|90:60|90:b2|b8:e8|c8:2a|c8:69) echo "Apple";;
               
               # 小米设备（包括手机、平板、IoT设备）
               f8:a7|28:6c|7c:49|64:cc|28:e3|0c:1d|10:2a|58:44|64:09|\
               8c:be|9c:99|ac:f7|fc:64|00:9e|14:f6|18:59|20:82|3c:bd|\
               7c:1d|98:fa|c4:0b|c4:6a|d4:97|ec:d0|f0:b4|f4:8b|34:ce|\
               64:b4|8c:1f|98:9c) echo "Xiaomi";;
               
               # 华为设备（包括手机、平板、路由器）
               48:46|00:e0|68:a0|68:a8|70:54|70:72|70:79|70:7b|70:8a|\
               74:88|78:1d|78:6a|68:ab|00:18|00:25|00:34|00:46|10:47|\
               10:c6|28:31|2c:97|3c:df|48:43|4c:54|4c:f9|50:01|54:39|\
               58:2a|5c:09|5c:7d|60:de|60:e7|74:9d|80:13|80:b6|88:28|\
               88:44|88:cf|9c:37|9c:b2|ac:4e|ac:85|b4:15|b8:bc|bc:25|\
               bc:76|c4:05|c4:86|cc:a2|d0:d0|d4:40|d4:b1|dc:d9|e4:a7|\
               e8:08|ec:4d|f4:55|f4:c7|f8:01|f8:23|f8:75|fc:48) echo "Huawei";;

               # OPPO 设备
               a4:3d|8c:0f|ec:51|cc:2d|f4:29|1c:77|e8:bb|1c:48|2c:5b|\
               3c:77|44:11|4c:18|4c:a1|50:63|5c:32|7c:93|88:6a|08:d2|\
               2c:bc|3c:33|48:00|a0:41|a4:77|b8:37|bc:3a|c8:f2|cc:2d|\
               dc:6d|e8:b4|ec:51) echo "OPPO";;

               # vivo 设备
               70:47|90:63|9c:a5|10:f6|14:23|18:e3|1c:da|20:5d|24:31|\
               28:fa|2c:dc|3c:a3|44:9e|4c:fb|50:bc|50:e0|54:19|08:23|\
               18:e3|1c:da|20:5d|3c:a3|4c:fb|60:be|70:47|74:23|76:40|\
               90:63|94:14|9c:a5|bc:2d|c4:66|f4:29|f8:1d) echo "vivo";;

               # 三星设备
               a0:10|a0:21|a0:82|a4:84|a8:f2|ac:5f|b0:47|b0:c4|b0:df|\
               b4:62|b8:57|b8:5e|c4:42|00:07|00:15|00:17|00:1b|00:23|\
               00:24|08:08|08:37|08:d4|0c:14|10:1d|14:49|14:89|18:16|\
               18:3f|1c:62|20:13|24:4b|28:27|28:39|30:07|34:23|38:0a|\
               38:16|3c:5a|3c:8b|40:0e|44:4e|48:13|4c:3c|50:32|50:77|\
               50:b7|54:88|58:b1|5c:2e|5c:49|5c:99|60:6b|64:1c|68:27|\
               68:48|6c:2f|70:28|70:fd|78:00|78:47|7c:0b|7c:2e|80:18|\
               84:11|84:25|84:38|84:55|88:32|8c:71|90:f1|94:01|94:35|\
               98:1d|9c:02|a0:75|a4:6c|a8:51|ac:36|b0:47|b4:3a|b8:57|\
               bc:14|bc:44|bc:72|c0:65|c4:50|c8:14|cc:07|d0:17|d4:87|\
               d4:e8|d8:90|e4:32|e4:40|e4:92|e8:3a|f0:72|f4:42|f4:9f|\
               f8:77|fc:00|fc:42) echo "Samsung";;

               # 路由器设备
               14:cf|14:22|54:c8|54:75|30:b4|18:d6|84:16|c0:3f|84:1b|\
               44:94|40:5d|28:c6|20:4e|20:0c|00:0f|00:1a|00:27|08:10|\
               0c:80|18:d6|1c:1d|24:de|28:c6|30:b4|30:fc|44:94|48:7d|\
               50:bd|54:75|54:a0|5c:63|60:32|64:66|6c:19|70:4f|74:ea|\
               84:16|88:25|8c:21|90:ae|98:da|9c:c9|a0:f3|ac:84|b0:be|\
               c0:3f|c4:e9|c8:3a|cc:08|d4:6e|d8:32|e4:d3|e8:94|ec:26|\
               f4:83|fc:ec) echo "路由器";;

               # 特殊物联网设备 (ESP、树莓派等)
               18:fe|24:0a|28:6d|3c:71|b8:27|dc:a6|e4:5f|d8:0d|00:1b|\
               24:62|30:ae|3c:71|40:f5|4c:11|54:2b|60:01|68:c6|80:7d|\
               84:cc|84:f3|8c:aa|98:f4|ac:d0|b4:e6|bc:dd|c4:4f|cc:50|\
               d8:a0|dc:4f|ec:fa) echo "ESP设备";;

               # 闭路摄像头设备
               00:40|28:2c|e0:50|00:08|00:0e|ec:71|78:1f|54:c4|bc:32|\
               00:24|3c:ef|4c:bc|90:02|10:12|bc:51|84:26|28:24|40:23|\
               34:29) echo "摄像头";;
               
               # 打印机设备
               00:17|00:80|08:00|30:05|3c:d9|00:00|00:21|00:26|9c:93|\
               00:01|00:04|00:30|9c:ae|00:22|00:25|f4:ce|00:11) echo "打印机";;

               # 若都不匹配则显示未知设备
               *) echo "未知设备";;
           esac
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
