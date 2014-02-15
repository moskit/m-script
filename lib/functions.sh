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
[ -z "$M_ROOT" ] && M_ROOT=$(readlink -f "$fpath/../")
source "$M_ROOT/conf/mon.conf"
SQLBIN=`which sqlite3 2>/dev/null || echo echo`
[ -z "$M_TEMP" ] && log "M_TEMP is not defined" && echo "M_TEMP is not defined" >&2 && exit 1

store_results() {
  # syntax:
  # store_results fieldname1|datatype1,fieldname2|datatype2,... <filename|tablename>
  [ -z "$1" ] && echo "store_results: fields are not defined" && exit 1
  [ -n "$SQLITE3" -a "$SQLITE3" == "1" ] || exit 0
  if [ -z "$2" ]; then
    caller=$(readlink -f "$0")
    callername=${caller##*/}
    callerfolder=${caller%/*}
    callerparent=${callerfolder%/*}
    if [ -n "$callerparent" -a "${callerparent##*/}" == "standalone" ]; then
      dbfile="$callerfolder/${callername%.mon}.db"
    elif [ -n "$callerfolder" -a "${callerfolder##*/}" == "tests" ]; then
      dbfile="$callerfolder/../sysdata"
    else
      log "Non-standard file location, unable to determine where the database is, caller parent folder is ${callerparent##*/}, caller folder is ${callerfolder##*/}"
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
  values="$(IFS=','; for f in $1; do f=${f%%|*}; eval "echo -n \'\$${f}\',"; done)"
  values="${values%,}"
  fields="$(IFS=','; for f in $1; do echo -n "${f%%|*},"; done)"
  fields="${fields%,}"
  if [ ! -f "$dbfile" ] || [ -f "$dbfile" -a -z "`$SQLBIN "$dbfile" ".schema $dbtable"`" ]; then
    cfields="$(IFS=','; for f in $1; do echo -n "${f%%|*} `echo "${f}" | cut -d'|' -f2`,"; done)"
    cfields="${cfields%,}"
    $SQLBIN -echo "$dbfile" "CREATE TABLE $dbtable (timeindex integer, day varchar(8), $cfields)" >>$M_ROOT/monitoring.log 2>&1
  fi
  dbquery "$dbfile" "INSERT INTO $dbtable (timeindex, day, $fields) values ($timeindex, '$day', $values)"
  unset `echo $fields | tr ',' ' '`
}

check_results() {
  # syntax:
  # check_results var1<|description|datatype1>,var2<|description|datatype2>,...
  # where datatype can be real (default, slower but more universal) or integer
  # if description is omitted, variable name will be used in report
  [ -z "$1" ] && return 1
  caller=$(readlink -f "$0")
  callername=${caller##*/}
  callerconf="${caller%.mon}.conf"
  [ "$callerconf" == "$caller" ] && log "Monitor script must have extension .mon" && return 1
  source "$callerconf"
  IFSORIG=$IFS
  IFS=','
  for var2ck in $1 ; do
    varname=`echo "$var2ck" | cut -d'|' -f1`
    vardescr=`echo "$var2ck" | cut -s -d'|' -f2`
    vartype=`echo "$var2ck" | cut -s -d'|' -f3`
    [ -z "$vardescr" ] && vardescr=$varname
    [ "$varname" == "$vartype" ] && vartype=real
    thr1=`eval "echo \\$${varname}_1"`
    thr2=`eval "echo \\$${varname}_2"`
    thr3=`eval "echo \\$${varname}_3"`
    val=`eval "echo \\$${varname}"`
    if [ "$vartype" == "real" ]; then
      [ `echo "scale=2; $val >= $thr3" | bc` -eq 1 ] && echo "<***> $vardescr is $val" && continue
      [ `echo "scale=2; $val >= $thr2" | bc` -eq 1 ] && echo "<**>  $vardescr is $val" && continue
      [ `echo "scale=2; $val >= $thr1" | bc` -eq 1 ] && echo "<*>   $vardescr is $val" && continue
    fi
    if [ "$vartype" == "real4" ]; then
      [ `echo "scale=4; $val >= $thr3" | bc` -eq 1 ] && echo "<***> $vardescr is $val" && continue
      [ `echo "scale=4; $val >= $thr2" | bc` -eq 1 ] && echo "<**>  $vardescr is $val" && continue
      [ `echo "scale=4; $val >= $thr1" | bc` -eq 1 ] && echo "<*>   $vardescr is $val" && continue
    fi
    if [ "$vartype" == "integer" ]; then
      [ `expr $val \>= $thr3` -eq 1 ] && echo "<***> $vardescr is $val" && continue
      [ `expr $val \>= $thr2` -eq 1 ] && echo "<**>  $vardescr is $val" && continue
      [ `expr $val \>= $thr1` -eq 1 ] && echo "<*>   $vardescr is $val" && continue
    fi
    echo "<OK>  $vardescr is $val"
  done
  IFS=$IFSORIG
}
    
gendash() {
  if [ -e "$1" ]; then
    indic="ok"
    [ -n "`grep '<\*>' "$1"`" ] && indic="w1"
    [ -n "`grep '<\*\*>' "$1"`" ] && indic="w2"
    [ -n "`grep '<\*\*\*>' "$1"`" ] && indic="w3"
  else
    indic="empty"
  fi
  case $DASHBOARD in
    HTML)
      "$fpath/genhtml" --type=dash --css=${indic}${3} --folder="$2/localhost" "$1" 2>>"$M_ROOT/logs/dashboard.log"
      ;;
    JSON)
      "$fpath/genjson" --type=dash --css=${indic}${3} --folder="$2/localhost" "$1" 2>>"$M_ROOT/logs/dashboard.log"
      ;;
  esac
}

