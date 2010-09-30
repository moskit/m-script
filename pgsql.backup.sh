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


PSQL="$(which psql)"
PG_DUMP="$(which pg_dump)"
CHOWN="$(which chown)"
CHMOD="$(which chmod)"
GZIP="$(which gzip)"
BZIP2="$(which bzip2)"

[ -h $0 ] && xcommand=`readlink $0` || xcommand=$0
rcommand=${xcommand##*/}
rpath=${xcommand%/*}
#*/ (this is needed to fool vi syntax highlighting)

if [ "X${1}" == "X" ]; then
  echo "Error: configuration file is not defined for $0" >> ${rpath}/m_backup.error
  exit 1
else
  source ${1}
fi
if [ "X$pgsqlpass" != "X" ]; then
  echo "*:*:*:*:${pgsqlpass}" > ~/.pgpass && chmod 600 ~/.pgpass
fi
[ "X$pgsqluser" == "X" ] && echo "Error: database user not defined" >> ${rpath}/m_backup.error && exit 1
[ "X$pgsqlhost" == "X" ] && echo "Error: database host not defined" >> ${rpath}/m_backup.error && exit 1
[ "X${localbackuppath}" != "X" ] && DEST="${localbackuppath}" || DEST=${rpath}

MBD="$DEST/backup.tmp/pgsql"

if [ "X${2}" == "X" ]; then
  archname="$(hostname -f).$(date +"%Y.%m.%d_%H.%M")"
else
  archname="${2}"
fi

[ ! -d $MBD ] && install -d $MBD

# Get all database list first
if [ "X${pgdblist}" == "X" ]; then
  pgdblist="$($PSQL -U $pgsqluser -h $pgsqlhost --list -t | awk '{print $1}' | grep -vE '^$|^:|^template[0-9]')" 2>>${rpath}/m_backup.error
fi

for db in $pgdblist
do
  skipdb=-1
  if [ "X$pgdbexclude" != "X" ]; then
  	for i in $pgdbexclude
  	do
  	    [ "$db" == "$i" ] && skipdb=1 || :
  	done
  fi
    
  if [ "$skipdb" == "-1" ]; then
  	FILE="$MBD/$db.$archname.gz"
    $PG_DUMP -U $pgsqluser -h $pgsqlhost $db 2>>${rpath}/m_backup.error | $GZIP -9 > $FILE 2>>${rpath}/m_backup.error && echo "pgsql: $db dumped OK" >>${rpath}/m_backup.log
  fi
done

