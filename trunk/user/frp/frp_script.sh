#!/bin/sh
killall frpc
mkdir -p /tmp/frp
#启动frp功能后会运行以下脚本
#请自行修改 token 用于对客户端连接进行身份验证
# IP查询： http://119.29.29.29/d?dn=github.com

cat > "/tmp/frp/frpc.toml" <<-\EOF
# ==========客户端配置：==========
[common]
# IPv6 的文字地址或主机名必须用方括号括起来，例如 "[::1]:80"、"[ipv6-host]:http" 或 "[ipv6-host%zone]:80"
# 对于单独的 "server_addr" 字段，不需要方括号，如 "server_addr = ::"
# 远端frp服务器ip或域名
server_addr = 0.0.0.0
server_port = 7000
# 认证令牌
token = 12345678
# 连接服务器等待完成的最大时间。默认值为 10 秒
dial_server_timeout = 10
# 活动网络连接的保活探测间隔。如果为负值，则禁用保活探测
dial_server_keepalive = 7200
# 是否在发送到 frps 的心跳中包含身份验证令牌。默认值为 false
authenticate_heartbeats = false
# 是否在发送到 frps 的新工作连接中包含身份验证令牌。默认值为 false
authenticate_new_work_conns = false
# 预先建立的连接数，默认值为零
pool_count = 8
# 是否使用 tcp 流复用，默认为 true，必须与 frps 相同
# tcp_mux = true
# 指定 tcp 复用的保活间隔
# 仅当 tcp_mux 为 true 时有效
# tcp_mux_keepalive_interval = 60
# 用于连接服务器的通信协议，支持 tcp、kcp、quic 和 websocket，默认为 tcp
protocol = tcp
# 如果 tls_enable 为 true，frpc 将通过 tls 连接 frps
tls_enable = true

[web01]
type = http
local_ip = 192.168.2.1
local_port = 80
use_encryption = false
use_compression = true
# 安全认证，如果未设置，可以不需要认证就访问
http_user = admin
http_pwd = admin
# 如果 frps 的域名是 frps.com，那么可以通过 web01.frps.com 访问
subdomain = web01
custom_domains = web01.yourdomain.com
# 向本地 http 服务发送 GET 请求 '/status'，当返回 2xx 响应码时，http 服务被认为是活着的
health_check_url = /status
health_check_interval_s = 10
health_check_max_failed = 3
health_check_timeout_s = 3
# ====================
EOF

#启动：
frpc_enable=`nvram get frpc_enable`
frpc_enable=${frpc_enable:-"0"}
if [ "$frpc_enable" = "1" ] ; then
    frpc -c /tmp/frp/frpc.toml 2>&1 &
fi
