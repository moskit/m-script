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

rm -rf /tmp/m_script/.update/
[ -h $0 ] && xcommand=`readlink $0` || xcommand=$0
rcommand=${xcommand##*/}
rpath=${xcommand%/*}
#*/ (this is needed to fool vi syntax highlighting)
GIT=`which git`
WGET=`which wget`
if [ "X$GIT" == "X" ]; then
  echo "Git not found! Fetching tarball..."
  if [ "X$WGET" == "X" ]; then
    echo "Wget not found! Giving up, sorry..."
    exit 1
  else
    install -d /tmp/m_script/.update /tmp/m_script.$$
    $WGET -nH -P /tmp/m_script http://igorsimonov.com/m_script.latest.tar.gz
    `which tar` -xzf /tmp/m_script/m_script.latest.tar.gz -C /tmp/m_script.$$
    rm -f /tmp/m_script/m_script.latest.tar.gz
    mv /tmp/m_script.$$/m/* /tmp/m_script/.update
  fi
else
  $GIT clone git://igorsimonov.com/m_script /tmp/m_script/.update
fi
find /tmp/m_script/.update -type d -name .git | xargs rm -rf
echo "Checking directories:"
for script in `find "/tmp/m_script/.update" -type d`; do
  printf "${script##*/} ... "
  oldscript=`echo "$script" | sed "s|/tmp/m_script/.update/|${rpath}/../|"`
  if [ ! -e "${oldscript}" ]; then
    printf "copying ... "
    cp -r "${script}" "$oldscript" && chown -R `id -un`:`id -gn` "$oldscript" && echo "OK"
  fi
done
echo "Checking files:"
for script in `find "/tmp/m_script/.update" -type f`; do
  printf " -- ${script##*/} ... "
  oldscript=`echo "$script" | sed "s|/tmp/m_script/.update/|${rpath}/../|"`
  if [ -x "${oldscript}" ]; then
    if [ "${script}" -nt "$oldscript" ]; then
      cp "${script}" "$oldscript" && chown `id -un`:`id -gn` "$oldscript" && echo "OK"
    else
      echo "This file is older than the local one. Not updated"
    fi
  elif [ ! -e "${oldscript}" ]; then
    printf "new file. Copying ... "
    cp "${script}" "$oldscript" && chown `id -un`:`id -gn` "$oldscript" && echo "OK"
  elif [ "${script}" -nt "$oldscript" ]; then
    printf "this file is newer than the local one; saving as ${oldscript}.new, please check the differences manually ... "
    cp "${script}" "${oldscript}.new" && chown `id -un`:`id -gn` "${oldscript}.new" && echo "OK"
  else
    echo "not copying this file"
  fi
done
printf "Removing .new files that have zero difference with the local files ..."
for newfile in `find ${rpath}/../ -name "*.new"` ; do
  if [ `diff $newfile ${newfile%.new} | wc -l` -eq 0 ] ; then
    rm -f $newfile && touch ${newfile%.new} && printf "."
  fi
done && echo "OK"
printf "Running actions specific for this upgrade ... "
if [ -f "${rpath}/../this_upgrade_actions" ] ; then
  printf "found ... "
  echo "Running this upgrade specific actions script" >> ${rpath}/../upgrade.log
  bash "${rpath}/../this_upgrade_actions" >> ${rpath}/../upgrade.log
  if [[ $? -eq 0 ]] ; then
    echo "OK"
    rm -f "${rpath}/../this_upgrade_actions"
  else
    mv "${rpath}/../this_upgrade_actions" "${rpath}/../this_upgrade_actions.failed"
    echo "Error. Check the script: this_upgrade_actions.failed"
  fi
else
  echo "not found"
fi
rm -rf /tmp/m_script/.update/

