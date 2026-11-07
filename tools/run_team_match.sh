#!/bin/sh
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
log_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$log_dir"' EXIT HUP INT TERM
engine=${GODOT_BIN:-godot}
"$engine" --headless --path "$repo_root/game" --import >"$log_dir/import.log" 2>&1 || { cat "$log_dir/import.log"; exit 1; }
"$engine" --headless --path "$repo_root/game" --script res://benchmarks/run_team_match.gd >"$log_dir/match.log" 2>&1
code=$?
cat "$log_dir/match.log"
[ "$code" -eq 0 ] || exit 1
if grep -E 'ERROR:|SCRIPT ERROR:' "$log_dir/match.log"; then exit 1; fi
# User waiver 2026-11-07: the three-faction match ends at the cap with no winner (docs/reference/m7-verification-archive-gate3.md, G3.5 record).
grep -Eq '^TEAM MATCH cap tick=45000 winner=null units_peak=160$' "$log_dir/match.log" || exit 1
