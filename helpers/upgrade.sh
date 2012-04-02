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
rpath=$(readlink -m "$BASH_SOURCE")
rcommand=${rpath##*/}
rpath=${rpath%/*}
#*/
timeindex=`date -u +"%s"`
GIT=`which git 2>/dev/null`
WGET=`which wget 2>/dev/null`
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
  gitts=$(cd /tmp/m_script/.update && $GIT log -n1 --format=%at | tail -1)
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
  echo -n " -- ${script##*/} ... "
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
echo "Checking symlinks:"
for symlink in `find "/tmp/m_script/.update" -type l`; do
  echo -n " -- ${symlink##*/} ... "
  oldsymlink=`echo "$symlink" | sed "s|/tmp/m_script/.update/|${rpath}/../|"`
  cp --preserve=all --update "${symlink}" "$oldsymlink" && chown `id -un`:`id -gn` "$oldsymlink" && echo "OK"
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
  thists=`head -1 "${rpath}/../this_upgrade_actions" | sed 's|#||;s|[[:space:]]||'`
  if [[ $thists =~ [^[0-9]] ]] ; then
    echo "Timestamp not found or has wrong format, 1st line of the script must be: # <epoch>"
  else
    lastts=`tail -1 "${rpath}/../upgrade.log"`
    if [[ $lastts =~ [^[0-9]] ]] ; then
      echo "Unable to find last upgrade time, using file VERSION creation time"
      lastts=$(date -d "$(`which stat` -c %y VERSION | cut -d'.' -f1)" +"%s")
    fi
    echo "timestamps: now $timeindex, last $lastts, this $thists, git $gitts" >> "${rpath}/../upgrade_actions.log"
    if [ `expr $thists \> $lastts` -eq 1 ] ; then
      echo "`date` Running this upgrade specific actions script" >> "${rpath}/../upgrade_actions.log"
      
      bash "${rpath}/../this_upgrade_actions" ${rpath} >> "${rpath}/../upgrade_actions.log"
      if [[ $? -eq 0 ]] ; then
        echo "OK"
        install -d "${rpath}/../upgrade_actions"
        mv "${rpath}/../this_upgrade_actions" "${rpath}/../upgrade_actions/${thists}.success"
      else
        install -d "${rpath}/../upgrade_actions"
        mv "${rpath}/../this_upgrade_actions" "${rpath}/../upgrade_actions/${thists}.failed"
        echo "Error. Check the script: this_upgrade_actions.failed"
      fi
    else
      echo "outdated, not applying"
    fi
  fi
  rm -f "${rpath}/../this_upgrade_actions"
else
  echo "not found"
fi
rm -rf /tmp/m_script/.update/
echo $timeindex >> "${rpath}/../upgrade.log"
