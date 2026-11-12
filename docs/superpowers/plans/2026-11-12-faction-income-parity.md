# Faction Income Parity Measurement Plan

**Status: approved by the user 2026-11-12 (openings as listed, no third Chinook; subagent-driven run); evidence only, no game number changes.**

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Run rules: [milestone prompt](../../milestone-prompt.md).

**Goal:** Answer two questions with measurements: (1) is income per faction even in Zero Hour for the community openings, and (2) does Wargrid reproduce Zero Hour's result per opening?

**Architecture:** One new harness scenario family in `tools/zh_parity/parity.py` records a whole opening from the depot order (build time, collector training, travel, deposits) in Zero Hour; a new metric in `analyze.py` turns a trace into gross and net credits at fixed times and a steady rate. The same openings run headless in Wargrid through the simulation interface (real `build` and `produce` commands), printed as report-only rows. A reference note compares both. Existing per-collector rates are already at parity within 2 % ([economy archive](../../reference/m7-verification-archive-economy.md), T3 record; gated by `test_supply_parity.gd`); this plan measures what they do not: whole openings and faction against faction.

**Tech Stack:** Python 3 (harness, stdlib only), the Zero Hour source build of the [parity harness](../../reference/zero-hour-parity-harness.md) (always `-headless -noaudio`), typed GDScript test suite.

**Spec:** user request (2026-11-12, after the P1 playtest): "cash inflow equal for all the factions ... the base of the economy"; community openings named by the user: 2 USA helicopters, 3 China trucks, 5-7 GLA workers ("the 7 always felt ... unproven"). Prior evidence: [supply parity measured](../../reference/m7-supply-parity-measured.md), [economy parity](../../reference/m7-economy-parity.md).

## Global Constraints

- Evidence only (AGENTS: parity results feed a decision list, never an automatic number change). No file under `game/scripts/simulation/` or `game/scripts/definitions/` changes.
- Openings (count includes the free collector): `usa2` = Supply Center + 1 Chinook; `china3` = Supply Center + 2 trucks; `frc5` = Stash + start worker + 3 trained; `frc7` = Stash + start worker + 5 trained. GLA's start worker builds the stash, then collects; USA and China builders do not collect.
- Opening spend from retail INI (`python3 tools/zh_ini.py dump`, `build/zh_ini/inizh.jsonl`): AmericaSupplyCenter 2000 (`factionbuilding.ini:18715`), AmericaVehicleChinook 1200 (`americaair.ini:2203`), ChinaSupplyCenter 1500 (`factionbuilding.ini:21222`), ChinaVehicleSupplyTruck 600 (`chinavehicle.ini:2003`), GLASupplyStash 1500 (`factionbuilding.ini:19888`), GLAInfantryWorker 200 (`glainfantry.ini:3721`). So `usa2` 3200, `china3` 2700, `frc5` 2100, `frc7` 2500. Wargrid reads its own costs from `definitions/`; a cost mismatch is a finding, not a fix.
- Layout: one 400-box `SupplyDock`, depot at 162.5 and at 312.5 units centre to centre (Wargrid gaps 3 and 9, the layouts both sides already reach). Prerequisites (power plant where needed) spawned complete before t = 0; t = 0 is the depot build order. Start money 10000.
- Times: gross and net credits (gross minus opening spend) at 60, 120, 180, 300 and 600 s; steady rate = credits per minute between the last collector's first deposit and t = 600 s (or pile empty). Report the time at which net turns positive.
- Zero Hour: 3 repeats per row; spread over 5 % is reported, not hidden. Wargrid is deterministic: one run per row.
- Long sweeps rule: run one row end to end and check the pile does not run dry before 600 s (400 boxes x 75 = 30,000 credits) before the 24-run sweep.

## Review Focus

1. A collector trained but never ordered to the pile (raw spawns never self-start in Zero Hour, harness finding): every trained collector must deposit at least once. Assert in both tasks.
2. Pile exhaustion inside 600 s for `frc7`: report the time and cut the steady rate there.
3. GLA start worker counted twice or not at all: `frc5` must show exactly 5 distinct depositing workers.
4. Timer origin drift: Zero Hour frames vs Wargrid ticks both start at the depot order (30 per second on both sides).
5. Chinook full-load difference (open item in [M7 verification](../../reference/m7-verification.md), ZH waits for a full load, Wargrid does not): report it next to the `usa2` rows instead of silently comparing.

