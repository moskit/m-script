#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "$PWD/../../lib/dash_functions.sh"
CURL=`which curl 2>/dev/null`

print_cgi_headers
print_nav_bar "ElasticSearch|Nodes" "ElasticSearch/es_logs|Logs"
print_page_title "ID" "Node" "Heap used / committed" "Indices size" "Indices docs number" "Open file descriptors" "Conn http / transport"

for cluster in `find "$PWD/../../standalone/$scriptname/data" -type f -name "*.nodes" 2>/dev/null` ; do
  clustername=${cluster##*/} ; clustername=${clustername%.nodes}
  
  open_cluster "$clustername"
  close_cluster_line
  clusterdat=`find "$PWD/../../standalone/$scriptname/data/" -maxdepth 1 -name "${clustername}.*.dat" 2>/dev/null`
  [ -z "$clusterdat" ] && exit 1
  esip=`cat $clusterdat 2>/dev/null | grep ^ip\| | cut -d'|' -f2 | sort | uniq | grep -v ^$`
  for eshostip in $esip ; do
    eshostname=`grep ^$eshostip\| "$PWD/../../nodes.list" | cut -d'|' -f4`
    if [ -n "$eshostname" ] ; then
      servercluster=`grep ^$eshostip\| "$PWD/../../nodes.list" | cut -d'|' -f5`
      if [ -f "$PWD/../../standalone/$scriptname/${servercluster}.es_nodes.list" ]; then
        eshost=`grep "^${eshostname}:" "$PWD/../../standalone/${scriptname}/${servercluster}.es_nodes.list"`
        [ -n "$eshost" ] || eshost=`grep "^${eshostip}:" "$PWD/../../standalone/$scriptname/${servercluster}.es_nodes.list"`
      fi
    else
      eshost="${eshostip}:9200"
    fi
    [ -n "$CURL" ] && thisesstatus=`$CURL -m 2 -s "http://$eshost/_cluster/health" | "$PWD"/../../lib/json2txt | grep '/"status"|' | cut -d'|' -f2 | tr -d '"'`
    if [ -n "$prevstatus" ] ; then
      [ "X$prevstatus" != "X$thisesstatus" ] && esstatus="$esstatus $thisesstatus"
    else
      esstatus="$thisesstatus"
    fi
    prevstatus=$thisesstatus
  done
  
  open_line "$clustername|hilited" ElasticSearch/eshealth
      for esst in $esstatus ; do
        echo "<div class=\"status\" id=\"${clustername}_http\" onclick=\"showDetails('${clustername}_name','ElasticSearch/esstatus')\" style=\"color: $esst ; font-weight: bold ;\">$esst</div>"
      done
      echo "<div id=\"data_${clustername}_http\" class=\"dhtmlmenu\" style=\"display: none\"></div>"
  close_line

    for node in `cat $PWD/../../standalone/$scriptname/${clustername}.nodes.list | sort` ; do
      [ "_`cat "$PWD/../../standalone/$scriptname/data/${clustername}.${node%:*}.dat"|grep ^master\||cut -d'|' -f2`" == "_1" ] && role="M" || unset role
      open_line "$node||$clustername"

        echo "<div class=\"status\" id=\"${node}_host\"><span class=\"master\">$role</span>`cat "$PWD/../../standalone/$scriptname/data/${clustername}.${node%:*}.dat" 2>/dev/null | grep ^\\"name\\"\||cut -d'|' -f2 | tr -d '"'`</div>"
        
        heap_used_in_bytes=`grep ^\"jvm\"\/\"mem\"\/\"heap_used_in_bytes\"\| "$PWD/../../standalone/$scriptname/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2`
        heap_used_in_mbytes=`echo "scale=2; $heap_used_in_bytes / 1048576" | bc`
        heap_committed_in_bytes=`grep ^\"jvm\"\/\"mem\"\/\"heap_committed_in_bytes\"\| "$PWD/../../standalone/$scriptname/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2`
        heap_committed_in_mbytes=`echo "scale=2; $heap_committed_in_bytes / 1048576" | bc`
        
        echo "<div class=\"status\" id=\"${node}_mem\">${heap_used_in_mbytes} / ${heap_committed_in_mbytes}</div>"
        
        indices_size_in_bytes=`grep ^\"indices\"/\"store\"/\"size_in_bytes\"\| "$PWD/../../standalone/$scriptname/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2 | tr -d '"'`
        indices_size_in_mbytes=`echo "scale=2; $indices_size_in_bytes / 1048576" | bc`
        
        echo "<div class=\"status\" id=\"${node}_size onclick=\"showDetails('${clustername}_name','ElasticSearch/index_size')\">${indices_size_in_mbytes}</div>"
        
        echo "<div class=\"status\" id=\"${node}_docs onclick=\"showDetails('${clustername}_name','ElasticSearch/index_docsnum')\">`grep ^\\"indices\\"/\\"docs\\"/\\"count\\"\| "$PWD/../../standalone/$scriptname/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2`</div>"
        echo "<div class=\"status\" id=\"${node}_files\">`grep ^\\"process\\"/\\"open_file_descriptors\\"\| "$PWD/../../standalone/${scriptname}/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2`</div>"
        echo "<div class=\"status\" id=\"${node}_conn\">`grep ^\\"http\\"/\\"current_open\\"\| "$PWD/../../standalone/${scriptname}/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2` / `grep ^\\"transport\\"/\\"server_open\\"\| "$PWD/../../standalone/${scriptname}/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2`</div>"
        
      close_line
    done
    
close_cluster

done




