# Converted maps playable: verification

Plan: [converted maps playable plan](../superpowers/plans/2026-11-08-converted-maps-playable.md). Spec: [design](../superpowers/specs/2026-11-08-converted-maps-playable-design.md). Handoff: converted maps prompt (`converted-maps-prompt.txt`, private).

## Resume record

```text
Resume record (updated 2026-11-09, final checks green on 9ed2331; docs-only edits uncommitted)
Branch / base commit / working-tree state: converted-maps / f1747db / morning fixes and final-review fixes uncommitted (more-maps sweep table regenerated, blueprint, development, relay-stack-spike, this file, run_team_match.sh comment, test_online_scene.gd N19 labels)
Implemented: Tasks 1, 2, 3, 3b, 3c, 4, 5, 6, 6b, 7, 8, 9, 10 (committed through 026f2b2); final-review fixes (uncommitted)
Verified on 882f182 plus the uncommitted re-pin: suite 600 / 137167 / 0 failures, TESTS PASSED, run_team_match.sh 0, run_netplay match PASSED (tick 9024), lint 0, warnings see Morning fixes re-pin section; credits fixes (answers 11, 12) on top: suite 604 / 137289 / 0, lint 0, warnings 120 files 0, python checks 0 (see Morning fixes credits); test gaps and replay fields (answers 13, 15) on top: suite 609 / 137297 / 0, lint 0, warnings 120 files 0, netplay match, maps, map-mismatch, perturb PASSED (see Morning fixes test gaps); credits test gaps and seed home on top: suite 609 / 137307 / 0, lint 0, warnings 120 files 0, run_netplay match tick 9024 and perturb PASSED (see Morning fixes credits gaps and seed home); report-field gaps on top: suite 609 / 137307 / 0, lint 0, warnings 120 files 0, run_netplay perturb and match PASSED (see Morning fixes report-field gaps)
Morning fixes done: relay protocol first, wave targeting, re-pin (Fm1 included), credits, test gaps, replay fields, credits gaps, seed home, report-field gaps
Pending: user items in the plan's "Left for the user" (relay deploy, push and CI, merge, playtest, Fm1 decision); Done-when "attack on Ashfall" open (M8)
Known red case or blocker: none; wave-fix pins and Fm1 re-pinned (uncommitted); ashfall bot matches slower with the answer-20 retarget (see Morning fixes)
Approved decisions, pre-authorizations used, deferred gates: none new
Usage so far: not run
Final checks (9ed2331): all green, see Final checks 2026-11-09; docs updated for Fm1 green, wave fix, conformance 41, match tick 9024
Next exact action: user reviews the uncommitted docs diff, then commit approval; then push, CI, relay deploy, playtest
Final-review fixes: sweep table in more-maps regenerated from t8-sweep.log (pairs lost their second value) and its judgement corrected (Dry Wells usa,usa is a cap, not a loss; range of first damage excludes frc,frc); Ashfall attack check (open, M8); blueprint status names Fm1; development.md entry above; relay-stack-spike eleven scenarios; N19 labels; run_team_match.sh waiver pointer restored; go test and golangci-lint rows lose the sh prefix
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
| 2026-11-08 23:31 | 2dc1a6c + Task 5 diff (before review fixes) | `sh tools/run_tests.sh` | CASES 580, CHECKS 136950, FAILURES 2 (Fm1 pair only) | 1 | none | n/a | no |
| 2026-11-08 23:33 | 2dc1a6c + Task 5 diff | `sh tools/run_lint.sh` / `run_warnings.sh` | 116 files | 0 / 0 | Success: no problems found; WARNINGS CHECKED 116 FILES | n/a | no |
| 2026-11-08 23:38 | 2dc1a6c + Task 5 diff, regex check removed | `sh tools/run_tests.sh` | CASES 580, CHECKS 136958, FAILURES 5 (3 new MS3 + Fm1 pair) | 1 | none | n/a | no |
| 2026-11-08 23:41 | 2dc1a6c + Task 5 diff + review fixes | `sh tools/run_tests.sh` | CASES 580, CHECKS 136958, FAILURES 2 (Fm1 pair only) | 1 | none | n/a | no |
| 2026-11-08 23:44 | same | `sh tools/run_lint.sh` / `run_warnings.sh` | 116 files | 0 / 0 | WARNINGS CHECKED 116 FILES | n/a | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_tests.sh` | CASES 596, CHECKS 137159, FAILURES 2 (Fm1 pair only) | 1 | none (no TESTS PASSED; known red) | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_lint.sh` | no problems | 0 | exit 0 | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_warnings.sh` | WARNINGS CHECKED 120 FILES | 0 | WARNINGS CHECKED 120 FILES | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_python_checks.sh` | n/a | 0 | exit 0 | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `go test -count=1 -race ./... (relay/)` | ok | 0 | exit 0 | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `golangci-lint run (relay/)` | 0 issues | 0 | exit 0 | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_conformance.sh` | n = 39 | 0 | CONFORMANCE PASSED 39 | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_netplay.sh match` | terminal tick 8300 | 0 | NETPLAY PASSED match 14.0 s | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_netplay.sh kill` | n/a | 0 | NETPLAY PASSED kill 2.2 s | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_netplay.sh stall` | n/a | 0 | NETPLAY PASSED stall 15.2 s | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_netplay.sh silent` | n/a | 0 | NETPLAY PASSED silent 11.5 s | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_netplay.sh spike` | n/a | 0 | NETPLAY PASSED spike 38.5 s | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_netplay.sh perturb` | n/a | 0 | NETPLAY PASSED perturb 1.6 s | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_netplay.sh version` | n/a | 0 | NETPLAY PASSED version 1.3 s | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_netplay.sh relay-down` | n/a | 0 | NETPLAY PASSED relay-down 3.2 s | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_netplay.sh relay-term` | n/a | 0 | NETPLAY PASSED relay-term 3.6 s | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_netplay.sh maps` | NETCLIENT MAP ashfall STARTS 6,2 | 0 | NETPLAY PASSED maps 2.6 s | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_netplay.sh map-mismatch` | n/a | 0 | NETPLAY PASSED map-mismatch 1.3 s | 1.5-2.5 (uptime at 05:01 and 05:05) | no |
| 2026-11-09 05:0x | 15c38bf (clean at start; docs-only edits uncommitted from the lint run on) | `sh tools/run_benchmark.sh (alone)` | hordes300 p95 2.819 and open p95 1.847 over 1.82 (recorded, not loosened) | 0 | BENCHMARK PASSED 2; COMBAT BENCHMARK PASSED 10; LOCKSTEP BENCHMARK PASSED 1 | 1.5-2.5 (uptime at 05:01 and 05:05) | no |

## Task 1 RED

Tree `aa9bea2` plus new vectors and tests, production code unchanged.

- `sh tools/run_conformance.sh` against the protocol-1 relay: `FAIL settings_echoed_byte_exact: bad welcome "{\"type\":\"error\",\"reason\":\"protocol mismatch\"}"`; `CONFORM default: 36 cases, 34 failed`.
- `go test ./...` in `relay/`: build failed, `envelope_test.go:57:137: e.settings undefined (type *envelope has no field or method settings)` (compile error instead of the first `TestParseRules` failure, because the new test reads `e.settings`).
- Suite: `FAIL: W2 rejects start without seed` (and 7 more W2/W3 lines), `CASES 559 CHECKS 136858 FAILURES 8`.

## Task 5 RED

Tree `2dc1a6c` plus new tests, `match_settings.gd` absent, `SkirmishMain.starts` absent. Suite did not load: `SCRIPT ERROR: Parse Error: Preload file "res://scripts/match_settings.gd" does not exist.` and `Parse Error: Cannot find member "starts" in base "res://scripts/skirmish_main.gd".` (compile-level RED; MS3 cannot run before MatchSettings exists).

Review fix RED: with the `_valid_id` check removed, `FAIL: MS3 an unknown map id is refused: { "map": "../maps/ashfall", ...}` (also `../../../protocol/vectors/hello` and `ASHFALL`). Restored, green. N12 `is_same` check and N11 dropdown checks added; N12 restart mutant not run. Row timestamps in this file are wall clock; rows above dated 2026-11-09 00:xx are ahead of it.

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

## Task 4

RED: n/a (measurement, no tracked source change). Tree measured: HEAD `bc43b77`, clean. Scratch source `wargrid-overnight-work/scratch/bot_match.gd` (copy and `.uid` deleted after the run).

`BOT MATCH map=ashfall factions=usa,china seed=1 starts=[2, 6] end_tick=26371 winner=1 first_build=[390, 420] first_collect=[1350, 1290] first_enemy_damage=[23910, -1] tick_ms p50/p95/p99/max=0.741/1.057/1.961/5.367`, exit 0, 19 s wall, load 1.61 before / 1.44 after, Godot alone. Budgets (1.82 / 3.64, snapshot 0.91) pass; ledger row added in `performance.md`. Bots: both seats build and collect; seat 1 attacks (first enemy damage tick 23,910), seat 2 never damaged an enemy building before it lost. Task 8 owns any bot fix. Log: `wargrid-overnight-work/logs/t4-bot.log`.

## Task 6

RED (tests present, no production change): `FAIL: N13 the joiner refuses a different map before the simulation exists`, also `FAIL: N15 seat 1 sim starts on the seeded cells, got [(40, 23), (40, 84)]`, `FAIL: N16 left before the start is explained`, `SCRIPT ERROR: Invalid call. Nonexistent function 'left_before_start'` (L14); `CASES 585 CHECKS 136972 FAILURES 10`.

Joiner hello now carries no `settings` (the create hello carries `MatchSettings.for_map`); the headless client does the same. N16's late case feeds peer packets 4..40 (0..3 are prefilled).

Rows: tree `fdb81c4` + Task 6 diff. `run_tests.sh` `CASES 585 CHECKS 136975 FAILURES 2` (Fm1 pair), exit 1, no marker; `run_lint.sh` exit 0; `run_warnings.sh` `WARNINGS CHECKED 118 FILES` exit 0; `run_netplay.sh match` `terminal tick 8300` `NETPLAY PASSED match 14.3 s`; `maps` `NETCLIENT MAP ashfall STARTS 3,7` PASSED 2.4 s; `map-mismatch` PASSED 1.3 s; `kill` PASSED 2.1 s; `version` PASSED 1.3 s; `run_conformance.sh` `CONFORMANCE PASSED 39` exit 0. Logs: `wargrid-overnight-work/logs/t6-*.log`.

## Task 6 fix
- RED: N14 and N13 `Create usable` failed with `_set_busy(false)` removed from `_fail` (suite FAILURES 5); N15 `transport closed once, Create usable` failed with the decode-failure close removed (FAILURES 3).
- Fixed: N13/N14 call `_set_busy(true)` first; new N15 (start without settings, plus unexpected type closes the transport); launcher closes transport on unexpected type; `--perturb-map-hash` applies to seat 2 only.
- Row: uncommitted tree on fdb81c4; suite CASES 586 CHECKS 136979 FAILURES 2 (Fm1 pair only), lint and warnings exit 0, netplay map-mismatch and maps PASSED.

## Task 6b
- RED (tests present, no production change): `ERROR: Node not found: "Center/Box/WaitRow" (relative to "/root/Launcher").` and `FAIL: incomplete/empty case test_launcher_layout` (N5), N17/N18 case also errors on the missing node; `CASES 586 CHECKS 136662 FAILURES 3`.
- Row: uncommitted tree on fdb81c4 (Task 6 diff + 6b diff). `run_tests.sh` `CASES 586 CHECKS 137053 FAILURES 2` (Fm1 pair only), exit 1, no marker; `run_lint.sh` exit 0; `run_warnings.sh` `WARNINGS CHECKED 118 FILES` exit 0. Logs `wargrid-overnight-work/logs/t6b-*.log`.
- Unverified: see review fixes below; browser clipboard needs a user gesture and secure context, not checked until a web run.

## Task 6b review fixes
- RED: registering `test_cancel_and_copy_while_waiting` (CASES 586 to 587) printed `ERROR: Clipboard is not supported by this display server.` (log line 23); the case is now run, not skipped.
- Fixed: Copy press and clipboard check only when `DisplayServer.has_feature(FEATURE_CLIPBOARD)`; `await runner.process_frame` before `launcher.free()`; first N17 check also asserts Copy and Cancel stay enabled (RED by mutant: `WaitRow/Copy` added to `_set_busy`, `FAIL: N17 waiting shows Copy and Cancel, launcher stays busy`, FAILURES 3; restored); volume sliders now sit above WaitRow, so WaitRow is directly above Status.
- N18 headless: only the stored `_code` is asserted; Copy's clipboard effect is unverified headless (the clipboard branch does not run).
- Row: uncommitted tree on 1dceeea. `run_tests.sh` `CASES 587 CHECKS 137058 FAILURES 2` (Fm1 pair only), exit 1, no marker; `run_lint.sh` exit 0; `run_warnings.sh` `WARNINGS CHECKED 118 FILES` exit 0. Logs `wargrid-overnight-work/logs/t6bf-*.log`.

## Task 7
- RED (stub `credits.gd` returning "", tests registered; without the stub the suite did not compile): `FAIL: CR1 every CREDITS.md music row is in the panel: Conflict`, `FAIL: CR3 the MacLeod attribution block is verbatim`, `FAIL: CR7 Wargrid GPL line`, `ERROR: Node not found: "CreditsPanel" (relative to "/root/Launcher")` (N10), 10 MP9 failures; `CASES 596 CHECKS 136723 FAILURES 48`. CASES rose 587 to 596 (7 CR + MP9 + N10).
- Layout: Credits sits directly under JoinRow (volume sliders now sit between it and WaitRow); N5 passes at 1280x720 and 1920x1080, no fallback needed.
- Rows: uncommitted tree on `b06e307`. `run_tests.sh` `CASES 596 CHECKS 137159 FAILURES 2` (Fm1 pair only), exit 1, no marker; `run_lint.sh` exit 0; `run_warnings.sh` `WARNINGS CHECKED 118 FILES` exit 0; `run_python_checks.sh` exit 0.
- Export evidence (templates 4.7.2 installed): `export_build.sh Linux` exit 0, `grep -ac Zhelanov` on the binary (embedded pck) 2; `export_build.sh Web` exit 0, `grep -ac Zhelanov` on `index.pck` 2. Handoff's 0.9.0 exe had 0. Outputs in `wargrid-overnight-work/scratch/t7/`. Logs `wargrid-overnight-work/logs/t7-*.log`.
- Unverified: panel look on screen (Task 9); Godot licence text content is whatever `Engine.get_license_text()` returns, tests use a marker string.

### Task 7 review (Opus, APPROVE) - minors for the morning
- No test covers the attribution notice or the `changes:` field (CR1 checks columns 2-6 as substrings only); strengthen CR1 to assert the whole line per row.
- launcher.gd wiring untested: a wrong NOTICE.md path or `""` instead of `Engine.get_license_text()` passes; section order unasserted.
- Godot "Complying with licenses" may also want `Engine.get_copyright_info()` / `get_license_info()`; panel ships only `get_license_text()`. User decision.
- N10 can leak click.wav playback near the end of a process (`1 resources still in use at exit`); the full 4-shard run is clean.
- `_macleod` takes the first ```text fence, not the one under the heading; a CRLF checkout drops the block silently.

