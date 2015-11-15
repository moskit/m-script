#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
M_ROOT="$PWD/../../.."
source "$M_ROOT/lib/dash_functions.sh"
source "$M_ROOT/standalone/MongoDB/mongo_servers.conf"
if [ "_$DBENGINE" == "_WT" ]; then
  WT=true
else
  WT=false
fi
print_cgi_headers 
print_nav_bar "MongoDB|Servers" "MongoDB/mongo_extended|Extended" "MongoDB/mongosharding|Sharding" "MongoDB/mongocollections|Collections" "MongoDB/mongologger|Log Monitor"
if $WT ; then
  print_page_title "host:port" "Records scanned (N/sec)" "Disk reads / writes (MB/sec)" "Files open" "Open cursors" "Fastmod / Idhack / Scan-and-order (N/sec)" "Replication ops (N/sec)"
else
  print_page_title "host:port" "Records scanned (N/sec)" "Data in RAM, size (MB) / over seconds" "Index hit / access (N/sec)" "Open cursors" "Fastmod / Idhack / Scan-and-order (N/sec)" "Replication ops (N/sec) / bandwidth (bytes/sec)"
fi

print_mongo_server() {
  IFS2=$IFS ; IFS=$IFS1
  local clname="$1"
  local host=`echo "$2" | cut -d'|' -f1`
  local role=`echo "$2" | cut -d'|' -f4`
  local roleprop=( `echo "$role" | tr '=' ' '` )
  local roleind=`echo $role | cut -b 1 | sed 's|.|\U&|'`
  if [ "_${roleprop[0]}" == "_slave" ]; then
    if [ -n "${roleprop[2]}" ]; then # it is a functioning RS member 
      if [ ${roleprop[2]} -ne 0 ] 2>/dev/null; then # it is a delayed secondary
        if [ "_${roleprop[1]}" == "_true" ]; then # it is hidden
          if [ ${roleprop[4]} -ne 0 ]; then # priority is not 0
            roleerror="\nERROR: priority is not 0 for a delayed secondary\n"
            roleerrorclass=" roleerror"
          fi
        else
          roleerror="\n\nERROR: delayed secondary must be hidden"
          roleerrorclass=" roleerror"
        fi
        roleind="${roleind}D"
      else
        [ "_${roleprop[1]}" == "_true" ] && roleind="${roleind}H"
      fi
    fi
    local roletitle="`echo -e "slave\n\nHidden: ${roleprop[1]}\nDelay: ${roleprop[2]}\nIndexes: ${roleprop[3]}\nPriority: ${roleprop[4]}\nVotes: ${roleprop[5]}\nTags: ${roleprop[6]}${roleerror}"`"
  else
    local roletitle="`echo -e "${roleprop[0]}\n\nPriority: ${roleprop[1]}\nVotes: ${roleprop[2]}\nTags: ${roleprop[3]}"`"
  fi
  port="${host##*:}"
  name="${host%:*}"
  nodeid="$clname|${name}:${port}"
  [ ${#name} -gt 14 ] && namep="${name:0:7}..${name:(-7)}" || namep=$name
  [ -d "$PWD/../MongoDB/$clname/${name}:${port}" ] && install -d "$PWD/../MongoDB/$clname/${name}:${port}"
  
  report=`cat "$M_ROOT/standalone/MongoDB/${name}:${port}.ext.report" 2>/dev/null`
  
  echo "<div class=\"server\" id=\"${nodeid}\">"
  
    echo "<div class=\"servername clickable\" id=\"${nodeid}_name_ext\" onClick=\"showData('${nodeid}_name_ext','/MongoDB')\" title=\"${name}:${port}\">${namep}:${port}<span class=\"${roleprop[0]}${roleind}${roleerrorclass}\" title=\"${roletitle}\">${roleind}</span><div id=\"data_${nodeid}_name_ext\" class=\"dhtmlmenu\" style=\"display: none\"></div></div>" 2>/dev/null
    
    scanned=`echo "$report" | grep '^Records scanned'`
    scanned=`expr "$scanned" : ".*:\ *\(.*[^ ]\)\ *$"`
    echo "<div class=\"status clickable\" id=\"${nodeid}_scanned\" onclick=\"showDetails('${nodeid}_scanned','MongoDB/mongo_records_scanned_graph')\">${scanned}</div>"
    
    if $WT ; then
      blockrd=`echo "$report" | grep 'Data read (MB/sec)'`
      blockrd=`expr "$blockrd" : ".*:\ *\(.*[^ ]\)\ *$"`
      blockwr=`echo "$report" | grep 'Data written (MB/sec)'`
      blockwr=`expr "$blockwr" : ".*:\ *\(.*[^ ]\)\ *$"`
      openfiles=`echo "$report" | grep 'Files open'`
      openfiles=`expr "$openfiles" : ".*:\ *\(.*[^ ]\)\ *$"`
      echo -e "<div class=\"status clickable\" id=\"${nodeid}_blockrdwr\" onclick=\"showDetails('${nodeid}_blockrdwr','MongoDB/mongo_wt_block_readwrite_graph')\">${blockrd} / ${blockwr}</div>\n<div class=\"status\" id=\"${nodeid}_openfiles\"\">${openfiles}</div>"
    else
      inmemdd=`echo "$report" | grep '^Data size'`
      inmemdd=`expr "$inmemdd" : ".*:\ *\(.*[^ ]\)\ *$"`
      inmemsec=`echo "$report" | grep '^Over seconds'`
      inmemsec=`expr "$inmemsec" : ".*:\ *\(.*[^ ]\)\ *$"`
      echo "<div class=\"status clickable\" id=\"${nodeid}_inmem\" onclick=\"showDetails('${nodeid}_inmem','MongoDB/mongo_data_inram_graph')\">${inmemdd} / ${inmemsec}</div>"
      
      indexhits=`echo "$report" | grep '^Index hits'`
      indexhits=`expr "$indexhits" : ".*:\ *\(.*[^ ]\)\ *$"`
      indexacc=`echo "$report" | grep '^Index accesses'`
      indexacc=`expr "$indexacc" : ".*:\ *\(.*[^ ]\)\ *$"`
      echo "<div class=\"status clickable\" id=\"${nodeid}_index\" onclick=\"showDetails('${nodeid}_index','MongoDB/mongo_index_hits_graph')\">${indexhits} / ${indexacc}</div>"
    fi
    
    cursors=`echo "$report" | grep '^Open cursors'`
    cursors=`expr "$cursors" : ".*:\ *\(.*[^ ]\)\ *$"`
    echo "<div class=\"status\" id=\"${nodeid}_cursors\">${cursors}</div>"
    
    fastmod=`echo "$report" | grep '^Fastmod operations'`
    fastmod=`expr "$fastmod" : ".*:\ *\(.*[^ ]\)\ *$"`
    idhack=`echo "$report" | grep '^Idhack operations'`
    idhack=`expr "$idhack" : ".*:\ *\(.*[^ ]\)\ *$"`
    scanorder=`echo "$report" | grep '^Scan and order operations'`
    scanorder=`expr "$scanorder" : ".*:\ *\(.*[^ ]\)\ *$"`
    echo "<div class=\"status\" id=\"${nodeid}_oper\">${fastmod} / ${idhack} / ${scanorder}</div>"

    replstats=`echo "$report" | grep '^Network usage'`
    replops=`expr "$replstats" : ".*operations.*:\ *\(.*[^ ]\)\ *$"`
    replbw=`expr "$replstats" : ".*bytes.*:\ *\(.*[^ ]\)\ *$"`
    echo "<div class=\"status\" id=\"${nodeid}_repl\">${replops} / ${replbw}</div>"

  echo "</div>"
  echo "<div class=\"details\" id=\"${nodeid}_details\"></div>"
  unset roleerror roleerrorclass
  IFS=$IFS2
}

IFS1=$IFS
IFS='
'

# Standalone servers
if [ `cat "$M_ROOT/standalone/MongoDB/mongo_servers.list" 2>/dev/null | wc -l` -gt 0 ] ; then
  clustername="MongoDB Servers"
  open_cluster "$clustername"
  close_cluster_line
    for rs in `cat "$M_ROOT/standalone/MongoDB/mongo_servers.list" | cut -d'|' -f3 | sort | uniq` ; do
      echo "<div class=\"server hilited\" id=\"$rs\">"
      echo "<div class=\"servername\" id=\"${rs}_name\">Replica Set: ${rs}</div>"
      echo "</div>"
      for s in `cat "$M_ROOT/standalone/MongoDB/mongo_servers.list" | grep "|$rs|"` ; do
        print_mongo_server "$clustername" "$s"
      done
    done
### Not members of any RS
    for s in `cat "$M_ROOT/standalone/MongoDB/mongo_servers.list" | grep ^.*\|$` ; do
      print_mongo_server "$clustername" "$s"
    done
    
  close_cluster
  
fi

# Shard servers
if [ `cat "$M_ROOT/standalone/MongoDB/mongo_shards.list" 2>/dev/null | wc -l` -gt 0 ] ; then

  clustername="Shard Servers"
  open_cluster "$clustername"
  close_cluster_line
    for rs in `cat "$M_ROOT/standalone/MongoDB/mongo_shards.list" | cut -d'|' -f2 | sort | uniq` ; do
      echo "<div class=\"server hilited\" id=\"$rs\">"
      echo "<div class=\"servername\" id=\"${rs}_name\">Replica Set: ${rs}</div>"
      echo "</div>"
      for s in `cat "$M_ROOT/standalone/MongoDB/mongo_shards.list" | grep "|$rs|"` ; do
        print_mongo_server "$clustername" "$s"
      done
    done
### Not members of any RS
    for s in `cat "$M_ROOT/standalone/MongoDB/mongo_shards.list" | grep ^.*\|$` ; do
      print_mongo_server "$s"
    done
  close_cluster
  
fi
IFS=$IFS1

