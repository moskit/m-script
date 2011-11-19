#!/bin/bash

echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""
[ -f "/sbin/ifconfig" ] && IFCFG=/sbin/ifconfig || IFCFG=`which ifconfig 2>/dev/null`
[ "X$IFCFG" != "X" ] && localip=`$IFCFG | sed '/inet\ /!d;s/.*r://;s/\ .*//' | grep -v '127.0.0.1'` || localip="ifconfig_not_found"
source "${PWD}/../../conf/dash.conf"
timerange=`expr $slotline_length \* \( $freqdef - $timeshift \)` || timerange=10000
oldest=`date -d "-$timerange sec"`
hour=`date -d "$oldest" +"%H"`
echo "<div class=\"dashtitle\">"
echo "<div class=\"clustername\"><span class=\"indent\">Cluster</span></div>"
echo "<div class=\"server\">"
echo "<span class=\"servername\">Server</span>"
freqdef1=`expr $freqdef + 5`
for ((n=0; n<$slotline_length; n++)) ; do
  timediff=`expr $n \* \( $freqdef - $timeshift \)`
  timestamp=`date -d "$oldest +$timediff sec"`
  hournew=`date -d "$timestamp" +"%H"`
  if [ "X$hournew" == "X$hour" ] ; then
    echo "<div class=\"chunk\">&nbsp;</div>"
  else
    echo "<div class=\"chunk hour\">${hournew}:00</div>"
    hour=$hournew
  fi
done
echo "</div>"
echo "</div>"

for cluster in `find ../servers/* -maxdepth 0 -type d 2>/dev/null`
do
  echo "<div class=\"clustername\"><span class=\"indent\">${cluster##*/}</span></div>"
  echo "<div class=\"cluster\" id=\"${cluster##*/}\">"
  if [ "X${cluster##*/}" == "Xlocalhost" ] ; then
    echo "<div class=\"server\" id=\"localhost\">"
    
      echo "<span class=\"servername\" onclick=\"showDetails('localhost','serverdetails')\">localhost</span>"
      
      cat "../servers/localhost/dash.html" 2>/dev/null || echo "No data"
    echo "</div>"
    echo "<div class=\"details\" id=\"localhost_details\"></div>"
    echo "</div>"
    continue
  fi
  for server in `find $cluster/* -maxdepth 0 -type d 2>/dev/null | sort`
  do
    echo "<div class=\"server\" id=\"${server##*/}\">"
      echo "<span class=\"servername\" onclick=\"showDetails('${server##*/','serverdetails')\">${server##*/}</span>"
      cat "../servers/${server}/dash.html" 2>/dev/null || echo "No data"
      [ -e "../servers/${server}/notfound" ] && echo "<div class=\"chunk\"><div style=\"width:4px;height:4px;margin: 8px 3px 8px 3px;background-color: orange;\">&nbsp;</div></div>"
      [ -e "../servers/${server}/stopped" ] && echo "<div class=\"chunk\"><div style=\"width:4px;height:4px;margin: 8px 3px 8px 3px;background-color: red;\">&nbsp;</div></div>"
    echo "</div>"
    echo "<div class=\"details\" id=\"${server##*/}_details\"></div>"
  done
  echo "</div>"
done

exit 0

