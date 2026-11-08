# Converted maps playable: verification

Plan: [converted maps playable plan](../superpowers/plans/2026-11-08-converted-maps-playable.md). Spec: [design](../superpowers/specs/2026-11-08-converted-maps-playable-design.md). Handoff: [converted maps prompt](../converted-maps-prompt.txt).

## Resume record

```text
Resume record (updated 2026-11-08 22:40)
Branch / base commit / working-tree state: converted-maps / 90cb4a5 / Task 2 diff uncommitted (start_spots.gd, test_start_spots.gd, run_tests.gd registration)
Last green task / next incomplete task: Task 2 green, awaiting coordinator commit and review / Task 3
Changed paths since last commit: game/scripts/simulation/start_spots.gd (+.uid), game/tests/test_start_spots.gd (+.uid), game/tests/run_tests.gd
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh (twice) / 566 / 136868 / 0 / 0 / TESTS PASSED 136868
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: none used
Usage so far: not run
Next exact action: Task 3 (chosen starts become seats 1 and 2)
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
