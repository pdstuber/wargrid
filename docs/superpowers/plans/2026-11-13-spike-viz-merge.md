# spike-visualization merge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge `spike-visualization` into `main` with the README roadmap generated from `docs/packages.md` + `docs/STATUS.md`, a tick-frame rendered area and the 2026-11-10+ ledger rows backfilled.

**Architecture:** Merge commit on branch `viz-merge` (worktree `~/projects/wargrid-wt-viz`, off `main` `83a3c7b`), then one commit per task. Python tools only; no game code.

**Tech Stack:** Python 3 stdlib (`unittest`, `csv`, `re`), POSIX sh.

**Spec:** `docs/superpowers/specs/2026-11-13-spike-viz-merge-design.md`

## Global Constraints

- Never hand-edit generated blocks (`roadmap:`, `perf-table:`, `perf-charts:` markers); change the source and rerun the tool.
- Don't touch: `tools/zh_parity/`, `relay/`, the test runner (`tools/run_tests.sh` and its Godot runner), `web/`.
- `AGENTS.md`: keep main's text; add only the branch's perf-recording and generated-block rules, linking rather than duplicating.
- Recording rule unchanged: auto on clean `main`, `PERF_LABEL` forces, `PERF_RECORD=0` off.
- Commits local only on `viz-merge`; merge to `main` and push only with explicit user approval. Subagents never commit.
- Edit with the Edit tool or asserted replacements; agent shells use `gsed -i` (GNU) or `sed -i ''`.
- Nothing built in the last days may break (user, 2026-11-13): `git diff --stat main...viz-merge -- game relay protocol web .github` stays empty; `run_benchmark.sh` keeps every pass/fail check and exit path main has; suite case counts equal main's.

## Review Focus

1. Done package that left the Day lane (P1, P1.1, P2 today): must still show as Done, read from STATUS. Test in Task 2.
2. STATUS row whose state starts "Done" but the package is still in the Day lane table (P1.1 today): one row, Done, at its Day lane position, no duplicate. Test in Task 2.
3. A label with both `frame_interval` and `tick_frame` rows (the art lab rows): the area uses only `tick_frame`, never the max of both. Test in Task 3.
4. Current main benchmark log (new `WORST TICK`, `OVER BUDGET`, `BUDGET EXCEEDED`, extra combat rows): `perf_record.py` parses it without error. Checked in Task 5 on a real log; fixture line in Task 3.
5. Real `packages.md` and STATUS parse without errors (a reworded heading or table would silently empty the roadmap): Task 2 Step 7 runs `python3 tools/roadmap.py --check` on the real files and reads the rendered table; wrap-up runs `python3 tools/roadmap.py` then `--check`, and a parse error is listed for the user. Not in CI (user, 2026-11-13).

---

### Task 1: Merge and resolve conflicts

**Files:** `AGENTS.md`, `docs/development.md`, `docs/reference/performance.md`, `docs/wrapup.md`, `tools/run_benchmark.sh` (conflicts); `README.md`, `docs/milestone-prompt.md` (auto-merged, check).

