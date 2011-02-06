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

possible_options="name"
necessary_options="name"
[ "X$*" == "X" ] && echo "Can't run without options. Possible options are: ${possible_options}" && exit 1
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
  if [[ found -ne 1 ]]; then 
    echo "Unknown option: $s_optname"
    exit 1
  fi
done
found=0

for option in `echo $necessary_options | sed 's/,//g'`; do
  [ "X$(eval echo \$$option)" == "X" ] && missing_options="${missing_options}, --${option}" && found=1
done
if [[ found -eq 1 ]]; then
  missing_options=${missing_options#*,}
  echo "Necessary options: ${missing_options} not found"
  exit 1
fi

source ${rpath}/../conf/cloud.conf
PATH="${EC2_TOOLS_BIN_PATH}:${PATH}"
TMPDIR=/tmp/m_script/cloud
install -d $TMPDIR
install -d $SAVED_FILES_PATH
EXCLUDE="/usr/portage/distfiles"
for E in $EXCLUDE
do
  [ -e $E ] || ex=0
done
[ "X$ex" != "X0" ] && EXCLUDE="-e $EXCLUDE" || EXCLUDE=""
[ "X$name" == "X" ] && echo "Name needed" && exit 1
[ "X`which ec2-bundle-vol`" == "X" ] && echo "AMI Tools needed" && exit 1
[ "X`which ec2-register`" == "X" ] && echo "API Tools needed" && exit 1
#arch=i386

rm -rf ${SAVED_FILES_PATH%/}/image* 2>/dev/null
ec2-bundle-vol -r $arch --prefix "${name}" -d ${SAVED_FILES_PATH} --user $EC2_USERID $EXCLUDE -k $EC2_PRIVATE_KEY -c $EC2_CERT
ec2-upload-bundle -b "${BUCKETNAME}" -m "${SAVED_FILES_PATH%/}/${name}".manifest.xml -a $AWS_ACCESS_KEY_ID -s $AWS_SECRET_ACCESS_KEY
ec2-register --region $EC2_REGION "${BUCKETNAME}/${name}".manifest.xml -n "${name}"

