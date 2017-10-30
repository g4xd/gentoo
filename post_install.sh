#!/usr/bin/env bash

# Create user
useradd -m -G users,wheel,audio,video g4xd
echo -e "pass\npass\n" | passwd

# Install i3wn and xserver
echo "x11-base/xorg-server glamor" > /etc/portage/package.use/xorg
echo "x11-libs/libxcb xkb\nx11-libs/cario xcb" > /etc/portage/package.use/i3
emerge x11-base/xorg-drivers \
  x11-base/xorg-server \
  x11-terms/rxvt-unicode \
  media-libs/vulkan-loader \
  media-sound/alsa-utils
emerge x11-wm/i3 \
  x11-misc/i3status \
  x11-misc/i3lock \
  x11-misc/dmenu \
  x11-apps/setxkbmap \
  media-fonts/terminus-font
  
# Install coretools
emerge app-admin/sudo \
  app-editors/vim \
  app-misc/ranger \
  media-video/ffmpeg \
  dev-vcs/git \
  net-vpn/openvpn \
  app-portage/layman
  
# Install zshell
emerge app-shells/zsh \
  zsh-completions
  gentoo-zsh-completions
  
# Install laptop-mode
emerge app-laptop/laptop-mode-tools
ETH_DEV=$(ip a | awk -F': ' '/^2:/{print $2}')
sed -i "/DEVICES/s/eth0/$ETH_DEV"/ /etc/laptop-mode/conf.d/ethernet.conf
rc-update add laptop_mode default

# Install google chrome
echo "app-text/ghostscript-gpl cups\napp-text/xmlto text" /etc/portage/package.use/chrome
echo "www-client/google-chrome google-chrome" /etc/portage/package.licence
emerge www-client/google-chrome
