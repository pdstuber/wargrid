#!/bin/sh
cd "$(dirname -- "$0")" || exit 1
ruff format --check . && ruff check . && mypy .
