#!/bin/sh
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
log_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$log_dir"' EXIT HUP INT TERM
export LOG_DIR="$log_dir" GODOT_ENGINE="${GODOT_BIN:-godot}"
cd "$repo_root" || exit 1
count=$(git ls-files 'game/*.gd' | wc -l | tr -d ' ')
[ "$count" -gt 0 ] || { echo "no .gd files found" >&2; exit 1; }
# shellcheck disable=SC2016 # the sh -c body expands its own variables
git ls-files 'game/*.gd' | xargs -n1 -P4 sh -c '
	out="$LOG_DIR/$(echo "$1" | tr / _).log"
	"$GODOT_ENGINE" --headless --path game --check-only --verbose --script "res://${1#game/}" >"$out" 2>&1 || { cat "$out"; exit 255; }
' _ || exit 1
if cat "$log_dir"/*.log | grep -E -A1 'ERROR:'; then exit 1; fi
echo "WARNINGS CHECKED $count FILES"
