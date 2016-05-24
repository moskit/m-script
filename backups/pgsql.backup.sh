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

source "$rpath/conf/mon.conf"

if [ -z "$1" ]; then
  echo "Error: configuration file is not defined for $0" >> "$rpath/m_backup.error"
  exit 1
else
  source "$1"
fi

PSQL="$(which psql)"
PG_DUMP="$(which pg_dump)"
CHOWN="$(which chown)"
CHMOD="$(which chmod)"
GZIP="$(which gzip)"
BZIP2="$(which bzip2)"

if [ -n "$pgsqlpass" ]; then
  echo "*:*:*:*:$pgsqlpass" > ~/.pgpass && chmod 600 ~/.pgpass
fi
[ -z "$pgsqluser" ] && echo "Error: database user not defined" >> "$rpath/m_backup.error" && exit 1
[ -z "$pgsqlhost" ] && echo "Error: database host not defined" >> "$rpath/m_backup.error" && exit 1
[ -n "$localbackuppath" ] && DEST="$localbackuppath" || DEST="$rpath"

MBD="$DEST/backup.tmp/pgsql"

if [ -z "$2" ]; then
  archname="$(hostname -f).$(date +"%Y.%m.%d_%H.%M")"
else
  archname="$2"
fi

[ -d "$MBD" ] || install -d "$MBD"
rm -f "$M_TEMP/pgsql.backup.error" 2>/dev/null

# Get all database list first
if [ -z "$pgdblist" ]; then
  pgdblist="$($PSQL -U $pgsqluser -h $pgsqlhost  -t --list -A | cut -d'|' -f1 | grep -vE "^postgres|^template" 2>"$M_TEMP/pgsql.backup.error")"
  [ `cat "$M_TEMP/pgsql.backup.error" 2>/dev/null | wc -l` -gt 0 ] && echo "pgsql: Error getting database list:" >> "$rpath/m_backup.log" && cat "$M_TEMP/pgsql.backup.error" >> "$rpath/m_backup.error" && exit 1
fi

for db in $pgdblist ; do
  dumpdb=true
  if [ -n "$pgdbexclude" ]; then
  	for excl in $pgdbexclude ; do
  	    [ "$db" == "$excl" ] && dumpdb=false
  	done
  fi
    
  if $dumpdb ; then
    rm -f "$M_TEMP/pgsql.backup.error" 2>/dev/null
  	FILE="$MBD/$db.$archname.gz"
    $PG_DUMP -U $pgsqluser -h $pgsqlhost $db 2>>"$M_TEMP/pgsql.backup.error" | $GZIP > $FILE 2>>"$M_TEMP/pgsql.backup.error"
    [ `cat "$M_TEMP/pgsql.backup.error" 2>/dev/null | wc -l` -gt 0 ] && echo "pgsql: $db backup failed" >> "$rpath/m_backup.log" && cat "$M_TEMP/pgsql.backup.error" >> "$rpath/m_backup.error" || echo "pgsql: $db dumped OK" >> "$rpath/m_backup.log"
  fi
done

