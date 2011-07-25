#!/bin/bash

MYSQL=`which mysql 2>/dev/null`
MYUSER=
MYPASS=
MYDB=
rcommand=${0##*/}
rpath=${0%/*}
#*/
echo ""
echo "Delayed Jobs monitor"
echo "--------------------------"
echo ""

result=`$MYSQL -B -N -u$MYUSER -p$MYPASS $MYDB -e "select * from delayed_jobs where last_error is not null or failed_at is not null"`
if [ `echo $result | grep -v ^$ | wc -l` -eq 0  ]; then
  echo "<OK> No failed delayed jobs found."
else
  echo "<***> Found failed delayed jobs!"
  echo $result | sed 's|\\n|\n\r|g' | sed 's|^|<***>  |g'
fi

