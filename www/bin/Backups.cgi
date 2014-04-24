#!/bin/bash

scriptname=${0%.cgi}; scriptname=${scriptname##*/}

source "$PWD/../../lib/dash_functions.sh"
source "$PWD/../../conf/mon.conf"

print_cgi_headers

source "$PWD/../../standalone/$scriptname/backups.conf"

for bconf in `echo $BACKUPS | tr ',' ' '` ; do
  open_cluster "Backup configuration: $bconf"
  cat "$PWD/../../standalone/$scriptname/data/${bconf}.local.dat" | while read LINE ; do 
done
