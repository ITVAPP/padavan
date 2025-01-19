#!/bin/sh

# 获取相关配置
frpc_enable=$(nvram get frpc_enable)
frps_enable=$(nvram get frps_enable)
http_username=$(nvram get http_username)

# 检查frp状态并启动
check_frp() {
    if check_net; then
        # 检查frpc
        if [ "$frpc_enable" = "1" ] && [ -z "$(pidof frpc)" ]; then
            logger -t "frp" "检测到frpc未运行，启动中..."
            frp_start
        fi
        # 检查frps
        if [ "$frps_enable" = "1" ] && [ -z "$(pidof frps)" ]; then
            logger -t "frp" "检测到frps未运行，启动中..."
            frp_start
        fi
    else
        logger -t "frp" "网络检测失败，尝试启动frp"
    fi
}

# 检查网络连接
check_net() {
    /bin/ping -c 3 -w 5 223.5.5.5 >/dev/null 2>&1
    return $?
}

# 启动frp服务
frp_start() {
    /etc/storage/frp_script.sh

    # 更新crontab，仅添加一次
    cron_file="/etc/storage/cron/crontabs/$http_username"
    grep -q '/usr/bin/frp.sh C' "$cron_file" || cat >> "$cron_file" <<EOF
*/1 * * * * /bin/sh /usr/bin/frp.sh C >/dev/null 2>&1
EOF

    # 启动日志
    [ -n "$(pidof frpc)" ] && logger -t "frp" "frpc启动成功"
    [ -n "$(pidof frps)" ] && logger -t "frp" "frps启动成功"
}

# 停止frp服务
frp_close() {
    # 停止frpc
    if [ "$frpc_enable" = "0" ] && [ -n "$(pidof frpc)" ]; then
        killall -9 frpc frp_script.sh
        [ -z "$(pidof frpc)" ] && logger -t "frp" "已停止frpc"
    fi

    # 停止frps
    if [ "$frps_enable" = "0" ] && [ -n "$(pidof frps)" ]; then
        killall -9 frps frp_script.sh
        [ -z "$(pidof frps)" ] && logger -t "frp" "已停止frps"
    fi

    # 移除定时任务
    if [ "$frpc_enable" = "0" ] && [ "$frps_enable" = "0" ]; then
        sed -i '/frp/d' "/etc/storage/cron/crontabs/$http_username"
    fi
}

# 根据命令执行相应操作
case $1 in
    start)
        frp_start
        ;;
    stop)
        frp_close
        ;;
    C)
        check_frp
        ;;
    *)
        echo "Usage: $0 {start|stop|C}"
        ;;
esac
