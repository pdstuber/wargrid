# Converted maps playable: verification

Plan: [converted maps playable plan](../superpowers/plans/2026-11-08-converted-maps-playable.md). Spec: [design](../superpowers/specs/2026-11-08-converted-maps-playable-design.md). Handoff: [converted maps prompt](../converted-maps-prompt.txt).

## Resume record

```text
Resume record (updated 2026-11-09)
Branch / base commit / working-tree state: converted-maps / ef9e698 / re-pin + converter cleanup uncommitted (test_team_match.gd, run_team_match.sh, tools/zh_map/{convert,test_zh_map}.py, more-maps.md, this file)
Last green task / next incomplete task: Task 3c committed / coordinator commits the re-pin and cleanup as two commits
Changed paths since last commit: game/tests/test_team_match.gd, tools/run_team_match.sh, tools/zh_map/convert.py, tools/zh_map/test_zh_map.py, docs/reference/more-maps.md, docs/reference/converted-maps-verification.md
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh / 573 / 136886 / 2 (Fm1 pair only) / 1 / no marker
Known red case or blocker: Fm1 pair (morning decision)
Approved decisions, pre-authorizations used, deferred gates: re-pin of slot-moved pins pre-approved 2026-11-08, used here
Usage so far: not run
Next exact action: coordinator commits; next task per plan
```

## Baseline

Tree for all rows: `07c3ab6` (clean, branch `converted-maps`, equal to `main`). Logs: `/Users/pdstuber/projects/wargrid-overnight-work/logs/t0-<name>.log`. Machine at start: load averages 14.4 / 10.4 / 4.5 at 22:07, 3.9 / 7.9 / 4.3 at 22:09 (an unrelated load burst had ended before the benchmark ran). No Godot process present at any point (`pgrep -fl godot` empty).

| Command | Result |
|---|---|
| `sh tools/run_tests.sh` | `CASES 559 CHECKS 136844 FAILURES 0`, `TESTS PASSED 136844`, exit 0 |
| `sh tools/run_lint.sh` | exit 0 |
| `sh tools/run_warnings.sh` | `WARNINGS CHECKED 114 FILES`, exit 0 |
| `sh tools/run_python_checks.sh` | `All checks passed!`, exit 0 |
| `sh tools/run_netplay.sh match` | `match terminal tick 8400`, `NETPLAY PASSED match 15.2 s`, exit 0 |
| `sh tools/run_conformance.sh` | `CONFORMANCE PASSED 33`, exit 0 |
| `go test -count=1 -race ./...` (in `relay/`) | `ok wargrid/relay 2.763s`, exit 0 (uncached; a cached run also passed) |
| `golangci-lint run` (in `relay/`) | `0 issues.`, exit 0 |
| `sh tools/run_benchmark.sh` (alone) | `BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1`, exit 0; hordes300 over budget (see Findings) |

## Rows

Append-only. One row per command: tree, counts, exit, marker, load averages.

