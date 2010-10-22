#/bin/bash
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
    mv /tmp/m_script.$$/m_script*/* /tmp/m_script/.update
  fi
else
  $GIT clone git://igorsimonov.com/m_script /tmp/m_script/.update
fi
for script in `find "${rpath}/../" -type f -name "*.sh" -o -name "*.run"`; do
  printf "${script##*/} ... "
  updated=`echo "$script" | sed "s|${rpath}/../|/tmp/m_script/.update/|"`
  if [ -e "${updated}" ]; then
    if [ "${updated}" -nt "$script" ]; then
      cp "${updated}" "$script" && chown `id -un`:`id -gn` "$script" && echo "OK"
    else
      echo "This file either dont exist in update or is older than the local one. Not updated"
    fi
  fi
done
rm -rf /tmp/m_script/.update/

