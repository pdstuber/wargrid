# spike-visualization merge: design

Short design (small change). Decisions from the 2026-11-13 questionnaire (user); the rest is marked as the agent's call.

## Intent

Merge the user branch `spike-visualization` (benchmark recording to `docs/reference/perf-history.csv`, generated perf status table, generated README roadmap) into `main`, so the README shows players what is done and what comes next, and every gate benchmark lands in the perf history without hand edits. Comes before the Tighter gates night run, which edits `tools/run_benchmark.sh` on top of the merged file (user, 2026-11-13).

## Goals

- Branch merged with its history; conflicts in `AGENTS.md`, `docs/development.md`, `docs/reference/performance.md`, `docs/wrapup.md`, `tools/run_benchmark.sh` resolved. `AGENTS.md` keeps main's text and takes only the branch's perf-recording and generated-block rules, worded to fit and linking rather than duplicating (user, 2026-11-13).
- README roadmap generated from `docs/packages.md` (names, order) and `docs/STATUS.md` (state); `docs/roadmap.toml` dropped (user, 2026-11-13):
  - Rows: the branch's 7 approved done lines for M0-M7 (fixed in `tools/roadmap.py`; they never change), then the Day lane rows, then the Later items. Night lane not shown (engine work). Done packages that left the Day lane come from STATUS's Packages table (user, 2026-11-13).
  - States: Done (STATUS state cell starts with "Done"), Next (first not-done Day lane row), Planned (other Day lane rows), Later (Later items).
  - Later items in `docs/packages.md` get a bold `**Name:**` lead like the night lane; the tool reads it and fails on an item without one (user, 2026-11-13).
  - Block inside README `## Status`, after the "Early development" paragraph; the perf table block below it (user, 2026-11-13).
  - `.claude/commands/roadmap-wording.md` deleted; `docs/roadmap-wording.md` shrinks to the plain-words style rule for package names (user, 2026-11-13).
- Rendered area: "Drawing the screen" (open/dense and Ashfall) switches from `frame_interval` (non-tick frames, vsync off) to `tick_frame` (the `tick_ms` p95 of the `RENDERED SAMPLE` line, the art lab's C1 method). The trend across the switch reads "method change", not "x % better". Sim-only rows keep their history (user, 2026-11-10/12, 2026-11-13).
- Backfill into `perf-history.csv`: the art lab rows and every later ledger row (`performance.md` History, 2026-11-10 onward) that carries a number one of the chart's areas reads; `source` = `performance.md@<sha>:<line>` like the existing backfill.
- Recording rule unchanged from the branch: auto on a clean `main`, `PERF_LABEL` forces a record (gates), `PERF_RECORD=0` off (user, 2026-11-13).
- Nothing built in the last days may break (user, 2026-11-13): no file under `game/`, `relay/`, `protocol/`, `web/` or `.github/` changes; `run_benchmark.sh` keeps all of main's checks and exit paths; a stale README roadmap never fails CI (no real-files test; wrap-up regenerates and checks it).
- Wrap-up: the branch's step 1 (benchmark `main` when the newest `auto` row is not main's sha, load at most 2.5) and `python3 tools/roadmap.py --check`; the "list draft rows" part goes (user, 2026-11-13).

## Non-goals

No change to benchmarks, budgets or ledger verdicts; no new perf areas beyond the tick frame; no test runner, `tools/zh_parity/`, `relay/`, `web/` changes (handoff). No night lane in the README.

## Approaches

1. **Merge commit on `viz-merge` off `main`** (chosen): keeps the branch's 5 commits and their link to `spike-visualization`; follow-up commits on top.
2. Cherry-pick the 5 commits onto main: same content, duplicates commits, loses the merge link. Rejected.
3. Rewrite from scratch on main: throws away tested code. Rejected.

## Agent's calls

- `tools/perf_record.py` parses the current main benchmark logs (new `WORST TICK`, `OVER BUDGET`, `BUDGET EXCEEDED` lines, extra combat rows); checked against a fresh `run_benchmark.sh` log, unmapped scenarios are ignored, not errors.
- `tools/test_roadmap.py` rewritten first (test first), against fixture copies of `packages.md` and `STATUS.md` fragments; no real-files test (see Goals).
- A `P…` package in STATUS that is neither Done nor in the Day lane is a check error (keeps the two files honest); `night N` rows are ignored.

## Gates

`sh tools/run_python_checks.sh`, `run_shell_checks.sh`, `check_public.sh`, `run_lint.sh`, `run_warnings.sh`, full suite, `sh tools/run_benchmark.sh` with host load tagged (records a row once merged to main), one fresh Opus review of the diff. Merge into local `main` and push only with explicit approval. Generated blocks never edited by hand.
