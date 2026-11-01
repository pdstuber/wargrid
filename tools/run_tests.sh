#!/bin/sh
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
log_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$log_dir"' EXIT HUP INT TERM
engine=${GODOT_BIN:-godot}
"$engine" --headless --path "$repo_root/game" --import >"$log_dir/import.log" 2>&1
code=$?
cat "$log_dir/import.log"
[ "$code" -eq 0 ] || exit 1
if grep -E 'ERROR:|SCRIPT ERROR:' "$log_dir/import.log"; then exit 1; fi
"$engine" --headless --path "$repo_root/game" --script res://tests/run_tests.gd >"$log_dir/tests.log" 2>&1
code=$?
cat "$log_dir/tests.log"
[ "$code" -eq 0 ] || exit 1
if grep -E 'ERROR:|SCRIPT ERROR:' "$log_dir/tests.log"; then exit 1; fi
grep -Eq '^TESTS PASSED [1-9][0-9]*$' "$log_dir/tests.log" || exit 1
