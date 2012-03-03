#!/bin/bash
# Copyright (C) 2008-2011 Igor Simonov (me@igorsimonov.com)
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


rcommand=${0##*/}
rpath=${0%/*}
#*/ (this is needed to fix vi syntax highlighting)
SVN=`which svn 2>/dev/null`
[ "X$SVN" == "X" ] && echo "No Subversion found, exiting" && exit 1
possible_options="cluster help repository"
necessary_options=""
#[ "X$*" == "X" ] && echo "Can't run without options. Possible options are: ${possible_options}" && exit 1
for s_option in "${@}"
do
  found=0
  case ${s_option} in
  --*=*)
    s_optname=`expr "X$s_option" : 'X[^-]*-*\([^=]*\)'`  
    s_optarg=`expr "X$s_option" : 'X[^=]*=\(.*\)'` 
    ;;
  --*)
    s_optname=`expr "X$s_option" : 'X[^-]*-*\([^=]*\)'`    
    s_optarg='yes' 
    ;;
  *=*)
    echo "Wrong syntax: options must start with a double dash"
    exit 1
    ;;
  *)
    s_param=${s_option}
    s_optname=''
    s_optarg=''
    ;;
  esac
  for option in `echo $possible_options | sed 's/,//g'`; do 
    [ "X$s_optname" == "X$option" ] && eval "$option=${s_optarg}" && found=1
  done
  [ "X$s_option" == "X$s_param" ] && found=1
  if [[ $found -ne 1 ]]; then 
    echo "Unknown option: $s_optname"
    exit 1
  fi
done
if [ "X$help" == "Xyes" ] ; then
  echo "Usage: ${0##*/} <options>"
  echo
  echo "  This helper script checks if repositories listed in conf/deployment.conf have been updated. It is used by cloud/deploy.sh script (--check option), but can be used directly. It returns repository name and status, which is either 0 if no updates found or revision number if repository has been updated."
  echo
  echo "  Options:"
  echo
  echo "  --cluster=clustername    - checks repositories for this cluster only"
  echo "  --repository=name        - checks this repository only"
  exit 0
fi

TMPDIR=/tmp/m_script/cloud
install -d $TMPDIR

[ -f "${rpath}/../repos.revisions" ] || touch "${rpath}/../repos.revisions"

IFS1=$IFS
IFS='
'
for repo in `cat ${rpath}/../conf/repos.list|grep -v ^$|grep -v ^#|grep -v ^[[:space:]]*#` ; do
  reponame=`echo "${repo}" | cut -d'|' -f1`
  if [ -n "$repository" ] ; then
    if [ "$repository" != "$reponame" ] ; then
      continue
    fi
  fi
  repocluster=`echo "${repo}" | cut -d'|' -f6`
  if [ -n "$cluster" ] ; then
    if [ "$cluster" != "$repocluster" ] ; then
      continue
    fi
  fi
  # only svn is supported so far
  repourl=`echo "${repo}" | cut -d'|' -f3`
  repouser=`echo "${repo}" | cut -d'|' -f4`
  [ "X$repouser" == "X" ] || repouser="--username=$repouser"
  repopass=`echo "${repo}" | cut -d'|' -f5`
  [ "X$repopass" == "X" ] || repopass="--password=$repopass"
  prevrev=`cat "${rpath}/../repos.revisions" | grep "^$reponame" | cut -d' ' -f2 | sed 's|[^0-9]||g'`
  [ -n "$prevrev" ] || prevrev=0
  currev=`$SVN $repouser $repopass --non-interactive info "$repourl" | grep '^Last Changed Rev' | cut -d':' -f2 | sed 's|[^0-9]||g'`
  if [[ $prevrev =~ [0-9] ]] && [[ $currev =~ [0-9] ]] ; then
    if [ $currev -gt $prevrev ] ; then
      sed -i -e "/^$reponame/d" ${rpath}/../repos.revisions
      echo "$reponame $currev" | tee -a ${rpath}/../repos.revisions
    else
      echo "$reponame 0"
    fi
  else
    echo "Something went wrong:"
    echo "Previous revision for $reponame = $prevrev"
    echo "Current revision for $reponame = $currev"
    exit 1
  fi
  unset repouser repopass prevrev currev reponame repourl
done
unset cluster repository
IFS=$IFS1




