#!/bin/sh
cd "$(dirname -- "$0")/.." || exit 1
[ -d tools/.venv/bin ] && PATH="$PWD/tools/.venv/bin:$PATH" # the pinned ShellCheck wheel lives in the tools venv
git ls-files -z '*.sh' | xargs -0 shellcheck
