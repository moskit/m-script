#!/bin/bash

source "$PWD/../../lib/dash_functions.sh"

print_cgi_headers

Size="Default size" ; Image="Source Image" ; Cloud="Cloud" ; Region="Region" ; Role="Default Role"

open_cluster "Cluster"
print_cluster_inline "Size" "Image" "Cloud" "Region" "Role"
close_cluster_line
print_timeline "Server"
close_cluster

# localhost first; if it belongs to a listed cluster, that cluster will be the first
for localip in `"$PWD"/../../helpers/localips | grep -v '127.0.0.1'` ; do
  localserver=`grep ^$localip\| "$PWD/../../nodes.list"`
  [ -z "$localserver" ] && continue
  localcluster=`echo "$localserver" | cut -d'|' -f5`
  localcloud=`echo "$localserver" | cut -d'|' -f6`
  localserver=`echo "$localserver" | cut -d'|' -f4`
  [ -n "$localserver" ] && break
done

if [ -z "$localcluster" ]; then
  echo -e "<div class=\"clustername\"><span class=\"indent\">localhost</span></div>\n<div class=\"cluster\" id=\"localhost\">\n<div class=\"server\" id=\"localhost\">\n<span class=\"servername clickable\" id=\"localhost_status\" onclick=\"showDetails('localhost_status','serverdetails')\">localhost</span>"
  cat "../nodes/localhost/dash.html" 2>/dev/null || echo "No data"
  echo -e "</div>\n<div class=\"details\" id=\"localhost_details\"></div>\n</div>\n</div>"
else
  [ -d "../nodes/$localcloud/$localcluster/$localserver" ] || install -d "../nodes/$localcloud/$localcluster/$localserver"
fi

for cluster in `find ../nodes/*/* -maxdepth 0 -type d 2>/dev/null`
do
  cld=`echo "$cluster" | cut -d'/' -f3`
  cls=`echo "$cluster" | cut -d'/' -f4`
  clsconf=`grep "|${cld}$" "$PWD/../../conf/clusters.conf" | grep "^$cls|"`
  if [ -f "$M_TEMP/cloud/$cld/flavors.list" ]; then
  size=`echo "$clsconf" | cut -d'|' -f5`
  sizeh=`cat "$M_TEMP/cloud/$cld/flavors.list" | grep ^$size\| | cut -d'|' -f2 | tr -d '"'`
  fi
  if [ -f "$M_TEMP/cloud/$cld/images.list" ]; then
  img=`echo "$clsconf" | cut -d'|' -f6`
  imgh=`cat "$M_TEMP/cloud/$cld/images.list"  | grep ^$img\| | cut -d'|' -f2 | tr -d '"'`
  fi
  region=`echo "$clsconf" | cut -d'|' -f3`
  role=`echo "$clsconf" | cut -d'|' -f10`
  open_cluster "${cld}|${cls}"
  print_cluster_inline "sizeh" "imgh" "cld" "region" "role"
  close_cluster_line
  unset sizeh imgh cld region role

  if [ "_$cls" == "_$localcluster" ] && [ "_$cld" == "_$localcloud" ]; then
    node="${cld}/${cls}|${localserver}"
    echo -e "<div class=\"server\" id=\"localhost\">\n<span class=\"servername clickable\" id=\"${node}_status\" onclick=\"showDetails('${node}_status','serverdetails')\" title=\"$localserver\">${localserver:0:20}</span>"
    cat "../nodes/localhost/dash.html" 2>/dev/null || echo "No data"
    [ -e "../nodes/localhost/notfound" ] && echo "<div class=\"chunk\"><div style=\"width:4px;height:4px;margin: 8px 3px 8px 3px;background-color: orange;\">&nbsp;</div></div>"
    [ -e "../nodes/localhost/stopped" ] && echo "<div class=\"chunk\"><div style=\"width:4px;height:4px;margin: 8px 3px 8px 3px;background-color: red;\">&nbsp;</div></div>"
    echo -e "</div>\n<div class=\"details\" id=\"${node}_details\"></div>"
  fi

  for server in `find $cluster/* -maxdepth 0 -type d 2>/dev/null | grep -v "^$cluster/$localserver$" | sort`
  do
    node="${cld}/${cls}|${server##*/}"
    serverh="${server##*/}"
    echo -e "<div class=\"server\" id=\"$node\">\n<span class=\"servername clickable\" id=\"${node}_status\" onclick=\"showDetails('${node}_status','serverdetails')\" title=\"$serverh\">${serverh:0:20}</span>"
      cat "../nodes/$server/dash.html" 2>/dev/null || echo "No data"
      [ -e "../nodes/$server/notfound" ] && echo "<div class=\"chunk\"><div style=\"width:4px;height:4px;margin: 8px 3px 8px 3px;background-color: orange;\">&nbsp;</div></div>"
      [ -e "../nodes/$server/stopped" ] && echo "<div class=\"chunk\"><div style=\"width:4px;height:4px;margin: 8px 3px 8px 3px;background-color: red;\">&nbsp;</div></div>"
    echo -e "</div>\n<div class=\"details\" id=\"${node}_details\"></div>"
  done
  close_cluster
done

exit 0

