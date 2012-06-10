#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "${PWD}/../../lib/dash_functions.sh"
CURL=`which curl 2>/dev/null`

print_cgi_headers
print_page_title "ID" "Host" "Heap used / committed" "Indices size" "Indices docs number" "Open file descriptors" "Conn http / transport"

for cluster in "${PWD}/../../standalone/${scriptname}/data/"*.nodes ; do
  clustername=${cluster##*/} ; clustername=${clustername%.nodes}
  
  print_cluster_header "$clustername"
  
  clusterdat=`ls -1t "${PWD}/../../standalone/${scriptname}/data/${clustername}."*.dat`
  esip=`cat $clusterdat | grep ^ip\| | cut -d'|' -f2 | sort | uniq | grep -v ^$`
  for eshostip in $esip ; do
    eshostname=`grep ^$eshostip\| "${PWD}/../../servers.list" | cut -d'|' -f4`
    if [ -n "$eshostname" ] ; then
      servercluster=`grep ^$eshostip\| "${PWD}/../../servers.list" | cut -d'|' -f5`
      [ -f "${PWD}/../../standalone/${scriptname}/${servercluster}.es_servers.list" ] && eshost=`grep "^${eshostname}:" "${PWD}/../../standalone/${scriptname}/${servercluster}.es_servers.list"`
      [ -n "$eshost" ] || eshost=`grep "^${eshostip}:" "${PWD}/../../standalone/${scriptname}/${servercluster}.es_servers.list"`
    else
      eshost="${eshostip}:9200"
    fi
    [ -n "$CURL" ] && thisesstatus=`$CURL -m 2 -s "http://${eshost}/_cluster/health" | "${PWD}/../../lib/json2txt" | grep '/status|' | cut -d'|' -f2`
    if [ -n "$prevstatus" ] ; then
      [ "X$prevstatus" != "X$thisesstatus" ] && esstatus="$esstatus $thisesstatus"
    else
      esstatus="$thisesstatus"
    fi
    prevstatus=$thisesstatus
  done
  
  echo "<div class=\"cluster\" id=\"${clustername}\">"
    echo "<div class=\"server\" id=\"${clustername}_status\">"
    
      echo "<div class=\"servername\" id=\"${clustername}_name\" onclick=\"showDetails('${clustername}_status','eshealth')\">Cluster: ${clustername}</div>"
      for esst in $esstatus ; do
        echo "<div class=\"status\" id=\"${clustername}_http\" onclick=\"showDetails('${clustername}_status','esstatus')\" style=\"color: $esst ; font-weight: bold ;\">$esst</div>"
      done
      echo "<div id=\"data_${clustername}_http\" class=\"dhtmlmenu\" style=\"display: none\"></div>"
    echo "</div>"
    
    echo "<div id=\"${clustername}_details\" class=\"details\" style=\"display: none\"></div>"
    
    for node in `cat ${PWD}/../../standalone/${scriptname}/${clustername}.nodes.list` ; do
      [ "X`cat "${PWD}/../../standalone/${scriptname}/data/${clustername}.${node%:*}.dat"|grep ^master\||cut -d'|' -f2`" == "X1" ] && role="M" || unset role
      echo "<div class=\"server\" id=\"${node}\">"
        echo "<div class=\"servername\" id=\"${node}_name\" onClick=\"showData('${node}_name','/${scriptname}')\">`cat "${PWD}/../../standalone/${scriptname}/data/${clustername}.${node%:*}.dat"|grep ^name\||cut -d'|' -f2`<span class=\"master\">$role</span><div id=\"data_${node}_name\" class=\"dhtmlmenu\" style=\"display: none\"></div></div>"
        echo "<div class=\"status\" id=\"${node}_host\">${node%:*}</div>"
        echo "<div class=\"status\" id=\"${node}_mem\">`grep ^jvm\/mem\/heap_used\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2 | tr -d 'mb'` / `grep ^jvm\/mem\/heap_committed\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2 | tr -d 'mb'`</div>"
        echo "<div class=\"status\" id=\"${node}_size\">`grep ^indices/size\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2`</div>"
        echo "<div class=\"status\" id=\"${node}_docs\">`grep ^indices/docs/num_docs\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2`</div>"
        echo "<div class=\"status\" id=\"${node}_files\">`grep ^process/open_file_descriptors\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2`</div>"
        echo "<div class=\"status\" id=\"${node}_conn\">`grep ^http/server_open\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2` / `grep ^transport/server_open\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${node%:*}.dat" | cut -d'|' -f2`</div>"
      echo "</div>"
    done

done




