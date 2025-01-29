#!/bin/sh

# 错误码定义
E_SUCCESS=0
E_NETWORK=1
E_AUTH=2
E_API=3
E_PARAM=4
E_SYSTEM=5

# API URL 定义
API_BASE_URL="https://api.cloudflare.com/client/v4"
API_ZONES_URL="$API_BASE_URL/zones"
get_dns_records_url() {
    echo "$API_ZONES_URL/$1/dns_records"
}
get_dns_record_url() {
    echo "$API_ZONES_URL/$1/dns_records/$2"
}

# 动态获取所需命令
CURL=$(which curl 2>/dev/null)
GREP=$(which grep 2>/dev/null)
AWK=$(which awk 2>/dev/null)
SED=$(which sed 2>/dev/null)
DATE=$(which date 2>/dev/null)
PS=$(which ps 2>/dev/null)
KILL=$(which kill 2>/dev/null) 
SLEEP=$(which sleep 2>/dev/null) 
TOUCH=$(which touch 2>/dev/null) 
MKDIR=$(which mkdir 2>/dev/null)  
PING=$(which ping 2>/dev/null)
HEAD=$(which head 2>/dev/null)
CUT=$(which cut 2>/dev/null)
CAT=$(which cat 2>/dev/null)
WC=$(which wc 2>/dev/null)
BASENAME=$(which basename 2>/dev/null)

# 通用错误处理函数
handle_error() {
    error_code=$1
    error_message=$2
    retry_count=${3:-0}
    max_retries=${4:-2}
    
    case $error_code in
        $E_NETWORK)
            log_message "错误" "网络错误: $error_message"
            if [ $retry_count -lt $max_retries ]; then
                log_message "信息" "尝试第 $((retry_count + 1)) 次重试..."
                return 0
            fi
            ;;
        $E_AUTH)
            log_message "错误" "认证错误: $error_message"
            return 1
            ;;
        $E_API)
            log_message "错误" "API错误: $error_message"
            if [ $retry_count -lt $max_retries ]; then
                log_message "信息" "尝试第 $((retry_count + 1)) 次重试..."
                return 0
            fi
            ;;
        $E_PARAM)
            log_message "错误" "参数错误: $error_message"
            return 1
            ;;
        $E_SYSTEM)
            log_message "错误" "系统错误: $error_message"
            return 1
            ;;
        *)
            log_message "错误" "未知错误: $error_message"
            return 1
            ;;
    esac
    return 1
}

# 健康检查函数
check_system_environment() {
    has_error=0
    
    # 检查所有必要的命令
    for cmd in curl grep awk sed date ps kill sleep touch mkdir ping head cut cat wc basename; do
        cmd_var=$(eval echo \$$(echo $cmd | tr 'a-z' 'A-Z'))
        if [ -z "$cmd_var" ]; then
            log_message "错误" "未找到必要的命令: $cmd"
            has_error=1
        else
            log_message "信息" "找到命令 $cmd: $cmd_var"
        fi
    done
    
    # 检查日志目录权限
    log_dir=$(dirname "$LOG_FILE")
    if [ ! -d "$log_dir" ]; then
        if ! mkdir -p "$log_dir" 2>/dev/null; then
            log_message "错误" "无法创建日志目录: $log_dir"
            has_error=1
        fi
    fi
    
    if [ ! -w "$log_dir" ]; then
        log_message "错误" "日志目录无写入权限: $log_dir"
        has_error=1
    fi
    
    [ $has_error -eq 1 ] && return 1
    return 0
}

# 网络连接检查函数
check_network_connectivity() {
    has_error=0
    
    if ! ping -c 1 -W 3 api.cloudflare.com >/dev/null 2>&1; then
        log_message "警告" "无法连接到 Cloudflare API"
        has_error=1
    fi
    
    if ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
        log_message "警告" "无法连接到互联网"
        has_error=1
    fi
    
    [ $has_error -eq 1 ] && return 1
    return 0
}

# 主健康检查函数
health_check() {
    log_message "信息" "开始健康检查..."
    has_error=0
    
    if ! check_system_environment; then
        log_message "错误" "系统环境检查失败"
        has_error=1
    fi
    
    if ! check_network_connectivity; then
        log_message "错误" "网络连接检查失败"
        has_error=1
    fi
    
    if [ $has_error -eq 0 ]; then
        log_message "信息" "健康检查完成"
        return 0
    else
        log_message "错误" "健康检查失败"
        return 1
    fi
}

