#!/bin/bash
echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
${PWD}/../../standalone/${scriptname}/mongodb.mon > ${PWD}/${scriptname}.tmp
${PWD}/../../lib/txt2html ${PWD}/${scriptname}.tmp
rm -f ${PWD}/${scriptname}.tmp


