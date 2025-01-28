#!/bin/sh

result=0
mtd_part_name="Storage"
mtd_part_dev="/dev/mtdblock5"
mtd_part_size=65536
dir_storage="/etc/storage"
slk="/tmp/.storage_locked"
tmp="/tmp/storage.tar"
tbz="${tmp}.bz2"
hsh="/tmp/hashes/storage_md5"

func_get_mtd()
{
	local mtd_part mtd_char mtd_idx mtd_hex
	mtd_part=`cat /proc/mtd | grep \"$mtd_part_name\"`
	mtd_char=`echo $mtd_part | cut -d':' -f1`
	mtd_hex=`echo $mtd_part | cut -d' ' -f2`
	mtd_idx=`echo $mtd_char | cut -c4-5`
	if [ -n "$mtd_idx" ] && [ $mtd_idx -ge 4 ] ; then
		mtd_part_dev="/dev/mtdblock${mtd_idx}"
		mtd_part_size=`echo $((0x$mtd_hex))`
	else
		logger -t "Storage" "Cannot find MTD partition: $mtd_part_name"
		exit 1
	fi
}

func_mdir()
{
	[ ! -d "$dir_storage" ] && mkdir -p -m 755 $dir_storage
}

func_stop_apps()
{
	killall -q rstats
	[ $? -eq 0 ] && sleep 1
}

func_start_apps()
{
	/sbin/rstats
}

func_load()
{
	local fsz

	bzcat $mtd_part_dev > $tmp 2>/dev/null
	fsz=`stat -c %s $tmp 2>/dev/null`
	if [ -n "$fsz" ] && [ $fsz -gt 0 ] ; then
		md5sum $tmp > $hsh
		tar xf $tmp -C $dir_storage 2>/dev/null
	else
		result=1
		rm -f $hsh
		logger -t "Storage load" "Invalid storage data in MTD partition: $mtd_part_dev"
	fi
	rm -f $tmp
	rm -f $slk
}

func_tarb()
{
	rm -f $tmp
	cd $dir_storage
	find * -print0 | xargs -0 touch -c -h -t 201001010000.00
	find * ! -type d -print0 | sort -z | xargs -0 tar -cf $tmp 2>/dev/null
	cd - >>/dev/null
	if [ ! -f "$tmp" ] ; then
		logger -t "Storage" "Cannot create tarball file: $tmp"
		exit 1
	fi
}

func_save()
{
	local fsz

	logger -t "Storage save" "Save storage files to MTD partition \"$mtd_part_dev\""
	echo "Save storage files to MTD partition \"$mtd_part_dev\""
	rm -f $tbz
	md5sum -c -s $hsh 2>/dev/null
	if [ $? -eq 0 ] ; then
		echo "Storage hash is not changed, skip write to MTD partition. Exit."
		rm -f $tmp
		return 0
	fi
	md5sum $tmp > $hsh
	bzip2 -9 $tmp 2>/dev/null
	fsz=`stat -c %s $tbz 2>/dev/null`
	if [ -n "$fsz" ] && [ $fsz -ge 16 ] && [ $fsz -le $mtd_part_size ] ; then
		mtd_write write $tbz $mtd_part_name
		if [ $? -eq 0 ] ; then
			echo "Done."
			logger -t "Storage save" "Done."
		else
			result=1
			echo "Error! MTD write FAILED"
			logger -t "Storage save" "Error write to MTD partition: $mtd_part_dev"
		fi
	else
		result=1
		echo "Error! Invalid storage final data size: $fsz"
		logger -t "Storage save" "Invalid storage final data size: $fsz"
	fi
	rm -f $tmp
	rm -f $tbz
}

func_backup()
{
	rm -f $tbz
	bzip2 -9 $tmp 2>/dev/null
	if [ $? -ne 0 ] ; then
		result=1
		logger -t "Storage backup" "Cannot create BZ2 file!"
	fi
	rm -f $tmp
}

