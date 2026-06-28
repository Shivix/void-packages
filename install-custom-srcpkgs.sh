#!/usr/bin/env bash

set -euo pipefail

# Zig must come before fp as it is used to build
pkgs=(codex dmenu dwm zig fp lualib lus prefix sent zls zua)

for pkg in "${pkgs[@]}"; do
	./xbps-src pkg "$pkg"
	sudo xbps-install --yes --repository hostdir/binpkgs/local "$pkg"
done
