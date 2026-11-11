# Simulation data layout: decision proposal (2026-11-11)

Status: **proposed, not approved.** Task T6 of the [performance next plan](../superpowers/plans/2026-11-11-performance-next.md), written for stop gate 3. Docs only: no code, benchmark or window was run for this note. Inputs: [performance next](performance-next.md) (sections 2, 5, 6, 7, 8), the [native spike report](native-sim-spike.md) (section 1 formulas), the [view rows design](../superpowers/specs/2026-11-12-view-rows-design.md), the [determinism rules](determinism-rules.md), the [simulation interface](sim-interface.md), the [golden scenarios plan](../superpowers/plans/2026-11-09-state-digest-golden-scenarios.md), blueprint §7 and §11, and the rows in the [verification file](performance-next-verification.md).

Labels: **measured** (a row in the verification file or performance next, command and tree there), **source** (quoted file), **inferred** (arithmetic on measured rows), **estimate** (not measured). Host: the Mac mini. Every "on the target" number is a Mac number times F = 5.5 (the ledger's rule), so inferred.

## 1. Recommendation

1. **Move the simulation's per-unit state to packed arrays in GDScript, system by system, but only inside the milestone that rewrites that system anyway** (movement and pathing first, unit avoidance on the same columns, combat with the split-rates re-pin). No standalone storage migration of systems that are not otherwise touched.
2. **No Rust kernel now, and no whole port.** The first kernel is justified only by a named system that already lives in packed arrays, has a GDScript reference, and misses a stated budget in GDScript: a horde mode's agents (if the user wants the mode) or the avoidance neighbour loop (if it misses its 0.5 ms cap). On the 210-unit goal row kernels give about 1.36x on `step` against a 5.5-7.8 % tax on the rest; that is not worth a toolchain.
3. **The next performance target for the frame is presentation, not storage.** After T4 the drawing side is as large as the simulation step, and interpolation costs more per tick than the whole hand-off (section 7). A storage change cannot reach that work.

Why, in one paragraph: packed arrays are the only layout that makes the hand-off near free and makes kernels possible at all (hand-off 0.1-0.4 % against 60-73 % on Dictionaries, measured), and they give 1.4-1.6x on per-unit loops (measured, horde workload). But on the goal row the kernel-shaped systems are only about a third of `step`, the simulation is headed for a worker thread where its tick has a 33 ms period, and after T4 the presentation work left on the main thread caps any simulation-only gain at about 2x of the per-tick work (section 3). So the layout change pays for itself when it rides on rewrites that happen anyway, and loses when it is a project of its own.

## 2. Inputs after T4 (measured unless labelled)

Profile zones from `sh tools/run_profile.sh` on a git-archive copy of `perf-next` 6dbcc02 (after T4), three runs, 2026-11-11 14:40-15:10, load 1.2-1.5 (verification file, T4 task 7 row; logs `~/projects/wargrid-perf-work/t4-measure/after-{1,2,3}.log`). Mean ms per tick, run spread at most 0.02 ms. `step` zones did not change with T4 (T4 touched no simulation system).

| Zone (share of `step`) | skirmish3v3 (210 to 57 units) | team match (peak 261) | hordes300 (400 to 292) |
|---|---|---|---|
| `step` mean / p95 | 0.70 / 1.31 | 1.07 / 1.93 | 1.98 / 2.86 |
| `step.combat_plan` | 0.370 (53 %) | 0.403 (38 %) | 0.796 (40 %) |
| of which `combat.build_grid` | 0.060 (9 %) | 0.101 (9 %) | 0.170 (9 %) |
| of which `combat.nearest` | 0.040 (6 %) | 0.015 (1 %) | 0.133 (7 %) |
| `step.advance` (movement, horde bonus, containers) | 0.121 (17 %) | 0.317 (30 %) | 0.951 (48 %) |
| `step.combat_fire` | 0.173 (25 %) | 0.130 (12 %) | 0.136 (7 %) |
| `step.supply` | 0.016 (2 %) | 0.112 (10 %) | 0.043 (2 %) |
| `step.ids` | 0.013 (2 %) | 0.017 (2 %) | 0.039 (2 %) |
| hand-off after T4 (`view_state` + `view.sort` + `view.batch`) | 0.537 | 0.951 | 1.927 |
| of which `view_state` (fill from the entity Dictionaries) | 0.154 | 0.260 | 0.442 |
| of which drawing prep (`view.sort` + `view.batch`) | 0.383 | 0.690 | 1.484 |

**Kernel-shaped share s** (flat numeric loops: `step.advance` + `combat.build_grid` + `combat.nearest`, the candidates of performance next 5.4): skirmish3v3 **0.32**, team match **0.41**, hordes300 **0.63** (inferred). Performance next 5.4 used 0.56 for hordes300, the native spike's slice-level share (its horde and move slices plus grid and scan); `step.advance` also holds container and route bookkeeping that is not flat, so 0.56-0.63 is the honest range.

**Per-unit read cost p after T4** (inferred from the zones above). The profile has no per-tick unit count, and the T4 task 2 harness divided by the row count at the end of its sample, so per-row figures are bounds. hordes300 has the narrowest range (400 at start, 292 at the end):

| Part | ms per tick | µs per unit (400 .. 292 units) | As a fraction of hordes300 `step` |
|---|---|---|---|
| fill (`view_state`; what a port's Rust side would replace) | 0.442 | 1.1-1.5 | **0.22** |
| drawing prep (`view.sort` + `view.batch`; stays GDScript under every option) | 1.484 | 3.7-5.1 | **0.75** |
| Dictionary reads inside `view.build` and `view.poses` (T4b probe, upper bound) | 0.20 | 0.5-0.7 | 0.10 |

Reading against the native report's joint condition `1/K_lower + p <= 0.455`: with p defined as it was there (the part that replaces `snapshot()`), p = 0.22 passes (0.036 + 0.22 = 0.26 at K 27.7; G_port about 3.9, estimate). If the drawing prep is counted as well, p = 0.97 and the port fails (G about 1.0). The drawing prep is paid under every option, so it is not an argument against a port; it is the reason no simulation-side option, port included, can buy more than about 2x of the per-tick main-thread work (section 3).

## 3. What each option can buy

`G_inc = 1 / ((1+T)(1-s) + s/E)` (native report section 1), with T = 0.065 (dlink template tax, middle of 5.5-7.8 %, measured) and E = 40 (Rust on packed arrays, 34-58 measured on the friendliest kernel; combat bookkeeping will gain less, no number exists). Gains are on `step` against GDScript on packed arrays.

| Row | s | G_inc on `step` (inferred) | Cap from presentation: (step + hand-off) / hand-off (inferred) |
|---|---|---|---|
| skirmish3v3 (goal) | 0.32 | **1.36** (1.34 at T = 0.078) | 2.3 |
| team match (goal) | 0.41 | **1.55** | 2.1 |
| hordes300 (stress) | 0.56-0.63 | **2.07-2.46** | 2.0 |

The last column is the best any simulation-side change can do to the per-tick work on one thread (step plus hand-off), even at infinite speed, measured inputs. With interpolation on at 60 frames per second the main thread carries another 1.6-2.3 ms per tick (section 7), which lowers that cap further.

Expected gain per option on the goal row skirmish3v3 (Mac means; on the target times 5.5):

| Option | What changes | Expected effect | Label |
|---|---|---|---|
| A. Packed arrays in GDScript, movement only (inside the movement milestone) | `step.advance` 0.121 at 1.4-1.6x; fill from columns | `step` -0.04 to -0.05 ms; `view_state` 0.154 to about 0.02-0.05 (records still copied) | estimate (ratios measured on the horde workload, applied to these zones) |
| B. A plus combat on columns (with split rates and the persistent grid, one re-pin) | `combat_plan` + `combat_fire` 0.54 at 1.3-1.5x, before split rates | `step` 0.70 to about 0.50-0.55; per-tick total 1.24 to about 0.90-0.95 (about 1.3x) | estimate; combat gains less than the horde loop because it is branching and record lookups |
| C. B plus Rust kernels under movement, grid and scan | s 0.32 | `step` a further 1.36x, minus the tax on all other GDScript | inferred from the formula; not worth the toolchain for this row |
| D. Whole port | everything | 3.3-4.6x on `step` (native report estimate); per-tick total capped at 2.3x by presentation | estimate |

On hordes300 the same options give: A about -0.3 ms of 1.98 (advance 0.95 at 1.4-1.6x, estimate); C 2.07-2.46x, the first row where kernels clear the native spike's 2.2 line (inferred). For a horde mode of 1,000 agents, kernels are the enabler: GDScript on packed arrays 1.24 ms (staggered) against Rust 0.036 ms, measured; 10,000 agents 0.39 ms in Firefox, measured.

## 4. Order of work

1. **Presentation per-frame cost** (section 7). No simulation or trace change; independent of everything below; the largest measured item left on the main thread.
2. **Worker thread (T5)**, as designed there. Independent of storage: it publishes `view_state()` per tick, whatever the storage. It moves `step` and the fill off the main thread, which is what removes the goal row's simulation from the frame budget. Its fallback (no threads) is the reason storage still matters for the goal row at all.
3. **Golden scenarios plan** (approved 2026-11-10; its prerequisites, the interface and determinism notes, are done). Must come **before the first storage change**, for three reasons: the engine-neutral digest is the oracle a kernel is later compared against; golden scenarios run through the public interface, so they survive a storage swap that breaks `_entities` readers (20 test files under `game/tests` read `_entities`, `rg -l`, measured); and the combat and economy systems that keep Dictionary storage during the movement milestone need a behaviour baseline that the movement re-pin does not wash out. Note its own scope rule: no horde-style golden scenario (user), so the horde bonus inside `step.advance` is covered by traces and benchmarks only.
4. **Movement and pathing milestone on columns** (A). New movement state written as packed arrays from the start; the old `position` and `heading` Dictionary fields mirrored from the columns for systems not yet moved (the mirror costs what `_advance` costs today, H2). It re-pins traces anyway (navmesh, any angle), so the layout costs no extra re-pin.
5. **Unit avoidance milestone** on the same columns. The neighbour loop is the system most likely to need the first kernel on the goal rows (section 5).
6. **Combat on columns** together with split rates, the persistent target grid and worst-tick bounds (levers E, F, G; one shared re-pin, performance next section 6) (B). Re-profile; recompute s.
7. **Fog (M7.9)** designed on columns from the start (vision stamping is a flat loop over positions into a grid).
8. **First kernel** only when its trigger fires (section 8). A horde mode, if decided, starts there: new code, columns plus kernel from day one.

Not recommended: a whole port (D). It is capped by presentation like everything else, and steps 4-8 reach its simulation gain where it matters without a big bang.

## 5. Interactions

- **Movement and pathing milestone.** What it must do so its code can later take a kernel: flat arrays in, flat arrays out (positions, headings, speeds, size class, route cursor; routes in one waypoint pool with start and length per unit, not an `Array` per unit); static tables (navmesh rectangles, blocked cells, size-class clearances) passed once and rebuilt only on a terrain or building change; no callback into GDScript and no per-unit `Variant` inside the per-unit loop; the path search stays Godot's `AStar2D` (already compiled, gains nothing from a kernel). The first-task stuck prototype and the early cross-platform path test (user answers, design answers "Movement and pathing") stay as they are.
- **Unit avoidance.** Cost cap: about +0.5 ms per tick on every 300-unit row (user, design answers). The horde spike's separation loop is the same shape: 1.54 ms for 1,000 agents in GDScript on packed arrays (measured), so about 0.46 ms for 300 units every tick, about 0.25 ms staggered over three ticks (inferred), and about 1.5x that on Dictionaries (inferred), which is consistent with round 1 missing the cap. So avoidance needs columns, and is at the cap's edge without a kernel.
- **Fog.** No measurement exists. It adds per-unit work (vision per unit, staggered if allowed) and a new column for drawing (visible to the local team), so the fill grows. Design it on columns; a vision kernel is a flat-array candidate.
- **Worker thread (T5).** Ticks stay in order on one thread, so storage does not touch the determinism rule. With columns the worker's publish becomes a column copy (performance next 4.1: a packed snapshot copy is about 1,400x cheaper than a Dictionary one, toy loop, measured). Without threads (Safari, headers refused, a fallback build) the simulation is back on the main thread and option B's 0.3 ms matter more.
- **Split rates (E).** Orthogonal to layout and bigger on combat-heavy rows than layout alone (staggering by three: -45 % on the horde loop, measured). Do them in the same combat task so the re-pin happens once.

### Rules for a system that moves to columns

- Dense columns in id order. Ids are never reused and are inserted ascending, so id order equals today's Dictionary insertion order (determinism rules, "Order"); removal must compact in order, never swap-remove, or iteration order changes and traces move.
- Positions in `PackedFloat64Array` (float64, the same bits as today's `[x, y]` floats). Every `Vector2` site stays a `Vector2` site, because float32 rounding there is a coupling (determinism rules).
- Integers in `PackedInt64Array` for simulation state (the digest hashes 64-bit words; `ViewRows` uses `Int32` because it is presentation only).
- `snapshot()` keeps its exact output shape: it builds the entity Dictionaries from the columns, same keys, same int/float types. Then a storage change moves no pin, and every existing trace and pin is the regression oracle (determinism rules forbid packed arrays in snapshot values).
- During the change, old and new storage run side by side and compare the digest every tick (the native spike's shadow mode), then the old path is deleted in the same task.
- Tests that read `_entities` for the moved fields move to the public interface first (`tools/test_sim_boundary.py` allowlist).

## 6. What stays Dictionary

- `snapshot()` output, desync reports, JSON traces and fixtures, the wire format (determinism rules: no packed arrays in snapshot values).
- Buildings, supply sources, players, crates: a few dozen objects, not per-unit hot loops.
- Commands, command results, combat events (variable shape, few per tick).
- Per-unit records with variable shape or rare access until their system is rewritten: `order`, `combat` (until step 6), `collection` (supply is 10 % of team match `step`; revisit after re-profiling), `construction`, container membership, production queues.
- `definitions/` stay GDScript constants; a kernel gets them once as packed tables.
- `view_state()`'s records other than `units`.

## 7. Interpolation and presentation (short list)

- Measured (verification file, interpolation-on row): with interpolation on, CPU per frame is 0.82-1.14 ms (p50) against 0.04-0.05 ms off, on both trees. At 60 frames per second that is 1.6-2.3 ms per tick, more than the whole post-T4 hand-off (0.54-1.93 ms) and more than the goal row's `step` (0.70-1.07 ms). At 120 Hz it doubles. These are the rendered benchmark's 300-unit layouts, not skirmish3v3.
- Cause (source): `world_view.gd:272-275` `blend()` runs `_apply_alpha` and `_rebuild_batch()` every rendered frame, and `world_batch.gd:169-189` `build()` re-sorts every item and re-triangulates every body each time. The art decision "triangulated once at load and sent as one triangle array per tick" (blueprint §7, M7.5) holds per tick, not per frame.
- Default (source): smoothing is on whenever quality is High (`graphics_settings.gd:52-54`), and Auto picks Low when frame p95 exceeds 8.3 ms (`:31-32`). So on a slow device Auto may switch smoothing off exactly where it would matter (inferred).
- Next target (estimate, not measured): build the triangle array once per tick and move bodies per frame without a rebuild, either a vertex shader with a per-frame alpha and the per-tick from-to offset per vertex, or one `MultiMesh` per shape class with per-instance transforms written from the rows. Either should bring the per-frame cost near the interpolation-off value. A cheaper interim: per frame only translate the vertex ranges of moving items, no sort and no triangulation. Any variant changes the batch's golden output (WB18) by design, so it needs its own test plan and a rendered A/B (window, ask first).
- T4b (`build()` reads rows instead of item Dictionaries) is 0.07-0.20 ms per tick (probe, upper bound, 4-7 % of the hand-off): fold it into the item above, not a task of its own.
- Against the data layout: the storage change saves an estimated 0.2-0.3 ms per tick on the goal row and moves to the worker anyway; the interpolation rework saves an estimated 1.5-2 ms per tick of main-thread work at 60 Hz and stays on the main thread with or without a worker. For the frame budget, presentation comes first.

## 8. Triggers: what would change this recommendation

- **First kernel earlier:** avoidance in packed GDScript misses the 0.5 ms cap on a 300-unit row even when staggered; or the user decides a horde mode of 1,000 or more agents; or a re-profile after steps 4-6 puts s at 0.60 or more on a goal row (then G_inc exceeds 2.2 and pays over the tax).
- **Storage earlier or broader:** the worker thread fails (Safari, production headers not approved, or the measured hand-off to the main thread costs more than `step` saves), so the simulation stays in the frame; or a Deck Firefox goal-row measurement exceeds the tick budget by more than option B buys.
- **Storage narrower (columns only at the boundaries):** the movement milestone's columns gain under 1.2x on `step.advance` against the Dictionary version (the horde workload gave 1.4-1.6x); then stop migrating further systems and keep columns for the fill and kernels only.
- **Whole port back on the table:** kernels land under movement, avoidance and combat and the remaining GDScript simulation still misses a goal-row budget on a worker thread. Not expected from today's numbers.
- **Presentation not first:** the interpolation rework is measured and saves less than 0.5 ms per tick at 60 Hz.

## 9. Not verified

- No Steam Deck or browser row for any number here; target numbers are Mac times F = 5.5.
- The 1.4-1.6x layout gain is from the horde workload; Wargrid's combat bookkeeping has no packed measurement.
- E 34-58 is one friendly kernel; combat has no E.
- Per-unit costs are bounds (no per-tick unit count in the profile).
- Interpolation cost was measured on the rendered benchmark layouts, not the 210-unit skirmish, and no profile zone splits the per-frame cost into sort, triangulation and submit.
- Fog and avoidance costs on columns are estimates; neither exists yet.
