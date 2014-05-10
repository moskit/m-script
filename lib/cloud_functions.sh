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
  [ -n "$LOG" ] && echo "`date +"%m.%d %H:%M:%S"` ($$) ${CLOUD}/${0##*/}: ${@}">>$LOG
}

if [ -n "$CLOUD" ]; then
  source "$M_ROOT/conf/clouds/${CLOUD}.conf"
else
  CLOUD=`cat "$M_ROOT/conf/clusters.conf" | grep -vE "^#|^[[:space:]]#|^$" | cut -d'|' -f12 | sort | uniq | grep -v ^$`
  if [ `echo "$CLOUD" | wc -l` -eq 1 ]; then
    export CLOUD
  else
    unset CLOUD
  fi
  [ -z "$CLOUD" ] && log "Not sourcing cloud_functions, CLOUD is not defined" && exit 1
fi

lock_cloudops() {
  local LOG="$M_ROOT/logs/cloud.log"
  [ -n "$IAMACHILD" ] && log "I am a child, don't lock me up" && return 0
  local -i i
  i=0
  log "trying to acquire cloud operations lock"
  [ -n "$MAXLOCK" ] || MAXLOCK=30 
  lockfile=`find "$M_ROOT/cloud/" -maxdepth 1 -mindepth 1 -name "cloud.${CLOUD}.lock" -mmin +$MAXLOCK`
  if [ -n "$lockfile" ] ; then
    log " *** Lock file is older than $MAXLOCK minutes, removing"
    rm -f $lockfile
  fi
  while [ -f "$M_ROOT/cloud/cloud.${CLOUD}.lock" ]; do
    sleep 10
    i+=1
    log "$i :: cloud operations are locked"
    [ $i -gt 50 ] && log "failed to acquire the lock" && return 1
  done
  touch "$M_ROOT/cloud/cloud.${CLOUD}.lock"
  log "locking cloud operations"
}

unlock_cloudops() {
  local LOG="$M_ROOT/logs/cloud.log"
  if [ -f "$M_ROOT/cloud/cloud.${CLOUD}.lock" ]; then
    rm -f "$M_ROOT/cloud/cloud.${CLOUD}.lock" && log "unlocking cloud operations" || log "error removing lock"
  else
    log "unlocking: cloud operations were not locked"
  fi
  unset IAMACHILD
}

cloudops_locked() {
  local LOG="$M_ROOT/logs/cloud.log"
  # we don't lock up children
  [ -n "$IAMACHILD" ] && log "I am a child, I am not locked up" && return 1
  [ -f "$M_ROOT/cloud/cloud.${CLOUD}.lock" ] && return 0 || return 1
}

