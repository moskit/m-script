#!/bin/bash

source "$PWD/../../lib/dash_functions.sh"

print_cgi_headers

print_timeline "Server"

open_cluster "SSH Logins"
close_cluster_line
print_dashlines "auth"
close_cluster

open_cluster "TMP Monitor"
close_cluster_line
print_dashlines "tmpexe"
close_cluster

