#!/bin/sh
[ "$#" -eq 2 ] || { echo "usage: sh tools/export_build.sh PRESET OUT_PATH" >&2; exit 2; }
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
# Godot resolves a relative export path against game/, not the caller's directory.
case "$2" in /*) out=$2 ;; *) out=$(pwd)/$2 ;; esac
mkdir -p "$(dirname -- "$out")" || exit 1
"${GODOT_BIN:-godot}" --headless --path "$repo_root/game" --export-release "$1" "$out" || exit 1
[ -e "$out" ] || { echo "export produced no file: $out" >&2; exit 1; }
