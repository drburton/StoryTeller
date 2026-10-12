#!/usr/bin/env bash
# Builds a Visual Novel StoryTeller Studio app from this project: the block
# editor (studio/studio.tscn), with the tablet check (studio/check/) in its
# ⋯ menu.
#
# Usage:
#   GODOT_BIN=/path/to/godot tools/build_studio.sh <linux|android> <output-file>
#
# Needs Godot's export templates. Android also needs the Android SDK and a
# Java JDK set in Godot's editor settings, and a debug keystore (Godot makes
# one, or set GODOT_ANDROID_KEYSTORE_DEBUG_PATH, _USER, and _PASSWORD).
# Uses export_presets.cfg when it has the "Studio" presets, and otherwise
# writes a temporary one.
set -uo pipefail

godot="${GODOT_BIN:-godot}"
root="$(cd "$(dirname "$0")/.." && pwd)"
platform="${1:-}"
output="${2:-}"
case "$platform" in
	linux) preset="Studio Linux" ;;
	android) preset="Studio Android" ;;
	*) echo "Usage: tools/build_studio.sh <linux|android> <output-file>" >&2; exit 2 ;;
esac
if [[ -z "$output" ]]; then
	echo "Give an output file, such as build/studio.apk." >&2
	exit 2
fi
mkdir -p "$(dirname "$output")"
output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"

presets="$root/export_presets.cfg"
made_presets=0
cleanup() {
	if [[ $made_presets == 1 ]]; then rm -f "$presets"; fi
}
trap cleanup EXIT

if ! grep -qs "name=\"$preset\"" "$presets"; then
	if [[ -e "$presets" ]]; then
		echo "export_presets.cfg has no \"$preset\" preset; add one or move the file aside." >&2
		exit 1
	fi
	made_presets=1
	cat >"$presets" <<'PRESETS'
[preset.0]

name="Studio Linux"
platform="Linux"
runnable=false
custom_features="studio"
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*, tools/*, docs/*, demo/*, build/*"
export_path=""

[preset.0.options]

binary_format/embed_pck=true

[preset.1]

name="Studio Android"
platform="Android"
runnable=false
custom_features="studio"
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*, tools/*, docs/*, demo/*, build/*"
export_path=""

[preset.1.options]

gradle_build/use_gradle_build=false
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=1
version/name="0.1.0"
package/unique_name="org.visualnovelstoryteller.studio"
package/name="StoryTeller Studio"
package/signed=true
screen/immersive_mode=true
PRESETS
fi

"$godot" --headless --path "$root" --import >/dev/null 2>&1
log="$(mktemp)"
if ! "$godot" --headless --path "$root" --export-debug "$preset" "$output" >"$log" 2>&1; then
	tail -n 30 "$log"
	echo "Export failed."
	rm -f "$log"
	exit 1
fi
grep -E "ERROR|WARNING" "$log" | grep -vE "ALSA|audio driver" | head -20
rm -f "$log"
echo "$output"