func_restore()
{
	local fsz tmp_storage

	[ ! -f "$tbz" ] && exit 1

	fsz=`stat -c %s $tbz 2>/dev/null`
	if [ -z "$fsz" ] || [ $fsz -lt 16 ] || [ $fsz -gt $mtd_part_size ] ; then
		result=1
		rm -f $tbz
		logger -t "Storage restore" "Invalid BZ2 file size: $fsz"
		return 1
	fi

	tmp_storage="/tmp/storage"
	rm -rf $tmp_storage
	mkdir -p -m 755 $tmp_storage
	tar xjf $tbz -C $tmp_storage 2>/dev/null
	if [ $? -ne 0 ] ; then
		result=1
		rm -f $tbz
		rm -rf $tmp_storage
		logger -t "Storage restore" "Unable to extract BZ2 file: $tbz"
		return 1
	fi
	if [ ! -f "$tmp_storage/start_script.sh" ] ; then
		result=1
		rm -f $tbz
		rm -rf $tmp_storage
		logger -t "Storage restore" "Invalid content of BZ2 file: $tbz"
		return 1
	fi

	func_stop_apps

	rm -f $slk
	rm -f $tbz
	rm -rf $dir_storage
	mkdir -p -m 755 $dir_storage
	cp -rf $tmp_storage /etc
	rm -rf $tmp_storage

	func_start_apps
}

func_erase()
{
	mtd_write erase $mtd_part_name
	if [ $? -eq 0 ] ; then
		rm -f $hsh
		rm -rf $dir_storage
		mkdir -p -m 755 $dir_storage
		touch "$slk"
	else
		result=1
	fi
}

func_reset()
{
	rm -f $slk
	rm -rf $dir_storage
	mkdir -p -m 755 $dir_storage
}

