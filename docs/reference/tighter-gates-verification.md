```text
Resume record (updated 2026-11-13, plan written; no task started)
Branch / base commit / working-tree state: tighter-gates / 10b9423 / plan and this file uncommitted (the preparation commits them)
Last green task / next incomplete task: none / Task 0
Changed paths since last commit: docs/superpowers/plans/2026-11-13-tighter-gates.md, docs/reference/tighter-gates-verification.md
Last command / cases / checks / failures / exit / marker: none (plan writing ran only read-only checks, see evidence rows)
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: questionnaire 2026-11-13 (plan "Decisions"); one local commit per GREEN task (never push); CI run, Windows behaviour, CI timing and the cancel rule deferred to a pushed branch (morning)
Usage so far (python3 tools/session_usage.py <session files>): n/a
Next exact action: Task 0 Step 1
```

Plan: [tighter gates](../superpowers/plans/2026-11-13-tighter-gates.md). Spec: [tooling audit](tooling-audit.md). Logs: `~/projects/wargrid-overnight-work/tighter-gates/logs/` (outside the repository).

## Tasks

| Task | What | Model | Status |
|---|---|---|---|
| 0 | Baseline: timed suite, traces, load | Sonnet | not started |
| 1 | Real-time watchdog, killed runs stop their children (2, 3) | Sonnet | not started |
| 2 | One team match run plus a 3000-tick pair (5) | Sonnet | not started |
| 3 | Cases dealt by cost; timed suite after 5 and 6 (6) | Sonnet | not started |
| 4 | CI: relay in the export job, tool tests once, pinned gdlint, branch-only cancel (7, 8, 9, 14) | Sonnet | not started |
| 5 | Shell and tool cleanups (13, 16, 17, 19, left-out 6) | Sonnet | not started |
| 6 | Parity report fixes (4, 10, 11, left-out 4) | Sonnet | not started |
| 7 | Parity sweep fixes, `probe_patriot.py` deleted (12, left-out 1, 2, 3, 5) | Sonnet | not started |
| 8 | Extras: wrap-up benchmark rule, warnings on a fresh worktree | Sonnet | not started |
| 9 | One checks command (15) | Sonnet | not started |
| 10 | Docs and package gate | Sonnet | not started |
| 11 | Fresh-context branch review, one fix round | Opus (high) | not started |

## Baseline (Task 0; filled in by the run)

| Item | Value |
|---|---|
| Tree | |
| `uptime` at start / end | |
| Full four-process suite: wall seconds, CASES, CHECKS, exit | |
| Per-process times | not printed by the runner |
| Trace files (`replay`, `economy`, `combat`, `team` `-before.tsv`), line counts | |

## Measurements after findings 5 and 6 (Task 3)

| Item | Before (Task 0) | After (Task 3) |
|---|---|---|
| Wall seconds, full suite | | |
| `uptime` at start / end | | |
| Traces `cmp` against `*-before.tsv` | — | |
| `test_team_match` suite alone, seconds (Task 0 Step 4 / Task 2 Step 4) | | |
| Static gates: five alone (sum) / `run_checks.sh` (Task 9) | about 17 s (audit) | |

## Pinned values (V1-V6, checked at Tasks 2 and 10)

| # | Pin | Expected | Task 2 | Task 10 |
|---|---|---|---|---|
| V1 | `FINAL_DIGEST` | `3958ceaab11986af` | | |
| V2 | `TEAM_CORE_SERIES` | `8513092129969516499` | | |
| V3 | four traces | byte-identical to Task 0 | team only | all four |
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
