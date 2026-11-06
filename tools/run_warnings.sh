#!/bin/sh
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
log=$(mktemp) || exit 1
trap 'rm -f "$log"' EXIT HUP INT TERM
engine=${GODOT_BIN:-godot}
cd "$repo_root" || exit 1
count=0
for file in $(git ls-files 'game/*.gd'); do
	count=$((count + 1))
	"$engine" --headless --path game --check-only --verbose --script "res://${file#game/}" >>"$log" 2>&1 || { cat "$log"; exit 1; }
done
if grep -E -A1 'ERROR:' "$log"; then exit 1; fi
[ "$count" -gt 0 ] || { echo "no .gd files found" >&2; exit 1; }
echo "WARNINGS CHECKED $count FILES"
