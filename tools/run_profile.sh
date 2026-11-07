#!/bin/sh
# Headless profiling zones per scenario; reports only, never gates.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
log_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$log_dir"' EXIT HUP INT TERM
engine=${GODOT_BIN:-godot}
"$engine" --headless --path "$repo_root/game" --import >"$log_dir/import.log" 2>&1
code=$?
cat "$log_dir/import.log"
[ "$code" -eq 0 ] || exit 1
if grep -E 'ERROR:|SCRIPT ERROR:' "$log_dir/import.log"; then exit 1; fi
"$engine" --headless --path "$repo_root/game" --script res://benchmarks/run_profile.gd >"$log_dir/profile.log" 2>&1
code=$?
cat "$log_dir/profile.log"
[ "$code" -eq 0 ] || exit 1
if grep -E 'ERROR:|SCRIPT ERROR:' "$log_dir/profile.log"; then exit 1; fi
grep -Eq '^PROFILE COMPLETE 10$' "$log_dir/profile.log" || exit 1
