#!/bin/bash

source "$PWD/../../lib/dash_functions.sh"

print_cgi_headers
print_timeline Server
#print_page_title "NameColumnTitle|Data1|Data2|..."

open_cluster "SSH Logins"
close_cluster_line
for cld in ../auth/* ; do
if [ "_$cld" == "_localhost" ]; then
  open_line "localhost"
  print_dashline showlogs folder "auth/localhost"
  close_line
else
  for cls in ../auth/$cld/* ; do
    for node in ../auth/$cld/$cls/* ; do
      open_line "$node||${cld}_${cls}_${node}"
      
fi
close_cluster

open_cluster "TMP Monitor"
close_cluster_line
open_line "localhost"
print_dashline showlogs folder "tmpexe/localhost"
close_line
close_cluster
