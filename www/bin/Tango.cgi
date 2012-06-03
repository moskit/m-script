#!/bin/bash

scriptname=${0%.cgi}; scriptname=${scriptname##*/}

source "${PWD}/../../lib/dash_functions.sh"

print_cgi_headers

#print_page_title "NameColumnTitle|Data1|Data2|..."

print_cluster_header End-to-End

#  print_line_title tangobench End-to-End
    print_dashlines tangobench folder tango
#  close_line
print_cluster_bottom

print_cluster_header Log Monitor
#  print_line_title none Log Reader
    print_dashlines showlogs folder tango_logger
#  close_line

print_cluster_bottom


