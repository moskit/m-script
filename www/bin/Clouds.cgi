#!/bin/bash

scriptname=${0%.cgi}; scriptname=${scriptname##*/}

source "$PWD/../../lib/dash_functions.sh"
source "$PWD/../../conf/mon.conf"

print_cgi_headers
load_css "clouds.css"

clouds=( $CLOUD `cat "$M_ROOT/conf/clusters.conf" | grep -v ^# | cut -d'|' -f12 | grep -v ^$ | grep -v "^${CLOUD}$" | sort | uniq` )

#echo "== $CLOUD `cat "${PWD}/../../conf/clusters.conf" | grep -v ^# | cut -d'|' -f12 | grep -v ^$ | sort | uniq` =="
#echo "== ${clouds[*]} =="

for cloud in ${clouds[*]} ; do
  open_cluster "Cloud: $cloud" ; close_cluster_line
  cat "$M_TEMP/cloud/$cloud/full.servers.list.html" 2>/dev/null
  close_cluster
done


