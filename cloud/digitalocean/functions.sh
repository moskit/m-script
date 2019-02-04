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
  action=$1
  shift
  local params
  [ -n "$@" ] && params="/?${@}"
  [ -z "$region" ] && log "region not specified" && return 2
  Headers="-H Content-Type: application/json -H Authorization: Bearer $DO_TOKEN"
  if [ "_$log_request" == "_yes" ]; then
    log "$CURL -vvv -X $method $Headers \"https://${DO_API}/$Version/${service}${params}\""
    reqres=`$CURL -X $method $Headers "https://${DO_API}/$Version/${service}${params}"`
    echo "$reqres" > "$M_TEMP/cloud/$CLOUD/${callername}.resp.${region}"
    echo "$reqres" | "$M_ROOT"/lib/xml2txt | grep -v ^$
  else
    $CURL -X $method $Headers "https://${DO_API}/$Version/${service}${params}" | "$M_ROOT"/lib/xml2txt | grep -v ^$
  fi
}




