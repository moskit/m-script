#!/bin/bash

source "${PWD}/../../lib/dash_functions.sh"

print_cgi_headers
print_timeline Server
#print_page_title "NameColumnTitle|Data1|Data2|..."

open_cluster "SSH Logins"
close_cluster_line
open_line "localhost"
print_dashline showlogs folder "dict_blocker/localhost"
close_line
close_cluster
