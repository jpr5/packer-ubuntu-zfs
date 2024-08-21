#!/usr/bin/env bash
#
# Adapted from github:jen20/packer-ubuntu-zfs
#
# Notes:
#
#  - can't put a partition on /etc - ubuntu doesn't mount it (besides /) when booting = no sshd

set -o errexit
set -o pipefail
set -o xtrace

export DEBIAN_FRONTEND=noninteractive

# Wait for cloudinit on the surrogate to complete before making progress
while [[ ! -f /var/lib/cloud/instance/boot-finished ]]; do
    sleep 1
done

# There remains some sort of AWS EC2 / Ubuntu 24.04 kernel fuckery that is essentially a race
# condition around the partition tables being mucked with.  The end result is, sometimes shit fails
# shortly after this sgdisk, evidenced by the warning: Kernel is still using the old partition table.
# The problem will manifest at the mkfs.fat line below, saying the resource is busy (forever).  At
# which point, just cancel out of it and try again.  Not sure what the right solution is yet.

BOOT_PART=/dev/nvme1n1

partprobe -s
sgdisk -Z $BOOT_PART
partprobe -s

if test -d /sys/firmware/efi ; then
    # Partition the new root EBS volume
    sgdisk -g -n1:0:+10M -t1:EF00 -c1:GRUB -n2:0:0 -t2:BF01 -c2:ZFS -p $BOOT_PART
    mkfs.fat -v /dev/nvme1n1p1
else
    sgdisk -g -n1:0:4095 -t1:EF02 -c1:GRUB -n2:0:0 -t2:BF01 -c2:ZFS $BOOT_PART
fi

apt-get install -y zfsutils-linux debootstrap

# ZFS
zpool create sys /dev/nvme1n1p2 -o altroot=/mnt -o ashift=12 -o cachefile=/etc/zfs/zpool.cache -o autoexpand=on -O canmount=off -O compression=lz4 -O atime=off -O normalization=formD -m none -o compatibility=grub2

zfs create sys/os        -o mountpoint=/ -o canmount=noauto
zfs mount sys/os

# Make distinct locations we want to backup (home, srv, local) zfs mount points/snapshottable
zfs create sys/home      -o mountpoint=/home -o setuid=off
zfs create sys/home/root -o mountpoint=/root -o setuid=off
zfs create sys/local     -o mountpoint=/usr/local
zfs create sys/srv       -o mountpoint=/srv
zfs create sys/srv/logs  -o mountpoint=/srv/logs -o setuid=off
zfs create sys/var       -o mountpoint=/var -o setuid=off -o overlay=on
zfs create sys/var/cache -o mountpoint=/var/cache
#zfs create sys/var/tmp   -o mountpoint=/var/tmp
#zfs create sys/var/spool -o mountpoint=/var/spool
#zfs create sys/var/lib   -o mountpoint=/var/lib -o exec=on

# Display ZFS output for debugging purposes
zpool status
zfs list

# Bootstrap Ubuntu into /mnt
debootstrap --arch $CPUARCH noble /mnt

cp /etc/apt/sources.list /mnt/etc/apt/sources.list
cp /etc/apt/sources.list.d/ubuntu.sources /mnt/etc/apt/sources.list.d/ubuntu.sources # new in noble

# Copy the zpool cache
mkdir -p /mnt/etc/zfs
cp -p /etc/zfs/zpool.cache /mnt/etc/zfs/zpool.cache

# Create mount points and mount the filesystem
mkdir -p /mnt/{dev,proc,sys}
mount --rbind /dev /mnt/dev
mount --rbind /proc /mnt/proc
mount --rbind /sys /mnt/sys
mount --rbind /tmp /mnt/tmp # Scripts need access to SSH agent

cp /tmp/zfs.conf /mnt/tmp/zfs.conf

# Copy the bootstrap script into place and execute inside chroot
for file in bootstrap.sh setup.sh; do
    test -f /tmp/$file && chroot /mnt /tmp/$file
done

# Unmount bind mounts
umount -l /mnt/tmp
umount -l /mnt/dev
umount -l /mnt/proc
umount -l /mnt/sys

sleep 3

# Export the zpool
zpool export sys
