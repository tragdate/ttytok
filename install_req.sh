#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
#gets the package manager and define a variable for it to be used later and sets the names of the packages according to the package manager
if [ -f /usr/bin/apt-get ]; then
  PM="apt-get"
  PM_INSTALL="install"
  PM_PACKAGES="fzf inotify-tools mpv tmux"
  PM_YES="-y"
elif [ -f /usr/bin/yum ]; then
  PM="yum"
  PM_INSTALL="install"
  PM_PACKAGES="fzf inotify-tools mpv tmux"
  PM_YES="-y"
elif [ -f /usr/bin/pacman ]; then
  PM="pacman"
  PM_INSTALL="-S"
  PM_PACKAGES="fzf inotify-tools mpv tmux"
  PM_YES="--noconfirm --needed"
elif [ -f /usr/bin/dnf ]; then
  PM="dnf"
  PM_INSTALL="install"
  PM_PACKAGES="fzf inotify-tools mpv tmux"
  PM_YES="-y"
elif [ -f /usr/bin/apk ]; then
  PM="apk"
  PM_INSTALL="add"
  PM_PACKAGES="fzf inotify-tools mpv tmux"
  PM_YES="--no-confirm"
else
  echo "No compatible package manager found"
  exit 1
fi

#installs the packages
$PM $PM_INSTALL $PM_PACKAGES $PM_YES
