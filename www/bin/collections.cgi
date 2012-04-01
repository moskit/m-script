#!/bin/bash
echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""

saname="MongoDB"
scriptname=${0%.cgi}
scriptname=${scriptname##*/}

cat "${PWD}/../../standalone/${saname}/views_nav_bar.html" | sed "/\"${scriptname}\"/s/\"viewsbutton\"/\"viewsbutton active\"/"


