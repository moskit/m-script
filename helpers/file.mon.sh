#!/bin/bash
INWAIT=`which inotifywait 2>/dev/null`
pidfile=/root/file_monitor.pid
LSOF=`which lsof 2>/dev/null`

case $1 in
start)
  ($INWAIT -mrq --timefmt '%s' --format '%T|%e|%w|%f' -e open $2 & echo "$!" >> $pidfile) | while read LINE ; do
    $LSOF $2 > /root/file_monitor.tmp
    ps -ef >> /root/file_monitor.tmp
    date >> /root/file_monitor.tmp
    echo >> /root/file_monitor.tmp
    cat /root/file_monitor.tmp | mail -s "Password change detected" me@igorsimonov.com
    cat /root/file_monitor.tmp >> /root/file_monitor.log
  done &
  echo "$!" >> $pidfile
  ;;
stop)
  if [ -f $pidfile ]; then
    for pid in `cat $pidfile` ; do
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


