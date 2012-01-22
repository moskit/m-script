#!/bin/bash
echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""

echo "<ul id=\"tabnav\">"
echo "<li class=\"tab active\" id=\"dash\" onClick=\"initMonitors('dash', 0)\">Servers Health</li>"
for standalone in `find ${PWD}/../../standalone/rc -type l` ; do
  standalone=`readlink $standalone | tr ' ' '_'`
  standalone=${standalone##*/}
  echo "<li class=\"tab\" id=\"${standalone}\" onClick=\"initMonitors('${standalone}', 0)\">${standalone}</li>"
done
echo "</ul>"