| Date | Tree | Command | Counts | Exit | Marker | Load (1/5/15 min) | Partial |
|---|---|---|---|---|---|---|---|
| 2026-11-08 22:08 | 07c3ab6 | `sh tools/run_tests.sh` | CASES 559, CHECKS 136844, FAILURES 0 | 0 | TESTS PASSED 136844 | 14.4 / 10.4 / 4.5 (22:07) | no |
| 2026-11-08 22:08 | 07c3ab6 | `sh tools/run_lint.sh` | no problems found | 0 | Success: no problems found | 14.4 / 10.4 / 4.5 (22:07) | no |
| 2026-11-08 22:08 | 07c3ab6 | `sh tools/run_warnings.sh` | 114 files | 0 | WARNINGS CHECKED 114 FILES | 14.4 / 10.4 / 4.5 (22:07) | no |
| 2026-11-08 22:08 | 07c3ab6 | `sh tools/run_python_checks.sh` | n/a | 0 | All checks passed! | 14.4 / 10.4 / 4.5 (22:07) | no |
| 2026-11-08 22:09 | 07c3ab6 | `sh tools/run_netplay.sh match` | n/a | 0 | match terminal tick 8400; NETPLAY PASSED match | 3.9 / 7.9 / 4.3 (22:09) | no |
| 2026-11-08 22:09 | 07c3ab6 | `sh tools/run_conformance.sh` | n = 33 | 0 | CONFORMANCE PASSED 33 | 3.9 / 7.9 / 4.3 (22:09) | no |
| 2026-11-08 22:09 | 07c3ab6 | `go test -count=1 -race ./...` (relay/) | ok | 0 | ok wargrid/relay | 3.9 / 7.9 / 4.3 (22:09) | no |
| 2026-11-08 22:09 | 07c3ab6 | `golangci-lint run` (relay/) | 0 issues | 0 | 0 issues. | 3.9 / 7.9 / 4.3 (22:09) | no |
| 2026-11-08 22:09 | 07c3ab6 | `sh tools/run_benchmark.sh` (alone) | BENCHMARK 2, COMBAT 10, LOCKSTEP 1; hordes300 over budget | 0 | BENCHMARK PASSED 2; COMBAT BENCHMARK PASSED 10; LOCKSTEP BENCHMARK PASSED 1 | pre 3.9 / 7.9 / 4.3, post 2.9 / 7.2 / 4.1 | no |
| 2026-11-08 22:12 | aa9bea2 + Task 1 diff | `go test -count=1 -race ./...` (relay/) | ok | 0 | ok wargrid/relay | 1.9 / 4.2 / 3.6 (22:14) | no |
| 2026-11-08 22:12 | aa9bea2 + Task 1 diff | `golangci-lint run` (relay/) | 0 issues | 0 | 0 issues. | 1.9 / 4.2 / 3.6 (22:14) | no |
| 2026-11-08 22:13 | aa9bea2 + Task 1 diff | `sh tools/run_conformance.sh` | n = 39 (33 + 6 new) | 0 | CONFORMANCE PASSED 39 | 1.9 / 4.2 / 3.6 (22:14) | no |
| 2026-11-08 22:13 | aa9bea2 + Task 1 diff | `sh tools/run_tests.sh` | CASES 559, CHECKS 136859, FAILURES 0 | 0 | TESTS PASSED 136859 | 1.9 / 4.2 / 3.6 (22:14) | no |
| 2026-11-08 22:14 | aa9bea2 + Task 1 diff | `sh tools/run_lint.sh` / `run_warnings.sh` | 114 files | 0 / 0 | WARNINGS CHECKED 114 FILES | 1.9 / 4.2 / 3.6 (22:14) | no |
| 2026-11-08 22:14 | aa9bea2 + Task 1 diff | `sh tools/run_netplay.sh match` | n/a | 0 | match terminal tick 8400; NETPLAY PASSED match | 1.9 / 4.2 / 3.6 (22:14) | no |
| 2026-11-08 22:40 | 90cb4a5 + Task 2 diff | `sh tools/run_tests.sh` (run twice, SS6 identical both times) | CASES 566, CHECKS 136868, FAILURES 0 | 0 | TESTS PASSED 136868 | n/a | no |
| 2026-11-08 22:41 | 90cb4a5 + Task 2 diff | `sh tools/run_lint.sh` / `run_warnings.sh` | 114 files | 0 / 0 | Success: no problems found; WARNINGS CHECKED 114 FILES | n/a | no |
| 2026-11-08 23:10 | b609404 + Task 3 diff | `sh tools/run_tests.sh` | CASES 571, CHECKS 136880, FAILURES 0 | 0 | TESTS PASSED 136880 | n/a | no |
| 2026-11-08 23:11 | b609404 + Task 3 diff | `sh tools/run_lint.sh` / `run_warnings.sh` | 116 files | 0 / 0 | WARNINGS CHECKED 116 FILES | n/a | no |
| 2026-11-08 23:12 | b609404 + Task 3 diff | `sh tools/run_netplay.sh match` | n/a | 0 | match terminal tick 8400; NETPLAY PASSED match | n/a | no |
| 2026-11-08 23:45 | 32e780d + Task 3b diff | `sh tools/run_tests.sh` | CASES 572, CHECKS 136883, FAILURES 7 (pins only) | 1 | none | n/a | no |
| 2026-11-08 23:48 | 32e780d + Task 3b diff | `sh tools/run_team_match.sh` | `TEAM MATCH won tick=38510 winner=2 units_peak=207` | 1 | pin mismatch | n/a | no |
| 2026-11-08 23:49 | 32e780d + Task 3b diff | `sh tools/run_netplay.sh match` | terminal tick 8300 | 1 | NETPLAY FAILED match: terminal tick 8300, pinned 8400 | n/a | no |
| 2026-11-08 23:50 | 32e780d + Task 3b diff | `sh tools/run_lint.sh` / `run_warnings.sh` | 116 files | 0 / 0 | WARNINGS CHECKED 116 FILES | n/a | no |
| 2026-11-09 00:15 | 32e780d + Task 3b diff + review fix | `sh tools/run_tests.sh` | CASES 573, CHECKS 136886, FAILURES 7 (same pins, same values) | 1 | none | n/a | no |
| 2026-11-09 00:18 | same | lint / warnings / `run_netplay.sh match` / `run_team_match.sh` | 116 files; terminal 8300; `won tick=38510 winner=2 units_peak=207` | 0 / 0 / 1 / 1 | pin mismatches only, identical to 23:48-23:49 | n/a | no |

