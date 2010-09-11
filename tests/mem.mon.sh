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

FREE=`which free`
PS=`which ps`
UPTIME=`which uptime`
VMSTAT=`which vmstat`
rcommand=${0##*/}
rpath=${0%/*}
#*/ (this is needed to fix vi syntax highlighting)
timeindexnow=`cat /tmp/m_script/timeindex`
source ${rpath}/../mon.conf
ruptime=`$UPTIME`
if $(echo $ruptime | grep -E "min|day" >/dev/null); then
  x=$(echo $ruptime | sed 's/,//g' | awk '{print $3 " " $4}')
else
  x=$(echo $ruptime | sed 's/,//g' | awk '{print $3 " (hh:mm)"}')
fi
ruptime="$x"
if [ `echo ${ruptime} | grep -c 'hh'` -eq 1 ]
then
  dbuptime=0
else
  dbuptime=`echo ${ruptime} | awk '{print $1}'`
fi
rusedram="$($FREE -to | grep Mem: | awk '{ print $3 }')"
musedram=`solve "$rusedram / 1024"`
rfreeram="$($FREE -to | grep Mem: | awk '{ print $4 }')"
mfreeram=`solve "$rfreeram / 1024"`
ractiveram=`cat /proc/meminfo | grep "^Active:" | awk '{ print $2}'`
mactiveram=`solve "$ractiveram / 1024"`
rtotalram="$($FREE -to | grep Mem: | awk '{ print $2 }')"
mtotalram=`solve "$rtotalram / 1024"`
rusedswap="$($FREE -to | grep Swap: | awk '{ print $3 }')"
musedswap=`solve "$rusedswap / 1024"`
rfreeswap="$($FREE -to | grep Swap: | awk '{ print $4 }')"
mfreeswap=`solve "$rfreeswap / 1024"`
rtotalswap="$($FREE -to | grep Swap: | awk '{ print $2 }')"
mtotalswap=`solve "$rtotalswap / 1024"`
rtotalmemfree="$($FREE -to | grep Total: | awk '{ print $4 }')"
mtotalmemfree=`solve "$rtotalmemfree / 1024"`
rtotalprocess="$($PS axue | grep -vE "^USER|grep|ps" | wc -l)"

rload="$($UPTIME | awk -F'average: ' '{ print $2}')"
x="$(echo $rload | sed s/,//g | awk '{ print $2}')"
rloadavg="$(echo $rload | sed s/,//g | awk '{ print $3}')"
y1="$(echo "$x >= $LOAD_WARN_1" | bc)"
y2="$(echo "$x >= $LOAD_WARN_2" | bc)"
y3="$(echo "$x >= $LOAD_WARN_3" | bc)"
echo ""
echo "System status:"
echo "--------------"
printf "Uptime:\t\t\t\t$ruptime\n"
printf "Load average:\t\t\t$rload\n"
printf "Total running processes:\t$rtotalprocess\n"
echo "$rfs"
echo "RAM/Swap status:"
echo "----------------"
printf "Total RAM:\t\t${mtotalram} MB\n"
printf "Active RAM:\t\t${mactiveram} MB\n"
printf "Used RAM:\t\t${musedram} MB\n" 
printf "Free RAM:\t\t${mfreeram} MB\n"
printf "Used Swap:\t\t${musedswap} MB\n"
printf "Free Swap:\t\t${mfreeswap} MB\n"
printf "Total Swap:\t\t${mtotalswap} MB\n"
echo "----------------"
echo ""
warnind='(OK) '
[ "$y1" == "1" ] && warnind=' <*> '
[ "$y2" == "1" ] && warnind='<**> '
[ "$y3" == "1" ] && warnind='<***>'
echo "${warnind} Average load is $x"

totalmemused=`solve "($rusedram + $rusedswap) / ($rtotalram + $rtotalswap) * 100"`
totalramused=`solve "$ractiveram / $rtotalram * 100"`

y1="$(echo "$totalmemused >= $MEM_WARN_1" | bc)"
y2="$(echo "$totalmemused >= $MEM_WARN_2" | bc)"
y3="$(echo "$totalmemused >= $MEM_WARN_3" | bc)"

warnind='(OK) '
[ "$y1" == "1" ] && warnind=' <*> '
[ "$y2" == "1" ] && warnind='<**> '
[ "$y3" == "1" ] && warnind='<***>'
echo "${warnind} Free system memory is ${mtotalmemfree} MB, ${totalmemused}% used"

y1="$(echo "$totalramused >= $RAM_WARN_1" | bc)"
y2="$(echo "$totalramused >= $RAM_WARN_2" | bc)"
y3="$(echo "$totalramused >= $RAM_WARN_3" | bc)"

warnind='(OK) '
[ "$y1" == "1" ] && warnind=' <*> '
[ "$y2" == "1" ] && warnind='<**> '
[ "$y3" == "1" ] && warnind='<***>'
echo "${warnind} Active memory is ${mactiveram} MB, ${totalramused}% of total RAM"
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
        thr=`cat /proc/acpi/processor/$cpu/throttling | grep '\*' | awk '{ print $2}' | sed "s|%$||" | sed "s|^0||"`
        thrt=`solve "$thrt + $thr"`
        if [ "X${thr}" == "X0" ]; then
          warnind='(OK) '
        else
          warnind='<***>'
        fi
        echo "${warnind} $cpu frequency is scaled down by ${thr} %"
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
  sqlite3 ${rpath}/../sysdata "update sysdata set totalram=$rtotalram, freeram=$rfreeram, activeram=$ractiveram, totalswap=$rtotalswap, freeswap=$rfreeswap, uptime='${dbuptime}', loadavg=$rloadavg, procnum=$rtotalprocess, cpuusage=$cpuusage, cpufscale='${thrt}', cputemp='${tmprt}' where timeindex='$timeindexnow'"
fi
