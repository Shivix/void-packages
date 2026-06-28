#!/usr/bin/env bash

set -euo pipefail

# Use args as pkg list, else install all if none provided.
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
    git ls-remote --tags "https://git.suckless.org/$project" \
    | sed 's#.*refs/tags/##' \
    | sed 's/\^{}//' \
    | grep -E '^[0-9]+(\.[0-9]+)*$' \
    | sort -V \
    | tail -n1
}

latest_zig_master_version() {
    curl -fsSL "https://ziglang.org/download/index.json" | jq  -r 'keys[]  | select(test("^[0-9]+.[0-9]+.[0-9]+$"))' | sort -V | tail -1
}

for pkg in "${pkgs[@]}"; do
    emplate="srcpkgs/$pkg/template"

    version=$(sed -n 's/^version=//p' "$template")

    case "$pkg" in
        codex)   newver=$(latest_stable_tag "https://github.com/openai/codex.git" "rust-v") ;;
        dmenu|dwm|sent) newver=$(latest_suckless_tag "$pkg") ;;
        luarocks)newver=$(latest_stable_tag "https://github.com/luarocks/luarocks.git" "v") ;;
        prefix)  newver=$(latest_stable_tag "https://github.com/Shivix/prefix.git" "v") ;;
        zig)     newver=$(latest_zig_master_version) ;;
        zls)     newver=$(latest_stable_tag "https://github.com/zigtools/zls.git" "") ;;
        *)       newver="$version" ;;
    esac

    [[ -n "$newver" ]] || { echo "no stable tag found for $pkg" >&2; exit 1; }
    if [[ "$newver" != "$version" ]]; then
        sed -i -E "s/^version=.*/version=$newver/" "$template"
        echo "$pkg: $version -> $newver"
        version="$newver"
    fi

    distfile=$(./xbps-src show "$pkg" | awk '/distfiles/ { print $2 }')
    checksum=$(sed -n 's/^checksum=//p' "$template")
    newchecksum=""
    if [[ "$pkg" = "zig" ]]; then
        newchecksum=$(
        curl -fsSL https://ziglang.org/download/index.json |
        jq -r --arg v "$version" '.[$v]["x86_64-linux"].shasum'
    )
    else
        newchecksum=$(curl -fsSL "$distfile" | sha256sum | awk '{print $1}')
    fi
    if [[ "$newchecksum" != "$checksum" ]]; then
        echo "$pkg: new checksum"
        sed -i -E "s/^checksum=.*/checksum=$newchecksum/" "$template"
        ./xbps-src clean "$pkg"
        ./xbps-src pkg "$pkg"
        sudo xbps-install --yes --repository hostdir/binpkgs/local "$pkg" -f
    else
        echo "$pkg: up to date"
    fi
done
