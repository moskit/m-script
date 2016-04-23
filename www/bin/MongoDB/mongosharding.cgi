#!/bin/bash

saname="MongoDB"
scriptname=${0%.cgi}
scriptname=${scriptname##*/}
M_ROOT="$PWD/../../.."
source "$M_ROOT/lib/dash_functions.sh"

print_cgi_headers 
print_nav_bar "MongoDB|Servers" "MongoDB/mongo_extended|Extended" "MongoDB/mongosharding|Sharding" "MongoDB/mongocollections|Collections" "MongoDB/mongologger|Log Monitor"
print_page_title "Collection" "Status" "Count" "Data Size" "Size on Disk" "Index Size" "Chunks"

for db in `find "$M_ROOT/standalone/$saname/data" -mindepth 1 -maxdepth 1 -type f -name shards.*.* | sed "s|$M_ROOT/standalone/$saname/data/shards.||g" | cut -d'.' -f1 | sort | uniq | grep -v ^$` ; do

  [ -f "$M_ROOT/standalone/$saname/data/${db}.dat" ] || continue
  db_dat=`cat "$M_ROOT/standalone/$saname/data/${db}.dat"`
  total_ok=`echo "$db_dat" | grep ^0\/\"ok\"\| | cut -d'|' -f2`
  total_status=$([ "_$total_ok" == "_1" ] && echo "<font color=\"green\">OK</font>" || echo "<font color=\"red\">$total_ok</font>")
  total_count=`echo "$db_dat" | grep ^0\/\"objects\"\| | cut -d'|' -f2`
  total_datasize=`echo "$db_dat" | grep ^0\/\"dataSize\"\| | cut -d'|' -f2`
  total_storsize=`echo "$db_dat" | grep ^0\/\"storageSize\"\| | cut -d'|' -f2`
  total_indexsize=`echo "$db_dat" | grep ^0\/\"indexSize\"\| | cut -d'|' -f2`
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
  total_chunks=`echo "$db_dat" | grep ^0\/\"nchunks\"\| | cut -d'|' -f2`
  
  open_cluster "$db"
  
  print_cluster_inline "total_status" "total_count" "total_datasize" "total_storsize" "total_indexsize" "total_chunks"
  close_cluster_line "$db"
  
  for coll in "$M_ROOT/standalone/$saname/data"/shards.${db}.* ; do
    coll=`echo "$coll" | sed "s|$M_ROOT/standalone/$saname/data/shards.${db}.||"`
    open_line "$coll" MongoDB/shards
    if [ -f "$M_ROOT/standalone/$saname/data/${db}.${coll}.dat" ]; then
      for d in `cat "$M_ROOT/standalone/$saname/data/${db}.${coll}.dat"` ; do
        eval "`echo "$d"`"
      done

      coll_size=`expr $coll_size / 1048576`
      csunits="MB"
      if [ ${#coll_size} -gt 3 ] ; then
        coll_size=`expr $coll_size / 1024` && csunits="GB"
        coll_storsize="`expr $coll_storsize / 1073741824` $csunits"
        coll_indexsize="`expr $coll_indexsize / 1073741824` $csunits"
      else
        coll_storsize="`expr $coll_storsize / 1048576` $csunits"
        coll_indexsize="`expr $coll_indexsize / 1048576` $csunits"
      fi
      coll_size="$coll_size $csunits"
      coll_status=$([ "_$coll_ok" == "_1" ] && echo "<font color=\"green\">OK</font>" || echo "<font color=\"red\">$coll_ok</font>")
    else
      coll_status="-"
      coll_count="-"
      coll_size="-"
      coll_storsize="-"
      coll_indexsize="-"
      coll_chunks="-"
    fi
    print_inline "coll_status" "coll_count" "coll_size" "coll_storsize" "coll_indexsize" "coll_chunks"
    close_line
  done
  close_cluster
done
echo "<br/>"
print_timeline "Sharding Events"
open_cluster "All Shards"
  close_cluster_line
  print_dashlines "mongo_shards"
close_cluster

