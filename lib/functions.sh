#!/bin/bash
# Copyright (C) 2008-2012 Igor Simonov (me@igorsimonov.com)
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

fpath=$(readlink -f "$BASH_SOURCE")
fpath=${fpath%/*}
#*/
source "$fpath/../conf/mon.conf"
SQL=`which sqlite3 2>/dev/null`

store_results() {
  [ -z "$1" ] && echo "Fields are not defined" && exit 1
  [ -n "$SQLITE3" -a "$SQLITE3" == "1" ] || exit 0
  if [ -z "$2" ]; then
    caller=$(readlink -f "$0")
    callername=${caller##*/}
    callerfolder=${caller%/*}
    callerparent=${callerfolder%/*}
echo "if [ -n \"$callerparent\" -a \"${callerparent##*/}\" == \"standalone\" ]"
echo "elif [ -n \"$callerfolder\" -a \"${callerfolder##*/}\" == \"tests\" ]"
    if [ -n "$callerparent" -a "${callerparent##*/}" == "standalone" ]; then
      dbfile="$callerfolder/${callername%.mon}.db"
    elif [ -n "$callerfolder" -a "${callerfolder##*/}" == "tests" ]; then
      dbfile="$callerfolder/../sysdata"
    else
      echo "Non-standard file location, unable to determine where the database is"
      exit 1
    fi
    dbtable="${callername%.mon}"
  else
    dbfile="${2%%|*}"
    dbtable="${2##*|}"
  fi
  timeindex=`date +"%s"`
  day=`date +"%Y%m%d"`
  [ -z "$dbtable" ] && echo "Unable to find out what table to store the data into" && exit 1
  [ -z "$dbfile" ] && echo "Database file definition is NULL" && exit 1
  values="$(IFS=','; for f in $1; do f=${f%:*}; eval "echo \$${f},"; done)"
  values="${values%,}"
  if [ ! -f "$dbfile" ]; then
    fields="`echo "$1" | tr ':' ' '`"
    $SQL "$dbfile" "CREATE TABLE $dbtable (timeindex integer, day varchar(8), $fields)"
  fi
  fields="$(IFS=','; for f in $1; do f=${f%:*}; echo "${f},"; done)"
  fields="${fields%,}"
#echo "$SQL \"$dbfile\" \"INSERT INTO $dbtable (timeindex, day, $fields) values ($timeindex, '$day', $values)\""
  $SQL "$dbfile" "INSERT INTO $dbtable (timeindex, day, $fields) values ($timeindex, '$day', $values)"

}

function gendash() {
  indic="ok"
  [ -n "`grep '<\*>' "$1"`" ] && indic="w1"
  [ -n "`grep '<\*\*>' "$1"`" ] && indic="w2"
  [ -n "`grep '<\*\*\*>' "$1"`" ] && indic="w3"
  case $DASHBOARD in
    HTML)
      "${fpath}/genhtml" --type=dash --css=${indic}${3} --folder="$2/localhost" "$1" 2>>"${fpath}/../dashboard.log"
      ;;
    JSON)
      "${fpath}/genjson" --type=dash --css=${indic}${3} --folder="$2/localhost" "$1" 2>>"${fpath}/../dashboard.log"
      ;;
  esac
}

function genreport() {
  case $DASHBOARD in
    HTML)
      "${fpath}/genhtml" --type=report "$1" 2>>"${fpath}/../dashboard.log"
      ;;
    JSON)
      "${fpath}/genjson" --type=report "$1" 2>>"${fpath}/../dashboard.log"
      ;;
  esac
}

print_report_title() {
  echo -e "`date`\n------------------------------\n" > "$1"
}

