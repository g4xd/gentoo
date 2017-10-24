#!/usr/bin/env bash

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
COUNT=0
RESULT=1
while [[ ! $RESULT -eq 0 ]] do
  DATE=$(date -d "-$COUNT day" +%Y%m%d)
  curl http://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-$DATE.tar.bz2 | \
  tar xjp --xattrs --numeric-owner 2>/dev/null
  RESULT=$?
  let COUNT++
done

# Selecting mirrors
echo 'GENTOO_MIRRORS="http://mirror.yandex.ru/gentoo-distfiles/"' >> /mnt/gentoo/etc/portage/make.conf
mkdir /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
 
# Copy DNS info
cp -L /etc/resolv.conf /mnt/gentoo/etc/

# Mounting the necessary filesystems
mount -t proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

# Entering the new environment
cat <<CHROOT | chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) $PS1"

# Mounting the boot partition
mkdir /boot
mount /dev/sda2 /boot

# Configuring Portage
emerge-webrsync
emerge --sync
emerge --ask --update --deep --newuse @world
emerge --ask cpuid2cpuflags
sed -i "s/CPU_FLAGS_X86.*/$(cpuinfo2cpuflags-x86)/" /etc/portage/make.conf
echo "MAKEOPTS=\"-j$(nproc)" >> /etc/portage/make.conf

# Timezone
echo "Europe/Moscow" > /etc/timezone
emerge --config sys-libs/timezone-data

# Configure locales
sed -i '/en_US.UTF/s/#//' /etc/locale.gen
locale-gen
eselect locale set en_US.utf8
env-update && source /etc/profile && export PS1="(chroot) $PS1"

# Configuring kernel
emerge --ask sys-kernel/gentoo-sources
emerge --ask sys-kernel/linux-firmware
emerge --ask sys-kernel/genkernel
cat <<'FSTAB' >> /etc/fstab
/dev/sda2   /boot   vfat    defaults,noatime    0 2
/dev/sda3   none    swap    sw                  0 0
/dev/sda4   /       ext4    noatime             0 1
FSTAB
genkernel all

# Host and domain information
sed -i '/host/s/".*"/"gentoo"/' /etc/conf.d/hostname
sed -i 's/\.\\O//' /etc/issue

# Configuring the network
emerge --ask --noreplace net-misc/netifrc
cd /etc/init.d
ln -s net.lo net.wlo1
rc-update add net.wlo1 default

# Get PCMCIA working
emerge --ask sys-apps/pcmciautils

# Set root password
echo -e "pass\npass\n" | passwd

# System logger
emerge --ask app-admin/sysklogd app-admin/logrotate
rc-update add sysklogd default

# Cron daemon
emerge --ask sys-process/cronie
rc-update add cronie default

# File indexing
emerge --ask sys-apps/mlocate

# Installing a DHCP client
emerge --ask net-misc/dhcpcd

# GRUB2
emerge --ask --verbose sys-boot/grub:2
grub-install --target=x86_64-efi --efi-directory=/boot --removable
grub-mkconfig -o /boot/grub/grub.cfg
CHROOT

cd
umount -l /mnt/gentoo/dev{/shm,/pts,}
umount -R /mnt/gentoo
reboot
