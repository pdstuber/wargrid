#!/bin/sh
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
rm -rf "$repo_root/web/site" || exit 1
sh "$repo_root/tools/export_build.sh" Web "$repo_root/web/site/index.html" || exit 1
fly deploy "$repo_root/web" -c "$repo_root/web/fly.toml" -a wargrid-web --dockerfile "$repo_root/web/Dockerfile" --ha=false
