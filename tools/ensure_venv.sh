#!/bin/sh
# Creates tools/.venv with the pinned dev tools on first use; no-op when it exists.
tools=$(cd -- "$(dirname -- "$0")" && pwd) || exit 1
py="$tools/.venv/bin/python3"
[ -x "$py" ] && exit 0
fail() { echo "ensure_venv: $1" >&2; exit 1; }
command -v uv >/dev/null 2>&1 || fail "uv not found; install it (brew install uv) or run: python3.12 -m venv tools/.venv && tools/.venv/bin/pip install -r tools/requirements-dev.txt"
uv venv -q --python 3.12 "$tools/.venv" || fail "uv venv --python 3.12 tools/.venv failed"
# Remove a half-built venv so the next run retries instead of trusting it.
uv pip install -q --python "$py" -r "$tools/requirements-dev.txt" || { rm -rf "$tools/.venv"; fail "uv pip install -r tools/requirements-dev.txt failed"; }
