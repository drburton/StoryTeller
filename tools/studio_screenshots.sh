#!/usr/bin/env bash
# Saves the Studio screenshots the textbook uses (docs/studio-design.md
# §13): each shot in studio/lessons/screenshots.json, made from the lesson
# projects and templates, as a PNG in the output folder.
#
# Usage:
#   GODOT_BIN=/path/to/godot tools/studio_screenshots.sh <output-folder> [shot names...]
#
# SIZE sets the window (default 1366x1024, an iPad's shape). Without a
# display, it runs under xvfb-run when that is installed.
set -euo pipefail

godot="${GODOT_BIN:-godot}"
root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -lt 1 ]]; then
	echo "Usage: tools/studio_screenshots.sh <output-folder> [shot names...]" >&2
	exit 2
fi
out="$(mkdir -p "$1" && cd "$1" && pwd)"
shift
size="${SIZE:-1366x1024}"
run=("$godot" --path "$root" --rendering-driver opengl3 --resolution "$size" -s res://tools/studio_screenshots.gd -- "$out" "$@")
if [[ -z "${DISPLAY:-}" ]] && command -v xvfb-run >/dev/null; then
	xvfb-run -a -s "-screen 0 ${size}x24" "${run[@]}"
else
	"${run[@]}"
fi
