#!/bin/sh
killall frpc
mkdir -p /tmp/frp
#启动frp功能后会运行以下脚本
#frp项目地址教程: https://github.com/fatedier/frp/blob/master/README_zh.md
#请自行修改 token 用于对客户端连接进行身份验证
# IP查询： http://119.29.29.29/d?dn=github.com

cat > "/tmp/frp/frpc.toml" <<-\EOF
# ==========客户端配置：==========
[common]
# 服务端需要 v0.53.0 版本或以上，因为本版本通过 SSH 隧道模式连接
# IPv6 的文字地址或主机名必须用方括号括起来，例如 "[::1]:80"、"[ipv6-host]:http" 或 "[ipv6-host%zone]:80"
# 对于单独的 "server_addr" 字段，不需要方括号，如 "server_addr = ::"
server_addr = 0.0.0.0
server_port = 7000

# 连接服务器等待完成的最大时间。默认值为 10 秒
dial_server_timeout = 10

# 活动网络连接的保活探测间隔。如果为负值，则禁用保活探测
dial_server_keepalive = 7200

# 是否在发送到 frps 的心跳中包含身份验证令牌。默认值为 false
authenticate_heartbeats = false

# 是否在发送到 frps 的新工作连接中包含身份验证令牌。默认值为 false
authenticate_new_work_conns = false

# 认证令牌
token = 12345678

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

[ssh]
# tcp | udp | http | https | stcp | xtcp，默认为 tcp
type = tcp
local_ip = 192.168.2.1
local_port = 22
# 限制此代理的带宽，单位为 KB 和 MB
bandwidth_limit = 1MB
# 在哪里限制带宽，可以是 'client' 或 'server'
bandwidth_limit_mode = client
# frps 监听的远程端口
remote_port = 6001
# frps 将为同一组中的代理进行负载均衡
group = test_group
# 组应具有相同的组密钥
group_key = 123456
# 为后端服务启用健康检查，支持 'tcp' 和 'http'
health_check_type = tcp
# 健康检查连接超时
health_check_timeout_s = 3
# 如果连续失败 3 次，代理将从 frps 中移除
health_check_max_failed = 3
# 每 10 秒进行一次健康检查
health_check_interval_s = 10

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
if [ "$frpc_enable" = "1" ] ; then
    frpc -c /tmp/frp/frpc.toml 2>&1 &
fi
