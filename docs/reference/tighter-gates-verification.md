```text
Resume record (updated 2026-11-13, Task 8 green)
Branch / base commit / working-tree state: tighter-gates / f63ff70 / Task 8 changes uncommitted (coordinator commits)
Last green task / next incomplete task: Task 8 / Task 9
Changed paths since last commit: tools/perf_record.py, tools/test_perf_charts.py, tools/run_warnings.sh, docs/wrapup.md, docs/reference/tighter-gates-verification.md
Last command / cases / checks / failures / exit / marker: run_python_checks.sh (no Godot suite; no GDScript logic touched) / exit 0 / PYTHON TESTS PASSED
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: questionnaire 2026-11-13 (plan "Decisions"); one local commit per GREEN task (never push); CI run, Windows behaviour, CI timing and the cancel rule deferred to a pushed branch (morning)
Usage so far (python3 tools/session_usage.py <session files>): n/a
Next exact action: Task 9
```

Plan: [tighter gates](../superpowers/plans/2026-11-13-tighter-gates.md). Spec: [tooling audit](tooling-audit.md). Logs: `~/projects/wargrid-overnight-work/tighter-gates/logs/` (outside the repository).

## Tasks

| Task | What | Model | Status |
|---|---|---|---|
| 0 | Baseline: timed suite, traces, load | Sonnet | GREEN |
| 1 | Real-time watchdog, killed runs stop their children (2, 3) | Sonnet | GREEN |
| 2 | One team match run plus a 3000-tick pair (5) | Sonnet | GREEN |
| 3 | Cases dealt by cost; timed suite after 5 and 6 (6) | Sonnet | GREEN |
| 4 | CI: relay in the export job, tool tests once, pinned gdlint, branch-only cancel (7, 8, 9, 14) | Sonnet | GREEN |
| 5 | Shell and tool cleanups (13, 16, 17, 19, left-out 6) | Sonnet | GREEN |
| 6 | Parity report fixes (4, 10, 11, left-out 4) | Sonnet | GREEN |
| 7 | Parity sweep fixes, `probe_patriot.py` deleted (12, left-out 1, 2, 3, 5) | Sonnet | GREEN |
| 8 | Extras: wrap-up benchmark rule, warnings on a fresh worktree | Sonnet | GREEN |
| 9 | One checks command (15) | Sonnet | not started |
| 10 | Docs and package gate | Sonnet | not started |
| 11 | Fresh-context branch review, one fix round | Opus (high) | not started |

## Baseline (Task 0; filled in by the run)

| Item | Value |
|---|---|
| Tree | `tighter-gates` `11e8174` (descends from `10b9423`), clean |
| `uptime` at start / end | load 1.68 1.69 1.53 (20:32) / 2.17 1.92 1.63 (20:34) |
| Full four-process suite: wall seconds, CASES, CHECKS, exit | 85 s, CASES 849, CHECKS 144207, FAILURES 0, exit 0, `TESTS PASSED 144207` |
| Per-process times | not printed by the runner |
| Trace files (`replay`, `economy`, `combat`, `team` `-before.tsv`), line counts | replay 1200, economy 1200, combat 1200, team 100 |

## Measurements after findings 5 and 6 (Task 3)

| Item | Before (Task 0) | After (Task 3) |
|---|---|---|
| Wall seconds, full suite | 85 | 53 |
| `uptime` at start / end | 1.68 1.69 1.53 / 2.17 1.92 1.63 | 2.16 2.35 2.16 (20:50) / 3.37 2.69 2.29 (20:51) |
| Traces `cmp` against `*-before.tsv` | — | all four silent |
| `test_team_match` suite alone, seconds (Task 0 Step 4 / Task 2 Step 4) | 104 (CASES 4, CHECKS 13, exit 0) | Task 2: 48 (CASES 4, CHECKS 15, exit 0, trace env set) |
| Static gates: five alone (sum) / `run_checks.sh` (Task 9) | about 17 s (audit) | |

## Pinned values (V1-V6, checked at Tasks 2 and 10)

