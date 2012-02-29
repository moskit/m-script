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
    if [ -n "$eshostname" ] ; then
      servercluster=`grep ^$eshostip\| "${PWD}/../../servers.list" | awk -F'|' '{print $5}'`
      
      eshost=`grep "^${eshostip}:" "${PWD}/../../standalone/${scriptname}/${servercluster}.es_servers.list"`
      [ -n "$eshost" ] || eshost=`grep "^${eshostname}:" "${PWD}/../../standalone/${scriptname}/${servercluster}.es_servers.list"`
    else
      eshost=$eshostip
    fi
    thisesstatus=`$CURL "http://${eshost}/_cluster/health" | "${PWD}/../../lib/json2txt" | grep '/status|' | cut -d'|' -f2`
    [ -n "$esstatus" ] && [ "X$esstatus" != "X$thisesstatus" ] && esstatus="$esstatus $thisesstatus" || esstatus="$thisesstatus"
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




