#!/bin/bash

echo "INSTALLER: install user cli tools"

DEST="$HOME/.local/bin/edit"
mkdir -p "$HOME/.local/bin"
cp edit.lua "$DEST"
chmod 755 "$DEST"
