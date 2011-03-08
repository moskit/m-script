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
currtime=`date +"%s"`

possible_options="keep cluster ami state filter noupdate help region"
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

if [ -n "$help" ] ; then
  case $help in 
    cluster)
      echo "Usage: --cluster=<cluster name>"
      echo "  Shows only instances within this cluster"
      echo "  (tagged with \"cluster=<cluster name>\")"
    ;;
    ami)
      echo "Usage: --ami=<ami_id>"
      echo "  Shows only instances with this AMI ID"
    ;;
    state)
      echo "Usage: --state=<state>"
      echo "  Shows only instances in this state"
      echo "  e.g. --state=running"
    ;;
    filter)
      cat << "EOF"
Usage: --filter=<var1,var2,var3>

  Shows the defined variables only, like this:
  
  var1 var2 var3
  
  for each instance according to other options, e.g. to get intenal and external
  IPs of running instances, use:
  
  show_servers.sh --state=running --filter=inIP,extIP
  
  Possible variables are:
  
    iID
    inIP
    extIP
    iami
    istate
    izone
    ikeypair
    istarted
    SG
    icluster
    itag
    bdev
    bID
    bstarted
    iaki
    iari

EOF
    
    ;;
    noupdate)
      echo "Usage: --noupdate"
      echo "doesn't query AWS, uses the raw data of the previous query instead"
    ;;
    *)
      echo "Use help=option"
      echo "Possible options are: ${possible_options}"
    ;;
  esac
  exit 0
fi

source ${rpath}/../conf/cloud.conf
for var in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY EC2_TOOLS_BIN_PATH JAVA_HOME EC2_HOME EC2_PRIVATE_KEY EC2_CERT EC2_REGION EC2_AK ; do
  [ -z "`eval echo \\$\$var`" ] && echo "$var is not defined! Define it in conf/cloud.conf please." && exit 1
done
PATH="${EC2_TOOLS_BIN_PATH}:${PATH}"
export JAVA_HOME EC2_HOME EC2_PRIVATE_KEY EC2_CERT AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY EC2_REGION PATH

TMPDIR=/tmp/m_script/cloud
install -d $TMPDIR
[ -n "$noupdate" ] && noupdate="--noupdate"
[ -n "$region" ] && region="--region=$region"
[ -n "$cluster" ] && cluster="--cluster=$cluster"
[ -n "$ami" ] && ami="--ami=$ami"
[ -n "$state" ] && state="--state=$state"

${rpath}/show_servers.sh $noupdate $region $cluster $ami $state --filter=bID > $TMPDIR/volumes.list
if [ -n "$keep" ] ; then
  outdated=`date -d "$currtime - $keep days" +"%s"`
  ec2-describe-snapshots $region > $TMPDIR/snapshots.list
  for ebs in `cat $TMPDIR/volumes.list` ; do
    cat $TMPDIR/snapshots.list | grep " $ebs " | while read snap ; do
      snapID=`echo $snap | awk '{print $2}'`
      snaptime=`echo $snap | awk '{print $5}' | sed 's|T| |'`
      if [[ $snaptime -lt $outdated ]] ; then
        ec2-delete-snapshot $snapID
      fi
    done
    ec2-create-snapshot $ebs
  done
else
  for ebs in `cat $TMPDIR/volumes.list` ; do
    ec2-create-snapshot $ebs
  done
fi

