#!/bin/sh
lanip=$1
defaultfile=$2
dicfile=$3
oc1=${lanip%%.*}
x=${lanip#*.*}
oc2=${x%%.*}
x=${x#*.*}
oc3=${x%%.*}
dhcpfrom=$oc1"."$oc2"."$oc3".100"
dhcpto=$oc1"."$oc2"."$oc3".238"
sed -i "s/\"192.168.168.1\"/\"$lanip\"/g" $defaultfile
sed -i "s/\"192.168.168.100\"/\"$dhcpfrom\"/g" $defaultfile
sed -i "s/\"192.168.168.238\"/\"$dhcpto\"/g" $defaultfile
sed -i "s/192.168.168.1/$lanip/" $dicfile
