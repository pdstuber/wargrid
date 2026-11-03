#!/bin/sh
# Compares this machine's replay traces with the Linux and Windows traces of one CI run.
# macOS is checked locally because hosted macOS runners repeatedly failed to start within the job timeout.
[ "$#" -eq 1 ] || { echo "usage: sh tools/compare_local_traces.sh RUN_ID" >&2; exit 2; }
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT HUP INT TERM
gh run download "$1" --repo pdstuber/wargrid -n replay-linux -n replay-windows -D "$work/ci" || exit 1
WARGRID_REPLAY_TRACE="$work/replay-local.tsv" WARGRID_ECONOMY_REPLAY_TRACE="$work/economy-local.tsv" WARGRID_COMBAT_REPLAY_TRACE="$work/combat-local.tsv" \
	sh "$repo_root/tools/run_tests.sh" >"$work/tests.log" 2>&1 || { tail -20 "$work/tests.log"; exit 1; }
for scenario in replay economy combat; do
	printf '%s: ' "$scenario"
	python3 "$repo_root/tools/compare_replays.py" "$work/ci/replay-linux/$scenario-linux.tsv" "$work/ci/replay-windows/$scenario-windows.tsv" "$work/$scenario-local.tsv" || exit 1
done
