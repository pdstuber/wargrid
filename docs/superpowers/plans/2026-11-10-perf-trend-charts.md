# Perf Trend Charts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Parse benchmark logs into `docs/reference/perf-history.csv` and draw committed SVG charts plus a "latest vs previous" block that answer: runs on low-end? did this change hurt? where does the cost go? how did perf evolve?

**Architecture:** `tools/perf_record.py` reads the JSON summary lines the benchmarks already print and appends raw-ms rows. `tools/perf_chart.py` holds the one budget table (mirroring the ledger Budgets table), computes % of budget at chart time, writes `docs/reference/perf/budget.svg` and `breakdown.svg`, and rewrites a marked block at the top of `docs/reference/performance.md`. A throwaway windowless-render spike runs first and decides how rendered rows get recorded.

**Tech Stack:** Python 3.12 stdlib only (`csv`, `json`, `re`, `statistics`, `subprocess`, `os.getloadavg`), `unittest`; ruff + mypy via `sh tools/run_python_checks.sh`. No matplotlib, no GDScript changes.

**Spec:** `docs/superpowers/specs/2026-11-10-perf-trend-charts-design.md`

## Global Constraints

- CSV columns, in order: `date, commit, label, machine, metric, scenario, run, p95_ms, p99_ms, mean_ms, method, load, source`. **Deviation from spec, user confirms at the Task 0 gate:** `mean_ms` added because the plumbing budget and the breakdown segments are per-tick means (ledger G12: `snapshot` + `view.copy` + `view.sort` means); the alternative (sum of zone p95s in `p95_ms`) would flip the ledger's "Ashfall passes" plumbing status.
- Raw ms only in the CSV; % of budget computed at chart time against **today's** budgets and F from one table in `perf_chart.py`.
- Today's budgets (ledger Budgets table), target / dev ms, stat: sim tick 10 / 1.82 p95, 20 / 3.64 p99; plumbing 5 / 0.91 mean; rendered frame interval 16.7 / 3.04 p95 (also the Ashfall row); lockstep overhead 3.3 / 0.6 p99. F = 5.5.
- Median line + band to worst run; summaries compare worst vs worst.
- `method` is an epoch tag (`pre-P1`, `P1`, …); a line never connects across epochs.
- Measured target machines (`deck-native`, `deck-firefox`) plotted as distinct markers at value ÷ **target** budget, never joined to the F-scaled dev line.
- `load` = 1-min load average at record time; rows above 2.5 (the T3 load guard) are drawn and listed as busy.
- Past F/budget changes are labelled vertical markers, not data steps. Never loosen a budget or F to look green; >100 % reads "exceeded".
- `sh tools/run_python_checks.sh` passes; new code fully typed; tests run as `python3 tools/test_perf_charts.py` (unittest, `unittest.main()` footer like `tools/test_session_usage.py`).
- Every benchmark, suite and check call: `timeout: 600000`, output redirected to a file in the scratchpad, read only summary lines.
- Rendered runs open a window: ask the user first, batch them. Subagents never commit or push; commit steps say **ask user**.
- README stays player-facing: one link only. Ledger stays authoritative for prose and caveats.

## Review Focus

1. Same log recorded twice (user re-runs the command) → refused, nothing appended (Task 1 `test_duplicate_log_refused`).
2. Truncated or failed log (missing `BENCHMARK PASSED`/`COMBAT BENCHMARK PASSED 10`/`LOCKSTEP BENCHMARK PASSED 1`/`RENDERED BENCHMARK PASSED 4`, or any `ERROR:` line) → exit 1, nothing appended (Task 1 `test_incomplete_log_refused`).
3. A label with only one run → "no previous run"; a metric missing from the previous label → compare against the last earlier label in the same epoch that has it (named in the line), or "not comparable" if that one is in another epoch; never a crash or an unnamed comparison (ruling 2026-11-10, gate-only rendered rows would otherwise always read "no previous run") (Task 4 `test_summary_without_previous`).
4. Ledger markers missing or duplicated → `perf_chart.py` exits 1 without touching the ledger (Task 4 `test_ledger_markers_required`).
5. Profiled rendered runs mixed into the unprofiled frame line → kept apart by scenario suffix `:profile` (Task 1 `test_profiled_rendered_rows_suffixed`, Task 2 `test_budget_ignores_profiled_rows`).

