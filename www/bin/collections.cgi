#!/bin/bash

saname="MongoDB"
scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "${PWD}/../../lib/dash_functions.sh"

print_cgi_headers
print_nav_bar "MongoDB|Servers" "sharding|Sharding" "collections|Collections" "mongo_logger|Log Monitor"
print_page_title "Collection" "Status" "Primary" "Sharded" "Count" "Data Size" "Index Size"

[ -f "${PWD}/../../standalone/$saname/data/databases.dat" ] || exit 0

for db in `cat "${PWD}/../../standalone/$saname/data/databases.dat"` ; do
  dbname=${db%|*}
  #dbsize=${db#*|}  # It's a files total size
  
  db_dat="${PWD}/../../standalone/${saname}/data"/${dbname}.dat
  [ -f "$db_dat" ] || continue
  total_datasize=`cat $db_dat | grep ^0\/dataSize\| | cut -d'|' -f2`
  [ "X$total_datasize" == "X0" ] && continue
  total_ok=`cat "$db_dat" | grep ^0\/ok\| | cut -d'|' -f2`
  total_status=$([ "X$total_ok" == "X1" ] && echo "<font color=\"green\">OK</font>" || echo "<font color=\"red\">$total_ok</font>")
  total_count=`cat $db_dat | grep ^0\/objects\| | cut -d'|' -f2`
  
  total_storsize=`cat $db_dat | grep ^0\/storageSize\| | cut -d'|' -f2`
  total_indexsize=`cat $db_dat | grep ^0\/indexSize\| | cut -d'|' -f2`
  total_datasize=`expr $total_datasize / 1048576`
  csunits="MB"
  
  if [ ${#total_datasize} -gt 3 ] ; then
    total_datasize=`expr $total_datasize / 1024` && csunits="GB"
    total_storsize="`expr $total_storsize / 1073741824` $csunits"
    total_indexsize="`expr $total_indexsize / 1073741824` $csunits"
  else
    total_storsize="`expr $total_storsize / 1048576` $csunits"
    total_indexsize="`expr $total_indexsize / 1048576` $csunits"
  fi
  
  total_datasize="$total_datasize $csunits"
  total_chunks=`cat $db_dat | grep ^0\/nchunks\| | cut -d'|' -f2`
  
  open_cluster databases "$dbname"
  
  print_cluster_inline "total_status" "" "" "total_count" "total_datasize" "total_indexsize"
  close_cluster_line "$dbname"
  
  for coll in "${PWD}/../../standalone/$saname/data"/${dbname}.*.dat ; do
    collinfo=`cat "$coll"`
    coll_name=`echo "$collinfo" | grep ^0\/ns\| | cut -d'|' -f2`
    coll_name=${coll_name#*.}
    print_line_title indexes "$coll_name"
    coll_ok=`echo "$collinfo" | grep ^0\/ok\| | cut -d'|' -f2`
    coll_status=$([ "X$coll_ok" == "X1" ] && echo "<font color=\"green\">OK</font>" || echo "<font color=\"red\">$coll_ok</font>")
    coll_sharded=`echo "$collinfo" | grep ^0\/sharded\| | cut -d'|' -f2`
    coll_primary=`echo "$collinfo" | grep ^0\/primary\| | cut -d'|' -f2`
    coll_count=`echo "$collinfo" | grep ^0\/count\| | cut -d'|' -f2`
    coll_size=`echo "$collinfo" | grep ^0\/size\| | cut -d'|' -f2`
    coll_indexsize=`echo "$collinfo" | grep ^0\/totalIndexSize\| | cut -d'|' -f2`

    coll_size=`expr $coll_size / 1048576`
    csunits="MB"
    if [ ${#coll_size} -gt 3 ] ; then
      coll_size=`expr $coll_size / 1024` && csunits="GB"
      coll_indexsize="`expr $coll_indexsize / 1073741824` $csunits"
    else
      coll_indexsize="`expr $coll_indexsize / 1048576` $csunits"
    fi
    coll_size="$coll_size $csunits"
    
    print_inline "coll_status" "coll_sharded" "coll_primary" "coll_count" "coll_size" "coll_indexsize"
    close_line "$coll_name"
    
  done
  close_cluster
done

