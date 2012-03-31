#!/bin/bash
echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""

scriptname=${0%.cgi}
scriptname=${scriptname##*/}

cat "${PWD}/../../standalone/${scriptname}/views_nav_bar.html" | sed "/\"${scriptname}\"/s/\"viewsbutton\"/\"viewsbutton active\"/"


