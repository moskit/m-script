#!/bin/bash

source "$PWD/../../lib/dash_functions.sh"

print_cgi_headers
print_timeline Server
#print_page_title "NameColumnTitle|Data1|Data2|..."

open_cluster "SSH Logins"
close_cluster_line
for cld in ../auth/* ; do
if [ "_${cld##*/}" == "_localhost" ]; then
  open_line "localhost"
  print_dashline "" folder "auth/localhost"
  close_line
else
  for cls in ../auth/$cld/* ; do
    print_dashlines "" folder "$cls"
  done
fi
done
close_cluster

open_cluster "TMP Monitor"
close_cluster_line
for cld in ../tmpexe/* ; do
if [ "_${cld##*/}" == "_localhost" ]; then
  open_line "localhost"
  print_dashline "" folder "tmpexe/localhost"
  close_line
else
  for cls in ../auth/$cld/* ; do
    print_dashlines "" folder "$cls"
  done
fi
done
close_cluster

