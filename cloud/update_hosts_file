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

cat ${rpath}/../servers.list | grep -v ^[[:space:]]*$ | grep -v ^[[:space:]]*# | awk '{print $1" "$2}' | while read HOST
do
  ip=`echo $HOST | awk '{print $1}'`
  hname=`echo $HOST | awk '{print $2}'`
  if [ `grep -c "$ip[[:space:]]*$hname" /etc/hosts` -eq 0 ] ; then
    if [ `grep -c "$ip " /etc/hosts` -eq 1 ] ; then
      sed -i -e "/$ip/d" /etc/hosts
    fi
    if [ `grep -c " $hname " /etc/hosts` -eq 1 ] ; then
      sed -i -e "/ $hname /d" /etc/hosts
    fi
    if [ `grep -c " $hname$" /etc/hosts` -eq 1 ] ; then
      sed -i -e "/ $hname$/d" /etc/hosts
    fi
    echo "$ip $hname" >> /etc/hosts
  fi
done

