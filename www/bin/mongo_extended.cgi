#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "$PWD/../../lib/dash_functions.sh"
print_cgi_headers
print_nav_bar "MongoDB|Servers" "mongo_extended|Extended" "mongosharding|Sharding" "mongocollections|Collections" "mongologger|Log Monitor"
print_page_title "host:port" "Records scanned / (N/sec)" "Data in RAM, size (MB) / over seconds" "Index hit / access, (N/sec)" "Fastmod / Idhack / Scan-and-order, (N/sec)" "Replication ops, (N/sec)"

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
    
    scanned=`echo "$report" | grep '^Records scanned' | cut -d':' -f2`
    scanned=`expr "$scanned" : "^\ *\(.*[^ ]\)\ *$"`
    echo "<div class=\"status\" id=\"${nodeid}_scanned\">${scanned}</div>"
    
    inmemdd=`echo "$report" | grep '^Data size' | cut -d':' -f2`
    inmemdd=`expr "$inmemdd" : "^\ *\(.*[^ ]\)\ *$"`
    inmemsec=`echo "$report" | grep '^Over seconds' | cut -d':' -f2`
    inmemsec=`expr "$inmemsec" : "^\ *\(.*[^ ]\)\ *$"`
    echo "<div class=\"status\" id=\"${nodeid}_inmem\">${inmemdd} / ${inmemsec}</div>"
    
    indexhits=`echo "$report" | grep '^Index hits' | cut -d':' -f2`
    indexhits=`expr "$indexhits" : "^\ *\(.*[^ ]\)\ *$"`
    indexacc=`echo "$report" | grep '^Index accesses' | cut -d':' -f2`
    indexacc=`expr "$indexacc" : "^\ *\(.*[^ ]\)\ *$"`
    echo "<div class=\"status\" id=\"${nodeid}_index\">${indexhits} / ${indexacc}</div>"
    
    fastmod=`echo "$report" | grep '^Fastmod operations' | cut -d':' -f2`
    fastmod=`expr "$fastmod" : "^\ *\(.*[^ ]\)\ *$"`
    idhack=`echo "$report" | grep '^Idhack operations' | cut -d':' -f2`
    idhack=`expr "$idhack" : "^\ *\(.*[^ ]\)\ *$"`
    scanorder=`echo "$report" | grep '^Scan and order operations' | cut -d':' -f2`
    scanorder=`expr "$scanorder" : "^\ *\(.*[^ ]\)\ *$"`
    echo "<div class=\"status\" id=\"${nodeid}_oper\">${fastmod} / ${idhack} / ${scanorder}</div>"
    
    replops=`echo "$report" | grep '^Total' | cut -d':' -f2`
    replops=`expr "$replops" : "^\ *\(.*[^ ]\)\ *$"`
    echo "<div class=\"status\" id=\"${nodeid}_repl\">${replops}</div>"

  echo "</div>"
  echo "<div class=\"details\" id=\"${nodeid}_details\"></div>"
}

IFS1=$IFS
IFS='
'

# Standalone servers
if [ `cat "$PWD/../../standalone/MongoDB/mongo_servers.list" 2>/dev/null | wc -l` -gt 0 ] ; then
  clustername="MongoDB Servers"
  open_cluster "$clustername"
  close_cluster_line
    for rs in `cat "$PWD/../../standalone/MongoDB/mongo_servers.list" | cut -d'|' -f3 | sort | uniq` ; do
      echo "<div class=\"server hilited\" id=\"$rs\">"
      echo "<div class=\"servername\" id=\"${rs}_name\">Replica Set: ${rs}</div>"
      echo "</div>"
      for s in `cat "$PWD/../../standalone/MongoDB/mongo_servers.list" | grep "|$rs|"` ; do
        print_mongo_server "$clustername" "$s"
      done
    done
### Not members of any RS
    for s in `cat "$PWD/../../standalone/MongoDB/mongo_servers.list" | grep ^.*\|$` ; do
      print_mongo_server "$clustername" "$s"
    done
    
  close_cluster
  
fi

# Shard servers
if [ `cat "$PWD/../../standalone/MongoDB/mongo_shards.list" 2>/dev/null | wc -l` -gt 0 ] ; then

  clustername="Shard Servers"
  open_cluster "$clustername"
  close_cluster_line
    for rs in `cat "$PWD/../../standalone/MongoDB/mongo_shards.list" | cut -d'|' -f2 | sort | uniq` ; do
      echo "<div class=\"server hilited\" id=\"$rs\">"
      echo "<div class=\"servername\" id=\"${rs}_name\">Replica Set: ${rs}</div>"
      echo "</div>"
      for s in `cat "$PWD/../../standalone/MongoDB/mongo_shards.list" | grep "|$rs|"` ; do
        print_mongo_server "$clustername" "$s"
      done
    done
### Not members of any RS
    for s in `cat "$PWD/../../standalone/MongoDB/mongo_shards.list" | grep ^.*\|$` ; do
      print_mongo_server "$s"
    done
  close_cluster
  
fi
IFS=$IFS1

