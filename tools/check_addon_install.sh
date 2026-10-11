#!/usr/bin/env bash
# Installs the plugin zip into an empty Godot project and uses it the way a
# new user would: enable the plugin, press Set Up Project, run the game,
# press New Game, and play the starter tale to the end. Catches anything in
# addons/storyteller/ that depends on files or settings only this repository
# has.
#
# Usage:
#   GODOT_BIN=/path/to/godot tools/check_addon_install.sh [plugin.zip]
#
# Builds the zip with tools/package_addon.sh when none is given.
set -uo pipefail

godot="${GODOT_BIN:-godot}"
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

zip="${1:-}"
if [[ -z "$zip" ]]; then
	zip="$("$root/tools/package_addon.sh" "$work/dist")" || exit 1
fi

project="$work/project"
mkdir -p "$project/addons/install_check"
(cd "$project" && unzip -q "$zip")
cp "$root/tools/addon_install/enabler.gd" "$project/addons/install_check/"
cp "$root/tools/addon_install/play_check.gd" "$project/"
cat >"$project/addons/install_check/plugin.cfg" <<'CFG'
[plugin]

name="Install Check"
description="Enables StoryTeller and runs Set Up Project."
author="StoryTeller"
version="1"
script="enabler.gd"
CFG
cat >"$project/project.godot" <<'PROJECT'
config_version=5

[application]

config/name="StoryTeller Install Check"

[editor_plugins]

enabled=PackedStringArray("res://addons/install_check/plugin.cfg")
PROJECT

# Messages from machines with no sound card or speech voices, not from StoryTeller.
noise='ALSA|audio driver|"status < 0"|Parameter "synth" is null|V-Sync'
failed=0

errors_in() {
	grep -E 'SCRIPT ERROR|^ERROR' "$1" | grep -vE "$noise" || true
}

expect() {
	if ! grep -qxF "CHECK $2" "$1"; then
		echo "Expected \"CHECK $2\"."
		failed=1
	fi
}

echo "Enabling the plugin and setting up the project..."
"$godot" --headless --path "$project" --import >"$work/import.log" 2>&1
timeout 120 "$godot" --headless --editor --path "$project" >"$work/editor.log" 2>&1
grep '^CHECK' "$work/editor.log"
for check in "enabled=true" "autoload=true" "story_tab=true" "needs_setup=true" "setup_errors=0" "main_scene=res://main.tscn" "editor_done"; do
	expect "$work/editor.log" "$check"
done
problems="$(errors_in "$work/editor.log")"
if [[ -n "$problems" ]]; then
	echo "$problems"
	failed=1
fi

echo "Playing the starter tale..."
"$godot" --headless --path "$project" --import >>"$work/import.log" 2>&1
timeout 120 "$godot" --headless --path "$project" -s res://play_check.gd >"$work/play.log" 2>&1
play_status=$?
grep '^CHECK' "$work/play.log"
expect "$work/play.log" "play_done"
problems="$(errors_in "$work/play.log")"
if [[ -n "$problems" ]]; then
	echo "$problems"
	failed=1
fi
if [[ $play_status != 0 ]]; then
	failed=1
fi

if [[ $failed != 0 ]]; then
	echo "Install check failed. Full logs:"
	echo "--- editor ---"; tail -n 40 "$work/editor.log"
	echo "--- play ---"; tail -n 40 "$work/play.log"
	exit 1
fi
echo "Install check passed: $(basename "$zip") works in an empty project."
