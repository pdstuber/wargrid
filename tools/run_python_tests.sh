#!/bin/sh
cd "$(dirname -- "$0")/.." || exit 1
py=tools/.venv/bin/python3
[ -x "$py" ] || py=python3
status=0
tests=$(git ls-files 'tools/*test_*.py' | grep -v 'test_install_godot.py') # that one downloads Godot; CI runs it
[ -n "$tests" ] || { echo "FAIL: no Python tests found"; exit 1; }
for t in $tests; do
	out=$("$py" "$t" 2>&1) || { echo "FAIL: $t"; echo "$out"; status=1; }
done
out=$("$py" tools/zh_parity/analyze.py --self-test 2>&1) || { echo "FAIL: analyze.py --self-test"; echo "$out"; status=1; }
[ "$status" -eq 0 ] && echo "PYTHON TESTS PASSED"
exit "$status"
