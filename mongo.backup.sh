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

rpath=$(readlink -f "$BASH_SOURCE")
rcommand=${rpath##*/}
rpath=${rpath%/*}
#*/

[ -z "$M_ROOT" ] && M_ROOT=$rpath

if [ -z "$1" ]; then
  echo "Error: configuration file is not defined for $0" >> "$rpath/m_backup.error"
  exit 1
else
  source ${1}
fi

MONGO="$(which mongo 2>/dev/null)"
MONGODUMP="$(which mongodump 2>/dev/null)"
GZIP="$(which gzip 2>/dev/null)"
BZIP2="$(which bzip2 2>/dev/null)"
LOG="$rpath/m_backup.log"

[ -z "$MONGO" ] && echo "Mongo client (mongo) not found, exiting." && exit 1
[ -z "$MONGODUMP" ] && echo "Mongo dump utility (mongodump) not found, exiting." && exit 1

log() {
  echo "`date +"%m.%d %H:%M:%S"` ${0##*/}: ${@}">>$LOG
}

full_coll_backup() {
  # storing the latest ID before dumping for the ID-based incremental backups.
  # Use --objcheck while restoring such backups if you care about duplicates.
  if [ "$3" == "_id" ]; then
    $MONGO "$DBHOST/$1" --quiet --eval "db.$2.find({},{$3:1}).sort({$3:-1}).limit(1).forEach(printjson)" 2>/dev/null | lib/json2txt | cut -d'|' -f2 > "$rpath/var/mongodb/${1}.${2}.${bktype}.lastid"
  else
    $MONGO "$DBHOST/$1" --quiet --eval "db.$2.find({},{$3:1,_id:0}).sort({$3:-1}).limit(1).forEach(printjson)" 2>/dev/null | lib/json2txt | cut -d'|' -f2 > "$rpath/var/mongodb/${1}.${2}.${bktype}.lastid"
  fi
  $MONGODUMP --host $DBHOST --db "$1" --collection "$2" $USER $PASS --out "$MBD/${1}.${2}.${bktype}.${archname}" 1>>"$stdinto" 2>>"$rpath/logs/mongo.backup.tmp" && echo "mongo: $1 dumped successfully" >>"$rpath/m_backup.log" || echo "mongo: $1 dump failed" >>"$rpath/m_backup.log"
  [ -n "$TAR" ] && (IFS=$IFS1 ; cd "$MBD" ; $TAR "${1}.${2}.${bktype}.${archname}.tar.${ext}" "${1}.${2}.${bktype}.${archname}" 1>>"$stdinto" 2>>"$rpath/logs/mongo.backup.tmp")
  cat "$rpath/logs/mongo.backup.tmp" | grep -v ^connected | grep -v 'Removing leading' >>"$rpath/m_backup.error" && rm -f "$rpath/logs/mongo.backup.tmp"
  rm -rf "$MBD/${1}.${2}.${bktype}.${archname}" 2>>"$rpath/m_backup.error"
}

[ -n $debugflag ] && stdinto="$rpath/m_backup.log" || stdinto=/dev/null

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

[ "X$mongohosts" == "X" ] && echo "Error: database host not defined" >> "$rpath/m_backup.error" && exit 1
[ "X${localbackuppath}" != "X" ] && DEST="${localbackuppath}" || DEST=$rpath

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
  DBHOST=$($MONGO --host $mongohost --quiet --eval "var im = rs.isMaster(); if(im.ismaster && im.hosts) { im.hosts[1] } else { '$mongohost' }" | tail -1) 2>>"$rpath/m_backup.error"
  [ $? -eq 0 ] && break
done
 
echo "Host $DBHOST selected." >>"$rpath/m_backup.log"
if [ "X${2}" == "X" ]; then
  archname="$DBHOST.$(date +"%Y.%m.%d_%H.%M")"
else
  archname="${2}"
fi

if [ -n "$mongodbpertableconf" ] ; then
  [ -n "$debugflag" ] && echo "Per table backup configuration enabled" >> "$rpath/m_backup.log"
  [ ! -f "$mongodbpertableconf" ] && mongodbpertableconf="$M_ROOT/$mongodbpertableconf"
  [ ! -f "$mongodbpertableconf" ] && echo "Per table configuration file not found" >> "$rpath/m_backup.error" && exit 1
  IFS1=$IFS
  IFS='
'
  for table in `cat "$mongodbpertableconf" | grep -v ^$ | grep -v  ^#|grep -v ^[[:space:]]*#` ; do
    db=`echo $table | cut -d'|' -f1`
    coll=`echo $table | cut -d'|' -f2`
    bktype=`echo $table | cut -d'|' -f3`
    idfield=`echo $table | cut -d'|' -f4`
    [ -z "$db" ] && continue
    [ -z "$coll" ] && continue
    [ -z "$bktype" ] && bktype=full
    [ -z "$idfield" ] && idfield="_id"
    [ -n "$debugflag" ] && echo -e "\n>>> Database $db table $coll type $bktype\n" >> "$rpath/m_backup.log"
    case $bktype in
      full)
        full_coll_backup "$db" "$coll" "$idfield"
        ;;
      periodic)
        [ -n "$debugflag" ] && log "db: $db table: $coll per-table periodic backup"
        [ -d "$rpath/var/mongodb" ] || install -d "$rpath/var/mongodb"
        if [ -f "$rpath/var/mongodb/${db}.${coll}.${bktype}.lastid" ] ; then
          lastid=`cat "$rpath/var/mongodb/${db}.${coll}.${bktype}.lastid"`
        elif [ -f "$rpath/var/mongodb/${db}.${coll}.full.lastid" ] ; then
          lastid=`cat "$rpath/var/mongodb/${db}.${coll}.full.lastid"`
        else
          lastid=0
        fi
        [ -n "$debugflag" ] && log "last backuped ID: $lastid"
        if [ "$lastid" == "0" ]; then
          [ -n "$debugflag" ] && log "forcing full backup"
          bktype=full
          full_coll_backup "$db" "$coll" "$idfield"
        else
          [ -n "$debugflag" ] && log "running periodic backup"
          bkname="`echo "$lastid" | tr '|():' '_' | tr -d '"{}[]$ '`"
          QUERY="{ $idfield : { \$gt : $lastid }}"
          [ -n "$debugflag" ] && log "$QUERY"
          $MONGODUMP --host $DBHOST --db "$db" --collection "$coll" --query "$QUERY" $USER $PASS --out "$MBD/${db}.${coll}.${bktype}.${bkname}.${archname}" 1>>"$stdinto" 2>>"$rpath/logs/mongo.backup.tmp" && echo "mongo: $db dumped successfully" >>"$rpath/m_backup.log" || echo "mongo: $db dump failed" >>"$rpath/m_backup.log"
          [ -n "$debugflag" ] && log "archiving"
          [ -n "$TAR" ] && (IFS=$IFS1 ; cd "$MBD" ; $TAR "${db}.${coll}.${bktype}.${bkname}.${archname}.tar.${ext}" "${db}.${coll}.${bktype}.${bkname}.${archname}" 1>>"$stdinto" 2>>"$rpath/logs/mongo.backup.tmp")
          cat "$rpath/logs/mongo.backup.tmp" | grep -v ^connected | grep -v 'Removing leading' >>"$rpath/m_backup.error" && rm -f "$rpath/logs/mongo.backup.tmp"
          rm -rf "$MBD/${db}.${coll}.${bktype}.${bkname}.${archname}" 2>>"$rpath/m_backup.error"
        fi
        ;;
      *)
        echo "Don't know how to do $bktype backup" >> "$rpath/m_backup.error"
        ;;
    esac
  done
  IFS=$IFS1