## Task 8
- Sweep: 24 runs (6 pairs x skirmish, dry_wells, broken_crown, ashfall), seed 1, cap 45,000, headless, alone, exit 0 each, tick p95 0.52 to 1.12 ms (budget 1.82). Table in `docs/reference/more-maps.md` "Bot-vs-bot sweep". Log `wargrid-overnight-work/logs/t8-sweep.log`.
- Row: tree `596db73` plus uncommitted Task 6 to 7 diff; only tracked change is the docs table; scratch copy and .uid deleted. No suite run (docs only).
- Both seats build and collect on every new-map row. Ashfall: four rows where one seat never damaged an enemy building (`china,china` seat 1 at cap; `usa,china` seat 2, `frc,usa` seat 1, `china,frc` seat 1, the last three each the loser). Same pattern on Dry Wells. Final-review attack check (seeds 1 to 3, Ashfall): waves launch but armies end 30 to 60 cells short of the enemy base, army sizes fall; not a wave-never-sets-out bug, no fix, no pin touched. **Done-when "attack on Ashfall": open (M8).** Ashfall first building damage 14,970 to 44,070 ticks outside `frc,frc`.

## Task 9
- Rendered pan check on dry_wells, broken_crown, ashfall plus Credits screenshot and rendered movement benchmark, alone, `--audio-driver Dummy`, every window ended by itself. No `godot` process was running beforehand. Results and observations in `docs/reference/performance.md` "Rendered check per map".
- Rows: tree `2354087`. `PAN CHECK` p99 frame 2.67 / 2.61 / 2.72 ms; `RENDERED BENCHMARK PASSED 4`, Ashfall guard 2.936 ms, exit 0. Scratch copies and .uid deleted from `game/`; only tracked change is the two docs. Logs `wargrid-overnight-work/logs/t9-*` (`t9_*.log`).

