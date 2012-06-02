#!/bin/bash
echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""

saname="MongoDB"
scriptname=${0%.cgi}
scriptname=${scriptname##*/}
MONGO=`which mongo 2>/dev/null`
source "${PWD}/../../conf/mon.conf"
FREQ2=`expr $FREQ \* 2`

db_header() {
  echo "<div class=\"clustername\"><span class=\"indent\">${1}</span></div>"
  echo "<div class=\"cluster\" id=\"${1}\">"
}

db_bottom() {
  echo "</div>"
}

coll_header() {
  echo "<div class=\"server\" id=\"${1}\">"
  
    echo "<div class=\"servername\" id=\"${1}_name\" onClick=\"showData('${1}_name','/${scriptname}')\">${1}<div id=\"data_${1}_name\" class=\"dhtmlmenu\" style=\"display: none\"></div></div>"
    
    echo "<div class=\"status\" id=\"${1}_datasize\">`grep ^memRes\| "${PWD}/../../standalone/${scriptname}/data/${name}:${port}.dat" | cut -d'|' -f2` / `grep ^memVir\| "${PWD}/../../standalone/${scriptname}/data/${name}:${port}.dat" | cut -d'|' -f2`</div>"
    
    echo "<div class=\"status\" id=\"${id}_conn\">`grep ^connCurrent\| "${PWD}/../../standalone/${scriptname}/data/${name}:${port}.dat" | cut -d'|' -f2` / `grep ^connAvailable\| "${PWD}/../../standalone/${scriptname}/data/${name}:${port}.dat" | cut -d'|' -f2`</div>"
    
    echo "<div class=\"status\" id=\"${id}_bw\">`grep '^Bandwidth in ' "${PWD}/../../standalone/${scriptname}/data/${name}:${port}.report" | cut -d':' -f2 | sed 's| *||g'` / `grep '^Bandwidth out ' "${PWD}/../../standalone/${scriptname}/data/${name}:${port}.report" | cut -d':' -f2 | sed 's| *||g'`</div>"
    
    echo "<div class=\"status\" id=\"${id}_qps\" onclick=\"showDetails('${id}_qps','mongoqps')\">`grep '^Network requests per second' "${PWD}/../../standalone/${scriptname}/data/${name}:${port}.report" | cut -d':' -f2 | sed 's| *||g'`</div>"
    
  echo "</div>"
}

coll_bottom() {
  echo "</div>"
}

print_shards() {
  echo "do nothing"
}

cat "${PWD}/../../standalone/${saname}/views_nav_bar.html" | sed "/\"${scriptname}\"/s/\"viewsbutton\"/\"viewsbutton active\"/"
confserver=`tail -1 "${PWD}/../../standalone/${saname}/mongo_config_servers.list"`
[ -z "$confserver" ] && echo "No configuration servers found" && exit 1
masters=`a=0 ; $MONGO "$confserver"/config --quiet --eval "db.databases.find( { "partitioned" : true }, { "primary" : 1 } ).forEach(printjson)" | "${PWD}"/../../lib/json2txt | while read LINE ; do i=${LINE%%/*} ; if [[ "$i" == "$a" ]] ; then echo -n -e "|${LINE##*|}" ; else echo -n -e "\n${LINE##*|}" ; a=$i ; fi  ; done ; echo ; unset a`
for db in `ls -1 "${PWD}/../../standalone/${saname}/data"/shards.*.* | cut -d'/' -f2 | cut -d'.' -f2 | sort | uniq` ; do
  db_header $db
  for coll in "${PWD}/../../standalone/${saname}/data"/shards.${db}.* ; do
    colldata=`find "${PWD}/../../standalone/${saname}/data" -name ${db}.dat -mmin $FREQ2 2>/dev/null`
    if [ -n "$colldata" ] ; then
      colldata=`grep ^$coll\| "$colldata"`
#    else
#    
    fi
    coll_header $colldata
    print_shards $coll
    coll_bottom
  done
  db_bottom
done

