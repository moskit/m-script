#!/bin/bash

IPT=`which iptables`
[ "X$IPT" == "X" ] && echo "No iptables found" && exit 1
$IPT -X ACCT_IN
$IPT -X ACCT_OUT
$IPT -N ACCT_IN
$IPT -N ACCT_OUT

IFS1=$IFS
IFS='
'
for ip in `for i in 1 2 3 4; do nmap -sP 192.168.${i}0.0/24 | grep -v 192\.168\.${i}0\.1\); done | grep ^Host`; do
  ip="${ip#*(}"; ip="${ip%)*}"
  $IPT -I ACCT_IN -d $ip
  $IPT -I ACCT_OUT -s $ip
  echo $ip >> ips.`date +"%H.%M.%S"`
done





IFS=$IFS1
