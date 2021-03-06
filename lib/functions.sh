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
caller=$(readlink -f "$0")
callername=${caller%.mon}
callername=${callername##*/}
callerfolder=${caller%/*}
callerparent=${callerfolder%/*}
timeshift=`cat "$M_TEMP/timeshift" 2>/dev/null` || timeshift=10

store_results() {
  # syntax:
  # store_results fieldname1|datatype1<,fieldname2|datatype2,>... <filename|tablename>
  [ -z "$1" ] && echo "store_results: fields are not defined" && exit 1
  [ -n "$SQLITE3" -a "$SQLITE3" == "1" ] || exit 0
  if [ -z "$2" ]; then
    if [ -n "$callerparent" -a "${callerparent##*/}" == "standalone" ]; then
      dbfile="$callerfolder/${callername}.db"
    elif [ -n "$callerfolder" -a "${callerfolder##*/}" == "tests" ]; then
      dbfile="$callerfolder/../sysdata"
    else
      log "Non-standard file location, unable to determine where the database is, caller parent folder is ${callerparent##*/}, caller folder is ${callerfolder##*/}"
      exit 1
    fi
    dbtable="$callername"
  else
    dbfile="${2%%|*}"
    dbtable="${2##*|}"
    [ `echo "$dbfile" | cut -b1` == "/" ] || dbfile="$M_ROOT/$dbfile"
  fi
  dbtable=`echo "$dbtable" | tr '.' '_' | tr '-' '_'`
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
}

check_results() {
  # syntax:
  # check_results "var1<|description|datatype1|ao>,var2<|description|datatype2>,.."
  # where datatype can be real (default, slower but more universal) or integer
  # if description is omitted, variable name will be used in report
  # Do not use commas in description! They are used as separators.
  # The 4th field, if present, indicates that only alerts will be reported.
  [ -z "$1" ] && return 1
  callerconf="${caller%.mon}.conf"
  [ "$callerconf" == "${caller}.conf" ] && log "Monitor script must have extension .mon" && return 1
  [ -e "$callerconf" ] && source "$callerconf"
  IFSORIG=$IFS
  IFS=','
  for var2ck in $1 ; do
    varname=`echo "$var2ck" | cut -s -d'|' -f1`
    thr1=`eval "echo \"\\$${varname}_1\""`
    thr2=`eval "echo \"\\$${varname}_2\""`
    thr3=`eval "echo \"\\$${varname}_3\""`
    val=`eval "echo \"\\$${varname}\""`
    vardescr=`echo "$var2ck" | cut -s -d'|' -f2`
    [ -z "$thr1" ] && echo "      ${vardescr}:  $val" && continue
    vartype=`echo "$var2ck" | cut -s -d'|' -f3`
    [ -n "`echo "$var2ck" | cut -s -d'|' -f4`" ] && ao=true || ao=false
    [ -z "$vardescr" ] && vardescr=$varname
    [ -z "$vartype" ] && vartype=real
    
    case $vartype in
      real)
        if [ `echo "scale=2; $thr3 <= 0" | bc` -eq 1 ]; then
          [ `echo "scale=2; -$val >= $thr3" | bc 2>/dev/null` -eq 1 ] && echo "<***> ${vardescr}:  $val" && continue
          [ `echo "scale=2; -$val >= $thr2" | bc 2>/dev/null` -eq 1 ] && echo "<**>  ${vardescr}:  $val" && continue
          [ `echo "scale=2; -$val >= $thr1" | bc 2>/dev/null` -eq 1 ] && echo "<*>  ${vardescr}:  $val" && continue
        else
          [ `echo "scale=2; $val >= $thr3" | bc 2>/dev/null` -eq 1 ] && echo "<***> ${vardescr}:  $val" && continue
          [ `echo "scale=2; $val >= $thr2" | bc 2>/dev/null` -eq 1 ] && echo "<**>  ${vardescr}:  $val" && continue
          [ `echo "scale=2; $val >= $thr1" | bc 2>/dev/null` -eq 1 ] && echo "<*>  ${vardescr}:  $val" && continue
        fi
        ;;
      real4)
        if [ `echo "scale=4; $thr3 <= 0" | bc` -eq 1 ]; then
          [ `echo "scale=4; -$val >= $thr3" | bc 2>/dev/null` -eq 1 ] && echo "<***> ${vardescr}:  $val" && continue
          [ `echo "scale=4; -$val >= $thr2" | bc 2>/dev/null` -eq 1 ] && echo "<**>  ${vardescr}:  $val" && continue
          [ `echo "scale=4; -$val >= $thr1" | bc 2>/dev/null` -eq 1 ] && echo "<*>  ${vardescr}:  $val" && continue
        else
          [ `echo "scale=4; $val >= $thr3" | bc 2>/dev/null` -eq 1 ] && echo "<***> ${vardescr}:  $val" && continue
          [ `echo "scale=4; $val >= $thr2" | bc 2>/dev/null` -eq 1 ] && echo "<**>  ${vardescr}:  $val" && continue
          [ `echo "scale=4; $val >= $thr1" | bc 2>/dev/null` -eq 1 ] && echo "<*>  ${vardescr}:  $val" && continue
        fi
        ;;
      integer)
        if [ `expr $thr3 \<= 0` -eq 1 ]; then
          [ `expr -$val \>= $thr3 2>/dev/null` -eq 1 ] 2>/dev/null && echo "<***> ${vardescr}:  $val" && continue
          [ `expr -$val \>= $thr2 2>/dev/null` -eq 1 ] 2>/dev/null && echo "<**>  ${vardescr}:  $val" && continue
          [ `expr -$val \>= $thr1 2>/dev/null` -eq 1 ] 2>/dev/null && echo "<*>  ${vardescr}:  $val" && continue
        else
          [ `expr $val \>= $thr3 2>/dev/null` -eq 1 ] 2>/dev/null && echo "<***> ${vardescr}:  $val" && continue
          [ `expr $val \>= $thr2 2>/dev/null` -eq 1 ] 2>/dev/null && echo "<**>  ${vardescr}:  $val" && continue
          [ `expr $val \>= $thr1 2>/dev/null` -eq 1 ] 2>/dev/null && echo "<*>  ${vardescr}:  $val" && continue
        fi
        ;;
    esac
    $ao || echo "<OK>  ${vardescr}:  $val"
  done
  echo
  IFS=$IFSORIG
}
    