| # | Pin | Expected | Task 2 | Task 10 |
|---|---|---|---|---|
| V1 | `FINAL_DIGEST` | `3958ceaab11986af` | unchanged (TB3 final digest check passes) | |
| V2 | `TEAM_CORE_SERIES` | `8513092129969516499` | unchanged (TB4 passes, now in the single run) | |
| V3 | four traces | byte-identical to Task 0 | team only: `cmp` silent | all four (Task 3: all four `cmp` silent) |
| V4 | netplay match terminal tick | 9129 | — | |
| V5 | `run_team_match.sh` line | `won tick=39497 winner=2 units_peak=271` | — | |
| V6 | other `game/tests` pins | only `run_tests.gd`, `test_runner.gd`, `test_team_match.gd` differ from `main` | | |

## Unverifiable tonight (for the morning)

- CI on Linux and Windows for every change, the CI timing before and after, and the concurrency rule's behaviour: need a pushed branch (push needs approval).
- Windows behaviour of the shell changes (trap in `run_tests.sh`, `run_checks.sh`, the relay build in the export job).
- Parity sweep and report fixes against the real game (no Zero Hour launch at night; unit tests and fake launchers only).
- Before the push: deleting the `Godot / Lint` job (Task 4) breaks a branch-protection rule that requires it; check `gh api repos/{owner}/{repo}/branches/main/protection --jq '.required_status_checks.contexts'` (a read, user's morning).
- Commands the night permissions refused, each with its exact text (filled in by the run).
- Finding 18 (exported builds run the whole suite) stays deferred until CI time is measured after findings 5 to 7.

## Evidence rows (append-only)

- 2026-11-13, plan writing, tree `tighter-gates` `10b9423` clean, read-only checks (no suite, no benchmark): every audit line anchor re-read; drift: `docs/development.md` lint note is line 66 (audit: 65), the other cited lines match. `sh tools/run_warnings.sh` on this fresh worktree (no `game/.godot`): exit 1, 244 `ERROR` lines, mostly `Identifier "PlaytestSession" not declared` and `Could not resolve class "res://scripts/main.gd"` (no global class cache); after `godot --headless --path game --import` (exit 0, 1.5 s): `run_warnings.sh` exit 0, `WARNINGS CHECKED 161 FILES`. So this worktree now has `game/.godot` but no `wargrid-imported` stamp; Task 8 reproduces extra b in a scratch worktree. `actionlint` 1.7.12 exit 0 and `shellcheck` 0.11.0 exit 0 on all tracked `*.sh`. `python3 tools/test_install_godot.py` OK (every `urlretrieve` mocked, writes only into its temp dir); `python3 tools/test_perf_charts.py`, `tools/test_zh_parity.py`, `tools/test_check_reference.py` exit 0 with the system Python (the touched tools import only the standard library). `rg -n probe_patriot` outside the audit: the file itself and archive or status docs only. GitHub docs read for finding 14: a new run cancels an older pending run in the same group even without `cancel-in-progress`; in a called workflow the `github` context is the caller's.
- 2026-11-13, plan revised after the user's rulings and the readiness review (no suite run): extra a uses the pathspec `game tools/run_benchmark.sh tools/perf_record.py tools/perf_chart.py` (on `10b9423`: `c88ba13`, equal to the newest `auto` row); delta sign Wargrid minus Zero Hour, so the non-`credits_per_min` rows flip (`analyze.py:626`) and `:628` stays; review fixes applied to Tasks 0-10 (sweep stop event in the worker, code hash in `write()`, a full fake for the boot test, text anchors in Task 3, `RunBenchmarkTest` as the benchmark guard, denied-command rule, protection-check morning item).
- 2026-11-13, Task 0, tree `tighter-gates` `11e8174` clean: import run (`test_runner`) exit 0, 4 cases 7 checks; timed full suite exit 0, 85 s, CASES 849 CHECKS 144207 FAILURES 0, `TESTS PASSED 144207`, load 1.68 -> 2.17 (1 min); `test_team_match` alone exit 0, 104 s, 13 checks; traces 1200/1200/1200/100 lines in the logs directory. No repository file changed besides this one.
- 2026-11-13, Task 1, tree `tighter-gates` `436ed43` plus the two changed paths: red A (timer 10 s, `test_team_match_prefix`): no watchdog line, exit 0; red B: `alive=4`. After the change: green A (`WATCHDOG_SECONDS` 10): `FAIL: watchdog timeout in test_team_match_prefix`, `FAIL: 1 of 1 shards did not finish`, exit 1; green B: `alive=0`, runner exit 1, no probe process left (SIGTERM was enough, no KILL needed); `test_runner` exit 0 (4 cases, 7 checks); full suite exit 0, CASES 849 CHECKS 144200 FAILURES 0, `TESTS PASSED 144200`, no Thread or WARNING lines; `run_lint.sh`, `run_warnings.sh`, `run_shell_checks.sh` exit 0. CHECKS 144200 vs Task 0's 144207: the unchanged tree (stashed) also gives 144200, so the 7 are run-to-run variation or Task 0's run, not this change; Task 2 should recheck the baseline count. Logs `t1-*.log`.
- 2026-11-13, Task 2, tree `tighter-gates` `f591ef8` plus `game/tests/test_team_match.gd`: `test_team_core_series` and the second 20000-tick sim removed; `test_team_match_prefix` is the one run (trace, TB3, TB4); new `test_team_match_pair` (3000 ticks, 16 comparisons, TB5). Red by mutation: extra step of `b` at tick 1000 -> `FAIL: TB5 ... first divergence 1200`, exit 1; series line moved above `step` -> `FAIL: TB4 ... got 2575876620437009839`, exit 1; both reverted (file identical to the good copy). Green: `WARGRID_TEST_ONLY=test_team_match` exit 0, 48 s, CASES 4 CHECKS 15 (trace env set; Task 0's 13 had none: the trace-open check adds 1, TB5 adds 2, the dropped agree check removes 1), team trace `cmp` silent. Full suite (trace env vars set, load 1.52 at start) exit 0, 72 s, CASES 849 CHECKS 144204 FAILURES 0, `TESTS PASSED 144204`, team `cmp` silent; `run_lint.sh`, `run_warnings.sh`, `run_shell_checks.sh` exit 0. Logs `t2-*.log`. No permission denials.
- 2026-11-13, Task 3, tree `tighter-gates` `6346515` plus `game/tests/run_tests.gd`, `game/tests/test_runner.gd`: one-process timing run exit 0 (849 cases, 15 cases of 1 s or more, `t3-slow.txt`; `test_team_match_prefix` 44.8 s, next 11.7 s). Red: stub `shard(..., _costs)` -> `WARGRID_TEST_ONLY=test_runner` exit 1, R5 slow-case and rest checks FAIL, equal-cost checks pass (the plan's first R5 check is split into two). Green: cost-descending deal to the least loaded process (ties lower index, lower process), `CASE_SECONDS` table, default 0.1; `test_runner` exit 0 (5 cases, 11 checks); timed full suite (trace env vars set) exit 0, 53 s (Task 0: 85 s), CASES 850 (849 + new R5 case) CHECKS 144212 FAILURES 0, `TESTS PASSED 144212`, all four traces `cmp` silent, V1/V2 pass in the suite; load 2.16 -> 3.37 (1 min), so the speed-up is measured under heavier load than the baseline. `run_lint.sh`, `run_warnings.sh`, `run_shell_checks.sh` exit 0. Logs `t3-*.log`. No permission denials.
- 2026-11-13, Task 4, tree `tighter-gates` `a39bc9c` plus `ci.yml`, `run_lint.sh`, `run_python_tests.sh`: red 8 (`assert False` in `test_cached_archive_skips_download`): `run_python_tests.sh` exit 0; red 9 (`env PATH=/usr/bin:/bin:/opt/homebrew/bin run_lint.sh`): exit 127, `gdlint: not found`. Green: probe 8 prints `FAIL: tools/test_install_godot.py`, exit 1, reverted -> exit 0 `PYTHON TESTS PASSED`; probe 9 exit 0 (`Success: no problems found`); `actionlint` exit 0; `run_shell_checks.sh` exit 0; `run_python_checks.sh` exit 0. `rg relay-bin .github/workflows` lists only the new build line and the netplay step. Not run: the optional local relay build plus `run_netplay.sh match` (V4); no Godot, CI, Windows or concurrency check (morning). Docs still naming the old job/exclusion (`docs/guide/13-testing-and-tooling.md:141,169`, development notes lint note) are left for Task 10. Logs `t4-*.log`. No permission denials.
- 2026-11-13, Task 5, tree `tighter-gates` `1d2abb8` plus the six tool paths: baseline suite before edits exit 0, CASES 850 CHECKS 144205 FAILURES 0 (`t5-base.log`). Red 13: the plan's `TMPDIR` probe does not work (`mktemp -d` here ignores `TMPDIR`), so the probe counted `tmp.*` folders in the real temp dir: old `run_conformance.sh` leaves 1, new leaves 0; `run_netplay.sh match` (exit 0, `NETPLAY PASSED match`, V4 not rechecked beyond pass) leaves 0. Red 16/19: `GODOT_BIN=false run_benchmark.sh` exit 1 with 0 `load average` lines; new `RunBenchmarkTest` case and two new `check_reference` tests failed before the fix. Green: same probe prints 2 load lines, exit 1; `test_perf_charts.py` exit 0; `test_check_reference.py` 12 tests OK; `relay-down` (2.6 s) and `relay-term` (3.0 s) `NETPLAY PASSED`, first try; `run_shell_checks.sh` exit 0; `run_python_checks.sh` exit 0 (after ruff import sort and format of the new tests). Not run: full benchmark (Task 10 gate), Godot suite after the change (no GDScript touched). Load 3.1-4.5 during the baseline (other sessions), 1.6 at the end. Logs `t5-*.log`. No permission denials.
- 2026-11-13, Task 6, tree `tighter-gates` `71a0102` plus the four tool paths: red: `test_zh_parity.py` 5 new tests fail (pooled key set missing `shot_interval`, `movement` TypeError/StopIteration path on zero speed, empty folder exit 0, delta `-2`), `test_check_reference.py` `test_no_rows_fails` exit 0 != 1. Green: `test_zh_parity.py` 45 tests OK, `test_check_reference.py` OK, `analyze.py --self-test` exit 0, `run_python_checks.sh` exit 0 `PYTHON TESTS PASSED` (first run caught ruff PLW1510 in the new subprocess test, fixed). Delta now `exp - got` (Wargrid minus Zero Hour); `credits_per_min` unchanged. Not run: Godot suite (no GDScript touched), Zero Hour (never). Logs `t6-*.log`. No permission denials.
- 2026-11-13, Task 7, tree `tighter-gates` `56fc867` plus the parity paths: baseline suite exit 0, CASES 850 CHECKS 144205 FAILURES 0 (`t7-base.log`). Red: 5 new tests fail (interrupt, exit 143 retried, error text) or error (`CODE` missing, 503 as RuntimeError) on today's code. Green: `test_zh_parity.py` 51 tests OK, `analyze.py --self-test` exit 0, `run_python_checks.sh` exit 0 `PYTHON TESTS PASSED` (ruff import order fixed once), `check_public.sh` exit 0. `probe_patriot.py` removed with `git rm`; remaining mentions: audit and plan, packages and parity-improvements docs (updated), archives. Packages line is 83 now (plan said 73). Not run against the real game, no Zero Hour launch; fake launchers and stubs only. Logs `t7-*.log`. No permission denials.
- 2026-11-13, Task 8, tree `tighter-gates` `f63ff70` plus `perf_record.py`, `test_perf_charts.py`, `run_warnings.sh`, `wrapup.md`: red: new `AutoRecordTest` case fails (label was HEAD sha); fresh detached worktree `run_warnings.sh` exit 1, `Identifier "PlaytestSession" not declared`. Green: `test_perf_charts.py` 56 tests OK; fixed script in the fresh worktree exit 0, `WARNINGS CHECKED 161 FILES`; scratch worktree removed; `run_warnings.sh` on this tree exit 0, 161 files; `run_python_checks.sh` exit 0 (ruff format applied once); `run_shell_checks.sh` exit 0; `check_public.sh` exit 0. Not run: Godot suite (no GDScript touched), benchmark. Logs `t8-*.log`. No permission denials.
