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


rcommand=${0##*/}
rpath=${0%/*}
#*/ (this is needed to fix vi syntax highlighting)
ports=`cat ${rpath}/../ports.list | grep -v '^#' | grep -v '^[:space:]*#'`
sockets=`cat ${rpath}/../sockets.list | grep -v '^#' | grep -v '^[:space:]*#'`
[ -x /bin/netstat ] && NETSTATCMD='/bin/netstat'
[ "X$NETSTATCMD" == "X" ] && NETSTATCMD=`which netstat`

if [ `uname` == "Linux" ]; then
  [ "X$NETSTATCMD" == "X" ] && echo "Netstat utility not found! Aborting.." && exit 1
  NETCONNS="${NETSTATCMD} -tuapn"
  SOCKCONNS="${NETSTATCMD} -xlpn"
fi

[ -x /bin/ping ] && PING='/bin/ping'
[ "X$PING" == "X" ] && PING=`which ping`

if [ `uname` == "Linux" ]; then
  ROUTE="${NETSTATCMD} -rn"
fi


source ${rpath}/../mon.conf

echo
echo "Services up and running:"
echo "----------------"
echo
echo "Name                Listening on                            Connections"
echo
${NETCONNS} | grep 'LISTEN' > /tmp/m_script/netstat.tmp
while read LINE
do
  portfound=0
  t=$(echo $LINE | awk '{ print $4 }')
  sname=$(echo $LINE | awk '{ print $7 }' | cut -d/ -f2 | cut -d: -f1)
  # now compare ports
  for i in ${ports}
  do
    if [ "X${i}" == "X${t}" ]
    then
      j=`expr "${i}" : '.*\(:[0-9]*\)'`
      ports=$(echo ${ports} | sed "s@${t}@@")
      printf "$sname"
      m=`expr length $sname`
      l=`expr 20 - $m`
      for ((n=1; n <= $l; n++)); do printf " "; done
      printf "${t}"
      # | sed 's|0.0.0.0:|port |g' | sed 's|127.0.0.1:|port |g' | sed 's|<\:\:\:>|port |g' | sed 's|\:\:\:|port |g'
      m=`expr length "${t}"`
      l=`expr 40 - $m`
      for ((n=1; n <= $l; n++)); do printf " "; done
      printf "`${NETCONNS} | grep \"${j}\" | grep 'ESTABLISHED' | wc -l`\n"
      portfound=1
      break
    fi
  done
[ $portfound -ne 1 ] && echo "<***> Service ${sname} listening on ${t} is not being monitored." | sed 's|0.0.0.0:|port |g' | sed 's|127.0.0.1:|port |g' | sed 's|<\:\:\:>|port |g' | sed 's|\:\:\:|port |g'
done < /tmp/m_script/netstat.tmp
if [ "X${ports}" != "X" ]
then
 echo "<***> There is no services listening on: ${ports}" | sed 's|0.0.0.0:|port |g' | sed 's|127.0.0.1:|port |g' | sed 's|<\:\:\:>|port |g' | sed 's|\:\:\:|port |g'
fi
echo
${SOCKCONNS} | grep STREAM > /tmp/m_script/netstat.tmp
#  | awk -F'STREAM' '{print $2}' | awk '{print $3}'
while read LINE
do
  socketfound=0
  t="${LINE##*[[:space:]]}"
  sname=$(echo $LINE | awk -F'STREAM' '{print $2}' | awk '{print $3}')
  sname=${sname#*/}
  # now compare sockets
  for i in ${sockets}
  do
    if [ "X${i}" == "X${t}" ]
    then
      sockets=$(echo ${sockets} | sed "s@${t}@@")
      printf "$sname"
      m=`expr length $sname`
      l=`expr 20 - $m`
      for ((n=1; n <= $l; n++)); do printf " "; done
      printf "${t}\n"
      portfound=1
      break
    fi
  done
done < /tmp/m_script/netstat.tmp
rm -f /tmp/m_script/netstat.tmp
if [ "X${sockets}" != "X" ]
then
 echo "<***> There is no services listening on unix sockets: ${sockets}"
fi
# End of netstat test

# Connectivity test
if [ "X$CONNTEST_IP" == "X" ]
then
  if [ "X$ROUTE" != "X" ]; then
    ${ROUTE} | grep 'G' | grep -v 'Flags' | awk '{print $2}' > /tmp/m_script/ping.tmp
  elif [ -f /etc/resolv.conf ]; then
    grep '^nameserver' /etc/resolv.conf | awk '{print $2}' > /tmp/m_script/ping.tmp
  else
    echo "Unable to get any IP from system to ping (tried: gateway, nameserver). Please provide IP address for ping test in mon.conf file"
  fi
  failedip=""
  pingedip=""
  while read LINE
  do
   [ "X${LINE}" == "X" ] || $PING -c1 $LINE >/dev/null
   if [ "$?" != "0" ] ; then
    failedip="${failedip} ${LINE}"
   else
    pingedip="yes"
   fi
  done < /tmp/m_script/ping.tmp
else
  for connip in ${CONNTEST_IP}
  do
    [ "X${connip}" == "X" ] || $PING -c1 ${connip} >/dev/null
    if [ "$?" != "0" ] ; then
      failedip="${failedip} ${LINE}"
    else
      pingedip="yes"
    fi
  done
fi

if [ "x$pingedip" == "xyes" ]; then
 echo ""
 echo 'Server is connected'
else
 echo '<***> Server is disconnected!'
 echo "<***> IP(s) ${failedip} unavailable"
fi

