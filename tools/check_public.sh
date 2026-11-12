#!/bin/sh
# usage: check_public.sh — fails when tracked files carry private detail or working files (AGENTS.md, public repository rule).
# Prints PUBLIC CHECK PASSED or the offending lines and exits 1.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
cd "$repo_root" || exit 1
status=0

working=$(git ls-files 'docs/*-prompt.txt' 'docs/session-notes*.md')
if [ -n "$working" ]; then
  echo "$working"
  echo "PUBLIC CHECK FAILED: working files are tracked; they belong in the private notes repository"
  status=1
fi

home_path='/Users/[A-Za-z]'
hostname='[A-Za-z0-9]+(-[A-Za-z0-9]+)+\.local([^A-Za-z0-9.-]|$)'
lan_address='(^|[^0-9.])(10\.[0-9]{1,3}|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}([^0-9.]|$)'
session_id='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
scratch_path='claude-[0-9]+/|\.claude/projects/-'
personal_mail='@(gmail|googlemail|outlook|hotmail|icloud|yahoo|proton|protonmail|gmx)\.[a-z]+'
if git grep -nIE "$home_path|$hostname|$lan_address|$session_id|$scratch_path|$personal_mail" -- . ':(exclude)tools/check_public.sh'; then
  echo "PUBLIC CHECK FAILED: home path, hostname, LAN address, session id, scratch path or personal mail address in tracked files"
  status=1
fi

# Personal words would themselves be a leak here, so the list lives outside the repository and CI runs without it.
words=${WARGRID_PRIVATE_WORDS:-$HOME/projects/wargrid-private/public-denylist.txt}
if [ -s "$words" ] && git grep -nIiE -f "$words" -- .; then
  echo "PUBLIC CHECK FAILED: word from the private list in tracked files"
  status=1
fi

[ "$status" -ne 0 ] || echo "PUBLIC CHECK PASSED"
exit "$status"
