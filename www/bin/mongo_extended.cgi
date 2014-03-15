#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "$PWD/../../lib/dash_functions.sh"
print_cgi_headers
print_nav_bar "MongoDB|Servers" "mongo_extended|Extended" "mongosharding|Sharding" "mongocollections|Collections" "mongologger|Log Monitor"
print_page_title "host:port" "Status" "Memory Res/Virt (Mbytes)" "Bandwidth In/Out (Mbytes/sec)" "Operations (N/sec)" "Locks Curr/Overall  (%)" "Not In RAM / Page Faults  (N/sec)"

print_mongo_server() {
  local clname="$1"
  local host=`echo "$2" | cut -d'|' -f1`
  local role=`echo "$2" | cut -d'|' -f4`
  port="${host##*:}"
  name="${host%:*}"
  nodeid="$clname|${name}:${port}"
  [ ${#name} -gt 14 ] && namep="${name:0:7}..${name:(-7)}" || namep=$name
  [ -d "$PWD/../MongoDB/$clname/${name}:${port}" ] && install -d "$PWD/../MongoDB/$clname/${name}:${port}"
  [ -n "$port" ] && wport=`expr $port + 1000`
  
  report=`cat "$PWD/../../standalone/MongoDB/data/${name}:${port}.ext.report" 2>/dev/null`
  rawdata=`cat "$PWD/../../standalone/MongoDB/data/${name}:${port}.ext.dat" 2>/dev/null`
  
  echo "<div class=\"server\" id=\"${nodeid}\">"
  
    echo "<div class=\"servername clickable\" id=\"${nodeid}_name\" onClick=\"showData('${nodeid}_name','/${scriptname}')\" title=\"${name}:${port}\">${namep}:${port}<span class=\"${role}\" title=\"${role}\">`echo $role 2>/dev/null | cut -b 1 | sed 's|.|\U&|'`</span><div id=\"data_${nodeid}_name\" class=\"dhtmlmenu\" style=\"display: none\"></div></div>" 2>/dev/null
   
    bwinout=`echo "$report" | grep '^Bandwidth ' | cut -d':' -f2 | sed 's| *||g'`
    echo "<div class=\"status\" id=\"${nodeid}_bw\">`echo "$bwinout" 2>/dev/null | head -1` / `echo "$bwinout" 2>/dev/null | tail -1`</div>" 2>/dev/null
    qps=`echo "$report" | grep '^Network requests per second' | cut -d':' -f2 | sed 's| *||g'`
    [ -n "$qps" ] || rps=`echo "$report" | grep '^Total' | awk '{print $2}'`
    
    echo "<div class=\"status clickable\" id=\"${nodeid}_qps\" onclick=\"showDetails('${nodeid}_qps','mongoqps')\">$qps</div>"
    
    locktime=`echo "$report" | grep '^Lock time ' | cut -d':' -f2 | sed 's| *||g'`
    echo "<div class=\"status clickable\" id=\"${nodeid}_locks\" onclick=\"showDetails('${nodeid}_locks','mongolocks')\">`echo "$locktime" 2>/dev/null | head -1` / `echo "$locktime" 2>/dev/null | tail -1`</div>" 2>/dev/null
    
    notinmemory=`echo "$report" | grep '^Records not found in memory' | cut -d':' -f2 | sed 's| *||g'`
    pagefaults=`echo "$report" | grep '^Page fault exceptions' | cut -d':' -f2 | sed 's| *||g'`
    echo "<div class=\"status clickable\" id=\"${nodeid}_recstats\" onclick=\"showDetails('${nodeid}_recstats','mongorecstats')\">`echo "$notinmemory" | head -1` / `echo "$pagefaults" | tail -1`</div>"
    
  echo "</div>"
  echo "<div class=\"details\" id=\"${nodeid}_details\"></div>"
}

IFS1=$IFS
IFS='
'

# Standalone servers
if [ `cat "$PWD/../../standalone/$scriptname/mongo_servers.list" 2>/dev/null | wc -l` -gt 0 ] ; then
  clustername="MongoDB Servers"
  open_cluster "$clustername"
  close_cluster_line
    for rs in `cat "$PWD/../../standalone/$scriptname/mongo_servers.list" | cut -d'|' -f3 | sort | uniq` ; do
      echo "<div class=\"server hilited\" id=\"$rs\">"
      echo "<div class=\"servername\" id=\"${rs}_name\">Replica Set: ${rs}</div>"
      echo "</div>"
      for s in `cat "$PWD/../../standalone/$scriptname/mongo_servers.list" | grep "|$rs|"` ; do
        print_mongo_server "$clustername" "$s"
      done
    done
### Not members of any RS
    for s in `cat "$PWD/../../standalone/$scriptname/mongo_servers.list" | grep ^.*\|$` ; do
      print_mongo_server "$clustername" "$s"
    done
    
  close_cluster
  
fi

# Shard servers
if [ `cat "$PWD/../../standalone/$scriptname/mongo_shards.list" 2>/dev/null | wc -l` -gt 0 ] ; then

  clustername="Shard Servers"
  open_cluster "$clustername"
  close_cluster_line
    for rs in `cat "$PWD/../../standalone/$scriptname/mongo_shards.list" | cut -d'|' -f2 | sort | uniq` ; do
      echo "<div class=\"server hilited\" id=\"$rs\">"
      echo "<div class=\"servername\" id=\"${rs}_name\">Replica Set: ${rs}</div>"
      echo "</div>"
      for s in `cat "$PWD/../../standalone/$scriptname/mongo_shards.list" | grep "|$rs|"` ; do
        print_mongo_server "$clustername" "$s"
      done
    done
### Not members of any RS
    for s in `cat "$PWD/../../standalone/$scriptname/mongo_shards.list" | grep ^.*\|$` ; do
      print_mongo_server "$s"
    done
  close_cluster
  
fi
IFS=$IFS1

