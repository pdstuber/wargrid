#!/bin/sh
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
version=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' "$repo_root/game/project.godot")
refuse() { echo "deploy_web: $1 needs $2, config/version is \"$version\"" >&2; exit 1; }
# The relay only pairs equal build strings, so a -dev version keeps test players out of production rooms.
case "$1" in
	'') app=wargrid-web health=https://wargrid.pdstuber.dev/health
		case "$version" in '' | *-*) refuse production "a release version" ;; esac ;;
	test) app=wargrid-web-test health=https://wargrid-web-test.fly.dev/health
		case "$version" in *-*) ;; *) refuse test "a prerelease version such as 0.7.0-dev" ;; esac ;;
	*) echo "usage: sh tools/deploy_web.sh [test]" >&2; exit 1 ;;
esac
rm -rf "$repo_root/web/site" || exit 1
sh "$repo_root/tools/export_build.sh" Web "$repo_root/web/site/index.html" || exit 1
cp "$repo_root/LICENSE" "$repo_root/game/data/maps/NOTICE.md" "$repo_root/web/site/" || exit 1
"${GODOT_BIN:-godot}" --headless --script "$repo_root/tools/godot_licenses.gd" -- "$repo_root/web/site/GODOT_LICENSES.txt" || exit 1
fly deploy "$repo_root/web" -c "$repo_root/web/fly.toml" -a "$app" --dockerfile "$repo_root/web/Dockerfile" --ha=false || exit 1
curl -fsS --retry 10 --retry-delay 6 --retry-all-errors "$health"
