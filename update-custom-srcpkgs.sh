#!/usr/bin/env bash

set -euo pipefail

pkgs=(codex dmenu dwm fp lualib luarocks lus nvim prefix sent zig zls zua)

latest_stable_tag() {
	local repo="$1" prefix="$2"
	git ls-remote --tags --refs "$repo" \
		| awk '{print $2}' \
		| sed 's#refs/tags/##' \
		| while IFS= read -r tag; do
			[[ -n "$prefix" && "$tag" != "$prefix"* ]] && continue
			tag="${tag#"$prefix"}"
			[[ "$tag" =~ ^[0-9]+(\.[0-9]+)*$ ]] && echo "$tag"
		done \
		| sort -V \
		| tail -n1
}

latest_suckless_tag() {
	local project="$1"
	curl -fsSL "https://git.suckless.org/${project}/refs.html" \
		| grep -Eo '>[0-9]+(\.[0-9]+)*<' \
		| tr -d '<>' \
		| sort -V \
		| tail -n1
}

for pkg in "${pkgs[@]}"; do
	template="srcpkgs/$pkg/template"

	version=$(sed -n 's/^version=//p' "$template")

	case "$pkg" in
		codex)   newver=$(latest_stable_tag "https://github.com/openai/codex.git" "rust-v") ;;
		dmenu|dwm|sent) newver=$(latest_suckless_tag "$pkg") ;;
		luarocks)newver=$(latest_stable_tag "https://github.com/luarocks/luarocks.git" "v") ;;
		prefix)  newver=$(latest_stable_tag "https://github.com/Shivix/prefix.git" "v") ;;
		*)       newver="$version" ;;
	esac

	[[ -n "$newver" ]] || { echo "no stable tag found for $pkg" >&2; exit 1; }
	if [[ "$newver" != "$version" ]]; then
		sed -i -E "s/^version=.*/version=$newver/" "$template"
		echo "$pkg: $version -> $newver"
		version="$newver"
	fi

	if [[ "$pkg" == "nvim" ]]; then
		deps_txt="$(curl -fsSL https://raw.githubusercontent.com/neovim/neovim/nightly/cmake.deps/deps.txt)"
		luajit_url=$(echo "$deps_txt" | awk '$1=="LUAJIT_URL"{print $2; exit}')
		luv_url=$(echo "$deps_txt" | awk '$1=="LUV_URL"{print $2; exit}')
		lua_compat53_url=$(echo "$deps_txt" | awk '$1=="LUA_COMPAT53_URL"{print $2; exit}')
		lpeg_url=$(echo "$deps_txt" | awk '$1=="LPEG_URL"{print $2; exit}')

		luajit_ver=$(basename "$luajit_url" .tar.gz)
		luv_ver=$(basename "$luv_url" .tar.gz)
		lua_compat53_ver=$(basename "$lua_compat53_url" .tar.gz)
		lua_compat53_ver="${lua_compat53_ver#v}"
		lpeg_ver=$(basename "$lpeg_url" .tar.gz)
		lpeg_ver="${lpeg_ver#lpeg-}"
		lpeg_deps_commit=$(echo "$lpeg_url" | sed -E 's#^https://github.com/neovim/deps/raw/([^/]+)/opt/lpeg-.*#\1#')

		sed -i -E "s|^_luajit_version=.*|_luajit_version=$luajit_ver|" "$template"
		sed -i -E "s|^_luv_version=.*|_luv_version=$luv_ver|" "$template"
		sed -i -E "s|^_lua_compat53_version=.*|_lua_compat53_version=$lua_compat53_ver|" "$template"
		sed -i -E "s|^_lpeg_version=.*|_lpeg_version=$lpeg_ver|" "$template"
		sed -i -E "s|^_lpeg_deps_commit=.*|_lpeg_deps_commit=$lpeg_deps_commit|" "$template"
		exit 0
	fi

	distfile=$(./xbps-src show $pkg | awk '/distfiles/ { print $2 }')
	checksum=$(sed -n 's/^checksum=//p' "$template")
	newchecksum=$(curl -fsSL "$distfile" | sha256sum | awk '{print $1}')
	if [[ "$newchecksum" != "$checksum" ]]; then
		echo "$pkg: new checksum"
		sed -i -E "s/^checksum=.*/checksum=$newchecksum/" "$template"
		echo ./xbps-src clean "$pkg"
		echo ./xbps-src pkg "$pkg"
		echo sudo xbps-install --yes --repository hostdir/binpkgs/local $pkg -f
	fi
done
