#!/bin/bash

[ -h $0 ] && xcommand=`readlink $0` || xcommand=$0
rcommand=${xcommand##*/}
rpath=${xcommand%/*}
#*/
[ -z "$M_ROOT" ] && M_ROOT="$rpath/.."

if [ -z "$2" ]; then
  echo "Error: configuration file is not specified for $0" >> "$LOG"
  exit 1
else
  source "$2"
fi

[ -f "$rpath/${rcommand%%.*}.conf" ] && source "$rpath/${rcommand%%.*}.conf"

# server can be login-path
if [ -z "$server" ]; then
  [ -z "$dbhost" ] && dbhost=localhost
  [ -z "$dbport" ] && dbport=3306
  [ -z "$dbuser" ] && errorexit "User not specified"
  [ -z "$dbpassword" ] && errorexit "Password not specified"
  server="${dbuser}:${dbpassword}@${dbhost}:${dbport}"
fi

[ -d "$targetpath/$1" ] || install -d "$targetpath/$1"

MBLM=`which mysqlbinlogmove 2>/dev/null`
[ -z "$MBLM" ] && echo "Utility mysqlbinlogmove from MySQL Utilities package not found" && exit 1

install -d "$targetpath/$1"
$MBLM $OPTIONS --server="$server" --log-type=all "$targetpath/$1"
