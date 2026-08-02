#!/usr/bin/env bash

set -euo pipefail

doas xbps-install -Su

git fetch upstream
git rebase -i upstream/master --autostash
./update-custom-srcpkgs.sh

doas xbps-remove -O

#vkpurge rm all

orphan_list="$(xbps-remove -on)"

if [[ -n "$orphan_list" ]]; then
	echo "Orphans found:"
	echo "$orphan_list"
	read -r -p "Do you want to remove these orphans? (y/N) " user_confirmation
	if [[ "${user_confirmation}" == "y" ]]; then
		doas xbps-remove -o
	fi
fi

doas makewhatis /usr/share/man

doas fstrim /

# TODO: search for warns and errors and add filter for warnings I'm okay with.
printf "Please check the following for errors and new warnings:\ndoas dmesg\nsvlogtail"
