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

	distfile=$(sed -n 's/^distfiles="\([^"]*\)"/\1/p' "$template")
	url=${distfile//\$\{pkgname\}/$pkg}
	url=${url//\$\{version\}/$version}
	url=${url//\$pkgname/$pkg}
	url=${url//\$version/$version}

	checksum=$(curl -fsSL "$url" | sha256sum | awk '{print $1}')
	sed -i -E "s/^checksum=.*/checksum=$checksum/" "$template"
done
