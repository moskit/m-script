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
  if [ -n "$LOG" ]; then
    echo "`date +"%m.%d %H:%M:%S"` ($PPID/$$) ${CLOUD}/${0##*/}: ${@}">>$LOG
  fi
}

CLOUDS=`cat "$M_ROOT/conf/clusters.conf" | grep -vE "^[[:space:]]*$|^[[:space:]]*#" | cut -d'|' -f12 | sort | uniq | grep -v ^$`
export CLOUDS LOG

# current cloud passed as an environment variable
if [ -n "$CLOUD" ]; then
  source "$M_ROOT/conf/clouds/${CLOUD}.conf"
else
# if there is only one cloud, it is passed as an environment variable by default
  if [ `echo "$CLOUDS" | wc -l` -eq 1 ]; then
    export CLOUD=$CLOUDS
  fi
fi

list_clusters() {
  # list_clusters <cloud name>
  cat "$M_ROOT/conf/clusters.conf" | grep -vE "^[[:space:]]*$|^[[:space:]]*#" | cut -d'|' -f1,12 | grep "|$1$" | cut -sd'|' -f1 | sort | uniq
}

list_node_names() {
  # list_node_names <cloud name> <cluster name>
  cat "$M_ROOT/nodes.list" | grep -vE "^[[:space:]]*$|^[[:space:]]*#" | cut -d'|' -f4,5,6 | grep "|$2|$1$" | cut -sd'|' -f1 | sort | uniq
}

