#!/bin/sh
# 流量统计脚本
# 用途：统计局域网设备开机后的总流量
# JSON位置：/tmp/traffic_stats.json
# 定义变量
JSON_FILE="/tmp/traffic_stats.json"
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
   local line=$(grep "$ip" /tmp/dnsmasq.leases)
   local hostname=$(echo "$line" | awk '{print $4}')
   local mac=$(echo "$line" | awk '{print $2}')
   
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
   if [ "$hostname" = "*" ] || [ "$hostname" = "wlan0" ] || echo "$hostname" | grep -q "[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}" ]; then
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
       hostname=$(echo "$hostname" | cut -d' ' -f1)
       echo "$hostname"
   fi
}
# 创建JSON数组开始
create_json_start() {
  echo -n "{\"time\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"devices\":[" > $JSON_FILE
}
# 添加设备到JSON
add_device_json() {
  local ip="$1"
  local up="$2"
  local down="$3"
  local first="$4"
  
  # 获取MAC地址
  local mac=$(arp -n | grep "$ip" | head -n 1 | awk '{print $4}')
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
  iptables -L STATS >/dev/null 2>&1 || {
      iptables -N STATS
      iptables -I FORWARD -j STATS
  }
  # 开始创建JSON
  create_json_start
  # 统计
  TOTAL_UP=0
  TOTAL_DOWN=0
  FIRST=1
  
  for ip in $(arp -n | grep -v incomplete | grep "\[ether\]" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
  do
      # 检查IP是否已有规则，没有则添加
      iptables -L STATS -v | grep -q $ip || {
          iptables -A STATS -s $ip
          iptables -A STATS -d $ip
      }
      UP=$(iptables -L STATS -nvx | grep "$ip" | head -n 1 | awk '{print $2}')
      DOWN=$(iptables -L STATS -nvx | grep "$ip" | tail -n 1 | awk '{print $2}')
      
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
traffic_stats
