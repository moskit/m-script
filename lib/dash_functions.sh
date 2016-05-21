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

source "$M_ROOT/conf/mon.conf"
source "$M_ROOT/conf/dash.conf"
[ -n "$timeshift" ] || timeshift=`cat "$M_TEMP/timeshift" 2>/dev/null` || timeshift=10
freqdef=`expr $FREQ + $timeshift`

SQL=`which sqlite3 2>/dev/null`

source "$M_ROOT/lib/cloud_functions.sh"
export CLOUD CLOUDS freqdef

print_cgi_headers() {
cat << "EOF"
Pragma: no-cache
Expires: 0
Content-Cache: no-cache
Content-type: text/html

EOF
}

print_page_title() {
  # print_page_title "main title" "title1<|cssclass1>" "title2<|cssclass2>"...
  echo -e "<div class=\"dashtitle\">\n  <div class=\"server\">\n    <div class=\"servername\" id=\"title1\">${1}</div>"
  shift
  while [ -n "$1" ] ; do
    dfpptarg="$1"
    dfppttitle=`echo "$dfpptarg" | cut -d'|' -f1`
    dfpptid=$(echo "$dfppttitle" | tr ' ' '_')
    dfpptclass=`echo "$dfpptarg" | cut -sd'|' -f2`
    [ -z "$dfpptclass" ] && dfpptclass="status"
    if [ "_$dfppttitle" == "_-" ]; then
      echo "<div class=\"$dfpptclass\" id=\"$dfpptid\">&nbsp;</div>"
      shift
      continue
    fi
    echo "<div id=\"$dfpptid\" class=\"$dfpptclass\"><b>${dfppttitle}</b></div>"
    shift
  done
  echo -e "  </div>\n</div>"
  unset dfpptid
}

open_cluster() {
  # open_cluster "Cluster (folder name)" "Onclick script" "Title (pop-up on hover)"
  dfocid="$1"
  shift
  [ -n "$1" ] && dfoconclick="$1"
  shift
  echo "<div class=\"cluster\" id=\"${dfocid}\" title=\"$@\">"
  echo -e "<div class=\"clustername\"><span id=\"${dfocid}_name\" `[ -n "$dfoconclick" ] && echo -n "class=\\"indent clickable\\" onclick=\\"showDetails('${dfocid}_name','${dfoconclick}')\\"" || echo -n "class=\\"indent\\""`>${dfocid##*|}</span>"
  unset dfoconclick
}

