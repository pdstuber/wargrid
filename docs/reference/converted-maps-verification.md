# Converted maps playable: verification

Plan: [converted maps playable plan](../superpowers/plans/2026-11-08-converted-maps-playable.md). Spec: [design](../superpowers/specs/2026-11-08-converted-maps-playable-design.md). Handoff: [converted maps prompt](../converted-maps-prompt.txt).

## Resume record

```text
Resume record (updated 2026-11-08 22:12)
Branch / base commit / working-tree state: converted-maps / 07c3ab6 (= main HEAD) / clean before Task 0 file was written; only this file is new
Last green task / next incomplete task: Task 0 baseline green (known red: none; hordes300 over budget, see Baseline) / Task 1
Changed paths since last commit: docs/reference/converted-maps-verification.md (new, uncommitted)
Last command / cases / checks / failures / exit / marker: sh tools/run_benchmark.sh / 2 + 10 + 1 benchmark groups / 0 failures reported / exit 0 / BENCHMARK PASSED 2, COMBAT BENCHMARK PASSED 10, LOCKSTEP BENCHMARK PASSED 1
Known red case or blocker: none blocking. Known over budget on main HEAD: COMBAT hordes300 p95 2.84 / p99 3.33 ms vs 1.82/3.64 budget (benchmark script still passes via regression ceiling); recorded, not loosened
Approved decisions, pre-authorizations used, deferred gates: branch created from main HEAD; no source changes; user pre-approved two pin re-pins (Tasks 3b, 3c) per plan Global Constraints; Windows allowed tonight
Usage so far (python3 tools/session_usage.py <session files>): not run (no session files passed to this subagent)
Next exact action: Task 1 (relay and wire protocol 2) RED run, after the coordinator's commit of Task 0
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

## Findings for the morning

Choices the plan made that the user did not decide (plan "Execution rules for this run"):

1. Map dropdown on its own row, although the design says "next to the faction dropdowns". Reason: F5 caps that row at 520 px.
2. Offline Restart keeps the same starts.
3. The relay checks that `settings` is a JSON object of at most 4096 bytes, although "Decided" says it copies `settings` without reading it. Reason: clients require a Dictionary, and the 65,536-byte frame cap applies to `start`.
4. Godot's "Complying with licenses" page may also ask for third-party notices (`Engine.get_copyright_info()`). Not verified. "Decided" names only `Engine.get_license_text()`.

Baseline facts for later tasks:

5. `COMBAT hordes300` is over its budget on main HEAD: p95 2.84 ms, p99 3.33 ms, against 1.82 / 3.64 ms. `run_benchmark.sh` still reports `BENCHMARK PASSED` because the regression ceiling p95/p99 is [3.07, 4.05]. Recorded as exceeded, not loosened. Ledger context: [performance ledger](performance.md) (its Deck Firefox p95 verdict already lists hordes300 as the one row over 10 ms).
6. The relay `go test` baseline was run uncached (`-count=1`); the first run reported `(cached)`.
