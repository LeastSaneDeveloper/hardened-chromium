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
remote_trivalent_patches=()
truncated_remote_trivalent_patches=()

get_remote_trivalent_patches() {
	cd trivalent-patches-tmp/
	local retry=0
	while true; do
		git clone "https://github.com/secureblue/Trivalent.git"
		if [[ ! -d Trivalent/patches/trivalent ]]; then
			rm -rf Trivalent/
			echo "ERROR! git operation failed!"
			if [[ ${retry} -gt 0 ]]; then
				echo "Failed to clone $((retry+1)) times..."
			fi
			if [[ ${retry} == 2 ]]; then
				echo "Aborting!"
				cd "${patches_directory}"
				rm -rf trivalent-patches-tmp/
				exit 1
			fi
			echo "Retrying..."
			retry=$((retry+1))
		else
			break
		fi
	done
	cd Trivalent/patches/trivalent
	mapfile -t remote_trivalent_patches < <(
		find . -type f -name "*.patch" -printf "%P\n" | sort
	)
	for ((i=0; i<${#remote_trivalent_patches[@]}; i++)); do
		patch_name="${remote_trivalent_patches[${i}]##*/}"
		truncated_remote_trivalent_patches[i]="${remote_trivalent_patches[${i}]%${patch_name}${patch_name:4}}"
	done
	cd "${patches_directory}"
}

update_trivalent_patches() {
    get_remote_trivalent_patches
    cd "./trivalent/"
    mapfile -t current_trivalent_patches < <(
        find . -type f -name "*.patch" ! -name "modified-*.patch" -printf "%P\n" | sort
    )
    local truncated_trivalent_patches=()
	for ((i=0; i<${#current_trivalent_patches[@]}; i++)); do
		truncated_trivalent_patches[i]="${current_trivalent_patches[${i}]}"
	done
	local updated_counter=0
	local removed_counter=0
	local patch_not_found_counter=0
	for ((i=0; i<${#truncated_trivalent_patches[@]}; i++)); do
		for ((j=0; j<${#truncated_remote_trivalent_patches[@]}; j++)); do
			if [[ "${truncated_remote_trivalent_patches[${j}]}" == "${truncated_trivalent_patches[${i}]}" ]]; then
				if [[ "${remote_trivalent_patches[${j}]}" == "${current_trivalent_patches[${i}]}" ]]; then
					echo "Updating patch ${current_trivalent_patches[${i}]}"
					echo "	No name change"
				else
					echo "Updating patch ${current_trivalent_patches[${i}]}"
					echo "	Patch renamed to: ${remote_trivalent_patches[${j}]}"
				fi
				rm "${current_trivalent_patches[${i}]}"
				cp "${patches_directory}/trivalent-patches-tmp/Trivalent/patches/trivalent/${remote_trivalent_patches[${j}]}" ./
				updated_counter=$((updated_counter+1))
			else
				patch_not_found_counter=$((patch_not_found_counter+1))
			fi
		done
		# Assume, since the patch has not been found, the patch has been removed
		if [[ ${patch_not_found_counter} == "${#truncated_remote_trivalent_patches[@]}" ]]; then
			echo "Removing ${current_trivalent_patches[i]}"
			echo "	Patch has been removed in Trivalent"
			rm "${current_trivalent_patches[${i}]}"
			removed_counter=$((removed_counter+1))
		fi
		patch_not_found_counter=0
	done
	echo ""
	echo "Updated ${updated_counter} patches."
	echo "Removed ${removed_counter} patches."
	cd "${patches_directory}"
}

mkdir trivalent-patches-tmp/ # create a temporary directory for cloning the Trivalent patches
update_trivalent_patches
rm -rf trivalent-patches-tmp/ # cleanup
exit 0