print_cluster_inline() {
  # print_cluster_inline "metric<|onclick><|cssclass>" "metric2<|onclick2><|cssclass2>" ...
  while [ -n "$1" ] ; do
    dfpcistatusarg="$1"
    if [ "_$dfpcistatusarg" == "_-" ]; then
      echo "<div id=\"${dfocid}_status\" class=\"clusterstatus\">&dash;</div>"
      shift
      continue
    fi
    dfpcistatus=`echo "$dfpcistatusarg" | cut -d'|' -f1`
    dfpcionclick=`echo "$dfpcistatusarg" | cut -sd'|' -f2`
    dfpciclass=`echo "$dfpcistatusarg" | cut -sd'|' -f3`
    if [ -n "$dfpcionclick" ]; then
      classadded="clickable"
      onclick="onclick=\"showDetails('${dfolid}_$dfpcistatus','$dfpcionclick')\""
    else
      unset onclick classadded dfpcionclick
    fi
    [ -z "$dfpciclass" ] && dfpciclass="status"
    dfpcicont=`eval echo \\$$dfpcistatus`
    [ ${#dfpcicont} -gt 12 ] && dfpcicontalt=`echo -n "$dfpcicont" | cut -d'=' -f2 | tr -d '<>'` || unset dfpcicontalt
    echo "<div id=\"${dfocid}_status\" class=\"$dfpciclass $classadded\" $onclick title=\"$dfpcicontalt\">${dfpcicont}</div>"
    shift
  done
}

close_cluster_line() {
  echo "</div>"
  [ -n "$dfocid" ] && echo "<div class=\"details\" id=\"${dfocid}_details\"></div>"
}

close_cluster() {
  echo "</div>"
  unset dfocid
}

open_line() {
  # open_line "title<|style><|uniqkey>" "onclick"
  dfoltitle="$1"
  shift
  if [ -n "$1" ]; then
    dfolonclick=$1
    classadded="clickable"
  fi
  dfolkey=`echo "$dfoltitle" | cut -s -d'|' -f3`
  dfolnode="${dfoltitle%%|*}"
  dfolstyle=" `echo "$dfoltitle" | cut -sd'|' -f2`"
  dfolnodep="${dfolnode:0:20}"
  [ -n "$dfocid" ] && dfolkey="${dfocid#*|}${dfolkey}"
  [ -n "$dfolkey" ] && dfolid="$dfolkey|$dfolnode" || dfolid="$dfolnode"
  echo -e "<div class=\"server${dfolstyle}\" id=\"${dfolid}\">\n<div class=\"servername $classadded\" id=\"${dfolid}_name\" onclick=\"showDetails('${dfolid}_name','${dfolonclick}')\" title=\"$dfolnode\">$dfolnodep</div>"
  unset dfolparent dfolnode dfolonclick dfolnodep
}

close_line() {
  echo "</div>"
  echo "<div class=\"details\" id=\"${dfolid}_details\"></div>"
  unset dfolid
}

print_inline() {
  # print_inline "metric<|onclick><|style>" "metric2<|onclick2><|style2>" ...
  while [ -n "$1" ] ; do
    dfpistatusarg="$1"
    if [ "_$dfpistatusarg" == "_-" ]; then
      echo "<div id=\"${dfolid}_status\" class=\"clusterstatus\">&dash;</div>"
      shift
      continue
    fi
    dfpistatus=`echo "$dfpistatusarg" | cut -d'|' -f1`
    dfpionclick=`echo "$dfpistatusarg" | cut -s -d'|' -f2`
    dfpistyle=`echo "$dfpistatusarg" | cut -s -d'|' -f3`
    if [ -n "$dfpionclick" ]; then
      classadded="clickable"
      onclick="onclick=\"showDetails('${dfolid}_$dfpistatus','$dfpionclick')\""
    else
      unset onclick classadded dfpionclick
    fi
    [ -n "$dfpistyle"] && style="style=\"$dfpistyle\"" || unset style
    echo "<div class=\"status $classadded\" id=\"${dfolid}_$dfpistatus\" $onclick $style>`eval echo \"\\$$dfpistatus\"`</div>"
    shift
  done
  unset dfpistatus dfpionclick dfpistyle
}

print_dashline() {
  # if source is a folder:
  # print_dashlines path/to/folder <"onclick">
  # where folder is the one where dash.html is located, path relative to M_ROOT/www
  # if source is an Sqlite database:
  # print_dashlines "/path/to/db/file|table name|node field name|/path/to/test/conf" <"onclick">
  local target="$1"
  shift
  local onclick="$1"
  shift
  local source="$1"
  if [ -z "$source" ]; then
    if [ -d "$M_ROOT/www/$target" ]; then
      source=folder
    else
      source=sqlite
    fi
  fi
  case $source in
    folder)
      [ -d "$M_ROOT/www/$target" ] || install -d "$M_ROOT/www/$target"
      tail -n $slotline_length "$M_ROOT/www/$target/dash.html" 2>/dev/null
      ;;
    sqlite)
      local dbfile=`echo "$target" | cut -sd'|' -f1`
      local dbtable=`echo "$target" | cut -sd'|' -f2`
      local nodefield=`echo "$target" | cut -sd'|' -f3`
      local conf=`echo "$target" | cut -sd'|' -f4`
      source "$conf"
      ;;
  esac
}

