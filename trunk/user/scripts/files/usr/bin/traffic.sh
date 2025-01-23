#!/bin/sh

# 流量统计脚本
# 用途：统计局域网设备开机后的总流量
# JSON位置：/www/traffic_stats.json

# 定义变量
JSON_FILE="/www/traffic_stats.json"

# 检查目录
if [ ! -d "/www" ]; then
   echo "Error: /www directory not found"
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
   
   if [ "$first" != "1" ]; then
       echo -n "," >> $JSON_FILE
   fi
   
   echo -n "{\"ip\":\"$ip\",\"mac\":\"$mac\",\"up_bytes\":$up,\"down_bytes\":$down,\"up_formatted\":\"$(format_bytes $up)\",\"down_formatted\":\"$(format_bytes $down)\"}" >> $JSON_FILE
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
