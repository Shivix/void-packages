#!/usr/bin/env bash

set -euo pipefail

pkgs=(codex dmenu dwm fp lualib luarocks lus nvim prefix sent zig zls zua)

for pkg in "${pkgs[@]}"; do
	./xbps-src pkg "$pkg"
	sudo xbps-install --yes --repository hostdir/binpkgs/local "$pkg"
done