func_fill()
{
	dir_httpssl="$dir_storage/https"
	dir_dnsmasq="$dir_storage/dnsmasq"
	dir_ovpnsvr="$dir_storage/openvpn/server"
	dir_ovpncli="$dir_storage/openvpn/client"
	dir_sswan="$dir_storage/strongswan"
	dir_sswan_crt="$dir_sswan/ipsec.d"
	dir_inadyn="$dir_storage/inadyn"
	dir_crond="$dir_storage/cron/crontabs"
	dir_wlan="$dir_storage/wlan"
	dir_chnroute="$dir_storage/chinadns"
	#dir_gfwlist="$dir_storage/gfwlist"

	script_start="$dir_storage/start_script.sh"
	script_started="$dir_storage/started_script.sh"
	script_shutd="$dir_storage/shutdown_script.sh"
	script_postf="$dir_storage/post_iptables_script.sh"
	script_postw="$dir_storage/post_wan_script.sh"
	script_inets="$dir_storage/inet_state_script.sh"
	script_vpnsc="$dir_storage/vpns_client_script.sh"
	script_vpncs="$dir_storage/vpnc_server_script.sh"
	script_ezbtn="$dir_storage/ez_buttons_script.sh"

	user_hosts="$dir_dnsmasq/hosts"
	user_dnsmasq_conf="$dir_dnsmasq/dnsmasq.conf"
	user_dnsmasq_servers="$dir_dnsmasq/dnsmasq.servers"
	user_dhcp_conf="$dir_dnsmasq/dhcp.conf"
	user_ovpnsvr_conf="$dir_ovpnsvr/server.conf"
	user_ovpncli_conf="$dir_ovpncli/client.conf"
	user_inadyn_conf="$dir_inadyn/inadyn.conf"
	user_sswan_conf="$dir_sswan/strongswan.conf"
	user_sswan_ipsec_conf="$dir_sswan/ipsec.conf"
	user_sswan_secrets="$dir_sswan/ipsec.secrets"
	
	chnroute_file="/etc_ro/chnroute.bz2"
	#gfwlist_conf_file="/etc_ro/gfwlist.bz2"

	# create crond dir
	[ ! -d "$dir_crond" ] && mkdir -p -m 730 "$dir_crond"

	# create https dir
	[ ! -d "$dir_httpssl" ] && mkdir -p -m 700 "$dir_httpssl"

	# create chnroute.txt
	if [ ! -d "$dir_chnroute" ] ; then
		if [ -f "$chnroute_file" ]; then
			mkdir -p "$dir_chnroute" && tar jxf "$chnroute_file" -C "$dir_chnroute"
		fi
	fi

	# create gfwlist
	#if [ ! -d "$dir_gfwlist" ] ; then
		#if [ -f "$gfwlist_conf_file" ]; then	
			#mkdir -p "$dir_gfwlist" && tar jxf "$gfwlist_conf_file" -C "$dir_gfwlist"
		#fi
	#fi

	# create start script
	if [ ! -f "$script_start" ] ; then
		reset_ss.sh -a
	fi

	# create started script
	if [ ! -f "$script_started" ] ; then
		cat > "$script_started" <<EOF
#!/bin/sh

# CPU多核利用率优化
/usr/bin/rps-rfs-ops.sh set

# 优化设置
echo 0 > /proc/sys/net/netfilter/nf_conntrack_checksum
echo 1 > /proc/sys/net/ipv4/tcp_syncookies
echo 1 > /proc/sys/net/ipv4/route/gc_elasticity
echo 3 > /proc/sys/net/ipv4/tcp_fastopen
echo 1 > /proc/sys/net/netfilter/nf_conntrack_tcp_be_liberal
echo 1 > /proc/sys/net/netfilter/nf_conntrack_tcp_loose
echo 18 > /proc/sys/net/ipv4/route/gc_interval
echo 18 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_syn_sent
echo 18 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_syn_recv
echo 580 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established
echo 18 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_fin_wait
echo 18 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_close_wait
echo 18 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_last_ack
echo 18 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_time_wait
echo 18 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_close
echo 18 > /proc/sys/net/netfilter/nf_conntrack_udp_timeout
echo 58 > /proc/sys/net/netfilter/nf_conntrack_udp_timeout_stream
echo 18 > /proc/sys/net/netfilter/nf_conntrack_icmp_timeout
echo 580 > /proc/sys/net/netfilter/nf_conntrack_generic_timeout
echo 580 > /proc/sys/net/ipv4/netfilter/ip_conntrack_tcp_timeout_established
echo 18 > /proc/sys/net/ipv4/netfilter/ip_conntrack_udp_timeout
echo 88 > /proc/sys/net/ipv4/netfilter/ip_conntrack_udp_timeout_stream
echo 18 > /proc/sys/net/netfilter/nf_conntrack_log_invalid
echo 168888 > /proc/sys/net/netfilter/nf_conntrack_max
echo 4096 65536 16777216 > /proc/sys/net/core/rmem_max
echo 4096 65536 16777216 > /proc/sys/net/core/wmem_max
echo 4096 65536 16777216 > /proc/sys/net/ipv4/tcp_rmem
echo 4096 65536 16777216 > /proc/sys/net/ipv4/tcp_wmem

### drop caches
sync && echo 3 > /proc/sys/vm/drop_caches

### 流量统计脚本，使用本功能还需在 系统管理 - 服务 - 调度任务 (Crontab) 中取消 traffic 前的 # 号注释
nice -n 18 /usr/bin/traffic.sh

# 蜜罐防火墙规则，将访问 20,21,22,23,3389 端口的人列入黑名单，启用就去掉规则前的 # 号
# nice -n 18 /usr/bin/flytrap.sh

EOF
		chmod 755 "$script_started"
	fi

	# create shutdown script
	if [ ! -f "$script_shutd" ] ; then
		cat > "$script_shutd" <<EOF
#!/bin/sh

### Custom user script
### \$1 - action (0: reboot, 1: halt, 2: power-off)

EOF
		chmod 755 "$script_shutd"
	fi

	# create post-iptables script
	if [ ! -f "$script_postf" ] ; then
		cat > "$script_postf" <<EOF
#!/bin/sh

# 解决 PMTU 黑洞
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
ip6tables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# 开放IPv6端口
ip6tables -F
ip6tables -X
ip6tables -P INPUT ACCEPT
ip6tables -P OUTPUT ACCEPT
ip6tables -P FORWARD ACCEPT

EOF
		chmod 755 "$script_postf"
	fi

	# create post-wan script
	if [ ! -f "$script_postw" ] ; then
		cat > "$script_postw" <<EOF
#!/bin/sh

# 启用 cloudflare ddns 更新IP解析， 使用 API Token 方式 或 使用 Email + API Key 方式
# nice -n 18 /usr/bin/cloudflare_ddns.sh abc.aa.com xxxxxxxxxxxxxxxx
# nice -n 18 /usr/bin/cloudflare_ddns.sh abc.aa.com '' user@example.com xxxxxxxxxxxxxxxx

EOF
		chmod 755 "$script_postw"
	fi

	# create inet-state script
	if [ ! -f "$script_inets" ] ; then
		cat > "$script_inets" <<EOF
#!/bin/sh

logger -t "di" "Internet state: \$1, elapsed time: \$2s."

# CPU多核利用率优化
/usr/bin/rps-rfs-ops.sh set

# 启用 cloudflare ddns 更新IP解析， 使用 API Token 方式 或 使用 Email + API Key 方式
# nice -n 18 /usr/bin/cloudflare_ddns.sh abc.aa.com xxxxxxxxxxxxxxxx
# nice -n 18 /usr/bin/cloudflare_ddns.sh abc.aa.com '' user@example.com xxxxxxxxxxxxxxxx

EOF
		chmod 755 "$script_inets"
	fi

	# create vpn server action script
	if [ ! -f "$script_vpnsc" ] ; then
		cat > "$script_vpnsc" <<EOF
#!/bin/sh

### Custom user script

peer_if="\$2"
peer_ip="\$4"
peer_name="\$5"

### example: add static route to private LAN subnet behind a remote peer

func_ipup()
{
#  if [ "\$peer_name" == "dmitry" ] ; then
#    route add -net 192.168.5.0 netmask 255.255.255.0 dev \$peer_if
#  elif [ "\$peer_name" == "victoria" ] ; then
#    route add -net 192.168.8.0 netmask 255.255.255.0 dev \$peer_if
#  fi
   return 0
}

func_ipdown()
{
#  if [ "\$peer_name" == "dmitry" ] ; then
#    route del -net 192.168.5.0 netmask 255.255.255.0 dev \$peer_if
#  elif [ "\$peer_name" == "victoria" ] ; then
#    route del -net 192.168.8.0 netmask 255.255.255.0 dev \$peer_if
#  fi
   return 0
}

case "\$1" in
up)
  func_ipup
  ;;
