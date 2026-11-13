#!/bin/sh
# Creates tools/.venv with the pinned dev tools, or updates it after requirements-dev.txt changes.
tools=$(cd -- "$(dirname -- "$0")" && pwd) || exit 1
py="$tools/.venv/bin/python3"
req="$tools/requirements-dev.txt"
stamp="$tools/.venv/requirements-dev.txt"
[ -x "$py" ] && cmp -s "$req" "$stamp" && exit 0
fail() { echo "ensure_venv: $1" >&2; exit 1; }
command -v uv >/dev/null 2>&1 || fail "uv not found; install it (brew install uv) or run: python3.12 -m venv tools/.venv && tools/.venv/bin/pip install -r tools/requirements-dev.txt"
fresh=0
if [ ! -x "$py" ]; then
  uv venv -q --python 3.12 "$tools/.venv" || fail "uv venv --python 3.12 tools/.venv failed"
  fresh=1
fi
if ! uv pip install -q --python "$py" -r "$req"; then
  # Remove only a half-built venv; an existing one still works with its old pins.
  [ "$fresh" = 1 ] && rm -rf "$tools/.venv"
  fail "uv pip install -r tools/requirements-dev.txt failed"
fi
cp "$req" "$stamp"
