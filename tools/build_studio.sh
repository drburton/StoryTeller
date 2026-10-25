#!/usr/bin/env bash
# Builds a Visual Novel StoryTeller Studio app from this project: the block
# editor (studio/studio.tscn), with the tablet check (studio/check/) in its
# ⋯ menu. The demo's pictures and sounds ship as part of the starter library
# (studio/library/); its scenes, tales, and translations are left out.
#
# Usage:
#   GODOT_BIN=/path/to/godot tools/build_studio.sh <linux|android|web> <output-file>
#
# For the web, the output file is the page, such as build/studio-web/index.html;
# its folder then holds everything a web host needs (decision 0024).
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
	web) preset="Studio Web" ;;
	*) echo "Usage: tools/build_studio.sh <linux|android|web> <output-file>" >&2; exit 2 ;;
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
include_filter="studio/samples/*.txt, studio/templates/*.txt, studio/lessons/*.txt"
exclude_filter="tests/*, tools/*, docs/*, build/*, studio/lessons/screenshots.json, demo/tales/*, demo/translations/*, demo/embedded/*, demo/yarn/*, demo/demo.*, demo/story_config.tres"
export_path=""

[preset.0.options]

binary_format/embed_pck=true

[preset.1]

name="Studio Android"
platform="Android"
runnable=false
custom_features="studio"
export_filter="all_resources"
include_filter="studio/samples/*.txt, studio/templates/*.txt, studio/lessons/*.txt"
exclude_filter="tests/*, tools/*, docs/*, build/*, studio/lessons/screenshots.json, demo/tales/*, demo/translations/*, demo/embedded/*, demo/yarn/*, demo/demo.*, demo/story_config.tres"
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

[preset.2]

name="Studio Web"
platform="Web"
runnable=false
custom_features="studio"
export_filter="all_resources"
include_filter="studio/samples/*.txt, studio/templates/*.txt, studio/lessons/*.txt"
exclude_filter="tests/*, tools/*, docs/*, build/*, studio/lessons/screenshots.json, demo/tales/*, demo/translations/*, demo/embedded/*, demo/yarn/*, demo/demo.*, demo/story_config.tres"
export_path=""

[preset.2.options]

variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=true
progressive_web_app/enabled=true
progressive_web_app/display=1
progressive_web_app/orientation=1
progressive_web_app/background_color=Color(0.105882, 0.117647, 0.152941, 1)
PRESETS
fi

# The Studio edits a tale's text, but an export holds only the imported
# tale, so the sample's text ships as a plain copy (include_filter above).
samples="$root/studio/samples"
mkdir -p "$samples"
cp "$root/examples/wheres_biscuit/tales/wheres_biscuit.tale" "$samples/wheres_biscuit.tale.txt"
trap 'cleanup; rm -rf "$samples"' EXIT

"$godot" --headless --path "$root" --import >/dev/null 2>&1
log="$(mktemp)"
# The web build is the one a school hosts, so it is a release build.
mode="--export-debug"
if [[ $platform == web ]]; then mode="--export-release"; fi
if ! "$godot" --headless --path "$root" "$mode" "$preset" "$output" >"$log" 2>&1; then
	tail -n 30 "$log"
	echo "Export failed."
	rm -f "$log"
	exit 1
fi
grep -E "ERROR|WARNING" "$log" | grep -vE "ALSA|audio driver" | head -20
rm -f "$log"
echo "$output"
