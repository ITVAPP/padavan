#!/bin/sh

script_start="/etc/storage/start_script.sh"

# create start script
cat > "$script_start" <<EOF
#!/bin/sh

### Custom user script for tuning router before start

########################################################
### tune linux kernel
########################################################
# backlog for UNIX sockets
echo 64       > /proc/sys/net/unix/max_dgram_qlen

# igmp
echo 30       > /proc/sys/net/ipv4/igmp_max_memberships

# arp
echo 1        > /proc/sys/net/ipv4/conf/all/arp_announce
echo 1        > /proc/sys/net/ipv4/conf/default/arp_announce

# neigh ipv4
echo 256      > /proc/sys/net/ipv4/neigh/default/gc_thresh1
echo 1024     > /proc/sys/net/ipv4/neigh/default/gc_thresh2
echo 2048     > /proc/sys/net/ipv4/neigh/default/gc_thresh3

# ipv6
if [ -d /proc/sys/net/ipv6 ] ; then
  echo 256    > /proc/sys/net/ipv6/neigh/default/gc_thresh1
  echo 1024   > /proc/sys/net/ipv6/neigh/default/gc_thresh2
  echo 2048   > /proc/sys/net/ipv6/neigh/default/gc_thresh3
  echo 16384  > /proc/sys/net/ipv6/route/max_size
fi

# reverse-path filter
echo 1        > /proc/sys/net/ipv4/conf/default/rp_filter
echo 1        > /proc/sys/net/ipv4/conf/eth2/rp_filter

# CPU IRQ
set_rps_rfs() {
    echo f >/proc/irq/11/smp_affinity
    echo f >/proc/irq/12/smp_affinity
    for device in $(ls /sys/class/net); do
        echo f >/sys/class/net/$device/queues/rx-0/rps_cpus
        echo 32768 >/sys/class/net/$device/queues/rx-0/rps_flow_cnt
    done
    echo 32768 >/proc/sys/net/core/rps_sock_flow_entries
}
get_rps_rfs() {
    cat /proc/irq/11/smp_affinity
    cat /proc/irq/12/smp_affinity
    for device in $(ls /sys/class/net); do
        printf "%-10s %-5s %-10s\n" "$device" "$(cat /sys/class/net/$device/queues/rx-0/rps_cpus)" "$(cat /sys/class/net/$device/queues/rx-0/rps_flow_cnt)"
    done
    cat /proc/sys/net/core/rps_sock_flow_entries
}
case $1 in
get)
    get_rps_rfs
    ;;
set)
    set_rps_rfs
    ;;
*)
    get_rps_rfs
    ;;
esac

# panic
echo 1        > /proc/sys/kernel/panic
echo 1        > /proc/sys/kernel/panic_on_oops
echo 0        > /proc/sys/vm/panic_on_oom

# 优化连接
echo 168888 > /proc/sys/net/netfilter/nf_conntrack_max
echo 18 > /proc/sys/vm/swappiness
echo 0 > /proc/sys/net/netfilter/nf_conntrack_checksum
echo 1 > /proc/sys/net/netfilter/nf_conntrack_tcp_be_liberal
echo 1 > /proc/sys/net/netfilter/nf_conntrack_tcp_loose
echo 1 > /proc/sys/net/ipv4/tcp_syncookies
echo 1 > /proc/sys/vm/overcommit_memory
echo 58 > /proc/sys/vm/dirty_background_ratio
echo 88 > /proc/sys/vm/dirty_ratio
echo 1 > /proc/sys/net/ipv4/route/gc_elasticity
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
echo 4096 65536 16777216 > /proc/sys/net/core/rmem_max
echo 4096 65536 16777216 > /proc/sys/net/core/wmem_max
echo 4096 65536 16777216 > /proc/sys/net/ipv4/tcp_rmem
echo 4096 65536 16777216 > /proc/sys/net/ipv4/tcp_wmem
echo 3 > /proc/sys/net/ipv4/tcp_fastopen
echo 8 > /proc/sys/net/netfilter/nf_conntrack_log_invalid

EOF
chmod 755 "$script_start"

if [ -z "$1" ] ; then
	$script_start
	mtd_storage.sh save
fi
