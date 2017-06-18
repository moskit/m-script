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

[ -z "$dbhost" ] && dbhost=localhost
[ -z "$dbport" ] && dbport=3306
[ -z "$dbuser" ] && errorexit "User not specified"
[ -z "$dbpassword" ] && errorexit "Password not specified"
server="${dbuser}:${dbpassword}@${dbhost}:${dbport}"

export MYSQL_PWD="$dbpassword"

MYSQL=`which mysql 2>/dev/null`
[ -z "$MYSQL" ] && echo "Mysql CLI not found"
STAT=`which stat 2>/dev/null`
[ -z "$STAT" ] && echo "Utility stat not found"

# bin-log flush must be performed by its original owner
indexfile=`$MYSQL -u $dbuser -h ${dbhost} -P ${dbport} -Bse "show variables like 'log_bin_index'" | tr '\t' '|' | cut -sd'|' -f2`
mysqluser=`$STAT -c %U "$indexfile"`
mysqlgroup=`$STAT -c %G "$indexfile"`

[ -d "$targetpath/$1" ] || install -o $mysqluser -g $mysqlgroup -d "$targetpath/$1"

MBLM=`which mysqlbinlogmove 2>/dev/null`
[ -z "$MBLM" ] && echo "Utility mysqlbinlogmove from MySQL Utilities package not found" && exit 1

su - $mysqluser -s /bin/bash -c "$MBLM $OPTIONS --server=\"$server\" \"$targetpath/$1\""

