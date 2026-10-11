#!/usr/bin/env bash
# Runs the StoryTeller test suite headless.
#
# Usage:
#   GODOT_BIN=/path/to/godot tools/run_tests.sh [--filter=text]
#
# GODOT_BIN defaults to "godot" on the PATH.
set -uo pipefail

godot="${GODOT_BIN:-godot}"
root="$(cd "$(dirname "$0")/.." && pwd)"
import_log="$(mktemp)"
trap 'rm -f "$import_log"' EXIT

echo "Importing project with $("$godot" --version --headless 2>/dev/null | tail -n 1)"
"$godot" --headless --path "$root" --import >"$import_log" 2>&1
if grep -qE "SCRIPT ERROR|Parse Error" "$import_log"; then
	grep -E -A3 "SCRIPT ERROR|Parse Error" "$import_log"
	echo "Script errors found while importing the project."
	exit 1
fi

args=()
if [[ $# -gt 0 ]]; then
	args=(-- "$@")
fi
"$godot" --headless --path "$root" -s res://tests/run_tests.gd "${args[@]}"
