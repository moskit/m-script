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

solve() {
bc << EOF
scale=2
${1}
EOF
}

VMSTAT=`which vmstat`
rcommand=${0##*/}
rpath=${0%/*}
#*/ (this is needed to fix vi syntax highlighting)
timeindexnow=`cat /tmp/m_script/timeindex`
source ${rpath}/../conf/mon.conf

## Not in mon.conf, not sure it is needed there
CPUUPERIOD=1
CPUUSAMPLES=5

$VMSTAT -n $CPUUPERIOD $CPUUSAMPLES | awk '{ print $13"|"$14"|"$16 }' | tail -5 > /tmp/m_script/cpuusage

usavg=0
syavg=0
waavg=0
while read LINE
do
  us=`echo $LINE | cut -d'|' -f1`
  sy=`echo $LINE | cut -d'|' -f2`
  wa=`echo $LINE | cut -d'|' -f3`
  usavg=`solve "$usavg + $us"`
  syavg=`solve "$syavg + $sy"`
  waavg=`solve "$waavg + $wa"`
done < /tmp/m_script/cpuusage
usavg=`solve "$usavg / $CPUUSAMPLES"`
syavg=`solve "$syavg / $CPUUSAMPLES"`
waavg=`solve "$waavg / $CPUUSAMPLES"`
cpuusage=`solve "$usavg + $syavg + $waavg"`
y1="$(echo "$cpuusage >= $CPU_USAGE_1" | bc)"
y2="$(echo "$cpuusage >= $CPU_USAGE_2" | bc)"
y3="$(echo "$cpuusage >= $CPU_USAGE_3" | bc)"

warnind='(OK) '
[ "$y1" == "1" ] && warnind=' <*> '
[ "$y2" == "1" ] && warnind='<**> '
[ "$y3" == "1" ] && warnind='<***>'
echo "${warnind} `expr $CPUUPERIOD \* $CPUUSAMPLES` sec average CPU usage is ${cpuusage}: system ${syavg}, user ${usavg}, wait ${waavg}"

### Throttle
# Old interface
if [ -d "/proc/acpi/processor" ]
then
  throttle=`find /proc/acpi/processor -name "throttling"`
  if [ "X$throttle" != "X" ]
  then
    if [ `cat $throttle | grep -c 'not supported'` -eq 0 ]
    then
      cpunum=`ls /proc/acpi/processor | wc -l`
      thrt=0
      for cpu in `ls /proc/acpi/processor`
      do
        if [ "X`cat /proc/acpi/processor/$cpu/throttling | grep 'T0:' | awk '{print $2}'`" == 'X100%' ] ; then isnormal=''; else isnormal=' scaled down by' ; fi
        thrstate=`cat /proc/acpi/processor/$cpu/throttling | grep '\*' | awk '{ print $1}' | sed 's_*__'`
        thr=`cat /proc/acpi/processor/$cpu/throttling | grep '\*' | awk '{ print $2}' | sed "s|%$||" | sed "s|^0||"`
        thrt=`solve "$thrt + $thr"`
        if [ "X${thr}" == "X0" ]; then
          warnind='(OK) '
        else
          if [ "X${thr}" == "X100" ] && [ "X${thrstate}" == "XT0:" ]; then
            warnind='(OK) '
          else
            warnind='<***>'
          fi
        fi
        echo "${warnind} $cpu frequency is$isnormal ${thr} %"
      done
      thrt=`solve "$thrt / $cpunum"`
    fi
  fi
fi
# New interface



if [ "X$SQLITE3" == "X1" ] && [ "X${1}" == "XSQL" ]
then
  sqlite3 ${rpath}/../sysdata "update sysdata set cpuusage=$cpuusage where timeindex='$timeindexnow'"
fi

