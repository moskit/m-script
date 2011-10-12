#!/bin/bash

echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""

rcommand=${0##*/}
rpath=${0%/*}
#*/

for cluster in ${rpath}/../servers/*
do
  echo "<div class=\"cluster\" id=\"${cluster##*/}\">"
  for server in $cluster/*
  do
    echo "<div class=\"server\" id=\"${server##*/}\">"
      cat "${server}/dash.html"
    echo "</div>"
  done
  echo "</div>"
done


exit 0
