#!/bin/bash
tpath=$(readlink -f "$BASH_SOURCE")
tpath=${tpath%/*}
#*/
[ -z "$M_ROOT" ] && M_ROOT=$(readlink -f "$tpath/../")

caller=$(readlink -f "$0")
callername=${caller##*/}
debug=true
LOG="$M_ROOT/logs/cloud.log"
verbose="yes"
log_request="yes"

[ -z "$AWS_ACCESS_KEY_ID" ] && echo "AWS_ACCESS_KEY_ID not found!" && exit 1
[ -z "AWS_SECRET_ACCESS_KEY" ] && echo "AWS_SECRET_ACCESS_KEY not found!" && exit 1
region=$DEFAULT_REGION

source "$M_ROOT/lib/functions.sh"
source "$tpath/functions.sh"

aws_api_request $@ > "$tpath/test.sh.log"

echo "canonical_querystring = $CanonicalQueryString"
echo -e "canonical_headers = $CanonicalHeaders"
echo "signed_headers = $SignedHeaders"
echo "payload_hash = $HashedPayload"
echo "canonical_request = $CanonicalRequest"
echo "signed_request = $SignedRequest"
echo "string_to_sign = $StringToSign"
echo "signature = $signature"
#echo -n "$StringToSign" | $SSLEX dgst -hex -sha256 -hmac "$kSigning" | cut -sd' ' -f2
echo
echo "https://${endpoint}?${Query}"

python "$tpath"/test.py $@> "$tpath/test.py.log"