## Task 1 RED

Tree `aa9bea2` plus new vectors and tests, production code unchanged.

- `sh tools/run_conformance.sh` against the protocol-1 relay: `FAIL settings_echoed_byte_exact: bad welcome "{\"type\":\"error\",\"reason\":\"protocol mismatch\"}"`; `CONFORM default: 36 cases, 34 failed`.
- `go test ./...` in `relay/`: build failed, `envelope_test.go:57:137: e.settings undefined (type *envelope has no field or method settings)` (compile error instead of the first `TestParseRules` failure, because the new test reads `e.settings`).
- Suite: `FAIL: W2 rejects start without seed` (and 7 more W2/W3 lines), `CASES 559 CHECKS 136858 FAILURES 8`.

## Findings for the morning

Choices the plan made that the user did not decide (plan "Execution rules for this run"):

1. Map dropdown on its own row, although the design says "next to the faction dropdowns". Reason: F5 caps that row at 520 px.
2. Offline Restart keeps the same starts.
3. The relay checks that `settings` is a JSON object of at most 4096 bytes, although "Decided" says it copies `settings` without reading it. Reason: clients require a Dictionary, and the 65,536-byte frame cap applies to `start`.
4. Godot's "Complying with licenses" page may also ask for third-party notices (`Engine.get_copyright_info()`). Not verified. "Decided" names only `Engine.get_license_text()`.

Baseline facts for later tasks:

5. `COMBAT hordes300` is over its budget on main HEAD: p95 2.84 ms, p99 3.33 ms, against 1.82 / 3.64 ms. `run_benchmark.sh` still reports `BENCHMARK PASSED` because the regression ceiling p95/p99 is [3.07, 4.05]. Recorded as exceeded, not loosened. Ledger context: [performance ledger](performance.md) (its Deck Firefox p95 verdict already lists hordes300 as the one row over 10 ms).
6. The relay `go test` baseline was run uncached (`-count=1`); the first run reported `(cached)`.

### Task 1 review minors (Opus, APPROVE)
- Settings not-object/over-cap fail at parse level, so they get "invalid message" before the protocol check (protocol 3 + `"settings":"x"`). Plan asks for it; morning decision.
- `"settings":null` untested in TestParseRules (mutant dropping `&& obj != nil` survives).
- TestParseRules uses 4098 bytes, not 4097; conformance covers the boundary.
- test_wire W3 `files.size() >= 15` but 16 vectors; should be `>= 16`.
- conformance `expectStart` uses Atoi, accepts `"seed":+5`.

## Task 2 RED and SS6 derivation

- RED (tree `90cb4a5`, stub `assign` returning `[1, 2]`): `FAIL: SS2 each later one the free start with the largest summed straight-line distance to the taken ones`; `CASES 566 CHECKS 136868 FAILURES 8`.
- SS6 derivation: first GREEN run, tree `90cb4a5` + Task 2 diff, macOS (Apple Silicon), Ashfall 1v1 seeds 0..15 printed `8-4,2-6,3-7,5-1,6-2,2-6,7-3,4-8,1-5,3-7,2-6,6-2,6-2,8-4,6-2,5-1`; only SS6 failed (empty literal), SS1-SS5 and SS7 passed. Literal pinned; two later full runs matched. Linux and Windows confirmation by CI is still open (user exit-gate item).

### Task 2 review minors (Opus, APPROVE)
- `team <= 0` (no team) rule untested (ZH Ashfall teams [0,0]); add before M9.
- SS3 does not prove "summed": Ashfall teams [1,2,3,4], chosen [1,4,0,0] gives [1,4,7,5]; max-of-nearest gives [1,4,7,2].
- SS6 pins only an 8-start map; draw sequence for 3/6-start maps unpinned.
- No guard for more slots than starts or an off-map chosen seat (unreachable tonight).

## Task 3 RED

Parse-level RED only: with the new tests and no production code, `run_tests.sh` exit 1 with `Parse Error: Too many arguments for "create()" call. Expected at most 4 but received 5.` and `Static function "with_starts()" not found in base "res://scripts/simulation/map_data.gd"`. A stub-level run (so SK-S1 could fail by assertion) did not compile either (unused-parameter warnings are errors), so the SK-S1 assertion line was never observed failing.

