#!/bin/bash

log() {
  if [ -n "$LOG" ]; then
    echo -e "`date +"%m.%d %H:%M:%S"` ($PPID/$$) ${0##*/}: ${@}">>$LOG
  fi
}

errorexit() {
  echo -e "$CONTR_SEQ$ATTR_BOLD${FG_RED}$1${UNSET_COLOR}" >&2
  release_lock
  exit 1
}

do_backup() {
  starttime=`date +"%s"`
  $1 $2 $3
  res=$?
  finishtime=`date +"%s"`
  timespent `expr $finishtime - $starttime`
  [ $res -eq 0 ] && echo "Backup finished in $timetotal" || echo "Backup failed after $timetotal"
  return $res
}

timespent() {
  timetotal=$1
  if [ $timetotal -lt 60 ]; then
    timetotal="$timetotal sec"
  elif [ $timetotal -lt 3600 ]; then
    timetotal="`expr $timetotal / 60` min `expr $timetotal % 60` sec"
  elif [ $timetotal -lt 86400 ]; then
    timetotal="`expr $timetotal / 3600` hours `expr $timetotal % 3600 / 60` min"
  else
    timetotal="`expr $timetotal / 86400` days `expr $timetotal % 86400 / 3600` hours"
  fi
}

sizeof() {
  spath=$1
  totalsize=`du -k -s "$spath" | cut -f1`
  if [ $totalsize -lt 100000 ]; then
    totalsize="$totalsize kB"
  elif [ $totalsize -lt 100000000 ]; then
    totalsize="`expr $totalsize / 1000` MB"
  elif [ $totalsize -lt 100000000000 ]; then
    totalsize="`expr $totalsize / 1000000` GB"
  else
    totalsize="`expr $totalsize / 1000000000` TB"
  fi
}

splitfile() {
  if [ -n "$split_size" ]; then
    split -b $split_size -d $1 $1
    rm "${localbackuppath}/${archname}.${linetoname}.tar.bz2"
  fi
}

tar_files() {
  TAR=`which tar 2>/dev/null`
  [ -z "$TAR" ] && errorexit "Tar executable not found"
  while read LINE ; do
    linetoname=`echo "$LINE" | sed 's|/|_|g'`
    case $compression in
    gzip|gz)
      $TAR $ARCOPTS -c -z -f "$targetpath/${archname}.${linetoname}.tar.gz" "$LINE"
      res=$?
      if [ $res -eq 0 ]; then
        log "tar.gz backup: success, file size `stat -c %s "$targetpath/${archname}.${linetoname}.tar.gz"`"
        splitfile "$targetpath/${archname}.${linetoname}.tar.gz"
      fi
      ;;
    bzip2|bz2)
      $TAR $ARCOPTS -c -j -f "$targetpath/${archname}.${linetoname}.tar.bz2" "$LINE"
      res=$?
      if [ $res -eq 0 ]; then
        log "tar.bz2 backup: success, file size `stat -c %s "$targetpath/${archname}.${linetoname}.tar.bz2"`"
        splitfile "$targetpath/${archname}.${linetoname}.tar.bz2"
      fi
      ;;
    xz)
      $TAR $ARCOPTS -c -J -f "$targetpath/${archname}.${linetoname}.tar.xz" "$LINE"
      res=$?
      if [ $res -eq 0 ]; then
        log "tar.xz backup: success, file size `stat -c %s "$targetpath/${archname}.${linetoname}.tar.xz"`"
        splitfile "$targetpath/${archname}.${linetoname}.tar.xz"
      fi
      ;;
    "")
      $TAR $ARCOPTS -c -f "$targetpath/${archname}.${linetoname}.tar" "$LINE"
      res=$?
      if [ $res -eq 0 ]; then
        log "tar backup: success, file size `stat -c %s "$targetpath/${archname}.${linetoname}.tar"`"
        splitfile "$targetpath/${archname}.${linetoname}.tar"
      fi
      ;;
    esac
  done<"$1"
  return $res
}
