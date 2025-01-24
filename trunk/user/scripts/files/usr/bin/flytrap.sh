#!/bin/sh
# 此脚本用于防火墙规则的管理，通过设置必要的规则来屏蔽不良IP。规则会持续生效，直到系统重启或手动重置防火墙。
# 设置脚本执行权限：chmod 755 /usr/bin/flytrap.sh
# 清理黑名单所有规则和IP集合：/usr/bin/flytrap.sh clean
# 列出黑名单和白名单中的IP：/usr/bin/flytrap.sh list 4（IPv4或IPv6）
# 将一个IP添加到黑名单：/usr/bin/flytrap.sh add 112.17.165.25
# 从黑名单中删除一个IP：/usr/bin/flytrap.sh del 107.148.94.42
# 如需记录屏蔽IP，在定时任务执行：/usr/bin/flytrap.sh log_blocked_ips
# 添加白名单IP：/usr/bin/flytrap.sh add_whitelist 192.168.1.100
# 删除白名单IP：/usr/bin/flytrap.sh del_whitelist 192.168.1.100

# 可自定义的选项区域

wan_name="ppp0"  # 监控的网络接口名称
trap_ports="20,21,22,23,3389"  # 需要监控的端口，多个端口用逗号分隔
trap6="no"  # 是否启用IPv6支持，"yes"启用，"no"禁用
unlock="16888"  # 黑名单IP的超时时间，0表示永久，单位：秒
log_file="/tmp/IPblacklist-log.txt"  # 日志文件路径
sh_file="/usr/bin"  # 脚本安装路径
max_log_size=$((3*1024*1024))  # 最大日志文件大小，默认3MB
# 白名单的IP地址，可以通过脚本参数动态添加和删除
whitelist_ips="107.149.214.25,107.148.94.42"  # 示例白名单IP，多个IP用逗号分隔

# 可自定义的选项结束

# 设置PATH，确保脚本可以找到所需命令
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/bin:/opt/sbin:$PATH"

# 定义匹配IPv4和IPv6地址的正则表达式
IPREX4='([0-9]{1,3}\.){3}[0-9]{1,3}(/([0-9]|[1-2][0-9]|3[0-2]))?'
IPREX6='([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}(([0-9]{1,3}\.){3}[0-9]{1,3})|([0-9a-fA-F]{1,4}:){1,4}:(([0-9]{1,3}\.){3}[0-9]{1,3})'

# 动态获取所需命令路径
IPSET_PATH=$(which ipset 2>/dev/null)
IPTABLES_PATH=$(which iptables 2>/dev/null)
IP6TABLES_PATH=$(which ip6tables 2>/dev/null)
GREP=$(which grep 2>/dev/null)
AWK=$(which awk 2>/dev/null)
SED=$(which sed 2>/dev/null)
DATE=$(which date 2>/dev/null)
PS=$(which ps 2>/dev/null)
RM=$(which rm 2>/dev/null)
TOUCH=$(which touch 2>/dev/null)
SLEEP=$(which sleep 2>/dev/null)
KILL=$(which kill 2>/dev/null)
STAT=$(which stat 2>/dev/null)

# 检查必需命令是否存在
check_required_commands() {
    local missing_commands=0
    
    if [ -z "$IPSET_PATH" ]; then
        echo "错误: 未找到 ipset 命令" | tee -a "$log_file"
        missing_commands=1
    fi
    
    if [ -z "$IPTABLES_PATH" ]; then
        echo "错误: 未找到 iptables 命令" | tee -a "$log_file"
        missing_commands=1
    fi
    
    if [ -z "$GREP" ] || [ -z "$AWK" ] || [ -z "$SED" ]; then
        echo "错误: 基本文本处理命令 (grep/awk/sed) 缺失" | tee -a "$log_file"
        missing_commands=1
    fi
    
    if [ "$trap6" = "yes" ] && [ -z "$IP6TABLES_PATH" ]; then
        echo "错误: IPv6 已启用但未找到 ip6tables 命令" | tee -a "$log_file"
        missing_commands=1
    fi
    
    if [ $missing_commands -eq 1 ]; then
        exit 1
    fi
}

