#!/bin/bash
echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
#${PWD}/../../standalone/${scriptname}/mongodb.mon
CURL=`which curl 2>/dev/null`
IFS1=$IFS
IFS='
'
if [ -f "${PWD}/../../standalone/${scriptname}/mongo_config_servers.list" ] ; then
  echo "<div class=\"clustername\">Configuration servers</div>"
  echo "<div class=\"cluster\" id=\"configservers\">"
    for s in `cat "${PWD}/../../standalone/${scriptname}/mongo_config_servers.list"` ; do
      port=${s##*:}
      name=${s%:*}
      id=${name}_${port}
      install -d "${PWD}/../${scriptname}/configservers/${id}"
      [ -n "$port" ] && wport=`expr $port + 1000`
      #$CURL -s "http://${name}:${wport}" > "${PWD}/../${scriptname}/configservers/${id}/${id}_name.html"
      echo "<div class=\"servername\" id=\"${id}\">${name}:${wport}"
        echo "<div id=\"${id}_http\" onclick=\"showURL('${id}_http','http://${name}:${wport}','${scriptname}')\">http<div id=\"data_${id}_http\" class=\"dhtmlmenu\" style=\"display: none\"></div></div>"
      echo "</div>"
    done
  echo "</div>"
fi

if [ -f "${PWD}/../../standalone/${scriptname}/mongo_shards.list" ] ; then
  echo "<div class=\"clustername\">Shard servers</div>"
  echo "<div class=\"cluster\" id=\"shardservers\">"
    for s in `cat "${PWD}/../../standalone/${scriptname}/mongo_shards.list"` ; do
      port=`echo $s | awk '{print $1}' | cut -d':' -f2`
      name=`echo $s | awk '{print $1}' | cut -d':' -f1`
      id=${name}_${port}
      install -d "${PWD}/../${scriptname}/shardservers/${id}"
      [ -n "$port" ] && wport=`expr $port + 1000`
      #$CURL -s "http://${name}:${wport}" > "${PWD}/../${scriptname}/shardservers/${id}/${id}_name.html"
      echo "<div class=\"servername\" id=\"${id}\">${name}:${wport}"
        echo "<div id=\"${id}_http\" onclick=\"showURL('${id}_http','http://${name}:${wport}','${scriptname}')\">http<div id=\"data_${id}_http\" class=\"dhtmlmenu\" style=\"display: none\"></div></div>"
      echo "</div>"
    done
  echo "</div>"
fi

if [ -f "${PWD}/../../standalone/${scriptname}/mongo_mongos_servers.list" ] ; then
  echo "<div class=\"clustername\">Balancers</div>"
  echo "<div class=\"cluster\" id=\"balancers\">"
    for s in `cat "${PWD}/../../standalone/${scriptname}/mongo_mongos_servers.list"` ; do
      port=${s##*:}
      name=${s%:*}
      id=${name}_${port}
      install -d "${PWD}/../${scriptname}/balancers/${id}"
      [ -n "$port" ] && wport=`expr $port + 1000`
      #$CURL -s "http://${name}:${wport}" > "${PWD}/../${scriptname}/balancers/${id}/${id}_name.html"
      echo "<div class=\"servername\" id=\"${id}\">${name}:${wport}"
        echo "<div id=\"${id}_http\" onclick=\"showURL('${id}_http','http://${name}:${wport}','${scriptname}')\">http<div id=\"data_${id}_http\" class=\"dhtmlmenu\" style=\"display: none\"></div></div>"
      echo "</div>"
    done
  echo "</div>"
fi
IFS=$IFS1