### Task 3 review (Opus, APPROVE)
- RED gap closed by reviewer: mutant with `if false:` around with_starts fails all 3 SK-S1 checks, both SK-S3 checks and SK-S4 ("diagonal: 74.0").
- Minors: bot wave `_rally` untested; off-map starts in create push_error then crash in MapData.create({}) (add `return null`); repeated seats / length != 2 unguarded; SK-S1 checks unit and building as one bool.

## Task 3b RED

Tree `32e780d` + new test and the faction key (FRC 7, no `_produce` change): `FAIL: SK-C1 a USA bot runs two collectors per supply center, got 1`; also `SK-C2 ... got 1`, `SK-C4 ... got 0`; `CASES 572 CHECKS 136883 FAILURES 3`.

## Task 3b moved pins

All failures after the change are pins; old values are the committed constants (equal to the Task 3 green run). Cause check against Task 3 commit not re-run: Task 3b touches only its Owns files.

| Pin | Old | New | Command |
|---|---|---|---|
| `test_skirmish_match.gd` TERMINAL_TICK (S1) | 8501, winner 1 | 8452, winner 1 | `run_tests.sh` "S1 pinned outcome, got 8452" |
| `test_skirmish_match.gd` S1_CORE_SERIES | 8576069817585818203 | 8642905752227994667 | "S1 core series pinned" |
| `test_skirmish_match.gd` CHINA_TERMINAL_TICK (Cs1) | 26359, winner 2 | 27555, winner 2 | "Cs1 pinned outcome" |
| `test_skirmish_match.gd` FRC_TERMINAL_TICK (Fm1) | 23534, winner 1 | no win by cap 45000 (status ongoing, terminal -1) | "Fm1 ... ends won inside the cap" and "pinned outcome" |
| `test_team_match.gd` FINAL_DIGEST (TB3) | 020f659e77ee6c20 | 1c2a5905802d4d9b | "TB3 final digest" |
| `test_team_match.gd` TEAM_CORE_SERIES (TB4) | 7692526877276561850 | 205812011678164261 | "TB4 team core series pinned" |
| `run_team_match.sh` | cap tick=45000 winner=null units_peak=160 | won tick=38510 winner=2 units_peak=207 | `sh tools/run_team_match.sh` |
| `run_netplay.sh match` terminal tick | 8400 | 8300 | `sh tools/run_netplay.sh match` |

Note for the re-pin: Fm1 no longer ends within its cap (FRC 5 laborers per cache instead of 7 slows the economy); re-pinning needs a larger cap or a decision, not just a number. Replay traces: no other suite failure.

## Task 3b review fix

RED (fix removed, new tests present): `FAIL: SK-C5 two supply centers, a USA bot owns exactly 4, got 5` and `... China bot owns exactly 6, got 7`; `FAILURES 9` (7 pins + 2). Fix: `_produce` counts collectors queued in any depot. SK-C3 now pins faction values (USA 2, China 3, FRC 5); stale test renamed to `test_bot_keeps_one_builder_four_gatherers`. Single-depot pins unmoved.

Fm1 cause per reviewer (plausible, not a bug; morning decision): the USA second helicopter drives USA income 41475 vs about 20000; map runs out of supply near t=30000; FRC wins at t=73560. USA1+FRC5 ends 26611, USA2+FRC7 ends 42951.

## Task 3b re-pin

Tree `b3e4824` + re-pin diff. Cause for all: collectors per supply center USA 2, China 3, FRC 5 (Task 3b). Old values as in "Task 3b moved pins".

| Pin | Old | New |
|---|---|---|
| S1 `TERMINAL_TICK` | 8501 | 8452 (winner 1) |
| S1 `S1_CORE_SERIES` | 8576069817585818203 | 1809165491953682337 (the moved-pins table said 8642905752227994667, measured before the review fix; the suite reports 1809165491953682337, same on two runs) |
| Cs1 `CHINA_TERMINAL_TICK` | 26359 | 27555 (winner 2) |
| `FINAL_DIGEST` | 020f659e77ee6c20 | 1c2a5905802d4d9b |
| `TEAM_CORE_SERIES` | 7692526877276561850 | 205812011678164261 |
| `run_team_match.sh` | cap tick=45000 winner=null units_peak=160 | won tick=38510 winner=2 units_peak=207 (stale waiver comment replaced) |
| `run_netplay.sh match` | 8400 | 8300 |

