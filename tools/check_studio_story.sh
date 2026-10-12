#!/usr/bin/env bash
# Checks the way a teacher or parent publishes a student's story (decision
# 0022): installs the plugin zip in an empty Godot project, presses Open a
# Studio story with a story file from the Studio, plays the story to its
# end, and exports it as a web game, ready for itch.io or a class website.
#
# Usage:
#   GODOT_BIN=/path/to/godot tools/check_studio_story.sh [story.zip] [web-folder]
#
# Makes a story file with the Studio's starter art when none is given. The
# web export needs Godot's web export templates (web_nothreads_release.zip);
# without them that step is skipped. Give a web folder to keep the web build.
set -uo pipefail

godot="${GODOT_BIN:-godot}"
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap '[[ -n "${KEEP_WORK:-}" ]] || rm -rf "$work"' EXIT

story="${1:-}"
web_out="${2:-$work/web}"
if [[ -z "$story" ]]; then
	echo "Making a story file the way the Studio does..."
	"$godot" --headless --path "$root" -s res://tools/studio_story/make_story.gd -- "$work/stories" "$work/castle_trip.zip" >"$work/make.log" 2>&1
	if ! grep -qxF "CHECK story_file=true" "$work/make.log"; then
		tail -n 20 "$work/make.log"
		echo "Could not make a story file."
		exit 1
	fi
	story="$work/castle_trip.zip"
fi
story="$(cd "$(dirname "$story")" && pwd)/$(basename "$story")"

zip="$("$root/tools/package_addon.sh" "$work/dist")" || exit 1
project="$work/project"
mkdir -p "$project/addons/studio_story_check"
(cd "$project" && unzip -q "$zip")
cp "$root/tools/studio_story/enabler.gd" "$project/addons/studio_story_check/"
cp "$root/tools/addon_install/play_check.gd" "$project/"
cat >"$project/addons/studio_story_check/plugin.cfg" <<'CFG'
[plugin]

name="Studio Story Check"
description="Enables StoryTeller and opens a Studio story file."
author="StoryTeller"
version="1"
script="enabler.gd"
CFG
cat >"$project/project.godot" <<'PROJECT'
config_version=5

[application]

config/name="Studio Story Check"

[editor_plugins]

enabled=PackedStringArray("res://addons/studio_story_check/plugin.cfg")

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
PROJECT
cat >"$project/export_presets.cfg" <<'PRESET'
[preset.0]

name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="play_check.gd, addons/studio_story_check/*"
export_path=""

[preset.0.options]

variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
PRESET

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

report() {
	grep '^CHECK' "$1"
	local problems
	problems="$(errors_in "$1")"
	if [[ -n "$problems" ]]; then
		echo "$problems"
		failed=1
	fi
}

echo "Opening $(basename "$story") with Open a Studio story..."
"$godot" --headless --path "$project" --import >"$work/import.log" 2>&1
STUDIO_STORY_ZIP="$story" timeout 120 "$godot" --headless --editor --path "$project" >"$work/editor.log" 2>&1
report "$work/editor.log"
for check in "enabled=true" "story_tab=true" "scene=true" "problems=0" "editor_done"; do
	expect "$work/editor.log" "$check"
done

echo "Playing the story..."
"$godot" --headless --path "$project" --import >>"$work/import.log" 2>&1
timeout 120 "$godot" --headless --path "$project" -s res://play_check.gd >"$work/play.log" 2>&1
play_status=$?
report "$work/play.log"
expect "$work/play.log" "play_done"
if [[ $play_status != 0 ]]; then
	failed=1
fi

templates="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates"
if ls "$templates"/*/web_nothreads_release.zip >/dev/null 2>&1; then
	echo "Exporting it for the web..."
	mkdir -p "$web_out"
	"$godot" --headless --path "$project" --export-release "Web" "$web_out/index.html" >"$work/web.log" 2>&1
	for file in index.html index.pck index.wasm index.js; do
		if [[ ! -s "$web_out/$file" ]]; then
			echo "The web export has no $file."
			failed=1
		fi
	done
	if [[ $failed == 0 ]]; then
		echo "Web build: $web_out ($(du -sh "$web_out" | cut -f1))"
	fi
else
	echo "Skipping the web export: no web export templates in $templates."
fi

if [[ $failed != 0 ]]; then
	echo "Studio story check failed. Full logs:"
	echo "--- editor ---"; tail -n 40 "$work/editor.log"
	echo "--- play ---"; tail -n 40 "$work/play.log"
	[[ -f "$work/web.log" ]] && { echo "--- web ---"; tail -n 40 "$work/web.log"; }
	exit 1
fi
echo "Studio story check passed: $(basename "$story") opens, plays, and exports."
