#!/usr/bin/env bash
# Builds the Studio for the web and checks it in Chromium (decision 0024):
# the page loads, a story made from a template keeps its tale and pictures
# after the page is loaded again, and it opens in the blocks and the map
# and plays (studio/web/web_check.gd, tools/studio_web/check.js).
#
# Usage:
#   GODOT_BIN=/path/to/godot tools/check_studio_web.sh [screenshot-folder] [web-folder]
#
# Give a web folder to keep the web build: put its files on any web host.
#
# Needs Godot's web export template (web_nothreads_release.zip), Python 3
# to serve the page, and Node.js with the playwright package and its
# Chromium. CHROMIUM may name a Chromium to use instead.
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
shots="${1:-$work/shots}"
web="${2:-$work/web}"
mkdir -p "$shots"
server=""
cleanup() {
	if [[ -n "$server" ]]; then kill "$server" 2>/dev/null; fi
	rm -rf "$work"
}
trap cleanup EXIT

echo "Building the Studio for the web..."
if ! "$root/tools/build_studio.sh" web "$web/index.html" >"$work/build.log" 2>&1; then
	tail -n 20 "$work/build.log"
	exit 1
fi

port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$web" >"$work/server.log" 2>&1 &
server=$!
sleep 1

echo "Opening it in Chromium..."
if node "$root/tools/studio_web/check.js" "http://127.0.0.1:$port/index.html" "$shots"; then
	echo "Studio web check passed. Screenshots: $shots"
else
	echo "Studio web check failed. Screenshots: $shots"
	exit 1
fi