## Final-review fixes
- Rows: tree `026f2b2` plus uncommitted fixes. `sh tools/run_tests.sh` `CASES 596 CHECKS 137159 FAILURES 2` (Fm1 pair only), exit 1 by design; `sh tools/run_lint.sh` exit 0; `sh tools/run_warnings.sh` `WARNINGS CHECKED 120 FILES`, exit 0; `sh tools/run_team_match.sh` exit 0. Logs `wargrid-overnight-work/logs/ff-*.log`. No netplay run: no production or pin change.
- Ashfall attack check: scratch Godot script (`game/diag_wave.gd`, deleted afterwards) logged army position per seat every 1,200 ticks from tick 6,000 to 16,000, `china,china` seeds 1 to 3 and `usa,china` seeds 1 and 2 (logs `diag_*.txt`). Waves launch; closest army centroid to the enemy start 30 to 63 cells (start distance 154 to 168); armies shrink. Not a wave-never-sets-out bug, so no fix. Whether armies die midway or stall on the long path is unchecked: M8.
- Finding for M9 or debug: `headless_client` `_replay_oracle` always loads `skirmish.json`, so replaying a `--map` client's log checks against the wrong map, and the desync report carries no map, seed or starts.

## Morning fixes 2026-11-09 — relay protocol first
- RED: `parseEnvelope` had no `badSettings` (new tests did not compile); `sh tools/run_conformance.sh` against the old relay: `FAIL protocol_beats_bad_settings`, `CONFORM default: 38 cases, 1 failed`.
- Fix: a hello with malformed settings now parses with `badSettings`; `registry.join` checks protocol (mismatch), then `badSettings` (invalid message), then missing settings. Protocol 2 wire bytes unchanged.
- Tests: `TestParseRules` (bad settings incl. `null`, protocol 2 and 3), `TestJoinProtocolBeatsSettings`; conformance `protocol_beats_bad_settings` and `settings_null_refused`.
- Rows: uncommitted tree on `bd5e4db`. `go test -count=1 -race ./...` in `relay/` ok, exit 0; `golangci-lint run` 0 issues; `sh tools/run_conformance.sh` `CONFORMANCE PASSED 41` (default 38, delay 2, silence 1), exit 0. Logs `wargrid-overnight-work/logs/m-relay-*.log`. No netplay or Godot run.

