#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

apt install lua5.3
mkdir -m 755 -p /usr/local/bin
cp -f "edit.lua" "/usr/local/bin/edit"
chmod 755 "/usr/local/bin/edit"

