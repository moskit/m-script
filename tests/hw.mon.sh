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

rcommand=${0##*/}
rpath=${0%/*}
#*/ (this is needed to fix vi syntax highlighting)
timeindexnow=`cat /tmp/m_script/timeindex`
source ${rpath}/../conf/mon.conf


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

