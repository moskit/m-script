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

if [ "X${1}" == "X" ]; then
  echo "Error: configuration file is not defined for $0" >> ${rpath}/m_backup.error
  exit 1
else
  source ${1}
fi

MONGO="$(which mongo 2>/dev/null)"
MONGODUMP="$(which mongodump 2>/dev/null)"
GZIP="$(which gzip 2>/dev/null)"
BZIP2="$(which bzip2 2>/dev/null)"

if [ "X$compression" == "Xgzip" ] && [ -n "$GZIP" ] ; then
  compress=$GZIP
  ext="gz"
  TAR="`which tar 2>/dev/null` czf"
fi

if [ "X$compression" == "Xbzip2" ] && [ -n "$BZIP2" ] ; then
  compress=$BZIP2
  ext="bz2"
  TAR="`which tar 2>/dev/null` cjf"
fi

[ "X$mongohosts" == "X" ] && echo "Error: database host not defined" >> ${rpath}/m_backup.error && exit 1
[ "X${localbackuppath}" != "X" ] && DEST="${localbackuppath}" || DEST=${rpath}

MBD="$DEST/backup.tmp/mongo"

[ ! -d $MBD ] && install -d $MBD
if [ "X$mongopass" == "X" ]; then
  PASS=""
else
  PASS="--password=$mongopass"
fi

if [ "X$mongouser" == "X" ]; then
  USER=""
else
  USER="--username=$mongouser"
fi

for mongohost in $mongohosts ; do
  DBHOST=$($MONGO --host $mongohost --quiet --eval "var im = rs.isMaster(); if(im.ismaster && im.hosts) { im.hosts[1] } else { '$mongohost' }" | tail -1) 2>>${rpath}/m_backup.error
  [ $? -eq 0 ] && break
done
 
echo "Host $DBHOST selected." >>${rpath}/m_backup.log
if [ "X${2}" == "X" ]; then
  archname="$DBHOST.$(date +"%Y.%m.%d_%H.%M")"
else
  archname="${2}"
fi

if [ "X$mongodblist" == "X" ]; then
  mongodblist="$($MONGO $DBHOST/admin --eval "db.runCommand( { listDatabases : 1 } ).databases.forEach ( function(d) { print( '=' + d.name ) } )" | grep ^= | sed 's|^=||g')" 2>>${rpath}/m_backup.error
fi

for db in $mongodblist
do
  skipdb=-1
  if [ "$mongodbexclude" != "" ]; then
  	for i in $mongodbexclude
  	do
  	  [ "$db" == "$i" ] && skipdb=1 || :
  	done
  fi
  
  if [ "$skipdb" == "-1" ]; then
### Works if version >= 1.7, avoids intermediate space usage by uncompressed dumps
### Note that it doesn't dump indexes
#    if [ -n "$compress" ] ; then
#    for collection in `mongo $DBHOST/$db --eval "db.getCollectionNames()" | tail -1 | sed 's|,| |g'` ; do
#      $MONGODUMP $USER $PASS --host $mongohost --db $db --collection $collection --out - | $compress > "${MBD}/${db}.${archname}/${collection}.bson.${ext}" 2>>${rpath}/m_backup.error
#    done
#    fi
    $MONGODUMP --host $mongohost --db $db $USER $PASS --out "${MBD}/${db}.${archname}" 2>>${rpath}/m_backup.error && echo "mongo: $db dumped OK" >>${rpath}/m_backup.log
    [ -n "$TAR" ] && $TAR "${MBD}/${db}.${archname}.tar.${ext}" "${MBD}/${db}.${archname}" 2>>${rpath}/m_backup.error
    rm -rf "${MBD}/${db}.${archname}" 2>>${rpath}/m_backup.error
  fi
done


