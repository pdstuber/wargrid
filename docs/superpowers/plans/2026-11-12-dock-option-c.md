# Dock Option C Implementation Plan

**Status: approved by the user 2026-11-12 (questionnaire answers below); unattended subagent run.**

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. Run rules: [milestone prompt](../../milestone-prompt.md), unattended section, with the overrides under "Run rules" below.

**Goal:** Measure dock option C (one pile lock per credit for every collector, two constants), the 1..8 collector saturation curves on both sides with saturation and payback metrics, and a per-phase breakdown of the frc7 shortfall, and add them to the dock-hold note. Evidence only.

**Architecture:** Two new test-only dock models `c1` and `c2` reuse split's lead/lock mechanics with pile locks from a per-credit rule. The parity harness gains a 1..8 collector sweep and a saturation metric; the report suite gains sweep, metric and phase lines behind an env switch. The note gets an Option C section and an updated decision list.

**Tech Stack:** typed GDScript (Godot 4.7.2), Python 3 stdlib (harness), Zero Hour source build via the parity harness.

**Spec:** [dock-hold experiment design](../specs/2026-11-12-dock-hold-experiment-design.md) plus the decisions below; evidence so far: [dock-hold experiment note](../../reference/dock-hold-experiment.md) (items 6 and 7 of its decision list), `~/projects/wargrid-dock-work/research-report.md` (option C), `~/projects/wargrid-dock-work/web-research-report.md` (metrics).

## Decisions (user, 2026-11-12)

- Two C variants: `c1` = 184 / 300 ticks per credit (Zero Hour truck pile lock), `c2` = 44 / 75 (the median of the three measured ratios 44/75, 184/300, 345/600, which is the worker's).
- Depot locks under C: as split (per-kind measured).
- 1..8 collector sweep on both sides. Zero Hour: worker at 162.5 and 312.5 units, truck and Chinook at 312.5 units (the gated MULTI depots plus worker far), 3 reps each.
- frc7 breakdown: both sides, from existing Zero Hour traces (no new games for it); Wargrid per-tick phases.
- Reviews: per code task a Sonnet task review, then an Opus final whole-branch review and an Opus note review.
- Blocked: rule and continue, record every ruling; ping the phone only for a stop condition.
- Stop: after the reviewed note update on `dock-hold`; local commits only; no cherry-pick, no push.
- Zero Hour parity game launches through the harness are pre-approved (user, 2026-11-12), always headless and silent.
- Metric 3 (faction-priced basket) stays out until a basket is chosen.

## Global Constraints

- Evidence only. Default `hold` unchanged: full suite passes with every pinned trace and digest identical; `hold`, `split` and `queue` report lines byte-identical to `~/projects/wargrid-dock-work/wargrid-{hold,split,queue}.txt`. No change under `game/scripts/simulation/definitions/`, to any gated target or tolerance.
- Branch `dock-hold` only (worktree `~/projects/wargrid-wt-dock`, head `f7c9e02` at plan time). Harness tooling commits stay separate from game commits (cherry-pickable later).
- Kind-keyed tables live under `game/scripts/experiments/` (`tools/test_faction_guard.py`). Tests use only the simulation interface (no underscore members, no `active_collector_id`).
- Pass rule as in the design: eight opening rows within 5 % of Zero Hour in net at 600 s and in steady rate; single-collector `TARGETS` rows within 5 %; five `MULTI` rows and Chinook x4 within 5 % of the re-measured steady targets (`~/projects/wargrid-dock-work/zh/pooled.md`). Old window reported, not judged.
- Steady window 300-600 s after the gather order, ending at pile empty; short when it ends before 450 s.
- Zero Hour runs only through `tools/zh_parity/parity.py` (`-headless -noaudio`); fork `a75330d82` is built; never `pkill` broadly, `--kill DIR` only.
- Determinism rules: integer ticks, ordered containers.
- Work folder `~/projects/wargrid-dock-work/` (new outputs under `c/`).

## Run rules (overrides for this run)

- Coordinator: a Sonnet session in `~/projects/wargrid-wt-dock`; implementers Sonnet; per-task reviewers Sonnet; final and note reviews Opus. Implementers never commit; the coordinator commits after each clean review (pre-authorized local commits).
- Long commands with Bash `timeout: 600000` or `run_in_background`; wait for completion notifications; no sleep polling.
- Ledger: run `scripts/sdd-workspace` on this plan; the ledger is the resume record.

## Review Focus

1. `c1`/`c2` change a lone collector's cycle (lead + lock must equal today's stand per kind and target). Test in Task 1.
2. A computed pile lock longer than today's stand (lead would go negative): clamp to `lead = 0`, keep today's ticks; reported. Test in Task 1.
3. Zero Hour x1 `_s600` rows: `collecting()` takes its lone-collector `phases()` path, which needs `unit`, `pile`, `depot` meta (present in `collect()`); a crash there kills the sweep. Test in Task 2.
4. A pile emptying inside the window at N = 7-8 Chinooks (about 3100+ per minute drains 30,000 credits near 600 s): window cut and flagged on both sides; the saturation metric must use the flagged rows honestly. Test in Task 2 (metric) and Task 3 (Wargrid line).
5. Marginal income at or below zero: payback reported as `inf` (never a negative or divide-by-zero). Tests in Tasks 2 and 3.

