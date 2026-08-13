#!/bin/bash

# Copyright 2025-2026 The hardened_chromium Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.

set -oue pipefail

patches_directory="$(pwd)"
readonly patches_directory
remote_helium_patches=()
truncated_remote_helium_patches=()

get_remote_helium_patches() {
	cd helium-patches-tmp/
	local retry=0
	while true; do
		git clone "https://github.com/imputnet/helium.git" Helium
		if [[ ! -d Helium/patches/helium ]]; then
			rm -rf Helium/
			echo "ERROR! git operation failed!"
			if [[ ${retry} -gt 0 ]]; then
				echo "Failed to clone $((retry+1)) times..."
			fi
			if [[ ${retry} == 2 ]]; then
				echo "Aborting!"
				cd "${patches_directory}"
				rm -rf helium-patches-tmp/
				exit 1
			fi
			echo "Retrying..."
			retry=$((retry+1))
		else
			break
		fi
	done
	cd Helium/patches/helium
	mapfile -t remote_helium_patches < <(
		find . -type f -name "*.patch" -printf "%P\n" | sort
	)
	for ((i=0; i<${#remote_helium_patches[@]}; i++)); do
		patch_name="${remote_helium_patches[${i}]##*/}"
		truncated_remote_helium_patches[i]="${remote_helium_patches[${i}]%${patch_name}${patch_name}}"
	done
	cd "${patches_directory}"
}

update_helium_patches() {
    get_remote_helium_patches
    cd "./helium/"
    mapfile -t current_helium_patches < <(
        find . -type f -name "*.patch" ! -name "modified-*.patch" -printf "%P\n" | sort
    )
    local truncated_helium_patches=()
	for ((i=0; i<${#current_helium_patches[@]}; i++)); do
	truncated_helium_patches[i]="${current_helium_patches[${i}]}"
	done
	local updated_counter=0
	local removed_counter=0
	local patch_not_found_counter=0
	for ((i=0; i<${#truncated_helium_patches[@]}; i++)); do
		for ((j=0; j<${#truncated_remote_helium_patches[@]}; j++)); do
		if [[ "${truncated_remote_helium_patches[${j}]}" == "${truncated_helium_patches[${i}]}" ]]; then
		if [[ "${remote_helium_patches[${j}]}" == "${current_helium_patches[${i}]}" ]]; then
		echo "Updating patch ${current_helium_patches[${i}]}"
					echo "	No name change"
				else
					echo "Updating patch ${current_helium_patches[${i}]}"
					echo "	Patch renamed to: ${remote_helium_patches[${j}]}"
				fi
				rm "${current_helium_patches[${i}]}"
				cp "${patches_directory}/helium-patches-tmp/Helium/patches/helium/${remote_helium_patches[${j}]}" ./
				updated_counter=$((updated_counter+1))
			else
				patch_not_found_counter=$((patch_not_found_counter+1))
			fi
		done
		# Assume, since the patch has not been found, the patch has been removed
		if [[ ${patch_not_found_counter} == "${#truncated_remote_helium_patches[@]}" ]]; then
			echo "Removing ${current_helium_patches[i]}"
			echo "	Patch has been removed in Helium"
			rm "${current_helium_patches[${i}]}"
			removed_counter=$((removed_counter+1))
		fi
		patch_not_found_counter=0
	done
	echo ""
	echo "Updated ${updated_counter} patches."
	echo "Removed ${removed_counter} patches."
	cd "${patches_directory}"
}

mkdir helium-patches-tmp/ # create a temporary directory for cloning the Helium patches
update_helium_patches
rm -rf helium-patches-tmp/ # cleanup
exit 0