gendash() {
  [ -z "$DASHBOARD" ] && return
  local name
  local LOG="$M_ROOT/logs/dashboard.log"
  if [ -n "$1" ]; then
    name="$1"
    shift
    if [ -n "$1" ]; then
      report="$1"
    else
      report="${caller}.report"
    fi
    [ -n "$2" ] && indic2="$2"
  else
    name="$callername"
  fi
  if [ -f "$report" ]; then
    indic="ok"
    [ -n "`grep '<\*>' "$report"`" ] && indic="w1"
    [ -n "`grep '<\*\*>' "$report"`" ] && indic="w2"
    [ -n "`grep '<\*\*\*>' "$report"`" ] && indic="w3"
  else
    indic="empty"
  fi
  log "generating dash from report ${report}, folder $name/localhost, indic=${indic}, indic2=$indic2"
  case $DASHBOARD in
    HTML)
      "$fpath/genhtml" --type=dash --css=${indic}${indic2} --folder="$name/localhost" "$report" 2>>"$M_ROOT/logs/dashboard.log"
      ;;
    JSON)
      "$fpath/genjson" --type=dash --css=${indic}${indic2} --folder="$name/localhost" "$report" 2>>"$M_ROOT/logs/dashboard.log"
      ;;
  esac
}

genreport() {
  [ -z "$DASHBOARD" ] && return
  local name
  if [ -n "$1" ]; then
    name="$1"
    shift
    if [ -n "$1" ]; then
      report="$1"
    else
      report="${caller}.report"
    fi
  else
    name="${callername}"
  fi
  case $DASHBOARD in
    HTML)
      "$fpath/genhtml" --type=report --folder="$name/localhost" "$report" 2>>"$M_ROOT/logs/dashboard.log"
      ;;
    JSON)
      "$fpath/genjson" --type=report --folder="$name/localhost" "$report" 2>>"$M_ROOT/logs/dashboard.log"
      ;;
  esac
}

print_report_title() {
  echo -e "`date`\n------------------------------\n" > "$1"
}

printcol() {
  if [ -n "$1" ] ; then
    l=`expr $col - 1`
    str=`echo "$1" | cut -b 1-$l`
    printf "%-${col}s" $str
  else
    printf "%${col}s"
  fi
}

log() {
  if [ -n "$LOG" ]; then
    echo -e "`date +"%m.%d %H:%M:%S"` ($PPID/$$) ${0##*/}: ${@}">>$LOG
  fi
}