# 改进的网络请求函数，使用curl
# 改进的网络请求函数，使用curl
curl_with_timeout() {
    url=$1
    shift
    
    retry_count=0
    max_retries=2
    
    while [ $retry_count -lt $max_retries ]; do
        if echo "$CURL" | $GREP -q "^busybox"; then
            # 如果是 busybox curl，移除不支持的选项
            response=$($CURL -s -k \
                      --retry 2 \
                      --retry-delay 1 \
                      "$@" \
                      "$url")
        else
            # 如果是完整版 curl，使用所有选项
            response=$($CURL --silent -k \
                           --max-time 10 \
                           --retry 2 \
                           --retry-delay 1 \
                           --tlsv1.0 \
                           --tls-max 1.2 \
                           --ciphers DEFAULT@SECLEVEL=1 \
                           "$@" \
                           "$url")
        fi
        curl_exit_code=$?
        
        if [ $curl_exit_code -eq 0 ] && [ ! -z "$response" ]; then
            echo "$response"
            return 0
        fi
        
        log_message "警告" "请求失败(尝试 $((retry_count + 1))/$max_retries): $url"
        retry_count=$((retry_count + 1))
        
        if [ $retry_count -lt $max_retries ]; then
            sleep 3
        fi
    done
    
    handle_error $E_NETWORK "curl 失败, URL: $url, 退出码: $curl_exit_code"
    return 1
}

# 检查并清理已运行的进程
check_and_clean_process() {
    local script_name=$(basename "$0")  # 获取当前脚本名称
    local current_pid=$$  # 获取当前脚本的进程ID

    # 使用适配 BusyBox 的命令
    local running_pids=""
    if echo "$PS" | $GREP -q "^busybox"; then
        running_pids=$(busybox ps w | $GREP "$script_name" | $GREP -v grep | $GREP -v "$current_pid" | $AWK '{print $1}')
    else
        running_pids=$($PS w | $GREP "$script_name" | $GREP -v grep | $GREP -v "$current_pid" | $AWK '{print $1}')
    fi

    if [ ! -z "$running_pids" ]; then
        log_message "信息" "发现正在运行的同脚本实例，正在清理..."
        for pid in $running_pids; do
            if $KILL -0 "$pid" 2>/dev/null; then
                log_message "信息" "终止进程: $pid"
                $KILL "$pid" 2>/dev/null
                $SLEEP 1
            fi
        done
        log_message "信息" "同脚本进程清理完成"
    else
        log_message "信息" "没有发现其他运行的脚本实例。"
    fi
}

# 配置日志文件路径
LOG_FILE="/tmp/cloudflare-ddns.txt"

# 定义日志文件的最大大小
MAX_LOG_SIZE=1048576  # 默认设置为 1MB

# 检查和轮转日志文件
check_and_rotate_log() {
    if [ -f "$LOG_FILE" ]; then
        # 使用更通用的方式获取文件大小
        size=$(wc -c < "$LOG_FILE" 2>/dev/null)
        if [ $? -eq 0 ] && [ $size -gt $MAX_LOG_SIZE ]; then
            log_message "信息" "日志文件大小($size 字节)超过限制($MAX_LOG_SIZE 字节)，正在重建日志文件"
            cat /dev/null > "$LOG_FILE"
            log_message "信息" "日志文件已重建"
        fi
    fi
}

# 日志函数
log_message() {
    level="$1"
    message="$2"
    # 确保日志目录存在
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    # 如果日志文件不存在则创建
    touch "$LOG_FILE" 2>/dev/null
    # 检查并在必要时轮转日志
    check_and_rotate_log
    # 追加日志消息
    echo "$($DATE '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LOG_FILE"
    echo "[$level] $message"
}

# 参数检查和处理
if [ "$#" -lt 2 ]; then
    echo "用法: $0 <完整域名> <API_TOKEN>"
    echo "或者: $0 <完整域名> '' <邮箱> <API_KEY>"
    echo "示例: $0 mail.example.com TOKEN"
    echo "      $0 mail.example.com '' user@example.com API_KEY"
    exit 1
