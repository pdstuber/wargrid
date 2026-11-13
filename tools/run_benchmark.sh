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
[ "$(grep -c '^BUDGET PASS ' "$log_dir/tests.log")" -eq 2 ] || exit 1
[ "$(grep -c '^WORST TICK ' "$log_dir/tests.log")" -eq 2 ] || exit 1
"$engine" --headless --path "$repo_root/game" --script res://benchmarks/run_combat.gd >"$log_dir/combat.log" 2>&1
code=$?
cat "$log_dir/combat.log"
[ "$code" -eq 0 ] || exit 1
if grep -E 'ERROR:|SCRIPT ERROR:' "$log_dir/combat.log"; then exit 1; fi
grep -Eq '^COMBAT BENCHMARK PASSED 10$' "$log_dir/combat.log" || exit 1
[ "$(grep -c '^COMBAT BUDGET PASS ' "$log_dir/combat.log")" -eq 7 ] || exit 1
[ "$(grep -c '^WORST TICK ' "$log_dir/combat.log")" -eq 10 ] || exit 1
"$engine" --headless --path "$repo_root/game" --script res://benchmarks/run_lockstep.gd >"$log_dir/lockstep.log" 2>&1
code=$?
cat "$log_dir/lockstep.log"
[ "$code" -eq 0 ] || exit 1
if grep -E 'ERROR:|SCRIPT ERROR:' "$log_dir/lockstep.log"; then exit 1; fi
grep -Eq '^LOCKSTEP BENCHMARK PASSED 1$' "$log_dir/lockstep.log" || exit 1
[ "$(grep -c '^LOCKSTEP BUDGET PASS ' "$log_dir/lockstep.log")" -eq 1 ] || exit 1
[ "$(grep -c '^WORST TICK ' "$log_dir/lockstep.log")" -eq 1 ] || exit 1
over=$(cat "$log_dir"/*.log | sed -n 's/^OVER BUDGET \([^ ]*\) .*/\1/p' | tr '\n' ' ')
[ -z "$over" ] || echo "BUDGET EXCEEDED ${over% } (regression ceilings held)"

record_perf() {
	cat "$log_dir/tests.log" "$log_dir/combat.log" "$log_dir/lockstep.log" >"$log_dir/all.log"
	cd "$repo_root" || return 1
	[ "${PERF_RECORD:-1}" = 0 ] && return 0
	python3 tools/perf_record.py "$log_dir/all.log" --auto ${PERF_LABEL:+--label "$PERF_LABEL"} || return 1
	python3 tools/perf_chart.py
}
record_perf || echo "perf: WARNING recording or charts failed (benchmark result unaffected)"
exit 0
