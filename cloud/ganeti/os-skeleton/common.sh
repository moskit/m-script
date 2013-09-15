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

AWK=`which awk 2>/dev/null || echo "awk utility not found!"`
DUMP=`which dump 2>/dev/null || echo "dump utility not found!"`
LOSETUP=`which losetup 2>/dev/null || echo "losetup utility not found!"`
KPARTX=`which kpartx 2>/dev/null || echo "kpartx utility not found!"`
SFDISK=`which sfdisk 2>/dev/null || echo "sfdisk utility not found!"`
QEMU_IMG=`which qemu-img 2>/dev/null || echo "qemu-img utility not found!"`
MKDIR_P="`which install 2>/dev/null` -d"

[ -z "$SFDISK" ] && exit 1
[ -z "$KPARTX" ] && exit 1

if [ -z "$OS_API_VERSION" -o "$OS_API_VERSION" = "5" ]; then
  DEFAULT_PARTITION_STYLE="none"
else
  DEFAULT_PARTITION_STYLE="msdos"
fi
: ${PARTITION_STYLE:=$DEFAULT_PARTITION_STYLE}

M_ROOT=%{M_ROOT}%

[ -z "$M_ROOT" ] && echo "M_ROOT environment variable is not defined" && exit 1
LOG="$M_ROOT/logs/cloud.log"
[ -z "$M_TEMP" ] && source "$M_ROOT/conf/mon.conf"
[ -z "$M_TEMP" ] && M_TEMP="/tmp/m_script"
M_TEMP="$M_TEMP/cloud/ganeti"

source "$M_TEMP/vars"
[ -z "$VARIANTS_DIR" ] && echo "VARIANTS_DIR not defined" && exit 1

CLEANUP=( )

log_error() {
  echo "$@" >>"$LOG"
}

debug() {
    [ "$IMAGE_DEBUG" == "1" -o "$IMAGE_DEBUG" == "yes" ] &&  $@ || :
}

get_api10_arguments() {
  if [ -z "$INSTANCE_NAME" -o -z "$HYPERVISOR" -o -z "$DISK_COUNT" ]; then
    log_error "Missing OS API Variable:"
    log_error "(INSTANCE_NAME HYPERVISOR or DISK_COUNT)"
    exit 1
  fi
  instance=$INSTANCE_NAME
  if [ $DISK_COUNT -lt 1 -o -z "$DISK_0_PATH" ]; then
    log_error "At least one disk is needed"
    exit 1
  fi
  if [ "$SCRIPT_NAME" = "export" ]; then
    if [ -z "$EXPORT_DEVICE" ]; then
      log_error "Missing OS API Variable EXPORT_DEVICE"
    fi
    blockdev=$EXPORT_DEVICE
  elif [ "$SCRIPT_NAME" = "import" ]; then
    if [ -z "$IMPORT_DEVICE" ]; then
       log_error "Missing OS API Variable IMPORT_DEVICE"
    fi
    blockdev=$IMPORT_DEVICE
  else
    blockdev=$DISK_0_PATH
  fi
  if [ "$SCRIPT_NAME" = "rename" -a -z "$OLD_INSTANCE_NAME" ]; then
    log_error "Missing OS API Variable OLD_INSTANCE_NAME"
  fi
  old_name=$OLD_INSTANCE_NAME
}

format_disk0() {
  $SFDISK -H 255 -S 63 --quiet --Linux "$1" <<EOF
0,,L,*
EOF
}

mkfs_disk0() {
  local mkfs="mkfs.${FILESYSTEM}"
  # Format /
  $mkfs -Fq -L / $root_dev > /dev/null
  # During reinstalls, ext4 needs a little time after a mkfs so add it here
  # and also run a sync to be sure.
  sync
  sleep 2
}

mount_disk0() {
  local target=$1
  mount $root_dev $target
  CLEANUP+=("umount $target")
  # sync the file systems before unmounting to ensure everything is flushed
  # out
  CLEANUP+=("sync")
}

map_disk0() {
  blockdev="$1"
  filesystem_dev_base=`$KPARTX -l -p- $blockdev | grep -m 1 -- "-1.*$blockdev" | $AWK '{print $1}'`
  if [ -z "$filesystem_dev_base" ]; then
    log_error "Cannot interpret kpartx output and get partition mapping"
    exit 1
  fi
  $KPARTX -a -p- $blockdev > /dev/null
  filesystem_dev="/dev/mapper/$filesystem_dev_base"
  if [ ! -b "$filesystem_dev" ]; then
    log_error "Can't find kpartx mapped partition: $filesystem_dev"
    exit 1
  fi
  echo "$filesystem_dev"
}

unmap_disk0() {
  $KPARTX -d -p- $1
}

setup_console() {
    local target="$1"
    if [ -z "$target" ] ; then
        log_error "target not set for setup_console"
        exit 1
    fi
    # Upstart is on this system, so do this instead
    if [ -e "$target/etc/event.d/tty1" ] ; then
        cat "$target/etc/event.d/tty1" | sed -re 's/tty1/ttyS0/' \
            > "$target/etc/event.d/ttyS0"
        return
    fi
    # upstart in karmic and newer
    if [ -e "$target/etc/init/tty1.conf" ] ; then
        cat "$target/etc/init/tty1.conf" | \
        sed -re 's/^exec.*/exec \/sbin\/getty -L 115200 ttyS0 vt102/' \
            > "$target/etc/init/ttyS0.conf"
        sed -ie 's/tty1/ttyS0/g' "$target/etc/init/ttyS0.conf"
        return
    fi

    case $OPERATING_SYSTEM in
        gentoo)
            sed -i -e 's/.*ttyS0.*/s0:12345:respawn:\/sbin\/agetty 115200 ttyS0 vt100/' \
                "$target/etc/inittab"
            ;;
        centos)
            echo "s0:12345:respawn:/sbin/agetty 115200 ttyS0 vt100" >> \
                "$target/etc/inittab"
            ;;
        debian|ubuntu)
            sed -i -e 's/.*T0.*/T0:23:respawn:\/sbin\/getty -L ttyS0 115200 vt100/' \
                "$target/etc/inittab"
            ;;
        *)
            echo "No support for your OS in instance-image, skipping..."
            ;;
    esac
}

cleanup() {
  if [ ${#CLEANUP[*]} -gt 0 ]; then
    LAST_ELEMENT=$((${#CLEANUP[*]}-1))
    REVERSE_INDEXES=$(seq $LAST_ELEMENT -1 0)
    for i in $REVERSE_INDEXES; do
      ${CLEANUP[$i]}
    done
  fi
}

trap cleanup EXIT

SCRIPT_NAME=$(basename $0)
KERNEL_PATH="$INSTANCE_HV_kernel_path"

if [ -f /sbin/blkid -a -x /sbin/blkid ]; then
  VOL_ID="/sbin/blkid -o value -s UUID"
  VOL_TYPE="/sbin/blkid -o value -s TYPE"
else
  for dir in /lib/udev /sbin; do
    if [ -f $dir/vol_id -a -x $dir/vol_id ]; then
      VOL_ID="$dir/vol_id -u"
      VOL_TYPE="$dir/vol_id -t"
    fi
  done
fi

if [ -z "$VOL_ID" ]; then
  log_error "vol_id or blkid not found, please install udev or util-linux"
  exit 1
fi

get_api10_arguments


