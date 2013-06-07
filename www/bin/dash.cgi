#!/bin/bash

source "$PWD/../../lib/dash_functions.sh"

print_cgi_headers

print_timeline Cluster Server

for cluster in `find ../servers/* -maxdepth 0 -type d 2>/dev/null`
do
  echo "<div class=\"clustername\"><span class=\"indent\">${cluster##*/}</span></div>"
  echo "<div class=\"cluster\" id=\"${cluster##*/}\">"
  if [ "X${cluster##*/}" == "Xlocalhost" ] ; then
    echo "<div class=\"server\" id=\"localhost\">"
    
      echo "<span class=\"servername\" id=\"localhost_status\" onclick=\"showDetails('localhost_status','serverdetails')\">localhost</span>"
      
      cat "../servers/localhost/dash.html" 2>/dev/null || echo "No data"
    echo "</div>"
    echo "<div class=\"details\" id=\"localhost_details\"></div>"
    echo "</div>"
    continue
  fi
  for server in `find $cluster/* -maxdepth 0 -type d 2>/dev/null | sort`
  do
    echo "<div class=\"server\" id=\"${server##*/}\">"
      echo "<span class=\"servername\" id=\"${server##*/}_status\" onclick=\"showDetails('${server##*/}_status','serverdetails')\">${server##*/}</span>"
      cat "../servers/$server/dash.html" 2>/dev/null || echo "No data"
      [ -e "../servers/$server/notfound" ] && echo "<div class=\"chunk\"><div style=\"width:4px;height:4px;margin: 8px 3px 8px 3px;background-color: orange;\">&nbsp;</div></div>"
      [ -e "../servers/$server/stopped" ] && echo "<div class=\"chunk\"><div style=\"width:4px;height:4px;margin: 8px 3px 8px 3px;background-color: red;\">&nbsp;</div></div>"
    echo "</div>"
    echo "<div class=\"details\" id=\"${server##*/}_details\"></div>"
  done
  echo "</div>"
done

exit 0

