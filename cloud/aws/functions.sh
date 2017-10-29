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

SSLEX=`which openssl 2>/dev/null`
CURL=`which curl 2>/dev/null`
CURL="$CURL -s"

[ -z "$CLUSTER_TAG" ] && CLUSTER_TAG="cluster"
LOG="$M_ROOT/logs/cloud.log"

[ -n "$verbose" ] && debug=true || debug=false

aws_api_request() {
  ### aws_api_request {service} {version} {authmethod} {GET|POST} {endpoint} {action} <params>
  ### endpoint must not contain https://
  ### headers must be assigned to variable HEADERS. If it's empty, two basic
  ### headers are generated: host and x-amz-date
  ### payload (if present) must be assigned to variable PAYLOAD
  ### version is API version, e.g. 2016-11-15 (see API documentation)
  ### authmethod can be header or params
  # CanonicalRequest =
  # HTTPRequestMethod + '\n' +
  # CanonicalURI + '\n' +
  # CanonicalQueryString + '\n' +
  # CanonicalHeaders + '\n' +
  # SignedHeaders + '\n' +
  # HexEncode(Hash(RequestPayload))
  [ -z "$3" ] && log "Wrong number of parameters: aws_api_request $*" && return 1
  [ -z "$region" ] && log "region not specified" && return 2
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
  local endpoint
  endpoint=$1
  shift
  local action
  action=$1
  shift
  local params
  params="$@"
  timestamp=`date -u +"%Y%m%dT%H%M%SZ"`
  IFSORIG=$IFS
  
  CanonicalURI="/`echo "$endpoint" | cut -sd'/' -f2- | "$M_ROOT"/cloud/aws/urlencode`"
  qparams=`echo -e "Action=${action}\n$params\nVersion=$Version" | tr '&' '\n'`
  qparams=`echo -e -n "$qparams" | LC_COLLATE=C sort | grep -v ^$`
  IFS='
'
  for qpar in $qparams ; do
    qpar="`echo "$qpar" | cut -d'=' -f1 | "$M_ROOT"/cloud/aws/urlencode`=`echo "$qpar" | cut -sd'=' -f2 | "$M_ROOT"/cloud/aws/urlencode`"
    qparams1="${qparams1}\n${qpar}"
  done
  CanonicalQueryString=`echo -e "$qparams1" | grep -v ^$ | tr '\n' '&'`
  # grep adds newline at the end anyway
  CanonicalQueryString=${CanonicalQueryString%&}
  
  if [ -z "$HEADERS" ]; then
    HEADERS="Host: ${endpoint%%/*}\nX-Amz-Date: ${timestamp}"
  fi
  SortedHeaders=`echo -e "$HEADERS" | LC_COLLATE=C sort`
  for header in $SortedHeaders ; do
    headername=`echo "$header" | cut -sd':' -f1 | sed "s|^ ||;s| $||;s|  *| |g;s|\(.*\)|\L\1|g"`
    headervalue=`echo "$header" | cut -sd':' -f2 | sed "s|^ ||;s| $||;s|  *| |g"`
    if [ -z "$CanonicalHeaders" ]; then
      CanonicalHeaders="${headername}:${headervalue}"
    else
      CanonicalHeaders="${CanonicalHeaders}\n${headername}:${headervalue}"
    fi
  done
  IFS=$IFSORIG
  SignedHeaders=`echo -e "$CanonicalHeaders" | cut -d':' -f1`
  SignedHeaders=`echo -e "$SignedHeaders" | tr '\n' ';'`
  SignedHeaders="${SignedHeaders%;}"
  
  HashedPayload=`echo -n "$PAYLOAD" | $SSLEX dgst -sha256 | cut -sd' ' -f2`
  CanonicalRequest=`echo -e "$method\n$CanonicalURI\n$CanonicalQueryString\n$CanonicalHeaders\n\n$SignedHeaders\n$HashedPayload"`
  SignedRequest=`echo -n "$CanonicalRequest" | $SSLEX dgst -sha256 | cut -sd' ' -f2`
  thedate=`date -u +"%Y%m%d"`
  StringToSign=`echo -e "AWS4-HMAC-SHA256\n${timestamp}\n$thedate/$region/$service/aws4_request\n$SignedRequest"`
  
  # kSecret = your secret access key
  # kDate = HMAC("AWS4" + kSecret, Date)
  # kRegion = HMAC(kDate, Region)
  # kService = HMAC(kRegion, Service)
  # kSigning = HMAC(kService, "aws4_request")
  
  kDate=`echo -n "$thedate" | $SSLEX dgst -binary -sha256 -hmac "AWS4${AWS_SECRET_ACCESS_KEY}"`
  kRegion=`echo -n "$region" | $SSLEX dgst -binary -sha256 -hmac "$kDate"`
  kService=`echo -n "$service" | $SSLEX dgst -binary -sha256 -hmac "$kRegion"`
  kSigning=`echo -n "aws4_request" | $SSLEX dgst -binary -sha256 -hmac "$kService"`
  #signature=`echo -n "$StringToSign" | $SSLEX dgst -hex -sha256 -hmac "$kSigning" | cut -sd' ' -f2`
  signature=`echo -n "$StringToSign" | $SSLEX dgst -binary -sha256 -hmac "$kSigning" | od -An -t x1 -v | tr -d ' \n'`
  # querystring = Action=action
  # querystring += &X-Amz-Algorithm=algorithm
  # querystring += &X-Amz-Credential= urlencode(access_key_ID + '/' + credential_scope)
  # querystring += &X-Amz-Date=date
  # querystring += &X-Amz-Expires=timeout interval
  # querystring += &X-Amz-SignedHeaders=signed_headers
  
  if $debug ; then
    log "AUTH process interals:\n=== CanonicalQueryString:\n$CanonicalQueryString\n=== SortedHeaders:\n$SortedHeaders\n=== CanonicalHeaders:\n$CanonicalHeaders\n=== SignedHeaders:\n$SignedHeaders\n=== HashedPayload:\n$HashedPayload\n=== CanonicalRequest:\n$CanonicalRequest\n=== SignedRequest:\n$SignedRequest\n=== StringToSign:\n$StringToSign\n=== signature:\n$signature"
  fi
  if [ "_$authmethod" == "_header" ]; then
    AuthHeader="Authorization: AWS4-HMAC-SHA256 Credential=$AWS_ACCESS_KEY_ID/$thedate/$region/$service/aws4_request, SignedHeaders=${SignedHeaders}, Signature=$signature"
    SortedHeaders=`echo -e "$SortedHeaders\n$AuthHeader"`
    Query="${CanonicalQueryString}"
  else
    SignedHeaders=`echo -e "$SignedHeaders" | tr -d '\n' | "$M_ROOT"/cloud/aws/urlencode`
    Query="${CanonicalQueryString}&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=`echo -n "${AWS_ACCESS_KEY_ID}/$thedate/$region/$service/aws4_request" | "$fpath"/urlencode`&X-Amz-Date=${timestamp}&X-Amz-Expires=120&X-Amz-SignedHeaders=${SignedHeaders}&X-Amz-Signature=$signature"
  fi
  
  if [ "_$log_request" == "_yes" ]; then
    log "$CURL -vvv -X $method -H \"$SortedHeaders\" \"https://${endpoint}/?${Query}\""
    reqres=`$CURL -X $method -H "$SortedHeaders" "https://${endpoint}/?${Query}"`
    log "$reqres"
    echo "$reqres" | "$M_ROOT"/lib/xml2txt | grep -v ^$
  else
    $CURL -X $method -H "$SortedHeaders" "https://${endpoint}/?${Query}" | "$M_ROOT"/lib/xml2txt | grep -v ^$
  fi
  unset reqres Query SignedHeaders signature endpoint SortedHeaders thedate service timestamp CanonicalQueryString qpar header CanonicalRequest qparams1 CanonicalHeaders
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




