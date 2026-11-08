# Perf spike gap closure plan (2026-11-08)

Status: **planned, not started.** Read against `perf-spike` at bcaf65b while the ws6 job (Jobs A-D, below) was running. Planning alone authorizes nothing. Start only on the user's word.

Goal: close every gap between the user's [original request](../../performance-spike-original-input.md) and what the spike delivered. The refined [handoff](../../performance-spike-prompt.txt) dropped half of goal 2: "if thresholds are unrealistic, propose revised values supported by measurements". That half is deliverable 6 and the main point of this plan. Part 1 therefore comes first and gets the most care.

Process: [milestone prompt](../../milestone-prompt.md) "Unattended run". A coordinator plus one fresh subagent per task, Sonnet (medium). One Opus (high) gate review at the end of Part 2, plus the Opus final check (T9). Subagents never commit. Local commits after green tasks are pre-authorized only as in the milestone prompt. Resume record: [perf-spike-verification.md](../../reference/perf-spike-verification.md). Every task appends a dated evidence row there.

## Rules every task follows

- **Hosts.** *Quiet* means: this Mac (Apple M6), `pgrep -fl 'godot|generalszh|WargridBench'` empty, load ≤ 2.5 at start, `uptime` recorded at start and end, mains power. Use the guard in scratchpad `ws6/lib.sh`. Run one Godot process at a time. Every Godot job, including import, export, suite and warnings, runs from a `git archive` copy in the scratchpad. *CPU-light* means reading, writing docs or scripts, git, `sh -n`, `python3 -I -m py_compile`. CPU-light work may run while the quiet batch runs. Godot work may not.
- **Stop conditions** (all tasks): a trace, pin or digest moves; a budget, ceiling or assertion would change; any gameplay change; a visible window, the Deck, a browser, fly, push, PR or merge; the resume record disagrees with the tree. On a stop, the coordinator uses PushNotification, then AskUserQuestion, then SendMessage to the same subagent.
- **Nothing changes a threshold without the user.** Part 1 only *proposes* values. T8 applies the approved ones.
- **Noise.** A difference below the A/A spread is noise. Any item whose best-case payoff is below the spread is marked optional or dropped.
- **Briefs.** Each subagent gets paths, not content: this file plus its task heading, the resume record, and the ws6 notes logs.

## Already in flight (ws6, do not duplicate)

Scratchpad `ws6/runs/{A,B,C,D}/notes.log`, chained by `ws6/chain.sh`:

| Job | What | Feeds |
|---|---|---|
| A | team match on HEAD, `H` vs `Hm` (profiler on vs off), 3 runs each, interleaved | team-match gate value; whether `TEAM TIMING` includes profiler overhead |
| B | `run_b.gd` on `Hb`, 3 plain runs + 1 profiled run | contact max (11.7-11.9 ms) attribution, team worst tick |
| C | macOS Bench release export, base `BX` vs HEAD `HX`, 3 runs each, plus editor `bench_runner` on HX | release/editor ratio (18-20 % on 2026-11-06) |
| D | `bench_ab.sh bba985c HEAD` over movement and every `run_combat.gd` layout, 3 rounds, plus lockstep and team match A/B, 3 rounds | full re-baseline; 3 of the 13 ceiling samples |
| (coordinator) | `sh tools/run_benchmark.sh` on HEAD, quiet | close criterion of the handoff; sample 4 |

## Gap map: original deliverables against the delivered state

| Original item | Delivered | Gap | Task |
|---|---|---|---|
| D1 baseline report, failure margins | WS1 table (bba985c) | the final bba985c → HEAD comparison is pieced together from different days; Job D replaces it | T1 |
| D2 bottleneck analysis | WS1, 2a, 2i | contact max and team worst tick are unexplained (Jobs B, A); no allocation or memory view (objective 1 says "CPU, memory") | T1, Q3 |
| D3 technology evaluation | typing, threads; GDExtension skipped by the user | none in scope (GDExtension skipped by user decision) | none |
| D4 recommendations | 5 items | rec 1 is still listed as the top item although its own design says "do not build"; rec 2 is unmeasured; rec 3 is an estimate | T0a, T0c, Q4, Q5 |
| D5 improvements with before/after | 6 kept fixes | no direct before/after (Job D gives it) | T1 |
| **D6 gate recommendations** | 4 rows, all "stay report-only" | **no proposed value for any gate; most gates are missing from the table; no worst-of-N data** | **Part 1** |
| D7 remaining work | short list | no CI guard design; no scaling numbers ("scaling behavior as the number of units, players ... increases"); the user items are not separated | T0d, Q2, Part 3 |
| Policy: "keep benchmarks reproducible and representative" | — | the ledger claims a rendered 16.7 ms gate that `rg` cannot find in `game/`; the Ashfall budget verdict rests on `--profile` runs only | T0b, U3 |

