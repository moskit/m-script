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

print_server() {
  local line1
  local line2
  local line3
  local line4
  local line5
  local line6
  local line7
  IFS1=$IFS
  IFS='|'
  if [ "X$filter" == "X" ] ; then
    for s in `echo "${1}"` ; do
      a=`echo "$s" | awk -F'::' '{print $1}'`
      b=`echo "$s" | awk -F'::' '{print $2}'`
      case $a in
        iID)
          line1="Server $b $line1"
          ;;
        inIP)
          line2="IP: internal $b $line2"
          ;;
        extIP)
          line2="$line2 external $b"
          ;;
        iami)
          [ -n "$ami" ] && [ "X$ami" != "X$b" ] && IFS=$IFS1 && return 0
          line5="AMI: $b $line5"
          ;;
        istate)
          [ -n "$state" ] && [ "X$state" != "X$b" ] && IFS=$IFS1 && return 0
          line4="State: $b $line4"
          ;;
        izone)
          line3="Zone: $b $line3"
          ;;
        ikeypair)
          line3="$line3 Key: $b"
          ;;
        istarted)
          line4="$line4 since $b"
          ;;
        SG)
          line1="${line1}Security group: $b"
          ;;
        icluster)
          [ -n "$cluster" ] && [ "X$cluster" != "X$b" ] && IFS=$IFS1 && return 0
          line1="$line1 cluster: $b"
          ;;
        itag)
          line6="$line6 $b"
          ;;
        bdev)
          line7="EBS device: $b $line7"
          ;;
        bID)
          line7="$line7 ID: $b"
          ;;
        bstarted)
          line7="$line7 since $b\n"
          ;;
        iaki)
          line5="$line5  AKI: $b"
          ;;
        iari)
          line5="$line5  ARI: $b"
          ;;
      esac
    done
    echo "---------------------------------------------------------------------"
    printf "${line1}\n${line2}\n${line3}\n${line4}\n${line5}\n"
    [ -n "$line6" ] && printf "${line6}\n"
    [ -n "$line7" ] && printf "${line7}\n"

  else
    for s in `echo "${1}"` ; do
      a=`echo "$s" | awk -F'::' '{print $1}'`
      b=`echo "$s" | awk -F'::' '{print $2}'`
      filter=`echo $filter | sed 's_,_|_g'`
      for s in $filter ; do
        [ "X$a" == "X$s" ] && printf "$b "
      done
      printf "\n"
    done
  fi
  IFS=$IFS1
  return 0
}

parse_server() {
  if [[ ${1} =~ ^RESERVATION ]] ; then
    printf "SG::`echo ${1} | awk -F'|' '{print $4}'`|"
  fi
  if [[ ${1} =~ ^INSTANCE ]] ; then
    iID=`echo ${1} | awk -F'|' '{print $2}'`
    inIP=`echo ${1} | awk -F'|' '{print $18}'`
    extIP=`echo ${1} | awk -F'|' '{print $17}'`
    iami=`echo ${1} | awk -F'|' '{print $3}'`
    istate=`echo ${1} | awk -F'|' '{print $6}'`
    ikeypair=`echo ${1} | awk -F'|' '{print $7}'`
    isize=`echo ${1} | awk -F'|' '{print $10}'`
    istarted=`echo ${1} | awk -F'|' '{print $11}'`
    izone=`echo ${1} | awk -F'|' '{print $12}'`
    iaki=`echo ${1} | awk -F'|' '{print $13}'`
    iari=`echo ${1} | awk -F'|' '{print $14}'`
    printf "iID::$iID|iami::$iami|iaki::$iaki|iari::$iari|"
    if [ "X$istate" == "Xrunning" ] ; then
      printf "inIP::$inIP|extIP::$extIP|"
    fi
    printf "istate::$istate|istarted::$istarted|izone::$izone|ikeypair::$ikeypair|"
    
  fi
  if [[ ${1} =~ ^TAG ]] ; then
    object=`echo ${1} | awk -F'|' '{print $2}'`
    itag=`echo ${1} | awk -F'|' '{print $4}'`
    tagvalue=`echo ${1} | awk -F'|' '{print $5}'`
    if [ "X$object" == "Xinstance" ] ; then
      if [ "X$itag" == "Xcluster" ] ; then
        printf "icluster::$tagvalue|"
      else
        printf "itag::${itag}=${tagvalue}|"
      fi
    fi
  fi
  if [[ ${1} =~ ^BLOCKDEVICE ]] ; then
    bdev=`echo ${1} | awk -F'|' '{print $2}'`
    bID=`echo ${1} | awk -F'|' '{print $3}'`
    bstarted=`echo ${1} | awk -F'|' '{print $4}'`
    printf "bdev::$bdev|bID::$bID|bstarted::$bstarted|"
  fi
}

possible_options="cluster ami state filter noupdate"
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

source ${rpath}/../conf/cloud.conf
for var in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY EC2_TOOLS_BIN_PATH JAVA_HOME EC2_HOME EC2_PRIVATE_KEY EC2_CERT EC2_REGION EC2_AK ; do
  [ -z "`eval echo \\$\$var`" ] && echo "$var is not defined! Define it in conf/cloud.conf please." && exit 1
done
PATH="${EC2_TOOLS_BIN_PATH}:${PATH}"
export JAVA_HOME EC2_HOME EC2_PRIVATE_KEY EC2_CERT AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY EC2_REGION PATH

TMPDIR=/tmp/m_script/cloud
install -d $TMPDIR

if [ "X$noupdate" == "X" ] ; then
  [ "X`which ec2-describe-instances`" == "X" ] && echo "API Tools needed" && exit 1
  ${EC2_TOOLS_BIN_PATH}/ec2-describe-instances -K "$EC2_PRIVATE_KEY" -C "$EC2_CERT" --region $EC2_REGION | sed 's/\t/|/g' > $TMPDIR/ec2.servers.tmp
fi

while read SERVER
do
  if [[ $SERVER =~ ^RESERVATION ]] ; then
    [ -n "$current_server" ] && print_server "$current_server" && unset current_server
    current_server=`parse_server $SERVER` && unset newr
  else
    if [[ $SERVER =~ ^INSTANCE ]] && [ $newr ] ; then
      print_server "$current_server" && unset current_server
      current_server=`parse_server $SERVER`
      newr=1
    else
      current_server="$current_server`parse_server $SERVER`"
    fi
  fi
done<$TMPDIR/ec2.servers.tmp
print_server "$current_server"
unset newr current_server


