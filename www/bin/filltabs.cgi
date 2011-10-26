#!/bin/bash
echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""

echo "<ul id=\"tabnav\">"
echo "<li class=\"tab active\" id=\"dash\"><a href=\"#\" onClick=\"initMonitors('dash')\">Servers Health</a></li>"
for standalone in `find ${PWD}/../../standalone/rc -type l` ; do
  standalone=`readlink $standalone`
  standalone=${standalone##*/}
  echo "<li class=\"tab\" id=\"${standalone}\" onClick=\"initMonitors('${standalone}')\">${standalone}</li>"
done
echo "</ul>"