else
  [ -n "$debugflag" ] && echo "Per table backup configuration disabled" >> "$rpath/m_backup.error"
  if [ "X$mongodblist" == "X" ]; then
    mongodblist="$($MONGO $DBHOST/admin --eval "db.runCommand( { listDatabases : 1 } ).databases.forEach ( function(d) { print( '=' + d.name ) } )" | grep ^= | sed 's|^=||g')" 2>>"$rpath/m_backup.error"
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
      if $compress_onthefly ; then
### Works if version >= 1.7, avoids intermediate space usage by uncompressed dumps
### Note that it doesn't dump indexes
        install -d "$MBD/${db}.${archname}"
        if [ -n "$compress" ] ; then
          for collection in `$MONGO $DBHOST/$db --quiet --eval "db.getCollectionNames()" | tail -1 | sed 's|,| |g'` ; do
            $MONGODUMP $USER $PASS --host $DBHOST --db $db --collection $collection --out - | $compress > "$MBD/${db}.${archname}/${collection}.bson.${ext}" 2>>"$rpath/m_backup.error"
          done
        fi
    # --------------------
    # 
      else
        $MONGODUMP --host $DBHOST --db $db $USER $PASS --out "$MBD/${db}.${archname}" 1>>"$stdinto" 2>"$rpath/logs/mongo.backup.tmp" && echo "mongo: $db dumped successfully" >>"$rpath/m_backup.log" || echo "mongo: $db dump failed" >>"$rpath/m_backup.log"
        [ -n "$TAR" ] && pushd "$MBD" && $TAR "${db}.${archname}.tar.${ext}" "${db}.${archname}" 1>>"$stdinto" 2>>"$rpath/logs/mongo.backup.tmp"
        popd
        cat "$rpath/logs/mongo.backup.tmp" | grep -v ^connected | grep -v 'Removing leading' >>"$rpath/m_backup.error" && rm -f "$rpath/logs/mongo.backup.tmp"
        rm -rf "$MBD/${db}.${archname}" 2>>"$rpath/m_backup.error"
      fi
    fi
  done
fi

