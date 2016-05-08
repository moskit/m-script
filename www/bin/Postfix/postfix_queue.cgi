#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
M_ROOT="$PWD/../../.."
source "$M_ROOT/lib/dash_functions.sh"
print_cgi_headers
print_nav_bar "Postfix|Activity" "Postfix/postfix_queue|Queue"
source "$M_ROOT/standalone/Postfix/postfix.conf"

print_timeline "Server"
open_cluster "Queue"
print_dashlines "postfix_queue" "Postfix/postfix_queue"
close_cluster
