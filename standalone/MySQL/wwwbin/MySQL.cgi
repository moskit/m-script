#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "$PWD/../../lib/dash_functions.sh"
source "$PWD/../../lib/cloud_functions.sh"
source "$PWD/../../standalone/MySQL/mysql.conf"

print_cgi_headers
print_nav_bar "MySQL|Performance" "MySQL/resources|Resources" "MySQL/databases|Data" "MySQL/logreader|Logs"

print_page_title "Node" "Queries / sec" "Connections / sec" "Cache hits ratio, %" "Table locks waited, %" "Threads active" "Threads created / sec"

for dbcl in `echo "$dbcluster" | tr ',' ' '`; do

  open_cluster "$dbcl"
  close_cluster_line
  
  for dbh in `"$PWD"/../../cloud/common/get_ips --names --cluster=$dbcl` ; do

    source "$PWD/../../standalone/MySQL/${dbh}.dat"
    open_line "$dbh"
    print_inline "qps|MySQL/qps" "connps|MySQL/connps" "qcachehitsratio|MySQL/cache" "locksratio|MySQL/locks" "Threads_connected|MySQL/threads" "threadsps|MySQL/threadsps"
    close_line
    
  done
  
  close_cluster
  
done

for dbcl in `echo "$dbcluster" | tr ',' ' '`; do

  open_cluster "$dbcl"
  close_cluster_line
  print_dashlines "mysqlstatus"
  close_cluster
  
done
