#!/bin/bash

echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""
[ -f "/sbin/ifconfig" ] && IFCFG=/sbin/ifconfig || IFCFG=`which ifconfig 2>/dev/null`
[ "X$IFCFG" != "X" ] && localip=`$IFCFG | sed '/inet\ /!d;s/.*r://;s/\ .*//' | grep -v '127.0.0.1'` || localip="ifconfig_not_found"
source "${PWD}/../../conf/dash.conf"
timerange=`expr $slotline_length \* $freqdef` || timerange=10000
oldest=`date -d "-$timerange sec"`
hour=`date -d "$oldest" +"%H"`
echo "<div class=\"dashtitle\">"
echo "<div class=\"clustername\">Cluster</div>"
echo "<div class=\"server\">"
echo "<span class=\"servername\">Server</span>"
for ((n=0; n<$slotline_length; n++)) ; do
  timediff=`expr $n \* $freqdef`
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
echo "<div class=\"pageline\"></div>"
for cluster in `find ../servers/* -maxdepth 0 -type d`
do
  echo "<div class=\"clustername\">${cluster##*/}</div>"
  echo "<div class=\"cluster\" id=\"${cluster##*/}\">"
  if [ "X${cluster##*/}" == "Xlocalhost" ] ; then
    echo "<div class=\"server\" id=\"localhost\">"
      echo "<span class=\"servername\"><a href=\"/servers/localhost\">localhost</a></span>"
      cat "../servers/localhost/dash.html" 2>/dev/null || echo "No data"
    echo "</div>"
    echo "</div>"
    continue
  fi
  for server in `find $cluster/* -maxdepth 0 -type d | sort`
  do
    echo "<div class=\"server\" id=\"${server##*/}\">"
      echo "<span class=\"servername\"><a href=\"/servers/${cluster##*/}/${server##*/}\">${server##*/}</a></span>"
      cat "../servers/${server}/dash.html" 2>/dev/null || echo "No data"
    echo "</div>"
  done
  echo "</div>"
done

exit 0

