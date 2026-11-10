# Perf trend charts: design (project 1 of 2)

Update 2026-11-10: the line charts (budget.svg, breakdown.svg) were tried and dropped because the user found them unreadable; the result is a status table generated into the ledger and the README. Chart wording below is historical.

## Context

Today's perf reports are tables of ms values against dev-machine budgets, with caveats about method changes. They don't tell the user what they want to know. The user wants a chart that answers four questions at a glance:
1. Will it run on low-end (target device / browser)?
2. Did this change hurt?
3. Where does the cost go?
4. How did perf evolve across milestones (to look back on and to show others)?

The second project, a live progress site (Go app on fly, `*.pdstuber.dev`, coarse task-level events), is brainstormed after this one ships. The CSV from this project is meant to feed that site later.

## Approaches (user picked A, 2026-11-10)

- **A. CSV in repo + generated status table (picked).** Benchmark logs are parsed into one CSV and a stdlib Python tool writes a status table (area, status, budget used, change vs last run) into the ledger and the README.
- B. Mermaid `xychart-beta` in markdown. Rejected: no stacked breakdown and no labelled budget line.

## Goals / non-goals / anti-goals

- Goals: the four questions above, readable without knowing what p95 or F means. Low upkeep: recording a run is one command after `run_benchmark.sh`.
- Non-goals: interactive charts, live updates, the progress site. CI recording (runner hardware differs and has no baseline; user dropped it 2026-11-10 after review). See "Automatic recording".
- Anti-goals: a chart that hides a regression, mixes non-comparable methods into one line, or quietly treats the F-scaled estimate as a measurement. Never loosen budgets to look green.

## Design

**Data: `docs/reference/perf-history.csv`** (committed, long format, one row per metric per run).
Columns: `date, commit, label, machine, metric, scenario, run, p95_ms, p99_ms, mean_ms, method, load, source`.
- Raw ms only. The % of budget is computed at chart time against **today's** budgets (budget, which stat it applies to (`p95`/`p99`/per-tick) and F are read from one table in `perf_chart.py`, mirroring the ledger Budgets table). One ruler for all history. Past F or budget changes are drawn as labelled vertical markers, not as steps in the data (my call: otherwise an F change looks like a perf change).
- `machine` is `dev` or a target such as `deck-native` or `deck-firefox`. Measured target points are never mixed into the F-scaled dev line (my call).
- `run` numbers repeated runs within one label. The table uses the worst run; the comparison is worst against worst (my call: conservative, can't hide a regression).
- `method` is an epoch tag (`pre-P1`, `P1`, …). A line never connects across epochs.
- `load` is the 1-min load average at record time. Busy rows (WoW running, see memory) are marked.
- `label` is the milestone or task, e.g. `M7.5 T3`.

**Recording: `tools/perf_record.py <benchmark log> --label "…"`** parses the existing JSON summary lines that the benchmarks already print (`COMBAT <layout> tick_ms={…}`, `LOCKSTEP overhead_ms={…}`, the movement lines in `run_movement.gd`) and appends rows. No GDScript changes. Rendered benchmark logs (`run_game.sh … movement_benchmark.tscn`) go through the same parser.

**Status table: `tools/perf_chart.py` → ledger block and README block**, stdlib only: one row per budgeted area, sorted worst first, with status (over / close / OK), budget used as a percent of the limit for the estimated target device (value ÷ dev-machine budget, equal via F), and the change against the previous comparable run (worst vs worst).

**Step 0: windowless-render spike (user, 2026-11-10: spike first).** This is a throwaway test, kept out of the tree, run before the tools are built.
- A: run `movement_benchmark.tscn` with a real GPU but with the window off-screen or hidden (`--position` outside the display, or similar). Check that the numbers match an on-screen run within noise, and that macOS/Godot doesn't clamp the window back onto the screen.
- B: run the web export in headless Chrome or Firefox with GPU flags. Confirm a real GPU (not SwiftShader) via the WebGL renderer string, and see whether frame timings come out.

The outcome decides how rendered rows are recorded. If A works, the breakdown can be recorded with every benchmark run, but loosening the AGENTS.md "rendered benchmarks open a window: ask first" rule needs the user's explicit OK. If B works, browser cost becomes its own `machine=dev-browser` line. If neither works, rendered rows are recorded at milestone gates, which already require a rendered rerun when presentation changed. The spike result is reported to the user before Task 1 continues. The spike's rendered runs still count as "opens a window": ask once and batch them all into that one request.
A generated markdown block, "latest vs previous": one plain-words line per metric ("sim tick p95: 39% of budget, 3% slower than M7.5 T2 (worst vs worst); run-to-run spread up to 50%"). Answers question 2. Noise threshold: the builder derives it from the spread of repeated runs already in the ledger (worst-of-13 data).

**Where it shows:** at the top of `docs/reference/performance.md` (the ledger), between generated-block markers, and the same table in the README by the user's request (AGENTS.md defines README as player-facing; the user overrode that).

**Backfill:** from the ledger History and Budgets tables. Only rows with clear p95/p99 numbers, each tagged with its epoch. Prose-only findings stay out. Every backfilled row's `source` cites its ledger line or verification note.

**Ledger rule update:** the "Rule per milestone" section adds: record the run with `perf_record.py` and regenerate the table. The ledger stays authoritative for prose and caveats. The CSV holds numbers only.

## Automatic recording (user, 2026-11-10: local hook + CI side line)

- **Dev rows, local hook:** `tools/run_benchmark.sh` calls `perf_record.py` itself after a passing run, so no manual step. It then regenerates the table in the ledger and the README, so the working tree is always current (no git hook, no CI check; user, 2026-11-10: benchmarks already run constantly). Concurrent worktrees can conflict on the CSV tail; resolve by merging rows and regenerating. Records only on `main` with a clean tree (user, 2026-11-10: not on spike or experiment branches); `PERF_LABEL="…"` forces a record elsewhere (milestone gates). Label defaults to `auto <short sha>`; opt out with `PERF_RECORD=0`. A rerun of the same log is refused by the existing duplicate check.
- **No CI recording** (user, 2026-11-10). Runner timings are noisy, not comparable with the F-scaled dev line and have no baseline. Revisit only as a PR regression alarm after the runner noise is measured.

## Left to the builder

table styling, exact metric list (the budgeted rows in the ledger Budgets table, plus combat layouts), parser regexes, noise-threshold calculation, test shape (one small test of parse + chart in `tools/`, passing `sh tools/run_python_checks.sh`).

## Critical files

- new: `tools/perf_record.py`, `tools/perf_chart.py`, a test beside them, `docs/reference/perf-history.csv`
- edit: `docs/reference/performance.md` (generated block + rule), `README.md` (generated table block, by the user's request), `docs/development.md` (command line)
- read-only inputs: `tools/run_benchmark.sh`, `game/benchmarks/run_movement.gd`, `run_combat.gd`, `run_lockstep.gd`

## Verification

- `sh tools/run_python_checks.sh` passes.
- Record one fresh `sh tools/run_benchmark.sh` log (output to a file, timeout 600000), regenerate the table, and check the new row appears with its load tag.
- Check the failing direction: a synthetic row at 120% of budget is drawn above the 100% line and reported as "exceeded" in the summary.

## Next steps after approval

Copy this design to `docs/superpowers/specs/2026-11-10-perf-trend-charts-design.md`, then the writing-plans skill (plan written by Opus per memory). No implementation before the plan.
