#!/bin/sh
# usage: run_netplay.sh match|kill|stall|silent|spike|perturb|version|relay-down|relay-term
scenario=$1
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
out=${NETPLAY_OUT:-$(mktemp -d)}
mkdir -p "$out" || exit 1
client=${WARGRID_CLIENT:-"godot --headless --path $repo_root/game"}
relay_bin=$WARGRID_RELAY_BIN
port=$(${PYTHON:-python3} -c 'import socket;s=socket.socket();s.bind(("",0));print(s.getsockname()[1])')
url=${WARGRID_RELAY_URL:-ws://127.0.0.1:$port/ws}
remote=${WARGRID_RELAY_URL:+1}
pids=""
started=$(${PYTHON:-python3} -c 'import time;print(time.time())')

cleanup() { for p in $pids; do kill -9 "$p" 2>/dev/null; done; }
trap cleanup EXIT HUP INT TERM
fail() { echo "NETPLAY FAILED $scenario: $*"; echo "logs: $out"; exit 1; }
ms() { ${PYTHON:-python3} -c 'import time;print(int(time.time()*1000))'; }

start_relay() {
  [ -z "$remote" ] || return 0
  if [ -z "$relay_bin" ]; then
    relay_bin=$out/relay
    (cd "$repo_root/relay" && go build -o "$relay_bin" .) || fail "relay build failed"
  fi
  env PORT=$port "$@" "$relay_bin" >"$out/relay.log" 2>&1 &
  relay_pid=$!
  pids="$pids $relay_pid"
  i=0
  until curl -sf "http://127.0.0.1:$port/health" >/dev/null; do
    i=$((i + 1)); [ $i -lt 100 ] || fail "relay did not start"
    sleep 0.2
  done
}

# start_client NAME ARGS...: logs to $out/NAME.log, pid in $pid
start_client() {
  name=$1; shift
  # shellcheck disable=SC2086
  $client -- --netclient --relay "$url" --uncapped --hash-log "$out/$name.tsv" --command-log "$out/$name.cmd" --report-dir "$out" "$@" >"$out/$name.log" 2>&1 &
  pid=$!
  pids="$pids $pid"
}

start_pair() { # EXTRA_SEAT1 ... -- EXTRA_SEAT2 ...
  rm -f "$out/code"
  start_client s1 --match new --code-file "$out/code" --seat-script human $1
  pid1=$pid
  i=0
  until [ -s "$out/code" ]; do
    i=$((i + 1)); [ $i -lt 100 ] || fail "no match code"
    sleep 0.2
  done
  start_client s2 --match "$(cat "$out/code")" --seat-script opponent $2
  pid2=$pid
}

wait_exit() { # PID SECONDS
  i=0; limit=$(($2 * 5))
  while kill -0 "$1" 2>/dev/null; do
    i=$((i + 1)); [ $i -lt $limit ] || fail "pid $1 still running after $2 s"
    sleep 0.2
  done
}

end_line() { grep '^NETCLIENT END' "$out/$1.log" | tail -n 1; }
log_ms() { grep "^NETCLIENT $2" "$out/$1.log" | tail -n 1 | awk '{print $NF}'; }
expect_end() { # NAME STATUS
  line=$(end_line "$1")
  case "$line" in "NETCLIENT END $2 TICK "*) ;; *) fail "$1: expected END $2, got '$line'" ;; esac
}
end_tick() { end_line "$1" | awk '{print $5}'; }
same_hashes() { ${PYTHON:-python3} "$repo_root/tools/compare_replays.py" --interval 30 --rows 0 "$@" >/dev/null || fail "hash logs differ: $*"; }

oracle() {
  # shellcheck disable=SC2086
  $client -- --netclient --replay-log "$out/s1.cmd" --hash-log "$out/oracle.tsv" >"$out/oracle.log" 2>&1 || fail "oracle failed"
  expect_end oracle match_over
}

[ -z "$remote" ] || [ "$scenario" = match ] || fail "WARGRID_RELAY_URL supports only match"
match_wait=${WARGRID_MATCH_WAIT:-180}

