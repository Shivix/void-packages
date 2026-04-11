#!/usr/bin/env bash

set -euo pipefail

pkgs=("$@")
(( ${#pkgs[@]} == 0 )) && pkgs=(codex dmenu dwm fp lualib luarocks lus prefix sent zig zls zua)

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

latest_zig_master_version() {
	curl -fsSL "https://ziglang.org/download/index.json" | jq -r '.master.version | sub("-dev\\."; "dev.")'
}

for pkg in "${pkgs[@]}"; do
	template="srcpkgs/$pkg/template"

	version=$(sed -n 's/^version=//p' "$template")

	case "$pkg" in
		codex)   newver=$(latest_stable_tag "https://github.com/openai/codex.git" "rust-v") ;;
		dmenu|dwm|sent) newver=$(latest_suckless_tag "$pkg") ;;
		luarocks)newver=$(latest_stable_tag "https://github.com/luarocks/luarocks.git" "v") ;;
		prefix)  newver=$(latest_stable_tag "https://github.com/Shivix/prefix.git" "v") ;;
		zig)     newver=$(latest_zig_master_version) ;;
		*)       newver="$version" ;;
	esac

	[[ -n "$newver" ]] || { echo "no stable tag found for $pkg" >&2; exit 1; }
	if [[ "$newver" != "$version" ]]; then
		sed -i -E "s/^version=.*/version=$newver/" "$template"
		echo "$pkg: $version -> $newver"
		version="$newver"
	fi
fi

	distfile=$(./xbps-src show "$pkg" | awk '/distfiles/ { print $2 }')
	checksum=$(sed -n 's/^checksum=//p' "$template")
	newchecksum=$(curl -fsSL "$distfile" | sha256sum | awk '{print $1}')
	if [[ "$newchecksum" != "$checksum" ]]; then
		echo "$pkg: new checksum"
		sed -i -E "s/^checksum=.*/checksum=$newchecksum/" "$template"
		./xbps-src clean "$pkg"
		./xbps-src pkg "$pkg"
		sudo xbps-install --yes --repository hostdir/binpkgs/local "$pkg" -f
	fi
done
