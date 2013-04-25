#!/bin/bash

echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""
echo $QUERY_STRING >> "$PWD/../../logs/dashboard.log"
path="`echo $QUERY_STRING | tr '&' '\n' | grep '^path' | sed 's@path=@@;s@%2F@/@g;s@%20@ @g;s@%3A@:@g'`"
cat "$PWD/..$path" 2>> "$PWD/../../logs/dashboard.log" 

