#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "$PWD/../../lib/dash_functions.sh"
print_cgi_headers
print_nav_bar "Postfix|Activity" "Postfix/postfix_queue|Queue"

print_timeline "Server"
print_dashlines "postfix_activity" "Postfix/postfix_activity"