## Morning fixes 2026-11-09 — wave targeting (answers 9, 10, 20; reworked after review)
- RED (scoped run of `test_skirmish.gd` + `test_skirmish_waves.gd` on the first diff, `ENGAGE_RADIUS = 30`, tests already rewritten; log `m-wave2-red3.log`): `FAIL: W3 a wave marching to a base fights an enemy unit that comes within reach, got [1, 1, 1, 1]`, `FAIL: W1 enemy unit at (70.5, 11.5): wave targets 1, got [2, 2, 2, 2]`, `FAIL: W4 a building in reach beats a unit beyond it, got [2, 2, 2, 2]`.
- Fix: `Skirmish._pick` scores only enemy buildings unless an enemy unit is within `DEFENCE_RADIUS` (10 cells) of the wave centroid (`_candidates`, `_engaged`; the pin-fitted `ENGAGE_RADIUS = 30` is gone). `_drive_waves`: when the wave's target is a building and an enemy unit is within `DEFENCE_RADIUS` of the centroid, `_pick` again and, if it changes the target, the whole wave (not only idle units) is re-ordered; after the unit dies the next decision falls back to a building. No simulation change.
- Tests: `test_wave_targets_base_unless_enemy_near` (W1: unit 8 cells from the rally: unit; 27 cells: building), `test_wave_target_removed_same_tick` (W2), `test_wave_fights_unit_met_on_the_way` (W3: marching wave retargets to a unit spawned 6 cells away, back to the building once it is dead), `test_wave_ignores_far_unit_beside_building` (W4: building 9.5 cells away, tank 11 cells away, not engaged, building wins). Mutants killed: dropping the unit test in `_engaged` (W4), no retarget (W3), retarget of idle units only (W3).
- A3 derivation (expectation unchanged: builder first, then the remaining targets by score). With radius 10 a wave launched at the rally (43.5, 14.5) only sees units within 10 cells; the old builders at x=20.5 were 23 cells away. Units near the rally are also inside the bot's own `DEFENCE_RADIUS`, so the bot's base must not exist or `_defend` orders the army before tick 5400: the test removes the bot's headquarters (4) and builder (3). Builders at (41.5, 22.5) and (45.5, 6.5) are 8 cells from the centroid on opposite sides and outside every unit's vision (6), so nothing auto-acquires them and the second is still within 10 after the wave moves toward the first. Score 28 - 1 = 27 for both (first wins on id), buildings follow once no unit is left.
- T5 (`test_skirmish_waves.gd`, vehicle 28 above a power plant 27) also moved: tank (43.5, 23.5) and plant origin (38, 23), both in the same 4-cell band at 9.0 and 10.1 cells; expectation unchanged.
- Measure (seed 1, cap 45000; first_enemy_damage seat1/seat2, end tick, winner; before = first diff, after = this rework): ashfall usa,china 8250/9330, 25163, 1 -> 36330/14760, no end at 45000; ashfall china,china 9570/9330, 41795, 1 -> -1/15150, 26969, 2 (seat 1 never damaged a building); broken_crown usa,china 6900/7740, 30877, 1 -> 6900/7740, 28937, 1; skirmish usa,china -> 16770/9360, 23105, 2. Attribution (radius 10 without the answer-20 retarget): ashfall usa,china 8250/9330, 27077, 1; ashfall china,china 9570/9330, 24120, 1. The retarget causes the ashfall slowdown: waves stop for units and the seat 1 wave does not reach a building in time.
- Fm1 real end (`skirmish.json`, frc,usa, cap raised to 150000, scratch run): tick 48052, winner 1 (pinned 23534, the suite cap is 45000).
- Moved pins, not re-pinned (old -> new): S1 `S1_CORE_SERIES` 1809165491953682337 -> 8424451727004271161, S1 outcome tick 8452 winner 1 -> 8569 winner 1; Cs1 tick 27555 winner 2 -> 11220 winner 2; TB3 `FINAL_DIGEST` b1c0606ee2bb58fc -> 69a1e12278c29044; TB4 `TEAM_CORE_SERIES` 7949105010122908522 -> 1748824102688385527; `run_team_match.sh` still `cap tick=45000 winner=null`, units_peak 246 -> 261 (script pin fails); `run_netplay.sh match` terminal tick 8300 -> 9024; Fm1 pair red as before (ongoing at 45000).
- Rows: uncommitted tree on `bd5e4db`. Suite `CASES 600 CHECKS 137167 FAILURES 7` (S1 x2, Cs1, TB3, TB4, Fm1 x2), exit 1; lint exit 0; warnings 120 files, exit 0; `run_netplay.sh match` exit 1 (`terminal tick 9024, pinned 8300`); `run_team_match.sh` exit 1 (units_peak 261, pinned 246). Logs `wargrid-overnight-work/logs/m-wave2-*.log`.

