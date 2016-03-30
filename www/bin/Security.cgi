#!/bin/bash

source "$PWD/../../lib/dash_functions.sh"

print_cgi_headers
print_timeline Server
#print_page_title "NameColumnTitle|Data1|Data2|..."

for cld in $CLOUDS ; do

open_cluster "$cld|SSH Logins"
close_cluster_line
print_dashlines auth
close_cluster

open_cluster "$cld|TMP Monitor"
close_cluster_line
print_dashlines tmpexe
close_cluster

done