down)
  func_ipdown
  ;;
esac

EOF
		chmod 755 "$script_vpnsc"
	fi

	# create vpn client action script
	if [ ! -f "$script_vpncs" ] ; then
		cat > "$script_vpncs" <<EOF
#!/bin/sh

### Custom user script

# private LAN subnet behind a remote server (example)
peer_lan="192.168.168.0"
peer_msk="255.255.255.0"

### example: add static route to private LAN subnet behind a remote server

func_ipup()
{
#  route add -net \$peer_lan netmask \$peer_msk gw \$IPREMOTE dev \$IFNAME
   return 0
}

func_ipdown()
{
#  route del -net \$peer_lan netmask \$peer_msk gw \$IPREMOTE dev \$IFNAME
   return 0
}

logger -t vpnc-script "\$IFNAME \$1"

case "\$1" in
up)
  func_ipup
  ;;
down)
  func_ipdown
  ;;
esac

EOF
		chmod 755 "$script_vpncs"
	fi

	# create Ez-Buttons script
	if [ ! -f "$script_ezbtn" ] ; then
		cat > "$script_ezbtn" <<EOF
#!/bin/sh

### Custom user script
### Called on WPS or FN button pressed
### \$1 - button param

[ -x /opt/bin/on_wps.sh ] && /opt/bin/on_wps.sh \$1 &

