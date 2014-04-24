#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "$PWD/../../lib/dash_functions.sh"
print_cgi_headers
print_nav_bar "Postfix|Activity" "postfix_queue|Queue"

for cloud in $CLOUDS ; do
  open_cluster $cloud
  close_cluster

  for pfcluster in `echo "$POSTFIX_CLUSTERS" | tr ',' ' '`; do
    open_cluster "$pfcluster"
      close_cluster_line
      print_dashlines postfix_activity folder "postfix_activity/$cloud/Activity Monitor"
    close_cluster
  done

done