# 检查规则是否存在的辅助函数（保持不变）
check_rule_exists() {
    local ipt_cmd=$1
    local rule=$2
    $ipt_cmd -C $rule >/dev/null 2>&1
    return $?
}

# 环境检查函数，检测是否安装了iptables和ip6tables
check_environment() {
    if [ "$trap6" = "yes" ] && [ -z "$IP6TABLES_PATH" ]; then
        echo "trap6设置为yes，但未找到ip6tables命令，IPv6支持将被禁用。" | tee -a "$log_file"
        trap6="no"
    fi

    if [ -z "$IPTABLES_PATH" ] || [ ! -x "$IPTABLES_PATH" ]; then
        echo "未找到iptables命令，请手动安装iptables。" | tee -a "$log_file"
        exit 1
    fi
}

# 检查 IPSET_PATH 是否有效，如果无效则安装 ipset
check_ipset() {
    if [ -z "$IPSET_PATH" ] || [ ! -x "$IPSET_PATH" ]; then
        echo "未找到 ipset 命令，正在尝试安装..."
        install_ipset
        IPSET_PATH=$(which ipset)
        if [ -z "$IPSET_PATH" ] || [ ! -x "$IPSET_PATH" ]; then
            echo "安装 ipset 失败，请手动安装。" | tee -a "$log_file"
            exit 1
        fi
    fi
}

