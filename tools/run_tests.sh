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
shards=${WARGRID_TEST_SHARDS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}
[ "$shards" -ge 1 ] 2>/dev/null || { echo "FAIL: WARGRID_TEST_SHARDS must be a number >= 1"; exit 1; }
[ "$shards" -gt 4 ] && shards=4 # measured: 8 shards are no faster than 4, the slowest case bounds the run
pids=""
i=0
while [ "$i" -lt "$shards" ]; do
	"$engine" --headless --path "$repo_root/game" --script res://tests/run_tests.gd -- --shard="$i/$shards" >"$log_dir/tests.$i.log" 2>&1 &
	pids="$pids $!"
	i=$((i + 1))
done
status=0
i=0
for pid in $pids; do
	wait "$pid" || status=1
	grep -Ev '^(CASES|TESTS PASSED) ' "$log_dir/tests.$i.log"
	i=$((i + 1))
done
if cat "$log_dir"/tests.*.log | grep -E 'ERROR:|SCRIPT ERROR:' >/dev/null; then status=1; fi
cat "$log_dir"/tests.*.log | awk -v shards="$shards" -v status="$status" '
	/^CASES / { cases += $2; checks += $4; failures += $6; done++ }
	END {
		print "CASES " cases " CHECKS " checks " FAILURES " failures
		if (done != shards) print "FAIL: " shards - done " of " shards " shards did not finish"
		else if (status == 0 && failures == 0 && checks > 0) print "TESTS PASSED " checks
	}' >"$log_dir/summary.log"
cat "$log_dir/summary.log"
grep -Eq '^TESTS PASSED [1-9][0-9]*$' "$log_dir/summary.log" || exit 1
