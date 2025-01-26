#!/bin/sh
killall frpc
mkdir -p /tmp/frp
# frpc 客户端版本 V35.1
# 请自行修改 token 用于对客户端连接进行身份验证
# IP查询： http://119.29.29.29/d?dn=github.com

cat > "/tmp/frp/frpc.ini" <<-\EOF
# ==========客户端配置：==========
[common]
# IPv6必须用方括号括起来，例如"[::1]:80"、"[ipv6-host]:http"或"[ipv6-host%zone]:80"
# 对于单个"server_addr"字段，不需要方括号，如"server_addr = ::"
server_addr = "0.0.0.0"

# 连接端口
server_port = "7000"

# 特权模式密钥，客户端连接到FRPS服务端的验证密钥
token = "12345678"

# 用于连接服务器的通信协议, 支持tcp、kcp和websocket
protocol = tcp

# 预先建立的连接数量，默认值为0
pool_count = 8

# 是否启用tcp流复用，默认为true，必须与frps保持一致
tcp_mux = true

# 你的代理名称将被更改为{user}.{proxy}
user = Aicss_Net

# 决定首次登录失败时是否退出程序，否则将持续尝试重新登录frps
login_fail_exit = true

[Aicss_web01]
# 特权模式
privilege_mode = true

# 穿透协议类型，可选：tcp，udp，http，https，stcp，xtcp
type = http

# 要解析到的内网IP
local_ip = 192.168.168.102

# 本地监听端口，通常有ssh端口22，远程桌面3389等等
local_port = 80

# 如果frps的域名是Aicss.Net，那么可以通过URL http://web01.Aicss.Net 访问
subdomain = web01

# 你自己的域名
custom_domains = web01.yourdomain.com

# 对传输内容进行压缩
use_encryption = true

# 将 frpc 与 frps 之间的通信内容加密传输
use_compression = true

# ====================
EOF

#启动：
frpc_enable=`nvram get frpc_enable`
frpc_enable=${frpc_enable:-"0"}
if [ "$frpc_enable" = "1" ] ; then
    frpc -c /tmp/frp/frpc.ini 2>&1 &
fi
