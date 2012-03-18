#!/bin/bash
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

[ -n "`expr "${BASH_SOURCE[0]}" : '\(\/\)'`" ] && rpath="${BASH_SOURCE[0]}" || rpath="./${BASH_SOURCE[0]}"
while [ -h "$rpath" ] ; do rpath=`readlink "$rpath"` ; done
rcommand=${rpath##*/}
rpath="$(cd -P "${rpath%/*}" && pwd)"
#*/

M_ROOT="$rpath"

setup_env() {
  source "${rpath}/conf/mon.conf"
  source "${rpath}/conf/cloud.conf"
  source "${rpath}/conf/deployment.conf"
  export CLOUD ROLES_ROOT M_ROOT
  export PATH=${M_ROOT}/deployment:${M_ROOT}/cloud/${CLOUD}:${M_ROOT}/helpers:${PATH}
}

cr() {
  [ -z "$1" ] && ls "$ROLES_ROOT" && return
  cd "$ROLES_ROOT/$1"
  export M_ROLE="$1"
  export role="$1"
  M_CLUSTER=`cat "${rpath}/conf/clusters.conf" | grep -v ^# | grep -v ^$ | cut -d'|' -f1,10 | grep \|${M_ROLE}$ | cut -d'|' -f1`
  export M_CLUSTER
  flavor=`grep ^$M_CLUSTER\| "${rpath}/../conf/clusters.conf" | cut -d'|' -f11`
  export flavor
  if ${use_color} ; then
    PS1="\[\033[00;37m\][\[\033[01;31m\]${HOSTNAME%%.*}\[\033[0m\]:\[\033[01;36m\]${M_ROLE}\[\033[00;37m\]]# \[\033[0m\]"
  else
    PS1="[${HOSTNAME%%.*}:${M_ROLE}]# "
  fi
  source role.conf
}

exit() {
  export PS1=$OLDPS1
  unset M_ROLE M_CLUSTER ROLES_ROOT role flavor
  unset cr exit
}

setup_env

OLDPS1=$PS1
use_color=false
safe_term=${TERM//[^[:alnum:]]/?}   # sanitize TERM
match_lhs=""
[[ -f ~/.dir_colors   ]] && match_lhs="${match_lhs}$(<~/.dir_colors)"
[[ -f /etc/DIR_COLORS ]] && match_lhs="${match_lhs}$(</etc/DIR_COLORS)"
[[ -z ${match_lhs}    ]] \
	&& type -P dircolors >/dev/null \
	&& match_lhs=$(dircolors --print-database)
[[ $'\n'${match_lhs} == *$'\n'"TERM "${safe_term}* ]] && use_color=true
export use_color
if ${use_color} ; then
  PS1="\[\033[00;37m\][\[\033[01;31m\]${HOSTNAME%%.*}\[\033[0m\]:\[\033[01;36m\]${M_ROLE}\[\033[00;37m\]]# \[\033[0m\]"
else
  PS1="[${HOSTNAME%%.*}:${M_ROLE}]# "
fi
export PS1
unset use_color safe_term match_lhs

