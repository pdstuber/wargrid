#!/bin/sh
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
[ "$#" -eq 0 ] && set -- res://scenes/skirmish.tscn
exec "${GODOT_BIN:-godot}" --path "$repo_root/game" "$@"
