#!/bin/bash
# Copyright (C) 2018 Igor Simonov (me@igorsimonov.com)
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

fpath=$(readlink -f "$BASH_SOURCE")
fpath=${fpath%/*}
#*/
[ -z "$M_ROOT" ] && M_ROOT=$(readlink -f "$fpath/../")
[ -z "$CLOUD" ] && echo "No cloud defined" >&2 && exit 1
caller=$(readlink -f "$0")
callername=${caller##*/}
CURL=`which curl 2>/dev/null`
[ -z "$CURL" ] && echo "curl not found" >&2 && exit 1
CURL="$CURL -s -k"
STAT=`which stat 2>/dev/null`
[ -z "$STAT" ] && echo "stat not found" >&2 && exit 1
LOG="$M_ROOT/logs/cloud.log"
[ -d "$M_TEMP/cloud/$CLOUD" ] || install -d "$M_TEMP/cloud/$CLOUD"
VERSION="v$API_VERSION"

do_api_request() {
  ### do_api_request {service} {version} {authmethod} {httpmethod} {postbody} <params>
  [ -z "$4" ] && log "Wrong number of parameters: do_api_request $*" && return 1
  local service
  service=$1
  shift
  local Version
  Version=$1
  shift
  local authmethod
  authmethod=$1
  shift
  local method
  method=$1
  shift
  local postbody
  postbody=$1
  shift
  local params
  [ -n "$@" ] && params="/?${@}"
  Headers="Content-Type: application/json
Authorization: Bearer $DO_TOKEN"
  if [ "_$method" == "_POST" ]; then
    local apirequest="$CURL -X $method -H \"$Headers\" \"https://${DO_API}/$Version/${service}${params}\" -d '$postbody'"
  fi
  if [ "_$log_request" == "_yes" ]; then
    log "$apirequest"
  fi
  $apirequest || "$M_ROOT"/lib/json2txt | grep -v ^$
}