---

## Part 1: threshold proposals (main deliverable)

### Rules for proposals

- **Budget rows** (`target budget ÷ F`) are derived from the target device. The run-to-run rule never changes them. Only two things move them: a re-measured F (U1, the Steam Deck), or the user changing the target share. A lower F loosens every budget, so it is the user's decision. A row that misses its budget stays "exceeded" until code fixes it or the user accepts a re-measured F.
- **Ceilings and regression guards** (stress ceilings, Ashfall guard, BM6): proposed value = worst of N ≥ 13 quiet runs on one code tree, plus 5 %. That is the M4.1 rule. The M7 re-pin used only 4 runs and was marked "tighten when more runs exist". A ceiling above its budget is only a regression guard, and the report must say so.
- **Gated vs report-only.** Promote a row to a gate only if its worst of 13 + 5 % still clears the line. Otherwise a pass or fail is a coin flip on host noise. In M7, load 2.7-3.5 moved rows by about 60 %. Wall-clock gates are therefore only meaningful under the quiet-host rule, which the exit gate already requires.
- **Direction labels.** *Retain*, *tighten* (needs the user's OK), *loosen* (needs the user's decision, backed by a measurement on the target), *new gate* (the user's OK).

### Gate inventory (values to verify in T0b; "measured" = latest quiet median, to be replaced by T2)

| # | Gate | Where | Current value | Measured (tree) | Provisional proposal | Evidence still needed |
|---|---|---|---|---|---|---|
| G1 | movement open / dense sim p95 / p99 | `run_movement.gd:74` | 8 / 16 ms (the old dev gate, about 5x loose) | 1.501 / 1.487 p95 (WS4); p99 1.766 / 1.788 (WS1) | **tighten** to the budget 1.82 / 3.64. Alternative: worst of 13 + 5 % as a regression ceiling under the budget | 13 samples (T2) |
| G2 | combat `contact`, `skirmish3v3` | `run_combat.gd` `COMBAT BUDGET`, `run_benchmark.sh` counts 2 PASS | 1.82 / 3.64 | contact 1.19 / 1.72; skirmish3v3 1.43 / 1.62 (WS1) | **retain** | 13 samples confirm the margin |
| G3 | combat `open` stress ceiling | `run_combat.gd:10` | 3.05 / 4.23 | 1.865 p95 (WS4) | **tighten** to worst of 13 + 5 % (expected about 2.0 / 2.7). Budget 1.82 stays; the row stays exceeded unless U1 justifies a re-measured F | 13 samples; U1 for any budget question |
| G4 | combat `dense` stress ceiling | `run_combat.gd:10` | 3.31 / 5.01 | 1.796 p95 (WS4) | **tighten** to worst of 13 + 5 %. Do not promote to a budget row: it sits inside the spread of 1.82, so the gate would flake | 13 samples |
| G5 | `hordes300` | report-only, no ceiling | none | 2.821 / about 3.4 (WS4) | **new gate**: a regression ceiling at worst of 13 + 5 %, report-only against the budget | 13 samples |
| G6 | `transports`, `defences`, `docks`, `ramp`, `frc` | report-only | none | all inside 1.82 / 3.64 (WS1: worst p99 2.49 defences) | **new gate**: promote to `COMBAT BUDGET` each row whose worst of 13 + 5 % clears 1.82 / 3.64. Otherwise retain report-only | 13 samples |
| G7 | team match sim p95 / p99 | `run_team_match.sh` prints `TEAM TIMING`, no gate; not in `run_benchmark.sh` | none (budget 1.82 / 3.64) | 1.303 / about 2.88, profiler on (WS4) | **new gate** at the budget with the profiler off, if Job A shows profiler overhead and worst of 13 + 5 % clears 3.64. Otherwise retain report-only. Max tick (about 10 ms) stays a watch item | Job A, 10 samples (T2) |
| G8 | lockstep overhead p99 | `run_lockstep.gd:11` | 0.6 ms | 0.065-0.072 | **retain**. It is a budget (10 % of a tick ÷ F), not a ceiling; worst + 5 % (about 0.08) would flake on a µs-scale p99 | Job D |
| G9 | rendered frame p95 (open, dense) | **does not exist** (T0b 2026-11-08: `movement_benchmark.gd` asserts only the Ashfall guard, line 168; 16.7 ms is the render goal, not a gate; the ledger text is corrected) | 16.7 ms claimed; budget 3.04 | open 1.40-2.16, dense 2.10-2.16 (R2, `--profile`) | ledger corrected. A **new gate** at 3.04 for open and dense is offered only after U3 gives 13 runs without `--profile` | U3 |
| G10 | Ashfall frame guard | `movement_benchmark.gd:10` | 3.3 ms (budget 3.04) | 2.89-3.02 (`--profile`, R2); 0.506 (no profile, one run) | **tighten** to the budget 3.04 or to worst of 13 + 5 % without `--profile`, whichever is lower; first explain the 0.5 vs 2.9 gap (is `--profile` the cause?). The failing direction must be exercised once (scratch copy, guard set below the measured value) | U3 |
| G11 | horde rendered frame | no gate (3.51-4.08 > 3.04) | none | R2 | **retain** report-only (exceeded, reported) | none |
| G12 | presentation plumbing per tick | budget table only | 0.91 ms | about 1.9 (2026-11-03 probe); R2 profile on Ashfall: `snapshot` 1.47 + `view.copy` 0.08 + `view.points` 0.08 + `view.sort` 0.05 ≈ 1.68 | **retain** 0.91, status exceeded. Update the "current" cell from R2 (labelled profile on, Ashfall, rendered). The fix (stop deep-copying state twice) is out of scope | none (existing evidence) |
| G13 | BM6 contact tick-0 `combat_work` peak | `test_benchmark.gd:183` | (16000, 18500] | 18168 (2e row, base tree) | **retain**. Machine-independent, already in CI. Note headroom 1.8 % at the top | peak on HEAD from the T2 logs |
| G14 | BM6b joiner work | `test_benchmark.gd:197` | ≤ 1500 | not recorded | **retain** (T0b: the check at `test_benchmark.gd:197` is ≤ 1500 per tick after tick 0, confirmed; the peak is not recorded anywhere) | peak from the T2 logs |
| G15 | snapshot size ceiling | `test_snapshot_size_ceiling` | 84,119 / 84,983 nodes, busiest unit 336 (T0b: 82,703 / 83,567 was the M6 Task 8 value) | at ceiling by design | **retain** | none |
| G16 | watch item: worst sim tick | budget table, no gate | 7.8 ms (2026-11-03) | team about 10 ms, contact 11.8 ms | **retain** as a watch item; update the numbers from Jobs A and B | Jobs A, B |
| G17 | F itself | ledger | 5.5 (Deck Firefox, 63f5a9a, before every fix) | — | **retain until U1**. Afterwards propose the re-measured F per row (either direction). Any change to F is the user's decision | U1 |

### T2: ceiling and gate samples (quiet, Sonnet)

- **Goal.** 13 or more samples per row on one code tree, for G1-G7.
- **Inputs.** HEAD (check `git diff --stat <Job D B-ref> HEAD -- game` is empty, so the Job D runs count). Scratch archive copy; `ws6/lib.sh` guard; `run_combat.gd`, `run_movement.gd`, `run_team_match.gd` (the profiler mode Job A shows to be right).
- **Host.** Quiet. About 12 min for 10 x (combat + movement), plus about 8 min for 10 team runs. Runs come one after another, not interleaved (there is only one tree). Record load per run.
- **Acceptance.** Every run exits 0 with its PASSED line. The table has n ≥ 13 per row (Job D + `run_benchmark.sh` + T2); per row it gives p50 / p95 / p99 / max, min-max spread and worst + 5 %. `combat_work=` is identical across runs, and the BM6 peak is read from the logs.
- **Stop.** Unequal `combat_work` between runs (non-determinism). The guard aborts twice. Never retry in a loop.
- **Writes.** A verification row "T2 ceiling samples", with the table. No ledger row (no gate changed).

### T3: threshold proposal table (CPU-light, Sonnet; Opus reviews it in T7)

- **Goal.** For G1-G17: current value, measured values (n, tree, load), rule applied, proposed number, direction, reason, and the user decision needed.
- **Inputs.** T1, T2, the gate inventory above.
- **Acceptance.** Every inventory row has a number or an explicit "retain". Each tighten or new gate shows worst + 5 % and the margin to its budget. Each loosen candidate names the U1 measurement it waits for. No code is changed.
- **Stop.** A proposed ceiling would be *below* a quiet run's value (an arithmetic error), or a row's spread exceeds 10 % of its value (the sampling is not trustworthy: re-plan).
- **Writes.** It replaces the "Gate recommendations" subsection of `performance.md` "Post-M7 performance spike (2026-11)" with the full table. The status line at the top of `performance.md` stays "existing gates unchanged".

---

## Part 2: other measurement and write-up tasks

Order: CPU-light tasks first (now, alongside ws6), then **one quiet batch** run as a single chained script after ws6 ends, then the write-up.

### CPU-light, start now

**T0a: claims audit.** *Goal:* list each claim in the spike write-up and the budget table that rests on a missing or stale measurement, with the task that settles it. Known so far:
- the budget table's movement "1.59 / 1.58, 13 % margin" (now about 1.50);
- the counters table's "combat target checks: not implemented" (it is `combat_work`, BM6);
- the 0.91 plumbing "current" cell (G12);
- R2's "passes 3.04 by 0.02" (only `--profile` runs);
- rec 1 is ranked first although the design says not to build it;
- rec 3's "0.3-0.5 ms" is an unlabelled estimate;
- "release 18-20 % faster" (Job C);
- the cumulative bba985c → WS4 numbers come from different days (Job D);
- `TEAM TIMING` includes the profiler (Job A).

*Inputs:* `performance.md` lines 1-24, 113-131 and 207-272. *Host:* CPU-light. *Who:* Sonnet. *Acceptance:* a list in the verification file. Edits go only where existing evidence settles the claim, and each such edit names its evidence. *Stop:* a claim that would flip a pass or fail verdict. *Writes:* verification row "T0a claims audit", plus the `performance.md` text fixes.

**T0b: gate inventory check.** *Goal:* confirm the location and value of every G-row, and find the rendered 16.7 ms gate (G9) or record that it does not exist. *Inputs:* `rg -n` over `game/benchmarks`, `game/scripts/debug/movement_benchmark.gd`, `game/tests/test_benchmark.gd`, `tools/run_benchmark.sh`. *Host:* CPU-light. *Acceptance:* the inventory table is corrected in place. *Writes:* this plan's table and a verification row.

**T0c: bound on per-cell, per-team enemy counts (rec 2, approved by the user, never tried).** *Code fact:* since 2b, `_nearest` (combat.gd:325-333) already skips non-hostile owners and empty cells, at one `cells.has(key)` per window cell per hostile owner. Per-team counts would save only those misses, and on `open` and `dense` there is one hostile owner, so they save nothing. *Goal:* turn that into a written bound: window cells × hostile owners × the cost of a miss, against the A/A spread (0.04 ms). *Host:* CPU-light (reading). *Who:* Sonnet. *Acceptance:* the bound is written down. Q4 runs only if the bound is above the spread for some row (most likely team match or skirmish3v3). *Expected:* below the spread, so recorded as "not attempted, bound below noise". *Writes:* verification row; recommendation 2 updated.

**T0d: CI guard design (proposal item 13).** *Goal:* half a page in `performance.md` "Not covered yet" that answers "CI does not run any benchmark". It says what CI already gates (BM6, BM6b, snapshot ceiling: all in the suite); which counters to add (path-queue peak, `_nearest` candidates per call); and that wall-clock rows on runners are trend-only and never fail. *Host:* CPU-light. *Who:* Sonnet. *Acceptance:* text only, no workflow edit. Adding to `.github/workflows` needs the user's OK. *Writes:* `performance.md` "Not covered yet".

**T0e: rebaseline check after 45df3eb.** *Fact:* `bench_runner.gd:29` runs only open, dense, contact and skirmish3v3, and the 5a web numbers came from a patched copy. So no committed release or web number for `hordes300`, `frc` or `horde_render` was measured without enemies. *Goal:* confirm that with `rg`, then close the "rebaseline" item in the write-up. Also add `hordes300` to the `bench_runner.gd` combat list, so that U1 yields an F for hordes300. This is a benchmark-tool edit: lint, and warnings in Q6. *Who:* Sonnet. *Stop:* any committed number that is affected. *Writes:* the `performance.md` remaining-work line, a verification row, `game/benchmarks/bench_runner.gd`.

**T0f: scratch scripts for the quiet batch.**
- Q2 scaling workload: a copy of `combat_workload.gd` with an army multiplier and an owner split.
- Q3 memory runner: `Performance.MEMORY_STATIC` and `OBJECT_COUNT` every 300 ticks.
- Q4 counter patch, written only if T0c says so.
- `batch.sh` chains Q1-Q8 with the ws6 guard and skips a job on a stop.

All files stay in the scratchpad, checked with `sh -n` only. *Who:* Sonnet. *Acceptance:* the scripts parse, and each Godot script calls `quit()` on every path.

### T1: read the ws6 results (CPU-light, after the chain ends)

- **Goal.** Turn Jobs A-D and `run_benchmark.sh` into evidence:
  - the bba985c → HEAD table for every row (median, spread, p50 / p95 / p99 / max);
  - profiler off vs on for the team match;
  - the contact max tick, its zone and its cause;
  - the team worst tick by index;
  - release/editor ratio, base vs HEAD;
  - whether `run_benchmark.sh` exits 0 and prints the lockstep line (the handoff's close criterion).
- **Inputs.** `ws6/runs/*/notes.log` and the logs; `scratchpad/tools/ab_summary.py`.
- **Acceptance.** Every job's notes end with JOBDONE, or an ABORT is recorded. Numbers are copied, not retyped.
- **Stop.** `combat_work` or digests differ between bba985c and HEAD (they must be equal: all kept fixes preserve the trace). Or `run_benchmark.sh` exits 1 on HEAD.
- **Writes.** Verification rows "ws6 re-baseline", "team profiler", "contact max", "release bench", and one ledger History row "perf spike re-baseline bba985c vs HEAD".

### T1b: AI and navigation zones in the team match (CPU-light, after Job A's logs exist, Sonnet; added 2026-11-08 by the user's approval)

`run_team_match.gd` already prints `Profiler.report` and `PROFILE_SLOW`. From the Job A logs (profiler on), table mean / p99 / max of `opponent.decide`, `navigation.astar`, `step.service_paths`, `apply_orders`, `allocation.assign` and `snapshot`, and name the zone behind the team-match max tick. *Acceptance:* a table in the verification file. If a zone causes the max tick, write the two re-pin ideas (stagger AI seats, per-tick A* work budget) as questions for the user; both move traces and need a decision.

### T10: snapshot double-copy design (Opus high, read-only, writes one design file; added 2026-11-08 by the user's approval)

The plumbing row (snapshot + view copy + sort) is 1.68 ms against a 0.91 ms budget, and `snapshot` is 1.47 ms per rendered tick on Ashfall. Suspected cause: `_sorted_copies` `duplicate(true)` plus the view's `state.duplicate()`. Design how to stop the double copy with digests and traces identical; estimate the gain from the measured zones. *Output:* `docs/superpowers/specs/2026-11-08-snapshot-copy-design.md`. If built, one A/B in the U3 rendered batch plus lockstep.

### Quiet batch (one chained script, one Godot process at a time, after ws6)

| # | Task | Time | Value / payoff | Status |
|---|---|---|---|---|
| Q1 | T2 samples | about 20 min | the input to Part 1 | required |
| Q2 | scaling sweep | about 20 min | objective 5; "how many units fit in 1.82 at F" | required |
| Q3 | memory proxy | about 5 min | objective 1 asks about memory; no GC exists (refcounting), so this is a proxy only | required, low cost |
| Q6 | warnings + lint on the T0e edit; `unsafe_*` count per warning type | about 2 min | user decision on rec 5 | required |
| Q4 | per-cell counters | about 5 min | only if T0c says the bound is above the spread | conditional |
| Q5 | `_hold_cells` Task 0 (design §6, G1 + G2) | about 30 min | the design expects a net gain of 0.03-0.05 ms, the size of the spread | **optional, user's go only** |
| Q8 | series dump + paired per-tick analysis | about 25 min | only if T1/T2 leave an open verdict, where a delta between bba985c and HEAD inside the spread decides a proposal. Absolute verdicts (open 1.865 vs 1.82) are settled by the 13 samples, not by pairing | conditional, expected unused |
| Q7 | 60-min calibration (`run_calibration.gd`) | 60 min | drift check only; A/A spreads already bound the noise | **optional, last, only if the host is free** |

**Q2: scaling sweep.**
- *Goal:* step mean, p95 and µs per unit-tick against alive units, plus the largest army inside 1.82 / 3.64, in two series:
  - units: `open` and `hordes300` at 0.5x, 1x, 1.5x and 2x;
  - players: 300 units split across 2, 4 and 6 owners in 3v3-style teams. The per-owner grid makes owner count a real cost factor.
- *Inputs:* the T0f workload copy, profiler off; HEAD; and bba985c for `open` 1x and 2x only (did the fixes change the slope?).
- *Host:* quiet. *Who:* Sonnet.
- *Acceptance:* one table per series; spawn failures are recorded as the cap reached.
- *Stop:* none beyond the global ones (scratch only).
- *Writes:* verification row "Q2 scaling"; one paragraph and a table in the `performance.md` spike section ("Scaling").

**Q3: memory proxy.**
- *Goal:* static memory and object count every 300 ticks on `hordes300` and the team match. Growth means churn or a leak; a flat line closes the question.
- *Who:* Sonnet. *Acceptance:* both series are recorded, with the caveat "proxy, no allocation counter in GDScript".
- *Writes:* verification row; one line in "Baseline and bottleneck".

**Q6: warnings.**
- *Goal:* `sh tools/run_lint.sh` and `sh tools/run_warnings.sh` on T0e. In a scratch copy, enable `unsafe_property_access`, `unsafe_method_access` and `unsafe_call_argument` one at a time and count each.
- *Writes:* verification row; rec 5 updated with the per-type counts. The decision is U6.

**Q4, Q5, Q8.** Each one's inputs, acceptance and stop are in its source: T0c; the [`_hold_cells` design](../specs/2026-11-08-hold-cells-occupancy-design.md) §6 Task 0 (its go rule); and the scratchpad proposal item B. Each only writes a verification row and, if run, a ledger row.

### T6: write-up update (CPU-light, Sonnet)

- **Goal.** One consistent `performance.md` spike section: T1 numbers, T3 table, Q2 and Q3 sections, T0a fixes, recommendations re-ranked (rec 1 marked "do not build" unless Q5 passes; rec 2 marked with the T0c bound), "Remaining work" split into "needs the user" (Part 3) and "later work".
- **Also.** The resume record; README and AGENTS status lines (one line each).
- **Acceptance.** Links and labels are checked, every number cites its tree and host, the status line still says gates are unchanged.
- **Writes.** `performance.md`, `perf-spike-verification.md`, `README.md`, `AGENTS.md`.

### T7: gate review (Opus high, fresh context, read-only)

- **Brief.** The T3 table, T1/T2/Q2 evidence, this plan, the prior rulings in the resume record (not to be re-raised). The reviewer checks:
  - each proposed number against the raw logs and the rule;
  - each claim of a "new gate" against its margin;
  - that no loosen proposal lacks a target measurement.

  It names the change that would make each new number wrong.
- **Stop gate.** The coordinator records the findings, notifies the user and ends the session.

---

## Part 3: needs the user

Each item is listed with what the agent prepares. None starts without the user.

| # | Item | Agent prepares | Feeds |
|---|---|---|---|
| U0 | **Decide each T3 proposal** (tighten / new gate / retain; any loosening) | the T3 table | T8 |
| U1 | **Steam Deck F = 5.5 re-check**, native and Firefox, on the final tree (ledger how-to; Deck address, Desktop Mode, mains). Gives F per row including hordes300 (T0e) and decides whether any budget may move | Sonnet driver over ssh with the user present; table in the "Target factor" section format | G3, G5, G17; the only path to a justified loosening |
| U2 | `_hold_cells` Task 0 go / no-go | the design's numbers | Q5 |
| U3 | **Rendered window batch** (one request): 13 runs of `movement_benchmark.tscn` without `--profile` plus 3 with it (explains Ashfall 0.5 vs 2.9 ms); one scratch run with the Ashfall guard below the measured value (failing direction); optional `draw.units` one-pass prototype (rec 3, presentation only) | `r1r2`-style script, scratch copies | G9, G10, rec 3 |
| U4 | Browsers: Safari (threaded and single-threaded), Chrome vs Vivaldi (install Chrome?), relay match from the fly origin | checklist from the 5d result | write-up, README |
| U5 | README "floats in WASM vs native": a mixed browser + desktop match through the relay (needs two players or the user clicking) | a how-to; the 5a digest evidence | README open item |
| U6 | enable `unsafe_*` warnings or not (maintainability, not performance: Workstream 4) | Q6 counts | rec 5 |
| U7 | ultra review of the branch, merge, push | — | — |

**T8: apply the approved thresholds (Sonnet, after U0; quiet).** Change only the constants the user approved: `run_combat.gd` `STRESS_CEILING` / `BUDGET` lists, `run_movement.gd:74`, a `run_team_match` gate, `ASHFALL_FRAME_P95_MS`, and the `run_benchmark.sh` PASS counts. Then run `sh tools/run_benchmark.sh` quiet on the new tree (exit 0, lockstep line printed); lint and warnings; and the suite if a test constant changed. *Stop:* the new gate fails on a quiet run, which means the T3 arithmetic or the sample was wrong: report, do not widen. *Writes:* a ledger History row naming every changed value, old → new, with the user's approval date; the budget table; the status line.

## T9: final deliverable check (Opus high, fresh context, read-only, last)

Check the write-up against the **external brief** (written by another AI without knowledge of this codebase, supplied by the user as an outside perspective; advisory, not a spec: an item that does not fit Wargrid is marked *not applicable* with the reason, and a user decision such as dropping GDExtension counts as an answer), not only the handoff. Every item gets *met / partly / not met* with a pointer, or a recorded user decision:

- deliverables D1-D7;
- objectives 1-5, each bullet: baseline, regression, profiling, average vs worst vs variability, typing, GDExtension (user decision), threads, other optimizations, scaling;
- each "Benchmark Gate Policy" bullet: proposed values, never silently relaxed, rationale documented, reproducible and representative;
- the success sentence: a suite whose pass/fail results can be trusted.

A "not met" item becomes a remaining-work line or a question for the user. It is never edited to look met. *Writes:* a verification row "T9 deliverable check", plus the resume record.

## Dropped or kept optional, with reasons

- Regression bisect (the brief's 'when and why it regressed'): dropped by the user's decision 2026-11-08. About 1 h of quiet host, no decision it would change; causes are already named as features (M6 teams and map, M7 gate 1) from the ledger rows.

- **Q5 `_hold_cells`**: the design expects the net gain to equal the A/A spread and other rows to get worse. Optional, the user decides.
- **Q7 60-min calibration**: drift is already bounded by the A/A spreads; useful only for comparing an evening run with a morning run. Optional.
- **Q8 series dump**: helps only with deltas, and every open verdict is absolute. Conditional.
- **Rec 2 per-cell counts**: probably below noise by construction (T0c). Measured only if the bound says otherwise.
- **Startup and load-time bisect** (proposal item 14): no deliverable needs it.
- **GDExtension**: skipped by the user's decision; T9 records it as such, not as a gap.