EOF
		chmod 755 "$script_ezbtn"
	fi

	# 创建用户 dnsmasq 配置目录
	[ ! -d "$dir_dnsmasq" ] && mkdir -p -m 755 "$dir_dnsmasq"

	# 如果 dnsmasq.conf 或 hosts 存在于存储目录，则移动到 dnsmasq 目录
	for i in dnsmasq.conf hosts ; do
		[ -f "$dir_storage/$i" ] && mv -n "$dir_storage/$i" "$dir_dnsmasq"
	done

	# 如果用户自定义的 dnsmasq 配置文件不存在，则创建它
	if [ ! -f "$user_dnsmasq_conf" ] ; then
		cat > "$user_dnsmasq_conf" <<EOF
# 自定义 dnsmasq 配置文件

### 启用并发 DNS 查询，提升查询效率
all-servers
# 限制 DNS 转发的并发数量
dns-forward-max=168
### 设置 DNS 缓存大小
cache-size=888
### 不转发没有域名部分的查询请求
domain-needed
### 阻止私有地址范围的查询转发
bogus-priv
### 禁用 /etc/resolv.conf 中的上游 DNS，仅使用此配置
no-resolv
### Web Proxy 自动发现 (WPAD)
dhcp-option=252,"\n"
### 本地域名解析，仅从 hosts 或 DHCP 查询
local=/router/localdomain/

EOF
	if [ -f /usr/bin/vlmcsd ]; then
		cat >> "$user_dnsmasq_conf" <<EOF
### vlmcsd related
srv-host=_vlmcs._tcp,my.router,1688,0,100

EOF
	fi

	if [ -f /usr/bin/wing ]; then
		cat >> "$user_dnsmasq_conf" <<EOF
# Custom domains to gfwlist
#gfwlist=mit.edu

EOF
	fi

	if [ -d $dir_gfwlist ]; then
		cat >> "$user_dnsmasq_conf" <<EOF
### gfwlist related (resolve by port 5353)
#min-cache-ttl=3600
#conf-dir=/etc/storage/gfwlist

EOF
	fi
		chmod 644 "$user_dnsmasq_conf"
	fi

	# create user dns servers
	if [ ! -f "$user_dnsmasq_servers" ] ; then
		cat > "$user_dnsmasq_servers" <<EOF
# Custom user servers file for dnsmasq
#server=/mit.ru/izmuroma.ru/10.25.11.30

# IPv4 DNS服务器
server=1.1.1.1
server=8.8.8.8
server=119.29.29.29
server=223.6.6.6
server=180.76.76.76

# IPv6 DNS服务器
server=2400:3200::1
server=2402:4e00::
server=2400:da00::6666
server=2606:4700:4700::1111
server=2001:4860:4860::8888

EOF
		chmod 644 "$user_dnsmasq_servers"
	fi

	# create user dns dhcp_conf
	if [ ! -f "$user_dhcp_conf" ] ; then
		cat > "$user_dhcp_conf" <<EOF
# Custom user hosts for dhcp_hostsfile
# Example:
#6C:96:CF:E0:95:55,192.168.1.10,iMac

EOF
		chmod 644 "$user_dhcp_conf"
	fi

	# create user inadyn.conf"
	[ ! -d "$dir_inadyn" ] && mkdir -p -m 755 "$dir_inadyn"
	if [ ! -f "$user_inadyn_conf" ] ; then
		cat > "$user_inadyn_conf" <<EOF
# Custom user conf file for inadyn DDNS client

### Example for twoDNS.de:
#system custom@http_srv_basic_auth

EOF
		chmod 644 "$user_inadyn_conf"
	fi

	# create user hosts
	if [ ! -f "$user_hosts" ] ; then
		cat > "$user_hosts" <<EOF
# Custom user hosts file
# Example:
# 192.168.1.100		Boo

EOF
		chmod 644 "$user_hosts"
	fi

	# create user AP confs
	[ ! -d "$dir_wlan" ] && mkdir -p -m 755 "$dir_wlan"
	if [ ! -f "$dir_wlan/AP.dat" ] ; then
		cat > "$dir_wlan/AP.dat" <<EOF
# Custom user AP conf file

EOF
		chmod 644 "$dir_wlan/AP.dat"
	fi

	if [ ! -f "$dir_wlan/AP_5G.dat" ] ; then
		cat > "$dir_wlan/AP_5G.dat" <<EOF
