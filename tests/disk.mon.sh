#!/usr/bin/env bash
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


# bc workaround to make it work with floating point numbers
solve() {
bc << EOF
scale=2
${1}
EOF
}

rcommand=${0##*/}
rpath=${0%/*}
#*/ (this is needed to fix vi syntax highlighting)
timeindexnow=`cat /tmp/m_script/timeindex`
lasttimeindex=`cat /tmp/m_script/lasttimeindex`
diffsec=`expr $timeindexnow - $lasttimeindex 2>/dev/null` || diffsec=1

source ${rpath}/../conf/mon.conf

if [ "X$SQLITE3" == "X1" ] && [ "X${1}" == "XSQL" ]; then
  alltables=`sqlite3 ${rpath}/../sysdata ".tables"`
fi

echo ""
echo "Disks usage:"
echo "------------"
df -m | grep -v shm | grep -v tmpfs | grep -v udev | grep -v "^Filesystem" > /tmp/m_script/disk.tmp
printf "\tDisk\t\t\t\tMountpoint\t\t\tUsage\n\n"
while read LINE
do
  if [ -n "${LONGLINE}" ]
  then
    LINE="${LONGLINE} ${LINE}"
    LONGLINE=""
  fi
  # Sometimes df breaks a line, if it is much longer than 80 symbols
  if [ x$(echo $LINE | awk '{ print $6}') == "x" ] && [ -z ${LONGLINE} ]
  then
    LONGLINE="${LINE}"
    continue
  fi
  disk=$(echo $LINE | awk '{ print $1}')
  mpoint=$(echo $LINE | awk '{ print $6}')
  used=$(echo $LINE | awk '{ print $5}' | sed 's@\%@@')
  x1="$(echo "$used >= $DISK_WARN_1" | bc)"
  x2="$(echo "$used >= $DISK_WARN_2" | bc)"
  x3="$(echo "$used >= $DISK_WARN_3" | bc)"
  warnind='(OK) '
  [ "$x1" == "1" ] && warnind=' <*> '
  [ "$x2" == "1" ] && warnind='<**> '
  [ "$x3" == "1" ] && warnind='<***>'
  echo "${used}" >> /tmp/m_script/diskusage 
  printf "$warnind\t$disk"
  m=`expr length $disk`
  l=`expr 32 - $m`
  if [ $l -lt 1 ] ; then
    printf " "
  else
    for ((n=1; n <= $l; n++)); do printf " "; done
  fi
  printf "$mpoint"
  m=`expr length $mpoint`
  l=`expr 32 - $m`
  if [ $l -lt 1 ] ; then
    printf " "
  else
    for ((n=1; n <= $l; n++)); do printf " "; done
  fi
  printf "$used%%\n"
  if [ "X$SQLITE3" == "X1" ] && [ "X${1}" == "XSQL" ]; then
    diskname=${disk##*/}
    tablefound=`for dbtable in $alltables ; do [ "X$dbtable" == "X$diskname" ] && echo "yes" ; done`
    [ -n "$tablefound" ] || sqlite3 ${rpath}/../sysdata "create table $diskname(timeindex integer primary key, diskusage real, diskreads real, diskwrites real, drspeed real, dwspeed real)"
    unset tablefound
    [[ `sqlite3 ${rpath}/../sysdata "select count(*) from $diskname where timeindex='$timeindexnow'"` -eq 0 ]] && sqlite3 ${rpath}/../sysdata "insert into $diskname (timeindex) values ('$timeindexnow')"
    sqlite3 ${rpath}/../sysdata "update $diskname set diskusage='${used}' where timeindex='$timeindexnow'"
  fi
## Discovering what this disk really is
  echo $disk >> /tmp/m_script/disk.tmp.ext
  linkedto=`readlink $disk 2>/dev/null`
  if [ -n "$linkedto" ] ; then
    echo "Disk $disk is a symlink to $linkedto" >> /tmp/m_script/disk.tmp.discovered
    echo "/dev/$linkedto" >> /tmp/m_script/disk.tmp.ext
  fi
  slaves=`ls /sys/class/block/${disk##*/}/slaves 2>/dev/null`
  if [ -n "$slaves" ] ; then
    echo "Disk $disk is a logical volume built upon $slaves" | sed 's|\n| and |g' >> /tmp/m_script/disk.tmp.discovered
    for sldisk in $slaves ; do echo "/dev/$sldisk" >> /tmp/m_script/disk.tmp.ext ; done
  fi
done < /tmp/m_script/disk.tmp
echo
cat /tmp/m_script/disk.tmp.discovered 2>/dev/null
echo
echo "Average disk I/O speed:"
echo "-----------------------"
echo
echo "    Disk                  Overall, Mbytes/sec             Current, Mbytes/sec"
echo
VMSTAT=`which vmstat 2>/dev/null`
if [ "X${VMSTAT}" != "X" ]; then
  DISKSTAT="$VMSTAT -d"
fi
if [ "X${DISKSTAT}" != "X" ]; then
  $DISKSTAT >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Couldn't get disk stats"
    exit 0
  fi
  df | grep '^\/dev\/' | awk '{ print $1 }' > /tmp/m_script/disk.tmp
  cat /proc/swaps | grep '^\/dev\/' | awk '{ print $1 }' >> /tmp/m_script/disk.tmp
  disks=""
  while read LINE; do
    diskexists=0
    disk=${LINE##*/}
    for d in ${disks}; do
      if [ "X${d}" == "X${disk}" ]; then
        diskexists=1
      fi
    done

    if [ $diskexists -eq 0 ]; then
      disks="$disk ${disks}"
      dr=$($DISKSTAT | grep "^${disk}" | awk '{ print $4 }')
      drtime=$($DISKSTAT | grep "^${disk}" | awk '{ print $5 }')
      
      if [[ $drtime -gt 100 ]]; then
        drspeed=`solve "($dr / 2048) / ($drtime / 1000)"`
      else
        drspeed=0
      fi
      replinerd=`printf "/dev/${disk} read:"`
      m=`expr length $disk`
      l=`expr 20 - $m`
      for ((n=1; n <= $l; n++)); do replinerd=`printf "$replinerd "`; done
      replinerd=`printf "${replinerd}${drspeed}"`
      echo "${drspeed}" >> /tmp/m_script/diskiord
      dw=$($DISKSTAT | grep "^${disk}" | awk '{ print $8 }')
      dwtime=$($DISKSTAT | grep "^${disk}" | awk '{ print $9 }')
      if [[ $dwtime -gt 100 ]]; then
        dwspeed=`solve "($dw / 2048) / ($dwtime / 1000)"`
      else
        dwspeed=0
      fi
      replinerw=`printf "/dev/${disk} write:"`
      m=`expr length $disk`
      l=`expr 20 - $m`
      for ((n=1; n <= $l; n++)); do replinerw=`printf "$replinerw "`; done
      replinerw=`printf "${replinerw}${dwspeed}"`
      echo "${dwspeed}" >> /tmp/m_script/diskiowr
    fi

    if [ "X$SQLITE3" == "X1" ] && [ "X${1}" == "XSQL" ]; then
    
      diskname=${disk##*/}
      
      tablefound=`for dbtable in $alltables ; do [ "X$dbtable" == "X$diskname" ] && echo "yes" ; done`
      [ -n "$tablefound" ] || sqlite3 ${rpath}/../sysdata "create table $diskname(timeindex integer primary key, diskusage real, diskreads real, diskwrites real, drspeed real, dwspeed real)"
      unset tablefound
      [[ `sqlite3 ${rpath}/../sysdata "select count(*) from $diskname where timeindex='$timeindexnow'"` -eq 0 ]] && sqlite3 ${rpath}/../sysdata "insert into $diskname (timeindex) values ('$timeindexnow')"
      
      diskreads=`solve "($dr / 2048)"`
      diskreadslast=`sqlite3 ${rpath}/../sysdata "select diskreads from $diskname where timeindex='$lasttimeindex'"`
      drspeed=`solve "($diskreads - $diskreadslast) / $diffsec"`
      replinerd=`printf "$replinerd                    $drspeed\n"`
      
      diskwrites=`solve "($dw / 2048)"`
      diskwriteslast=`sqlite3 ${rpath}/../sysdata "select diskwrites from $diskname where timeindex='$lasttimeindex'"`
      dwspeed=`solve "($diskwrites - $diskwriteslast) / $diffsec"`
      replinerw=`printf "$replinerw                    $dwspeed\n"`
      
      sqlite3 ${rpath}/../sysdata "update $diskname set diskusage='${used}', diskreads='${diskreads}', drspeed='${drspeed}', diskwrites='${diskwrites}', dwspeed='${dwspeed}' where timeindex='$timeindexnow'"
      
    fi
    echo "$replinerd"
    echo "$replinerw"
  done < /tmp/m_script/disk.tmp.ext

fi

if [ "X$SQLITE3" == "X1" ] && [ "X${1}" == "XSQL" ]; then
  disksnum=`cat /tmp/m_script/diskusage | wc -l`
  diskusage=0
  if [ -f /tmp/m_script/diskusage ]; then
    while read LINE; do
      diskusage=`solve "$diskusage + $LINE"`
    done < /tmp/m_script/diskusage
    diskusage=`solve "$diskusage / $disksnum"`
  fi
  diskiord=0
  if [ -f /tmp/m_script/diskiord ]; then
    disksnum=`cat /tmp/m_script/diskiord | wc -l`
    while read LINE; do
      diskiord=`solve "$diskiord + $LINE"`
    done < /tmp/m_script/diskiord
    diskiord=`solve "$diskiord / $disksnum"`
  fi
  diskiowr=0
  if [ -f /tmp/m_script/diskiowr ]; then
    disksnum=`cat /tmp/m_script/diskiowr | wc -l`
    while read LINE; do
      diskiowr=`solve "$diskiowr + $LINE"`
    done < /tmp/m_script/diskiowr
    diskiowr=`solve "$diskiowr / $disksnum"`
  fi

  sqlite3 ${rpath}/../sysdata "update sysdata set diskusage='${diskusage}', diskiord='${diskiord}', diskiowr='${diskiowr}' where timeindex='$timeindexnow'"
fi
rm -f /tmp/m_script/disk.tmp.* >/dev/null 2>&1
rm -f /tmp/m_script/diskiowr /tmp/m_script/diskiord /tmp/m_script/diskusage >/dev/null 2>&1
