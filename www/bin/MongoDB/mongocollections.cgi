#!/bin/bash

M_ROOT="$PWD/../../.."
source "$M_ROOT/lib/dash_functions.sh"
cgi_begin

print_nav_bar "MongoDB|Servers" "MongoDB/mongo_extended|Extended" "MongoDB/mongosharding|Sharding" "MongoDB/mongocollections|Collections" "MongoDB/mongologger|Log Monitor"
print_page_title "Collection" "Status" "Type" "Records" "Data Size" "Index Size" "Storage Size"

[ -f "$M_ROOT/standalone/$saname/data/databases.dat" ] || exit 0
source "$M_ROOT/standalone/$saname/mongo_databases.conf"
ignored=`echo "$IGNORED_DBS" | tr ',' ' '`
ignored=`echo "$ignored" | tr ' ' '\n' | grep -v ^$`

for dbname in `cat "$M_ROOT/standalone/$saname/data/databases.dat" | cut -d'|' -f2 | sort | uniq` ; do
  echo "$ignored" | grep -q "^${dbname}$" && continue
  
  [ -f "$M_ROOT/standalone/$saname/data/${dbname}.dat" ] || continue
  db_dat=`cat "$M_ROOT/standalone/$saname/data/${dbname}.dat"`
  total_count=`echo "$db_dat" | grep ^0\/\"objects\"\| | cut -d'|' -f2`
  [ "_$total_count" == "_0" ] && continue
  total_datasize=`echo "$db_dat" | grep ^0\/\"dataSize\"\| | cut -d'|' -f2`
  total_ok=`echo "$db_dat" | grep ^0\/\"ok\"\| | cut -d'|' -f2`
  total_status=$([ "_$total_ok" == "_1" ] && echo "<font color=\"green\">OK</font>" || echo "<font color=\"red\">$total_ok</font>")
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
  
  open_cluster "$dbname"
  
  print_cluster_inline "total_status" "-" "total_count" "total_datasize" "total_indexsize" "total_storsize"
  close_cluster_line
  
  for coll in "$M_ROOT/standalone/$saname/data"/${dbname}.*.dat ; do
    for d in `cat "$coll"` ; do
      eval "`echo "$d"`"
    done
    
    [ -z "$coll_name" ] && continue
    coll_name=${coll_name#*.}
    open_line "$coll_name" "MongoDB/indexes"

    coll_status=$([ "_$coll_ok" == "_1" ] && echo "<font color=\"green\">OK</font>" || echo "<font color=\"red\">$coll_ok</font>")

    coll_size=`expr $coll_size / 1024`
    csunits="KB"
    if [ ${#coll_size} -gt 3 ] ; then
      coll_size=`expr $coll_size / 1024` && csunits="MB"
    elif [ ${#coll_size} -gt 6 ] ; then
      coll_size=`expr $coll_size / 1048576` && csunits="GB"
    fi
    coll_size="$coll_size $csunits"
    
    coll_indexsize=`expr $coll_indexsize / 1024`
    csunits="KB"
    if [ ${#coll_indexsize} -gt 3 ] ; then
      coll_indexsize=`expr $coll_indexsize / 1024` && csunits="MB"
    elif [ ${#coll_indexsize} -gt 6 ] ; then
      coll_indexsize=`expr $coll_indexsize / 1048576` && csunits="GB"
    fi
    coll_indexsize="$coll_indexsize $csunits"
    
    coll_storsize=`expr $coll_storsize / 1024`
    csunits="KB"
    if [ ${#coll_storsize} -gt 3 ] ; then
      coll_storsize=`expr $coll_storsize / 1024` && csunits="MB"
    elif [ ${#coll_storsize} -gt 6 ] ; then
      coll_storsize=`expr $coll_storsize / 1048576` && csunits="GB"
    fi
    coll_storsize="$coll_storsize $csunits"
    [ "_$coll_capped" == "_undefined" ] && coll_capped=false
    coll_type=$($coll_sharded && echo -n "<span class=\"colltype\">SH</span>"; $coll_capped && echo -n "<span class=\"colltype\">C</span>")
    print_inline "coll_status" "coll_type" "coll_count|MongoDB/mongo_coll_count_graph" "coll_size|MongoDB/mongo_coll_size_graph" "coll_indexsize|MongoDB/mongo_coll_indexsize_graph" "coll_storsize"
    close_line "$coll_name"
    
  done
  close_cluster
done

cgi_end
