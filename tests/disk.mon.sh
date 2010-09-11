#!/usr/bin/env bash
# Copyright (C) 2008-2009 Igor Simonov (me@igorsimonov.com)
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

source ${rpath}/../mon.conf
echo ""
echo "Disks usage:"
echo "------------"
df -m | grep -v shm | grep -v tmpfs | grep -v udev | grep -v "^Filesystem" > /tmp/m_script/disk.tmp
printf "\tDisk\t\t\t\tMountpoint\t\t\tUsage\n\n"
while read LINE
do
  if [ -n ${LONGLINE} ]
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
  for ((n=1; n <= $l; n++)); do printf " "; done
  printf "$mpoint"
  m=`expr length $mpoint`
  l=`expr 32 - $m`
  for ((n=1; n <= $l; n++)); do printf " "; done
  printf "$used%%\n"
done < /tmp/m_script/disk.tmp
echo ""
echo "Average disk I/O speed:"
echo "-----------------------"
VMSTAT=`which vmstat`
if [ "X${VMSTAT}" != "X" ]
then
  DISKSTAT="$VMSTAT -d"
fi
if [ "X${DISKSTAT}" != "X" ]
then
  $VMSTAT -d >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Couldn't get disk stats"
    exit 0
  fi
  df | grep '^\/dev\/' | awk '{ print $1}' > /tmp/m_script/disk.tmp
  cat /proc/swaps | grep '^\/dev\/' | awk '{ print $1}' >> /tmp/m_script/disk.tmp
  disks=""
  while read LINE
  do
    diskexists=0
    disk=`basename ${LINE}`
    for d in ${disks}
    do
      if [ "X${d}" == "X${disk}" ]; then
        diskexists=1
      fi
    done
    if [ `$DISKSTAT | grep "^${disk}" | wc -l` -gt 0 ]
    then
      if [ $diskexists -eq 0 ]; then
        disks="$disk ${disks}"
        dr=$($DISKSTAT | grep "^${disk}" | awk '{ print $4}')
        drtime=$($DISKSTAT | grep "^${disk}" | awk '{ print $5}')
        if [ $drtime -ne 0 ]; then
          drspeed=`solve "($dr / 2048) / ($drtime / 1000)"`
          printf "/dev/${disk} read:"
          m=`expr length $disk`
          l=`expr 29 - $m`
          for ((n=1; n <= $l; n++)); do printf " "; done
          printf "${drspeed} Mbytes/sec\n"
          echo "${drspeed}" >> /tmp/m_script/diskiord
        fi
        dw=$($DISKSTAT | grep "^${disk}" | awk '{ print $8}')
        dwtime=$($DISKSTAT | grep "^${disk}" | awk '{ print $9}')
        if [ $dwtime -ne 0 ]; then
          dwspeed=`solve "($dw / 2048) / ($dwtime / 1000)"`
          printf "/dev/${disk} write:"
          m=`expr length $disk`
          l=`expr 28 - $m`
          for ((n=1; n <= $l; n++)); do printf " "; done
          printf "${dwspeed} Mbytes/sec\n"
          echo "${dwspeed}" >> /tmp/m_script/diskiowr
        fi
      fi
    else
      disklen=`expr $disk : '[a-z]*.*[a-z]'`
      disk1=`echo $disk | cut -c 1-$disklen`
      disklenbefore=`expr length $disk`
      disklenafter=`expr length $disk1`
      
      [ $disklenafter -lt $disklenbefore ] && echo ${disk1} >> /tmp/m_script/disk.tmp || echo "Couldn't get statistics for disk ${disk1}"
    fi
  done < /tmp/m_script/disk.tmp
  rm -f /tmp/m_script/disk.tmp
else
  echo "Disk I/O statistics is unavailable for this system"
fi
if [ "X$SQLITE3" == "X1" ] && [ "X${1}" == "XSQL" ]
then
  disksnum=`cat /tmp/m_script/diskusage | wc -l`
  diskusage=0
  if [ -f /tmp/m_script/diskusage ]; then
    while read LINE
    do
      diskusage=`solve "$diskusage + $LINE"`
    done < /tmp/m_script/diskusage
    diskusage=`solve "$diskusage / $disksnum"`
    diskiord=0
  fi
  if [ -f /tmp/m_script/diskiord ]; then
    disksnum=`cat /tmp/m_script/diskiord | wc -l`
    while read LINE
    do
      diskiord=`solve "$diskiord + $LINE"`
    done < /tmp/m_script/diskiord
    diskiord=`solve "$diskiord / $disksnum"`
    diskiowr=0
  fi
  if [ -f /tmp/m_script/diskiowr ]; then
    disksnum=`cat /tmp/m_script/diskiowr | wc -l`
    while read LINE
    do
      diskiowr=`solve "$diskiowr + $LINE"`
    done < /tmp/m_script/diskiowr
    diskiowr=`solve "$diskiowr / $disksnum"`
  fi
  sqlite3 ${rpath}/../sysdata "update sysdata set diskusage='${diskusage}', diskiord='${diskiord}', diskiowr='${diskiowr}' where timeindex='$timeindexnow'"
fi
rm -f /tmp/m_script/diskiowr /tmp/m_script/diskiord /tmp/m_script/diskusage >/dev/null 2>&1
