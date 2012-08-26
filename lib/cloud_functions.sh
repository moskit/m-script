#!/bin/bash
# Copyright (C) 2008-2012 Igor Simonov (me@igorsimonov.com)
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

dpath=$(readlink -f "$BASH_SOURCE")
dpath=${dpath%/*}
#*/
[ -z "$M_ROOT" ] && M_ROOT=$(readlink -f "$dpath/../")
[ -z "$LOG" ] && LOG="$M_ROOT/logs/cloud.log"

log() {
  [ -n "$LOG" ] && echo "`date +"%m.%d %H:%M:%S"` ${CLOUD}/${0##*/}: ${@}">>$LOG
}

get_lock() {
  local -i i
  i=0
  while [ -f "$M_TEMP/cloud/$CLOUD/lock" ]; do
    sleep 5
    i+=1
    [ $i -gt 100 ] && return 1
  done
  touch "$M_TEMP/cloud/$CLOUD/lock"
}

rm_lock() {
  rm -f "$M_TEMP/cloud/$CLOUD/lock"
}

generate_name() {
  # double-check the cluster is defined
  [ -z "$cluster" ] && cluster=$M_CLUSTER
  [ -z "$cluster" ] && log "Cluster is not defined, exiting" && exit 1
  nam=$(cat "${rpath}/../../servers.list" | grep -v ^# | grep -v ^$ | grep \|${cluster}[[:space:]]*$ | cut -d'|' -f4 | while read name ; do expr "X$name" : 'X\(.*[^0-9]\)[0-9]*' ; expr "X$name" : "X\($cluster\)[0-9]*" ; done | sort | uniq -c | sort | tail -1) ; nam=${nam##* }
  [ -n "$nam" ] || nam=$cluster
  am=0 ; lm=0
  num=$(cat "${rpath}/../../servers.list" | grep -v ^# | grep -v ^$ | cut -d'|' -f4 | grep ^$nam[0-9] | while read name ; do a=`expr "X$name" : 'X.*[^0-9]\([0-9]*\)'` ; l=${#a} ; [ `expr $l \> ${lm}` -gt 0 ] && lm=$l ; [ `expr $a \> ${am}` -gt 0 ] && am=$a ; echo "$am|$lm" ; done | tail -1)
  am=${num%|*} ; lm=${num#*|}
  if [ -n "$am" ] ; then
    am=`expr $am + 1`
    # length might change
    lnew=${#a}
    [[ $lnew -gt $lm ]] && lm=$lnew
  else
    am=1
  fi
  [ -n "$lm" ] || lm=$NAME_INDEX_LENGTH
  echo "$nam`until [[ ${#am} -eq $lm ]] ; do am="0$am" ; m0="0$m0" ; [[ ${#am} -gt $lm ]] && exit 1 ; echo $m0 ; done | tail -1`$am"
}

check_cluster_limit() {
  # double-check the cluster is defined
  [ -z "$cluster" ] && cluster=$M_CLUSTER
  [ -z "$cluster" ] && log "cluster is not defined, exiting" && exit 1
  limit=`cat "$M_ROOT/conf/clusters.conf" | grep ^${cluster}\| | cut -d'|' -f7`
  [ -z "$limit" ] && return 0
  limit=${limit#*:}
  [ "$limit" == "0" ] && return 0
  # tmp file is assumed to be up-to-date
  n=`${rpath}/show_servers --view=none --noupdate --count --cluster=$cluster`
  log "cluster $cluster limit is ${limit}, current servers number is $n"
  [ -z "$n" ] && n=0
  [ `expr $n \>= 0` -gt 0 ] || return 1
  [ `expr $limit \> $n` -gt 0 ] && return 0
  return 1
}

check_cluster_minimum() {
  # double-check the cluster is defined
  [ -z "$cluster" ] && cluster=$M_CLUSTER
  [ -z "$cluster" ] && log "cluster is not defined, exiting" && exit 1
  limit=`cat "$M_ROOT/conf/clusters.conf" | grep ^${cluster}\| | cut -d'|' -f7`
  [ -z "$limit" ] && return 0
  [ `expr "$limit" : '.*:'` -eq 0 ] && return 0
  limit=${limit%:*}
  [ "$limit" == "0" ] && return 0
  # tmp file is assumed to be up-to-date
  n=`${rpath}/show_servers --view=none --noupdate --count --cluster=$cluster`
  log "cluster $cluster minimum is ${limit}, current servers number is $n"
  [ -z "$n" ] && n=0
  [ `expr $n \>= 0` -gt 0 ] || return 1
  [ `expr $limit \< $n` -gt 0 ] && return 0
  return 1
}