fi

# 解析完整域名
FULL_DOMAIN="$1"
API_TOKEN="$2"
EMAIL="$3"
API_KEY="$4"

# 验证域名格式并拆分为主机名和域名
if ! echo "$FULL_DOMAIN" | $GREP -qE '^([a-zA-Z0-9_-]+\.)*[a-zA-Z0-9_-]+\.[a-zA-Z]{2,}$'; then
    echo "错误: 无效的域名格式: $FULL_DOMAIN"
    exit 1
fi

# 获取最后两段作为主域名
DOMAIN=$(echo "$FULL_DOMAIN" | $AWK -F'.' '{printf "%s.%s", $(NF-1), $NF}')

# 获取主域名之前的所有部分作为子域名
if [ "$FULL_DOMAIN" = "$DOMAIN" ]; then
    HOST="@"
else
    HOST=$(echo "$FULL_DOMAIN" | $SED "s/\.$DOMAIN\$//")
fi

# 验证认证参数
if [ -z "$API_TOKEN" ] && ([ -z "$EMAIL" ] || [ -z "$API_KEY" ]); then
    echo "错误: 必须提供 API Token 或者 邮箱+API Key"
    exit 1
fi

# 运行健康检查
if ! health_check; then
    log_message "错误" "健康检查失败，退出程序"
    exit 1
fi

# 设置认证头
set_auth_headers() {
    if [ ! -z "$API_TOKEN" ]; then
        # 直接存储认证头值，不包含引号
        AUTH_HEADER="Authorization: Bearer $API_TOKEN"
        log_message "信息" "使用 API Token 认证"
        return 0
    elif [ ! -z "$EMAIL" ] && [ ! -z "$API_KEY" ]; then
        # 直接存储认证头值，不包含引号
        AUTH_HEADER_EMAIL="X-Auth-Email: $EMAIL"
        AUTH_HEADER_KEY="X-Auth-Key: $API_KEY"
        log_message "信息" "使用邮箱/API Key 认证"
        return 0
    else
        handle_error $E_AUTH "必须提供 API Token 或 邮箱+API Key"
        return 1
    fi
}

# 获取当前公网IP
get_current_ip() {
    ip=""
    
    # 尝试从 ip.3322.net 获取IP
    if [ -z "$ip" ]; then
        ip=$(wget -qO- "http://ip.3322.net" | $GREP -E -o '([0-9]+\.){3}[0-9]+' | head -n1)
        if [ ! -z "$ip" ]; then
            log_message "信息" "从 ip.3322.net 获取到IP: $ip"
        else
            log_message "警告" "从 ip.3322.net 获取IP失败，尝试下一个源"
            sleep 1
        fi
    fi
    
    # 尝试从 ifconfig.me 获取IP
    if [ -z "$ip" ]; then
        ip=$(wget -qO- "http://ifconfig.me/ip" | $GREP -E -o '([0-9]+\.){3}[0-9]+' | head -n1)
        if [ ! -z "$ip" ]; then
            log_message "信息" "从 ifconfig.me 获取到IP: $ip"
        else
            log_message "警告" "从 ifconfig.me 获取IP失败，尝试下一个源"
            sleep 1
        fi
    fi
    
    # 最后从 ident.me 获取IP
    if [ -z "$ip" ]; then
        ip=$(wget -qO- "http://ident.me" | $GREP -E -o '([0-9]+\.){3}[0-9]+' | head -n1)
        if [ ! -z "$ip" ]; then
            log_message "信息" "从 ident.me 获取到IP: $ip"
        else
            log_message "警告" "从 ident.me 获取IP失败"
            sleep 1
        fi
    fi
    
    if [ ! -z "$ip" ]; then
        CURRENT_IP="$ip"
        log_message "信息" "成功获取到当前IP: $CURRENT_IP"
        return 0
    fi
    
    handle_error $E_NETWORK "无法从任何源获取当前IP地址"
    return 1
}

