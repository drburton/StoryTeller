#!/usr/bin/env bash
# Downloads a Linux Godot build for CI and prints the executable path.
#
# Usage: tools/ci_install_godot.sh <version> <install-dir>
#   version: release tag without the "Godot_v" prefix, e.g. 4.7.2-stable or 4.8-beta1
set -euo pipefail

version="$1"
dir="$2"
exe="$dir/Godot_v${version}_linux.x86_64"

if [[ ! -x "$exe" ]]; then
	mkdir -p "$dir"
	url="https://github.com/godotengine/godot-builds/releases/download/${version}/Godot_v${version}_linux.x86_64.zip"
	curl -fsSL --retry 3 -o "$dir/godot.zip" "$url"
	unzip -q -o "$dir/godot.zip" -d "$dir"
	rm "$dir/godot.zip"
	chmod +x "$exe"
fi

echo "$exe"
