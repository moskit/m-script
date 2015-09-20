#!/bin/bash

scriptname=${0%.cgi}; scriptname=${scriptname##*/}

source "$PWD/../../lib/dash_functions.sh"
source "$PWD/../../conf/mon.conf"

print_cgi_headers
load_css "clouds.css"

clouds=( $CLOUD `cat "$M_ROOT/conf/clusters.conf" | grep -vE "^#|^[[:space:]]#" | cut -sd'|' -f12 | grep -v ^$ | grep -v "^${CLOUD}$" | sort | uniq` )

open_cluster "Events"
  close_cluster_line
  open_line "localhost"
    print_dashline "" folder "clouds/localhost"
  close_line
close_cluster

for cloud in ${clouds[*]} ; do
  open_cluster "Cloud: $cloud" ; close_cluster_line
  cat "$M_TEMP/cloud/$cloud/full.servers.list.html" 2>/dev/null
  close_cluster
done


