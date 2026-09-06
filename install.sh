#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

echo "INSTALLER: apt update"
apt update

echo "INSTALLER: install system packages"
apt install -y lua5.3

echo "INSTALLER: install system cli tools"
mkdir -m 755 -p /usr/local/bin
cp -f "edit.lua" "/usr/local/bin/edit"
chmod 755 "/usr/local/bin/edit"

