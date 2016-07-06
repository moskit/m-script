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
#*/ (this is needed to fool vi syntax highlighting)

if [ -z "$1" ]; then
  echo "Error: configuration file is not defined for $0" >> "$rpath/m_backup.error"
  exit 1
else
  source "$1"
fi

MYSQL=`which mysql 2>/dev/null`
MYSQLDUMP=`which mysqldump 2>/dev/null`
CHOWN=`which chown 2>/dev/null`
CHMOD=`which chmod 2>/dev/null`
GZIP=`which gzip 2>/dev/null`

[ -z "$MYSQL" ] && echo "ERROR: mysql CLI not found" >> "$rpath/m_backup.error" && exit 1
[ -z "$MYSQLDUMP" ] && echo "ERROR: mysqldump utility not found" >> "$rpath/m_backup.error" && exit 1
[ -z "$mysqluser" ] && echo "ERROR: database user not defined" >> "$rpath/m_backup.error" && exit 1
[ -z "$mysqlhost" ] && echo "ERROR: database host not defined" >> "$rpath/m_backup.error" && exit 1
[ -n "$localbackuppath" ] && DEST="$localbackuppath" || DEST="$rpath"
OPTIONS="$mysqldumpoptions"

MBD="$DEST/backup.tmp/mysql"

if [ -z "$2" ]; then
  archname="$(hostname -f).$(date +"%Y.%m.%d_%H.%M")"
else
  archname="$2"
fi

[ ! -d $MBD ] && install -d $MBD
if [ -n "$mysqlpass" ]; then
  PASS="-p$mysqlpass"
fi

if [ -n "$debugflag" ]; then
  VERB="-v"
fi

if [ -z "$mysqldblist" ]; then
  mysqldblist="$($MYSQL "-u$mysqluser" -h $mysqlhost "$PASS" -Bse 'show databases')" 2>>"$rpath/m_backup.error"
fi

for db in $mysqldblist ; do
  dumpdb=true
  if [ -n "$mysqldbexclude" ]; then
    for excl in $mysqldbexclude ; do
      [ "$db" == "$excl" ] && dumpdb=false
    done
  fi
    
  if $dumpdb ; then
    FILE="$MBD/$db.$archname.gz"
    $MYSQLDUMP "-u$mysqluser" -h$mysqlhost "$PASS" $VERB $OPTIONS "$db" 2>>"$rpath/m_backup.error" | $GZIP > $FILE 2>>"$rpath/m_backup.error" && echo "mysql: $db dumped OK" >>"$rpath/m_backup.log"
  fi
done