generate_name() {
  cluster="$*"
  [ -z "$cluster" ] && cluster=$M_CLUSTER
  [ -z "$cluster" ] && log "Cluster is not defined, exiting" && return 1
  nam=$(cat "$M_ROOT/servers.list" | grep -vE "^#|^$|^[[:space:]]#" | grep \|${cluster}\| | cut -d'|' -f4 | while read name ; do expr "X$name" : 'X\(.*[^0-9]\)[0-9]*' ; expr "X$name" : "X\($cluster\)[0-9]*" ; done | sort | uniq -c | sort | tail -1) ; nam=${nam##* }
  [ -n "$nam" ] || nam=$cluster
  am=0 ; lm=0
  num=$(cat "$M_ROOT/servers.list" | grep -vE "^#|^$|^[[:space:]]#" | cut -d'|' -f4 | grep ^$nam[0-9] | while read name ; do a=`expr "X$name" : "X$nam\([0-9]*\)"` ; l=${#a} ; [[ `expr $l \> ${lm}` -gt 0 ]] && lm=$l ; [[ `expr $a \> ${am}` -gt 0 ]] && am=$a ; echo "$am|$lm" ; done | tail -1)
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
  cluster="$*"
  [ -z "$cluster" ] && cluster=$M_CLUSTER
  [ -z "$cluster" ] && log "cluster is not defined, not checking limit" && return 0
  clcloud=`cat "$M_ROOT/conf/clusters.conf" | grep ^${cluster}\| | cut -d'|' -f12`
  [ -n "$clcloud" ] && [ "X$clcloud" != "X$CLOUD" ] && CLOUD=$clcloud && source "$M_ROOT/conf/clouds/${CLOUD}.conf"
  limit=`cat "$M_ROOT/conf/clusters.conf" | grep ^${cluster}\| | cut -d'|' -f7`
  [ -z "$limit" ] && return 0
  limit=${limit#*:}
  [ "$limit" == "0" ] && return 0
  n=`IAMACHILD=1 "$M_ROOT/cloud/$CLOUD_PROVIDER"/show_servers --view=none --noupdate --count --cluster=$cluster`
  [ -z "$n" ] && n=0
  log "cluster $cluster limit is ${limit}, current servers number is $n"
  #[ `expr $n \>= 0` -gt 0 ] || return 1
  [ `expr $limit \>= $n` -gt 0 ] 2>/dev/null && return 0
  return 1
}

check_cluster_minimum() {
  cluster="$*"
  [ -z "$cluster" ] && cluster=$M_CLUSTER
  [ -z "$cluster" ] && log "cluster is not defined, not checking limit" && return 0
  clcloud=`cat "$M_ROOT/conf/clusters.conf" | grep ^${cluster}\| | cut -d'|' -f12`
  [ -n "$clcloud" ] && [ "X$clcloud" != "X$CLOUD" ] && CLOUD=$clcloud && source "$M_ROOT/conf/clouds/${CLOUD}.conf"
  limit=`cat "$M_ROOT/conf/clusters.conf" | grep ^${cluster}\| | cut -d'|' -f7`
  [ -z "$limit" ] && return 0
  [ `expr "$limit" : '.*:'` -eq 0 ] && return 0
  limit=${limit%:*}
  [ "$limit" == "0" ] && return 0
  n=`IAMACHILD=1 "$M_ROOT/cloud/$CLOUD_PROVIDER"/show_servers --view=none --noupdate --count --cluster=$cluster`
  [ -z "$n" ] && n=0
  log "cluster $cluster minimum is ${limit}, current servers number is $n"
  [ `expr $limit \<= $n` -gt 0 ] && return 0
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
  log "exit at line: $2 status: $1"
  [ -z "$IAMACHILD" ] && log "I am a parent, unlocking" && unlock_cloudops || log "I am a child, cannot unlock"
  exit $1
}

get_hostname() {
  [ -z "$1" ] && return 1
  if [ `echo $localip | grep -c "^$1$"` -ne 0 ] ; then
    sname=`$HOSTNAME`
  else
    KEY=`$M_ROOT/helpers/find_key server $1`
    [ -f "$KEY" ] && sname=`$SSH -i "$KEY" -o StrictHostKeyChecking=no -o ConnectionAttempts=1 -o ConnectTimeout=10 $1 hostname 2>/dev/null`
  fi
  [ `expr "$sname" : ".*[\"\t\s_,\.\']"` -ne 0 ] && unset sname
  [ -z "$sname" ] && log "Unable to retrieve hostname of the server with IP $1" && return 1
  return 0
}

find_local_ips() {
  IFCFG=`which ifconfig 2>/dev/null`
  if [ -n "$IFCFG" ] ; then
    $IFCFG | sed '/inet\ /!d;s/.*r://;s/\ .*//' | grep -v '127.0.0.1'
  else
    IFCFG=`which ip 2>/dev/null`
    [ -n "$IFCFG" ] && $IFCFG addr list | grep 'inet.*scope\ global' | while read L ; do expr "$L" : 'inet \(.*\)/' ; done
  fi
}

check_super_cluster() {
  # returns 0 if the argument IP is in a SUPER_CLUSTER (see conf/mon.conf)
  # except if it is a local IP
  [ -z "$SUPER_CLUSTER" ] && M_TEMP1=$M_TEMP && source "$M_ROOT/conf/mon.conf" && M_TEMP=$M_TEMP1
  [ -z "$SUPER_CLUSTER" ] && return 1
  [ -z "$2" ] && return 1
  localips=`find_local_ips`
  echo "$localips" | grep -q "^${1}$" && return 1
  [ "X$2" == "X$SUPER_CLUSTER" ] && return 0
}

  
