# Snapshot copy cost: design (2026-11-08)

Status: **proposed, not approved, not started.** Task T10 of the [gap closure plan](../plans/2026-11-08-spike-gap-closure.md). Rules from the [spike handoff](../../performance-spike-prompt.txt): no gameplay change, traces and digests identical, at most three kept fixes per round, no budget loosened. Read-only design, against `perf-spike` at 43bf48e plus the uncommitted docs. No Godot process was run; every number below comes from existing logs (R2 runs `A1-A3.out`, `B1-B3.out` and Workstream 1 `ws1/profile.log` in the spike scratchpad, the M6 Task 11 records, and the ledger).

## Recommendation

The task's premise is out of date. The "double copy" (simulation `duplicate(true)` plus the view's deep `state.duplicate(true)`) was removed in M6 Task 11 (fix D and 11d, [m6-verification](../../reference/m6-verification.md) "Task 11 perf fixes" and "Task 11.9 re-measure": `view.copy` 0.743 -> 0.078 ms). What the R2 row shows is something else: **two `snapshot()` calls per rendered tick** (`calls_per_tick=2.00` on open, dense and Ashfall in all six R2 runs). The second call comes from the benchmark harness, not from the game: `MovementWorkload.settled()` (movement_workload.gd:53-54) takes a full snapshot every tick to check whether all units have arrived.

1. **P0, do now (docs only):** correct the plumbing row. With one snapshot it is 0.87 ms on Ashfall (budget 0.91, passes by 0.04 ms), not 1.68. On the combat layouts it is 1.21-1.30 ms (exceeded).
2. **P2, do now (small game fix, presentation only):** the skirmish and online scenes take **3 snapshots per tick** whenever a production building is selected (`_production_kind` calls `simulation.snapshot()`, twice per HUD refresh). This saves about 1.5 ms per tick at 300 units, but no benchmark row shows it.
3. **P1, the user decides:** the same `settled()` snapshot sits **inside the timed window of the gated headless movement row** (`run_movement.gd:31-32`, also `bench_runner.gd:40-41`). About half of the "sim-only" 1.50 ms p95 is snapshot. Making `settled()` cheap is correct, but it moves a gated row by about 0.7 ms and every rendered tick row by 0.74 ms. That is a change of what a row measures, so it cannot be folded in silently.
4. **P3, only after a gate:** a cheaper `_entity_copy`. It shares `position`, `heading`, `destination` and `order` read-only, the way `route` already is. This is the only proposal that cuts real per-tick game cost for every consumer. Its gain is unmeasured (estimated 0.15-0.4 ms per 300-unit snapshot). It costs three test rewrites and needs a probe first. Run it only after P1 is decided; otherwise it would "improve" the movement gate through the harness.

Rejected: handing the view a live, read-only reference. A shallow view copy changes nothing (section 3).

## 1. Where each copy happens, and its cost

Per-tick zone means, ms, R2 six runs (profiler on, Apple M6, rendered); spreads are min-max across the runs.

| Zone | open | dense | Ashfall | horde (400 units, combat) | large_196 |
|---|---|---|---|---|---|
| `snapshot` (per tick) | 1.468-1.502 | 1.486-1.508 | 1.458-1.480 | 0.993-1.006 | 1.080-1.089 |
| `snapshot` calls per tick | 2.00 | 2.00 | 2.00 | 1.00 | 1.00 |
| `snapshot` per call | 0.73-0.75 | 0.74-0.75 | 0.73-0.74 | 0.99-1.01 | 1.08-1.09 |
| `view.copy` | 0.083-0.085 | 0.084-0.086 | 0.078-0.080 | 0.141-0.150 | 0.155-0.157 |
| `view.sort` | 0.053 | 0.053-0.054 | 0.053-0.054 | 0.060-0.061 | 0.063-0.064 |
| `view.points` | 0.075-0.076 | 0.075-0.077 | 0.080-0.081 | 0.082-0.083 | 0.089-0.091 |
| plumbing, ledger definition (one snapshot + copy + sort) | 0.88 | 0.88 | **0.87** | **1.21** | **1.30** |