# 检查并清理已运行的进程
check_and_clean_process() {
    local script_name=$(basename "$0")  # 获取当前脚本名称
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

# 日志管理函数，检查日志文件大小，如果超过限制则删除旧日志并创建新日志
manage_log() {
    if [ -f "$log_file" ]; then
        log_size=$($STAT -c%s "$log_file")
        if [ "$log_size" -ge "$max_log_size" ]; then
            echo "日志文件大小超过限制，删除旧日志文件并创建新日志文件。"
            $RM -f "$log_file"
            $TOUCH "$log_file"
        fi
    fi
}

# 创建IP集合（黑名单和白名单）
create_ipset() {
    if ! $IPSET_PATH list -n | $GREP -q "flytrap_blacklist"; then
        echo "正在创建flytrap ipset ipv4..." | tee -a "$log_file"
        if [ "$unlock" -gt 0 ]; then
            $IPSET_PATH create flytrap_blacklist hash:net timeout $unlock || { echo "创建flytrap_blacklist失败。" | tee -a "$log_file"; exit 1; }
        else
            $IPSET_PATH create flytrap_blacklist hash:net || { echo "创建flytrap_blacklist失败。" | tee -a "$log_file"; exit 1; }
        fi
    else
        echo "flytrap ipset ipv4已经存在。" | tee -a "$log_file"
    fi

    if [ "$trap6" = "yes" ] && ! $IPSET_PATH list -n | $GREP -q flytrap6_blacklist; then
        echo "正在创建flytrap ipset ipv6..." | tee -a "$log_file"
        if [ "$unlock" -gt 0 ]; then
            $IPSET_PATH create flytrap6_blacklist hash:net family inet6 timeout $unlock || { echo "创建flytrap6_blacklist失败。" | tee -a "$log_file"; trap6="no"; }
        else
            $IPSET_PATH create flytrap6_blacklist hash:net family inet6 || { echo "创建flytrap6_blacklist失败。" | tee -a "$log_file"; trap6="no"; }
        fi
    else
        echo "flytrap ipset ipv6已经存在。" | tee -a "$log_file"
    fi

    # 创建白名单
    if ! $IPSET_PATH list -n | $GREP -q "flytrap_whitelist"; then
        echo "正在创建flytrap ipset白名单..." | tee -a "$log_file"
        $IPSET_PATH create flytrap_whitelist hash:net || { echo "创建flytrap_whitelist失败。" | tee -a "$log_file"; exit 1; }
    else
        echo "flytrap ipset白名单已经存在。" | tee -a "$log_file"
    fi
}

# 清理iptables规则
clean_ipt() {
    rule_exp=$1
    rule_comment=$2
    rule_type=$3
    ipt_cmd=$IPTABLES_PATH
    [ "$rule_type" = "6" ] && ipt_cmd=$IP6TABLES_PATH
    ipt_test=$($ipt_cmd -S | $GREP -E "$rule_exp" | head -1)
    while echo "$ipt_test" | $GREP -q "\-A"; do
        echo "清理规则：$rule_comment IPv$rule_type ..." | tee -a "$log_file"
        $ipt_cmd $(echo "$ipt_test" | $SED "s/-A/-D/")
        ipt_test=$($ipt_cmd -S | $GREP -E "$rule_exp" | head -1)
    done
}

# 清理IP集合和相关规则
clean_trap() {
    clean_ipt "INPUT.+$wan_name.+multiport.+flytrap_blacklist" "INPUT->flytrap_blacklist(ipset) IPv4" "4"
    clean_ipt "FORWARD.+$wan_name.+multiport.+flytrap_blacklist" "INPUT->flytrap_blacklist(ipset) IPv4" "4"
    clean_ipt "INPUT.+match-set.+flytrap_blacklist.+DROP" "flytrap_blacklist->INPUT(DROP) IPv4" "4"
    clean_ipt "FORWARD.+match-set.+flytrap_blacklist.+DROP" "flytrap_blacklist->FORWARD(DROP) IPv4" "4"
    clean_ipt "OUTPUT.+match-set.+flytrap_blacklist.+DROP" "flytrap_blacklist->OUTPUT(DROP) IPv4" "4"
    $IPSET_PATH list -n | $GREP -q "flytrap_blacklist" && $IPSET_PATH destroy flytrap_blacklist
    $IPSET_PATH list -n | $GREP -q "flytrap_whitelist" && $IPSET_PATH destroy flytrap_whitelist
    if [ "$trap6" = "yes" ]; then
        clean_ipt "INPUT.+$wan_name.+multiport.+flytrap6_blacklist" "INPUT->flytrap6_blacklist(ipset) IPv6" "6"
        clean_ipt "FORWARD.+$wan_name.+multiport.+flytrap6_blacklist" "INPUT->flytrap6_blacklist(ipset) IPv6" "6"
        clean_ipt "INPUT.+match-set.+flytrap6_blacklist.+DROP" "flytrap6_blacklist->INPUT(DROP) IPv6" "6"
        clean_ipt "FORWARD.+match-set.+flytrap6_blacklist.+DROP" "flytrap6_blacklist->FORWARD(DROP) IPv6" "6"
        clean_ipt "OUTPUT.+match-set.+flytrap6_blacklist.+DROP" "flytrap6_blacklist->OUTPUT(DROP) IPv6" "6"
        $IPSET_PATH list -n | $GREP -q flytrap6_blacklist && $IPSET_PATH destroy flytrap6_blacklist
    fi
}

# 检查防火墙规则，并记录被加入黑名单的IP
add_trap() {
    # 添加白名单规则，确保插入到INPUT链的第一个位置
    if ! $IPTABLES_PATH -C INPUT -m set --match-set flytrap_whitelist src -j ACCEPT >/dev/null 2>&1; then
        echo "添加flytrap_whitelist白名单规则..." | tee -a "$log_file"
        $IPTABLES_PATH -I INPUT 1 -m set --match-set flytrap_whitelist src -j ACCEPT || {
            echo "无法添加白名单规则。" | tee -a "$log_file"
            exit 1
        }
        # 添加RETURN规则，确保白名单IP直接跳过后续规则
        $IPTABLES_PATH -I INPUT 2 -m set --match-set flytrap_whitelist src -j RETURN || {
            echo "无法添加白名单跳过规则。" | tee -a "$log_file"
            exit 1
        }
    else
        echo "flytrap_whitelist白名单规则已存在，不需要重复添加。" | tee -a "$log_file"
    fi

    if ! $IPTABLES_PATH -C INPUT -m set --match-set flytrap_blacklist src -j DROP >/dev/null 2>&1; then
        echo "添加flytrap_blacklist规则..." | tee -a "$log_file"
        $IPTABLES_PATH -I INPUT -m set --match-set flytrap_blacklist src -j LOG --log-prefix "IP Blocked: " --log-level 4 || {
            echo "无法添加日志规则。" | tee -a "$log_file"
            exit 1
        }
        $IPTABLES_PATH -I INPUT -m set --match-set flytrap_blacklist src -j DROP || {
            echo "无法添加DROP规则。" | tee -a "$log_file"
            exit 1
        }
        $IPTABLES_PATH -I FORWARD -m set --match-set flytrap_blacklist src -j DROP || {
            echo "无法添加FORWARD规则。" | tee -a "$log_file"
            exit 1
        }
        $IPTABLES_PATH -I OUTPUT -m set --match-set flytrap_blacklist src -j DROP || {
            echo "无法添加OUTPUT规则。" | tee -a "$log_file"
            exit 1
        }
    else
        echo "flytrap_blacklist规则已存在，不需要重复添加。" | tee -a "$log_file"
    fi

    if ! $IPTABLES_PATH -C INPUT -i "$wan_name" -p tcp -m multiport --dports "$trap_ports" -m set ! --match-set flytrap_whitelist src -j SET --add-set flytrap_blacklist src >/dev/null 2>&1; then
        echo "添加蜜罐规则..." | tee -a "$log_file"
        $IPTABLES_PATH -I INPUT -i "$wan_name" -p tcp -m multiport --dports "$trap_ports" -m set ! --match-set flytrap_whitelist src -j SET --add-set flytrap_blacklist src || {
            echo "无法添加蜜罐规则。" | tee -a "$log_file"
            exit 1
        }
        $IPTABLES_PATH -I FORWARD -i "$wan_name" -p tcp -m multiport --dports "$trap_ports" -m set ! --match-set flytrap_whitelist src -j SET --add-set flytrap_blacklist src || {
            echo "无法添加FORWARD蜜罐规则。" | tee -a "$log_file"
            exit 1
        }
    else
        echo "蜜罐规则已存在，不需要重复添加。" | tee -a "$log_file"
    fi

    # IPv6 规则部分
    if [ "$trap6" = "yes" ]; then
        if ! $IP6TABLES_PATH -C INPUT -m set --match-set flytrap6_blacklist src -j DROP >/dev/null 2>&1; then
            echo "添加flytrap6_blacklist规则..." | tee -a "$log_file"
            $IP6TABLES_PATH -I INPUT -m set --match-set flytrap6_blacklist src -j LOG --log-prefix "IP6 Blocked: " --log-level 4 || {
                echo "无法添加IPv6日志规则。" | tee -a "$log_file"
                exit 1
            }
            $IP6TABLES_PATH -I INPUT -m set --match-set flytrap6_blacklist src -j DROP || {
                echo "无法添加IPv6 DROP规则。" | tee -a "$log_file"
                exit 1
            }
            $IP6TABLES_PATH -I FORWARD -m set --match-set flytrap6_blacklist src -j DROP || {
                echo "无法添加IPv6 FORWARD规则。" | tee -a "$log_file"
                exit 1
            }
            $IP6TABLES_PATH -I OUTPUT -m set --match-set flytrap6_blacklist src -j DROP || {
                echo "无法添加IPv6 OUTPUT规则。" | tee -a "$log_file"
                exit 1
            }
        else
            echo "flytrap6_blacklist规则已存在，不需要重复添加。" | tee -a "$log_file"
        fi

        if ! $IP6TABLES_PATH -C INPUT -i "$wan_name" -p tcp -m multiport --dports "$trap_ports" -j SET --add-set flytrap6_blacklist src >/dev/null 2>&1; then
            echo "添加IPv6蜜罐规则..." | tee -a "$log_file"
            $IP6TABLES_PATH -I INPUT -i "$wan_name" -p tcp -m multiport --dports "$trap_ports" -j SET --add-set flytrap6_blacklist src || {
                echo "无法添加IPv6蜜罐规则。" | tee -a "$log_file"
                exit 1
            }
            $IP6TABLES_PATH -I FORWARD -i "$wan_name" -p tcp -m multiport --dports "$trap_ports" -j SET --add-set flytrap6_blacklist src || {
                echo "无法添加IPv6 FORWARD蜜罐规则。" | tee -a "$log_file"
                exit 1
            }
        else
            echo "IPv6蜜罐规则已存在，不需要重复添加。" | tee -a "$log_file"
        fi
    fi
}

# 添加IP到白名单
add_whitelist() {
    $IPSET_PATH add flytrap_whitelist $1
    echo "添加IP $1 到白名单完成。" | tee -a "$log_file"
}

# 从白名单中删除IP
del_whitelist() {
    $IPSET_PATH del flytrap_whitelist $1
    echo "从白名单中删除IP $1 完成。" | tee -a "$log_file"
}

# 日志记录脚本 - 修改后的版本
log_blocked_ips() {
    manage_log  # 检查日志文件大小

    # 检查所有必要的规则是否存在
    rules_missing=0

    # 检查 ipset 规则集
    if ! $IPSET_PATH list -n | $GREP -q "flytrap_blacklist" || \
       ! $IPSET_PATH list -n | $GREP -q "flytrap_whitelist"; then
        rules_missing=1
    fi

    # 检查 IPv4 规则
    if ! check_rule_exists "$IPTABLES_PATH" "INPUT -m set --match-set flytrap_blacklist src -j DROP" || \
       ! check_rule_exists "$IPTABLES_PATH" "FORWARD -m set --match-set flytrap_blacklist src -j DROP" || \
       ! check_rule_exists "$IPTABLES_PATH" "OUTPUT -m set --match-set flytrap_blacklist src -j DROP" || \
       ! check_rule_exists "$IPTABLES_PATH" "INPUT -m set --match-set flytrap_whitelist src -j ACCEPT" || \
       ! check_rule_exists "$IPTABLES_PATH" "INPUT -i $wan_name -p tcp -m multiport --dports $trap_ports -m set ! --match-set flytrap_whitelist src -j SET --add-set flytrap_blacklist src"; then
        rules_missing=1
    fi

    # 如果启用了 IPv6，检查 IPv6 规则
    if [ "$trap6" = "yes" ]; then
        if ! $IPSET_PATH list -n | $GREP -q "flytrap6_blacklist" || \
           ! check_rule_exists "$IP6TABLES_PATH" "INPUT -m set --match-set flytrap6_blacklist src -j DROP" || \
           ! check_rule_exists "$IP6TABLES_PATH" "FORWARD -m set --match-set flytrap6_blacklist src -j DROP" || \
           ! check_rule_exists "$IP6TABLES_PATH" "OUTPUT -m set --match-set flytrap6_blacklist src -j DROP" || \
           ! check_rule_exists "$IP6TABLES_PATH" "INPUT -i $wan_name -p tcp -m multiport --dports $trap_ports -j SET --add-set flytrap6_blacklist src"; then
            rules_missing=1
        fi
    fi

    # 检查防护规则
    if ! check_rule_exists "$IPTABLES_PATH" "INPUT -p tcp --syn -m connlimit --connlimit-above 20 --connlimit-mask 32 -j DROP" || \
       ! check_rule_exists "$IPTABLES_PATH" "INPUT -p tcp ! --syn -m state --state NEW -j DROP" || \
       ! check_rule_exists "$IPTABLES_PATH" "INPUT -m state --state INVALID -j DROP"; then
        rules_missing=1
    fi

    # 如果发现规则缺失，重新运行完整脚本
    if [ $rules_missing -eq 1 ]; then
        echo "检测到防火墙规则不完整，重新运行脚本添加防火墙规则..." | tee -a "$log_file"
        $sh_file/flytrap.sh &
    else
        # 记录当前黑名单
        current_time=$($DATE '+%Y-%m-%d %H:%M:%S')
        echo "$current_time IPv4 黑名单：" >> "$log_file"
        $IPSET_PATH list flytrap_blacklist | $AWK '/^[0-9]/ {print $1}' >> "$log_file"

        if [ "$trap6" = "yes" ]; then
            echo "$current_time IPv6 黑名单：" >> "$log_file"
            $IPSET_PATH list flytrap6_blacklist | $AWK '/^[0-9]/ {print $1}' >> "$log_file"
        fi

        echo "***************************************" >> "$log_file"
    fi
}

# 将白名单组中的IP添加到flytrap_whitelist
add_ips_to_whitelist() {
    oldIFS="$IFS"
    IFS=','
    for ip in $whitelist_ips; do
        if [ -n "$ip" ]; then
            # 检查IP是否已在白名单中
            if ! $IPSET_PATH test flytrap_whitelist "$ip" 2>/dev/null; then
                $IPSET_PATH add flytrap_whitelist "$ip" 2>/dev/null
                echo "添加 $ip 到白名单成功" | tee -a "$log_file"
            else
                echo "IP $ip 已经在白名单中，跳过添加" | tee -a "$log_file"
            fi
        fi
    done
    IFS="$oldIFS"
}

# 列出IP集合中的IP地址
list_ips() {
    list_type=$1
    if [ "$list_type" = "4" ]; then
        if $IPSET_PATH list -n | $GREP -q flytrap_blacklist; then
            echo "IPv4 黑名单中的IP:"
            $IPSET_PATH list flytrap_blacklist
        else
            echo "没有找到IPv4黑名单flytrap_blacklist。"
        fi
    elif [ "$list_type" = "6" ]; then
        if $IPSET_PATH list -n | $GREP -q flytrap6_blacklist; then
            echo "IPv6 黑名单中的IP:"
            $IPSET_PATH list flytrap6_blacklist
        else
            echo "没有找到IPv6黑名单flytrap6_blacklist。"
        fi
    else
        echo "未知的IP类型：$list_type"
    fi
    echo "..........................."
    if $IPSET_PATH list -n | $GREP -q flytrap_whitelist; then
        echo "白名单中的IP:"
        $IPSET_PATH list flytrap_whitelist
    else
        echo "没有找到白名单flytrap_blacklist。"
    fi
}

# 配置防火墙的防护规则
setup_firewall_rules() {
    echo "设置防火墙规则..." | tee -a "$log_file"

    # 防止重复创建链
    if ! $IPTABLES_PATH -L syn-flood >/dev/null 2>&1; then
        $IPTABLES_PATH -N syn-flood
        $IPTABLES_PATH -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 4 -j RETURN
        $IPTABLES_PATH -A INPUT -p tcp --syn -j DROP
    else
        echo "Syn-Flood规则已存在。" | tee -a "$log_file"
    fi

    # 防止碎片攻击
    if ! $IPTABLES_PATH -C INPUT -f -m limit --limit 100/s --limit-burst 100 -j ACCEPT >/dev/null 2>&1; then
        $IPTABLES_PATH -A INPUT -f -m limit --limit 100/s --limit-burst 100 -j ACCEPT
        $IPTABLES_PATH -A INPUT -f -j DROP
    else
        echo "碎片攻击规则已存在。" | tee -a "$log_file"
    fi

    # 防止ICMP（Ping）攻击
    if ! $IPTABLES_PATH -C INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 10 -j ACCEPT >/dev/null 2>&1; then
        $IPTABLES_PATH -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 10 -j ACCEPT
        $IPTABLES_PATH -A INPUT -p icmp --icmp-type echo-request -j DROP
    else
        echo "ICMP攻击规则已存在。" | tee -a "$log_file"
    fi
    
    # 防止DOS攻击
    if ! $IPTABLES_PATH -C INPUT -p tcp ! --syn -m state --state NEW -j DROP >/dev/null 2>&1; then
        $IPTABLES_PATH -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
        $IPTABLES_PATH -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
        $IPTABLES_PATH -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
        $IPTABLES_PATH -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
        $IPTABLES_PATH -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
        $IPTABLES_PATH -A INPUT -p tcp --tcp-flags ACK,FIN FIN -j DROP
        $IPTABLES_PATH -A INPUT -p tcp --tcp-flags ACK,PSH PSH -j DROP
        $IPTABLES_PATH -A INPUT -p tcp --tcp-flags ACK,URG URG -j DROP
        $IPTABLES_PATH -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
        $IPTABLES_PATH -A INPUT -p tcp --tcp-flags ALL SYN,FIN,PSH,URG -j DROP
    else
        echo "DOS攻击规则已存在。" | tee -a "$log_file"
    fi

    # 防止SYN-Flood攻击的规则
    if ! $IPTABLES_PATH -C INPUT -p tcp --syn -m connlimit --connlimit-above 20 --connlimit-mask 32 -j DROP >/dev/null 2>&1; then
        $IPTABLES_PATH -A INPUT -p tcp --syn -m connlimit --connlimit-above 20 --connlimit-mask 32 -j DROP
    else
        echo "SYN-Flood攻击的规则已存在。" | tee -a "$log_file"
    fi

    # 防止伪装攻击
    if ! $IPTABLES_PATH -C INPUT -s 224.0.0.0/3 -j DROP >/dev/null 2>&1; then
        $IPTABLES_PATH -A INPUT -s 224.0.0.0/3 -j DROP
        $IPTABLES_PATH -A INPUT -s 169.254.0.0/16 -j DROP
        $IPTABLES_PATH -A INPUT -s 172.16.0.0/12 -j DROP
        $IPTABLES_PATH -A INPUT -s 192.0.2.0/24 -j DROP
        $IPTABLES_PATH -A INPUT -s 10.0.0.0/8 -j DROP
        $IPTABLES_PATH -A INPUT -s 0.0.0.0/8 -j DROP
        $IPTABLES_PATH -A INPUT -s 240.0.0.0/5 -j DROP
        $IPTABLES_PATH -A INPUT -s 127.0.0.0/8 ! -i lo -j DROP
    else
        echo "伪装攻击规则已存在。" | tee -a "$log_file"
    fi

    # 日志记录和丢弃非法数据包
    if ! $IPTABLES_PATH -C INPUT -m state --state INVALID -j LOG --log-prefix "INVALID DROP: " >/dev/null 2>&1; then
        $IPTABLES_PATH -A INPUT -m state --state INVALID -j LOG --log-prefix "INVALID DROP: "
        $IPTABLES_PATH -A INPUT -m state --state INVALID -j DROP
    else
        echo "非法数据包处理规则已存在。" | tee -a "$log_file"
    fi

    echo "防火墙规则设置完成！" | tee -a "$log_file"
}

# 根据传入的参数执行相应的操作
case "$1" in
    clean)
        clean_trap
        echo "清空所有IP完成。" | tee -a "$log_file"
        exit
        ;;
    list)
        list_type=$2
        [ -z "$list_type" ] && list_type="4"
        list_ips "$list_type"
        exit
        ;;
    add)
        $IPSET_PATH add flytrap_blacklist $2
        echo "添加IP $2 完成。" | tee -a "$log_file"
        exit
        ;;
    del)
        $IPSET_PATH del flytrap_blacklist $2
        echo "删除IP $2 完成。" | tee -a "$log_file"
        exit
        ;;
    add_whitelist)
        add_whitelist $2
        echo "添加IP $2 完成。" | tee -a "$log_file"
        exit
        ;;
    del_whitelist)
        del_whitelist $2
        echo "删除IP $2 完成。" | tee -a "$log_file"
        exit
        ;;
    log_blocked_ips)
        log_blocked_ips
        echo "检查黑名单日志完成。" | tee -a "$log_file"
        exit
        ;;
esac

# 默认执行清理旧规则、创建新规则并部署防火墙策略
$DATE +"%Y-%m-%d %H:%M:%S %Z" | tee -a "$log_file"
echo "网络接口名称：$wan_name" | tee -a "$log_file"
echo "监控端口：$trap_ports" | tee -a "$log_file"
echo "IPv6支持：$trap6" | tee -a "$log_file"
echo "IP超时设置：$unlock" | tee -a "$log_file"
echo "***************************************" >> "$log_file"

# 检查必需命令
check_required_commands
check_and_clean_process
check_environment
check_ipset
create_ipset
add_trap
add_ips_to_whitelist
setup_firewall_rules

if [ $? -eq 0 ]; then
    echo "脚本运行成功。" | tee -a "$log_file"
else
    echo "脚本运行失败。" | tee -a "$log_file"
fi

echo "***************************************" >> "$log_file"
