#!/bin/bash

solve() {
bc << EOF
scale=2
${1}
EOF
}
PATH="/sbin:/usr/sbin:${PATH}"
rcommand=${0##*/}
rpath=${0%/*}
#*/ (this is needed to fix vi syntax highlighting)
source ${rpath}/../mon.conf

echo ""
echo "Memory eaters (process name and process owner):"
echo "-----------------------------------------------"

IFS1=$IFS
IFS='
'
ps aux | tail -n +2 > /tmp/m_script/ps.list
for LINE in `cat /tmp/m_script/ps.list | grep -v ^$`; do
  command=`echo "${LINE}" | awk '{print $11}'`
  virtual=`echo "${LINE}" | awk '{print $5}'`
  resident=`echo "${LINE}" | awk '{print $6}'`
  user=`echo "${LINE}" | awk '{print $1}'`
  echo "${command} ${user} ${resident} ${virtual}" >> /tmp/m_script/ps.list.reordered
done
for proc in `cat /tmp/m_script/ps.list.reordered | awk '{print $1" "$2}' | sort | uniq` ; do
  virtual=0
  resident=0
  procuser=`echo $proc | awk '{print $1" "$2}'`
  for thisproc in `cat /tmp/m_script/ps.list.reordered | grep "^${procuser}" 2>/dev/null` ; do
    VSZ=`echo $thisproc | awk '{print $4}'`
    RSS=`echo $thisproc | awk '{print $3}'`
#echo "=== $VSZ $RSS $virtual $resident ==="
    virtual=`solve "$virtual + ($VSZ / 1024)"`
    resident=`solve "$resident + ($RSS / 1024)"`
  done
  if [[ `echo "$resident > $MEM_RES_MIN"|bc` -eq 1 ]] ; then
    echo "<**> Process \"${procuser}\" is using ${resident}MB of RAM"
  fi
  if [[ `echo "$virtual > $MEM_VIR_MIN"|bc` -eq 1 ]] ; then
    echo "<**> Process \"${procuser}\" is using ${virtual}MB of virtual memory"
  fi
done
rm -f /tmp/m_script/ps.list*
IFS=$IFS1

### for cat in applications cpanel system dotDefender http mail mysql ; do suma=0; for a in `cat mem_usage.txt | grep "${cat}$" | awk '{print $3}'`; do suma=`echo "scale=2; $suma + $a" | bc`; done; sumb=0; for b in `cat mem_usage.txt | grep "${cat}$" | awk '{print $4}'`; do sumb=`echo "scale=2; $sumb + $b" | bc`; done; echo "${cat} $suma $sumb"; done > totals
