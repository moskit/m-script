#!/bin/bash

source "$PWD/../../lib/dash_functions.sh"

print_cgi_headers

Size="Size/Tariff" ; Image="Source Image" ; Cloud="Cloud" ; Region="Region" ; Role="Deployment Role"

open_cluster "Cluster"
print_cluster_inline "Size" "Image" "Cloud" "Region" "Role"
close_cluster_line
print_timeline "Server"
close_cluster

echo -e "<div class=\"clustername\"><span class=\"indent\">localhost</span></div>\n<div class=\"cluster\" id=\"localhost\">\n<div class=\"server\" id=\"localhost\">\n<span class=\"servername\" id=\"localhost_status\" onclick=\"showDetails('localhost_status','serverdetails')\">localhost</span>"
cat "../servers/localhost/dash.html" 2>/dev/null || echo "No data"
echo -e "</div>\n<div class=\"details\" id=\"localhost_details\"></div>\n</div>\n</div>"

for cluster in `find ../servers/*/* -maxdepth 0 -type d 2>/dev/null`
do
  cld=`echo "$cluster" | cut -d'/' -f3`
  cls=`echo "$cluster" | cut -d'/' -f4`
  clsconf=`grep "|${cld}$" "$PWD/../../conf/clusters.conf" | grep "^$cls|"`
  size=`echo "$clsconf" | cut -d'|' -f5`
  sizeh=`cat "$M_TEMP/cloud/$cld/flavors.list" | grep ^$size\| | cut -d'|' -f2 | tr -d '"'`
  img=`echo "$clsconf" | cut -d'|' -f6`
  imgh=`cat "$M_TEMP/cloud/$cld/images.list"  | grep ^$img\| | cut -d'|' -f2 | tr -d '"'`
  region=`echo "$clsconf" | cut -d'|' -f3`
  role=`echo "$clsconf" | cut -d'|' -f10`
  open_cluster "${cld}|${cls}"
  print_cluster_inline "sizeh" "imgh" "cld" "region" "role"
  close_cluster_line
  #echo -e "<div class=\"clustername\"><span class=\"indent\">${cls}</span><span class=\"right_note\">Server size: $sizeh  Image: $imgh  Cloud: ${cld}</span></div>\n<div class=\"cluster\" id=\"${cls}_${cld}\">"

  for server in `find $cluster/* -maxdepth 0 -type d 2>/dev/null | sort`
  do
    serverh=${server##*/}
    echo -e "<div class=\"server\" id=\"$serverh\">\n<span class=\"servername\" id=\"${serverh}_status\" onclick=\"showDetails('${serverh}_status','serverdetails')\">${serverh:0:20}</span>"
      cat "../servers/$server/dash.html" 2>/dev/null || echo "No data"
      [ -e "../servers/$server/notfound" ] && echo "<div class=\"chunk\"><div style=\"width:4px;height:4px;margin: 8px 3px 8px 3px;background-color: orange;\">&nbsp;</div></div>"
      [ -e "../servers/$server/stopped" ] && echo "<div class=\"chunk\"><div style=\"width:4px;height:4px;margin: 8px 3px 8px 3px;background-color: red;\">&nbsp;</div></div>"
    echo -e "</div>\n<div class=\"details\" id=\"${serverh}_details\"></div>"
  done
  close_cluster
done

exit 0