Headless (Workstream 1 `run_profile.gd`, one snapshot per tick, harness excluded): movement open `snapshot` 0.729 mean against `step` 0.653; combat open 0.539.

Copy sites inside `Simulation._snapshot()` (simulation.gd:626-642):

- **Entities, the main cost.** `_entity_copy` (584-589) makes a shallow `duplicate()` of each unit (17 keys), loops over every key, and `duplicate(true)`s every Array or Dictionary value except `route`, which is shared read-only since d9e00b3. In the movement workload that means `position`, `heading`, `destination` and `order` (with its `target`). Combat units add `combat`; collectors add `collection`; containers add `passengers`.
- **`_sorted_copies`** (693-699) covers buildings, sources and players. These are not the cost: open has no buildings or sources, and its per-call snapshot (0.73-0.75) equals Ashfall's (0.73-0.74, with 6 buildings and 12 sources).
- **`_pending`, `_command_results`, `_combat_events`, `_match`, `_crates`** are `duplicate(true)`; they are small. `path_queue` is a shallow copy.
- **`map` and `terrain_cells`** are already cached read-only (e5aee2e).
- **`_player_snapshots`** loops over players times buildings to fill the power fields. This is small here and not measured on its own.

View side (`WorldView.set_state`, world_view.gd:53-70): `state.duplicate()` is a **shallow** copy of about 18 keys. It cannot cost 0.08-0.16 ms by itself, and its cost grows with entity count and combat fields. Hypothesis, not verified: the zone pays to free the previous tick's snapshot tree, because `_state` held the last reference to it. `view.sort` builds a new depth-sorted entity array (references only). `view.points` reads positions.

Callers that snapshot per tick:

| Caller | When | Snapshots |
|---|---|---|
| `base_main._refresh` / `main._refresh` | every physics tick | 1 |
| `skirmish_main._production_kind` via `base_main._refresh_hud:86` and `skirmish_main._refresh_hud:155` | every tick while a production building is selected | +2 (+1 if it is not completed) |
| `Skirmish.issue_opponents` | every 30 ticks (`DECISION_TICKS`), shared by all bots | 1/30 |
| `online_main._step_simulation` -> `Lockstep.finish_tick` | hash ticks only | 1 per hash tick |
| `base_main._builder` (placement preview) | per mouse move, at most once per tick | input-driven, not targeted |
| `MovementWorkload.settled` (harness: `run_movement`, `bench_runner`, `movement_benchmark`) | every tick, **inside the timed window** in `run_movement.gd` and `bench_runner.gd` and inside the rendered `tick_ms` | 1 |

Cross-check for the movement row: `run_movement` p50 1.438 (WS4) ≈ `step` p50 0.716 + `snapshot` p50 0.735 (Workstream 1 profile). The profiled step and the harness snapshot account for it.

## 2. Who needs an independent copy

"Independent" here means that a held snapshot keeps its values while the simulation advances. The sim replaces the shared arrays and never edits them, so read-only sharing gives the same guarantee.

