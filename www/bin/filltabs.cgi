#!/bin/bash
echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""

echo "<ul id=\"tabnav\">"
echo "<li class=\"tab\" id=\"dash\"><a href=\"#\" onClick=\"initMonitors('dash')\">Servers Health</a></li>"
for standalone in `find ${PWD}/../../${standalone}/* -maxdepth 0 -type d` ; do
  echo "<li class=\"tab\" id=\"${standalone}\"><a href=\"#\" onClick=\"initMonitors('${standalone}')\">Servers Health</a></li>"
done
echo "</ul>"

