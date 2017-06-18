#!/usr/bin/env bash
# Copyright (C) 2008-2009 Igor Simonov (me@igorsimonov.com)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

[ -h $0 ] && xcommand=`readlink $0` || xcommand=$0
rcommand=${xcommand##*/}
rpath=${xcommand%/*}
#*/
[ -z "$M_ROOT" ] && M_ROOT="$rpath/.."

if [ -z "$2" ]; then
  echo "Error: configuration file is not defined for $0" >> "$LOG"
  exit 1
else
  source "$2"
fi

MYSQL=`which mysql 2>/dev/null`
MYSQLDUMP=`which mysqldump 2>/dev/null`
GZIP=`which gzip 2>/dev/null`

[ -z "$MYSQL" ] && echo "Mysql CLI not found"
[ -z "$MYSQLDUMP" ] && echo "Mysqldump utility not found"

[ -f "$rpath/${rcommand%%.*}.conf" ] && source "$rpath/${rcommand%%.*}.conf"

[ -z "$dbhost" ] && dbhost=localhost
[ -z "$dbport" ] && dbport=3306

[ -z "$dbuser" ] && errorexit "User not specified"
[ -z "$dbpassword" ] && errorexit "Password not specified"

export MYSQL_PWD="$dbpassword"

case $compression in
gzip|gz)
  compressor=`which gzip 2>/dev/null`
  extension="gz"
  ;;
bzip2|bz2)
  compressor=`which bzip2 2>/dev/null`
  extension="bz2"
  ;;
xz)
  compressor=`which xz 2>/dev/null`
  extension="xz"
  ;;
*)
  errorexit "unknown compressor"
  ;;
esac
    
if [ -z "$mysqldblist" ]; then
  mysqldblist="$($MYSQL "-u $dbuser" -h $dbhost -P $dbport -Bse 'show databases')"
fi

for db in $mysqldblist ; do
  dumpdb=true
  if [ -n "$mysqldbexclude" ]; then
    for excl in $mysqldbexclude ; do
      [ "$db" == "$excl" ] && dumpdb=false
    done
  fi
    
  if $dumpdb ; then
    if [ -n "$compressor" ]; then
      backupfile="$targetpath/${db}.${archname}.sql.${extension}"
      $MYSQLDUMP "-u $dbuser" -h${dbhost}:${dbport} $OPTIONS "$db" 2>>"$M_TEMP/m_backup.error" | $compressor > $backupfile 2>>"$M_TEMP/m_backup.error" && echo "mysql: $db dumped OK"
    else
      backupfile="$targetpath/${db}.${archname}.sql"
      $MYSQLDUMP "-u $dbuser" -h${dbhost}:${dbport} $OPTIONS "$db" 2>>"$M_TEMP/m_backup.error" > $backupfile && echo "mysql: $db dumped OK"
    fi
  fi
done


