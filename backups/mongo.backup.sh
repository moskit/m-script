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

[ -z "$M_ROOT" ] && M_ROOT="$rpath"

if [ -z "$1" ]; then
  echo "Error: configuration file is not defined for $0" >> "$M_ROOT/m_backup.error"
  exit 1
else
  source "$1"
fi

MONGO=`which mongo 2>/dev/null`
MONGODUMP=`which mongodump 2>/dev/null`
GZIP=`which gzip 2>/dev/null`
BZIP2=`which bzip2 2>/dev/null`
TAR="`which tar 2>/dev/null`"
LOG="$M_ROOT/m_backup.log"

[ -z "$MONGO" ] && echo "Mongo client (mongo) not found, exiting." && exit 1
[ -z "$MONGODUMP" ] && echo "Mongo dump utility (mongodump) not found, exiting." && exit 1

log() {
  echo "`date +"%m.%d %H:%M:%S"` ${0##*/}: ${@}">>$LOG
}

full_coll_backup() {
  # storing the latest ID before dumping for the ID-based incremental backups
  # (updates of existing records are not backuped! for specific non-updateable
  # collections only!)
  # Use --objcheck while restoring such backups if you care about duplicates.
  if [ "$3" == "_id" ]; then
    $MONGO "$DBHOST/$1" --quiet --eval "db.$2.find({},{$3:1}).sort({$3:-1}).limit(1).forEach(printjson)" 2>/dev/null | "$M_ROOT"/lib/json2txt | cut -d'|' -f2 > "$M_ROOT/var/mongodb/${1}.${2}.${bktype}.lastid"
  else
    $MONGO "$DBHOST/$1" --quiet --eval "db.$2.find({},{$3:1,_id:0}).sort({$3:-1}).limit(1).forEach(printjson)" 2>/dev/null | "$M_ROOT"/lib/json2txt | cut -d'|' -f2 > "$M_ROOT/var/mongodb/${1}.${2}.${bktype}.lastid"
  fi
  $MONGODUMP --host $DBHOST --db "$1" --collection "$2" $USER $PASS --out "$MBD/${1}.${2}.${bktype}.${archname}" 1>>"$stdinto" 2>>"$M_ROOT/logs/mongo.backup.tmp" && echo "mongo: $1 dumped successfully" >>"$M_ROOT/m_backup.log" || echo "mongo: $1 dump failed" >>"$M_ROOT/m_backup.log"
  [ -n "$TAR" ] && (IFS=$IFS1 ; cd "$MBD" ; $TAR "${1}.${2}.${bktype}.${archname}.tar.${ext}" "${1}.${2}.${bktype}.${archname}" 1>>"$stdinto" 2>>"$M_ROOT/logs/mongo.backup.tmp")
  cat "$M_ROOT/logs/mongo.backup.tmp" | grep -v ^connected | grep -v 'Removing leading' >>"$M_ROOT/m_backup.error" && rm -f "$M_ROOT/logs/mongo.backup.tmp"
  rm -rf "$MBD/${1}.${2}.${bktype}.${archname}" 2>>"$M_ROOT/m_backup.error"
}

[ -n $debugflag ] && stdinto="$M_ROOT/m_backup.log" || stdinto=/dev/null

if [ "_$compression" == "_gzip" ] && [ -n "$GZIP" ] ; then
  compress=$GZIP
  ext="gz"
  TAR="$TAR czf"
fi

if [ "_$compression" == "_bzip2" ] && [ -n "$BZIP2" ] ; then
  compress=$BZIP2
  ext="bz2"
  TAR="$TAR cjf"
fi

[ -z "$compression" ] && TAR="$TAR cf"

[ -z "$mongohosts" ] && echo "Error: database host not defined" >> "$M_ROOT/m_backup.error" && exit 1
[ -n "$localbackuppath" ] && DEST="$localbackuppath" || DEST=$M_ROOT

MBD="$DEST/backup.tmp/mongo"

[ ! -d $MBD ] && install -d $MBD
if [ -z "$mongopass" ]; then
  PASS=""
else
  PASS="--password=$mongopass"
fi

if [ -z "$mongouser" ]; then
  USER=""
else
  USER="--username=$mongouser"
