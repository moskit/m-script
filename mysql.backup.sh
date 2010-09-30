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


MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
CHOWN="$(which chown)"
CHMOD="$(which chmod)"
GZIP="$(which gzip)"

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

[ "X$mysqluser" == "X" ] && echo "Error: database user not defined" >> ${rpath}/m_backup.error && exit 1
[ "X$mysqlhost" == "X" ] && echo "Error: database host not defined" >> ${rpath}/m_backup.error && exit 1
[ "X${localbackuppath}" != "X" ] && DEST="${localbackuppath}" || DEST=${rpath}

MBD="$DEST/backup.tmp/mysql"

if [ "X${2}" == "X" ]; then
  archname="$(hostname -f).$(date +"%Y.%m.%d_%H.%M")"
else
  archname="${2}"
fi

[ ! -d $MBD ] && install -d $MBD
if [ "X$mysqlpass" == "X" ]; then
  PASS=""
else
  PASS="-p$mysqlpass"
fi

if [ "X$mysqldblist" == "X" ]; then
  mysqldblist="$($MYSQL -u $mysqluser -h $mysqlhost $PASS -Bse 'show databases')" 2>>${rpath}/m_backup.error
fi

for db in $mysqldblist
do
  skipdb=-1
  if [ "$mysqldbexclude" != "" ]; then
  	for i in $mysqldbexclude
  	do
  	    [ "$db" == "$i" ] && skipdb=1 || :
  	done
  fi
    
  if [ "$skipdb" == "-1" ]; then
  	FILE="$MBD/$db.$archname.gz"
    $MYSQLDUMP -u$mysqluser -h$mysqlhost $PASS $db 2>>${rpath}/m_backup.error | $GZIP -9 > $FILE 2>>${rpath}/m_backup.error && echo "mysql: $db dumped OK" >>${rpath}/m_backup.log
  fi
done


