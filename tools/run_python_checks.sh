#!/bin/sh
cd "$(dirname -- "$0")" || exit 1
sh ensure_venv.sh || exit 1
[ -d .venv/bin ] && PATH="$PWD/.venv/bin:$PATH" # one venv holds ruff, mypy, numpy and scipy
ruff format --check . && ruff check . && mypy . && sh run_python_tests.sh
