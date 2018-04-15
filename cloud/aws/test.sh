#!/bin/bash
fpath=$(readlink -f "$BASH_SOURCE")
fpath=${fpath%/*}
#*/
[ -z "$M_ROOT" ] && M_ROOT=$(readlink -f "$fpath/../")

caller=$(readlink -f "$0")
callername=${caller##*/}

SSLEX=`which openssl 2>/dev/null`
[ -z "$AWS_ACCESS_KEY_ID" ] && echo "AWS_ACCESS_KEY_ID not found!" && exit 1
[ -z "AWS_SECRET_ACCESS_KEY" ] && echo "AWS_SECRET_ACCESS_KEY not found!" && exit 1
region=$DEFAULT_REGION

aws_api_request() {
  ### aws_api_request {service} {GET|POST} {endpoint} {action} <params>
  ### endpoint must not contain https://
  ### headers must be assigned to variable HEADERS. If it's empty, two basic
  ### headers are generated: host and x-amz-date
  ### payload (if present) must be assigned to variable PAYLOAD
  # CanonicalRequest =
  # HTTPRequestMethod + '\n' +
  # CanonicalURI + '\n' +
  # CanonicalQueryString + '\n' +
  # CanonicalHeaders + '\n' +
  # SignedHeaders + '\n' +
  # HexEncode(Hash(RequestPayload))
  [ -z "$3" ] && log "Wrong number of parameters: aws_api_request $*" && return 1
  #SignatureMethod=HmacSHA256
  Version="2013-10-15"
  [ -z "$region" ] && log "region not specified" && return 2
  local service
  service=$1
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
  timestamp='20150830T123600Z'
  IFSORIG=$IFS

  CanonicalURI="/`echo "$endpoint" | cut -sd'/' -f2- | "$fpath"/urlencode`"

  qparams=`echo -e "Action=${action}\n$params\nVersion=$Version" | tr '&' '\n'`
  qparams=`echo -e -n "$qparams" | LC_COLLATE=C sort | grep -v ^$`
  IFS='
'
  for qpar in $qparams ; do
    qpar="`echo "$qpar" | cut -d'=' -f1 | "$fpath"/urlencode`=`echo "$qpar" | cut -sd'=' -f2 | "$fpath"/urlencode`"
    qparams1="${qparams1}\n${qpar}"
  done
  CanonicalQueryString=`echo -e "$qparams1" | grep -v ^$ | tr '\n' '&'`
  # grep adds newline at the end anyway
  CanonicalQueryString=${CanonicalQueryString%&}

echo "canonical_querystring = $CanonicalQueryString"

  if [ -z "$HEADERS" ]; then
    HEADERS="host:${endpoint%%/*}\nx-amz-date:${timestamp}"
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

echo -e "canonical_headers = $CanonicalHeaders"
  SignedHeaders=`echo -e "$CanonicalHeaders" | cut -d':' -f1`
  SignedHeaders=`echo -e "$SignedHeaders" | tr '\n' ';'`
  SignedHeaders="${SignedHeaders%;}"
echo "signed_headers = $SignedHeaders"

  HashedPayload=`echo -n "$PAYLOAD" | $SSLEX dgst -sha256 | cut -sd' ' -f2`
echo "payload_hash = $HashedPayload"

  CanonicalRequest=`echo -e "$method\n$CanonicalURI\n$CanonicalQueryString\n$CanonicalHeaders\n\n$SignedHeaders\n$HashedPayload"`
  SignedRequest=`echo -n "$CanonicalRequest" | $SSLEX dgst -sha256 | cut -sd' ' -f2`

echo "canonical_request = $CanonicalRequest"
echo "signed_request = $SignedRequest"

  thedate=$dateStamp
  StringToSign=`echo -e "AWS4-HMAC-SHA256\n${timestamp}\n$thedate/$region/$service/aws4_request\n$SignedRequest"`

echo "string_to_sign = $StringToSign"

  # kSecret = your secret access key
  # kDate = HMAC("AWS4" + kSecret, Date)
  # kRegion = HMAC(kDate, Region)
  # kService = HMAC(kRegion, Service)
  # kSigning = HMAC(kService, "aws4_request")

  kDate=`echo -n "$thedate" | $SSLEX dgst -binary -sha256 -hmac "AWS4${AWS_SECRET_ACCESS_KEY}"`
  #echo -n "$kDate" | od -An -t x1 -v | tr -d ' \n'
  #echo
  kRegion=`echo -n "$region" | $SSLEX dgst -binary -sha256 -hmac "$kDate"`
  #echo -n "$kRegion" | od -An -t x1 -v | tr -d ' \n'
  #echo
  kService=`echo -n "$service" | $SSLEX dgst -binary -sha256 -hmac "$kRegion"`
  #echo -n "$kService"  | od -An -t x1 -v | tr -d ' \n'
  #echo
  kSigning=`echo -n "aws4_request" | $SSLEX dgst -binary -sha256 -hmac "$kService"`
  #echo -n "$kSigning"  | od -An -t x1 -v | tr -d ' \n'
  #echo
  signature=`echo -n "$StringToSign" | $SSLEX dgst -binary -sha256 -hmac "$kSigning" | od -An -t x1 -v | tr -d ' \n'`

  echo

echo "signature = $signature"
#echo -n "$StringToSign" | $SSLEX dgst -hex -sha256 -hmac "$kSigning" | cut -sd' ' -f2
echo

# querystring = Action=action
  # querystring += &X-Amz-Algorithm=algorithm
  # querystring += &X-Amz-Credential= urlencode(access_key_ID + '/' + credential_scope)
  # querystring += &X-Amz-Date=date
  # querystring += &X-Amz-Expires=timeout interval
  # querystring += &X-Amz-SignedHeaders=signed_headers

  SignedHeaders=`echo -e "$SignedHeaders" | tr -d '\n' | "$fpath"/urlencode`
  Query="${CanonicalQueryString}&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=`echo -n "${AWS_ACCESS_KEY_ID}/$thedate/$region/$service/aws4_request" | "$fpath"/urlencode`&X-Amz-Date=${timestamp}&X-Amz-Expires=120&X-Amz-SignedHeaders=${SignedHeaders}&X-Amz-Signature=$signature"

  echo "https://${endpoint}?${Query}"

}

aws_api_request $@

python "$fpath"/test.py $@


