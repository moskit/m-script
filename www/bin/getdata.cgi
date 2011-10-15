#!/bin/bash

echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""

[ -h $0 ] && xcommand=`readlink $0` || xcommand=$0
rcommand=${xcommand##*/}
rpath=${xcommand%/*} #*/
rpath="${rpath}"

path=`echo ${QUERY_STRING} | tr '&' '\n' | grep '^path' | sed 's@path=@@' | sed 's@%2F@/@g' | sed 's@%20@ @g'`
path="${path##*../}"
cat "${rpath}/../${path}"

