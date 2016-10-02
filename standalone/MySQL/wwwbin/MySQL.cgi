#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "$PWD/../../lib/dash_functions.sh"

print_cgi_headers
print_nav_bar "MySQL|Performance" "MySQL/resources|Resources" "MySQL/databases|Data" "MySQL/logreader|Logs"

print_page_title "Node" "Qeries / sec" "Connections / sec" "Cache hits ratio, %" "Table locks waited, %" "Threads active" "Threads created / sec"