---

### Task 1: Zero Hour opening scenario and metric

**Files:**
- Modify: `tools/zh_parity/parity.py` (new factory `opening(kind, units, collectors, seconds=600)`, registered as `open_<chinook|truck|worker>_u<1625|3125>_x<n>` for the four openings)
- Modify: `tools/zh_parity/analyze.py` (new `opening_curve(meta, rows, spend) -> dict`, used by `--json`)
- Test: `tools/test_zh_parity.py` (synthetic trace, no engine)

**Interfaces:**
- Produces: trace meta `order_frame`, `collectors` (ids), `kind`, `units`; `opening_curve` returns `{"gross": {60: int, ...}, "net": {...}, "steady_per_min": float, "break_even_s": float, "depositors": int, "pile_empty_s": float | None}`.

- [ ] **Step 1: Failing test** `test_opening_curve`: a synthetic trace with money rising by 75 at known frames for 3 collector ids gives the exact gross/net at 60 and 120 s, `depositors == 3`, `break_even_s` at the frame where gross passes spend, and `pile_empty_s is None`.
- [ ] **Step 2:** `python3 -m unittest discover -s tools` fails on the missing function.
- [ ] **Step 3: Implement** the scenario (reuse `collect()`'s strip, pile and depot setup; extra collectors from `train_unit` at the faction's producer after the depot completes, each ordered to the pile; GLA's builder ordered to the pile once the stash completes; record money every frame to `seconds`) and `opening_curve`.
- [ ] **Step 4:** Tests pass; `sh tools/run_python_checks.sh` exit 0.
- [ ] **Step 5:** One row end to end (`open_worker_u1625_x7`), check deposits from 7 workers and the pile time, then the sweep: `python3 -I tools/zh_parity/parity.py --out ~/projects/wargrid-income-work/zh --repeats 3 --lanes 3 'open_*'`; pooled table with `analyze.py --json`. Record rows (fork commit, Wargrid commit, trace dir) in the note of Task 3.
- [ ] **Step 6:** Commit "Measure whole supply openings in Zero Hour".

### Task 2: Wargrid opening rows (report only)

**Files:**
- Create: `game/tests/test_income_openings.gd` (registered in `run_tests.gd` `SUITES`)

**Interfaces:**
- Consumes: the opening definitions and time points of Global Constraints.
- Produces: one line per row `INCOME <opening> gap=<3|9> gross=<g60>,<g120>,<g180>,<g300>,<g600> net=... steady=<f> break_even=<s> depositors=<n> pile_empty=<s|->`.

- [ ] **Step 1: Failing test** `test_openings_deposit` per opening at gap 3: after 600 s every collector of the opening has deposited at least once and `depositors` equals the opening's count. Use only the [simulation interface](../../reference/sim-interface.md) (`build`, `produce`, `gather` commands; `view_state()`), set up like `test_supply_parity.gd` `layout()` but with the depot ordered, not pre-built.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=test_income_openings sh tools/run_tests.sh` fails.
- [ ] **Step 3: Implement** the setup and the report line for both gaps; the report rows are printed, not gated (they are evidence until the user decides).
- [ ] **Step 4:** The suite file passes, then the full suite, lint, warnings, `tools/test_sim_boundary.py` (in `run_python_checks.sh`).
- [ ] **Step 5:** Commit "Report Wargrid supply openings per faction".

### Task 3: Comparison note (stop)

**Files:**
- Create: `docs/reference/faction-income-parity.md`
- Modify: `docs/STATUS.md` (finding F3 points to the note)

- [ ] **Step 1:** Note, payoff first: answer to question 1 (Zero Hour faction against faction, net at 300 and 600 s and break-even per opening) and question 2 (Wargrid against Zero Hour per row, within 5 % or not), then the tables, then a decision list for the user (each mismatch with both numbers and candidate causes; no change proposed as decided). Label rows **measured (source build)** or **measured (Wargrid, tree)**.
- [ ] **Step 2:** `sh tools/check_public.sh` passes; links resolve.
- [ ] **Step 3:** Fresh Opus review of the note against the traces and the test output (numbers and claims). Fix, then commit "Compare faction income with Zero Hour". **STOP:** the user decides on any mismatch.

**Model routing:** Tasks 1 and 2 Sonnet, Task 3 note Sonnet, review Opus (high). Branch `income-parity` from `main`; work folder `~/projects/wargrid-income-work/` (outside the repo).
