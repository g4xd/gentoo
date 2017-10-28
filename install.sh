#!/usr/bin/env bash
set -ex

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
mkpart primary 8323 -1 \
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
while [[ ! $RESULT -eq 0 ]]; do
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

# Mounting the boot partition
if [[ ! -d /boot ]]; then mkdir /boot; done
mount /dev/sda2 /boot

# Configuring Portage
emerge-webrsync
emerge cpuid2cpuflags && \
sed -i "s/^CPU_FLAGS_X86.*/$(cpuinfo2cpuflags-x86)/" /etc/portage/make.conf

sed -i "/^CFLAGS/s/\".*\"/\"-march=native -O2 -pipe\"/" /etc/portage/make.conf
sed -i "/^USE/s/\".*\"/\"X vulkan vaapi alsa xtf\"/" /etc/portage/make.conf
echo "MAKEOPTS=\"-j$(nproc)\"" >> /etc/portage/make.conf
echo 'VIDEO_CARDS="intel i965"' >> /etc/portage/make.conf

emerge --update --deep --newuse @world

# Timezone
echo "Europe/Moscow" > /etc/timezone
emerge --config sys-libs/timezone-data

# Configure locales
sed -i '/en_US.UTF/s/#//' /etc/locale.gen
locale-gen
eselect locale set en_US.utf8
env-update && source /etc/profile

# Configuring kernel
emerge sys-kernel/gentoo-sources
emerge sys-kernel/linux-firmware
emerge sys-kernel/genkernel
cat <<FSTAB >> /etc/fstab
/dev/sda2   /boot   vfat    defaults,noatime    0 2
/dev/sda3   none    swap    sw                  0 0
/dev/sda4   /       ext4    noatime             0 1
FSTAB
genkernel all

# Host and domain information
sed -i '/host/s/".*"/"gentoo"/' /etc/conf.d/hostname
sed -i 's/\.\\O//' /etc/issue

# Configuring the network
emerge net-wireless/wpa_supplicant
emerge --noreplace net-misc/netifrc
cd /etc/init.d
ln -s net.lo net.wlo1
rc-update add net.wlo1 default

# Get PCMCIA working
emerge sys-apps/pcmciautils

# Set root password
echo -e "pass\npass\n" | passwd

# System logger
emerge app-admin/sysklogd app-admin/logrotate
rc-update add sysklogd default

# Cron daemon
emerge sys-process/cronie
rc-update add cronie default

# File indexing
emerge sys-apps/mlocate

# Installing a DHCP client
emerge net-misc/dhcpcd

# GRUB2
emerge --verbose sys-boot/grub:2
grub-install --target=x86_64-efi --efi-directory=/boot --removable
grub-mkconfig -o /boot/grub/grub.cfg

# install i3wn and xserver
emerge x11-base/xorg-drivers
emerge x11-base/xorg-server
emerge x11-wm/i3 x11-misc/i3status x11-misc/i3lock x11-misc/dmenu
CHROOT

cp /etc/wpa_supplicant/wpa_supplicant.conf /mnt/gentoo/etc/wpa_supplicant/
cp /etc/conf.d/net /mnt/gentoo/etc/conf.d/

cd
umount -l /mnt/gentoo/dev{/shm,/pts,}
umount -R /mnt/gentoo
reboot
