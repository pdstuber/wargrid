#!/bin/sh
# usage: sh native/tools/build.sh <mac|web|linux|all|place|remove> [emcc=3.1.74|4.0.20]
# Outputs per tree in WORK/build/<tree>/, so parallel task trees never overwrite each other.
native=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
tree=$(dirname "$native")
game="$tree/game"
work=/Users/pdstuber/projects/wargrid-native-work
out="$work/build/$(basename "$tree")"
logs="$work/logs/$(basename "$tree")"
emcc_version=3.1.74
for arg in "$@"; do case "$arg" in emcc=*) emcc_version=${arg#emcc=} ;; esac; done
web_features=godot/experimental-wasm,godot/experimental-wasm-nothreads,godot/lazy-function-tables
mkdir -p "$out" "$logs"

web_target_dir() {
	case "$emcc_version" in
		3.1.74) echo "$native/target" ;;
		4.0.20) echo "$native/target/emcc-4.0.20" ;;
		*) return 1 ;;
	esac
}

build_mac() {
	(cd "$native" && cargo build --release --workspace) || return 1
	mkdir -p "$out/mac" && cp "$native/target/release/libwargrid_native.dylib" "$native/target/release/wargrid_runner" "$out/mac/"
}

build_web() {
	target_dir=$(web_target_dir) || { echo "unknown emcc=$emcc_version"; return 1; }
	case "$emcc_version" in
		3.1.74) env_script="$HOME/emsdk/emsdk_env.sh" ;;
		4.0.20) env_script="$work/emsdk-4.0.20/emsdk_env.sh" ;;
	esac
	# Sourced in a subshell: never `emsdk activate`, never leak the environment into later steps.
	(
		. "$env_script" >/dev/null 2>&1 || exit 1
		emcc --version | head -1
		cd "$native" && CARGO_TARGET_DIR="$target_dir" cargo build --release -p wargrid_native --features "$web_features" -Zbuild-std --target wasm32-unknown-emscripten
	) || return 1
	mkdir -p "$out/web-$emcc_version" && cp "$target_dir/wasm32-unknown-emscripten/release/wargrid_native.wasm" "$out/web-$emcc_version/"
}

build_linux() {
	mkdir -p "$out/linux" "$work/build/linux-registry"
	container run --rm --platform linux/amd64 -e RUSTUP_TOOLCHAIN=1.94.1 -e CARGO_TARGET_DIR=/out/target \
		-v "$native":/src -v "$out/linux":/out -v "$work/build/linux-registry":/usr/local/cargo/registry -w /src \
		docker.io/library/rust:1.94-slim sh -c 'cargo build --release -p wargrid_core -p wargrid_runner -p wargrid_native && cargo test -p wargrid_core && cargo tree -p wargrid_core'
}

import_game() {
	godot --headless --path "$game" --import >"$logs/import-$1.log" 2>&1
}

write_gdextension() {
	{
		printf '[configuration]\nentry_symbol = "gdext_rust_init"\ncompatibility_minimum = 4.7\nreloadable = false\n\n[libraries]\n'
		for platform in $1; do
			case "$platform" in
				macos) file=libwargrid_native.dylib ;;
				web.wasm32) file=wargrid_native.wasm ;;
				linux.x86_64) file=libwargrid_native.so ;;
			esac
			key_prefix=${platform%%.*}
			key_suffix=${platform#"$key_prefix"}
			printf '%s.debug%s = "res://native_bin/%s"\n%s.release%s = "res://native_bin/%s"\n' "$key_prefix" "$key_suffix" "$file" "$key_prefix" "$key_suffix" "$file"
		done
	} >"$game/wargrid_native.gdextension"
}

place() {
	rm -rf "$game/native_bin" && mkdir -p "$game/native_bin"
	platforms=""
	if [ -f "$native/target/release/libwargrid_native.dylib" ]; then
		cp "$native/target/release/libwargrid_native.dylib" "$game/native_bin/" && platforms="$platforms macos"
	fi
	wasm="$(web_target_dir)/wasm32-unknown-emscripten/release/wargrid_native.wasm"
	if [ -f "$wasm" ]; then cp "$wasm" "$game/native_bin/" && platforms="$platforms web.wasm32"; fi
	if [ -f "$out/linux/target/release/libwargrid_native.so" ]; then
		cp "$out/linux/target/release/libwargrid_native.so" "$game/native_bin/" && platforms="$platforms linux.x86_64"
	fi
	[ -n "$platforms" ] || { echo "PLACE FAILED nothing built"; return 1; }
	write_gdextension "$platforms"
	# Known trap: the first editor import that sees a new extension may crash (exit 134); the second must pass.
	import_game place-1
	first=$?
	import_game place-2 || { echo "PLACE FAILED second import exit $? (log $logs/import-place-2.log)"; return 1; }
	echo "PLACED$platforms first_import_exit=$first second_import_exit=0"
}

remove() {
	rm -f "$game/wargrid_native.gdextension" "$game/wargrid_native.gdextension.uid"
	rm -rf "$game/native_bin"
	list="$game/.godot/extension_list.cfg"
	if [ -f "$list" ]; then
		grep -v 'wargrid_native.gdextension' "$list" >"$list.tmp"
		mv "$list.tmp" "$list"
	fi
	import_game remove || { echo "REMOVE FAILED import exit $? (log $logs/import-remove.log)"; return 1; }
	echo "REMOVED"
}

case "${1:-}" in
	mac) build_mac ;;
	web) build_web ;;
	linux) build_linux ;;
	all) build_mac && build_web && build_linux ;;
	place) place ;;
	remove) remove ;;
	*) echo "usage: sh native/tools/build.sh <mac|web|linux|all|place|remove> [emcc=3.1.74|4.0.20]"; exit 2 ;;
esac
