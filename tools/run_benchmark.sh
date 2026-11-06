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
"$engine" --headless --path "$repo_root/game" --script res://benchmarks/run_movement.gd >"$log_dir/tests.log" 2>&1
code=$?
cat "$log_dir/tests.log"
[ "$code" -eq 0 ] || exit 1
if grep -E 'ERROR:|SCRIPT ERROR:' "$log_dir/tests.log"; then exit 1; fi
grep -Eq '^BENCHMARK PASSED 2$' "$log_dir/tests.log" || exit 1
"$engine" --headless --path "$repo_root/game" --script res://benchmarks/run_combat.gd >"$log_dir/combat.log" 2>&1
code=$?
cat "$log_dir/combat.log"
[ "$code" -eq 0 ] || exit 1
if grep -E 'ERROR:|SCRIPT ERROR:' "$log_dir/combat.log"; then exit 1; fi
grep -Eq '^COMBAT BENCHMARK PASSED 8$' "$log_dir/combat.log" || exit 1
[ "$(grep -c '^COMBAT BUDGET PASS ' "$log_dir/combat.log")" -eq 2 ] || exit 1
"$engine" --headless --path "$repo_root/game" --script res://benchmarks/run_lockstep.gd >"$log_dir/lockstep.log" 2>&1
code=$?
cat "$log_dir/lockstep.log"
[ "$code" -eq 0 ] || exit 1
if grep -E 'ERROR:|SCRIPT ERROR:' "$log_dir/lockstep.log"; then exit 1; fi
grep -Eq '^LOCKSTEP BENCHMARK PASSED 1$' "$log_dir/lockstep.log" || exit 1
[ "$(grep -c '^LOCKSTEP BUDGET PASS ' "$log_dir/lockstep.log")" -eq 1 ] || exit 1
