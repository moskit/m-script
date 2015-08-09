#!/bin/bash

# Copyright (C) 2007, 2008, 2009 Google Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301, USA.

###
# This file contains functions extracted from common.sh file which is part of
# Ganeti because they are useful for helpers, plus some additions.
###

CLEANUP=( )

log_error() {
  echo "$@" >&2
}

map_disk0() {
  [ -z "$1" ] && log_error "argument to map_disk0 is empty" && return 1
  blockdev="$1"
  filesystem_dev_base=`kpartx -l -p- $blockdev | grep -m 1 -- "-1.*$blockdev" | awk '{print $1}'`
  if [ -z "$filesystem_dev_base" ]; then
    log_error "Cannot interpret kpartx output and get partition mapping using command:"
    log_error "kpartx -l -p- $blockdev | grep -m 1 -- \"-1.*$blockdev\" | awk '{print $1}'"
    exit 1
  fi
  kpartx -a -p- $blockdev > /dev/null
  filesystem_dev="/dev/mapper/$filesystem_dev_base"
  if [ ! -b "$filesystem_dev" ]; then
    `which dmsetup` mknodes
  fi
  if [ ! -b "$filesystem_dev" ]; then
    log_error "Can't find kpartx mapped partition: $filesystem_dev"
    exit 1
  fi
  echo "$filesystem_dev"
}

unmap_disk0() {
  kpartx -d -p- $1
}

mount_disk0() {
  local target=$1
  mount $filesystem_dev $target
  CLEANUP+=("umount $target")
  # sync the file systems before unmounting to ensure everything is flushed
  # out
  CLEANUP+=("sync")
}

cleanup() {
  if [ ${#CLEANUP[*]} -gt 0 ]; then
    LAST_ELEMENT=$((${#CLEANUP[*]}-1))
    REVERSE_INDEXES=$(seq ${LAST_ELEMENT} -1 0)
    errflag=false
    for i in $REVERSE_INDEXES; do
      if $errflag ; then
        log_error "Cleanup operation not executed: ${CLEANUP[$i]}"
      else
        ${CLEANUP[$i]}
        if [ $? -ne 0 ]; then
          log_error "Cleanup operation failed: ${CLEANUP[$i]}"
          errflag=true
        fi
      fi
    done
  fi
}

fix_routes() {
  # stop/staring an instance leads to that instance having lost its route
  # 
  IPR2=`which ip 2>/dev/null`
  GNTC=`which gnt-cluster 2>/dev/null`
  routingtable=`$GNTC info | grep ' link:' | cut -sd':' -f2 | tr -d ' '`
  $IPR2 route show table $routingtable | cut -sd' ' -f1,2,3 | while read route ; do ip route add $route ; done
}
