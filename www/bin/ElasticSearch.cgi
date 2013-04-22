#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "$PWD/../../lib/dash_functions.sh"
CURL=`which curl 2>/dev/null`

print_cgi_headers
print_nav_bar "ElasticSearch|Nodes" "es_logs|Logs"
print_page_title "ID" "Node" "Heap used / committed" "Indices size" "Indices docs number" "Open file descriptors" "Conn http / transport"

for cluster in `find "$PWD/../../standalone/$scriptname/data" -type f -name "*.nodes" 2>/dev/null` ; do
  clustername=${cluster##*/} ; clustername=${clustername%.nodes}
  
  open_cluster "$clustername"
  close_cluster_line
  clusterdat=`ls -1t "$PWD/../../standalone/$scriptname/data/${clustername}."*.dat`
  esip=`cat "$clusterdat" 2>/dev/null | grep ^ip\| | cut -d'|' -f2 | sort | uniq | grep -v ^$`
  for eshostip in $esip ; do
    eshostname=`grep ^$eshostip\| "$PWD/../../servers.list" | cut -d'|' -f4`
    if [ -n "$eshostname" ] ; then
      servercluster=`grep ^$eshostip\| "$PWD/../../servers.list" | cut -d'|' -f5`
      if [ -f "$PWD/../../standalone/$scriptname/${servercluster}.es_servers.list" ]; then
        eshost=`grep "^${eshostname}:" "$PWD/../../standalone/${scriptname}/${servercluster}.es_servers.list"`
        [ -n "$eshost" ] || eshost=`grep "^${eshostip}:" "$PWD/../../standalone/$scriptname/${servercluster}.es_servers.list"`
      fi
    else
      eshost="${eshostip}:9200"
    fi
    [ -n "$CURL" ] && thisesstatus=`$CURL -m 2 -s "http://$eshost/_cluster/health" | "$PWD/../../lib/json2txt" | grep '/"status"|' | cut -d'|' -f2 | tr -d '"'`
    if [ -n "$prevstatus" ] ; then
      [ "X$prevstatus" != "X$thisesstatus" ] && esstatus="$esstatus $thisesstatus"
    else
      esstatus="$thisesstatus"
    fi
    prevstatus=$thisesstatus
  done
  
  print_line_title eshealth "$clustername" "$clustername"
      for esst in $esstatus ; do
        echo "<div class=\"status\" id=\"${clustername}_http\" onclick=\"showDetails('${clustername}_name','esstatus')\" style=\"color: $esst ; font-weight: bold ;\">$esst</div>"
      done
      echo "<div id=\"data_${clustername}_http\" class=\"dhtmlmenu\" style=\"display: none\"></div>"
  close_line

    for node in `cat $PWD/../../standalone/$scriptname/${clustername}.nodes.list | sort` ; do
      [ "X`cat "$PWD/../../standalone/$scriptname/data/${clustername}.${node%:*}.dat"|grep ^master\||cut -d'|' -f2`" == "X1" ] && role="M" || unset role
      print_line_title "$scriptname" "$clustername" "$node"

        echo "<div class=\"status\" id=\"${node}_host\"><span class=\"master\">$role</span>`cat "$PWD/../../standalone/$scriptname/data/${clustername}.${node%:*}.dat" 2>/dev/null | grep ^\\"name\\"\||cut -d'|' -f2 | tr -d '"'`</div>"
        echo "<div class=\"status\" id=\"${node}_mem\">`grep ^\\"jvm\\"\/\\"mem\\"\/\\"heap_used\\"\| "$PWD/../../standalone/$scriptname/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2 | tr -d 'mb"'` / `grep ^\\"jvm\\"\/\\"mem\\"\/\\"heap_committed\\"\| "$PWD/../../standalone/$scriptname/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2 | tr -d 'mb"'`</div>"
        echo "<div class=\"status\" id=\"${node}_size\">`grep ^\\"indices\\"/\\"store\\"/\\"size\\"\| "$PWD/../../standalone/$scriptname/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2 | tr -d '"'`</div>"
        echo "<div class=\"status\" id=\"${node}_docs\">`grep ^\\"indices\\"/\\"docs\\"/\\"count\\"\| "$PWD/../../standalone/$scriptname/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2`</div>"
        echo "<div class=\"status\" id=\"${node}_files\">`grep ^\\"process\\"/\\"open_file_descriptors\\"\| "$PWD/../../standalone/${scriptname}/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2`</div>"
        echo "<div class=\"status\" id=\"${node}_conn\">`grep ^\\"http\\"/\\"server_open\\"\| "$PWD/../../standalone/${scriptname}/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2` / `grep ^\\"transport\\"/\\"server_open\\"\| "$PWD/../../standalone/${scriptname}/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2`</div>"
        
      close_line
    done
    
close_cluster

done




