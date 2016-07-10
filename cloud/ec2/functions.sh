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
callername=${callername##*/}

SSLEX=`which openssl 2>/dev/null`
CURL=`which curl 2>/dev/null`
CURL="$CURL -s -k"

[ -z "$CLUSTER_TAG" ] && CLUSTER_TAG="cluster"
LOG="$M_ROOT/logs/cloud.log"

[ -z "$CLOUD" ] && echo "No cloud defined" && exit 1
M_TEMP="$M_TEMP/cloud/$CLOUD"
[ -d "$M_TEMP" ] || install -d "$M_TEMP"

SignatureMethod=HmacSHA256
SignatureVersion=2
Version="2013-07-15"
AuthParams="SignatureMethod=${SignatureMethod}\nSignatureVersion=${SignatureVersion}\nVersion=${Version}"

ec2_api_request() {
  # ev2_api_request Action ParamString
  # where ParamString is an action-specific parameters. For example, for this
  # example from EC2 API documentation:
  # -----------
  # https://ec2.amazonaws.com/?Action=DescribeAddresses
  # &AllocationId.1= eipalloc-08229861
  # &AUTHPARAMS
  # -----------
  # ParamString would be "AllocationId.1=${your-var-from-caller-script}"
  timestamp=`date +"%Y-%m-%dT%H%%3A%M%%3A%S"`
  Params=`echo "$2" | tr '&' '\n'`
  qparams="$Params\n$AuthParams\nTimestamp=${timestamp}"
  qparams=`echo -e -n "$qparams" | sort | grep -v ^$ | tr '\n' '&'`
  query=`echo -n "AWSAccessKeyId=${AWS_ACCESS_KEY_ID}&Action=${1}&${qparams%&}"`
  Q=`echo -ne "GET\nec2.amazonaws.com\n/\n$query"`
  signature=`echo -n "$Q" | $SSLEX dgst -binary -sha256 -hmac "$AWS_SECRET_ACCESS_KEY" | base64 | "$M_ROOT"/lib/urlencode`
  if [ "_$log_request" == "_yes" ]; then
    log "$CURL \"https://ec2.amazonaws.com/?AWSAccessKeyId=${AWS_ACCESS_KEY_ID}&Action=${1}&${qparams}Signature=$signature\""
    reqres=`$CURL "https://ec2.amazonaws.com/?AWSAccessKeyId=${AWS_ACCESS_KEY_ID}&Action=${1}&${qparams}Signature=$signature"`
    log "$reqres"
    echo "$reqres" | "$M_ROOT"/lib/xml2txt | grep -v ^$ > "$M_TEMP/${callername}.resp"
  else
    $CURL "https://ec2.amazonaws.com/?AWSAccessKeyId=${AWS_ACCESS_KEY_ID}&Action=${1}&${qparams}Signature=$signature" | "$M_ROOT"/lib/xml2txt | grep -v ^$ > "$M_TEMP/${callername}.resp"
  fi
}

check_request_result() {
  reqparsed=`cat "$M_TEMP/${callername}.resp"`
  if [ `echo "$reqparsed" | wc -l` -eq 0 ]; then
    log "file $M_TEMP/${callername}.resp is empty"
    echo "ERROR: empty response" >&2
    return 1
  fi
  if [ `echo "$reqparsed" | grep -c Error` -ne 0 ]; then
    errmessage=`echo "$reqparsed" | grep Error | cut -d'|' -f2`
    log "request failed with error $errmessage"
    echo "ERROR: $errmessage" >&2
    return 1
  fi
  if [ -n "$@" ]; then
    for respelem in `echo $* | tr ',' ' '`; do
      echo "${respelem}: `echo "$reqparsed" | grep \"$respelem\" | cut -sd'|' -f2`"
    done
  fi
  return 0
}





