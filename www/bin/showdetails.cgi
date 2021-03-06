#!/bin/bash

echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""
echo $QUERY_STRING >> "$PWD/../../logs/dashboard.log"
script=`echo $QUERY_STRING | tr '&' '\n' | grep '^script' | sed 's@script=@@;s@%2F@/@g;s@%20@ @g;s@%3A@:@g'`
cluster=`echo $QUERY_STRING | tr '&' '\n' | grep '^cluster' | sed 's@cluster=@@;s@%2F@/@g;s@%20@ @g;s@%3A@:@g'`
server=`echo $QUERY_STRING | tr '&' '\n' | grep '^server' | sed 's@server=@@;s@%2F@/@g;s@%20@ @g;s@%3A@:@g'`

if [ -f "$PWD/$script" ]; then
  "$PWD/$script" "$cluster" "$server" 2>>"$PWD/../../logs/dashboard.log"
else
  echo "ERROR script $PWD/$script not found" >> "$PWD/../../logs/dashboard.log"
fi