## Morning fixes 2026-11-09 — re-pin after wave fix
- Cause of every pin below: wave-targeting fix 882f182 (answers 9, 10, 20); Fm1 per answers 1-2. Each new value taken from a run of the suite on the uncommitted tree on 882f182.
- S1 `TERMINAL_TICK` 8452 -> 8569 (winner 1 unchanged); `S1_CORE_SERIES` 1809165491953682337 -> 6600229479106917126 (the implementer's 8424451727004271161 did not match the run; the series runs to the new tick, re-derived after the tick change).
- Cs1 `CHINA_TERMINAL_TICK` 27555 -> 11220 (winner 2). TB3 `FINAL_DIGEST` b1c0606ee2bb58fc -> 69a1e12278c29044. TB4 `TEAM_CORE_SERIES` 7949105010122908522 -> 1748824102688385527.
- `run_team_match.sh` units_peak 246 -> 261 (still `cap tick=45000 winner=null`). `run_netplay.sh match` terminal tick 8300 -> 9024 (no other 8300 in ci.yml, docs/development.md, README).
- Fm1: `FRC_TICK_CAP` 45000 -> 50000 (end 48051, margin 1949 ticks); `FRC_TERMINAL_TICK` 23534 -> 48051 (loop index; the implementer's 48052 is the tick count), `FRC_WINNER` 1; "ends won inside the cap" assertion unchanged; one-line WHY comment on the cap.
- Rows: suite `CASES 600 CHECKS 137167 FAILURES 0`, `TESTS PASSED 137167`, exit 0; `run_team_match.sh` exit 0; `run_netplay.sh match` `match terminal tick 9024`, `NETPLAY PASSED match`, exit 0; lint exit 0. Logs `wargrid-overnight-work/logs/m-repin-*.log`.

## Morning fixes 2026-11-09 — credits (answers 11, 12)
- Item 11: `Credits.text(credits_md, notice_md, license_text, components, licenses)` gains a "Third-party components in Godot" section after the Godot licence: per component name, de-duplicated copyright lines across its parts, licence names; then every `Engine.get_license_info()` text once. `launcher.gd` passes `Engine.get_copyright_info()` and `Engine.get_license_info()`. Source: Godot "Complying with licenses" (third-party components "require attribution by explicitly citing their copyright statement and license text"; names both functions).
- Size (godot 4.7.2, headless, 1280x720): 102 components, 19 licence texts; panel text 92,645 chars, 2,280 lines; RichTextLabel content height 52,693 px against a 621 px view (about 85 screens, scrolls with its scroll bar, selection already on); open plus scene build 176 ms. Usable but long; no Close-button or layout change.
- Item 12: CR1 asserts the whole expected line per music row (notice when not `-`, `; changes: ` with backticks stripped); `_macleod` takes the fence under the "Attribution text requested by Kevin MacLeod" heading (CR10 earlier-fence copy) and `text()` normalises CRLF in `credits_md` (CR11 CRLF copy: block present and panel equals the LF panel); N10 (`_credits_wired`) checks "Electronic Arts" from NOTICE.md, a licence line from `Engine.get_license_text()` and section order Wargrid < Music < Voice < Maps < Godot < third-party. New CR8 (section, once-only copyright and licence text, order) and CR9 (real engine data: every component name and licence text present).
- RED (scoped run of `test_credits.gd` + `test_online_scene.gd`, signature accepted, behaviour absent, `m-credits-red3.log`): `CASES 31 CHECKS 717 FAILURES 136`, e.g. `FAIL: CR8 the third-party section names Foo Lib`, `FAIL: CR10 the block comes from under the MacLeod heading`, `FAIL: CR11 the MacLeod block survives CRLF input`, `FAIL: N10 Credits sections run Wargrid, Music, Voice, Maps, Godot, third-party at (1280, 720), got [0, 142, 1997, 2230, 5198, -1]`.
- Mutants on the fixed code (scoped, logs `m-credits-mut-*.log`): drop the notice column -> `FAIL: CR1 the panel has this music line: "Conflict" ... ; https://www.youtube.com/c/AlexandrZhelanovsMusic; changes: ...` (2 failures); keep backticks -> same CR1 line (5 failures); first-fence parse -> `FAIL: CR10 ...`; no CRLF normalisation -> `FAIL: CR11 the MacLeod block survives CRLF input` and `CR11 CRLF input gives the same panel`; wrong NOTICE path in `launcher.gd` -> `FAIL: N10 Credits text carries the maps notice at (1280, 720)` and (1920, 1080). Mutations reverted (files compared with saved copies).
- Rows: uncommitted tree on `1b1ac53`. `sh tools/run_tests.sh` `CASES 604 CHECKS 137289 FAILURES 0`, `TESTS PASSED 137289`, exit 0; `sh tools/run_lint.sh` exit 0; `sh tools/run_warnings.sh` `WARNINGS CHECKED 120 FILES`, exit 0; `sh tools/run_python_checks.sh` `All checks passed!`, exit 0. Logs `wargrid-overnight-work/logs/m-credits-*.log`. No netplay or rendered run; the panel was not looked at (headless measure only).

## Morning fixes 2026-11-09 — test gaps and replay fields (answers 13, 15)
- 13a `test_start_spots.gd`: SS8 teams [0,0] on Ashfall: slot 2 takes the farthest start (SS2 uses teams [1,2], so the no-team rule was untested); SS9 teams [1,2,3,4], chosen [1,4,0,0] -> [1,4,7,5]. 13b `test_wire.gd`: W2 rejects `"settings":null` in a hello; W3 `>= 16` -> `== 16` (16 vector files). 13c `test_skirmish.gd`: SK-S3 sibling, the bot wave rally for a unit far from it is seat 5's start cell on Ashfall. 13d already present (N11 label check against `MatchSettings.PLAY_MAPS.values()` and `dry_wells` default): skipped, `test_online_scene.gd` untouched.
- RED by mutant, each in an isolated copy of the tree (so a concurrent suite never saw a mutated file), logs `wargrid-overnight-work/logs/` and scratchpad: SS8: treat team 0 as a team -> `FAIL: SS8 no team (0) never makes slot 2 a teammate`; SS9: `_farthest` by nearest taken start -> `FAIL: SS9 the farthest start maximises the summed distance`; settings null: accept null -> `FAIL: W2 rejects hello settings null`; rally: `_rally` from the default map -> `FAIL: SK-S3 player 1's wave rally is seat 5's start cell, got [... "target": [4.5, 14.5] }]` (plus the pins TB3, TB4 that already depend on it); W3: 17th vector file -> `FAIL: W3 vector files found, got 17` (`>= 16` would pass).
- 15 test-first (production files at HEAD, new tests in `test_skirmish.gd` SK22, SK23): `SCRIPT ERROR: Invalid call. Nonexistent function '_report'`, `'_oracle_sim'`; `CASES 609 CHECKS 137293 FAILURES 3`.
- 15 code: `headless_client.gd` `_oracle_sim()` builds the oracle from `--map` (default test map) and `--seed` through `_match_sim`, shared with the live `_start`; the live line is now `NETCLIENT MAP <id> SEED <n> STARTS <a,b>` (starts stay the last token); both desync reports (`headless_client.gd` `_write_logs`, `online_main.gd` `_report()`) carry `map`, `seed`, `starts` from `MatchSettings.report_fields`. The seed is kept in `MatchSettings.last_seed`, set by `starts()`, because `launcher.gd` is under credits review; a cleaner home is a `SkirmishMain.match_seed` set in `launcher.gd` `_start` once that lands. Oracle usage on a non-default map: `--replay-log F --map ashfall --seed <SEED from the live NETCLIENT MAP line>`. `run_netplay.sh` `oracle()` still runs the default map only (the maps scenario stops at tick 900 and has no oracle step).
- Rows: uncommitted tree on `1b1ac53`. `sh tools/run_tests.sh` `CASES 609 CHECKS 137297 FAILURES 0`, `TESTS PASSED 137297`, exit 0; `sh tools/run_lint.sh` exit 0; `sh tools/run_warnings.sh` `WARNINGS CHECKED 120 FILES`, exit 0; `run_netplay.sh` match (`match terminal tick 9024`), maps (`NETCLIENT MAP ashfall SEED 1207039211 STARTS 2,6`), map-mismatch, perturb: each `NETPLAY PASSED`, exit 0. Logs `wargrid-overnight-work/logs/m-15-*.log`.

## Morning fixes 2026-11-09 — credits gaps and seed home
- Item 1: CR8 asserts two whole component blocks in the third-party section (`Foo Lib\n2020, Foo\n2021, Bar\nLicense: Expat, Zlib\n\nBaz Lib\n2019, Baz\nLicense: Expat`). RED (mutant in an isolated copy, `credits.gd` without `\nLicense: %s`, log `m-seed-red-lic.log`): `FAIL: CR8 each component block is name, copyright lines, then its licence names`, `CASES 609 CHECKS 137302 FAILURES 1`.
- Item 2: `_credits_wired` (N10) checks the last `Engine.get_copyright_info()` component name (the first, "Godot Engine", is also a heading) and a licence line (over 40 chars, no `[`) of the first `Engine.get_license_info()` text appear in the shown text. RED (mutant `launcher.gd` passing `[]` and `{}`, log `m-seed-red-cop2.log`): `FAIL: N10 Credits text names an engine component at (1280, 720)`, `FAIL: N10 Credits text carries an engine licence text at (1280, 720)` and (1920, 1080); `FAILURES 6`.
- Item 3: `MatchSettings.last_seed` removed. `static var match_seed` in `skirmish_main.gd` beside `map_path`/`starts`; `launcher.gd` sets it with `starts` in `_offline_setup` (`randi()`) and `_start` (`message.seed`). `online_main.gd` `_report()` reads it; `headless_client.gd` keeps its own `_match_seed`. `MatchSettings.report_fields(id, match_seed, chosen)` takes the seed explicitly; `starts()` has no side effect. SK23 sets `SkirmishMain.match_seed = 7`; tests that set SkirmishMain statics (SK23, five in `test_online_scene.gd`) save and restore it. New checks: N11 offline starts equal `MatchSettings.starts(id, SkirmishMain.match_seed)`, N19 `match_seed == 11` after `_start`. SK22/SK23 meaning unchanged.
- RED (tests first, production unchanged, log `m-seed-red3.log`): `SCRIPT ERROR: Parse Error: Cannot find member "match_seed" in base "res://scripts/skirmish_main.gd".`, exit 1. Not mutation-checked after the fix (N11/N19/SK23 read the static directly).
- Rows: uncommitted tree on `f1747db`. `sh tools/run_tests.sh` `CASES 609 CHECKS 137307 FAILURES 0`, `TESTS PASSED 137307`, exit 0; `sh tools/run_lint.sh` exit 0; `sh tools/run_warnings.sh` `WARNINGS CHECKED 120 FILES`, exit 0; `run_netplay.sh match` (`match terminal tick 9024`) and `perturb`: each `NETPLAY PASSED`, exit 0. Logs `wargrid-overnight-work/logs/m-seed-*.log`.

## Morning fixes 2026-11-09 — report-field gaps
- 1: `run_netplay.sh perturb` Python check asserts `map == "skirmish"`, int `seed`, `starts == []`. RED (dropped `report.merge(...)` in `_write_logs`, log `m-gaps-red1.log`): `KeyError: 'map'`, `NETPLAY FAILED perturb`. Restored: PASSED.
- 2: SK22 now runs `_replay_oracle` itself (subclass no-ops `_exit`, new `--oracle-ticks` arg bounds the loop; empty replay log). RED (`_replay_oracle` using `Skirmish.create(true,"human",{})`, log `m-gaps-red2.log`): `FAIL: SK22 ... seat 1 ... want seat 4`, seat 2 `want seat 8`, `FAILURES 2`. 3: `_oracle_sim` calls `_map_id()`.
- Rows: uncommitted tree on `f1747db`. `run_tests.sh` `CASES 609 CHECKS 137307 FAILURES 0`, `TESTS PASSED 137307`, exit 0; lint exit 0; warnings `WARNINGS CHECKED 120 FILES`, exit 0; `run_netplay.sh perturb` PASSED, `match` PASSED (`match terminal tick 9024`). Logs `m-gaps-*.log`.

## Final checks 2026-11-09 (tree `9ed2331`, docs-only edits uncommitted)
- Rows, one at a time, logs `wargrid-overnight-work/logs/m-final-*.log`: `run_tests.sh` `CASES 609 CHECKS 137307 FAILURES 0`, `TESTS PASSED 137307`, exit 0; `run_lint.sh` exit 0; `run_warnings.sh` `WARNINGS CHECKED 120 FILES`, exit 0; `run_python_checks.sh` exit 0 (32 source files); `relay/` `go test -count=1 -race ./...` ok, exit 0; `golangci-lint run` 0 issues; `run_conformance.sh` `CONFORMANCE PASSED 41`, exit 0.
- `run_netplay.sh` all exit 0 `NETPLAY PASSED`: match (terminal tick 9024), kill, stall, silent, spike, perturb, version, relay-down, relay-term, maps, map-mismatch. `run_team_match.sh` exit 0 (`TEAM MATCH cap tick=45000 winner=null units_peak=261`).
- `run_benchmark.sh` alone, exit 0, load 1.17 start / 1.14 end: `BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1`; exceeded and recorded in the ledger: combat open p95 1.857, hordes300 p95 2.855 (budget 1.82).

### Wave retarget diagnosis (Opus, 2026-11-09)
With waves fighting units within `DEFENCE_RADIUS` on the way, Ashfall seed 1 `usa,china` no longer ends by 45,000 and in `china,china` seat 1 never damages a building (seat 2 wins at 26,969). Probe on 598 unit-target episodes: no target flapping (0 dropped while the unit lived), no stop-and-go (at most 16 whole-wave re-orders in an ~8,300-tick wave), no chasing (air units are filtered out, so the USA supply helicopter is never a target; distance grew >5 cells in 3 episodes), no unhittable targets. Cause: armies now meet mid-map; the side that wins the first battle (t9000: 43-45 vs 39 wave units) camps there and each new 6-unit wave of the loser (`WAVE_MIN`) dies near its own base. Verdict: honest grinding, no targeting defect; wave size goes to M8 (user answer 21, 2026-11-09).

## User playtest (2026-11-09 evening)

Test app `wargrid-web-test` at `17e7f3d`, Safari. Ashfall offline ("looks good", lost to the bot), Broken Crown offline (no issues), Dry Wells offline (adjacent small-pile labels overlap; cosmetic per the user, removed by the M7.5 no-map-text answer), Credits panel renders, Copy in the online waiting screen copies the match code, online match MacBook vs Mac mini through the deployed relay ("everything worked great"; MacBook over wifi: command latency 185 ms, RTT 34 ms, F3 overlay). Not checked: Linux/Windows desktop builds, Chrome, Firefox, a hidden tab during an online match.