case $scenario in
  match)
    start_relay; start_pair "" ""
    wait_exit "$pid1" "$match_wait"; wait_exit "$pid2" "$match_wait"
    expect_end s1 match_over; expect_end s2 match_over
    [ "$(end_tick s1)" = "$(end_tick s2)" ] || fail "terminal ticks differ"
    [ "$(end_tick s1)" = 9989 ] || fail "terminal tick $(end_tick s1), pinned 9989"
    oracle; same_hashes "$out/s1.tsv" "$out/s2.tsv" "$out/oracle.tsv"
    echo "match terminal tick $(end_tick s1)" ;;
  kill)
    start_relay; start_pair "" "--exit-at-tick 600"
    wait_exit "$pid1" 60
    expect_end s1 ended_left
    [ "$(end_tick s1)" -ge 600 ] || fail "seat 1 ended before tick 600" ;;
  stall)
    start_relay; start_pair "" "--stall-at-tick 300 --stall-seconds 3"
    wait_exit "$pid1" 180; wait_exit "$pid2" 180
    expect_end s1 match_over; expect_end s2 match_over
    grep -q '^NETCLIENT STALL' "$out/s2.log" || fail "stall hook never ran"
    same_hashes "$out/s1.tsv" "$out/s2.tsv" ;;
  silent)
    start_relay; start_pair "" "--stall-at-tick 300 --stall-seconds 15"
    wait_exit "$pid1" 40
    expect_end s1 ended_left
    gap=$(($(log_ms s1 TIME) - $(log_ms s2 STALL)))
    [ "$gap" -le 12000 ] || fail "left took $gap ms after the stall started"
    echo "left announced $gap ms after stall start" ;;
  spike)
    start_relay WARGRID_TEST_DELAY_MS=200
    start_pair "--stop-at-tick 900" "--stop-at-tick 900"
    wait_exit "$pid1" 120; wait_exit "$pid2" 120
    expect_end s1 stopped; expect_end s2 stopped
    same_hashes "$out/s1.tsv" "$out/s2.tsv" ;;
  perturb)
    start_relay; start_pair "" "--perturb-at-tick 40"
    wait_exit "$pid1" 60; wait_exit "$pid2" 60
    expect_end s1 ended_desync; expect_end s2 ended_desync
    ${PYTHON:-python3} - "$out" <<'PY' || fail "desync report tick is not 60"
import json, sys
for seat in (1, 2):
    assert json.load(open(f"{sys.argv[1]}/desync-seat{seat}.json"))["tick"] == 60
PY
    diff_out=$(${PYTHON:-python3} "$repo_root/tools/desync_diff.py" "$out/desync-seat1.json" "$out/desync-seat2.json")
    [ $? -eq 1 ] || fail "desync_diff should exit 1"
    case "$diff_out" in *players*) ;; *) fail "desync_diff did not name players: $diff_out" ;; esac
    echo "$diff_out" ;;
  version)
    start_relay; start_pair "" "--build other"
    wait_exit "$pid2" 30
    expect_end s2 ended_relay
    case "$(end_line s2)" in *"build mismatch") ;; *) fail "seat 2 reason: $(end_line s2)" ;; esac
    kill -0 "$pid1" 2>/dev/null || fail "seat 1 should still be waiting"
    ! grep -q '^NETCLIENT END' "$out/s1.log" || fail "seat 1 ended"
    kill -9 "$pid1" ;;
  relay-down|relay-term)
    drain_ms=500
    start_relay WARGRID_DRAIN_MS=$drain_ms; start_pair "" ""
    sleep 2
    if [ "$scenario" = relay-down ]; then kill -9 "$relay_pid"; stop_limit=2000; else kill -TERM "$relay_pid"; stop_limit=$((drain_ms + 2000)); fi
    down=$(ms)
    wait_exit "$pid1" 20; wait_exit "$pid2" 20
    for name in s1 s2; do
      echo "$name: $(end_line $name) $(($(log_ms $name TIME) - down)) ms after relay stop"
      expect_end $name ended_relay
      [ "$(end_tick $name)" -gt 0 ] || fail "$name never started the match"
      [ $(($(log_ms $name TIME) - down)) -le $stop_limit ] || fail "$name took too long"
    done
    if [ "$scenario" = relay-term ] && [ -z "$remote" ]; then
      wait "$relay_pid" || fail "relay exited $? on SIGTERM"
      grep -q 'MATCH END' "$out/relay.log" || fail "relay logged no MATCH END on SIGTERM"
    fi ;;
  *) fail "unknown scenario" ;;
esac
echo "NETPLAY PASSED $scenario $(${PYTHON:-python3} -c "import time;print(round(time.time()-$started,1))") s"
