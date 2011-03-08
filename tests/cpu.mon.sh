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
source ${rpath}/../mon.conf

$VMSTAT -n 1 6 | grep -v "^[a-z]" | grep -v "^\ [a-z]" | awk '{ print $13}' > /tmp/m_script/cpuusage
tail -n 5 /tmp/m_script/cpuusage > /tmp/m_script/cpuusage.1
mv /tmp/m_script/cpuusage.1 /tmp/m_script/cpuusage
cputestnum=`cat /tmp/m_script/cpuusage | wc -l`
cpuusage=0
while read LINE
do
  cpuusage=`solve "$cpuusage + $LINE"`
done < /tmp/m_script/cpuusage
cpuusage=`solve "$cpuusage / $cputestnum"`
y1="$(echo "$cpuusage >= $CPU_USAGE_1" | bc)"
y2="$(echo "$cpuusage >= $CPU_USAGE_2" | bc)"
y3="$(echo "$cpuusage >= $CPU_USAGE_3" | bc)"

warnind='(OK) '
[ "$y1" == "1" ] && warnind=' <*> '
[ "$y2" == "1" ] && warnind='<**> '
[ "$y3" == "1" ] && warnind='<***>'
echo "${warnind} Average CPU usage is ${cpuusage}"
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
        if [ "X`cat /proc/acpi/processor/$cpu/throttling | grep 'T0' | awk '{print $2}'`" == 'X100%' ] ; then isnormal=''; else isnormal='is scaled down by' ; fi
        thrstate=`cat /proc/acpi/processor/$cpu/throttling | grep '\*' | awk '{ print $1}'`
        thr=`cat /proc/acpi/processor/$cpu/throttling | grep '\*' | awk '{ print $2}' | sed "s|%$||" | sed "s|^0||"`
        thrt=`solve "$thrt + $thr"`
        if [ "X${thr}" == "X0" ]; then
          warnind='(OK) '
        else
          if [ "X${thr}" == "X100" ] && [ "X${thrstate}" == "XT0" ]; then
            warnind='(OK) '
          else
            warnind='<***>'
          fi
        fi
        echo "${warnind} $cpu frequency $isnormal ${thr} %"
      done
      thrt=`solve "$thrt / $cpunum"`
    fi
  fi
fi
if [ -d /proc/acpi/thermal_zone ]
then
  if [ `ls /proc/acpi/thermal_zone | wc -l` -ne 0 ]
  then
    temperature=`find /proc/acpi/thermal_zone -name temperature`
    if [ "X$temperature" != "X" ]
    then
      thrmnum=`ls /proc/acpi/thermal_zone | wc -l`
      tmprt=0
      for thrm in `ls /proc/acpi/thermal_zone`
      do
        tmpr=`cat /proc/acpi/thermal_zone/$thrm/temperature  | awk '{ print $2}'`
        tmprt=`solve "$tmprt + $tmpr"`
        y1="$(echo "$tmpr >= $CPU_TEMP_1" | bc)"
        y2="$(echo "$tmpr >= $CPU_TEMP_2" | bc)"
        y3="$(echo "$tmpr >= $CPU_TEMP_3" | bc)"

        warnind='(OK) '
        [ "$y1" == "1" ] && warnind=' <*> '
        [ "$y2" == "1" ] && warnind='<**> '
        [ "$y3" == "1" ] && warnind='<***>'
        echo "${warnind} The $thrm zone temperature is ${tmpr} Centigrade"
      done
      tmprt=`solve "$tmprt / $thrmnum"`
    fi
  fi
fi
if [ "X$SQLITE3" == "X1" ] && [ "X${1}" == "XSQL" ]
then
  sqlite3 ${rpath}/../sysdata "update sysdata set cpuusage=$cpuusage, cpufscale='${thrt}', cputemp='${tmprt}' where timeindex='$timeindexnow'"
fi
