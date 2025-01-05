#!/bin/sh

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