- [ ] **Step 1:** In `~/projects/wargrid-wt-viz`: `git merge --no-ff --no-commit spike-visualization`. Expected: 5 conflicts as listed. Different set: stop and report.
- [ ] **Step 2: `tools/run_benchmark.sh`:** main's file unchanged through its last line (`[ -z "$over" ] || echo "BUDGET EXCEEDED …"`), then the branch's `record_perf` function, the `record_perf || echo …` line and `exit 0`.
- [ ] **Step 3: `AGENTS.md`:** main's text. In main's "Performance targets a low-end device" bullet, append the branch's `PERF_LABEL`/rendered-log sentence. Add the branch's "After a merge to `main`, run `sh tools/run_benchmark.sh` …" bullet at the top of "Verification and desktop use", shortened to: records itself on a clean `main`, `PERF_LABEL` forces, `PERF_RECORD=0` off, load above 2.5 → say so and run later, generated status blocks never hand-edited (link the ledger). Keep the branch's roadmap bullet for now (Task 2 rewrites it).
- [ ] **Step 4: `docs/development.md`, `docs/wrapup.md`:** main's text plus the branch's additions: the two command lines (`roadmap.py`, benchmark-to-log) in the commands block; wrapup gets the branch's step 1 (benchmark `main`) at the top, renumbered, and the `roadmap.py --check` sentence in the status-agreement step.
- [ ] **Step 5: `docs/reference/performance.md`:** main's text plus the branch's generated block and its intro lines where the branch put them (top of file); then `python3 tools/perf_chart.py` regenerates the blocks.
- [ ] **Step 6:** `rg -n '^(<<<<<<<|=======|>>>>>>>)' AGENTS.md docs tools README.md` → no hits. `sh tools/run_python_checks.sh > build/py.log 2>&1; echo "exit=$?"` → exit 0 (the branch's tests on merged files; `test_perf_charts.RunBenchmarkTest` runs `run_benchmark.sh` with stub logs that lack main's `WORST TICK` lines: add 2 / 10 / 1 such lines to the stub logs, never relax the script; `RealFilesTest` may fail only if README's roadmap block is stale: then `python3 tools/roadmap.py` and rerun).
- [ ] **Step 7:** Commit: `Merge spike-visualization` (subject), body one line: "Perf recording, status table and README roadmap; conflicts keep main's text."

### Task 2: Roadmap from packages.md and STATUS (test first)

**Files:**
- Modify: `tools/roadmap.py`, `tools/test_roadmap.py`, `docs/packages.md` (Later section), `README.md` (block position and lead-in line), `AGENTS.md` (roadmap bullet), `docs/development.md` (roadmap command comment), `docs/wrapup.md` (roadmap sentence), `docs/roadmap-wording.md`
- Delete: `docs/roadmap.toml`, `.claude/commands/roadmap-wording.md`

**Interfaces:**
- Produces in `tools/roadmap.py`:
  - `MILESTONES: tuple[str, ...]` = the 7 done names from `docs/roadmap.toml` rows with `state = "done"`, in file order ("Move and select units" … "Releases and sound").
  - `STATES = {"done": ("✅", "Done"), "next": ("⏭", "Next"), "planned": ("📋", "Planned"), "later": ("💡", "Later")}`.
  - `Row = tuple[str, str]` (name, state).
  - `status_packages(text: str) -> list[tuple[str, str, bool]]`: STATUS `## Packages` table rows as (id, name, done); done = State cell starts with "Done". Rows whose id starts with `night` skipped.
  - `day_lane(text: str) -> list[tuple[str, str]]`: `packages.md` `### Day lane` table as (id, name).
  - `later_names(text: str) -> list[str]`: `### Later` numbered items' `**Name:**` lead (text between `**` and `:**`).
  - `rows(packages: str, status: str) -> tuple[list[Row], list[str]]`: (rows, errors). Order: `MILESTONES` as done; then STATUS done packages not in the Day lane, in STATUS order; then Day lane rows (done if STATUS says done, else the first not-done one is `next`, the rest `planned`); then Later names as `later`. Errors: a Later item without a bold name (`"Later item N has no **Name:** lead"`); a `P…` STATUS row neither done nor in the Day lane (`"STATUS package P3 is not done and not in the Day lane"`); no Later section or Day lane table found.
  - `block(rows: list[Row]) -> str`: unchanged format from the branch (`**N of M parts done**` headline and `| | What | State |` table).
  - `main(argv)`: flags `--packages` (default `docs/packages.md`), `--status` (default `docs/STATUS.md`), `--readme`, `--check`; drops `--toml`, `--blueprint`; keeps the branch's error and write paths.

- [ ] **Step 1: Rewrite `tools/test_roadmap.py`** with small inline fixture strings (a 3-row Day lane, a 4-row STATUS table incl. one `night 1` row, 2 Later items). Tests and assertions:
  - `test_milestones_come_first_as_done`: first 7 rows == `[(m, "done") for m in MILESTONES]`.
  - `test_done_package_off_the_day_lane_comes_from_status`: STATUS `P1 | Tell us what you see | Done: …`, not in Day lane → row `("Tell us what you see", "done")` right after the milestones.
  - `test_done_package_still_in_the_day_lane_appears_once`: P1.1 Done in STATUS and in Day lane → exactly one `("Laborers that pay", "done")`, at its Day lane position.
  - `test_first_open_day_package_is_next_rest_planned`: states of the open Day lane rows == `["next", "planned"]`.
  - `test_later_items_use_bold_names`: `"1. **Order controls:** control groups…"` → `("Order controls", "later")`.
  - `test_later_item_without_bold_name_is_an_error`, `test_open_status_package_missing_from_day_lane_is_an_error`, `test_night_rows_are_ignored` (a `night 1` row not in the Day lane gives no error and no row).
  - Keep the branch's `FilesTest` cases (write idempotently, `--check` stale/current, check does not write, invalid data writes nothing, missing/duplicate marker) adapted to `--packages`/`--status` temp files; drop toml, draft-candidate and blueprint-key tests.
  - Drop `RealFilesTest`: a stale README must never fail CI (user, 2026-11-13); wrap-up regenerates and checks instead.
- [ ] **Step 2:** `cd tools && .venv/bin/python -m unittest test_roadmap -v > ../build/rm.log 2>&1; echo "exit=$?"` → exit 1, failures/import errors on the new names.
- [ ] **Step 3: Implement `tools/roadmap.py`** to the Interfaces block. Table parsing: lines starting `|` after the heading until the next heading, skip the header and `|---` rows, split on `|`, strip cells.
- [ ] **Step 4: `docs/packages.md` Later section:** give each of the 10 items a `**Name:**` lead, keeping the rest of the text; names: Order controls, Movement packages, Minimal real HUD, Unit avoidance, Fog of war, Ground batch A, Art pass, Ground batch B, Bots, 3v3 online. Item 1 keeps "Orders that feel yours" in its text.
- [ ] **Step 5: `README.md`:** move the `roadmap:begin/end` block into `## Status`, after the "Early development…" paragraph, perf-table block right below it; the lead-in line reads "What is done and what comes next (generated from [packages](docs/packages.md) and [STATUS](docs/STATUS.md)):". Then `python3 tools/roadmap.py`.
- [ ] **Step 6:** Delete `docs/roadmap.toml`, `.claude/commands/roadmap-wording.md`. `docs/roadmap-wording.md` becomes 2-3 lines: package names in `docs/packages.md` are the README roadmap's lines, so they are plain words for players, not labels; generated by `python3 tools/roadmap.py`, never edited in the README. Update the roadmap mentions in `AGENTS.md` (one bullet: block generated from packages and STATUS, change names or states there, link the wording rule), `docs/development.md` (command comment) and `docs/wrapup.md` (run `python3 tools/roadmap.py`, then `--check`; a parse error goes to the user; drop "list rows still `draft`"). `rg -n 'roadmap.toml|roadmap-wording|draft' AGENTS.md docs/development.md docs/wrapup.md docs/milestone-prompt.md README.md tools` → only intended hits.
- [ ] **Step 7:** Run Step 2's command → exit 0; `python3 tools/roadmap.py --check; echo "exit=$?"` → exit 0 and the README table lists 7 milestones, P1, P1.1, P2 done, P2.1 next, P2.2-P5 planned, 10 Later rows; `sh tools/run_python_checks.sh > build/py.log 2>&1; echo "exit=$?"` → exit 0.
- [ ] **Step 8:** Commit "Generate the README roadmap from packages and STATUS" + one line "roadmap.toml duplicated package state; names and states now have one home."

### Task 3: Tick-frame area (test first)

**Files:** Modify `tools/perf_record.py`, `tools/perf_chart.py`, `tools/test_perf_charts.py`.

**Interfaces:**
- `perf_record.py`: `RENDERED` also captures `tick_ms`; each `RENDERED SAMPLE <layout>` line yields `Sample("frame_interval", layout, …)` as today plus `Sample("tick_frame", layout, p95, p99, None)` from its `tick_ms` summary. Rows recorded from a rendered log get `method` = `tick-frame` for `tick_frame` samples (the CSV `method` column; other samples keep today's value).
- `perf_chart.py`: `Line.metric` becomes `metrics: tuple[str, ...]` (preference order). Per label, `series` uses the first metric in `metrics` that has rows for that label. The two rendered lines become `metrics=("tick_frame", "frame_interval")`; every other line `(old_metric,)`. Names stay "Drawing the screen" / "Drawing the screen, big map (Ashfall)".

- [ ] **Step 1: Tests in `tools/test_perf_charts.py`:**
  - `test_rendered_sample_records_tick_frame`: a `RENDERED SAMPLE open … tick_ms={"p95":2.9,"p99":3.5,…} frame_interval_ms={"p95":0.6,…}` line parses to samples with `("tick_frame","open",2.9,3.5,None)` and `("frame_interval","open",0.6,…)`.
  - `test_area_prefers_tick_frame_within_a_label`: one label with `tick_frame` p95 2.9 and `frame_interval` p95 0.6 → point `worst_pct` == 2.9/3.04*100.
  - `test_switch_to_tick_frame_reads_as_method_change`: older label only `frame_interval` (method `post-P1`), newer label `tick_frame` (method `tick-frame`) → `_vs_last` text contains "method changed".
  - `test_current_main_log_lines_parse`: a fixture combining a `WORST TICK …`, `OVER BUDGET …` and `BUDGET EXCEEDED …` line with one `HEADLESS` line parses without error (copy the exact line shapes from `game/benchmarks/bench_runner.gd` and `tools/run_benchmark.sh` on this tree).
- [ ] **Step 2:** `cd tools && .venv/bin/python -m unittest test_perf_charts -v > ../build/pc.log 2>&1; echo "exit=$?"` → exit 1 on the new tests only.
- [ ] **Step 3:** Implement to the Interfaces block; update every `line.metric` use.
- [ ] **Step 4:** Step 2's command → exit 0; `python3 tools/perf_chart.py` regenerates; `sh tools/run_python_checks.sh > build/py.log 2>&1; echo "exit=$?"` → exit 0.
- [ ] **Step 5:** Commit "Chart rendered rows by tick frame" + one line "Frame interval with vsync off measures non-tick frames (art lab C1)."

### Task 4: Backfill ledger rows 2026-11-10 onward

**Files:** Modify `docs/reference/perf-history.csv` (and regenerated blocks in `performance.md`, `README.md`).

- [ ] **Step 1:** For each History row in `docs/reference/performance.md` dated 2026-11-10 or later (rows 87-102 on `main` `83a3c7b`; re-find with `rg -n '^\| 2026-11-1' docs/reference/performance.md`), add CSV rows for every number a `LINES` area reads (movement/combat/lockstep tick p95/p99, plumbing mean, rendered tick-frame p95 per layout, Ashfall). Columns as the branch's backfill: `date`, empty `commit` unless the row names one, `label` = short row name (e.g. `art lab winners`, `P1 gate`, `c1 gate`, `P2 gate`), `machine=dev` (Mac rows only; skip Steam Deck/web rows), `run` per n, `method` = `tick-frame` for tick-frame rows else the branch's current method value, `load` = highest load the row states, `source` = `performance.md@83a3c7b:<line>`. Report-only rows (P2 playtest match, perf-next experiments, split A/B, noise check) are skipped: they are not gate measurements; list each skipped row with its reason in the task report.
- [ ] **Step 2:** `python3 tools/perf_chart.py`; read the generated README table; every area's "As of" date is plausible (rendered areas 2026-11-12 from the P1 rendered gate if it gives tick-frame numbers).
- [ ] **Step 3:** `sh tools/run_python_checks.sh > build/py.log 2>&1; echo "exit=$?"` → exit 0.
- [ ] **Step 4:** Commit "Backfill perf history from the art lab on".

### Task 5: Gates, live record check, review

- [ ] **Step 1:** In the worktree, each to `build/<name>.log`, judged by exit code (`timeout: 600000`): `sh tools/run_python_checks.sh`, `sh tools/run_shell_checks.sh`, `sh tools/check_public.sh`, `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/run_tests.sh`. Suite summary line (cases/checks) equals the same run on `main` `83a3c7b` (run it there too, before or after).
- [ ] **Step 1b: no-break checks:** `git diff --stat main...viz-merge -- game relay protocol web .github` → empty. `git diff main...viz-merge -- tools/run_benchmark.sh` → only added lines after main's last line. Failure path: copy the worktree to a scratch dir, make one benchmark check fail (e.g. change `BENCHMARK PASSED 2` to `3` in the scratch `run_benchmark.sh`), run it → exit 1 and CSV unchanged. Recording failure path: `PERF_LABEL=x` with `tools/perf_record.py` made to raise in the scratch copy → `perf: WARNING …` printed, exit 0, benchmark verdict unchanged.
- [ ] **Step 2:** `uptime` before and after; `PERF_LABEL="viz-merge check" sh tools/run_benchmark.sh > build/bench.log 2>&1; echo "exit=$?"` → exit 0, no `perf: WARNING` line, CSV gained rows with that label. Then revert those rows and the regenerated blocks (`git checkout -- docs/reference/perf-history.csv docs/reference/performance.md README.md`), since the real record comes on `main` after the merge.
- [ ] **Step 3:** Fresh Opus review of `git diff main...viz-merge` (diff + file paths, no repo search), docs with code claims included; apply confirmed findings, re-run affected gates.
- [ ] **Step 4:** `/ponytail-review` on the diff; apply cuts, re-verify.
- [ ] **Step 5:** Ask the user to approve the merge into local `main`; after the merge, `sh tools/run_benchmark.sh` on clean `main` records the `auto <sha>` row (tag load), user approves that commit; push only on separate approval.
