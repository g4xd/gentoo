#!/usr/bin/env bash

# Install i3wn and xserver
echo "x11-base/xorg-server glamor" > /etc/portage/package.use/xorg
echo "x11-libs/libxcb xkb\nx11-libs/cario xcb" > /etc/portage/package.use/i3
emerge x11-base/xorg-drivers \
  x11-base/xorg-server \
  x11-terms/rxvt-unicode
emerge x11-wm/i3 \
  x11-misc/i3status \
  x11-misc/i3lock \
  x11-misc/dmenu

# Install google chrome
echo "app-text/ghostscript-gpl cups\napp-text/xmlto text" /etc/portage/package.use/chrome
echo "www-client/google-chrome google-chrome" /etc/portage/package.licence
emerge www-client/google-chrome
