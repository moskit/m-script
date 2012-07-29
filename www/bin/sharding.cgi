#!/bin/bash

saname="MongoDB"
scriptname=${0%.cgi}
scriptname=${scriptname##*/}
MONGO=`which mongo 2>/dev/null`
source "${PWD}/../../conf/mon.conf"
source "${PWD}/../../lib/dash_functions.sh"
FREQ2=`expr $FREQ \* 2`

print_cgi_headers
print_nav_bar "MongoDB|Servers" "sharding|Sharding" "collections|Collections"
#confserver=`tail -1 "${PWD}/../../standalone/${saname}/mongo_config_servers.list"`
#[ -z "$confserver" ] && echo "No configuration servers found" && exit 1
#masters=`a=0 ; $MONGO "$confserver"/config --quiet --eval "db.databases.find( { "partitioned" : true }, { "primary" : 1 } ).forEach(printjson)" | "${PWD}"/../../lib/json2txt | while read LINE ; do i=${LINE%%/*} ; if [[ "$i" == "$a" ]] ; then echo -n -e "|${LINE##*|}" ; else echo -n -e "\n${LINE##*|}" ; a=$i ; fi  ; done ; echo ; unset a`

for db in `find "${PWD}/../../standalone/${saname}/data" -mindepth 1 -maxdepth 1 -type f -name shards.*.* | sed "s|${PWD}/../../standalone/${saname}/data/shards.||" | cut -d'.' -f1 | sort | uniq` ; do
  print_cluster_header "$db"
  for coll in "${PWD}/../../standalone/${saname}/data"/shards.${db}.* ; do
    print_line_title shards `echo $coll | sed "s|${PWD}/../../standalone/${saname}/data/shards.${db}.||"`
    echo $coll
    close_line
  done
  print_cluster_bottom
done

