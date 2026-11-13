#!/bin/sh
# Combat open layout at five sizes; reports only, never gates.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
log_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$log_dir"' EXIT HUP INT TERM
engine=${GODOT_BIN:-godot}
"$engine" --headless --path "$repo_root/game" --import >"$log_dir/import.log" 2>&1
code=$?
cat "$log_dir/import.log"
[ "$code" -eq 0 ] || exit 1
if grep -E 'ERROR:|SCRIPT ERROR:' "$log_dir/import.log"; then exit 1; fi
"$engine" --headless --path "$repo_root/game" --script res://benchmarks/run_scaling.gd >"$log_dir/scaling.log" 2>&1
code=$?
cat "$log_dir/scaling.log"
[ "$code" -eq 0 ] || exit 1
if grep -E 'ERROR:|SCRIPT ERROR:' "$log_dir/scaling.log"; then exit 1; fi
grep -Eq '^SCALING COMPLETE 5$' "$log_dir/scaling.log" || exit 1