print_dashlines() {
  # if source is a folder:
  # print_dashlines path/to/folder <"onclick">
  # where folder is the one named after the test binary in M_ROOT/www
  # if source is an Sqlite database:
  # print_dashlines "/path/to/db/file|table name|node field name|/path/to/test/conf" <"onclick">
  local target="$1"
  shift
  local onclick="$1"
  shift
  local source="$1"
  if [ -z "$source" ]; then
    if [ -d "$M_ROOT/www/$target" ]; then
      source=folder
    else
      source=sqlite
    fi
  fi
  case $source in
    folder)
      if [ -z "$dfocid" ]; then
        echo "<p color=\"red\">print_dashlines function must be inside the open_cluster/close_cluster block</p>"
        return 1
      fi
      cld=`echo $dfocid | cut -sd'|' -f1`
      cls=${dfocid#*|}
      [ -d "$M_ROOT/www/$target" ] || install -d "$M_ROOT/www/$target"
IFS1=$IFS; IFS='
'
      if [ -d "$M_ROOT/www/$target/localhost" ]; then
        for lip in `"$M_ROOT"/helpers/localips | grep -v '127.0.0.1'` ; do
          noderecord=`cat "$M_ROOT/nodes.list" | grep -vE "^#|^[[:space:]]#|^$" | cut -d'|' -f1,4,5,6 | grep "^$lip|"`
          [ -n "$noderecord" ] && break
        done
        # if localhost found as a cloud server (a part of configured cluster)
        if [ -n "$noderecord" ]; then
          node=`echo "$noderecord" | cut -sd'|' -f2`
          # lcls=`echo "$noderecord" | cut -sd'|' -f3`  # not needed for now
          lcld=`echo "$noderecord" | cut -sd'|' -f4`
          # defaulting to the found cloud in case cld is not defined
          [ -z "$cld" ] && cld=$lcld
          if [ "_$lcld" == "_$cld" ]; then
            open_line "$node||$cld" "$onclick"
            tail -n $slotline_length "$M_ROOT/www/$target/localhost/dash.html" 2>/dev/null
            close_line
            [ -d "$M_ROOT/www/$target/$cld/$cls" ] || install -d "$M_ROOT/www/$target/$cld/$cls"
            # symlink is needed to make downstream scripts work (like onclick scripts)
            [ -h "$M_ROOT/www/$target/$cld/$cls/$node" ] || ln -s "$M_ROOT/www/$target/localhost" "$M_ROOT/www/$target/$cld/$cls/$node"
          fi
        else
          open_line "localhost" "$onclick"
          tail -n $slotline_length "$M_ROOT/www/$target/localhost/dash.html" 2>/dev/null
          close_line
        fi
      fi
      for node in `find "$M_ROOT/www/$target/$cld/$cls/" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort` ; do
        node="${node##*/}"
        open_line "$node||${cld}_${cls}" "$onclick"
        tail -n $slotline_length "$M_ROOT/www/$target/$cld/$cls/$node/dash.html" 2>/dev/null
        close_line
      done
IFS=$IFS1
      ;;
    sqlite)
      local dbfile=`echo "$target" | cut -sd'|' -f1`
      local dbtable=`echo "$target" | cut -sd'|' -f2`
      local nodefield=`echo "$target" | cut -sd'|' -f3`
      local conf=`echo "$target" | cut -sd'|' -f4`
      source "$conf" 2>/dev/null
      ;;
  esac
}

print_timeline() {
  # print_timeline "title" <interval>
  if [ -n "$2" ]; then
    interval=$2
  else
    interval=$FREQ
  fi
  timerange=`expr $slotline_length \* \( $interval + $timeshift \)` || timerange=10000
  # print every 1st hour
  factor=1
  [ $interval -gt 1000 ] 2>/dev/null && factor=2
  local -i i
  i=0
  dfptoldest=`date -d "-$timerange sec"`
  dfpthour=`date -d "$dfptoldest" +"%H"`
  echo -e "<br/>\n<div class=\"server\">\n<span class=\"servername\">${1}</span>"
  for ((n=0; n<$slotline_length; n++)) ; do
    dfpttimediff=`expr $n \* \( $interval + $timeshift \)`
    dfpttimestamp=`date -d "$dfptoldest +$dfpttimediff sec"`
    dfpthournew=`date -d "$dfpttimestamp" +"%H"`
    if [ "_$dfpthournew" == "_$dfpthour" ] ; then
      echo "<div class=\"chunk timeline\">&nbsp;</div>"
    else
      i+=1
      if [ $i -eq $factor ]; then
        echo "<div class=\"chunk hour\">${dfpthournew}:00</div>"
        i=0
      else
        echo "<div class=\"chunk timeline\">&nbsp;</div>"
      fi
      dfpthour=$dfpthournew
    fi
  done
  echo "</div>"
  unset dfptoldest dfpthour dfpttimediff dfpttimestamp dfpthournew
}

