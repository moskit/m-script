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

for cluster in ${PWD}/../../standalone/${scriptname}/data/*.nodes ; do
  eshost=`grep transport_address $cluster | awk '{print $2}'`
  eshost=${eshost#*/} ; eshost=${eshost%:*}
  eshost=`grep "^${eshost}:" ${PWD}/../../standalone/${scriptname}/*.es_servers.list`
  clustername=${cluster##*/} ; clustername=${clustername%.nodes}
  esstatus=`$CURL "http://${eshost}/_cluster/health" | "${PWD}/../../lib/json2txt" | grep '/status ' | cut -d' ' -f2`
  echo "<div class=\"cluster\" id=\"${clustername}\">"
    echo "<div class=\"server\" id=\"${clustername}_status\">"
    
      echo "<div class=\"servername\" id=\"${clustername}_name\" onclick=\"showDetails('${clustername}_status','eshealth')\">Cluster: ${clustername}</div>"
      
      echo "<div class=\"status\" id=\"${clustername}_http\" onclick=\"showDetails('${clustername}_status','esstatus')\" style=\"color: $esstatus ; font-weight: bold ;\">$esstatus</div>"
      echo "<div id=\"data_${clustername}_http\" class=\"dhtmlmenu\" style=\"display: none\"></div>"
    echo "</div>"
    echo "<div id=\"${clustername}_details\" class=\"details\" style=\"display: none\"></div>"
    for esserver in `cat ${PWD}/../../standalone/${scriptname}/${clustername}.es_servers.list` ; do
      echo "<div class=\"server\" id=\"${esserver}\">"
        echo "<div class=\"servername\" id=\"${esserver}_name\" onClick=\"showData('${esserver}_name','/${scriptname}')\">`cat "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat"|grep ^name\||cut -d'|' -f2`<div id=\"data_${esserver}_name\" class=\"dhtmlmenu\" style=\"display: none\"></div></div>"
        echo "<div class=\"status\" id=\"${esserver}_host\">${esserver%:*}</div>"
        echo "<div class=\"status\" id=\"${esserver}_mem\">`grep ^jvm\/mem\/heap_used\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat" | cut -d'|' -f2 | tr -d 'mb'` / `grep ^jvm\/mem\/heap_committed\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat" | cut -d'|' -f2 | tr -d 'mb'`</div>"
        echo "<div class=\"status\" id=\"${esserver}_size\">`grep ^indices/size\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat" | cut -d'|' -f2`</div>"
        echo "<div class=\"status\" id=\"${esserver}_docs\">`grep ^indices/docs/num_docs\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat" | cut -d'|' -f2`</div>"
        echo "<div class=\"status\" id=\"${esserver}_files\">`grep ^process/open_file_descriptors\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat" | cut -d'|' -f2`</div>"
        echo "<div class=\"status\" id=\"${esserver}_conn\">`grep ^http/server_open\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat" | cut -d'|' -f2` / `grep ^transport/server_open\| "${PWD}/../../standalone/${scriptname}/data/${clustername}.${esserver%:*}.dat" | cut -d'|' -f2`</div>"
      echo "</div>"
    done

done




