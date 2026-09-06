#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

echo "UNINSTALLER: remove system cli tools"
rm -f "/usr/local/bin/edit"

