#!/bin/bash

parted -s /dev/sdc mklabel msdos mkpart primary ext4 2048s 100% set 1 lvm on
fdisk -uc -l /dev/sdc > /tmp/create-sdc-check.log

parted -s /dev/sdd mklabel msdos mkpart primary ext4 2048s 100% set 1 lvm on
fdisk -uc -l /dev/sdd > /tmp/create-sdd-check.log

parted -s /dev/sde mklabel msdos mkpart primary ext4 2048s 100% set 1 lvm on
fdisk -uc -l /dev/sde > /tmp/create-sde-check.log

parted -s /dev/sdf mklabel msdos mkpart primary ext4 2048s 100% set 1 lvm on
fdisk -uc -l /dev/sdf > /tmp/create-sdf-check.log

yum -y install lvm2
which pvcreate vgcreate lvcreate pvdisplay vgdisplay lvdisplay > /tmp/install-lvm2-check.log

pvcreate /dev/sdc1 /dev/sdd1 /dev/sde1 /dev/sdf1
pvdisplay > /tmp/pvcreate-check.log

vgcreate -v vg1 /dev/sdc1 /dev/sdd1 /dev/sde1 /dev/sdf1
vgdisplay > /tmp/vgcreate-check.log

lvcreate --extents 100%VG --name lv1 --stripes 4 --stripesize 64 vg1
lvdisplay > /tmp/lvdisplay-check.log

yum -y install xfsprogs
which mkfs.xfs > /tmp/install-xfsprogs-check.log

mkfs.xfs /dev/vg1/lv1

blkid /dev/vg1/lv1 | awk '{print $2}' | sed 's/\"//g' | sed 's/$/ \/u02      xfs     defaults,nobarrier  0 2/' >> /etc/fstab
cat -n /etc/fstab > /tmp/add-u02-to-fstab-check.log

mount -a
df -h -T -P -x tmpfs -x devtmpfs > /tmp/mount-u02-check.log

lsblk -stf > /tmp/lsblk-report.log