find_delta() {
  # Finds the difference between current monitor results and previous results
  # Supposed to be called only once from a monitor, so should include all vars
  # Usage: find_delta "var1|type,var2|type,..."
  #    or: find_delta "var1,var2,..."   (quotes can be omitted in this case)
  # type can be: 1. integer 2. anything else or empty means floating point
  if [ -f "$M_TEMP/${0##*/}.delta" ]; then
    arrprev=( `cat "$M_TEMP/${0##*/}.delta" | cut -d'|' -f2` )
  fi
  arrnames=( $(IFS=','; for f in $1; do echo -n "${f%%|*} "; done) )
  echo "$(IFS=','; for f in $1; do echo "${f}|`eval "echo \\$${f%%|*}"`"; done)" > "$M_TEMP/${0##*/}.delta"
  arrcurr=( $(IFS=','; for f in $1; do echo "`eval "echo \\$${f%%|*}"`|${f#*|} "; done) )
  [ ${#arrcurr[*]} -ne ${#arrprev[*]} ] && return
  for ((i=0; i<${#arrcurr[*]}; i++)); do
    if [ "_${arrcurr[$i]#*|}" == "_integer" ]; then
      arrval+=( `expr ${arrcurr[$i]%%|*} - ${arrprev[$i]} 2>/dev/null || echo 0` )
    else
      # TODO: bc silently defaults non-numeric arguments to 0
      arrval+=( `echo "scale=2; ${arrcurr[$i]%%|*} - ${arrprev[$i]}" | bc 2>/dev/null || echo 0` )
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
    if [ "_$cyclesleft" == "_0" ]; then
      unblock_alert "$1"
      return 1
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
    if [ "_$cyclesleft" == "_0" ]; then
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
  intervalstring=`echo "$@" | tr -d ' '`
  [ -z "$rpath" ] && rpath="$M_TEMP"
  interval=`date -d "1970/01/01 +$intervalstring" +"%s" 2>/dev/null`
  [ -z "$interval" ] && return 1
  local currinterval=`cat "$rpath/${callername}.interval.tmp" 2>/dev/null || echo 0`
  timeshift=`cat "$M_TEMP/timeshift" || echo 0`
  if [ $currinterval -ge $interval ]; then
    overflow=`expr $currinterval - $interval`
    (expr $FREQ + $timeshift + $overflow || echo 0) > "$rpath/${callername}.interval.tmp"
    return 0
  else
    (expr $currinterval + $FREQ + $timeshift || echo 0) > "$rpath/${callername}.interval.tmp"
    return 1
  fi
}

date_header() {
  echo -e "`date`\n------------------------------\n"
}

get_lock() {
  # removing stale lock file
  [ -z "$LOG" ] && LOG="$M_ROOT/monitoring.log"
  [ -z "$MAXLOCK" ] && MAXLOCK=60
  lockfile=`find "$callerfolder" -maxdepth 1 -name "${callername}.lock" -mmin +$MAXLOCK`
  if [ -n "$lockfile" ] ; then
    log "*** Lock file is older than $MAXLOCK minutes, removing"
    rm -f "$lockfile"
  fi
  sleep $((RANDOM%5))
  for ((i=1; i<=10; i++))
  do
    if [ -e "$callerfolder/${callername}.lock" ] ; then
      sleep $((RANDOM%10))
      continue
    else
      log "lock acquired"
      break
    fi
  done
  if [ -f "$callerfolder/${callername}.lock" ] ; then
    lockedproc=`cat "$callerfolder/${callername}.lock"`
    if [ -d /proc/$lockedproc ]; then
      log "given up acquiring the lock..."
      exit 1
    fi
    log "process that created the lock doesn't exist, allowing $callername to acquire it"
  fi
  echo $$ > "$callerfolder/${callername}.lock"
}

release_lock() {
  rm "$callerfolder/${callername}.lock" && log "lock released" || log "failed to release the lock (did not exist?)"
}

unlock_exit() {
  rm "$callerfolder/${callername}.lock"
  exit $1
}

function get_interval() {
  commline="$0 $*"
  commlinehash=`echo "$commline" | md5sum | cut -b 1,2,3,4,5,6,7,8`
  mv "$M_TEMP/timeindex.$commlinehash" "$M_TEMP/lasttimeindex.$commlinehash" 2>/dev/null
  timeindexnow=`date +"%s"`
  echo $timeindexnow > "$M_TEMP/timeindex.$commlinehash"
  lasttimeindex=`cat "$M_TEMP/lasttimeindex.$commlinehash" 2>/dev/null`
  interval=`expr $timeindexnow - $lasttimeindex 2>/dev/null || echo $FREQ`
  export timeindexnow lasttimeindex interval
}

getprocessname() {
  if [ -d /proc/$1 ] ; then
    pfull=`cat /proc/$1/cmdline | tr '\0' ' '`
    pcomm=`cat /proc/$1/comm || echo $pfull | cut -d' ' -f1`
  else
    pfull="unknown"
    pcomm="unknown"
  fi
}

get_opts() {
  # Usage: get_opts $@
  IFS1=$IFS
  declare -i ppn
  ppn=1
  commfound=false
  subcommfound=false
  short=false
  IFS='-'
  for s_option in "$@"
  do
    found=false
    case $s_option in
    --*=*)
      s_optname=`expr "X$s_option" : 'X[^-]*-*\([^=]*\)'`  
      s_optarg=`expr "X$s_option" : 'X[^=]*=\(.*\)'`
      ;;
    --*)
      s_optname=`expr "X$s_option" : 'X[^-]*-*\([^=]*\)'`    
      s_optarg='yes'
      ;;
    -*)
      s_optname=`echo "$s_option" | tr -d '-'`
      short=true
      s_optarg="yes"
      ;;
    *=*)
      echo "Wrong syntax: long options must start with a double dash"
      exit 1
      ;;
    *)
      if $short ; then
        s_optarg="$s_option"
        short=false
      else
        s_param=$s_option
        unset s_optname s_optarg
        case $ppn in
          1)
            IFS=$IFS1
            for comm in $possible_commands ; do
              if [ "_$s_param" == "_$comm" ]; then
                if $commfound ; then
                  echo "Only one command can be executed!"
                  echo "Commands are: $possible_commands"
                  exit 1
                else
                  found=true
                  commfound=true
                fi
              fi
            done
            if ! $found ; then 
              echo "Unknown command: $s_param"
              exit 1
            fi
            command1=$s_param
            IFS='-'
            ;;
          2)
            IFS=$IFS1
            for subcomm in $possible_subcommands ; do
              [ "_${subcomm%%:*}" == "_$command1" ] && subcommands=${subcomm#*:}
              for sub in `echo $subcommands | tr ',' ' '` ; do
                if [ "_$s_param" == "_$sub" ]; then
                  if $subcommfound ; then
                    echo "Only one subcommand can be executed!"
                    echo "Subcommands for $command1 are: ${subcommands}"
                    exit 1
                  else
                    found=true
                    subcommfound=true
                  fi
                fi
              done
              unset subcommands
            done
            if ! $found ; then 
              param1=$s_param
            else
              command2=$s_param
            fi
            IFS='-'
            ;;
          3)
            if [ -z "$param1" ] ; then
              param1=$s_param
            else
              param2=$s_param
            fi
            ;;
          4)
            if [ -z "$param2" ] ; then
              param2=$s_param
            else
              echo "Wrong number of positional parameters!"
              exit 1
            fi
            ;;
          *)
            echo "Wrong number of positional parameters!"
            exit 1
            ;;
        esac
        shift
        ppn+=1
      fi
      ;;
    esac
    for option in `echo $possible_options | sed 's| |-|g'`; do
      if [ "_$s_optname" == "_$option" ]; then
        if [ -n "$s_optarg" ]; then
          eval "$s_optname=\"$s_optarg\""
        else
          [ -z "$(eval echo \$$option)" ] && eval "$option="
        fi
        found=1
      fi
    done
  done
  IFS=$IFS1
}

