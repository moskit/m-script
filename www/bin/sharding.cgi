#!/bin/bash

saname="MongoDB"
scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "${PWD}/../../lib/dash_functions.sh"

print_cgi_headers
print_nav_bar "MongoDB|Servers" "sharding|Sharding" "collections|Collections"
print_page_title "Collection" "Status" "Count" "Data Size" "Size on Disk" "Index Size" "Chunks"
for db in `find "${PWD}/../../standalone/${saname}/data" -mindepth 1 -maxdepth 1 -type f -name shards.*.* | sed "s|${PWD}/../../standalone/${saname}/data/shards.||" | cut -d'.' -f1 | sort | uniq` ; do
  db_dat="${PWD}/../../standalone/${saname}/data"/${db}.dat
  total_ok=`cat "$db_dat" | grep ^1\/ok\| | cut -d'|' -f2`
  total_status=$([ "X$total_ok" == "X1" ] && echo "<font color=\"green\">OK</font>" || echo "<font color=\"red\">$total_ok</font>")
  total_count=`cat $db_dat | grep ^1\/count\| | cut -d'|' -f2`
  total_datasize=`cat $db_dat | grep ^1\/size\| | cut -d'|' -f2`
  total_storsize=`cat $db_dat | grep ^1\/storageSize\| | cut -d'|' -f2`
  total_indexsize=`cat $db_dat | grep ^1\/totalIndexSize\| | cut -d'|' -f2`

  total_datasize=`expr $total_datasize / 1048576`
  csunits="MB"
  if [ ${#coll_size} -gt 3 ] ; then
    total_datasize=`expr $total_datasize / 1024` && csunits="GB"
    total_storsize="`expr $total_storsize / 1073741824` $csunits"
    total_indexsize="`expr $total_indexsize / 1073741824` $csunits"
  else
    total_storsize="`expr $total_storsize / 1048576` $csunits"
    total_indexsize="`expr $total_indexsize / 1048576` $csunits"
  fi
  total_datasize="$total_datasize $csunits"
  total_chunks=`cat $db_dat | grep ^1\/nchunks\| | cut -d'|' -f2`
  
  print_cluster_header "$db"
  print_inline "total_status" "total_count" "total_datasize" "total_storsize" "total_indexsize" "total_chunks"
  close_line  "$db"
  
  for coll in "${PWD}/../../standalone/${saname}/data"/shards.${db}.* ; do
    coll_dat="${PWD}/../../standalone/${saname}/data"/${db}.${coll}.dat
    coll=`echo $coll | sed "s|${PWD}/../../standalone/${saname}/data/shards.${db}.||"`
    print_line_title shards "$coll"
    coll_ok=`cat $coll_dat | grep ^1\/ok\| | cut -d'|' -f2`
    coll_status=$([ "X$coll_ok" == "X1" ] && echo "<font color=\"green\">OK</font>" || echo "<font color=\"red\">$coll_ok</font>")
    coll_count=`cat $coll_dat | grep ^1\/count\| | cut -d'|' -f2`
    coll_size=`cat $coll_dat | grep ^1\/size\| | cut -d'|' -f2`
    stor_size=`cat $coll_dat | grep ^1\/storageSize\| | cut -d'|' -f2`
    coll_indexsize=`cat $coll_dat | grep ^1\/totalIndexSize\| | cut -d'|' -f2`

    coll_size=`expr $coll_size / 1048576`
    csunits="MB"
    if [ ${#coll_size} -gt 3 ] ; then
      coll_size=`expr $coll_size / 1024` && csunits="GB"
      stor_size="`expr $stor_size / 1073741824` $csunits"
      coll_indexsize="`expr $coll_indexsize / 1073741824` $csunits"
    else
      stor_size="`expr $stor_size / 1048576` $csunits"
      coll_indexsize="`expr $coll_indexsize / 1048576` $csunits"
    fi
    coll_size="$coll_size $csunits"
    coll_chunks=`cat $coll_dat | grep ^1\/nchunks\| | cut -d'|' -f2`

    print_inline "coll_status" "coll_count" "coll_size" "stor_size" "coll_indexsize" "coll_chunks"
    close_line "$coll"
  done
  print_cluster_bottom
done
