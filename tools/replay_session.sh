#!/bin/sh
# usage: replay_session.sh SESSION_FILE [--tick N]
# Replays each match of a playtest session headless; --tick N prints that tick's state and writes snapshots next to the file.
file=$1
[ -f "$file" ] || { echo "usage: replay_session.sh SESSION_FILE [--tick N]"; exit 2; }
tick=""
[ "$2" = "--tick" ] && tick=$3
file=$(CDPATH= cd -- "$(dirname -- "$file")" && pwd)/$(basename -- "$file")
stem=${file%.json}
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
client=${WARGRID_CLIENT:-"godot --headless --path $repo_root/game"}
log=$(mktemp) || exit 1
trap 'rm -f "$log"' EXIT HUP INT TERM
rows=$(${PYTHON:-python3} "$repo_root/tools/playtest_session.py" --replay-args "$file") || exit 1
status=0
tab=$(printf '\t')
while IFS=$tab read -r k cmd mode map seed factions end_tick end_digest marker_ticks; do
	set -- --replay-log "$cmd" --map "$map" --seed "$seed" --oracle-ticks "$end_tick"
	[ "$factions" = "-" ] || set -- "$@" --factions "$factions"
	state_ticks=$marker_ticks
	if [ -n "$tick" ]; then
		state_ticks=$tick
		set -- "$@" --snapshot-dir "$stem-m$k-snapshots"
	fi
	[ "$state_ticks" = "-" ] || set -- "$@" --state-ticks "$state_ticks"
	# shellcheck disable=SC2086
	$client -- --netclient "$@" >"$log" 2>&1
	grep '^ORACLE STATE' "$log"
	replayed=$(sed -n 's/^ORACLE FINAL [0-9]* //p' "$log")
	if [ -z "$replayed" ]; then
		echo "REPLAY FAILED $k ($mode): no ORACLE FINAL line"
		grep -E 'ERROR|SCRIPT|Unknown|needs' "$log" | head -5
		status=1
	elif [ "$replayed" = "$end_digest" ]; then
		echo "REPLAY MATCHED $k"
	else
		echo "REPLAY DIFFERS $k recorded=$end_digest replayed=$replayed"
		status=1
	fi
done <<EOF2
$rows
EOF2
exit $status
