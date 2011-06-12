#!/bin/bash
INWAIT=`which inotifywait 2>/dev/null`
pidfile=/root/folder_create_monitor.pid
LSOF=`which lsof 2>/dev/null`
AWK=`which awk 2>/dev/null`
case $1 in
start)
  trap 'exit 0' 0
  trap 'exit 0' 3
  trap 'exit 0' 15

  (${INWAIT} -mrq --timefmt '%s' --format '%T|%e|%w|%f' -e create $2 & echo "$!" >> $pidfile) | while read LINE ; do
    if [ -d `echo ${LINE} | ${AWK} -F'|' '{print $4}'` ] ; then
      $LSOF $2 > /root/folder_create_monitor.tmp
      ps -ef >> /root/folder_create_monitor.tmp
      date >> /root/folder_create_monitor.tmp
      echo >> /root/folder_create_monitor.tmp
      cat /root/folder_create_monitor.tmp | mail -s "Password change detected" me@igorsimonov.com
      cat /root/folder_create_monitor.tmp >> /root/folder_create_monitor.log
    fi
  done &
  echo "$!" >> $pidfile
  ;;
stop)
  if [ -f ${pidfile} ]; then
    for pid in `cat ${pidfile}` ; do
      printf "Stopping process $pid...      "
      kill -15 $pid && printf "done\n" || printf "failed\n"
    done
    rm -f $pidfile
  fi
  ;;
restart)
  $0 stop
  sleep 3
  $0 start
  ;;
*)
  echo "Usage: $0 start|stop|restart TARGET"
  ;;
esac


