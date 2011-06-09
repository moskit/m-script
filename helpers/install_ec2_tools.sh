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
CURL=`which curl 2>/dev/null`
LYNX=`which lynx 2>/dev/null`
LINKS=`which links 2>/dev/null`
WGET=`which wget 2>/dev/null`
UNZIP=`which unzip 2>/dev/null`

[ -n "$WGET" ] || (echo "Wget not found!" && exit 1)
[ -n "$UNZIP" ] || (echo "Unzip not found!" && exit 1)

EC2_HOME="/opt/ec2-tools"
[ -d $EC2_HOME ] && rm -rf "$EC2_HOME/*" || install -d $EC2_HOME
$WGET "http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip"
$WGET "http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.zip"
$WGET "http://ec2-downloads.s3.amazonaws.com/ElasticLoadBalancing.zip"
fullnameapi=`unzip -Z -1 ec2-api-tools.zip | tail -1 | awk -F'/' '{print $1}'`
$UNZIP -qq -d /tmp ec2-api-tools.zip
if [ -d "/tmp/$fullnameapi" ] ; then
  cp -a /tmp/$fullnameapi/* $EC2_HOME
  rm -rf ec2-api-tools.zip
else
  echo "Unzip didn't work as expected. Keeping ec2-api-tools.zip in $PWD, please unzip it manually to $EC2_HOME"
fi
fullnameami=`unzip -Z -1 ec2-ami-tools.zip | tail -1 | awk -F'/' '{print $1}'`
$UNZIP -qq -d /tmp ec2-ami-tools.zip
if [ -d "/tmp/$fullnameami" ] ; then
  cp -a /tmp/$fullnameami/* $EC2_HOME
  rm -rf ec2-ami-tools.zip
else
  echo "Unzip didn't work as expected. Keeping ec2-ami-tools.zip in $PWD, please unzip it manually to $EC2_HOME"
fi
fullnameelb=`unzip -Z -1 ElasticLoadBalancing.zip | tail -1 | awk -F'/' '{print $1}'`
$UNZIP -qq -d /tmp ElasticLoadBalancing.zip
if [ -d "/tmp/$fullnameelb" ] ; then
  cp -a /tmp/$fullnameelb/* $EC2_HOME
  rm -rf ElasticLoadBalancing.zip
else
  echo "Unzip didn't work as expected. Keeping ec2-ami-tools.zip in $PWD, please unzip it manually to $EC2_HOME"
fi
rm -rf /tmp/$fullnameapi /tmp/$fullnameami /tmp/$fullnameelb 2>/dev/null

