#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
M_ROOT="$PWD/../../../"
source "$M_ROOT/lib/dash_functions.sh"
print_cgi_headers
print_nav_bar "Postfix|Activity" "Postfix/postfix_queue|Queue"
source "$M_ROOT/standalone/Postfix/postfix.conf"

print_timeline "Server"

if [ -n "$POSTFIX_CLUSTERS" ]; then
  for cloud in $CLOUDS ; do
    for pfcluster in `echo "$POSTFIX_CLUSTERS" | tr ',' ' '`; do
      open_cluster "$cloud|Queue Monitor"
        close_cluster_line
        print_dashlines postfix_queue folder "postfix_queue/$cloud/Queue Monitor"
      close_cluster
    done
  done
else
  open_cluster "localhost"
    close_cluster_line
    print_dashlines postfix_queue folder "postfix_queue"
  close_cluster
fi

