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

for ngconf in $ngconfs ; do
  ngconf=${ngconf##*/}
  [ -e "$rpath/${ngconf}.conf" ] && source "$rpath/${ngconf}.conf"
  [ -z "$NGINX_SERVER" ] && echo "NGINX_SERVER is not defined" >&2 && continue
  [ -z "$file" ] && echo "file is not defined" >&2 && continue
  ngconfcloud=`echo "$NGINX_SERVER" | cut -sd'|' -f1`
  ngconfcluster=`echo "$NGINX_SERVER" | cut -sd'|' -f2`
  ngconfserver=`echo "$NGINX_SERVER" | cut -d'|' -f3`
  ngconfserver_sn=`echo "$ngconfserver" | tr '-' '_'`
  open_cluster $ngconfserver
    print_cluster_inline title1 title2 title3 title4
    close_cluster_line

    open_line "Performance"
      record=`sqlite3 $M_ROOT/standalone/%{SAM}%/${ngconfserver}.db \"select requests,users,err4xx,err5xx from ${ngconfserver_sn}_perf order by timeindex desc limit 1\" 2>&1`
      requests=`echo "$record" | cut -sd'|' -f1`
      users=`echo "$record" | cut -sd'|' -f2`
      err4xx=`echo "$record" | cut -sd'|' -f3`
      err5xx=`echo "$record" | cut -sd'|' -f4`
      print_inline requests users err4xx err5xx
    close_line
    print_dashlines "$ngconfserver" "%{SAM}%/requests"
  close_cluster
done

