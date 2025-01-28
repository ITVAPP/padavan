对性能调校做了多处修改和优化，仅测试了 JCG-AC860M （因为只有这款机器），其它机器可以复制 trunk/configs/templates/JCG-AC860M.config 的设置到你机器对应的配置文件 （风险自担）。

配置带以下主要插件（针对性的对各项插件脚本进行了调整和适配）：

1、科学上网 （支持 Shadowsocks、ShadowsocksR 、Vmess、Vless、Trojan，支持 v2ray-plugin）

2、Frpc 内网穿透 （客户端版本 V41）

3、包含 msd_lite，用于IPTV组播转单播

4、包含 FTP 服务器，用于文件传输

5、包含 USB 打印机服务

6、自己写的的蜜罐防火墙脚本、设备流量统计脚本、Cloudflare Ddns 更新IP解析脚本，并在后台做了网页支持，其它固件作者使用请加说明出处，谢谢


默认管理地址 192.168.168.1

默认管理账号和密码 admin

默认WIFI密码：1234567890

本固件适合养老不折腾的人使用，登陆后台后建议使用路由器的默认设置