genreport() {
  case $DASHBOARD in
    HTML)
      "$fpath/genhtml" --type=report --css=${indic}${3} --folder="$2/localhost" "$1" 2>>"$M_ROOT/logs/dashboard.log"
      ;;
    JSON)
      "$fpath/genjson" --type=report --css=${indic}${3} --folder="$2/localhost" "$1" 2>>"$M_ROOT/logs/dashboard.log"
      ;;
  esac
}

print_report_title() {
  echo -e "`date`\n------------------------------\n" > "$1"
}

log() {
  [ -n "$LOG" ] && echo "`date +"%m.%d %H:%M:%S"` ($$) ${0##*/}: ${@}">>$LOG
}

find_delta() {
  if [ -f "$M_TEMP/${0##*/}.delta" ]; then
    arrprev=( `cat "$M_TEMP/${0##*/}.delta" | cut -d'|' -f2` )
  fi
  arrnames=( $(IFS=','; for f in $1; do echo -n "${f%%:*} "; done) )
  echo "$(IFS=','; for f in $1; do echo "${f}|`eval "echo \\$${f%%:*}"`"; done)" > "$M_TEMP/${0##*/}.delta"
  arrcurr=( $(IFS=','; for f in $1; do echo "`eval "echo \\$${f%%:*}"`:${f#*:} "; done) )
  [ ${#arrcurr[*]} -ne ${#arrprev[*]} ] && return
  for ((i=0; i<${#arrcurr[*]}; i++)); do
    if [ "X${arrcurr[$i]#*:}" == "Xinteger" ]; then
      arrval+=( `expr ${arrcurr[$i]%%:*} - ${arrprev[$i]} 2>/dev/null || echo 0` )
    else
      # TODO: bc silently defaults non-numeric arguments to 0
      arrval+=( `echo "scale=2; ${arrcurr[$i]%%:*} - ${arrprev[$i]}" | bc 2>/dev/null || echo 0` )
    fi
  done

  for ((i=0; i<${#arrcurr[*]}; i++)); do
    eval "${arrnames[$i]}=${arrval[$i]}"
  done
  unset arrprev arrnames arrcurr arrval
}

block_alert() {
  # block_alert <monitor.mon> <cycles>
  echo $2 > "$M_ROOT/${1}.lock"
}

unblock_alert() {
  rm "$M_ROOT/${1}.lock" 2>/dev/null
  return 0
}

alert_blocked() {
  if [ -f "$M_ROOT/${1}.lock" ] ; then
    cyclesleft=`cat "$M_ROOT/${1}.lock"`
    if [ "X$cyclesleft" == "X0" ]; then
      unblock_alert && return 1
    else
      cyclesleft=`expr $cyclesleft - 1 || echo 0`
      echo $cyclesleft > "$M_ROOT/${1}.lock"
      return 0
    fi
  else
    return 1
  fi
}

block_action() {
  [ -n "$1" ] && [ `expr "$1" : ".*[^0-9]"` -ne 0 ] && return 1
  period=$1
  shift
  echo "${@}|$period" >> "$M_TEMP/actions.blocked" && log "action ${@} blocked for $period cycles" || log "error blocking action ${@} for $period cycles"
}

unblock_action() {
  ptrn=`echo "$@" | sed 's|/|\\\/|g;s| |\\\ |g'`
  sed -i "/^${ptrn}|/d" "$M_TEMP/actions.blocked" && log "action ${@} unblocked" || log "error unblocking action ${@}"
}

action_blocked() {
  if [ -f "$M_TEMP/actions.blocked" ] ; then
    cyclesleft=`grep "^${@}|" "$M_TEMP/actions.blocked" | cut -d'|' -f2`
    [ -z "$cyclesleft" ] && return 1
    if [ `echo "$cyclesleft" | wc -l` -gt 1 ];then
      cyclesleft=`echo "$cyclesleft" | sort -n | tail -1`
    fi
    if [ "X$cyclesleft" == "X0" ]; then
      unblock_action "$@" && log "unblocking action ${@} due to 0 cycles left" && return 1 || log "error unblocking action ${@} which had 0 cycles left"
    else
      cyclesleft=`expr $cyclesleft - 1 2>/dev/null` || cyclesleft=0
      unblock_action "$@"
      if [ $cyclesleft -gt 0 ] 2>>"$LOG"; then
        block_action $cyclesleft "$@"
      else
        return 1
      fi
      return 0
    fi
  else
    return 1
  fi
}

dbquery() {
  local dbfile
  local dbquery
  dbfile="$1"
  shift
  dbquery="$@"
  [ -z "$LOG" ] && LOG="$M_ROOT/monitoring.log"
  $SQLBIN "$dbfile" "$dbquery" 2>>"$LOG"
  qres=$?
  [ $qres -eq 0 ] && return 0
  if [ $qres -eq 5 -o $qres -eq 6 ]; then
    for ((i=0; i<10; i++)); do
      sleep 5
      $SQLBIN "$dbfile" "$dbquery" >> $LOG 2>&1
      if [ $? -ne 5 -a $? -ne 6 ]; then
        log "query to database $dbfile repeated after `expr $i \* 5` sec and finished successfully"
        return 0
      fi
    done
  fi
  log "query \"$dbquery\" to database $dbfile failed"
  return 1
}

solve() {
local sc=$1
shift
bc << EOF
scale=${sc};
define b (x) {
  if (x < 1 && x > 0) {
    print "0";
  }
  return x;
}
print b($@);
print "\n";
EOF
}

check_interval() {
  local interval="$*"
  [ -z "$rpath" ] && rpath="$M_TEMP"
  interval=`date -d "1970/01/01 +$interval" +"%s"`
  [ $interval -eq 0 ] && return 1
  local currinterval=`cat "$rpath/interval.tmp" 2>/dev/null || echo 0`
  timeshift=`cat "$M_TEMP/timeshift" || echo 0`
  currinterval=`expr $currinterval + $FREQ + $timeshift`
  if [ $currinterval -ge $interval ]; then
    echo 0 > "$rpath/interval.tmp"
    return 0
  else
    echo $currinterval > "$rpath/interval.tmp"
    return 1
  fi
}

date_header() {
  echo -e "`date`\n------------------------------\n"
}

get_lock() {
  # removing stale lock file
  [ -z "$LOG" ] && LOG="$M_ROOT/monitoring.log"
  [ -n "$MAXLOCK" ] || MAXLOCK=60
  lockfile=`find "$rpath" -maxdepth 1 -name "${rcommand}.lock" -mmin +$MAXLOCK`
  if [ -n "$lockfile" ] ; then
    log "*** Lock file is older than $MAXLOCK minutes, removing"
    rm -f "$lockfile"
  fi
  sleep $((RANDOM%5))
  for ((i=1; i<=10; i++))
  do
    if [ -e "$rpath/${rcommand}.lock" ] ; then
      sleep $((RANDOM%10))
      continue
    else
      log "lock acquired"
      break
    fi
  done
  if [ -f "$rpath/${rcommand}.lock" ] ; then
    log "giving up acquiring the lock..."
    exit 1
  fi

  touch "$rpath/${rcommand}.lock"
}