| Consumer (checked) | Use | Needs | P3 effect |
|---|---|---|---|
| `WorldView.set_state` and its draw, marks and points | holds `_state` until the next `set_state`; reads only (grep: no writes into state) | values stable until the next tick | none |
| `main` / `base_main` / `skirmish_main` / `online_main` HUD and input (`_refresh_hud`, `_building`, `_local_state`, `_context_order`, `_container`, `_matching_ids`, `_enemy_at`, `_builder`) | read immediately | read only | none |
| `Skirmish.issue_opponents` / `_decide` | reads one state while it calls `issue_command` | `pending_commands` and `last_sequences` must not follow the live queue | none: those stay deep copies |
| `Lockstep.finish_tick` -> `StateHash.digest`, and `_hash_snapshot` kept for `desync_report` | hashes now, keeps it for later | the picture of the hashed tick | none (replaced arrays keep the old values) |
| `StateHash.digest` (`state.hash()` + `core_check`) | hash depends on key order and values | same key order and values | shallow `duplicate()` keeps key order; the read-only flag is not hashed (d9e00b3 and e5aee2e left H1 `PINNED` unchanged) |
| Four replay traces (`test_replay.gd`, `test_team_match.gd`, `tools/compare_local_traces.sh`), TB3/TB4, S1/Cs1/Fm1 | digest per tick | as above | none expected; the oracle |
| BM5 `test_snapshot_size_ceiling` | counts nodes | node count | unchanged (shared arrays still count) |
| Tests that deep-copy and then edit: H2/H3/H4 (`test_state_hash.gd`), R2 (`test_replay.gd:67`), C9 (`test_simulation.gd:160-176`) | `duplicate(true)` first | writable copies | none (deep copies of read-only arrays are writable; H2 already edits a copied read-only `route`) |
| **C12** `test_simulation.gd:248` | writes `order.target[0]` into a raw snapshot | an independent `order` | **breaks**: rewrite as `is_read_only()` plus "a held snapshot keeps its target" |
| **G4** `test_groups.gd:114` | writes `destination[0]` into a raw snapshot | an independent `destination` | **breaks**: same rewrite |
| **A4** `test_combat.gd:919` | in-place `sim._entities[prey].position[0] += 1.0` on the live unit, after snapshots froze it | a writable live position | **breaks**: replace the array (`position = [x + 1.0, y]`) |
| Benchmarks and debug (`movement_benchmark` `_horde_start`, `_finish_layout` goal keys, `run_movement._valid`, `combat_workload`) | hold or compare values | values | none |

Sim writers of `position`, `heading`, `destination` and `order` (scripts grep for `x[0] =`, `.order.k =`, `append`/`clear`/`pop_*` on these fields): **none edit in place**. All of them replace the value (`_advance` writes `unit.position = [x, y]` every tick; `Locomotion` sets `heading = [...]`; orders get new dictionaries). `combat`, `collection` and `passengers` are edited in place, so they stay deep copies.

## 3. Proposal

**P0, ledger correction.** In the `performance.md` plumbing row, "Current": keep the 2026-11-03 figure; replace "1.68" with "one snapshot per game tick (R2 profiled 2.00 calls, one from the harness's `settled()`): Ashfall 0.73 + 0.08 + 0.05 = 0.87, open 0.88; horde 1.21, large_196 1.30". Status: "passes on the movement layouts by 0.04 ms, exceeded on the combat layouts". The budget is unchanged.

**P2, one snapshot per HUD refresh.** `_production_kind(building)` becomes `_production_kind(building, state)`. `base_main` ignores `state`; `skirmish_main` reads `_local_state(state)` instead of `_local_state(simulation.snapshot())`. Call sites pass the state they already hold: `base_main:86` and `skirmish_main:155` (`_refresh_hud`), `skirmish_main:25` (`super`), and `base_main:286` (`_produce_selected` keeps its snapshot in a local first). Same tick, same state, same faction, so the labels and commands stay identical. It touches no sim file.

