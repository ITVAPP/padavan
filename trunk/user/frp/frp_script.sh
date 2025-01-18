#!/bin/sh
killall frpc
mkdir -p /tmp/frp
#启动frp功能后会运行以下脚本
#请自行修改 token 用于对客户端连接进行身份验证
# IP查询： http://119.29.29.29/d?dn=github.com

cat > "/tmp/frp/frpc.toml" <<-\EOF
# ==========客户端配置：==========
[common]
# IPv6的字面地址或主机名必须用方括号括起来
# 例如"[::1]:80"、"[ipv6-host]:http"或"[ipv6-host%zone]:80"
# 对于单个"server_addr"字段，不需要方括号，如"server_addr = ::"
server_addr = 0.0.0.0
server_port = 7000
# 认证令牌
token = 12345678
# 用于连接服务器的通信协议, 支持tcp、kcp和websocket
protocol = tcp
# 连接服务器时等待连接完成的最大时间。默认值为18秒
# dial_server_timeout = 18
# 预先建立的连接数量，默认值为0
pool_count = 8
# 是否启用tcp流复用，默认为true，必须与frps保持一致
tcp_mux = true
# 指定tcp复用的保活间隔时间，仅在tcp_mux为true时有效
tcp_mux_keepalive_interval = 60
# 你的代理名称将被更改为{user}.{proxy}
user = Aicss_Net
# 决定首次登录失败时是否退出程序，否则将持续尝试重新登录frps
login_fail_exit = true
# 如果tls_enable为true，frpc将通过tls连接frps
tls_enable = true
# tls_cert_file = client.crt
# tls_key_file = client.key
# tls_trusted_ca_file = ca.crt
# tls_server_name = example.com
[web01]
type = http
local_ip = 127.0.0.1
local_port = 80
use_encryption = false
use_compression = true
# 如果frps的域名是Aicss.Net，那么可以通过URL http://web01.Aicss.Net访问
subdomain = web01
custom_domains = web01.yourdomain.com
# 带有"header_"前缀的参数将用于更新http请求头
header_X-From-Where = frp
health_check_type = http
# ====================
EOF

#启动：
frpc_enable=`nvram get frpc_enable`
frpc_enable=${frpc_enable:-"0"}
if [ "$frpc_enable" = "1" ] ; then
    frpc -c /tmp/frp/frpc.toml 2>&1 &
fi
