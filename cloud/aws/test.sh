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

python "$tpath"/test.py $@ $timestamp > "$tpath/test.py.log"


