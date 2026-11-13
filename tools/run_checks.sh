#!/bin/sh
cd -- "$(dirname -- "$0")/.." || exit 1
sh tools/ensure_venv.sh || exit 1 # three gates call it, and two parallel venv builds can break each other
log_dir=$(mktemp -d) || exit 1
pids=""
trap 'rm -rf "$log_dir"' EXIT
trap 'kill $pids 2>/dev/null; exit 1' HUP INT TERM # shortcut: TERM stops the gates, not their children; start each gate in its own process group if that ever matters
gates="run_lint run_warnings run_python_checks run_shell_checks check_public"
for gate in $gates; do
	sh "tools/$gate.sh" >"$log_dir/$gate.log" 2>&1 &
	pids="$pids $!"
done
failed=""
# shellcheck disable=SC2086 # pids are numbers
set -- $pids
for gate in $gates; do
	if wait "$1"; then echo "PASS $gate"; else echo "FAIL $gate"; failed="$failed $gate"; fi
	shift
done
for gate in $failed; do
	echo "--- $gate ---"
	cat "$log_dir/$gate.log"
done
[ -z "$failed" ] || exit 1
echo "CHECKS PASSED 5"
