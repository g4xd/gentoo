#!/usr/bin/env bash

# Configuring the network
net-setup wlo1

# Preparing the disks
parted -a optimal /dev/sda \
mklabel gpt \
unit mib \
mkpart primary 1 3 \
name 1 grub \
set 1 bios_grub on \
mkpart primary 3 131 \
name 2 boot \
mkpart primary 131 8323 \
name 3 swap \
mkpart primary 643 -1 \
name 4 rootfs

# Creating file systems
mkfs.vfat -F 32 /dev/sda2
mkfs.ext4 /dev/sda4
mkswap /dev/sda3
swapon /dev/sda3

# Mounting the root partition
mount /dev/sda4 /mnt/gentoo

# Setting the date and time
ntpd -q -g
hwclock --systohc

# Installing a stage tarball
cd /mnt/gentoo
CURRENT_DATE=$(date +%Y%m%d)
RESULT=1
while [[ ! $RESULT -eq 0 ]] do
  curl http://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-$CURRENT_DATE.tar.bz2 | tar xjp --xattrs --numeric-owner
  RESULT=$?
  let CURRENT_DATE--
end

 
# Copy DNS info
cp -L /etc/resolv.conf /mnt/gentoo/etc/

# Mounting the necessary filesystems
mount -t proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

# Entering the new environment
cat <<EOF | chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) $PS1"

# Mounting the boot partition
mkdir /boot
mount /dev/sda2 /boot

# Configuring Portage

emerge-webrsync
emerge --sync
emerge --ask --update --deep --newuse @world
