#!/bin/bash
# Copyright (C) 2014 Igor Simonov (me@igorsimonov.com)
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
#*/
[ -z "$M_ROOT" ] && M_ROOT=$(readlink -f "$rpath/../../")

CURL=`which curl 2>/dev/null`
[ -z "$CURL" ] && echo "Curl not found" && exit 1

try_auth() {
  local -i i
  i=0
  while [ ! -e "$M_TEMP/auth.resp" -o `cat "$M_TEMP/auth.resp" 2>/dev/null | wc -l` -eq 0 ] ; do
    [ $i -gt 10 ] && log "Problem getting authorization from the Rackspace Cloud API" && proper_exit 1 146
    "$rpath"/auth
    i+=1
    sleep 10
  done
  [ $i -ne 0 ] && log "$i additional auth request(s) due to no reply from API"
}
