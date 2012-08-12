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

M_ROOT=$(readlink -f "$dpath/..")

source "$dpath/../conf/mon.conf"
source "$dpath/../conf/dash.conf"
[ -n "$timeshift" ] || timeshift=`cat "$M_TEMP"/timeshift 2>/dev/null` || timeshift=5
[ -n "$freqdef" ] || freqdef=$FREQ
timerange=`expr $slotline_length \* \( $freqdef - $timeshift \)` || timerange=10000

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
  echo -e "<div class=\"dashtitle\">\n  <div class=\"server\">\n    <div class=\"servername\" id=\"title1\">${1}</div>"
  shift
  while [ -n "$1" ] ; do
    id=$(echo "$1" | tr -d '<>/' | tr ' ' '_')
    echo "<div class=\"status\" id=\"${id}\"><b>${1}</b></div>"
    shift
  done
  echo -e "  </div>\n</div>"
}

open_cluster() {
  if [ -n "$2" ]; then
    onclick=$1
    shift
  fi
  id="${@}"
  echo "<div class=\"cluster\" id=\"${id%%|*}\">"
  echo -e "<div class=\"clustername\"><span id=\"${id}_name\" `[ -n "$onclick" ] && echo -n "class=\\"indent clickable\\" onclick=\\"showDetails('${id}_name','${onclick}')\\"" || echo -n "class=\\"indent\\""`>${id#*|}</span>"
  unset onclick
}

print_cluster_inline() {
  while [ -n "$1" ] ; do
    status="$1"
    [ "${status%%|*}" != "${status#*|}" ] && onclick="${status#*|}" && status="${status%%|*}"
    [ -n "$onclick" -a "${onclick%%|*}" != "${onclick#*|}" ] && style="${onclick#*|}" && onclick="${onclick%%|*}"
    echo "<div id=\"${id}_status\" `[ -n "$onclick" ] && echo -n "class=\\"clusterstatus clickable\\" onclick=\\"showDetails('${id}_name','${onclick}')\\"" || echo -n "class=\\"clusterstatus\\""` style=\"$style\">$status</div>"
    shift
  done
}

close_cluster_line() {
  id="${@}"
  echo "</div>"
  [ -n "$id" ] && echo "<div class=\"details\" id=\"${id}_details\"></div>"
  
}

close_cluster() {
  echo "</div>"
}

print_line_title() {
  if [ -n "$2" ]; then
    onclick=$1
    shift
  fi
  id="${@}"
  echo -e "<div class=\"server\" id=\"${id}\">\n<div class=\"servername\" id=\"${id}_name\" onclick=\"showDetails('${id}_name','${onclick}')\">${@}</div>"
}

print_inline() {
  while [ -n "$1" ] ; do
    status="$1"
    [ "${status%%|*}" != "${status#*|}" ] && onclick="${status#*|}" && status="${status%%|*}"
    [ -n "$onclick" -a "${onclick%%|*}" != "${onclick#*|}" ] && style="${onclick#*|}"
    echo "<div class=\"status\" id=\"${clustername}_$status\" onclick=\"showDetails('${clustername}_name','$onclick')\" style=\"$style\">`eval echo \"\\$$status\"`</div>"
    shift
  done
}

close_line() {
 # id=$(echo ${@} | tr ' ' '_')
  id="${@}"
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
IFS1=$IFS; IFS='
'
      for server in `find "$dpath/../www/${@}/" -maxdepth 1 -mindepth 1 -type d` ; do
        print_line_title $onclick "${server##*/}"
        cat "$dpath/../www/${@}/${server##*/}/dash.html"
        close_line "${server##*/}"
      done
IFS=$IFS1
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
  oldest=`date -d "-$timerange sec"`
  hour=`date -d "$oldest" +"%H"`
  echo -e "<div class=\"dashtitle\">\n<div class=\"clustername\"><span class=\"indent\">${1}</span></div>\n<div class=\"server\">\n<span class=\"servername\">${2}</span>\n"
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

print_nav_bar() {
  # view0 is a special ID indicating updaterlevel = 0 in monitors.js
  # that is, clicking it is the same as clicking the corresponding upper tab
  # other buttons IDs become CGI scripts names (with .cgi extension)
  [ -z "$1" ] && exit 0
  [ "${1%%|*}" == "${0%.cgi}" ] && active=" active"
  echo -e "<div id=\"views\">\n<ul id=\"viewsnav\">\n<li class=\"viewsbutton$active\" id=\"view0\" onClick=\"initMonitors('${1%%|*}', 0)\">${1#*|}</li>"
    shift
    while [ -n "$1" ]; do
      unset active
      [ "${1%%|*}" == "${0%.cgi}" ] && active=" active"
      echo -e "<li class=\"viewsbutton$active\" id=\"${1%%|*}\" onClick=\"initMonitors('${1%%|*}', 1)\">${1#*|}</li>\n"
      shift
    done
  echo -e "</ul>\n</div>"
}