# 获取Zone ID
get_zone_id() {
    local retry=1
    while [ $retry -le 2 ]; do
        response=""
        log_message "调试" "开始获取Zone ID..."
        
        if [ ! -z "$API_TOKEN" ]; then
            log_message "调试" "使用API Token发起请求..."
            response=$(curl_with_timeout "$API_ZONES_URL" \
                -H "Content-Type: application/json" \
                -H "$AUTH_HEADER" \
                -k -v 2>&1)
        else
            log_message "调试" "使用Email/API Key发起请求..."
            response=$(curl_with_timeout "$API_ZONES_URL" \
                -H "Content-Type: application/json" \
                -H "$AUTH_HEADER_EMAIL" \
                -H "$AUTH_HEADER_KEY" \
                -k -v 2>&1)
        fi
        
        # 调试的时候使用
        # log_message "调试" "API响应: $response"
        
        if [ $? -ne 0 ]; then
            log_message "警告" "请求失败，HTTP状态码: $?"
            retry=$((retry + 1))
            continue
        fi
        
        # 使用更精确的方式提取Zone ID
        ZONE_ID=$(echo "$response" | $GREP -o '"id":"[^"]*","name":"'$DOMAIN'"' | $GREP -o '"id":"[^"]*"' | $CUT -d'"' -f4)
        
        if [ ! -z "$ZONE_ID" ]; then
            log_message "信息" "获取到Zone ID: $ZONE_ID"
            return 0
        fi
        
        log_message "警告" "获取Zone ID失败，第 $retry 次尝试（共2次）"
        
        # 调试的时候使用
        # log_message "调试" "完整响应内容: $response"
        
        retry=$((retry + 1))
        sleep 3
    done
    
    handle_error $E_API "无法获取域名 $DOMAIN 的Zone ID（已重试2次）"
    return 1
}

# 处理重复DNS记录
handle_duplicate_records() {
    local response=""
    local dns_records_url=$(get_dns_records_url "$ZONE_ID")"?type=A&name=$FULL_DOMAIN"

    if [ ! -z "$API_TOKEN" ]; then
        local records_response=$(curl_with_timeout "$dns_records_url" \
            -H "Content-Type: application/json" \
            -H "$AUTH_HEADER")
    else
        local records_response=$(curl_with_timeout "$dns_records_url" \
            -H "Content-Type: application/json" \
            -H "$AUTH_HEADER_EMAIL" \
            -H "$AUTH_HEADER_KEY")
    fi
    
    local record_count=$(echo "$records_response" | $GREP -o '"id":"[^"]*"' | wc -l)
    
    if [ "$record_count" -gt 1 ]; then
        log_message "警告" "发现 $record_count 个重复的 $FULL_DOMAIN 记录，正在清理..."
        
        # 保留最新的记录，删除其他记录
        local record_ids=$(echo "$records_response" | $GREP -o '"id":"[^"]*"' | cut -d'"' -f4)
        local latest_id=$(echo "$record_ids" | head -n1)
        
        for id in $record_ids; do
            if [ "$id" != "$latest_id" ]; then
                if [ ! -z "$API_TOKEN" ]; then
                    local delete_response=$(curl_with_timeout "$(get_dns_record_url "$ZONE_ID" "$id")" \
                        -H "Content-Type: application/json" \
                        -H "$AUTH_HEADER" \
                        -X DELETE)
                else
                    local delete_response=$(curl_with_timeout "$(get_dns_record_url "$ZONE_ID" "$id")" \
                        -H "Content-Type: application/json" \
                        -H "$AUTH_HEADER_EMAIL" \
                        -H "$AUTH_HEADER_KEY" \
                        -X DELETE)
                fi
                log_message "信息" "已删除重复记录: $id"
            fi
        done
    fi
}

