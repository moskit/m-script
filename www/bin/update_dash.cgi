#!/bin/bash

echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""

for cluster in `find ../servers/* -maxdepth 0 -type d`
do
  echo "<div class=\"clustername\">${cluster##*/}</div>"
  echo "<div class=\"cluster\" id=\"${cluster##*/}\">"
  if [ "X${cluster##*/}" == "Xlocalhost" ] ; then
    server="localhost"
   
    echo "<div class=\"server\" id=\"${server##*/}\">"
      echo "<span class=\"servername\">${server##*/}</span>"
      cat "../servers/${server}/dash.html" 2>/dev/null || echo "No data"
    echo "</div>"
    echo "</div>"
    continue
  fi
  for server in `find $cluster/* -maxdepth 0 -type d | sort`
  do
    echo "<div class=\"server\" id=\"${server##*/}\">"
      echo "<span class=\"servername\">${server##*/}</span>"
      cat "../servers/${server}/dash.html" 2>/dev/null || echo "No data"
    echo "</div>"
  done
  echo "</div>"
done

exit 0