list_node_ips() {
  # list_node_ips <cloud name> <cluster name>
  cat "$M_ROOT/nodes.list" | grep -vE "^[[:space:]]*$|^[[:space:]]*#" | cut -d'|' -f1,5,6 | grep "|$2|$1$" | cut -sd'|' -f1 | sort | uniq
}

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
    log "$i :: waiting for a lock"
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
  nam=$(cat "$M_ROOT/nodes.list" | grep -vE "^[[:space:]]*$|^[[:space:]]*#" | grep \|${cluster}\| | cut -d'|' -f4 | while read name ; do expr "X$name" : 'X\(.*[^0-9]\)[0-9]*' ; expr "X$name" : "X\($cluster\)[0-9]*" ; done | sort | uniq -c | sort | tail -1) ; nam=${nam##* }
  [ -n "$nam" ] || nam=$cluster
  nam=`sanitize_hostname $nam`
  am=0 ; lm=0
  num=$(cat "$M_ROOT/nodes.list" | grep -vE "^[[:space:]]*$|^[[:space:]]*#" | cut -d'|' -f4 | grep ^$nam[0-9] | while read name ; do a=`expr "X$name" : "X$nam\([0-9]*\)"` ; l=${#a} ; [[ `expr $l \> ${lm}` -gt 0 ]] && lm=$l ; [[ `expr $a \> ${am}` -gt 0 ]] && am=$a ; echo "$am|$lm" ; done | tail -1)
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

sanitize_hostname() {
  [ -z "$1" ] && echo "ERROR: empty hostname has been passed to sanitizer" && return
  if [ -n "$NAME_INDEX_SEPARATOR" ]; then
    # the name passed here may contain a separator at the end already
    hn=`expr $1 : "\(.*\)$NAME_INDEX_SEPARATOR$"`
    [ $? -eq 0 ] || hn=$1
    hn="${hn}${NAME_INDEX_SEPARATOR}"
  else
    hn=$1
  fi
  # M-Script allows any symbols in cluster names, but only underscore and dots
  # are converted to hyphen in the resulting hostnames, anything else is deleted
  echo "$hn" | sed 's|[^a-zA-Z0-9._-]||g;s|[._]|-|g;s|^-*||'
}

check_cluster_limit() {
  cluster="$*"
  [ -z "$cluster" ] && cluster=$M_CLUSTER
  [ -z "$cluster" ] && log "cluster is not defined, not checking limit" && return 1
  clcloud=`cat "$M_ROOT/conf/clusters.conf" | grep ^${cluster}\| | cut -d'|' -f12`
  [ -n "$clcloud" ] && [ "_$clcloud" != "_$CLOUD" ] && CLOUD=$clcloud
  source "$M_ROOT/conf/clouds/${CLOUD}.conf" || return 1
  limit=`cat "$M_ROOT/conf/clusters.conf" | grep ^${cluster}\| | cut -d'|' -f7`
  [ -z "$limit" ] && return 0
  limit=${limit#*:}
  [ "$limit" == "0" ] && return 0
  n=`IAMACHILD=1 "$M_ROOT/cloud/$CLOUD_PROVIDER"/show_servers --view=none --noupdate --count --cluster=$cluster`
  [ -z "$n" ] && n=0
  log "cluster $cluster limit is ${limit}, current servers number is $n"
  #[ `expr $n \>= 0` -gt 0 ] || return 1
  [ `expr $limit \> $n` -gt 0 ] 2>/dev/null && return 0
  return 1
}

check_cluster_minimum() {
  cluster="$*"
  [ -z "$cluster" ] && cluster=$M_CLUSTER
  [ -z "$cluster" ] && log "cluster is not defined, not checking limit" && return 1
  clcloud=`cat "$M_ROOT/conf/clusters.conf" | grep ^${cluster}\| | cut -d'|' -f12`
  [ -n "$clcloud" ] && [ "_$clcloud" != "_$CLOUD" ] && CLOUD=$clcloud
  source "$M_ROOT/conf/clouds/${CLOUD}.conf" || return 1
  limit=`cat "$M_ROOT/conf/clusters.conf" | grep ^${cluster}\| | cut -d'|' -f7`
  [ -z "$limit" ] && return 0
  [ `expr "$limit" : '.*:'` -eq 0 ] && return 0
  limit=${limit%:*}
  [ "$limit" == "0" ] && return 0
  n=`IAMACHILD=1 "$M_ROOT/cloud/$CLOUD_PROVIDER"/show_servers --view=none --noupdate --count --cluster=$cluster`
  [ -z "$n" ] && n=0
  log "cluster $cluster minimum is ${limit}, current servers number is $n"
  [ `expr $limit \< $n` -gt 0 ] && return 0
  return 1
}

test_cluster_limit() {
  cluster="$*"
  [ -z "$cluster" ] && cluster=$M_CLUSTER
  [ -z "$cluster" ] && log "cluster is not defined, not checking limit" && return 0
  clcloud=`cat "$M_ROOT/conf/clusters.conf" | grep ^${cluster}\| | cut -d'|' -f12`
  [ -n "$clcloud" ] && [ "_$clcloud" != "_$CLOUD" ] && CLOUD=$clcloud
  source "$M_ROOT/conf/clouds/${CLOUD}.conf" || return 0
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

test_cluster_minimum() {
  cluster="$*"
  [ -z "$cluster" ] && cluster=$M_CLUSTER
  [ -z "$cluster" ] && log "cluster is not defined, not checking limit" && return 0
  clcloud=`cat "$M_ROOT/conf/clusters.conf" | grep ^${cluster}\| | cut -d'|' -f12`
  [ -n "$clcloud" ] && [ "_$clcloud" != "_$CLOUD" ] && CLOUD=$clcloud
  source "$M_ROOT/conf/clouds/${CLOUD}.conf" || return 0
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
  NAME=`grep "^${1}|" "$M_ROOT/nodes.list" 2>/dev/null | cut -d'|' -f4`
  if [ -n "$NAME" ]; then
    echo "$NAME"
    return 0
  else
    log "getting name for IP $1 from /etc/hosts"
    NAME=`grep -E "^${1}[[:space:]]|[[:space:]]${1}[[:space:]]" /etc/hosts | head -1`
    if [ -n "$NAME" ]; then
      NAME=$(for N in $NAME ; do [[ "$N" =~ '\.' ]] || DNAME=$N ; done)
      [ -n "$DNAME" ] && NAME=$DNAME || NAME=`echo $NAME | awk '{print $2}' | cut -d'.' -f1`
      echo "$NAME"
      return 0
    else
      log "getting hostname for IP $1 from the host"
      NAME=`get_hostname $1`
      echo $NAME | awk '{print $2}' | cut -d'.' -f1
      return 0
    fi
  fi
  return 1
}

name_to_ip() {
  IP=`cat "$M_ROOT/nodes.list" 2>/dev/null | cut -d'|' -f1,4 | grep "|${1}$" | cut -d'|' -f1 | tail -1`
  if [ -z "$IP" ]; then
    IP=`grep -E "\ $name\ |\ $name$" /etc/hosts | tail -1`
    IP=`expr "$IP" : ".*\([0-9.]\)[[:space:]]"`
  fi
  [ -z "$IP" ] && return 1
  echo "$IP"
}

ip_to_name() {
  name=`cat "$M_ROOT/nodes.list" 2>/dev/null | cut -d'|' -f1,4 | grep "^${1}|" | cut -d'|' -f2 | tail -1`
  if [ -z "$name" ]; then
    name=`grep -E "^$1\ |\ $1\ " /etc/hosts | tail -1`
    name=`expr "$name" : ".*\s\(.*\)\s*$"`
  fi
  [ -z "$name" ] && return 1
  echo "$name"
}

proper_exit() {
  log "exit at line: $2 status: $1"
  if [ -z "$nolock" ]; then
    [ -z "$IAMACHILD" ] && log "I am a parent, unlocking" && unlock_cloudops || log "I am a child, cannot unlock"
  fi
  exit $1
}

get_hostname() {
  [ -z "$1" ] && return 1
  if [ `echo $localip | grep -c "^$1$"` -ne 0 ] ; then
    sname=`$HOSTNAME`
  else
    KEY=`$M_ROOT/helpers/find_key node $1` || return 1
    [ -f "$KEY" ] && sname=`$SSH -i "$KEY" -o StrictHostKeyChecking=no -o ConnectionAttempts=1 -o ConnectTimeout=10 $1 hostname 2>/dev/null`
  fi
  [ `expr "$sname" : ".*[\"\t\s_,\.\']"` -ne 0 ] && unset sname
  [ -z "$sname" ] && log "Unable to retrieve hostname of the server with IP $1" && return 1
  return 0
}

check_super_cluster() {
  # returns 0 if the argument IP is in a SUPER_CLUSTER (see conf/mon.conf)
  # except if it is a local IP
  [ -z "$SUPER_CLUSTER" ] && M_TEMP1=$M_TEMP && source "$M_ROOT/conf/mon.conf" && M_TEMP=$M_TEMP1
  [ -z "$SUPER_CLUSTER" ] && return 1
  [ -z "$2" ] && return 1
  "$M_ROOT/helpers"/localips 2>/dev/null | grep -q "^${1}$" && return 1
  [ "_$2" == "_$SUPER_CLUSTER" ] && return 0
}

check_node_up() {
  "$M_ROOT"/helpers/mssh "$1" true
}

run_init() {
  local initcloud=$1
  local initcluster=$2
  local initip=$3
  DISTRO=`cat "$M_ROOT/conf/clusters.conf" | grep -vE "^[[:space:]]*$|^[[:space:]]*#" | grep "^$initcluster|" | cut -d'|' -f11`
  source "$M_ROOT/conf/clouds/${initcloud}.conf"
  source "$M_ROOT/conf/deployment.conf"
  [ -z "$CONNECT_TIMEOUT" ] && CONNECT_TIMEOUT=5
  [ -z "$SSHPORT" ] && SSHPORT=22
  [ -z "$SSH_USER" ] && SSH_USER=root
  [ -z "$key" ] && key=`"$M_ROOT"/helpers/find_key cluster $initcluster`
  export SSH_USER SSHPORT CONNECT_TIMEOUT key initcloud initcluster initip
  if [ -e "$ROLES_ROOT/init/${CLOUD_PROVIDER}_${DISTRO}.sh" ]; then
    /bin/bash "$ROLES_ROOT/init/${CLOUD_PROVIDER}_${DISTRO}.sh"
    return $?
  fi
  if [ "_$initcloud" != "$_CLOUD_PROVIDER" ]; then
    if [ -e "$ROLES_ROOT/init/${initcloud}_${DISTRO}.sh" ]; then
      /bin/bash "$ROLES_ROOT/init/${initcloud}_${DISTRO}.sh"
      return $?
    fi
  fi
}
  
  
  
  
