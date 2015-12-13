#!/bin/bash
# Copyright (C) 2008-2009 Igor Simonov (me@igorsimonov.com)
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
[ -z "$M_ROOT" ] && M_ROOT=$(readlink -f "$rpath/..")
#*/
source "$M_ROOT/conf/mon.conf"
rm -rf "$M_TEMP"/.update/
timeindex=`date -u +"%s"`
GIT=`which git 2>/dev/null`
WGET=`which wget 2>/dev/null`
if [ -z "$GIT" ]; then
  echo "Git not found! Fetching tarball..."
  install -d "$M_TEMP"/.update "$M_TEMP".$$
  "$M_ROOT"/helpers/fetch http://igorsimonov.com/m_script.latest.tar.gz "$M_TEMP"/
  # if fetch fails, it is still possible to download it manually to /tmp
  if [ -f "$M_TEMP/m_script.latest.tar.gz" ]; then
    `which tar` -xzf "$M_TEMP"/m_script.latest.tar.gz -C "$M_TEMP".$$
    rm -f "$M_TEMP"/m_script.latest.tar.gz
    mv "$M_TEMP".$$/m/* "$M_TEMP"/.update
  fi
else
  $GIT clone --depth 1 git://igorsimonov.com/m_script "$M_TEMP"/.update || exit 1
  gitts=$(cd "$M_TEMP"/.update && $GIT log -n1 --format=%at | tail -1)
fi

[ "X$1" == "Xhelp" ] && echo -e "Usage:\n\n    $rcommand\n\nor:\n\n    $rcommand full  (to update all non-executables - may overwrite your configs!)\n" && exit 0
[ "X$1" == "Xfull" ] && fullupgrade=true || fullupgrade=false
[ "X$1" == "Xunnew" ] && unnew=true || unnew=false

find "$M_TEMP"/.update -type d -name .git | xargs rm -rf
echo "Checking directories:"
for script in `find "$M_TEMP/.update" -mindepth 1 -type d`; do
  sc=`echo "$script" | sed "s|$M_TEMP/.update/||"`
  echo -n "$sc ... "
  if [ ! -e "$M_ROOT/$sc" ]; then
    echo -n "copying ... "
    cp -r "$script" "$M_ROOT/$sc" && chown -R `id -un`:`id -gn` "$M_ROOT/$sc" && echo "OK"
  fi
done
echo "Checking files:"
for script in `find "$M_TEMP/.update" -type f`; do
  sc=`echo "$script" | sed "s|$M_TEMP/.update/||"`
  echo -n " -- $sc ... "
  if [ -x "$M_ROOT/$sc" ]; then
    if [ "$script" -nt "$M_ROOT/$sc" ]; then
      cp "$script" "$M_ROOT/$sc" && chown `id -un`:`id -gn` "$M_ROOT/$sc" && echo "OK"
    else
      echo "This file is older than the local one. Not updated"
    fi
  elif [ ! -e "$M_ROOT/$sc" ]; then
    [ "${sc##*/}" == "setup.done" ] && continue
    echo -n "new file. Copying ... "
    cp "$script" "$M_ROOT/$sc" && chown `id -un`:`id -gn` "$oldscript" && echo "OK"
  elif [ "$script" -nt "$M_ROOT/$sc" ]; then
    echo -n "this file is newer than the local one; saving as ${sc}.new, please check the differences manually ... "
    cp "$script" "$M_ROOT/${sc}.new" && chown `id -un`:`id -gn` "$M_ROOT/${sc}.new" && echo "OK"
  else
    echo "not copying this file"
  fi
done
echo "Checking symlinks:"
for symlink in `find "$M_TEMP/.update" -type l`; do
  sl=`echo "$symlink" | sed "s|$M_TEMP/.update/||"`
  echo -n " -- $sl ... "
  cp -P "$symlink" "$M_ROOT/$sl" && chown `id -un`:`id -gn` "$M_ROOT/$sl" && echo "OK"
done
printf "Removing .new files that have zero difference with the local files ..."
for newfile in `find "$M_ROOT/" -name "*.new"` ; do
  if [ `diff $newfile ${newfile%.new} | wc -l` -eq 0 ] ; then
    rm -f $newfile && touch ${newfile%.new} && printf "."
  fi
done && echo "OK"
echo -n "Running actions specific for this upgrade ... "
if [ -f "$M_ROOT/this_upgrade_actions" ] ; then
  echo -n "found ... "
  thists=`head -1 "$M_ROOT/this_upgrade_actions" | sed 's|#||;s|[[:space:]]||'`
  if [[ $thists =~ [^[0-9]] ]] ; then
    echo "Timestamp not found or has wrong format, 1st line of the script must be: # <epoch>"
  else
    [ -f "$M_ROOT/upgrade.log" ] || echo 0 > "$M_ROOT/upgrade.log"
    lastts=`tail -1 "$M_ROOT/upgrade.log"`
    if [[ $lastts =~ [^[0-9]] ]] ; then
      echo "Unable to find last upgrade time, using file VERSION creation time"
      lastts=$(date -d "$(`which stat` -c %y VERSION | cut -d'.' -f1)" +"%s")
    fi
    echo "timestamps: now $timeindex, last $lastts, this $thists, git $gitts" >> "$M_ROOT/upgrade_actions.log"
    if [ `expr $thists \> $lastts` -eq 1 ] ; then
      echo "`date` Running this upgrade specific actions script" >> "$M_ROOT/upgrade_actions.log"
      
      bash "$M_ROOT/this_upgrade_actions" "$rpath" 2>&1 | tee -a "$M_ROOT/upgrade_actions.log"
      if [[ $? -eq 0 ]] ; then
        echo "OK"
        install -d "$M_ROOT/upgrade_actions"
        mv "$M_ROOT/this_upgrade_actions" "$M_ROOT/upgrade_actions/${thists}.success"
      else
        install -d "$M_ROOT/upgrade_actions"
        mv "$M_ROOT/this_upgrade_actions" "$M_ROOT/upgrade_actions/${thists}.failed"
        echo "Error. Check the script: this_upgrade_actions.failed"
      fi
    else
      echo "outdated, not applying"
    fi
  fi
  rm -f "$M_ROOT/this_upgrade_actions"
else
  echo "not found"
fi
rm -rf "$M_TEMP"/.update/
echo $timeindex >> "$M_ROOT/upgrade.log"

if $unnew ; then
  find "$M_ROOT" -name "*.new" | grep -vE "\.conf\.|/conf/|\.list\." | while read updated ; do "$M_ROOT"/helpers/unnew $updated ; done
fi
if $fullupgrade ; then
  find "$M_ROOT" -name "*.new" | while read updated ; do "$M_ROOT"/helpers/unnew $updated ; done
else
  echo -e "Showing files that are not updated and saved with the .new extension added. Note that configuration files are not shown! Use this to find all files if you wish:\n\nfind \"$M_ROOT\" -name \"*.new\"\n\nUse the unnew helper script to overwrite specific files with their new version:\n\nunnew </path/to/file1.new /path/to/file2.new ...>\n\n"
  find "$M_ROOT" -name "*.new" | grep -vE "\.conf\.|/conf/|\.list\.|index\.html"
fi