colors() {
  # simple colors for output, call this function to assign vars when needed
  CONTR_SEQ='\033['
  UNSET_COLOR="${CONTR_SEQ}0m"
  FG_BLACK='30m'
  FG_RED='31m'
  FG_GREEN='32m'
  FG_YELLOW='33m'
  FG_BLUE='34m'
  FG_MAGENTA='35m'
  FG_CYAN='36m'
  FG_WHITE='37m'
  BG_BLACK='40m'
  BG_RED='41m'
  BG_GREEN='42m'
  BG_YELLOW='43m'
  BG_BLUE='44m'
  BG_MAGENTA='45m'
  BG_CYAN='46m'
  BG_WHITE='47m'
  ATTR_NONE='00;'
  ATTR_BOLD='01;'
  ATTR_UNDERSCORE='04;'
  ATTR_BLINK='05;'
  ATTR_REVERSE='07;'
  ATTR_CONCEALED='08;'
  # Example:
  # echo -e "$CONTR_SEQ$ATTR_BOLD$FG_RED$HOSTNAME$CONTR_SEQ$ATTR_BLINK${FG_WHITE}:$UNSET_COLOR"
  # echo -e "$CONTR_SEQ$FG_MAGENTA blablabla $UNSET_COLOR"  ### - simplest case
}

