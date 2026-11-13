#!/bin/sh
cd "$(dirname -- "$0")/.." || exit 1
sh tools/ensure_venv.sh || exit 1
PATH="$PWD/tools/.venv/bin:$PATH" # the pinned gdtoolkit lives in the tools venv
exec gdlint game
