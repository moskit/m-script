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

[[ $1 =~ ^\/ ]] && rroot='/'
for step in `echo ${1} | tr '/' ' '` ; do
  rlink=`readlink "${rroot}${rpath}${step}"`
  if [ -n "$rlink" ] ; then
    [[ $rlink =~ ^\/ ]] && rpath="${rlink}/" && unset rroot || rpath="${rpath}${rlink}/"
  else
    rpath="${rpath}${step}/"
  fi
done
rpath=${rpath%/}
[ -h "$rpath" ] && rpath=`readlink "$rpath"`
rcommand=${rpath##*/}
rpath="${rroot}${rpath%/*}"
#*/

source "${rpath}/conf/mon.conf"
source "${rpath}/conf/cloud.conf"
source "${rpath}/conf/deployment.conf"

M_ROOT=$(cd "${rpath}" && pwd)
export CLOUD ROLES_ROOT M_ROOT
export PATH=${M_ROOT}/deployment:${M_ROOT}/cloud/${CLOUD}:${M_ROOT}/helpers:${PATH}

cr() {
  [ -z "$1" ] && ls "$ROLES_ROOT" && return
  cd "$ROLES_ROOT/$1"
  export M_ROLE="$1"
  M_CLUSTER=`cat "${rpath}/conf/clusters.conf" | grep -v ^# | grep -v ^$ | cut -d'|' -f1,10 | grep \|${M_ROLE}$ | cut -d'|' -f1`
}

use_color=false
safe_term=${TERM//[^[:alnum:]]/?}   # sanitize TERM
match_lhs=""
[[ -f ~/.dir_colors   ]] && match_lhs="${match_lhs}$(<~/.dir_colors)"
[[ -f /etc/DIR_COLORS ]] && match_lhs="${match_lhs}$(</etc/DIR_COLORS)"
[[ -z ${match_lhs}    ]] \
	&& type -P dircolors >/dev/null \
	&& match_lhs=$(dircolors --print-database)
[[ $'\n'${match_lhs} == *$'\n'"TERM "${safe_term}* ]] && use_color=true

if ${use_color} ; then
  PROMPT_COMMAND='echo -ne "\033[00;37m[\033[01;31m${HOSTNAME%%.*}\033[00;39m:\033[01;36m${M_ROLE}\033[00;39m"'
  PS1='\033[00;37m]#\033[00;39m '
else
	PROMPT_COMMAND='echo -ne "[${HOSTNAME%%.*}:${M_ROLE}"'
	PS1=']# '
fi
export PROMPT_COMMAND PS1
unset use_color safe_term match_lhs

