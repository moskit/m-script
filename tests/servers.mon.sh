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



### Uncomment below and put your servers list to servers.conf if you need 
### to monitor multiple servers.
### Details and examples can be found in doc/multiple_servers.txt.

rcommand=${0##*/}
rpath=${0%/*}
#*/ (this is needed to fix vi syntax highlighting)
IFS1=$IFS
IFS='
'
echo ""
echo "Other servers availability"
echo "--------------------------"
echo ""
for mserver in `cat ${rpath}/../servers.conf|grep -v ^$|grep -v ^#|grep -v ^[[:space:]]*#`
do
  pingedip="no"
  # Simple ping test
  [ -x /bin/ping ] && PING='/bin/ping'
  [ "X$PING" == "X" ] && PING=`which ping`
  
  serverip=`echo $mserver|awk '{print $1}'`
  servername=`echo $mserver|awk '{print $2}'`
  $PING -c1 $serverip >/dev/null
  if [ "$?" != "0" ] ; then
    failed="${failed} ${servername}"
  else
    pingedip="yes"
  fi
  
  if [ "x$pingedip" == "xyes" ]; then
    echo "<OK> Server $servername is online"
  else
    echo "<***> Server $servername is offline!"
  fi

done
IFS=$IFS1

