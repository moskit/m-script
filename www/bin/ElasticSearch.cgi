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
    echo "<div class=\"status\" id=\"title2\">&nbsp;</div>"
    echo "<div class=\"status\" id=\"title3\"><b>Status</b></div>"
    echo "<div class=\"status\" id=\"title4\"><b>Memory Res/Virt</b></div>"
    echo "<div class=\"status\" id=\"title5\"><b>Conn Curr/Avail</b></div>"
    echo "<div class=\"status\" id=\"title6\"><b>Bandwidth In/Out</b></div>"
    echo "<div class=\"status\" id=\"title7\"><b>Requests / sec</b></div>"
  echo "</div>"
echo "</div>"

echo "<div class=\"clustername\"><span class=\"indent\">Clusters and nodes</span></div>"

for cluster in ${PWD}/../../standalone/${scriptname}/data/*.nodes ; do
  clustername=${cluster##*/} ; clustername=${clustername%.nodes}
  
  echo "<div class=\"cluster\" id=\"${clustername}\">"
  
  echo "<div class=\"server\" id=\"${clustername}_status\">"
  echo "<div class=\"servername\" id=\"${clustername}_name\">Cluster: ${clustername}</div>"
  echo "</div>"

  echo "<div class=\"status\" id=\"${id}_http\" onclick=\"showURL('${id}_http','http://${name}:${wport}','${scriptname}')\">HTTP<div id=\"data_${id}_http\" class=\"dhtmlmenu\" style=\"display: none\"></div></div>"




done




