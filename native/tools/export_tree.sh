#!/bin/sh
# usage: sh native/tools/export_tree.sh <W1|W2|W3|R1|R2> [emcc=...]; prints the export folder.
tree=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd) || exit 1
work=${WARGRID_NATIVE_WORK:-$HOME/projects/wargrid-native-work}
case "$1" in
	W1) preset="Web Bench" ;;
	W2) preset="Web Bench Dlink" ;;
	R1) preset="Web Render Bench" ;;
	R2) preset="Web Render Bench Dlink" ;;
	W3) echo "W3 needs the placed extension: added by T7" >&2; exit 2 ;;
	*) echo "usage: sh native/tools/export_tree.sh <W1|W2|W3|R1|R2> [emcc=3.1.74|4.0.20]" >&2; exit 2 ;;
esac
name=$1
cd "$tree" || exit 1
short=$(git rev-parse --short HEAD) || exit 1
task=$(basename "$tree")
base=$work/exports/$task-$short
out=$base/$name
src=$base/$name-src
rm -rf "$out" "$src"; mkdir -p "$out" "$src" || exit 1
log=$base/$name.log
{ echo "tree $tree"; git rev-parse HEAD; git status --short; } > "$base/$name.git"
# Working tree copy, so uncommitted work is exported; never exports from the tree itself.
git ls-files -co --exclude-standard | while IFS= read -r f; do [ -e "$f" ] && printf '%s\n' "$f"; done | tar -cf - -T - | tar -xf - -C "$src" || exit 1
{
	pwd; git rev-parse --short HEAD; date
	"${GODOT_BIN:-godot}" --headless --path "$src/game" --import || echo "import exit $? (see native-sim-spike plan, Known trap, if an extension is present)"
	"${GODOT_BIN:-godot}" --headless --path "$src/game" --export-release "$preset" "$out/index.html"
	echo "export exit $?"
} > "$log" 2>&1
[ -e "$out/index.html" ] || { echo "export produced no index.html, see $log" >&2; exit 1; }
python3 "$tree/native/tools/fixhtml.py" "$out/index.html" || exit 1
case $name in
	W1|R1) [ ! -e "$out/index.side.wasm" ] || { echo "$name must not contain index.side.wasm" >&2; exit 1; } ;;
	*) [ -e "$out/index.side.wasm" ] || { echo "$name lacks index.side.wasm (wrong template variant?), see $log" >&2; exit 1; } ;;
esac
rm -rf "$src"
du -sk "$out" | awk '{print "export size KB: " $1}' >> "$log"
echo "$out"
