#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "$PWD/../../lib/dash_functions.sh"
print_cgi_headers
print_nav_bar "Postfix|Activity" "postfix_queue|Queue"
source "$PWD/../../standalone/Postfix/postfix.conf"

for cloud in $CLOUDS ; do

  for pfcluster in `echo "$POSTFIX_CLUSTERS" | tr ',' ' '`; do
    open_cluster "$cloud|Queue Monitor"
      close_cluster_line
      print_dashlines postfix_queue folder "postfix_queue/$cloud/Queue Monitor"
    close_cluster
  done

done
