#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "$PWD/../../lib/dash_functions.sh"
print_cgi_headers
print_nav_bar "Postfix|Activity" "postfix_queue|Queue"
source "$PWD/../../standalone/Postfix/postfix.conf"

print_timeline "Server"

if [ -n "$POSTFIX_CLUSTERS" ]; then
  for cloud in $CLOUDS ; do
    for pfcluster in `echo "$POSTFIX_CLUSTERS" | tr ',' ' '`; do
      open_cluster "$cloud|Activity Monitor"
        close_cluster_line
        print_dashlines postfix_activity folder "postfix_activity/$cloud/Activity Monitor"
      close_cluster
    done
  done
else
  open_cluster "localhost"
    close_cluster_line
    print_dashlines postfix_activity folder "postfix_activity"
  close_cluster
fi
