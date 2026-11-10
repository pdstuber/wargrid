#!/bin/sh
# usage: sh native/tools/web_run.sh <mac|deck> <firefox|safari|vivaldi> <export folder> <query string> <label> [timeout s] [noiso]
# Exit codes: 0 result with BENCH DONE, 2 usage, 3 DECK DOWN, 4 NO RESULT, 5 BROWSER BUSY, 6 LOCKED, 7 PAGE ERROR, 8 BENCH FAILED.
[ "$#" -ge 5 ] || { sed -n 2,3p "$0" >&2; exit 2; }
host=$1 browser=$2 folder=$3 query=$4 label=$5 limit=${6:-900} noiso=$7
tree=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd) || exit 1
work=${WARGRID_NATIVE_WORK:-$HOME/projects/wargrid-native-work}
results=$work/results/$label
mkdir -p "$work/locks" "$results" || exit 1
lock=$work/locks/$host
srv=; bpid=; started_app=

# A lock whose pid is dead is taken over; noclobber makes the creation atomic.
if ! ( set -C; echo $$ > "$lock" ) 2>/dev/null; then
	if kill -0 "$(cat "$lock" 2>/dev/null)" 2>/dev/null; then echo "LOCKED by pid $(cat "$lock")"; exit 6; fi
	rm -f "$lock"
	( set -C; echo $$ > "$lock" ) 2>/dev/null || { echo "LOCKED"; exit 6; }
fi

cleanup() {
	[ -n "$bpid" ] && kill "$bpid" 2>/dev/null
	[ -n "$srv" ] && kill "$srv" 2>/dev/null
	case $started_app in
		Safari) osascript -e 'tell application "Safari" to quit' >/dev/null 2>&1 ;;
		Vivaldi) osascript -e 'tell application "Vivaldi" to quit' >/dev/null 2>&1 ;;
	esac
	[ "$host" = deck ] && sh "$tree/native/tools/deck.sh" clean "$label" >/dev/null 2>&1
	rm -rf "$work/profiles/run-$label"
	rm -f "$lock"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

verdict() { # classify the logs in $results
	if grep -qs '^JSERR' "$results"/*.log; then echo "PAGE ERROR"; return 7; fi
	if grep -qs 'BENCH FAILED' "$results"/*.log; then echo "BENCH FAILED"; return 8; fi
	if grep -qsE 'BENCH DONE|RENDERED BENCHMARK PASSED' "$results"/*.log; then echo "OK"; return 0; fi
	echo "NO RESULT"; return 4
}

if [ "$host" = deck ]; then
	[ "$browser" = firefox ] || { echo "the Deck runs Firefox only" >&2; exit 2; }
	deckctl() { sh "$tree/native/tools/deck.sh" "$@"; }
	deckctl push "$folder" "$label" || exit $?
	{ echo "host=deck label=$label query=$query"; date; } > "$results/run.txt"
	deckctl run "$label" "$query" "$limit" $noiso >> "$results/run.txt" 2>&1; rc=$?
	deckctl fetch "$label"
	if [ $rc = 3 ]; then echo "DECK DOWN"; exit 3; fi
	if [ $rc = 4 ]; then # retried once: the Deck may have slept or blanked its screen
		deckctl clean "$label" >/dev/null 2>&1
		deckctl push "$folder" "$label" && deckctl run "$label" "$query" "$limit" $noiso >> "$results/run.txt" 2>&1; rc=$?
		deckctl fetch "$label"
		[ $rc = 4 ] && { echo "NO RESULT twice: treating the Deck as down"; echo "DECK DOWN"; exit 3; }
	fi
	verdict; exit $?
fi
[ "$host" = mac ] || { echo "host must be mac or deck" >&2; exit 2; }

port=8060
if lsof -nP -iTCP:$port -sTCP:LISTEN >/dev/null 2>&1; then echo "port $port in use"; exit 1; fi
case $browser in
	firefox) ;;
	safari) app=Safari ;;
	vivaldi) app=Vivaldi ;;
	*) echo "browser must be firefox, safari or vivaldi" >&2; exit 2 ;;
esac
if [ -n "$app" ]; then
	if pgrep -x "$app" >/dev/null; then echo "BROWSER BUSY ($app was already running)"; exit 5; fi
	started_app=$app
fi

{ echo "host=mac browser=$browser label=$label query=$query folder=$folder"; date; uptime; sw_vers -productVersion; ps -Ao pcpu,comm -r | head -3; } > "$results/run.txt"
python3 -I "$tree/tools/serve_web_bench.py" "$folder" "$results" "$port" ${noiso:+--no-isolation} > "$results/server.log" 2>&1 &
srv=$!
n=0; until curl -s -o /dev/null "http://127.0.0.1:$port/index.html"; do
	n=$((n+1)); [ $n -gt 50 ] && { echo "server did not start"; exit 1; }; sleep 0.2
done
url="http://127.0.0.1:$port/index.html?$query"
case $browser in
	firefox)
		profile=$work/profiles/run-$label
		rm -rf "$profile"; cp -R "$work/profiles/firefox-accepted" "$profile" || exit 1
		printf '%s\n' 'user_pref("browser.aboutwelcome.enabled", false);' 'user_pref("browser.shell.checkDefaultBrowser", false);' 'user_pref("devtools.console.stdout.content", true);' >> "$profile/user.js"
		/Applications/Firefox.app/Contents/MacOS/firefox -no-remote -new-instance -profile "$profile" "$url" > "$results/browser.log" 2>&1 &
		bpid=$! ;;
	vivaldi)
		/Applications/Vivaldi.app/Contents/MacOS/Vivaldi --user-data-dir="$work/profiles/run-$label" --no-first-run --no-default-browser-check --enable-logging=stderr "$url" > "$results/browser.log" 2>&1 &
		bpid=$! ;;
	safari) open -a Safari "$url" ;;
esac
t=0
while [ $t -lt "$limit" ]; do
	if grep -qsE 'BENCH DONE|RENDERED BENCHMARK PASSED|BENCH FAILED|^JSERR' "$results"/web-*.log; then break; fi
	sleep 2; t=$((t+2))
done
{ date; uptime; } >> "$results/run.txt"
verdict; exit $?
