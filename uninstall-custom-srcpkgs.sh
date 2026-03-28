#!/usr/bin/env bash

set -euo pipefail

pkgs=(codex dmenu dwm fp lualib luarocks lus nvim prefix sent zig zls zua)

for pkg in "${pkgs[@]}"; do
	sudo xbps-remove -Ro "$pkg"
done
