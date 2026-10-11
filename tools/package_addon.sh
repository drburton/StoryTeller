#!/usr/bin/env bash
# Builds the plugin zip that people install: addons/storyteller/ and nothing
# else. Takes the files git tracks, with any uncommitted changes to them;
# new files need git add first. The zip unpacks into a project's root folder.
#
# Usage:
#   tools/package_addon.sh [output-folder]
#
# Writes <output-folder>/storyteller-<version>.zip (build/ by default), with
# the version from addons/storyteller/plugin.cfg, and prints its path.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-$root/build}"
version="$(sed -n 's/^version="\(.*\)"$/\1/p' "$root/addons/storyteller/plugin.cfg")"
if [[ -z "$version" ]]; then
	echo "No version in addons/storyteller/plugin.cfg." >&2
	exit 1
fi

mkdir -p "$out"
zip="$(cd "$out" && pwd)/storyteller-$version.zip"
rm -f "$zip"
# stash create records uncommitted changes without touching the work tree.
tree="$(git -C "$root" stash create)"
git -C "$root" archive --format=zip --output="$zip" "${tree:-HEAD}" addons/storyteller
echo "$zip"
