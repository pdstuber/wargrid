#!/bin/sh
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
exec "${GODOT_BIN:-godot}" --path "$repo_root/game" "$@"
