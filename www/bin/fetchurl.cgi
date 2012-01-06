#!/bin/bash

echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""
echo ${QUERY_STRING} >> "${PWD}/../../dashboard.log"
url=`echo ${QUERY_STRING} | tr '&' '\n' | grep '^url' | sed 's@url=@@;s@%2F@/@g;s@%20@ @g;s@%3A@:@g'`
to=`echo ${QUERY_STRING} | tr '&' '\n' | grep '^to' | sed 's@to=@@;s@%2F@/@g;s@%20@ @g;s@%3A@:@g'`
fetch=`which curl 2>/dev/null` || fetch=`which links 2>/dev/null` || fetch=`which lynx 2>/dev/null`
[ -z "$fetch" ] && echo "Found nothing to fetch with. Please install one of: curl, links, lynx" >> "${PWD}/../../dashboard.log" && exit 1
case ${fetch##*/} in
  curl)
    $fetch -s "$url" > "${PWD}/..$to"
    ;;
  links|lynx)
    $fetch -dump "$url" > "${PWD}/..$to"
    ;;
esac

cat "${PWD}/../${to}" 2>> "${PWD}/../../dashboard.log" 