---

### Task 0: Windowless-render spike (throwaway, STOP gate)

**Files:**
- Create: `docs/reference/perf-chart-spike.md` (results only)
- Scratch only (never in the tree): scratchpad `perf-spike/` for logs and any helper page/script.

- [ ] **Step 1: Prepare without rendering.** Check `godot --help` for `--position`/`--screen`; check web export presets and `tools/serve_web_bench.py` for a rendered web build of `movement_benchmark.tscn` (if none exists, note it; build one only into the scratchpad); check `ls /Applications` for Chrome/Firefox. Record findings in the spike doc. No window yet.
- [ ] **Step 2: Ask the user ONCE for all rendered runs** (load checked first, WoW memory: report load, wait if > 2.5). Batch: (a) on-screen `sh tools/run_game.sh res://scenes/movement_benchmark.tscn` ×2; (b) off-screen `sh tools/run_game.sh --position 10000,10000 res://scenes/movement_benchmark.tscn` ×2 (or the variant Step 1 found); (c) one on-screen `-- --profile` run (also the parser's PROFILE fixture); (d) web build in headless Chrome/Firefox with GPU flags, reading `WEBGL_debug_renderer_info` `UNMASKED_RENDERER_WEBGL`. Each log to `perf-spike/<case>-<n>.log`, `uptime` before each.
- [ ] **Step 3: Run the approved batch** (`timeout: 600000`, background + Monitor until-loop). For (b) record the actual window position Godot reports or the OS shows (clamped back on screen = fail).
- [ ] **Step 4: Write `docs/reference/perf-chart-spike.md`**: tree, machine, load per run, frame p95 per layout for (a) vs (b) with noise judged against the ledger's n 2 spreads (Ashfall 2.250-2.833), clamp result, (d) renderer string (SwiftShader = fail) and whether frame timings came out. End with a line `Outcome: A works | B works | neither` and `Decision: <pending user>`.
- [ ] **Step 5: STOP.** Report to the user: outcome, the A/B numbers, the `mean_ms` deviation, and the choice: record rendered rows with every run (only if A works; needs explicit OK to loosen the AGENTS.md "ask first" rule), add a `machine=dev-browser` line (only if B works), or record at milestone gates (default). Write the user's answer into the `Decision:` line. Do not start Task 1 before it.
- [ ] **Step 6: Commit (ask user):** `git add docs/reference/perf-chart-spike.md`.

### Task 1: CSV schema and `perf_record.py`

**Files:**
- Create: `tools/perf_record.py`, `tools/test_perf_charts.py`, `docs/reference/perf-history.csv` (header row only)

**Interfaces:**
- Produces:
  - `COLUMNS: tuple[str, ...]` (Global Constraints order)
  - `class Sample(NamedTuple): metric: str; scenario: str; p95_ms: float | None; p99_ms: float | None; mean_ms: float | None`
  - `parse_log(text: str) -> list[Sample]` — raises `ValueError` naming the missing marker or the `ERROR:` line
  - `next_run(rows: list[dict[str, str]], label: str, machine: str) -> int`
  - `log_source(text: str) -> str` → `"log sha256:<first 12 hex>"`
  - `main(argv: list[str] | None = None) -> int`; CLI `python3 tools/perf_record.py LOG --label "M7.5 T3" [--machine dev] [--method P1] [--csv docs/reference/perf-history.csv]`
- Metrics produced: `movement_tick` (HEADLESS, scenarios open/dense), `combat_tick` (COMBAT `<layout>`), `lockstep_overhead` (scenario `contact`), `frame_interval` (RENDERED SAMPLE `<layout>`), `step`, `draw` and `plumbing` (PROFILE `rendered_<layout>`, `mean_ms` only; `step` = zone `step`, `draw` = zone `draw` (not `draw.units`/`draw.overlays`, which are its children); plumbing = sum of `snapshot`, `view.copy`, `view.sort` means; zone names verified in the T0 profile fixture). Rendered rows from a log that has PROFILE lines get scenario `<layout>:profile`.

- [ ] **Step 1: Capture fixtures.** `sh tools/run_benchmark.sh > <scratch>/bench.log 2>&1` (`timeout: 600000`). Paste verbatim into `test_perf_charts.py` as constants: `HEADLESS open`, `HEADLESS dense`, two `COMBAT <layout> tick_ms=` lines plus `COMBAT TRANSPORTS passenger_shots_window=` and `COMBAT HORDES300 checks_window=` (must be ignored), the `LOCKSTEP overhead_ms=` line, and the three PASSED markers. Rendered constants (`RENDERED SAMPLE ashfall`, `PROFILE rendered_ashfall zone=step|snapshot|view.copy|view.sort`, `RENDERED BENCHMARK PASSED 4`) come from the Task 0 (c) log.
- [ ] **Step 2: Write failing tests.**

```python
def test_parse_headless_log(self):
    s = {(x.metric, x.scenario): x for x in perf_record.parse_log(HEADLESS_LOG)}
    self.assertEqual(s["movement_tick", "open"].p95_ms, <p95 from fixture>)
    self.assertEqual(s["lockstep_overhead", "contact"].p99_ms, <p99 from fixture>)
    self.assertNotIn(("combat_tick", "TRANSPORTS"), s)  # summary-only lines ignored
def test_profiled_rendered_rows_suffixed(self):
    s = {(x.metric, x.scenario): x for x in perf_record.parse_log(RENDERED_PROFILE_LOG)}
    self.assertIn(("frame_interval", "ashfall:profile"), s)
    self.assertAlmostEqual(s["plumbing", "ashfall:profile"].mean_ms, snapshot + copy + sort)
    self.assertIsNone(s["plumbing", "ashfall:profile"].p95_ms)
def test_incomplete_log_refused(self):  # drop COMBAT BENCHMARK PASSED 10; separately add "ERROR: x"
    self.assertRaises(ValueError, perf_record.parse_log, truncated)
    self.assertEqual(perf_record.main([log, "--label", "T", "--csv", csv]), 1); assert csv unchanged
def test_record_appends_with_load_and_run(self):
    main twice with two different logs, same label → runs 1 and 2; load column parses as float; commit non-empty; source starts "log sha256:"
def test_duplicate_log_refused(self):
    same log twice → second main returns 1, row count unchanged
def test_method_defaults_to_last_row(self):
    CSV with last dev row method "P1", no --method → new rows "P1"; empty CSV and no --method → exit 1
```

- [ ] **Step 3: Run** `python3 tools/test_perf_charts.py` → FAIL (`No module named perf_record`).
- [ ] **Step 4: Implement `perf_record.py`.** Regexes anchored at line start (`^HEADLESS (\S+) tick_ms=(\{[^}]*\})`, `^COMBAT ([a-z0-9_]+) tick_ms=…`, `^LOCKSTEP overhead_ms=…`, `^RENDERED SAMPLE (\S+) .*frame_interval_ms=…`, `^PROFILE rendered_(\S+) zone=(\S+) mean_ms=([\d.]+)`); `json.loads` the braces. Each family found needs its PASSED marker. Commit = `git rev-parse --short HEAD`, suffixed `+dirty` when `git status --porcelain` is non-empty; load = `os.getloadavg()[0]` rounded to 2; date = today ISO. Write the CSV with `csv.DictWriter` in append mode; create header if the file is empty.
- [ ] **Step 5: Run** test → PASS; `sh tools/run_python_checks.sh > <scratch>/py.log 2>&1` (`timeout: 600000`) → `PYTHON TESTS PASSED`, exit 0.
- [ ] **Step 6: Commit (ask user).**

### Task 2: `perf_chart.py` budget table and `budget.svg`

**Files:**
- Create: `tools/perf_chart.py`; Modify: `tools/test_perf_charts.py`

**Interfaces:**
- Consumes: `perf_record.COLUMNS`, CSV rows.
- Produces:
  - `F = 5.5`, `BUSY_LOAD = 2.5`
  - `class Budget(NamedTuple): target_ms: float; dev_ms: float; stat: str` (`"p95" | "p99" | "mean"`)
  - `class Line(NamedTuple): title: str; metric: str; budget: Budget; scenarios: tuple[str, ...]` — value per run = worst over its scenarios
  - `LINES: tuple[Line, ...]`: movement p95 / p99 (open, dense); combat gated p95 / p99 (contact, skirmish3v3, transports, defences, docks, ramp, frc); combat stress p95 (open, dense, hordes300); plumbing, movement layouts (ashfall, open, dense with `:profile`); plumbing, horde (horde, large_196 `:profile`); rendered frame p95 (open, dense); Ashfall frame p95 (ashfall); lockstep p99 (contact)
  - `MARKERS: tuple[tuple[str, str], ...]` (date, text), filled from the ledger: at least `2026-11-06` "F 6 → 5.5 (budgets 1.67 → 1.82)" and `2026-11-08` "P1: movement harness sim-only"
  - `class Point(NamedTuple): label: str; date: str; method: str; machine: str; median_pct: float; worst_pct: float; busy: bool`
  - `load_rows(path: Path) -> list[dict[str, str]]`
  - `series(rows: list[dict[str, str]], line: Line) -> list[Point]` — grouped by (label, machine), ordered by first date; % = value ÷ `dev_ms` for `dev`, ÷ `target_ms` otherwise
  - `budget_svg(rows: list[dict[str, str]]) -> str`
- SVG contract the tests read: budget line `<line class="budget-line" y1=…>`; dev points `<circle class="dev" data-line=… data-pct=… cy=…>`; target points `<rect class="target" …>`; busy points carry class `busy`; each epoch segment is one `<path class="series" data-line=…>`; markers `<line class="marker">` with a `<text>`; title text contains "estimated on target device (F from ledger)".

- [ ] **Step 1: Write failing tests** (synthetic rows built by a `row(**kw)` helper):

```python
def test_exceeded_point_above_budget_line(self):  # 120 % of 1.82 = 2.184 ms
    svg = perf_chart.budget_svg([row(metric="movement_tick", scenario="open", p95_ms="2.184")])
    self.assertLess(cy_of(svg, "movement p95"), y1_of_budget_line(svg))
def test_epoch_change_breaks_line(self):  # P1, P1, pre-P1 labels → two <path class="series"> for that line
def test_target_machine_not_joined(self):  # adding a deck-firefox row adds one rect.target, path count unchanged, its data-pct = value / 10
def test_median_and_worst_band(self):  # three runs 1.0/1.1/1.5 → median_pct ≈ 60.4, worst_pct ≈ 82.4
def test_busy_row_marked(self):  # load "3.1" → circle has class busy; load "1.2" → not
def test_budget_ignores_profiled_rows(self):  # frame_interval "open:profile" row → no point on rendered frame line
def test_output_deterministic(self):  # budget_svg(rows) == budget_svg(rows)
```

- [ ] **Step 2: Run** → FAIL (`No module named perf_chart`).
- [ ] **Step 3: Implement** the table, `series`, `budget_svg` (hand-written SVG strings, fixed width 960, y axis 0 %–max(150 %, worst point + 10 %), bold 100 % line, x labels = `label`). Styling is the builder's.
- [ ] **Step 4: Run** test → PASS; python checks as in Task 1 Step 5.
- [ ] **Step 5: Commit (ask user).**

### Task 3: `breakdown.svg` (branches on the spike decision)

**Files:**
- Modify: `tools/perf_chart.py`, `tools/test_perf_charts.py`

**Interfaces:**
- Produces: `class Bar(NamedTuple): label: str; run: int; step_ms: float; plumbing_ms: float; draw_ms: float; total_ms: float; frame_p95_ms: float`; `bars(rows) -> list[Bar]`; `breakdown_svg(rows) -> str`.
- Rule (amended 2026-11-10, user): one stacked bar per (label, run) with `step`, `plumbing` and `draw` mean rows on `ashfall:profile`; `total_ms` = sum of the three; the `frame_interval` p95 is drawn as a separate marker on the bar (not a stack member, so no unmeasured remainder is hidden). Lockstep: one separate small bar per label from `lockstep_overhead` p99 on `contact`, never stacked. Caption: "segments: mean ms per tick; marker: frame interval p95". `Bar` fields: `label, run, step_ms, plumbing_ms, draw_ms, total_ms, frame_p95_ms`.

- [ ] **Step 0: Read the `Decision:` line in `docs/reference/perf-chart-spike.md`.** Default / "milestone gates": implement as written. "Every run" (A, user-approved): same code; Task 6 changes the rule text. "dev-browser" (B): STOP and ask for a plan amendment with the browser log format captured in the spike; do not guess a parser.
- [ ] **Step 1: Write failing tests:**

```python
def test_breakdown_total_is_sum_of_means(self):  # step 0.63, plumbing 0.90, draw 1.14 → total_ms 2.67; frame_p95_ms 2.5 kept separate
def test_breakdown_frame_marker_present(self):  # svg has one <line class="frame-p95"> per bar
def test_lockstep_bar_separate(self):  # svg has <rect class="lockstep"> not inside <g class="stack">
def test_breakdown_skips_unprofiled_runs(self):  # ashfall (no :profile) rows → bars() == []
```

- [ ] **Step 2: Run** → FAIL. **Step 3:** implement. **Step 4:** tests + python checks pass.
- [ ] **Step 5: Commit (ask user).**

### Task 4: "Latest vs previous" block and ledger update

**Files:**
- Modify: `tools/perf_chart.py`, `tools/test_perf_charts.py`

**Interfaces:**
- Produces:
  - `NOISE_PCT: dict[str, float]` keyed by `Line.title`: max p95 spread % of the line's scenarios from `perf-spike-verification.md` "12 results" table (movement 50.3, combat gated 57.5, combat stress 40.7); lines without n ≥ 13 data are absent → "noise not measured"
  - `summary_lines(rows) -> list[str]`, one per line with dev data, e.g. `"movement p95: 39% of budget, 3% slower than M7.5 T2 (worst vs worst), within noise (spread 50%)"`; ≥ 100 % → `"… : 120% of budget, exceeded, …"`; previous label in another epoch → `"not comparable (method pre-P1 → P1)"`; none → `"no previous run"`; busy latest run appends `", busy host (load 3.1)"`
  - `BEGIN = "<!-- perf-charts:begin -->"`, `END = "<!-- perf-charts:end -->"`
  - `update_ledger(text: str, block: str) -> str` — raises `ValueError` unless exactly one BEGIN before one END
  - `main(argv: list[str] | None = None) -> int`: `python3 tools/perf_chart.py [--csv …] [--out docs/reference/perf] [--ledger docs/reference/performance.md]`; writes both SVGs and the block (two `![…](perf/…svg)` images + summary list); exit 1 on `ValueError`, ledger untouched

- [ ] **Step 1: Write failing tests:**

```python
def test_summary_worst_vs_worst(self):  # prev runs worst 1.00, latest worst 1.10 → "10% slower"
def test_summary_exceeded(self):  # latest worst 2.184 on movement p95 → contains "120% of budget, exceeded"
def test_summary_without_previous(self):  # single label → "no previous run"
def test_summary_epoch_change(self):  # prev pre-P1, latest P1 → "not comparable"
def test_ledger_markers_required(self):  # missing END, or two BEGINs → ValueError; main returns 1 and file bytes unchanged
def test_ledger_block_replaced_idempotent(self):  # update_ledger twice == once; text outside markers unchanged
```

- [ ] **Step 2: Run** → FAIL. **Step 3:** implement. **Step 4:** tests + python checks pass.
- [ ] **Step 5: Commit (ask user).**

### Task 5: Backfill from the ledger

**Files:**
- Modify: `docs/reference/perf-history.csv`

- [ ] **Step 1: Collect rows** from `docs/reference/performance.md` History, Budgets, M4.1, F re-check, Rendered check sections and `perf-spike-verification.md` "12 results". Only rows printing clear p95 and/or p99 (or the plumbing mean) for a scenario this plan's metrics name; skip prose, scratch spikes that are not the benchmark workload (e.g. the 2026-11-03 combat scratch spike, skirmish plumbing probe), warm-up rows and in-scene tick rows. Multi-run sources record the worst run as `run=1` (conservative, matches worst vs worst); the 46020ab n 13 batch records median as run 1 and worst as run 2 only if both are printed. Each row: `machine` `dev` (or `deck-native`/`deck-firefox` for the F re-check table, `method` per row there), `method` `pre-P1` for movement rows before P1 and `P1` after, combat rows `P1` from the spike on and `pre-P1` before, `load` from the source or empty, `source` = `performance.md:<line>` or `<note>.md#<anchor>`, `commit` from the source or empty.
- [ ] **Step 2: Verify** with a scratch one-off (not committed): every backfilled row parses with `csv.DictReader`, has a non-empty `source`, and its number appears verbatim on the cited line (`rg -n` per row). List any number that does not match and fix the row.
- [ ] **Step 3: Generate** `python3 tools/perf_chart.py` (ledger markers come in Task 6; until then run with `--ledger` pointing at a scratch copy containing the markers). Open both SVGs in Firefox (`open -a Firefox`, ask the user first, batch with Task 7 if preferred) and check the movement line breaks at P1 and the M4 combat points sit near 1.5-1.6 ms ÷ 1.82.
- [ ] **Step 4: Commit (ask user).**

### Task 6: Docs and rule update

**Files:**
- Modify: `docs/reference/performance.md` (BEGIN/END block under the Status paragraph; "Rule per milestone"), `README.md` (one link), `docs/development.md` (command line beside `sh tools/run_benchmark.sh`, ~line 70), `AGENTS.md` (one line under Verification: after a merge to `main`, run `sh tools/run_benchmark.sh` on `main`; it records itself; if load > 2.5 say so and run it later), `docs/wrapup.md` (checklist step: has `main` been benchmarked since the last merge? if not, run it or list it for tomorrow). No rendered-recording rule change: the spike decided milestone gates (user, 2026-11-10).
- Create: `docs/reference/perf/budget.svg`, `docs/reference/perf/breakdown.svg` (generated)

- [ ] **Step 0 (added after Task 5 review):** `MARKERS` in `tools/perf_chart.py` are placed by date, so the P1 marker lands on the first 2026-11-08 label ("perf spike T2h", still pre-P1), about 10 labels early. Anchor each marker to a label name (first P1 label) instead of a date, with a test that the marker x equals that label's slot. Do not change data. (Deferred: the combat lines break at P1 although combat does not use the P1 harness; fixing needs method per row in `series()`; leave to the final review.)
- [ ] **Step 1:** Insert the markers in `performance.md`, run `python3 tools/perf_chart.py`, confirm the block holds two images and one summary line per line.
- [ ] **Step 2:** "Rule per milestone" adds: record each benchmark log with `python3 tools/perf_record.py <log> --label "<milestone task>"` (rendered logs per the spike decision; default: at milestone gates, where the rendered rerun is already required), then `python3 tools/perf_chart.py`; the History row stays required for prose and caveats; the CSV holds numbers only.
- [ ] **Step 3:** `development.md`: `sh tools/run_benchmark.sh > bench.log 2>&1 && python3 tools/perf_record.py bench.log --label "…" && python3 tools/perf_chart.py`. README: one line linking the ledger's chart block, not the images inline.
- [ ] **Step 4:** Check every new link and path resolves (`rg -n 'perf-history.csv|perf/budget.svg|perf-chart-spike' docs README.md AGENTS.md`), status labels unchanged.
- [ ] **Step 5: Commit (ask user).**

### Task 6b: Automatic recording by the benchmark script (added 2026-11-10, user decision; CI dropped)

**Files:**
- Modify: `tools/run_benchmark.sh`, `tools/perf_chart.py`, `tools/test_perf_charts.py`, `docs/reference/performance.md` (rule line), `docs/development.md`

**Interfaces:**
- Consumes: `perf_record.main(argv) -> int` (Task 1).

- [ ] **Step 1: Failing test:** `test_run_benchmark_skips_record_off_main` (stub git branch `spike-x` → CSV bytes unchanged, skip line printed), `test_run_benchmark_perf_label_forces_record`, `test_run_benchmark_skips_record_when_disabled` (shell: `PERF_RECORD=0` leaves the CSV bytes unchanged; stub `GODOT_BIN` prints the three PASSED markers) and `test_run_benchmark_recorder_failure_does_not_fail_gate` (recorder exits 1 → script still exits 0, warning printed). Also `test_run_benchmark_regenerates_charts` (stub run → SVG bytes change when a row is added).
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3:** `run_benchmark.sh`: after all existing checks pass, record only when the branch is `main` and the tree is clean (user, 2026-11-10: no spike or experiment branches). The cleanliness check ignores the generated files (`docs/reference/perf-history.csv`, `docs/reference/perf/`, the ledger marker block) so a record never makes the next run look dirty (Task 1 deferred minor: exclude the CSV in `perf_record.py`'s `+dirty` check too). On other branches print one line `perf: not recording (branch <b>, tree <clean|dirty>)` and skip; an explicit `PERF_LABEL="<label>"` env var forces a record anywhere (milestone gates). `PERF_RECORD=0` still disables. Label on main: `auto <short sha>`; run then run `python3 tools/perf_chart.py` so SVGs and the ledger block are always current; a failure of either prints a warning only. `perf_chart.py`: cap how many `auto` labels the x axis shows (builder's choice, stated in a caption); named labels always show.
- [ ] **Step 4:** Tests + `sh tools/run_python_checks.sh` pass. The ledger rule line and `development.md` mention the hook and `PERF_RECORD=0`.
- [ ] **Step 5: Commit (ask user).**

### Task 7: Final verification

- [ ] **Step 1:** `sh tools/run_python_checks.sh > <scratch>/py.log 2>&1` (`timeout: 600000`) → exit 0, `PYTHON TESTS PASSED`.
- [ ] **Step 2:** `uptime`; `sh tools/run_benchmark.sh > <scratch>/bench-final.log 2>&1` (`timeout: 600000`, background) → exit 0. `python3 tools/perf_record.py <scratch>/bench-final.log --label "perf charts T7"`; `python3 tools/perf_chart.py`. Check with `rg -n 'perf charts T7' docs/reference/perf-history.csv` that rows exist with a numeric `load` and that the ledger summary names the new label.
- [ ] **Step 3: Failing direction:** copy the CSV to the scratchpad, append a synthetic `movement_tick open` row at p95 2.184, run `perf_chart.py --csv <copy> --out <scratch>/perf --ledger <scratch copy of ledger>`; confirm the point is above the 100 % line and the summary says "exceeded". Real files untouched (`git diff --stat` shows only intended changes).
- [ ] **Step 4:** Open both SVGs in Firefox (ask first). GitHub rendering: unverified until the user approves a push; report it as unverified.
- [ ] **Step 5:** `/ponytail-review` on the branch diff, apply cuts, re-run Step 1.
- [ ] **Step 6:** Report: tree, counts, exit codes, load, unverified items. Commit (ask user); push needs separate approval.