fi

for mongohost in $mongohosts ; do
  DBHOST=$($MONGO --host $mongohost --quiet --eval "var im = rs.isMaster(); if(im.ismaster && im.hosts) { im.hosts[1] } else { '$mongohost' }" | tail -1) 2>>"$M_ROOT/m_backup.error"
  res=$?
  [ $res -eq 0 ] && break
done

[ $res -ne 0 ] && echo -e "\n*** unable to find a MongoDB host, exiting\n" >> "$M_ROOT/m_backup.error" && exit 1
 
echo "Host $DBHOST selected." >>"$M_ROOT/m_backup.log"
if [ -z "${2}" ]; then
  archname="$DBHOST.$(date +"%Y.%m.%d_%H.%M")"
else
  archname="${2}"
fi

if [ -n "$mongodbpertableconf" ] ; then
  [ -d "$M_ROOT/var/mongodb" ] || install -d "$M_ROOT/var/mongodb"
  [ -n "$debugflag" ] && echo "Per table backup configuration enabled" >> "$M_ROOT/m_backup.log"
  [ ! -f "$mongodbpertableconf" ] && mongodbpertableconf="$M_ROOT/$mongodbpertableconf"
  [ ! -f "$mongodbpertableconf" ] && mongodbpertableconf="$M_ROOT/conf/$mongodbpertableconf"
  [ ! -f "$mongodbpertableconf" ] && echo "Per table configuration file not found" >> "$M_ROOT/m_backup.error" && exit 1
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
    [ -n "$debugflag" ] && echo -e "\n>>> Database $db table $coll type $bktype\n" >> "$M_ROOT/m_backup.log"
    case $bktype in
      full)
        full_coll_backup "$db" "$coll" "$idfield"
        ;;
      periodic)
        # ID-based incremental 
        [ -n "$debugflag" ] && log "db: $db table: $coll per-table periodic backup"
        [ -d "$M_ROOT/var/mongodb" ] || install -d "$M_ROOT/var/mongodb"
        if [ -f "$M_ROOT/var/mongodb/${db}.${coll}.${bktype}.lastid" ] ; then
          lastid=`cat "$M_ROOT/var/mongodb/${db}.${coll}.${bktype}.lastid"`
        elif [ -f "$M_ROOT/var/mongodb/${db}.${coll}.full.lastid" ] ; then
          lastid=`cat "$M_ROOT/var/mongodb/${db}.${coll}.full.lastid"`
        else
          lastid=0
        fi
        lastid=${lastid#*(}
        lastid=${lastid%)*}
        lastid=`echo "$lastid" | sed 's|"|\\"|g'`
        [ -n "$debugflag" ] && log "last backuped ID: $lastid"
        if [ "$lastid" == "0" ]; then
          [ -n "$debugflag" ] && log "forcing full backup"
          bktype=full
          full_coll_backup "$db" "$coll" "$idfield"
        else
          [ -n "$debugflag" ] && log "running periodic backup"
          bkname="`echo "$lastid" | tr '|():' '_' | tr -d '"{}[]$ '`"
          QUERY="{ $idfield : { \\$gt : $lastid }}"
          [ -n "$debugflag" ] && log "$QUERY"
          $MONGODUMP --host $DBHOST --db "$db" --collection "$coll" --query "$QUERY" $USER $PASS --out "$MBD/${db}.${coll}.${bktype}.${bkname}.${archname}" 1>>"$stdinto" 2>>"$M_ROOT/logs/mongo.backup.tmp"
          if [ $? -eq 0 ]; then
            if [ "$idfield" == "_id" ]; then
              $MONGO "$DBHOST/$db" --quiet --eval "db.$coll.find({},{$idfield:1}).sort({$idfield:-1}).limit(1).forEach(printjson)" 2>/dev/null | "$M_ROOT"/lib/json2txt | cut -d'|' -f2 > "$M_ROOT/var/mongodb/${db}.${coll}.${bktype}.lastid"
            else
              $MONGO "$DBHOST/$db" --quiet --eval "db.$coll.find({},{$idfield:1,_id:0}).sort({$idfield:-1}).limit(1).forEach(printjson)" 2>/dev/null | "$M_ROOT"/lib/json2txt | cut -d'|' -f2 > "$M_ROOT/var/mongodb/${db}.${coll}.${bktype}.lastid"
            fi
            echo "mongo: $db dumped successfully" >>"$M_ROOT/m_backup.log"
          else
            echo "mongo: $db dump failed" >>"$M_ROOT/m_backup.log"
          fi
          [ -n "$debugflag" ] && log "archiving"
          [ -n "$TAR" ] && (IFS=$IFS1 ; cd "$MBD" ; $TAR "${db}.${coll}.${bktype}.${bkname}.${archname}.tar.${ext}" "${db}.${coll}.${bktype}.${bkname}.${archname}" 1>>"$stdinto" 2>>"$M_ROOT/logs/mongo.backup.tmp")
          cat "$M_ROOT/logs/mongo.backup.tmp" | grep -v ^connected | grep -v 'Removing leading' >>"$M_ROOT/m_backup.error" && rm -f "$M_ROOT/logs/mongo.backup.tmp"
          rm -rf "$MBD/${db}.${coll}.${bktype}.${bkname}.${archname}" 2>>"$M_ROOT/m_backup.error"
        fi
        ;;
      *)
        echo "Don't know how to do $bktype backup" >> "$M_ROOT/m_backup.error"
        ;;
    esac
  done
  IFS=$IFS1
