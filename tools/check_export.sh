#!/usr/bin/env bash
# Exports the project as a .pck and checks it the way a shipped game sees
# it: source files are gone and only imported resources remain. Catches code
# that reads folders directly, which works in the editor but not in exports.
#
# Usage:
#   GODOT_BIN=/path/to/godot tools/check_export.sh
#
# Needs no export templates. Uses export_presets.cfg when it has a "Linux"
# preset, and otherwise writes a temporary one.
set -uo pipefail

godot="${GODOT_BIN:-godot}"
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
presets="$root/export_presets.cfg"
made_presets=0
cleanup() {
	rm -rf "$work"
	if [[ $made_presets == 1 ]]; then rm -f "$presets"; fi
}
trap cleanup EXIT

if ! grep -qs 'name="Linux"' "$presets"; then
	if [[ -e "$presets" ]]; then
		echo "export_presets.cfg has no \"Linux\" preset; add one to run this check."
		exit 1
	fi
	made_presets=1
	cat >"$presets" <<'PRESET'
[preset.0]

name="Linux"
platform="Linux"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*, tools/*, docs/*"
export_path=""

[preset.0.options]
PRESET
fi

"$godot" --headless --path "$root" --import >/dev/null 2>&1
if ! "$godot" --headless --path "$root" --export-pack "Linux" "$work/game.pck" >"$work/export.log" 2>&1; then
	tail -n 20 "$work/export.log"
	echo "Export failed."
	exit 1
fi

cp "$root/tools/export_check.gd" "$work/export_check.gd"
cd "$work" && "$godot" --headless --main-pack game.pck -s "$work/export_check.gd"
