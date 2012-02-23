#!/bin/bash
echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
CURL=`which curl 2>/dev/null`
[ -z "$CURL" ] && echo "Curl not found, exiting..  " && exit 1
CURL="$CURL -s"
echo "<div class=\"dashtitle\">"
  echo "<div class=\"server\">"
    echo "<div class=\"servername\" id=\"title1\">ID</div>"
    echo "<div class=\"status\" id=\"title2\"><b>Status<br />Host</b></div>"
    echo "<div class=\"status\" id=\"title3\"><b>Heap used / committed</b></div>"
    echo "<div class=\"status\" id=\"title4\"><b>Indices size</b></div>"
    echo "<div class=\"status\" id=\"title5\"><b>Indices docs number</b></div>"
    echo "<div class=\"status\" id=\"title6\"><b>Open file descriptors</b></div>"
    echo "<div class=\"status\" id=\"title7\"><b>Conn http / transport</b></div>"
  echo "</div>"
echo "</div>"

echo "<div class=\"clustername\"><span class=\"indent\">Clusters and nodes</span></div>"

for cluster in "${PWD}/../../standalone/${scriptname}/data/"*.nodes ; do
  clustername=${cluster##*/} ; clustername=${clustername%.nodes}
  clusterdat=`ls -1t "${PWD}/../../standalone/${scriptname}/data/${clustername}."*.dat`
  esip=`cat $clusterdat | grep ^ip\| | awk -F'|' '{print $2}' | sort | uniq`
  for eshostip in $esip ; do
    eshostname=`grep ^$eshostip\| "${PWD}/../../servers.list" | awk -F'|' '{print $4}'`
    servercluster=`grep ^$eshostip\| "${PWD}/../../servers.list" | awk -F'|' '{print $5}'`
    
    eshost=`grep "^${eshostip}:" "${PWD}/../../standalone/${scriptname}/${servercluster}.es_servers.list"`
    [ -n "$eshost" ] || eshost=`grep "^${eshostname}:" "${PWD}/../../standalone/${scriptname}/${servercluster}.es_servers.list"`
    esstatus=`$CURL "http://${eshost}/_cluster/health" | "${PWD}/../../lib/json2txt" | grep '/status|' | cut -d'|' -f2`
  
  done
  echo "<div class=\"cluster\" id=\"${clustername}\">"
    echo "<div class=\"server\" id=\"${clustername}_status\">"
    
      echo "<div class=\"servername\" id=\"${clustername}_name\" onclick=\"showDetails('${clustername}_status','eshealth')\">Cluster: ${clustername}</div>"
      
      echo "<div class=\"status\" id=\"${clustername}_http\" onclick=\"showDetails('${clustername}_status','esstatus')\" style=\"color: $esstatus ; font-weight: bold ;\">$esstatus</div>"
      echo "<div id=\"data_${clustername}_http\" class=\"dhtmlmenu\" style=\"display: none\"></div>"
    echo "</div>"
    echo "<div id=\"${clustername}_details\" class=\"details\" style=\"display: none\"></div>"
    for esserver in `cat ${PWD}/../../standalone/${scriptname}/${servercluster}.es_servers.list` ; do
      [ "X`cat "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat"|grep ^master\||cut -d'|' -f2`" == "X1" ] && role="M" || unset role
      echo "<div class=\"server\" id=\"${esserver}\">"
        echo "<div class=\"servername\" id=\"${esserver}_name\" onClick=\"showData('${esserver}_name','/${scriptname}')\">`cat "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat"|grep ^name\||cut -d'|' -f2`<span class=\"master\">$role</span><div id=\"data_${esserver}_name\" class=\"dhtmlmenu\" style=\"display: none\"></div></div>"
        echo "<div class=\"status\" id=\"${esserver}_host\">${esserver%:*}</div>"
        echo "<div class=\"status\" id=\"${esserver}_mem\">`grep ^os/jvm\/mem\/heap_used\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat" | cut -d'|' -f2 | tr -d 'mb'` / `grep ^os/jvm\/mem\/heap_committed\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat" | cut -d'|' -f2 | tr -d 'mb'`</div>"
        echo "<div class=\"status\" id=\"${esserver}_size\">`grep ^indices/size\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat" | cut -d'|' -f2`</div>"
        echo "<div class=\"status\" id=\"${esserver}_docs\">`grep ^indices/docs/num_docs\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat" | cut -d'|' -f2`</div>"
        echo "<div class=\"status\" id=\"${esserver}_files\">`grep ^os/process/open_file_descriptors\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat" | cut -d'|' -f2`</div>"
        echo "<div class=\"status\" id=\"${esserver}_conn\">`grep ^os/http/server_open\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat" | cut -d'|' -f2` / `grep ^os/transport/server_open\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat" | cut -d'|' -f2`</div>"
      echo "</div>"
    done

done




