# M5 verification

```text
Resume record (updated 2026-11-04, Task 3 done, at stop gate)
Branch / base commit / working-tree state: m5-online / 6111929 + Task 3 commit / clean after commit, nothing pushed
Last green task / next incomplete task: Task 3 / gate review of Task 3 (Opus, fresh context), then Task 4
Changed paths since last commit: none after the Task 3 commit
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh, 177 / 104,308 / 0 / 0 / TESTS PASSED 104308
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: Task 3 preflight rulings below. User playtest of M4.1 still pending. Railway investigation added as a later follow-up (user 2026-11-04, plan Task 11, design M9 list).
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: gate review (Opus, fresh context) of Task 3, then restart session; resume at Task 4 (relay)
```

## Evidence

| Item | Command | Result | Tree |
|---|---|---|---|
| Task 0 baseline | `sh tools/run_tests.sh` | 160 cases / 104,024 checks / 0 failures / exit 0, `TESTS PASSED 104024` | `m5-online` at `d66e4b1` clean |

Task 0 status check: README, AGENTS.md, blueprint §7 and session notes already say M4.1 is merged to `main` at `f2c5f9e` with the user playtest pending; no line says "not merged". No edits needed.

| Task 1 risk spike | Opus subagent, scratch scripts | Templates `Godot_v4.7.2-stable_export_templates.tpz` SHA-256 `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011` (matches GitHub asset digest). R1: exported macOS traces vs editor `REPLAYS MATCHED 1200` x3 (Linux/Windows wait for Task 6 CI). R2: user args work; `--script` ignored by release templates, so test builds use feature tag `wargrid_tests` with `run/main_loop_type` override to a `class_name WargridTestRunner` (verified in scratch copy: 160 / 104,030 / 0; add in Task 6). R3 EXCEEDED: SHA-256(var_to_bytes) p50/p95/p99 0.800/0.821/0.830 ms editor, 0.808 release (300 units, 188,852 bytes); JSON stringify+parse 50-command packet 0.063 / 0.063 ms p99. Opus follow-up: `Dictionary.hash()` 0.043 ms p99, all 5,418 contact leaves detected; user chose hash() plus core-field check. R4: 11 command types, 207 checks, 0 failures with `stringify(v, "", true, true)` | `m5-online` e12cde1 |

Task 1 preflight findings: `--script` unavailable in release templates; relative `--export-release` path resolves against `game/`; macOS export needs `bundle_identifier` and ETC2/ASTC import; Windows release exe is GUI subsystem (console wrapper preset set, unchecked on Windows); `_payload_fields` is an instance method, so Task 2/R4 hard-code the 11 command types. Windows console-wrapper output not verified.

Gate review (Task 1, Opus, fresh context, tree e12cde1): code ships; suite `TESTS PASSED 104024`, three exports from a fresh checkout succeed (macOS universal ad-hoc, Windows + console exe, Linux), template SHA-256 matches GitHub, `--script` hang reproduced. Plan fixes applied (docs only, rulings): word-wise FNV-1a (byte-wise 0.378 ms would break the 0.25 ms ceiling), exact core fields (`hp`, buildings excluded), NaN/inf handling, test-runner decision and exported-trace step moved into Task 6, `finish_tick(tick, state)` with a snapshot only on hash ticks (snapshot 0.375 ms p99), compare_replays tick-0 row and equal digest width, console exe for Windows, Task 1 Owns amended. Deferred minors: export_build.sh could pass on a stale output file (use `-nt` marker); `Wire.decode` should validate `hash.value` against `^[0-9a-f]{16}$` (Task 2); Task 7 Gatekeeper instruction (right-click Open) may be outdated on current macOS, check in Task 7; Task 8 must time snapshot plus digest on hash ticks or record the snapshot as a presentation cost.

| Task 2 hash + wire | `sh tools/run_tests.sh` | digest p99 0.136 ms (contact layout, 200 entities, <= 0.25), core_check 0.127 ms; 168 cases / 104,257 checks / 0 failures / exit 0. Pinned digest `15df35ca15bcc43b` (R1 world + player 1, one step); cross-platform equality awaits CI (Task 6). `JSON.parse_string` logs ERROR on bad input, so `Wire.decode` uses `JSON.new().parse`; `Wire.decode` validates `hash.value` as 16 lowercase hex (deferred minor from Task 1 gate). | `m5-online` |

Task 3 Opus preflight (15 findings, all accepted as rulings): (1) hash compare moved into `advance` when consuming the peer packet for tick t+delay (peer hash for t always meets own hash for t there); detection deterministic, both clients stop before stepping 64, report tick 60, latest hash-tick snapshot kept. (2) `finish_tick(tick)` takes `sim.tick()` after the step; `start` is finish_tick(0); peer last-received starts at delay-1. (3) `advance` returns false on `match_over`, no re-send. (4) seat scripts run once per sim tick, only when `can_step`. (5) test delivery order is preserved (delivery = max(previous, now + jitter)). (6) latency test clock = tick x 33,333 us set in the hook, so exactly 5 ticks. (7) cross-seat test runs all 11 x 11 type pairs (121) in one 1,640-tick match plus compares command_results every tick; **gap:** "building destroyed the same tick it is cancelled" is not arranged deterministically (cancel_build x attack pair only). (8) 300-id move uses 300 spawned infantry; sequence order checked on the peer's applied log; largest frame measured (cap boundary is Task 4). (9) run_tests registers test_lockstep. (10) relay `error` frame -> `ended_relay` with `end_reason()`; `welcome/start/pong` reaching `receive` -> `ended_protocol` (Task 5 transport must filter pong). (11) packet seat must be in `seats`. (12) `submit` deep-copies. (13) oracle uses `Skirmish.create(true, "human")`. (14) spec wording on prefill/hash cost to fix in docs at Task 11. (15) Task 5/7 must convert `start.seats` to `Array[int]` with `assign`.
Process note: Task 3 tests were written together with the implementation, not as a separately observed red run; the first run of the suite had two script-compile errors only, then 177 / 104,308 / 0. Suite exits 0; Lockstep closures that capture their owner form reference cycles (tests clear `send`/hooks; Task 5/7 owners must do the same).

| Task 3 lockstep core | `sh tools/run_tests.sh` | 177 cases / 104,308 checks / 0 failures / exit 0, `TESTS PASSED 104308`; offline `TERMINAL_TICK 10667 / WINNER 1` and replay traces untouched and green | `m5-online` |
