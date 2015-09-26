#!/bin/bash

cat << "EOF"
Pragma: no-cache
Expires: 0
Content-Cache: no-cache
Content-type: text/html

EOF
updater="`echo $QUERY_STRING | tr '&' '\n' | grep '^updater' | sed 's@updater=@@;s@%2F@/@g;s@%20@ @g;s@%3A@:@g'`"
[ -z "$updater" ] && exit 1

if [ -e "$PWD/../preloaders/${updater}.html" ]; then
  cat "$PWD/../preloaders/${updater}.html" 2>/dev/null || exit 1
else
  cat "$PWD/../preloaders/default.html" 2>/dev/null || exit 1
fi
