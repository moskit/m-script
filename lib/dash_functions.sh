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

dpath=$(readlink -f "$BASH_SOURCE")
dpath=${dpath%/*}
#*/
source "$dpath/../conf/mon.conf"
source "$dpath/../conf/dash.conf"

SQL=`which sqlite3 2>/dev/null`

print_cgi_headers() {
cat << "EOF"
Pragma: no-cache
Expires: 0
Content-Cache: no-cache
Content-type: text/html

EOF
}

print_page_title() {
  echo -e "<div class=\"dashtitle\">\n  <div class=\"server\">\n    <div class=\"servername\" id=\"title1\">${1%%|*}</div>"
  IFS1=$IFS ; IFS='|'
  for title in ${1#*|} ; do
    id=$(echo $title | tr -d '<>/' | tr ' ' '_')
    echo "<div class=\"status\" id=\"${id}\"><b>${title}</b></div>"
  done
  echo -e "  </div>\n</div>"
  IFS=$IFS1
}

print_cluster_header() {
  id=$(echo ${@} | tr ' ' '_')
  echo -e "<div class=\"clustername\"><span class=\"indent\">${@}</span></div>\n<div class=\"cluster\" id=\"${id}\">"
}

print_cluster_bottom() {
  echo "</div>"
}

print_line_title() {
  onclick=$1
  shift
  id=$(echo ${@} | tr ' ' '_')
  echo -e "<div class=\"server\" id=\"${id}\">\n<div class=\"servername\" id=\"${id}_name\" onclick=\"showDetails('${id}_name','${onclick}')\">${@}</div>"
}

close_line() {
  id=$(echo ${@} | tr ' ' '_')
  echo "</div>"
  echo "<div class=\"details\" id=\"${id}_details\"></div>"
}

print_dashline() {
  source=$1
  shift
  if [ -n "$source" ]; then
    case $source in
    folder)
      [ -d "$dpath/../www/${@}" ] || install -d "$dpath/../www/${@}"
      cat "$dpath/../www/${@}/dash.html"
      ;;
    database)
      dbpath=$1
      shift
      dbtable=$1
      ;;
    esac
  fi
}

print_dashlines() {
  onclick=$1
  source=$2
  shift 2
  if [ -n "$source" ]; then
    case $source in
    folder)
      [ -d "$dpath/../www/${@}" ] || install -d "$dpath/../www/${@}"
      for server in `find "$dpath/../www/${@}" -maxdepth 1 -mindepth 1 -type d` ; do
        print_line_title $onclick "${server##*/}"
        cat "$dpath/../www/${@}/${server##*/}/dash.html"
        close_line "${server##*/}"
      done
      ;;
    database)
      shift
      dbpath=$1
      shift
      dbtable=$1
      
      
      ;;
    esac
  fi
}

print_timeline() {
  [ -n "$timeshift" ] || timeshift=`cat "$TMPDIR"/timeshift 2>/dev/null` || timeshift=5
  [ -n "$freqdef" ] || freqdef=$FREQ
  timerange=`expr $slotline_length \* \( $freqdef - $timeshift \)` || timerange=10000
  oldest=`date -d "-$timerange sec"`
  hour=`date -d "$oldest" +"%H"`
  echo -e "<div class=\"dashtitle\">\n<div class=\"clustername\"><span class=\"indent\">${1}</span></div>\n<div class=\"server\">\n<span class=\"servername\">${2}</span>\n"
  freqdef1=`expr $freqdef + 5`
  for ((n=0; n<$slotline_length; n++)) ; do
    timediff=`expr $n \* \( $freqdef - $timeshift \)`
    timestamp=`date -d "$oldest +$timediff sec"`
    hournew=`date -d "$timestamp" +"%H"`
    if [ "X$hournew" == "X$hour" ] ; then
      echo "<div class=\"chunk\">&nbsp;</div>"
    else
      echo "<div class=\"chunk hour\">${hournew}:00</div>"
      hour=$hournew
    fi
  done
  echo -e "</div>\n</div>"
}


