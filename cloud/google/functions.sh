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

fpath=$(readlink -f "$BASH_SOURCE")
fpath=${fpath%/*}
#*/
[ -z "$M_ROOT" ] && M_ROOT=$(readlink -f "$fpath/../")

caller=$(readlink -f "$0")
callername=${caller##*/}

CURL=`which curl 2>/dev/null`
[ -z "$CURL" ] && echo "curl not found" >&2 && exit 1
CURL="$CURL -s -k"
STAT=`which stat 2>/dev/null`
[ -z "$STAT" ] && echo "stat not found" >&2 && exit 1

[ -z "$CLUSTER_TAG" ] && CLUSTER_TAG="cluster"
LOG="$M_ROOT/logs/cloud.log"

[ -z "$CLOUD" ] && echo "No cloud defined" >&2 && exit 1
M_TEMP="$M_TEMP/cloud/$CLOUD"
[ -d "$M_TEMP" ] || install -d "$M_TEMP"

GCLOUD="$M_ROOT/lib/google-cloud-sdk/bin/gcloud"

install_sdk() {
  rm -r "$M_ROOT/lib/google-cloud-sdk"
  export CLOUDSDK_INSTALL_DIR="$M_ROOT/lib"
  export CLOUDSDK_CORE_DISABLE_PROMPTS=1
  $CURL "https://sdk.cloud.google.com" | /bin/bash
}

get_oath2_token() {
  reply_prev=`cat "$M_ROOT/keys/gcetoken" 2>/dev/null`
  expires_in=`echo "$reply_prev" | grep expires_in | cut -sd'|' -f2 | tr -d '"'`
  if [ -n "$expires_in" ]; then
    time_prev=`$STAT -c "%Z" "$M_ROOT/keys/gcetoken"`
    time_now=`date +"%s"`
    since_prev=`expr $time_now - $time_prev + 60`
  fi
  if [ $since_prev -lt $expires_in ] 2>/dev/null; then
    reply=$reply_prev
  else
    reply=`$CURL "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" -H "Metadata-Flavor: Google" | "$M_ROOT"/lib/json2txt`
    echo "$reply" > "$M_ROOT/keys/gcetoken"
  fi
  access_token=`echo "$reply" | grep access_token | cut -sd'|' -f2 | tr -d '"'`
  token_type=`echo "$reply" | grep token_type | cut -sd'|' -f2 | tr -d '"'`
  echo "$token_type $access_token"
}


