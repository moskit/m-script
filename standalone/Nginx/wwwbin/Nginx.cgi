#!/bin/bash
scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "$PWD/../../lib/dash_functions.sh"
print_cgi_headers
print_timeline "Server"

title1="requests"
title2="users"
title3="4xx"
title4="5xx"

open_cluster "orders.whmcs"
  print_cluster_inline title1 title2 title3 title4
  close_cluster_line

  open_line "Performance"
    record=`/opt/m/helpers/mssh proxy sqlite3 $M_ROOT/standalone/HTTP/orders.whmcs.db \"select requests,users,err4xx,err5xx from orders_whmcs order by timeindex desc limit 1\" 2>&1`
    requests=`echo "$record" | cut -sd'|' -f1`
    users=`echo "$record" | cut -sd'|' -f2`
    err4xx=`echo "$record" | cut -sd'|' -f3`
    err5xx=`echo "$record" | cut -sd'|' -f4`
    print_inline requests users err4xx err5xx
  close_line
  print_dashlines "orders.whmcs" "HTTP/requests"
close_cluster

open_cluster "fastfollowerz.com"
  print_cluster_inline title1 title2 title3 title4
  close_cluster_line

  open_line "Performance"
    record=`/opt/m/helpers/mssh proxy sqlite3 $M_ROOT/standalone/HTTP/fastfollowerz.com.db \"select requests,users,err4xx,err5xx from fastfollowerz_com order by timeindex desc limit 1\" 2>&1`
    requests=`echo "$record" | cut -sd'|' -f1`
    users=`echo "$record" | cut -sd'|' -f2`
    err4xx=`echo "$record" | cut -sd'|' -f3`
    err5xx=`echo "$record" | cut -sd'|' -f4`
    print_inline requests users err4xx err5xx
  close_line
  print_dashlines "fastfollowerz.com" "HTTP/requests"
close_cluster

open_cluster "fastfollowerz.co"
close_cluster_line
print_dashlines "fastfollowerz.co" "HTTP/requests"
close_cluster

open_cluster "reporting"
close_cluster_line
print_dashlines "reporting" "HTTP/requests"
close_cluster