Fm1 untouched, still red. Rows: `run_tests.sh` `CASES 573 CHECKS 136886 FAILURES 2` (Fm1 pair), exit 1, no marker; `run_lint.sh` exit 0; `run_warnings.sh` `WARNINGS CHECKED 116 FILES` exit 0; `run_netplay.sh match` `terminal tick 8300`, `NETPLAY PASSED match 14.5 s`; `run_team_match.sh` `TEAM MATCH won tick=38510 winner=2 units_peak=207` exit 0.

### Coordinator note on S1_CORE_SERIES
The moved-pins table value 8642905752227994667 was measured with TERMINAL_TICK 8501 (series loop runs `TERMINAL_TICK + 1` ticks). With TERMINAL_TICK 8452 the correct pin is 1809165491953682337 (cause check: clean `git archive` of b3e4824 reproduces 8642905752227994667 under the old tick constant). Fm1 pair remains the only known red case.

## Task 3c

RED (convert.py change stashed, new tests present): `AssertionError: Lists differ: [12, 16] != [16, 14]` (test_supply_center_slot_nearest_supply) and `AssertionError: 19.525624189766635 not less than 19.5 : dry_wells seat 2`.

GREEN: converter tests `Ran 21 tests ... OK`; `run_python_checks.sh` exit 0. Maps regenerated from `CnC_Modding_Support` at `3aad8e4`; `git diff --stat` shows only the three maps (slot lines only) and `skirmish.json` unchanged. Ashfall seat 1 `supply_center` [23,128] -> [9,139]. After distances in `more-maps.md`.

Moved pins (not re-pinned; no other pin moved: S1, Cs1, test_map, test_supply Pl3 pass):

| Pin | Old | New |
|---|---|---|
| `FINAL_DIGEST` (TB3) | 1c2a5905802d4d9b | b1c0606ee2bb58fc |
| `TEAM_CORE_SERIES` (TB4) | 205812011678164261 | 7949105010122908522 |
| `run_team_match.sh` | won tick=38510 winner=2 units_peak=207 | cap tick=45000 winner=null units_peak=246 (exit 1: the script expects a win) |

Ashfall movement layout: scratch `MovementWorkload.create("ashfall")` spawned all 300 move-only units, exit 0, no assertion.

Rows: tree `1c26efe` + 3c diff. `run_tests.sh` `CASES 573 CHECKS 136886 FAILURES 4`, exit 1, no marker; `run_lint.sh` exit 0; `run_warnings.sh` `WARNINGS CHECKED 116 FILES` exit 0; `run_team_match.sh` as above; `run_netplay.sh match` not run (skirmish.json unchanged). Logs: `wargrid-overnight-work/logs/t3c-*.log`.

## Task 3c re-pin and cleanup

Re-pinned, each verified by running: `FINAL_DIGEST` 1c2a5905802d4d9b -> b1c0606ee2bb58fc, `TEAM_CORE_SERIES` 205812011678164261 -> 7949105010122908522, `run_team_match.sh` `won tick=38510 winner=2 units_peak=207` -> `cap tick=45000 winner=null units_peak=246`. The Ashfall 3v3 team match ends at the cap with no winner again (it was a win at tick 38510 after Task 3b). Cause: the Task 3c supply center slot move changed the start layout and so the bots' economy and fight.

Cleanup: two converter tests added (`test_supply_center_slot_ignores_small_piles`, `test_supply_center_slot_tie_takes_first_in_ring_scan`). RED with the delete_when_empty filter removed: `AssertionError: Tuples differ: (14, 17) != (22, 14)`. The tie test pins Ashfall-like geometry (equal-distance sites [8,16] and [9,16]; ring scan order picks x 8); it passed as written, since the tie rule is the existing `min` behaviour. `convert.py`: no-dock fallback replaced by `ConvertError("no supply dock")` (untested before, no shipped map or test needs it) and `SOURCE_W/SOURCE_H` replace `docks[0].get("footprint")`. Maps regenerated from `CnC_Modding_Support` `3aad8e4`: all three byte-identical. `more-maps.md`: Dry Wells seat 1 before is 27.2 (plan said 28.3); the moved slots are `supply_center`, `barracks`, `factory`, `command_center` on every seat, `power_plant` and `defence` unchanged. Duplicate fence fixed.

Rows: tree `ef9e698` + diff. `run_tests.sh` `CASES 573 CHECKS 136886 FAILURES 2` (Fm1 pair), exit 1, no marker; `run_lint.sh` exit 0; `run_warnings.sh` `WARNINGS CHECKED 116 FILES` exit 0; `run_python_checks.sh` exit 0; `run_team_match.sh` `TEAM MATCH cap tick=45000 winner=null units_peak=246` exit 0. Load 1.8. Logs: `wargrid-overnight-work/logs/t3c-repin-*.log`.
