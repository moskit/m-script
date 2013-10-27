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


rcommand=${0##*/}
rpath=${0%/*}
[ -z "$M_ROOT" ] && M_ROOT=$(readlink -f "$rpath/../../")
#*/

SSH=`which ssh 2>/dev/null`
SSLEX=`which openssl 2>/dev/null`
CURL=`which curl 2>/dev/null`
CURL="$CURL -s"
[ -z "$SSH" ] && echo "Ssh utility not found, exiting..  " && exit 1
IFCFG=`which ifconfig 2>/dev/null`
# Normally needed for localhost only, and not always: depends on system.
# Hostnames of remote servers are obtained via ssh which is a login shell;
# this is why the variable below is not used for remote servers: you may
# have different OSes there with different paths to hostname utility.
HOSTNAME=`which hostname 2>/dev/null`
[ -z "$CLUSTER_TAG" ] && CLUSTER_TAG="cluster"
LOG="$M_ROOT/logs/cloud.log"

ec2_api_request() {
  action=$1
  shift
  filters=`echo "$*" | tr ' ' '&'`
  timestamp=`date +"%Y-%m-%dT%H%%3A%M%%3A%S"`
  query="AWSAccessKeyId=${AWS_ACCESS_KEY_ID}&Action=${action}`[ -n "$filters" ] && echo -n "&${filters}"`&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=${timestamp}&Version=2013-07-15"
  Q=`echo -ne "GET\nec2.amazonaws.com\n/\n$query"`
  signature=`echo -n "$Q"| $SSLEX dgst -binary -sha256 -hmac "$AWS_SECRET_ACCESS_KEY" | base64 | "$M_ROOT"/lib/urlencode`
  $CURL "https://ec2.amazonaws.com/?${query}&Signature=$signature"
}