# 获取当前DNS记录
get_dns_record() {
    local response=""
    local dns_records_url=$(get_dns_records_url "$ZONE_ID")"?type=A&name=$FULL_DOMAIN"

    if [ ! -z "$API_TOKEN" ]; then
        response=$(curl_with_timeout "$dns_records_url" \
            -H "Content-Type: application/json" \
            -H "$AUTH_HEADER")
    else
        response=$(curl_with_timeout "$dns_records_url" \
            -H "Content-Type: application/json" \
            -H "$AUTH_HEADER_EMAIL" \
            -H "$AUTH_HEADER_KEY")
    fi
    
    # 处理重复记录
    handle_duplicate_records
    
    # 重新获取记录（确保获取清理后的记录）
    if [ ! -z "$API_TOKEN" ]; then
        response=$(curl_with_timeout "$dns_records_url" \
            -H "Content-Type: application/json" \
            -H "$AUTH_HEADER")
    else
        response=$(curl_with_timeout "$dns_records_url" \
            -H "Content-Type: application/json" \
            -H "$AUTH_HEADER_EMAIL" \
            -H "$AUTH_HEADER_KEY")
    fi
    
    RECORD_ID=$(echo "$response" | $GREP -o '"id":"[^"]*"' | head -n1 | cut -d'"' -f4)
    RECORD_IP=$(echo "$response" | $GREP -o '"content":"[^"]*"' | head -n1 | cut -d'"' -f4)
    
    if [ ! -z "$RECORD_ID" ]; then
        log_message "信息" "现有记录ID: $RECORD_ID"
        log_message "信息" "现有记录IP: $RECORD_IP"
    fi
}

# 更新DNS记录
update_dns_record() {
    local retry=1
    while [ $retry -le 2 ]; do
        if [ -z "$RECORD_ID" ]; then
            log_message "信息" "正在创建新的DNS记录..."
            local response=""
            if [ ! -z "$API_TOKEN" ]; then
                response=$(curl_with_timeout "$(get_dns_records_url "$ZONE_ID")" \
                    -H "Content-Type: application/json" \
                    -H "$AUTH_HEADER" \
                    --data "{\"type\":\"A\",\"name\":\"$HOST\",\"content\":\"$CURRENT_IP\",\"ttl\":1,\"proxied\":false}")
            else
                response=$(curl_with_timeout "$(get_dns_records_url "$ZONE_ID")" \
                    -H "Content-Type: application/json" \
                    -H "$AUTH_HEADER_EMAIL" \
                    -H "$AUTH_HEADER_KEY" \
                    --data "{\"type\":\"A\",\"name\":\"$HOST\",\"content\":\"$CURRENT_IP\",\"ttl\":1,\"proxied\":false}")
            fi
        else
            log_message "信息" "正在更新DNS记录..."
            local response=""
            if [ ! -z "$API_TOKEN" ]; then
                response=$(curl_with_timeout "$(get_dns_record_url "$ZONE_ID" "$RECORD_ID")" \
                    -H "Content-Type: application/json" \
                    -H "$AUTH_HEADER" \
                    -X PUT \
                    --data "{\"type\":\"A\",\"name\":\"$HOST\",\"content\":\"$CURRENT_IP\",\"ttl\":1,\"proxied\":false}")
            else
                response=$(curl_with_timeout "$(get_dns_record_url "$ZONE_ID" "$RECORD_ID")" \
                    -H "Content-Type: application/json" \
                    -H "$AUTH_HEADER_EMAIL" \
                    -H "$AUTH_HEADER_KEY" \
                    -X PUT \
                    --data "{\"type\":\"A\",\"name\":\"$HOST\",\"content\":\"$CURRENT_IP\",\"ttl\":1,\"proxied\":false}")
            fi
        fi
        
        if echo "$response" | $GREP -q '"success":true'; then
            log_message "信息" "DNS记录已成功更新为 $CURRENT_IP"
            return 0
        fi
        
        log_message "警告" "更新DNS记录失败，第 $retry 次尝试（共2次）"
        log_message "调试" "API响应: $response"
        retry=$((retry + 1))
        sleep 3
    done
    
    handle_error $E_API "更新DNS记录失败（已重试2次）"
    return 1
}

# 主程序执行流程
log_message "信息" "开始为 $FULL_DOMAIN 更新Cloudflare DDNS"
log_message "信息" "域名解析 - 主机记录: $HOST"
log_message "信息" "域名解析 - 主域名: $DOMAIN"

# 在主程序开始前检查和清理进程
check_and_clean_process

# 设置认证头
set_auth_headers || exit 1

# 获取当前IP
get_current_ip || exit 1

# 获取Zone ID
get_zone_id || exit 1

# 获取现有DNS记录
get_dns_record || exit 1

# 检查是否需要更新
if [ "$CURRENT_IP" = "$RECORD_IP" ]; then
    log_message "信息" "IP未发生变化，无需更新"
    exit 0
fi

# 更新DNS记录
update_dns_record || exit 1
