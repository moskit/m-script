#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "$PWD/../../lib/dash_functions.sh"
print_cgi_headers
print_nav_bar "Postfix|Activity" "Postfix/postfix_queue|Queue"

print_timeline "Server"
open_cluster "Activity"
close_cluster_line
print_dashlines "postfix_activity" "Postfix/postfix_activity"
close_cluster
