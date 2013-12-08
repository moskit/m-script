#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "$PWD/../../lib/dash_functions.sh"
print_cgi_headers
print_nav_bar "MongoDB|Servers" "sharding|Sharding" "collections|Collections" "mongo_logger|Log Monitor"
print_page_title "host:port" "Status" "Memory Res/Virt (Mbytes)" "Bandwidth In/Out (Mbytes/sec)" "Operations (N/sec)" "Locks Curr/Overall  (%)" "Not In RAM / Page Faults  (N/sec)"

print_mongo_server() {
  local clname="$1"
  local host=`echo "$2" | cut -d'|' -f1`
  local role=`echo "$2" | cut -d'|' -f4`
  port="${host##*:}"
  name="${host%:*}"
  nodeid="${name}:${port}|$clname"
  [ ${#name} -gt 14 ] && namep="${name:0:7}..${name:(-7)}" || namep=$name
  id="${name}_${port}"
  install -d "$PWD/../$scriptname/balancers/$id"
  [ -n "$port" ] && wport=`expr $port + 1000`
  
  report=`cat "$PWD/../../standalone/$scriptname/data/${name}:${port}.report" 2>/dev/null`
  rawdata=`cat "$PWD/../../standalone/$scriptname/data/${name}:${port}.dat" 2>/dev/null`
  
  echo "<div class=\"server\" id=\"${nodeid}\">"
  
    echo "<div class=\"servername clickable\" id=\"${nodeid}_name\" onClick=\"showData('${id}_name','/${scriptname}')\" title=\"${name}:${port}\">${namep}:${port}<span class=\"${role}\" title=\"${role}\">`echo $role 2>/dev/null | cut -b 1 | sed 's|.|\U&|'`</span><div id=\"data_${id}_name\" class=\"dhtmlmenu\" style=\"display: none\"></div></div>" 2>/dev/null
    echo "<div class=\"status status_short clickable\" id=\"${id}_http\" onclick=\"showURL('${id}_http','http://${name}:${wport}','${scriptname}')\">HTTP<div id=\"data_${id}_http\" class=\"dhtmlmenu\" style=\"display: none\"></div></div>"
    
    if [ "X`echo "$rawdata" | grep ^status\| | cut -d'|' -f2`" == "X1" ] ; then
      echo "<div class=\"status status_short statusok clickable\" id=\"${id}_status\" onclick=\"showDetails('${id}_status','mongostatus')\">OK</div>"
    else
      echo "<div class=\"status status_short statuserr clickable\" id=\"${id}_status\" onclick=\"showDetails('${id}_status','mongostatus')\">Error</div>"
    fi
    
    echo "<div class=\"status\" id=\"${id}_mem\">`echo "$rawdata" | grep ^memRes\| | cut -d'|' -f2` / `echo "$rawdata" | grep ^memVir\| | cut -d'|' -f2`</div>"
    
    bwinout=`echo "$report" | grep '^Bandwidth ' | cut -d':' -f2 | sed 's| *||g'`
    echo "<div class=\"status\" id=\"${id}_bw\">`echo "$bwinout" 2>/dev/null | head -1` / `echo "$bwinout" 2>/dev/null | tail -1`</div>" 2>/dev/null
    qps=`echo "$report" | grep '^Network requests per second' | cut -d':' -f2 | sed 's| *||g'`
    [ -n "$qps" ] || rps=`echo "$report" | grep '^Total' | awk '{print $2}'`
    
    echo "<div class=\"status clickable\" id=\"${id}_qps\" onclick=\"showDetails('${id}_qps','mongoqps')\">$qps</div>"
    
    locktime=`echo "$report" | grep '^Lock time ' | cut -d':' -f2 | sed 's| *||g'`
    echo "<div class=\"status clickable\" id=\"${id}_locks\" onclick=\"showDetails('${id}_locks','mongolocks')\">`echo "$locktime" 2>/dev/null | head -1` / `echo "$locktime" 2>/dev/null | tail -1`</div>" 2>/dev/null
    
    notinmemory=`echo "$report" | grep '^Records not found in memory' | cut -d':' -f2 | sed 's| *||g'`
    pagefaults=`echo "$report" | grep '^Page fault exceptions' | cut -d':' -f2 | sed 's| *||g'`
    echo "<div class=\"status clickable\" id=\"${id}_recstats\" onclick=\"showDetails('${id}_recstats','mongorecstats')\">`echo "$notinmemory" | head -1` / `echo "$pagefaults" | tail -1`</div>"
    
  echo "</div>"
  echo "<div class=\"details\" id=\"${nodeid}_details\"></div>"
}

IFS1=$IFS
IFS='
'
if [ `cat "$PWD/../../standalone/$scriptname/mongo_config_servers.list" 2>/dev/null | wc -l` -gt 0 ] ; then

  clustername="Configuration Servers"
  open_cluster "$clustername"
  close_cluster_line
  for s in `cat "$PWD/../../standalone/$scriptname/mongo_config_servers.list"` ; do
    print_mongo_server "$clustername" "$s"
  done
    
  close_cluster
  
# Standalone servers
elif [ `cat "$PWD/../../standalone/$scriptname/mongo_servers.list" 2>/dev/null | wc -l` -gt 0 ] ; then
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

if [ `cat "$PWD/../../standalone/$scriptname/mongo_mongos_servers.list" 2>/dev/null | wc -l` -gt 0 ] ; then

  clustername="Balancers"
  open_cluster "$clustername"
  close_cluster_line
  
    for s in `cat "$PWD/../../standalone/$scriptname/mongo_mongos_servers.list"` ; do
      print_mongo_server "$clustername" "$s"
    done
    
  close_cluster
  
fi
IFS=$IFS1

