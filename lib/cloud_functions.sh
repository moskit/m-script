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

lock_cloudops() {
  [ -n "$IAMACHILD" ] && log "I am a child" && return 0
  local -i i
  i=0
  log "trying to acquire the cloud operations lock"
  [ -n "$MAXLOCK" ] || MAXLOCK=30 
  lockfile=`find "$M_TEMP" -maxdepth 1 -name lock -mmin +$MAXLOCK`
  if [ -n "$lockfile" ] ; then
    log " *** Lock file is older than $MAXLOCK minutes, removing"
    rm -f $lockfile
  fi
  while [ -f "$M_TEMP/lock" ]; do
    sleep 5
    i+=1
    [ $i -gt 100 ] && log "failed to acquire the lock" && return 1
  done
  touch "$M_TEMP/lock"
  log "cloud operations locked"
}

unlock_cloudops() {
  rm -f "$M_TEMP/lock" && log "cloud operations unlocked"
  unset IAMACHILD
}

cloudops_locked() {
  # we don't lock children
  [ -n "$IAMACHILD" ] && log "I am a child" && return 1
  [ -f "$M_TEMP/lock" ] && return 0 || return 1
}

generate_name() {
  # double-check the cluster is defined
  [ -z "$cluster" ] && cluster=$M_CLUSTER
  [ -z "$cluster" ] && log "Cluster is not defined, exiting" && return 1
  nam=$(cat "$M_ROOT/servers.list" | grep -v ^# | grep -v ^$ | grep \|${cluster}[[:space:]]*$ | cut -d'|' -f4 | while read name ; do expr "X$name" : 'X\(.*[^0-9]\)[0-9]*' ; expr "X$name" : "X\($cluster\)[0-9]*" ; done | sort | uniq -c | sort | tail -1) ; nam=${nam##* }
  [ -n "$nam" ] || nam=$cluster
  am=0 ; lm=0
  num=$(cat "$M_ROOT/servers.list" | grep -v ^# | grep -v ^$ | cut -d'|' -f4 | grep ^$nam[0-9] | while read name ; do a=`expr "X$name" : "X$nam\([0-9]*\)"` ; l=${#a} ; [[ `expr $l \> ${lm}` -gt 0 ]] && lm=$l ; [[ `expr $a \> ${am}` -gt 0 ]] && am=$a ; echo "$am|$lm" ; done | tail -1)
  am=${num%|*} ; lm=${num#*|}
  if [ -n "$am" ] ; then
    am=`expr $am + 1`
    # length might have changed
    lnew=${#am}
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
  [ -z "$cluster" ] && log "cluster is not defined, exiting" && return 1
  limit=`cat "$M_ROOT/conf/clusters.conf" | grep ^${cluster}\| | cut -d'|' -f7`
  [ -z "$limit" ] && return 0
  limit=${limit#*:}
  [ "$limit" == "0" ] && return 0
  # tmp file is assumed to be up-to-date
  n=`IAMACHILD=1 ${rpath}/show_servers --view=none --noupdate --count --cluster=$cluster`
  log "cluster $cluster limit is ${limit}, current servers number is $n"
  [ -z "$n" ] && n=0
  #[ `expr $n \>= 0` -gt 0 ] || return 1
  [ `expr $limit \> $n` -gt 0 ] && echo 0 && return 0
  echo 1
  return 1
}

check_cluster_minimum() {
  # double-check the cluster is defined
  [ -z "$cluster" ] && cluster=$1
  [ -z "$cluster" ] && cluster=$M_CLUSTER
  [ -z "$cluster" ] && log "cluster is not defined, exiting" && return 1
  limit=`cat "$M_ROOT/conf/clusters.conf" | grep ^${cluster}\| | cut -d'|' -f7`
  [ -z "$limit" ] && return 0
  [ `expr "$limit" : '.*:'` -eq 0 ] && return 0
  limit=${limit%:*}
  [ "$limit" == "0" ] && return 0
  # tmp file is assumed to be up-to-date
  n=`IAMACHILD=1 ${rpath}/show_servers --view=none --noupdate --count --cluster=$cluster`
  [ -z "$n" ] && n=0
  log "cluster $cluster minimum is ${limit}, current servers number is $n"
  [ -z "$n" ] && n=0
  #[ `expr $n \>= 0` -gt 0 ] || return 1
  [ `expr $limit \< $n` -gt 0 ] && echo 0 && return 0
  echo 1
  return 1
}

find_name() {
  NAME=`grep "^${1}|" "$M_ROOT/servers.list" 2>/dev/null | cut -d'|' -f4`
  [ -n "$NAME" ] && echo "$NAME" && return 0 || NAME=`grep -E "^${1}[[:space:]]|[[:space:]]${1}[[:space:]]" /etc/hosts`
  [ -n "$NAME" ] && NAME=$(for N in $NAME ; do [[ "$N" =~ '\.' ]] || DNAME=$N ; done)
  [ -n "$DNAME" ] && NAME=$DNAME || NAME=`echo $NAME | awk '{print $2}' | cut -d'.' -f1`
  echo "$NAME"
}

proper_exit() {
  log "exit status: $1"
  [ -z "$IAMACHILD" ] && unlock_cloudops
  exit $1
}


