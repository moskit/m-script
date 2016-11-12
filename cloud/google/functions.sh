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
CURL="$CURL -s -k"

[ -z "$CLUSTER_TAG" ] && CLUSTER_TAG="cluster"
LOG="$M_ROOT/logs/cloud.log"

[ -z "$CLOUD" ] && echo "No cloud defined" && exit 1
M_TEMP="$M_TEMP/cloud/$CLOUD"
[ -d "$M_TEMP" ] || install -d "$M_TEMP"

GCLOUD="$M_ROOT/lib/google-cloud-sdk/bin/gcloud"

install_sdk() {
  rm -r "$M_ROOT/lib/google-cloud-sdk"
  export CLOUDSDK_INSTALL_DIR="$M_ROOT/lib"
  export CLOUDSDK_CORE_DISABLE_PROMPTS=1
  $CURL "https://sdk.cloud.google.com" | /bin/bash
}

get_nodes_list() {
  $GCLOUD compute instances list --format=json | "$M_ROOT"/lib/json2txt > "$M_TEMP"/${callername}.resp
}

