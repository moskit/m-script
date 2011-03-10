#!/bin/bash

# Copyright (C) 2008-2011 Igor Simonov (me@igorsimonov.com)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

### This script is monitoring net traffic between the machine it is running on
### and other hosts in the same network
 
class=24  # means CIDR notation ( /${class} )

rcommand=${0##*/}
rpath=${0%/*}
#*/ (this is needed to fix vi syntax highlighting)

solve() {
bc << EOF
scale=2
${1}
EOF
}
declare -i threshold

NMAP=`which nmap 2>/dev/null`
[ "X$NMAP" == "X" ] && echo "Nmap not found. It's needed for this script to work, sorry" && exit 0
IPT=`which iptables 2>/dev/null`
[ "X$IPT" == "X" ] && echo "No iptables found" && exit 1
MAILX=`which mail 2>/dev/null`
IFCFG=`which ifconfig 2>/dev/null`

possible_options="ip if threshold"
necessary_options=""
[ "X$*" == "X" ] && echo "Can't run without options. Possible options are: ${possible_options}" && exit 1
for s_option in "${@}"
do
  found=0
  case ${s_option} in
  --*=*)
    s_optname=`expr "X$s_option" : 'X[^-]*-*\([^=]*\)'`  
    s_optarg=`expr "X$s_option" : 'X[^=]*=\(.*\)'` 
    ;;
  --*)
    s_optname=`expr "X$s_option" : 'X[^-]*-*\([^=]*\)'`    
    s_optarg='yes' 
    ;;
  *=*)
    echo "Wrong syntax: options must start with a double dash"
    exit 1
    ;;
  *)
    s_param=${s_option}
    s_optname=''
    s_optarg=''
    ;;
  esac
  for option in `echo $possible_options | sed 's/,//g'`; do 
    [ "X$s_optname" == "X$option" ] && eval "$option=${s_optarg}" && found=1
  done
  [ "X$s_option" == "X$s_param" ] && found=1
  if [[ found -ne 1 ]]; then 
    echo "Unknown option: $s_optname"
    exit 1
  fi
done
found=0

for option in `echo $necessary_options | sed 's/,//g'`; do
  [ "X$(eval echo \$$option)" == "X" ] && missing_options="${missing_options}, --${option}" && found=1
done
if [[ found -eq 1 ]]; then
  missing_options=${missing_options#*,}
  echo "Necessary options: ${missing_options} not found"
  exit 1
fi

if [ -n "$ip" ] && [ -f "$if" ] ; then
  echo "Either --ip or --if option should be used, not both"
  exit 0
fi

if [ -n "$threshold" ] ; then
  [[ $threshold =~ [A-Za-z.,] ]] && echo "Threshold must be an integer. Setting it to 0" && threshold=0
else
  threshold=0
fi

TMPDIR=/tmp/m_script
install -d $TMPDIR

ip=`echo "$ip" | sed 's|,| |g'`
if=`echo "$if" | sed 's|,| |g'`

$IPT -L ACCT_IN >/dev/null 2>&1
[[ $? -eq 1 ]] && $IPT -N ACCT_IN || $IPT -F ACCT_IN
$IPT -L ACCT_OUT >/dev/null 2>&1
[[ $? -eq 1 ]] && $IPT -N ACCT_OUT || $IPT -F ACCT_OUT

if [ -n "$ip" ] ; then
  for i in $ip ; do $NMAP -sP ${i%.*}.0/${class} -oG $TMPDIR/nmap.sp.${i} > /dev/null ; done
fi
if [ -n "$if" ] ; then
  [ "X$IFCFG" == "X" ] && echo "No ifconfig found" && exit 1
  for ifc in $if ; do
    i=`$IFCFG $ifc | sed '/inet\ /!d;s/.*r://;s/\ .*//'`
    $NMAP -n -sP ${i%.*}.0/${class} -oG $TMPDIR/nmap.sp.${i} > /dev/null
  done
fi
IFS1=$IFS
IFS='
'
[ -f $TMPDIR/ips.list ] && rm -f $TMPDIR/ips.list
for ipt in `cat $TMPDIR/nmap.sp.* | grep 'Status: Up' | grep ^Host | awk '{print $2}'`; do
  $IPT -I ACCT_IN -d $ipt
  $IPT -I ACCT_OUT -s $ipt
  echo $ipt >> $TMPDIR/ips.list
done
sleep 100
$IPT -L ACCT_OUT -x -n -v | tail -n +2 | awk '{print $7" "$2}' > ${TMPDIR}/ipt.out
$IPT -L ACCT_IN -x -n -v | tail -n +2 | awk '{print $8" "$2}' > ${TMPDIR}/ipt.in

for ip in `cat ${TMPDIR}/ips.list`; do
  trin=`cat ${TMPDIR}/ipt.in|grep "^$ip "`; trin="${trin#* }"; trin=`solve "$trin / 800000"`
  trout=`cat ${TMPDIR}/ipt.out|grep "^$ip "`; trout="${trout#* }"; trout=`solve "$trout / 800000"`
  if [[ `echo "( $trin - $threshold ) > 0" | bc` -eq 1  ]] || [[ `echo "( $trout - $threshold ) > 0" | bc` -eq 1 ]]; then
    echo "$ip   $trin Kbytes/sec  $trout Kbytes/sec" >> ${TMPDIR}/trafeaters.report
#    $NMAP $ip | grep -v ^Nmap | grep -v ^Starting | grep -v ^Interestin | grep -v ^Not | grep -v ^MAC | grep -v '^135/' | grep -v '^139/' | grep -v '^445/' >> ${TMPDIR}/trafeaters.report 2>&1
  fi
done


if [ `cat ${TMPDIR}/trafeaters.report 2>/dev/null | wc -l` -gt 0 ] ; then
  cat ${TMPDIR}/trafeaters.report >> ${rpath}/../monitoring.log && rm -f ${TMPDIR}/trafeaters.report
  for MLINE in `cat ${rpath}/../mail.alert.list|grep -v ^$|grep -v ^#|grep -v ^[[:space:]]*#|awk '{print $1}'`
  do
    cat ${TMPDIR}/trafeaters.report | ${MAILX} -s "Server $(hostname -f) traffic consumers" ${MLINE}
  done
else
  echo "No traffic eaters at the moment" >> ${rpath}/../monitoring.log
fi

rm -f ${TMPDIR}/ips.* ${TMPDIR}/ipt.in ${TMPDIR}/ipt.out $TMPDIR/nmap.sp.* 2>/dev/null
IFS=$IFS1