---

### Task 1: Dock models c1 and c2

**Files:**
- Create: `game/scripts/experiments/dock_c.gd` (tables `C1`, `C2`)
- Modify: `game/scripts/simulation/supply_collection.gd` (`DOCK_MODELS` += `"c1", "c2"`; `_lead`, `_load_delay`, `_unload_delay` read the table of the active model for `split`, `c1`, `c2`)
- Modify: `game/tests/test_dock_models.gd` (`MODELS` += `"c1", "c2"`; tests below)

**Interfaces:**
- Produces: `C1`, `C2` with split's shape `{kind: {"source": {"lead", "box"}, "depot": {"lead", "work"}}}`, built from: `E = ceil(boxes * box_value * r)`; `box = round(E / (boxes + 1))`; `lead = (boxes + 1) * load_ticks - (boxes + 1) * box`, clamped: if `E >= (boxes + 1) * load_ticks` then `lead = 0, box = load_ticks`; depot entries copied from split. Values (from `Registry`: frc 1 box / 42 / 45, china 4 / 38 / 37, usa 8 / 43 / 213, box value 75):

| model | kind | E | source lead / box | depot lead / work |
|---|---|---|---|---|
| c1 (184/300) | frc_builder | 46 | 38 / 23 | 6 / 39 |
| c1 | china_collector | 184 | 5 / 37 | 0 / 37 |
| c1 | usa_collector | 368 | 18 / 41 | 60 / 153 |
| c2 (44/75) | frc_builder | 44 | 40 / 22 | 6 / 39 |
| c2 | china_collector | 176 | 15 / 35 | 0 / 37 |
| c2 | usa_collector | 352 | 36 / 39 | 60 / 153 |