resolve_disks() {
  sysfsmount=`cat /etc/mtab | grep '^sysfs '`
  if [ -n "$sysfsmount" ]; then
    sfsmp=`echo $sysfsmount | cut -sd' ' -f2`
    for blkdev in $sfsmp/block/* ; do
      sysblkdev=`readlink -f $blkdev`
      if [[ $sysblkdev =~ '/devices/virtual/' ]]; then
        name=`cat $sysblkdev/dm/name`
      else
        name=$blkdev
      fi
      size=`cat $sysblkdev/size`
      removable=`cat $sysblkdev/removable`
    done
    

  
  
  fi
}

resolve_markdown() {
  IFSORIG=$IFS
  IFS='
'
  [ ! -e "$1" ] && echo "*** file $1 not found!" >&2 && exit 1
  [ -n "$debug" ] || debug=false
  tmpfile="$M_TEMP/${1##*/}.tmp"
  rm "$tmpfile" "${tmpfile}.orig" 2>/dev/null
  cat "$1" | sed 's|}\%|}\%\\\n|g' | \
    sed "s|\\$|\\\\$|g;s|\%{\(.*\)}\%|$\{\1\}|g" | \
    sed 's|\\"|\\\\"|g' | \
    sed 's|"|\\\"|g' | \
    sed 's|`|\\\`|g' >> "${tmpfile}.orig"

  $debug && echo -e "\n --- TMP FILE ---\n\n" >&2 && cat "${tmpfile}.orig" && echo -e " --- END OF TMP FILE ---\n\n --- TMP FILE w/vars substituted ---\n\n" >&2

  for LINE in `cat -E "${tmpfile}.orig"` ; do
    if [[ `echo $LINE | grep -c '\\\\$$'` -gt 0 ]]; then
      KEEP="${KEEP}`echo "$LINE" | sed 's|\\\\$$||'`"
      continue
    else
      LINE="${KEEP}`echo $LINE | sed 's|\$$||'`"
      unset KEEP
      a=`eval "echo \"$LINE\""`
      if [ $? -eq 0 ] && [ -n "$a" ]; then
        echo "$a"
      else
        echo "$LINE"
      fi
    fi
  done
  IFS=$IFSORIG
  rm "$tmpfile" "${tmpfile}.orig" 2>/dev/null
}

readpath() { # readpath {/path/to/greppable/file|-} {path/to/object} <object filter> <value filter>
  local length=`echo "${2%/}" | grep -o '/' | wc -l`
  if [ -n "$4" ]; then # supposed to return multiple arrays, one of them has to be chosen based on $3
    local objarr=`cat $1 | tr -d '"' | grep "^${2%/}"`
    local objarrindex=`echo "$objarr" | grep "$3" | cut -sd'/' -f$((length+2))- | cut -sd'/' -f1`
    local obj=`echo "$objarr" | grep "^${2%/}/$objarrindex/$4"`
  elif [ -n "$3" ]; then # simple grep
    local obj=`cat $1 | tr -d '"' | grep "^${2%/}" | grep "$3"`
  else
    local obj=`cat $1 | tr -d '"' | grep "^${2%/}"`
  fi
  res=`echo "$obj" | cut -sd'/' -f$((length+2))-`
  [ `echo -n "$res" | wc -l` -eq 0 ] && echo "$obj" | cut -sd'|' -f2 && return 0
  [ `echo -n "$res" | wc -l` -eq 1 ] && echo "$res" | cut -sd'|' -f2 && return 0
  [ `echo -n "$res" | cut -sd'|' -f1 | grep -vcE '^[0-9]*$'` -eq 0 ] && echo "$res" | cut -sd'|' -f2 | sed 's|^|"|;s|$|"|' && return 0
  echo "$res"
}

