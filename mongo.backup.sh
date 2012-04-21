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

rpath=$(readlink -m "$BASH_SOURCE")
rcommand=${rpath##*/}
rpath=${rpath%/*}
#*/

if [ -z "$1" ]; then
  echo "Error: configuration file is not defined for $0" >> ${rpath}/m_backup.error
  exit 1
else
  source ${1}
fi

MONGO="$(which mongo 2>/dev/null)"
MONGODUMP="$(which mongodump 2>/dev/null)"
GZIP="$(which gzip 2>/dev/null)"
BZIP2="$(which bzip2 2>/dev/null)"

[ -z "$MONGO" ] && echo "Mongo client (mongo) not found, exiting." && exit 1
[ -z "$MONGODUMP" ] && echo "Mongo dump utility (mongodump) not found, exiting." && exit 1

[ -n $debugflag ] && stdinto="${rpath}/m_backup.log" || stdinto=/dev/null

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

if [ -n "$mongodbpertableconf" ] ; then
  IFS1=$IFS
  IFS='
'
  for table in `cat "$mongodbpertableconf" | grep -v ^$ | grep -v  ^#|grep -v ^[[:space:]]*#` ; do
    db=`echo $table | cut -d'|' -f1`
    coll=`echo $table | cut -d'|' -f2`
    bktype=`echo $table | cut -d'|' -f3`
    case bktype in
      full)
        $MONGODUMP --host $mongohost --db $db $USER $PASS --out "${MBD}/${db}.${coll}.${bktype}.${archname}" 1>>"$stdinto" 2>>${rpath}/logs/mongo.backup.tmp && echo "mongo: $db dumped successfully" >>${rpath}/m_backup.log || echo "mongo: $db dump failed" >>${rpath}/m_backup.log
        [ -n "$TAR" ] && $TAR "${MBD}/${db}.${coll}.${bktype}.${archname}.tar.${ext}" "${MBD}/${db}.${coll}.${bktype}.${archname}" 1>>"$stdinto" 2>>${rpath}/logs/mongo.backup.tmp
        cat ${rpath}/logs/mongo.backup.tmp | grep -v ^connected | grep -v 'Removing leading' >>${rpath}/m_backup.error
        rm -rf "${MBD}/${db}.${coll}.${bktype}.${archname}" 2>>${rpath}/m_backup.error
        ;;
      periodic)
        install -d "${rpath}/var/mongodb"
        if [ -f "${rpath}/var/mongodb/${table}.lastid" ] ; then
          lastid=`cat "${rpath}/var/mongodb/${table}.lastid"`
          if [ -n "$lastid" ] ; then
            echo "no op yet"
          else
            echo "File ${rpath}/var/mongodb/${table}.lastid exists but empty. Collection $table is not backuped!" >> ${rpath}/m_backup.error
          fi
        else
          echo "File ${rpath}/var/mongodb/${table}.lastid doesn't exist. Collection $table is not backuped!" >> ${rpath}/m_backup.error
        fi
        ;;
      *)
        echo "Don't know how to do $bktype backup" >> ${rpath}/m_backup.error
      ;;
    esac
  done
  IFS=$IFS1
else
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
  # --------------------
  # 
      $MONGODUMP --host $mongohost --db $db $USER $PASS --out "${MBD}/${db}.${archname}" 1>>"$stdinto" 2>${rpath}/logs/mongo.backup.tmp && echo "mongo: $db dumped successfully" >>${rpath}/m_backup.log || echo "mongo: $db dump failed" >>${rpath}/m_backup.log
      [ -n "$TAR" ] && $TAR "${MBD}/${db}.${archname}.tar.${ext}" "${MBD}/${db}.${archname}" 1>>"$stdinto" 2>>${rpath}/logs/mongo.backup.tmp
      cat ${rpath}/logs/mongo.backup.tmp | grep -v ^connected | grep -v 'Removing leading' >>${rpath}/m_backup.error
      rm -rf "${MBD}/${db}.${archname}" 2>>${rpath}/m_backup.error
    fi
  done
fi

