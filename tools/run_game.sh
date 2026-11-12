#!/bin/sh
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
# Shown in the playtest helper's build id; a failing git writes nothing. Removed on exit so a later direct launch shows no stale commit.
trap 'rm -f "$repo_root/game/build_commit.txt"' EXIT HUP INT TERM
if commit=$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null); then
	[ -z "$(git -C "$repo_root" status --porcelain)" ] || commit=$commit-dirty
	printf '%s\n' "$commit" > "$repo_root/game/build_commit.txt"
fi
[ "$#" -eq 0 ] && set -- res://scenes/launcher.tscn
"${GODOT_BIN:-godot}" --path "$repo_root/game" "$@"
