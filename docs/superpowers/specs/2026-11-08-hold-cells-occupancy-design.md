# Persistent occupancy for `_hold_cells`: design (2026-11-08)

Status: **proposed, not approved, not started.** This is recommendation 1 of the [post-M7 performance spike](../../reference/performance.md#post-m7-performance-spike-2026-11). Rules come from the spike handoff (`performance-spike-prompt.txt`, private): the fix must keep every trace, it counts as one of at most three kept fixes, it changes no gameplay, and no budget is loosened. Read against `perf-spike` at 8839e4f.

## Recommendation: do not build; at most run the Task 0 gate

Removing `_hold_cells` saves at most 0.072 ms on open and 0.059 ms on dense, and only on the ticks right after a unit dies. The persistent set has to be kept up to date on every tick, and that upkeep costs most of the saving. The estimated net gain on p95 (0.03-0.05 ms on open) is about the size of the gap (0.045 ms) and about the size of the A/A spread (up to 0.042 ms). The upkeep falls on every moving unit on every tick, so the movement rows and the team match get slower by more than their spreads (0.017 ms and 0.001-0.007 ms) while gaining nothing. That breaks the handoff rule "no other row worse beyond the spread". The design below is complete in case the user wants the number anyway. Its Task 0 is a gate that only measures, about 30 minutes, nothing kept. Build Tasks 1-3 only if that gate passes. I expect it to fail.

## 1. Current cost mechanism

- `Combat.plan` makes one `held = {"ready": false, "cells": {}, "rings": {}}` per tick. The first `_approach` call that passes its repath gate and its "destination already in reach" exit calls `_hold_cells` (combat.gd:214, 231-236). `_hold_cells` goes through `sim._entities.values()`, which allocates an Array of every entity. For each entity that is not an air kind and has no `container_id`, it inserts `sim._cell(position)` and, if a destination is set, `sim._cell(destination)`. `_cell` is a method call plus `Vector2(...).floor()` plus `Vector2i`. The set covers all owners and also units with no combat (collectors). Its body is a copy of `Simulation.occupied_cells()` (simulation.gd:92).
- Inside the tick the set is used in three ways only: `held.cells.has(cell)` in `_firing_cell`, which is reached only after the distance and component filters; `held.cells.erase(previous)` in `_approach`; and `held.cells[goal] = true` in `_approach`. Nothing iterates over it.
- Measured cost (2i, 51f8550, profiler on, 300 warm-up + 1800 ticks), as the mean per tick on ticks after a removal, with other ticks in brackets: open 0.072 [0.006], dense 0.059 [0.000], hordes300 0.159 [0.013]. Ticks after a removal are 7.8 %, 8.2 % and 5.7 % of all ticks. They own the p95: 75-92 % of the p95 ticks follow a removal (Workstream 1 / 2a). Inlining the cell floor recovered 0.013 / - / 0.027. The best 2i prototype recovered about 0.015 ms. 2f.0 put the whole `firing_cell` excess after a removal at +0.15 / +0.15 / +0.35. Of that, the ring loop is 0.097 / 0.091 / 0.216 and cannot be recovered (2i).
- Since 2i, Workstream 4 typed `Horde`, `Locomotion` and `_advance`. The g2 typing of `_hold_cells` was not kept, so its cost should be unchanged. That has not been re-measured. Task 0 re-measures it.
- Rows today, as p95 at the end of Workstream 4: open 1.865, dense 1.796, hordes300 2.821. Budget 1.82.

## 2. Proposed structure

**Owner.** `Simulation` owns the structure, because it owns `_entities` and nearly every write site. Combat only reads it.

- `var _held: Dictionary = {}` maps a `Vector2i` to an `int`. The value counts contributions: each entity that is not air and not contained adds +1 for the cell of its position and +1 for the cell of its destination, if it has one. Cells whose count is 0 are erased.
- `var _held_frozen: bool = false` and `var _held_pending: Array = []` hold a flat list of cell and delta pairs.
- `_held_bump(cell, delta)`: while frozen, append the pair; otherwise apply the delta and erase the cell when its count reaches 0.
- `_held_drop(unit)` and `_held_add(unit)`: return at once for an air kind or a contained unit. Otherwise bump the cell of the position and, if a destination is set, the cell of the destination, by -1 or +1. Both use `_cell` exactly as `_hold_cells` does.

**Invariant I1.** While not frozen, `_held` equals exactly the per-cell contribution counts computed from `_entities` at that moment. The test oracle's copy of the old loop computes the same counts.

**Updates.** A hook is needed only where an entity outside a container changes. There is no owner change anywhere: `rg '\.owner\s*=' game/scripts/simulation` finds nothing, and the set ignores owners anyway. There is no kind change either.

| Event | Site | Hook |
|---|---|---|
| spawn | `spawn` (simulation.gd:85) | `_held_add` after the insert |
| removal | `remove_object` (simulation.gd:743) | `_held_drop` just before `_entities.erase(id)` |
| move | `_advance` (simulation.gd:614), runs every tick for every moving unit | fast path: `var from := _cell(unit.position)` before the write and `var to := Vector2i(Vector2(x, y).floor())` after it; only when they differ and the unit is not air and not contained, bump -1 and +1. This must use `Vector2.floor()` (float32), not `floorf` on the float64 locals, because `_cell` rounds to float32 first and the two can disagree just below an integer. |
| destination | simulation.gd:377 `_apply_orders`, 433 and 443 `_assign_move`, 458 `_stop_unit`, 574 `_assign_route`, 685 `_replace_union`, 795 `_attach_builder`; combat.gd:197 `_halt`, 225 `_approach`; containers.gd:57 `head_for`; supply_collection.gd:109 `_seek` | one helper `_set_destination(unit, value)` that bumps the old cell -1, writes, then bumps the new cell +1 (only for units outside a container); each site calls it instead of assigning |
| board | containers.gd:110 `_board` | `_held_drop` before `container_id` is set (`_stop_unit` has already cleared the destination through the helper) |
| exit | containers.gd:136-137 `_exit_all` | `_held_add` after the position write |
| passenger moves | containers.gd:69 `step`, 204-205 `_relocate` | none: the unit is contained before and after, so it contributes nothing |
| reset | `_init` | `_held = {}`. There is no reset or load path: `rg 'restore\|from_snapshot\|_entities\s*='` finds nothing, and netplay replays commands from tick 0. If a load path is added later, it must rebuild `_held` with the counting loop. |

**Freeze inside `plan`.** The old set is a snapshot taken at one instant: the first approach of the tick that reaches line 214. Units planned earlier in the same tick (ascending id) may already have changed destinations through `_halt`, `_stop_unit` or `_go_home` / `_assign_move`, and the snapshot sees those changes. Changes made after the snapshot are never seen, except the approach's own erase and insert. The new code reproduces exactly that:

- `held = {"ready": false, "over": {}, "rings": {}}`. In `_approach`, `if not held.ready: held.ready = true; sim._held_frozen = true` replaces the call to `_hold_cells`.
- `held.cells.erase(previous)` becomes `held.over[previous] = false`, and `held.cells[goal] = true` becomes `held.over[goal] = true`. The last write wins. This keeps the set behaviour where it differs from the counts: an erase frees the cell even when another entity also sits in it or is heading there.
- In `_firing_cell` the lookup becomes `held.over.get(cell, sim._held.has(cell))`.
- At the end of `plan`: `if held.ready: sim._held_unfreeze()`, which applies `_held_pending` in order, clears it and sets `_held_frozen = false`. `plan` has no `return`, so there is only this one exit.
- Delete `_hold_cells`. The test file keeps a copy of it as the oracle.

**Hashes and snapshots.** `_snapshot()` (simulation.gd:626) lists its fields explicitly, so `_held*` is not added there. It therefore never reaches `StateHash.digest`, `core_check`, the replay traces, `seat_sim.snapshot` or lockstep. No field is added to any entity Dictionary, so `_entity_copy` is unaffected. Task 2 checks this with `rg -n '_held' game/scripts/simulation/simulation.gd`: the field must appear only in its declaration, the helpers and the hooks. H1 `PINNED` must stay unchanged.

**Test fixtures.** Tests that write `position`, `destination` or `container_id` directly bypass the hooks: `test_combat` 16 lines, `test_horde` 5, `test_supply` 4, `test_combat_navigation` 2, `test_salvage` 1, with some of these being camera lines; the N1 `_oracle_world` also writes `container_id`. Add `rebuild_held(sim)` to `game/tests/combat_fixture.gd` (test code only, the same counting loop) and call it after every such write that a `step()` follows. Game code never writes these fields directly; the only entity insert is `spawn`.

## 3. Why traces and `combat_work` cannot change

- The structure is only asked whether it contains a cell, and is never iterated. So the insertion order of `_held` and `held.over` cannot affect anything.
- The cells come from the same expressions as before: `_cell(...)` (`Vector2i(Vector2(p0, p1).floor())`) and `Vector2i(goal.floor())`. The fast path in `_advance` uses the same `Vector2.floor()` form. No float is computed differently, and `unit.position = [x, y]` stays as it is.
- Equality argument: I1 holds at the moment of the freeze, so the frozen counts are non-zero exactly on the old set. After the freeze, the old set changes only through erase and insert, and the overlay applies the same changes with the same "last write wins" rule. Every other write is deferred to `_held_pending`, and the old set never saw those writes either. So every lookup returns the same answer, `_firing_cell` picks the same `best`, and the destination, route, `_path_queue` order and replay traces are the same. Deltas add up in any order, so applying the pending list at unfreeze restores I1.
- `combat_work`: only `_firing_cell` (`ring.window_cells`) and `_nearest` add to it, and neither changes. `_hold_cells` never touched it.

## 4. Expected gain, with an honest bound

- **Ceiling** (if upkeep were free), on the ticks after a removal: open 0.072, dense 0.059, hordes300 0.159 ms. The p95 can move by at most about that much.
- **Upkeep cost** (estimate, not measured): about 0.05-0.1 us per moving unit per tick for the two `Vector2.floor()` calls and the compare in `_advance`, plus about 0.3-1 us per cell crossing, per destination write and per pending entry. That gives about 0.01-0.02 ms per tick on combat open and dense (about 146 / 126 moving units), 0.02-0.03 on hordes300 (about 246), and 0.02-0.04 on movement open and dense (300 moving units, where nothing is gained). Ticks after a removal also pay for their own extra stops and approaches, about 0.005-0.015.
- **Net on p95**: open about 0.03-0.05 ms against a gap of 0.045, dense about 0.03-0.045 (already about 0.02 under the budget, inside the spread), hordes300 about 0.12 (the gap there is 1.0 ms). On the other ticks the change is a slowdown of about 0.01 ms.
- **A/A spread** (Workstream 4): open p95 median delta -0.004, spread per tree 0.001-0.042; movement 0.017; team match p50 0.001 (2h) to 0.007. In 2h a team-match cost of +0.5 to +1 % was enough to call the change a regression and led to 2j.
- **Verdict**: the ceiling is above the spread, so this is not an automatic stop. The net gain is about equal to the spread, though, and the movement rows and team-match p50 will probably get worse beyond their spreads. So the change most likely fails acceptance as specified. It would not close hordes300.
- **Alternative rejected**: rebuilding position occupancy lazily per 8x8 bucket from `_build_grid`. Fights crowd into the buckets around the targets, so those are the very buckets it would rebuild. Destinations would still need hooks and a freeze, and on pursue-only ticks the grid is not built at all (0.07-0.16 ms to build).

## 5. Test plan

The failing tests are the spec. Write them on the mid tier or higher, before the implementation, all in `game/tests/test_combat.gd` next to N1, and add them to the test list at line 15. The oracle is a test-side copy of the old `_hold_cells` loop that returns counts (a multiset).

- **HC1 `test_held_matches_oracle`**: 300 seeded states (fixed seed, in the style of `_oracle_world`, but every mutation goes through a real API). Each state has 2-6 owners, the kinds `usa_rifle_infantry`, `usa_tank`, `usa_collector` and one air kind, about 40 units, and the containers that `rebuild_held` needs. Per state, run 6 rounds of random mutations: `spawn`, `remove_object`, move / attack / attack_move commands through `issue_command`, `_stop_unit`, `Combat._halt` (with `_chases` set), `Combat._go_home`, `Containers._board` / `unload`, `Containers.head_for`, and `step()`. Seed one unit 1e-7 below a cell boundary so the float32 floor case is covered. After every call check `sim._held == oracle_counts(sim)` (exact Dictionary equality, no zero entries), `_held_frozen == false` and `_held_pending.is_empty()`. Count the checks per mutation kind and fail if any kind has zero, or if there are fewer than 300 x 6 step checks.
- **HC2 `test_held_same_tick_cases`**: spec-worded, with the expected goal cells captured by running on a git archive of the base tree:
  - (a) a halt by a lower-id unit before the first approach frees its destination cell, so a higher-id approacher may take it;
  - (b) a halt after the first approach does not free the cell in that tick, but does in the next;
  - (c) an approacher's old destination cell, shared with another unit's position, is free for a later approacher in the same tick (erase semantics);
  - (d) `remove_object` on the unit in the best ring cell frees that cell for the next plan;
  - (e) a spawn between steps into the best ring cell holds it;
  - (f) boarding frees the unit's cells, and exiting holds them again;
  - (g) an air unit in the best cell never holds it;
  - (h) an approach that returns no cell (`blocked`) defers its `_stop_unit` hook until unfreeze.
- **HC3 `test_held_workloads`**: `CombatWorkload.create(layout)` for open, dense, hordes300, contact, skirmish3v3, transports, defences, docks, ramp and frc, 600 ticks each. Check I1 before every `step()`. Expect zero mismatches and more than 0 approaches per layout (`_scan_chases` or a new count of approaches); fail on zero.
- **Mutations** (scratch copy, each must turn HC1, HC2 or HC3 red; record the mismatch counts):
  - M1: skip the fast path in `_advance`;
  - M2: the fast path uses `floorf` on the float64 locals (the HC1 boundary seed must catch it);
  - M3: `_set_destination` skipped in `_stop_unit`;
  - M4: apply bumps live while frozen (HC2 b);
  - M5: the overlay erase decrements the count instead (HC2 c);
  - M6: the air filter dropped (HC2 g);
  - M7: `remove_object` without `_held_drop`;
  - M8: `_exit_all` without `_held_add`.
- **Acceptance** (from the handoff):
  - suite 0 failures and no case lost (486 plus the new ones); `sh tools/run_lint.sh` and `sh tools/run_warnings.sh` pass;
  - the four traces `cmp`-identical to a git archive run of the base; the 7 pin lines unchanged; `sh tools/run_netplay.sh match` PASSED at tick 8400; `sh tools/run_team_match.sh` exit 0 with the cap line; `combat_work` identical in every A/B pair.
- **Timing**: A B A B A B from git archive copies on the Apple M6 when quiet (`pgrep -fl 'godot|generalszh'` empty, `uptime` at start and end). Rows: run_combat (open, dense, hordes300, contact, skirmish3v3, transports, defences, docks, frc, ramp), run_movement open and dense, run_lockstep p99, run_team_match p50 / p95 / p99 and wall time.
- **Keep only if** open and dense p95 beat the A/A spread and no row (movement and team-match p50 included) is worse beyond its spread. Either way, record the result in `perf-spike-verification.md` and add a ledger row.

## 6. Task list (Sonnet, medium; one fresh subagent per task)

- **Task 0, gate (measure only, scratch copies, nothing kept)**:
  - G1: in a git-archive copy B, add `_held`, `_held_bump`, the spawn and remove hooks and the `_advance` fast path, with nothing reading them. Run A/B on movement open and dense, team match, and combat open and dense, A B A B A B.
  - G2: re-profile the `_hold_cells` zone on HEAD (open, dense, hordes300) with the 2i split by whether the previous tick had a removal.
  - **Go** only if the G2 mean after a removal minus the G1 cost per tick is larger than the open p95 A/A spread, **and** G1 leaves movement and team-match p50 within their spreads. Otherwise record "not built" with the numbers in `docs/reference/perf-spike-verification.md` and stop.
- **Task 1, tests first**: HC1-HC3, the oracle and `Fixture.rebuild_held` in `game/tests/test_combat.gd` and `game/tests/combat_fixture.gd`. HC2's expected values come from the base tree. Confirm HC1 and HC3 are red because `_held` does not exist yet, and that HC2 is green on base.
- **Task 2, implementation**:
  - `game/scripts/simulation/simulation.gd`: fields, `_held_bump`, `_held_drop`, `_held_add`, `_set_destination`, `_held_unfreeze`, the spawn, remove and `_advance` hooks, and the destination sites from §2;
  - `game/scripts/simulation/combat.gd`: `plan`, `_approach`, `_firing_cell` and `_halt`; delete `_hold_cells`;
  - `game/scripts/simulation/containers.gd`: `head_for`, `_board`, `_exit_all`;
  - `game/scripts/simulation/supply_collection.gd`: `_seek`;
  - `Fixture.rebuild_held` calls after direct writes in the test files listed in §2 (find them with `rg -n '\.(position|destination|container_id)\s*=[^=]' game/tests`);
  - check with `rg` that `_held` is not in `_snapshot`.
- **Task 3, verification**: the mutations M1-M8, acceptance (suite, lint, warnings, traces, pins, netplay, team match), the A/B timing and the keep rule from §5. Write the results to `docs/reference/perf-spike-verification.md` and add a ledger row to `docs/reference/performance.md`. Commits follow the handoff.
