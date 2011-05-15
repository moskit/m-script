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


rcommand=${0##*/}
rpath=${0%/*}
#*/ (this is needed to fix vi syntax highlighting)
ports=`cat ${rpath}/../ports.list 2>/dev/null| grep -v '^#' | grep -v '^[:space:]*#'`
sockets=`cat ${rpath}/../sockets.list 2>/dev/null| grep -v '^#' | grep -v '^[:space:]*#'`
[ -x /bin/netstat ] && NETSTATCMD='/bin/netstat'
[ "X$NETSTATCMD" == "X" ] && NETSTATCMD=`which netstat 2>/dev/null`

if [ `uname` == "Linux" ]; then
  [ "X$NETSTATCMD" == "X" ] && echo "Netstat utility not found! Aborting.." && exit 1
  NETCONNS="${NETSTATCMD} -tuapn"
  SOCKCONNS="${NETSTATCMD} -xlpn"
fi

[ -x /bin/ping ] && PING='/bin/ping'
[ "X$PING" == "X" ] && PING=`which ping`

if [ `uname` == "Linux" ]; then
  ROUTE="$NETSTATCMD -rn"
fi

[ -f ${rpath}/../conf/sockets.exclude ] || touch ${rpath}/../conf/sockets.exclude
[ -f ${rpath}/../conf/ports.exclude ] || touch ${rpath}/../conf/ports.exclude

source ${rpath}/../mon.conf

echo
echo "Services up and running:"
echo "-----------------------"
echo
echo "Name                Listening on                            Connections"
echo

$NETSTATCMD -tlpn | grep -v ^Proto | grep -v ^Active | awk '{ print $4" "$7 }' > /tmp/m_script/ports.$$
$NETSTATCMD -ulpn | grep -v ^Proto | grep -v ^Active | awk '{ print $4" "$6 }' >> /tmp/m_script/ports.$$

while read LINE
do
  portfound=0
  t=${LINE%%%*}
  prog=${LINE#* }
  prog=$(echo $prog | cut -d/ -f2 | cut -d: -f1)
  cat ${rpath}/../conf/ports.exclude | grep -v '^#' | grep -v '^[:space:]*#' | while read exclport ; do
    if [[ $exclport =~ [^[0-9-]]* ]] ; then
      
      [[ $prog =~ $exclport ]] && skip=1 && break
    else
      portif=${t%:*}
      portnum=${t##*:}
      port1=${exclport%-*}
      port2=${exclport#*-}
      ([[ $portnum -ge $port1 ]] || [[ $portnum -le $port2 ]]) && skip=1 && break
    fi
  done
  
  [[ $skip -eq 1 ]] && skip=0 && continue
  # now compare ports
  for i in ${ports}
  do
    if [ "X${i}" == "X${t}" ]
    then
      j=`expr "${i}" : '.*\(:[0-9]*\)'`
      ports=$(echo ${ports} | sed "s|${t}||")
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
  [[ $portfound -ne 1 ]] && echo "<***> Service ${sname} listening on ${t} is not being monitored." | sed 's|0.0.0.0:|port |g' | sed 's|<\:\:\:>|port |g' | sed 's|\:\:\:|port |g'
done < /tmp/m_script/ports.$$

if [ "X${ports}" != "X" ]
then
 echo "<***> There is no services listening on: ${ports}" | sed 's|0.0.0.0:|port |g' | sed 's|<\:\:\:>|port |g' | sed 's|\:\:\:|port |g'
fi

echo
$SOCKCONNS | grep STREAM > /tmp/m_script/sockets.$$
#  | awk -F'STREAM' '{print $2}' | awk '{print $3}'
while read LINE
do
  for exclsocket in `cat ${rpath}/../conf/sockets.exclude | grep -v '^#' | grep -v '^[:space:]*#'`
  do
    [[ $LINE =~ $exclsocket ]] && skip=1 && break
  done
  [[ $skip -eq 1 ]] && skip=0 && continue
  socketfound=0
  t="${LINE##*[[:space:]]}"
  sname=$(echo $LINE | awk -F'STREAM' '{print $2}' | awk '{print $3}')
  sname=${sname#*/}
  # now compare sockets
  for i in ${sockets}
  do
    if [ "X${i}" == "X${t}" ]
    then
      sockets=$(echo ${sockets} | sed "s|${t}||")
      printf "$sname"
      m=`expr length $sname`
      l=`expr 20 - $m`
      for ((n=1; n <= $l; n++)); do printf " "; done
      printf "${t}\n"
      socketfound=1
      break
    fi
  done
  [[ $socketfound -ne 1 ]] && echo "<***> Service ${sname} listening on ${t} is not being monitored."
done < /tmp/m_script/sockets.$$
rm -f /tmp/m_script/ports.$$ /tmp/m_script/sockets.$$
if [ "X${sockets}" != "X" ]
then
 echo "<***> There is no services listening on unix sockets: ${sockets}"
fi
# End of netstat test

# Connectivity test
if [ "X$CONNTEST_IP" == "X" ]
then
  if [ "X$ROUTE" != "X" ]; then
    $ROUTE | grep 'G' | grep -v 'Flags' | awk '{print $2}' > /tmp/m_script/ping.tmp
  elif [ -f /etc/resolv.conf ]; then
    grep '^nameserver' /etc/resolv.conf | awk '{print $2}' >> /tmp/m_script/ping.tmp
  else
    echo "Unable to get any IP from system network settings to ping (tried: gateway, nameserver). Please provide IP address for ping test in mon.conf file"
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
rm -f /tmp/m_script/ping.tmp
if [ "X$CONNTEST_IP" == "X127.0.0.1" ] || [ "X$CONNTEST_IP" == "Xlocalhost" ]; then
  if [ "x$pingedip" == "xyes" ]; then
   echo ""
   echo 'Localhost pinged successfully'
  else
   echo '<***> Ping to localhost timeout!'
  fi
else
  if [ "x$pingedip" == "xyes" ]; then
   echo ""
   echo 'Server is connected'
  else
   echo '<***> Server is disconnected!'
   echo "<***> IP(s) ${failedip} unavailable"
  fi
fi
