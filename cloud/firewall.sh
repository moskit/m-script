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



### Uncomment below and put your servers list to servers.list if you need 
### to monitor multiple servers.
### Details and examples can be found in doc/multiple_servers.txt.

rcommand=${0##*/}
rpath=${0%/*}
#*/ (this is needed to fix vi syntax highlighting)
[ -f "/sbin/iptables" ] && IPTABLES=/sbin/iptables || IPTABLES=`which iptables 2>/dev/null`
[ "X$IPTABLES" == "X" ] && echo "iptables not found!" && exit 1
[ -f "/sbin/ifconfig" ] && IFCFG=/sbin/ifconfig || IFCONFIG=`which ifconfig 2>/dev/null`
if [ "X$IFCONFIG" == "X" ]; then
  IFCONFIG=`which ip 2>/dev/null`
  if [ "X$IFCONFIG" == "X" ]; then
    echo "Neither ifconfig nor ip has been found! (Not root?)" && exit 1
  else
    IFCONFIG="$IFCONFIG addr show"
  fi
fi

IFS1=$IFS
IFS='
'
for clserver in `cat ${rpath}/../servers.list|grep -v ^$|grep -v ^#|grep -v ^[[:space:]]*#`
do
  serverip=`echo $clserver | awk '{print $1}'`
  if [ -n `$IFCONFIG | grep $serverip` ]; then
  echo $serverip
  $IPTABLES -I INPUT -s $serverip -j ACCEPT
  fi
done
myip=`echo $SSH_CLIENT | awk '{print $1}'`

IFS=$IFS1