**P1, cheap `settled()` (user decision).** `MovementWorkload.settled(sim)` reads live state instead of a snapshot:
`not sim._entities.is_empty() and sim._pending.is_empty() and every sim._entities value has status "arrived"`.
The workload already uses `sim._entities` in `create()`. It returns the same boolean as today (the snapshot's entities are exactly `_entities` values, and `pending_commands` is a copy of `_pending`), so the commands issued, the workload and the sim are identical. It changes the values of these rows: headless movement p95/p99 (gated), `bench_runner` movement (the F series), and rendered `tick_ms` and frame rows for open, dense and Ashfall. The user chooses (a) keep the harness as is and report that the row contains one snapshot, or (b) apply it with one ledger row that carries both values and a note that the history before it is not comparable.

**P3, share the replaced fields.** In `_entity_copy`:
```gdscript
const SHARED_FIELDS: Array[String] = ["route", "position", "heading", "destination", "order"]
# loop: skip SHARED_FIELDS; deep-copy every other Array/Dictionary (unknown fields stay safe)
# then freeze the live values once: _freeze(unit.position), heading, destination, order, order.target
```
`_freeze(v)` does nothing for `null`, and otherwise calls `make_read_only()` if the value is not read-only yet; `route` already works this way (588). Key order stays the same because `copy = unit.duplicate()` and reassignments do not reorder keys. Two facts are unverified and the probe checks them: `Dictionary.make_read_only()` is shallow (hence the separate `order.target` freeze), and an in-place write to a frozen array is skipped with an error rather than aborting the script. A writer missed by the grep would therefore become a deterministic no-op on every peer, not a desync. The suite would catch it through the traces and through a new check for "read-only" errors in the suite output.

**Rejected: a live reference for the view.** It would save the whole snapshot (0.74), but:
- `Lockstep._hash_snapshot` needs the hashed tick, not the current one;
- the bots read a state while queueing commands;
- G4, V4 and C9 compare `snapshot() == before` across mutations;
- the view needs id order and the derived player fields (`power_supply`, `alive`) that only `_snapshot` computes;
- one stray write from presentation code would desync online play;
- M6 already listed "presentation reading live state" as deferred and not approved.

**Rejected: dropping the view's shallow `duplicate()`.** It saves at most the `dict.duplicate()` of about 18 keys. The 0.08-0.16 zone is most likely the free of the previous snapshot, which moves elsewhere. It would also make `set_state` overwrite the caller's `entities` order.

## 4. Gain bound

| Item | Real game gain per tick | Rows it moves | Above noise? |
|---|---|---|---|
| P0 | 0 | plumbing row 1.68 -> 0.87 (an accounting fix) | n/a |
| P1 | 0 (harness only) | headless movement p95 about -0.7 (1.50 -> about 0.8, estimate); rendered tick -0.73 to -0.75 mean on open, dense and Ashfall; `snapshot` 2.00 -> 1.00 calls per tick | yes, far (the tick p95 spread is 0.02-0.04). Frame p95: probably no change; R2's -0.43 ms of `_draw` per tick did not move it |
| P2 | -2 snapshots while a production building is selected: about -1.5 ms at 300 units, less at skirmish sizes (41 entities peak in the M4 probe; scaled by entity count, unmeasured) | none (no benchmark selects a building) | not measurable on a row; the oracle is a call count |
| P3 | unmeasured; estimate -0.15 to -0.4 ms per 300-unit snapshot (4 small deep copies plus their frees per unit, against about 2.4 µs per unit today) | plumbing (0.87 -> about 0.5-0.7; horde 1.21 -> about 0.85-1.05); the `view.copy` free cost; with P1 not applied, also the movement gate (an artifact) | per call zone spread 0.011 ms, so 0.1 ms is about 10x the spread. If the probe shows < 0.1 ms per snapshot, stop |

Honest summary: P0 and P1 change numbers, not cost. P2 is a real but unbenchmarked game saving. P3 is the only general cost cut, and its size is a guess until the probe runs. If P1 is applied and P0 is accepted, the plumbing row already passes on the movement layouts. P3 then only matters for the combat layouts and for low-end headroom (×5.5 makes 0.3 ms about 1.6 ms on the target).

## 5. Test plan

Oracles:
- **O1, equal values (P3).** For four seeded states (movement open at step 38, as in BM5; `hordes300` at tick 600; the skirmish match at tick 3000; a team-match prefix at tick 2000), build a reference snapshot by deep-copying each live entity in id order into the new snapshot's place. Assert `snapshot.entities == ref`, `keys()` equal per entity, and `StateHash.digest(new) == StateHash.digest(new with ref entities)`.
- **O2, mutation after snapshot (P3).** Take snapshot S at tick t and deep copy D. Step 30 ticks covering movement, turning, an order replacement, retarget and fire (horde), a collector cycle (economy) and enter/unload (containers). Assert S == D. This generalises M-route.
- **O3, sharing (P3).** Two snapshots without a step share `position`/`heading`/`order` (`is_same`), and the shared values are read-only. After a step, a moved unit has a new `position` array.
- **O4.** C12, G4 and A4 rewritten as in section 2. Reviewer check: reverting the `_entity_copy` change makes O2 or O3 fail (name which).
- **O5 (P2).** In a skirmish scene test, select a completed barracks, `Profiler.reset()`, enable it, call `_refresh()`, and assert `Profiler.calls(&"snapshot") == 1`. Red on HEAD (3). Assert the Produce label text is unchanged (N1).
- **O6 (P1).** In `test_benchmark.gd`, for open and dense, compare at every tick of 600 workload ticks: new `settled(sim)` == the snapshot-based predicate. BM3 keeps passing.

Gates (each kept fix, on a `git archive` copy):
- suite 0 failures, cases equal to the old count plus the new ones;
- `run_lint.sh` and `run_warnings.sh`;
- the four traces `cmp`-identical to the base archive;
- pins S1 8501 / core series, Cs1 26359, Fm1 23534 winner 1, TB3, TB4, H1 `PINNED`, BM5 ceilings;
- `run_netplay.sh` match PASSED at tick 8400;
- the `run_team_match.sh` cap line;
- zero "read-only" errors in the suite output (`rg -c 'read-only'`).

Timing, quiet M6, one Godot process at a time:
- A/A first, then A B A B A B with three rounds per tree, one fix per comparison (P1 and P3 measured separately).
- Headless: `run_profile.sh` (`snapshot` per call, `view.copy`), `run_movement.gd`, `run_combat.gd`, `run_lockstep.gd` (overhead p99 and snapshot-on-hash p99), and the team match (`snapshot` zone 0.335).
- Accept when `snapshot` per call is better than the A/A spread and no row is worse beyond its spread, as the handoff requires.
- Rendered (in the user-approved U3 Mac batch, once, batched): `sh tools/run_game.sh res://scenes/movement_benchmark.tscn -- --profile`, A B A B A B. Compare tick p50/p95, frame p95, `ASHFALL_FRAME_P95_MS`, and `snapshot` mean and calls per tick.
- Lockstep: `run_lockstep.gd` plus `run_netplay.sh` on the same trees.

## 6. Task list (Sonnet, medium; one fresh subagent each)

1. **T10a, P0 (CPU-light).** Edit `docs/reference/performance.md` (plumbing row, "Current" and "Status" only) and add a dated row to `docs/reference/perf-spike-verification.md` with the per-call table from section 1. No code.
2. **T10b, P2.** Red test O5 in `game/tests/test_skirmish_scene.gd`, then change `game/scripts/base_main.gd` (`_production_kind`, `_refresh_hud:86`, `_produce_selected:281-286`) and `game/scripts/skirmish_main.gd` (`_production_kind`, `_refresh_hud:155`). Run the suite, lint and warnings. No traces needed (no sim file), but run the four traces anyway, since it is cheap.
3. **T10c, decision (coordinator -> user).** P1 (a) or (b). Then report the P3 probe result and get a go.
4. **T10d, P3 probe (quiet, headless, scratch only).** A scratch script with the old and the new `_entity_copy` side by side. It times 1000 snapshots on movement open at step 38 and on `hordes300` at tick 600, 3 interleaved rounds. It also checks `Dictionary.make_read_only` shallowness and the behaviour of a write to a frozen array. It must `quit()` on every path. Go only if the gain is ≥ 0.1 ms per snapshot.
5. **T10e, P3 (only on go).** Red tests O1, O2 and O3 (`game/tests/test_simulation.gd`, `game/tests/test_movement.gd`), then `game/scripts/simulation/simulation.gd` (`_entity_copy` and a `_freeze` helper only). Then rewrite C12 (`test_simulation.gd:248`), G4 (`test_groups.gd:114`) and A4 (`test_combat.gd:919`), listing them as allowed test changes in the verification row. Run all gates.
6. **T10f, P1 (only if (b)).** O6 in `game/tests/test_benchmark.gd`, then `game/scripts/debug/movement_workload.gd` (`settled` only). Run all gates. Write the ledger row with both values.
7. **T10g, measurement (quiet).** The headless A/B per kept fix, then a `performance.md` ledger row and a verification row.
8. **T10h, rendered A/B in the U3 batch, plus lockstep.** Carried by the coordinator's single window request; one row each.

Not checked: the hypothesis that `view.copy` is the free of the previous snapshot, the P3 gain, `make_read_only` semantics on Dictionary, `_player_snapshots` cost in the team match (6 seats times about 60 buildings), and web/Deck behaviour.
