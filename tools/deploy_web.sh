#!/bin/sh
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
rm -rf "$repo_root/web/site" || exit 1
sh "$repo_root/tools/export_build.sh" Web "$repo_root/web/site/index.html" || exit 1
cp "$repo_root/LICENSE" "$repo_root/game/data/maps/NOTICE.md" "$repo_root/web/site/" || exit 1
"${GODOT_BIN:-godot}" --headless --script "$repo_root/tools/godot_licenses.gd" -- "$repo_root/web/site/GODOT_LICENSES.txt" || exit 1
fly deploy "$repo_root/web" -c "$repo_root/web/fly.toml" -a wargrid-web --dockerfile "$repo_root/web/Dockerfile" --ha=false
