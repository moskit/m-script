#!/bin/bash
scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "$PWD/../../lib/dash_functions.sh"
source "$PWD/../../standalone/%{SAM}%/nginx.conf"
print_cgi_headers
print_timeline "Server"

title1="requests"
title2="users"
title3="4xx"
title4="5xx"

if [ -n "$CONF_LIST" ]; then
  ngconfs=`echo "$CONF_LIST" | tr ',' ' '`
else
  ngconfs=$NGINX_SERVER
fi

for target in $ngconfs ; do
name="${target##*/}"
open_cluster $name
  print_cluster_inline title1 title2 title3 title4
  close_cluster_line

  open_line "Performance"
    record=`sqlite3 $M_ROOT/standalone/%{SAM}%/${target}.db \"select requests,users,err4xx,err5xx from ${name}_perf order by timeindex desc limit 1\" 2>&1`
    requests=`echo "$record" | cut -sd'|' -f1`
    users=`echo "$record" | cut -sd'|' -f2`
    err4xx=`echo "$record" | cut -sd'|' -f3`
    err5xx=`echo "$record" | cut -sd'|' -f4`
    print_inline requests users err4xx err5xx
  close_line
  print_dashlines "$name" "%{SAM}%/requests"
close_cluster
done

