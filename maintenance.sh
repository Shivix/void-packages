#!/usr/bin/env bash

set -euo pipefail

sudo xbps-install -Su

git fetch upstream
git rebase -i upstream/master --autostash
./update-custom-srcpkgs.sh

sudo xbps-remove -O

#vkpurge rm all

orphan_list="$(xbps-remove -on)"

if [[ -n "$orphan_list" ]]; then
	echo "Orphans found:"
	echo "$orphan_list"
	read -r -p "Do you want to remove these orphans? (y/N) " user_confirmation
	if [[ "${user_confirmation}" == "y" ]]; then
		sudo xbps-remove -o
	fi
fi

sudo makewhatis /usr/share/man

sudo fstrim /

# TODO: search for warns and errors and add filter for warnings I'm okay with.
printf "Please check the following for errors and new warnings:\nsudo dmesg\nsvlogtail"
