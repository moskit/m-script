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
PATH="/sbin:/usr/sbin:${PATH}"
rcommand=${0##*/}
rpath=${0%/*}
#*/ (this is needed to fix vi syntax highlighting)
source ${rpath}/../mon.conf
if [ "X$SQLITE3" != "X0" ] && [ "X${1}" == "XSQL" ]
then

netstatbin=`which netstat`
iptablesbin=`which iptables`
 
timeindexnow=`cat /tmp/m_script/timeindex`
lasttimeindex=`cat /tmp/m_script/lasttimeindex`

numconn=`${netstatbin} -tupn | grep 'ESTABLISHED' | wc -l`
binputlast=`sqlite3 ${rpath}/../sysdata "select input from sysdata where timeindex='$lasttimeindex'"`
boutputlast=`sqlite3 ${rpath}/../sysdata "select output from sysdata where timeindex='$lasttimeindex'"`

if [ "X${iptablesbin}" != "X" ] && [ "X${IPTABLES}" != "X0" ]; then
  ${iptablesbin} -L INPUT -v -x > /tmp/ipt.input.accept
  if [ `grep '^Chain' /tmp/ipt.input.accept | grep -c ' 0 bytes'` -eq 1 ]
  then
    declare -i b
    b=0
    while read LINE
    do
      if [ "X${LINE}" != "X" ] && [ `echo ${LINE} | grep -c '^Chain'` -eq 0 ] && [ `echo ${LINE} | grep -c 'ACCEPT'` -eq 1 ]
      then
        a=`echo ${LINE} | awk '{print $2}'`
        b+=`expr "$a" : '\([0-9]*\)'`
      fi
    done < /tmp/ipt.input.accept
    binput=$b
  else
    c=`grep '^Chain' /tmp/ipt.input.accept`
    binput=`expr "${c}" : '.*\(\ [0-9]*\ bytes\).*' | awk '{print $1}'`
  fi

  ${iptablesbin} -L OUTPUT -v -x > /tmp/ipt.output.accept
  if [ `grep '^Chain' /tmp/ipt.output.accept | grep -c ' 0 bytes'` -eq 1 ]
  then
    declare -i b
    b=0
    while read LINE
    do
      if [ "X${LINE}" != "X" ] && [ `echo ${LINE} | grep -c '^Chain'` -eq 0 ] && [ `echo ${LINE} | grep -c 'ACCEPT'` -eq 1 ]
      then
        a=`echo ${LINE} | awk '{print $2}'`
        b+=`expr "$a" : '\([0-9]*\)'`
      fi
    done < /tmp/ipt.output.accept
    boutput=$b
  else
    c=`grep '^Chain' /tmp/ipt.output.accept`
    boutput=`expr "${c}" : '.*\(\ [0-9]*\ bytes\).*' | awk '{print $1}'`
  fi

  diffsec=`expr $timeindexnow - $lasttimeindex 2>/dev/null` || diffsec=1

  [ "X$binputlast" == "X" ] && binputlast=$binput
  [ "X$boutputlast" == "X" ] && boutputlast=$boutput
  # Number 2.5 represents approximately average number of seconds in one
  # month divided by 1024 twice
  
  diffbwin=`solve "25 * ($binput - $binputlast) / ($diffsec * 10240)"`
  diffbwout=`solve "25 * ($boutput - $boutputlast) / ($diffsec * 10240)"`
else
  binput=0
  boutput=0
  diffbwin=0
  diffbwout=0
fi
sqlite3 ${rpath}/../sysdata "update sysdata set connections='$numconn', input='$binput', output='$boutput', bwidthin='$diffbwin', bwidthout='$diffbwout' where timeindex='$timeindexnow'"
echo ""
echo "Bandwidth:"
echo "----------"
printf "Total connections:\t\t$numconn\n"
printf "Input bandwidth:\t\t$diffbwin GB/month\n"
printf "Output bandwidth:\t\t$diffbwout GB/month\n"

fi