print_nav_bar() {
  callername="${0%.cgi}"
  callername="${callername##*/}"
  unset dfpnbactive
  # view0 is a special ID indicating updaterlevel = 0 in monitors.js
  # that is, clicking it is the same as clicking the corresponding upper tab
  # other buttons IDs become CGI scripts names (with .cgi extension)
  ## Views provided as arguments have the highest priority
  if [ -n "$1" ]; then
    dfpnbcgi="${1%%|*}"
    dfpnbbtn="${1#*|}"
    [ "${dfpnbcgi#*/}" == "$callername" ] && dfpnbactive=" active"
    echo -e "<div id=\"views\">\n<ul id=\"viewsnav\">\n<li class=\"viewsbutton$dfpnbactive\" id=\"view0\" onClick=\"setUpdater('$dfpnbcgi')\">$dfpnbbtn</li>"
      shift
      while [ -n "$1" ]; do
        dfpnbcgi="${1%%|*}"
        dfpnbbtn="${1#*|}"
        # not printing if not exists
        if [ -x "$M_ROOT/www/bin/${1%%|*}.cgi" ]; then
          unset dfpnbactive
          [ "${dfpnbcgi#*/}" == "$callername" ] && dfpnbactive=" active"
          echo -e "<li class=\"viewsbutton$dfpnbactive\" id=\"${1%%|*}\" onClick=\"setUpdater('$dfpnbcgi')\">$dfpnbbtn</li>\n"
        fi
        shift
      done
    echo -e "</ul>\n</div>"
  else
    unset dfpnbactive
    ## Views from file nav.bar, located in SA folder. Requires variable 'saname'
    ## to be defined in CGI script! (name of the folder)
    if [ -e "$M_ROOT/standalone/$saname/nav.bar" ]; then
      IFSORIG=$IFS
      IFS='
'
        view=`cat "$M_ROOT/standalone/$saname/nav.bar" | head -1`
        if [ -x "$M_ROOT/www/bin/${view%%|*}.cgi" ]; then
          [ "${view%%|*}" == "$callername" ] && dfpnbactive=" active"
          echo -e "<div id=\"views\">\n<ul id=\"viewsnav\">\n<li class=\"viewsbutton$dfpnbactive\" id=\"view0\" onClick=\"setUpdater('${view%%|*}')\">${view#*|}</li>"
          unset dfpnbactive
        fi
        for view in `cat "$M_ROOT/standalone/$saname/nav.bar" | tail -n +2`; do
          if [ -x "$M_ROOT/www/bin/${view%%|*}.cgi" ]; then
            [ "${view%%|*}" == "$callername" ] && dfpnbactive=" active"
            echo -e "<div id=\"views\">\n<ul id=\"viewsnav\">\n<li class=\"viewsbutton$dfpnbactive\" id=\"view0\" onClick=\"setUpdater('${view%%|*}')\">${view#*|}</li>"
            unset dfpnbactive
          fi
        done
      IFS=$IFSORIG
    else
      # 3rd way: for each monitor there is CGI script with the same name, e.g.
      # SAFOLDER/foo.mon corresponds to M_ROOT/www/bin/foo.cgi
      # This means that the main monitor (corresp. to view0 CGI) must have the
      # same name as SAFOLDER, e.g. M_ROOT/standalone/MyMonitor/MyMonitor.mon
      for view in `find "$M_ROOT/standalone/$saname" -type l | sort | xargs readlink -f`; do
        view="${view##*/}"
        view="${view%.mon}"
        if [ "$view" == "$saname" ]; then
          if [ -x "$M_ROOT/www/bin/${view%%|*}.cgi" ]; then
            [ "$view" == "$callername" ] && dfpnbactive=" active"
            v0="<div id=\"views\">\n<ul id=\"viewsnav\">\n<li class=\"viewsbutton$dfpnbactive\" id=\"view0\" onClick=\"setUpdater('${view}')\">${view}</li>"
            unset dfpnbactive
          fi
        else
          if [ -x "$M_ROOT/www/bin/${view%%|*}.cgi" ]; then
            [ "$view" == "$callername" ] && dfpnbactive=" active"
            v1="<div id=\"views\">\n<ul id=\"viewsnav\">\n<li class=\"viewsbutton$dfpnbactive\" id=\"view0\" onClick=\"setUpdater('${view}')\">${view}</li>"
            unset dfpnbactive
          fi
        fi
      done
    fi
  fi
  unset dfpnbactive
}

print_table_2() {
  echo "<div class=\"tr\"><div class=\"td1\">${1}</div><div class=\"td2\">${2}</div></div>"
}

load_css() {
  echo "<style type=\"text/css\">"
  cat "$M_ROOT/www/css/$1"
  echo "</style>"
}

cgi_begin() {
  scriptname=${0%.cgi}
  saname=${PWD##*/}
  [ "_$saname" == "_bin" ] && unset saname
  scriptname=${scriptname##*/}
  if $cache_enabled ; then
    if [ ! -d "$M_ROOT/www/preloaders/$saname" ]; then
      install -d "$M_ROOT/www/preloaders/$saname"
    fi
    dFREQ=`expr $FREQ \* 2 / 60`
    if [ -z "`find "$M_ROOT/www/preloaders/$saname" -type f -name "${scriptname}.html" -mmin -$dFREQ`" ]; then
      exec 6>&1
      exec > "$M_ROOT/www/preloaders/$saname/${scriptname}.html.new"
      cachingrun=1
    else
      print_cgi_headers
    fi
  else
    print_cgi_headers
  fi
}

cgi_end() {
  if [ -n "$cachingrun" ]; then
    exec 1>&6 6>&-
    print_cgi_headers && cat "$M_ROOT/www/preloaders/$saname/${scriptname}.html.new"
    mv "$M_ROOT/www/preloaders/$saname/${scriptname}.html.new" "$M_ROOT/www/preloaders/$saname/${scriptname}.html"
  fi
}