# Custom user AP conf file

EOF
		chmod 644 "$dir_wlan/AP_5G.dat"
	fi

	# create openvpn files
	if [ -x /usr/sbin/openvpn ] ; then
		[ ! -d "$dir_ovpncli" ] && mkdir -p -m 700 "$dir_ovpncli"
		[ ! -d "$dir_ovpnsvr" ] && mkdir -p -m 700 "$dir_ovpnsvr"
		dir_ovpn="$dir_storage/openvpn"
		for i in ca.crt dh1024.pem server.crt server.key server.conf ta.key ; do
			[ -f "$dir_ovpn/$i" ] && mv -n "$dir_ovpn/$i" "$dir_ovpnsvr"
		done
		if [ ! -f "$user_ovpnsvr_conf" ] ; then
			cat > "$user_ovpnsvr_conf" <<EOF
# Custom user conf file for OpenVPN server

### Max clients limit
max-clients 10

### Internally route client-to-client traffic
client-to-client

### Allow clients with duplicate "Common Name"
;duplicate-cn

### Legacy LZO adaptive compression
;comp-lzo adaptive
;push "comp-lzo adaptive"

### Keepalive and timeout
keepalive 10 60

### Process priority level (0..19)
nice 3

### Syslog verbose level
verb 0
mute 10

EOF
			chmod 644 "$user_ovpnsvr_conf"
		fi

		if [ ! -f "$user_ovpncli_conf" ] ; then
			cat > "$user_ovpncli_conf" <<EOF
# Custom user conf file for OpenVPN client

### If your server certificates with the nsCertType field set to "server"
remote-cert-tls server

### Process priority level (0..19)
nice 0

### Syslog verbose level
verb 0
mute 10

EOF
			chmod 644 "$user_ovpncli_conf"
		fi
	fi

	# create strongswan files
	if [ -x /usr/sbin/ipsec ] ; then
		[ ! -d "$dir_sswan" ] && mkdir -p -m 700 "$dir_sswan"
		[ ! -d "$dir_sswan_crt" ] && mkdir -p -m 700 "$dir_sswan_crt"
		[ ! -d "$dir_sswan_crt/cacerts" ] && mkdir -p -m 700 "$dir_sswan_crt/cacerts"
		[ ! -d "$dir_sswan_crt/certs" ] && mkdir -p -m 700 "$dir_sswan_crt/certs"
		[ ! -d "$dir_sswan_crt/private" ] && mkdir -p -m 700 "$dir_sswan_crt/private"

		if [ ! -f "$user_sswan_conf" ] ; then
			cat > "$user_sswan_conf" <<EOF
### strongswan.conf - user strongswan configuration file

EOF
			chmod 644 "$user_sswan_conf"
		fi
		if [ ! -f "$user_sswan_ipsec_conf" ] ; then
			cat > "$user_sswan_ipsec_conf" <<EOF
### ipsec.conf - user strongswan IPsec configuration file

EOF
			chmod 644 "$user_sswan_ipsec_conf"
		fi
		if [ ! -f "$user_sswan_secrets" ] ; then
			cat > "$user_sswan_secrets" <<EOF
### ipsec.secrets - user strongswan IPsec secrets file

EOF
			chmod 644 "$user_sswan_secrets"
		fi
	fi
}

case "$1" in
load)
	func_get_mtd
	func_mdir
	func_load
	;;
save)
	[ -f "$slk" ] && exit 1
	func_get_mtd
	func_mdir
	func_tarb
	func_save
	;;
backup)
	func_mdir
	func_tarb
	func_backup
	;;
restore)
	func_get_mtd
	func_restore
	;;
erase)
	func_get_mtd
	func_erase
	;;
reset)
	func_stop_apps
	func_reset
	func_fill
	func_start_apps
	;;
fill)
	func_mdir
	func_fill
	;;
*)
	echo "Usage: $0 {load|save|backup|restore|erase|reset|fill}"
	exit 1
	;;
esac

exit $result
