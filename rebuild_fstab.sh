#!/bin/bash

rebuilt_fstab="/etc/fstab.$(date +%m%d%Y)"
blkid_tmp="/tmp/blkid.tmp" ; blkid > ${blkid_tmp}

disk_uuid="$(mdadm -D /dev/md126 | awk '/UUID/ {print $3}')"; \
echo "# WARNING:
# MODIFICATIONS TO THIS FILE MAY RESULT IN DATA UNAVAILABILITY!
#
# This file is managed by system and Atmos software automatically.
# Please DO NOT TOUCH this file manually.


devpts  /dev/pts          devpts  mode=0620,gid=5 0 0
proc    /proc             proc    defaults        0 0
sysfs   /sys              sysfs   noauto          0 0
debugfs /sys/kernel/debug debugfs noauto          0 0
usbfs   /proc/bus/usb     usbfs   noauto          0 0
tmpfs   /run              tmpfs   noauto          0 0
/dev/AtmosVG/LVRoot / xfs defaults 1 1
/dev/AtmosVG/LVroot2 /root2 xfs defaults 1 2
/dev/AtmosVG/LVvar /var xfs defaults 1 2
/dev/disk/by-id/md-uuid-${disk_uuid}-part1 /boot ext3 defaults 1 2
/dev/AtmosVG/LVSwap swap swap defaults 0 0
none    /cgroup    cgroup    defaults    0 0" > ${rebuilt_fstab}


for mds_uuid in $(ls /atmos/* -d1 | cut -d'/' -f3) ; do 
    [[ $(grep -q "${mds_uuid}" "${blkid_tmp}" | echo $?) ]] && echo "UUID=${mds_uuid} /atmos/${mds_uuid} xfs inode64,barrier,noatime,nodiratime" >> ${rebuilt_fstab};done

for ss_uuid in $(ls /mauiss-disks/ss-* -d1 | cut -d'/' -f3 | sed 's/ss-//g'); do
    [[ $(grep -q "${ss_uuid}" "${blkid_tmp}" | echo $?) ]] && echo "UUID=${ss_uuid} /mauiss-disks/ss-${ss_uuid} xfs inode64,barrier,noatime,nodiratime" >> ${rebuilt_fstab};done

/bin/cp -fp ${rebuilt_fstab} /etc/fstab 
awk '/atmos/{m++};/ss/{n++};END{printf "\nMDS Disks: %s\n SS Disks: %s\n",m,n}' /etc/fstab