- [ ] **Step 1: Failing tests:** `test_c_tables_follow_the_rule` (recompute every entry from `Registry` values and both ratios with the formula above, compare with `C1`/`C2`; assert lead + (boxes+1)·box == today's pile stand and depot lead + work == unload_ticks for every kind); `test_c_lone_cycle_unchanged` (first 9 deposit ticks of a lone collector per `TARGETS` kind at gap 3 equal under hold, c1 and c2).
- [ ] **Step 2:** `WARGRID_TEST_ONLY=test_dock_models sh tools/run_tests.sh` fails.
- [ ] **Step 3: Implement.** Keep the split code path; only the table lookup changes. If the table values computed in Step 1 differ from the table above, the formula wins: record a ruling.
- [ ] **Step 4:** Suite file passes; full suite green with earlier counts plus the new cases; hold/split/queue report lines byte-identical; lint, warnings, `run_python_checks.sh` exit 0. Save `c1`/`c2` report lines to `~/projects/wargrid-dock-work/c/wargrid-c1.txt` and `wargrid-c2.txt`.

### Task 2: Harness 1..8 sweep and saturation metric (tooling only)

**Files:**
- Modify: `tools/zh_parity/parity.py` (register `collect_<kind>_u<units*10>_x<n>_s600` for n in 1..8 for (worker, 162.5), (worker, 312.5), (truck, 312.5), (chinook, 312.5); existing `_s600` names keep their meaning)
- Modify: `tools/zh_parity/analyze.py` (`saturation(rates: dict[int, float | None], collector_cost: int) -> dict`; `--saturation DIR...` prints one JSON line per kind and depot from pooled steady medians)
- Test: `tools/test_zh_parity.py`

**Interfaces:**
- Produces: `saturation(rates, collector_cost)` returns `{"cap": float, "n_cap": int, "n90": int, "spend90": int, "marginal": {n: float}, "payback_s": {n: float}}` where `cap` = highest steady rate, `n90` = smallest n with rate ≥ 0.9 · cap, `spend90 = (n90 - 1) * collector_cost` (the first collector is free with the depot), `marginal[n] = rate[n] - rate[n-1]` (n ≥ 2), `payback_s[n] = collector_cost / (marginal[n] / 60)` or `float("inf")` when `marginal[n] <= 0`; rows with `None` rate or a short window are skipped and listed under `"skipped"`.
- Collector costs (retail INI, income plan): worker 200, truck 600, Chinook 1200.

- [ ] **Step 1: Failing tests:** `test_saturation_curve` (rates {1: 434, 2: 855, 3: 1270, 4: 1650, 5: 2000, 6: 2010, 7: 2010, 8: 1990}, cost 200 → cap 2010, n_cap 6, n90 5, spend90 800, marginal[6] 10, payback_s[8] inf); `test_saturation_skips_short` (a None and a short row listed in skipped, not used); `test_sweep_rows_registered` (all 32 names exist, each with `seconds == 600` as in `test_long_rows_registered`); `test_x1_long_row_metrics` (a synthetic lone-collector `_s600` trace through `metrics()` returns steady and lock windows without error).
- [ ] **Step 2:** `python3 -m unittest discover -s tools -p 'test_zh_parity.py'` fails.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Tests pass; `sh tools/run_python_checks.sh` exit 0.
- [ ] **Step 5:** Long-sweep rule: run `collect_chinook_u3125_x8_s600` once end to end (`--out ~/projects/wargrid-dock-work/c/zh-probe`); check 8 depositors and the pile-empty field.

### Task 3: Wargrid sweep, metrics and frc7 phases (report-only)

**Files:**
- Modify: `game/tests/test_dock_models.gd` (new case `test_sweep_rows`, runs only with `WARGRID_DOCK_SWEEP=1`, otherwise checks 1 and returns)
- Create: `game/tests/dock_metrics.gd` (`static func saturation(rates: Dictionary, collector_cost: int) -> Dictionary`, same contract as the Python one)

**Interfaces:**
- Consumes: `layout(kind, gap, count, model)` and `steady_rate(sim, gather_tick)` from `test_supply_parity.gd`; `run_opening(name, gap, model)` from `test_income_openings.gd`.
- Produces lines, per model in `models()`: `DOCK <m> sweep <kind> gap=<g> n=<n> steady=<f> pile_empty=<s|-> short=<bool>` for (frc_builder, 3), (frc_builder, 9), (china_collector, 9), (usa_collector, 9), n 1..8; `DOCK <m> saturation <kind> gap=<g> cap=<f> n_cap=<n> n90=<n> spend90=<int> marginal=<n:f,...> payback_s=<n:f|inf,...>`; `DOCK <m> phases frc7 gap=3 <phase>=<share %>,...` = per-tick phase shares (from `view_state()` phases, summed over the 7 workers, steady window 300-600 s) for hold, split, c1, c2.
- Collector costs from `Definitions.unit(kind).cost`.

- [ ] **Step 1: Failing tests:** `test_wargrid_saturation_matches_python` (the same synthetic curve as Task 2 Step 1 gives the same cap, n90, spend90, marginal and inf payback); `test_phase_shares_sum_to_100` (a short frc7 run under hold: shares sum to 100 ± 0.1 and include `loading` and `unloading`).
- [ ] **Step 2:** `WARGRID_TEST_ONLY=test_dock_models sh tools/run_tests.sh` fails.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** `WARGRID_DOCK_SWEEP=1 WARGRID_TEST_ONLY=test_dock_models sh tools/run_tests.sh` in the background; save lines to `~/projects/wargrid-dock-work/c/wargrid-sweep.txt`. Full suite (without the switch) green; lint, warnings exit 0.

### Task 4: Zero Hour sweep and the frc7 breakdown (no repo code unless a bug)

**Files:** results in `~/projects/wargrid-dock-work/c/zh/` and `~/projects/wargrid-dock-work/c/frc7-zh.md`.

- [ ] **Step 1:** `python3 -I tools/zh_parity/parity.py --out ~/projects/wargrid-dock-work/c/zh --repeats 3 --lanes 3 'collect_*_x[1-8]_s600'` restricted to the 32 names of Task 2 (`--list` first; 96 jobs, about 1.5-2 h) in the background; `runs.jsonl` all finished. A failed job is retried by the harness; a scenario that fails twice is recorded, not chased (ruling).
- [ ] **Step 2:** Pool (`analyze.py --json` over rep1-3) and `analyze.py --saturation`; write `c/zh/pooled.md` (steady median and spread per kind, depot and n; pile empty and short flags; saturation metrics).
- [ ] **Step 3: frc7 breakdown, Zero Hour side** from `~/projects/wargrid-dock-work/zh-open/rep{1,2,3}/open_worker_u1625_x7.tsv` (lock rows present): per worker in 300-600 s, share of frames moving, standing near the pile, standing near the stash, and share of frames holding the pile or stash lock; trips per worker and the median trip time. A throwaway script in the work folder; numbers into `c/frc7-zh.md` with the method.

### Task 5: Note update (stop)

**Files:**
- Modify: `docs/reference/dock-hold-experiment.md` (new section "Option C and saturation (2026-11-12)"; decision list items 6 and 7 get results; payoff paragraph gets one sentence on C)

- [ ] **Step 1:** Write: pass/fail per c1/c2 over the 22 judging rows next to hold and split; saturation curves table both sides (cap, n90, spend90, marginal and payback per n) with flags; frc7 phase shares (Wargrid per model, Zero Hour from traces) and what they say about the 14 % vs 6 % contention (cause or "not established"); updated decision list (no option marked decided; recommendations labelled). Labels: measured (source build, fork a75330d82), measured (Wargrid, branch tree <hash>), arithmetic.
- [ ] **Step 2:** `sh tools/check_public.sh` exit 0; links resolve.
- [ ] **Step 3:** Opus note review against the evidence files; fix; Opus final whole-branch review of the Task 1-3 diffs; one fix wave; scoped re-review.
- [ ] **Step 4:** Commit. **STOP:** push a phone notification with the one-line answer; the user decides.
