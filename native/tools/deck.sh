#!/bin/sh
# usage: sh native/tools/deck.sh <push FOLDER LABEL | run LABEL QUERY TIMEOUT [noiso] | fetch LABEL | clean [LABEL]>
# Exit 3 "DECK DOWN" when the address file is missing or the Deck does not answer; exit 4 "NO RESULT" on a timeout.
tree=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd) || exit 1
work=${WARGRID_NATIVE_WORK:-$HOME/projects/wargrid-native-work}
[ -s "$work/deck-address.txt" ] || { echo "DECK DOWN (no deck-address.txt)"; exit 3; }
addr=$(cat "$work/deck-address.txt")
deck() { ssh -o BatchMode=yes -o ConnectTimeout=5 "deck@$addr" "$@"; }
deck true >/dev/null 2>&1 || { echo "DECK DOWN ($addr does not answer)"; exit 3; }
dir=wargrid-native
cmd=$1; shift
case $cmd in
push)
	[ "$#" -eq 2 ] || { echo "usage: deck.sh push FOLDER LABEL" >&2; exit 2; }
	deck "mkdir -p ~/$dir/$2/site ~/$dir/$2/results" || exit 1
	tar --no-xattrs -C "$1" -cf - . | deck "tar -xf - -C ~/$dir/$2/site" || exit 1
	deck "cat > ~/$dir/serve_web_bench.py" < "$tree/tools/serve_web_bench.py" || exit 1
	;;
run)
	[ "$#" -ge 3 ] || { echo "usage: deck.sh run LABEL QUERY TIMEOUT [noiso]" >&2; exit 2; }
	deck sh -s -- "$dir" "$1" "$2" "$3" "$4" <<'REMOTE'
dir=$1; label=$2; query=$3; limit=$4; noiso=$5
root=$HOME/$dir/$label
port=8061
ffapp=$HOME/.var/app/org.mozilla.firefox
profile=$ffapp/wgn-profile-$label
unit=wgn-$label
cleanup() {
	systemctl --user stop "$unit-srv" "$unit-ff" >/dev/null 2>&1
	pkill -f -- "$profile" 2>/dev/null
	rm -rf "$profile"
}
trap cleanup EXIT
python3 - "$port" <<'PY' || { echo "port $port in use"; exit 1; }
import socket, sys
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind(("127.0.0.1", int(sys.argv[1])))
PY
echo "START $(date +%s) acad=$(cat /sys/class/power_supply/ACAD/online) load=$(cut -d' ' -f1-3 /proc/loadavg)"
mkdir -p "$profile"
{
	echo 'user_pref("browser.aboutwelcome.enabled", false);'
	echo 'user_pref("browser.shell.checkDefaultBrowser", false);'
	echo 'user_pref("browser.startup.homepage_override.mstone", "ignore");'
	echo 'user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);'
	echo 'user_pref("devtools.console.stdout.content", true);'
	cat "$ffapp"/config/mozilla/firefox/*/prefs.js 2>/dev/null | grep termsofuse
} > "$profile/user.js"
systemd-run --user --quiet --unit="$unit-srv" python3 -I "$HOME/$dir/serve_web_bench.py" "$root/site" "$root/results" "$port" ${noiso:+--no-isolation}
n=0; until curl -s -o /dev/null "http://127.0.0.1:$port/"; do n=$((n+1)); [ $n -gt 50 ] && { echo "server did not start"; exit 1; }; sleep 0.2; done
inhibit=; command -v kde-inhibit >/dev/null && inhibit="kde-inhibit --power --screenSaver"
systemd-run --user --quiet --unit="$unit-ff" $inhibit flatpak run org.mozilla.firefox -no-remote -new-instance -profile "$profile" "http://127.0.0.1:$port/index.html?$query"
t=0
while [ $t -lt "$limit" ]; do
	if grep -qsE 'BENCH DONE|RENDERED BENCHMARK PASSED|BENCH FAILED|^JSERR' "$root"/results/*.log; then
		echo "END $(date +%s) load=$(cut -d' ' -f1-3 /proc/loadavg)"; exit 0
	fi
	sleep 2; t=$((t+2))
done
echo "NO RESULT"; exit 4
REMOTE
	;;
fetch)
	[ "$#" -eq 1 ] || { echo "usage: deck.sh fetch LABEL" >&2; exit 2; }
	mkdir -p "$work/results/$1"
	deck "tar -C ~/$dir/$1/results -cf - ." | tar -xf - -C "$work/results/$1" || exit 1
	;;
clean)
	# Only what the runs created: our units, our profiles and our folder.
	deck "systemctl --user stop 'wgn-*' >/dev/null 2>&1; rm -rf ~/.var/app/org.mozilla.firefox/wgn-profile-* ~/$dir/${1:-}; pkill -f 'org.mozilla.firefox.*wgn-profile' 2>/dev/null; true"
	[ -n "$1" ] || deck "rmdir ~/$dir 2>/dev/null; true"
	;;
*) echo "usage: deck.sh <push|run|fetch|clean> ..." >&2; exit 2 ;;
esac