else
  [ -n "$debugflag" ] && echo "Per table backup configuration disabled" >> "$M_ROOT/m_backup.error"
  if [ -z "$mongodblist" ]; then
    mongodblist="$($MONGO $DBHOST/admin $USER $PASS --eval "db.runCommand( { listDatabases : 1 } ).databases.forEach ( function(d) { print( '=' + d.name ) } )" | grep ^= | sed 's|^=||g')" 2>>"$M_ROOT/m_backup.error"
  fi

  for db in `echo "$mongodblist" | tr ',' ' '`; do
    skipdb=-1
    if [ -n "$mongodbexclude" ]; then
    	for i in $mongodbexclude ; do
    	  [ "$db" == "$i" ] && skipdb=1 || :
    	done
    fi
    
    if [ "$skipdb" == "-1" ]; then
      if $compress_onthefly ; then
### Works if version >= 1.7, avoids intermediate space usage by uncompressed dumps
### Note that it doesn't dump metadata
        install -d "$MBD/${db}.${archname}"
        if [ -n "$compress" ] ; then
          for collection in `$MONGO $DBHOST/$db $USER $PASS --quiet --eval "db.getCollectionNames()" | tail -1 | sed 's|,| |g'` ; do
            ($MONGODUMP $USER $PASS --host $DBHOST --db $db --collection $collection --out - 2>"$M_ROOT/logs/mongo.backup.tmp" && echo "mongo: ${db}.${collection} dumped successfully" >>"$M_ROOT/m_backup.log" || echo "mongo: ${db}.${collection} dump failed" >>"$M_ROOT/m_backup.log") | $compress > "$MBD/${db}.${archname}/${collection}.bson.${ext}" 2>>"$M_ROOT/m_backup.error"
          done
        fi
    # --------------------
    # 
      else
        $MONGODUMP --host $DBHOST --db $db $USER $PASS --out "$MBD/${db}.${archname}" 1>>"$stdinto" 2>"$M_ROOT/logs/mongo.backup.tmp" && echo "mongo: $db dumped successfully" >>"$M_ROOT/m_backup.log" || echo "mongo: $db dump failed" >>"$M_ROOT/m_backup.log"
        [ -n "$TAR" ] && pushd "$MBD" && $TAR "${db}.${archname}.tar.${ext}" "${db}.${archname}" 1>>"$stdinto" 2>>"$M_ROOT/logs/mongo.backup.tmp"
        [ -n "$TAR" ] && popd
        cat "$M_ROOT/logs/mongo.backup.tmp" | grep -v ^connected | grep -v 'Removing leading' >>"$M_ROOT/m_backup.error" && rm -f "$M_ROOT/logs/mongo.backup.tmp"
        rm -rf "$MBD/${db}.${archname}" 2>>"$M_ROOT/m_backup.error"
      fi
    fi
  done
fi

