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

rpath=$(readlink -f "$BASH_SOURCE")
rcommand=${rpath##*/}
rpath=${rpath%/*}
#*/
source "$rpath/../conf/mon.conf"
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
  echo "<div class=\"clustername\"><span class=\"indent\">${@}</span></div>\n<div class=\"cluster\" id=\"${id}\">"
}

print_cluster_bottom() {
  echo "</div>"
}

print_line_title() {
  onclick=$1
  shift
  id=$(echo ${@} | tr ' ' '_')
  echo "<div class=\"server\" id=\"${id}\">\n<div class=\"servername\" id=\"${id}_name\" onclick=\"showDetails('${id}','${onclick}')\">${@}</div>"
}

close_line() {
  echo "</div>"
}

print_dashline() {
  source=$1
  shift
  if [ -n "$source" ]; then
    case $source in
    folder)
      shift
      cat "$rpath/../www/$1/dash.html"
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



