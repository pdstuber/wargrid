# M6 Teams, Full-Scale Map and Feel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (native, sequential, per `prompt.txt`). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a deterministic headless 3v3 bot match to a team victory on a full-scale map converted from EA's GPL Twilight Flame. Zero Hour's edge-to-edge range, Ranger cadence, tank splash, start delay, acceleration and turning are in, every pin is recalibrated once, and the ledger rows are inside unchanged budgets.

**Architecture:**
- **Map.** A stdlib Python converter (`tools/zh_map/`) turns the `.map` into `game/data/maps/ashfall.json`. A GDScript loader (`map_data.gd`) builds a `Simulation` from any map file; the 48×32 skirmish becomes `game/data/maps/skirmish.json`.
- **Teams.** Seats get a team id. One hostility rule, `Combat.hostile`, replaces every `owner !=` check. Victory is per team.
- **Feel.** Combat feel lives in `combat.gd` and `combat_definitions.gd`. Movement feel lives in a new `locomotion.gd` called from `Simulation._advance`, with no runtime trigonometry.
- **Order.** Map and teams first (the 1v1 stays identical), then feel, then measurement and scaling, then one recalibration.

**Tech Stack:** Godot 4.7.2, typed GDScript, Python 3 stdlib, `sh tools/run_tests.sh`, `sh tools/run_benchmark.sh`, `sh tools/run_netplay.sh`, `tools/zh_parity/`.

**Spec:**
- [M6 design](../specs/2026-11-05-m6-teams-full-map-design.md), approved 2026-11-05.
- Evidence: [M6 map and feel](../../reference/m6-map-and-feel.md), [parity spike](../../reference/zero-hour-parity-spike.md), [parity harness](../../reference/zero-hour-parity-harness.md).
- Rules it changes: the [M1 plan](2026-11-01-m1-vehicle.md) (instant movement), the [M4 design](../specs/2026-11-03-m4-combat-design.md), the [M5.1 design](../specs/2026-11-05-m5.1-playtest-findings-design.md).
- Run rules: [milestone prompt](../../milestone-prompt.md).
- Verification file: `docs/reference/m6-verification.md` (Task 0 creates it).

## Model routing

- **Opus (high):** Task 1 (source reading, INI values, cost judgement), every gate review, the Task 14 substantive review.
- **Sonnet (medium):** Tasks 2–12. Task 11's fixes were measured and approved up front (performance spike, user 2026-11-05), so it needs no cost judgement. These tasks are specified down to signatures, algorithms and test values; when a step leaves a real choice the plan does not settle, stop and ask instead of guessing.
- **Sonnet (low) is acceptable** only for Tasks 0 and 13 (records, ledger rows).

## Code anchors and pitfalls

- **Suites.** A suite file `extends RefCounted`, has `func cases() -> Array[Callable]` and test functions `func test_x(runner) -> bool` that call `runner.check(condition, "<ID> message")` and return `true`. New suites are added to `Suites` in `game/tests/run_tests.gd`. Python tool tests use `unittest` like `tools/test_check_reference.py` and run as `python3 tools/<dir>/test_x.py`.
- **Commands.** `sim.issue_command({"tick", "player", "sequence", "type", ...})`, for example `{"type": "move", "entity_ids": [1], "target": [x, y]}`, or `attack` with `target_id`. Attacking a non-hostile target returns `"Invalid attack target"` (`simulation.gd` `_validate` → `Combat.valid_target`).
- **Supply sources** occupy a depot-sized 3×3 footprint; `add_supply_source(origin: Vector2i, boxes: int)` takes the top-left cell and a box count.
- **Retaliation** (`Combat._retaliate_trigger`) reads `shot.attacker_id` / `shot.target_id`; shot events are `{"type": "shot", "tick", "attacker_id", "target_id", "damage"}` (`combat.gd` 252).
- **Match.** `_survives(player)` (a builder, or a completed depot/barracks/factory) stays the per-seat rule. `_evaluate_match` sets `status` to `"won"` or `"draw"`, plus `winner` and `ended_tick`.
- **Bots.** `Skirmish._attack` and `_pick` already choose the nearest enemy by category across all enemy objects. M6 changes only the filters (`owner != ctx.player` → `Combat.hostile(...)`), with no new target logic.
- **Hash.** `StateHash.digest` = `state.hash()` plus `StateHash.core_check(state)`. A new snapshot field changes the first half only.
- **JSON.** `JSON.parse_string` returns every number as `float`. The loader converts cells to `Vector2i` and box counts to `int` explicitly; never compare a parsed number with `==` against an `int` without converting it.
- **Range code.** `Combat._reach_by_kind` caches reach per kind. `_firing_cell` scans a box of `reach` around the target, so with edge range that box must grow by `radius(attacker) + radius(target)`, or chases miss valid cells.
- **Profiling.** `game/scripts/debug/profiler.gd` (from the performance spike): `var t := Profiler.begin()` … `Profiler.end(&"zone", t)`, `Profiler.end_tick()` once per tick, `Profiler.report(label)`, `Profiler.calls(&"zone")`. Off by default; it never touches simulation state (`test_profiling_keeps_determinism`). `sh tools/run_profile.sh` prints `PROFILE <scenario> zone=… mean_ms=… p95=… max=…` lines. The spike merge added 3 cases / 8 checks (`test_profiler.gd`); that is not an M6 change.
- **Exported builds** may tokenize scripts, so a test must never read `.gd` source at runtime. Source scans belong in Python tool tests.

## Global Constraints

**Units.** One cell is 25 Zero Hour world units, and one tick is one Zero Hour logic frame (30 Hz). Speeds are in cells per second, accelerations in cells per second², turn rates in degrees per second.

**Map.** Wargrid name **Ashfall**, file `game/data/maps/ashfall.json`. Every map file has a `notice` string. Ashfall's notice names EA's copyright line and points to `game/data/maps/NOTICE.md`, which holds EA's additional terms, the source path `Zero Hour/Maps/official/Twilight Flame/Twilight Flame.map` and revision `3aad8e4`. Never write "Twilight Flame" in game-visible text.

**Map JSON keys:**
- `name`, `notice`, `size` `[w, h]`;
- `cells`: h strings of w chars (`.` open, `#` cliff, `~` water);
- `heights`: h arrays of w ints (mean world height ×10, rounded);
- `starts`: an array of `{seat, cell:[x,y], slots:{reactor,depot,barracks,factory:[x,y]}}`, where the builder spawns at `cell + 0.5`;
- `sources`: an array of `{origin:[x,y], boxes}`, where `origin` is the top-left cell of the 3×3 footprint centred on the EA object's cell, and boxes are a count.

**Resampling.** A cell is blocked when at least half of its area is cliff or water; a cell covers 2.5 × 2.5 Zero Hour samples, weighted by area. The border is dropped.

**Seats and teams.**
- `add_player(player, credits, controller, team)`: `team` ≥ 1, defaulting to `player`.
- `start_match` accepts 2–8 distinct seats with at least two teams.
- `hostile(a, b) = a != b and (team_of(a) == 0 or team_of(b) == 0 or team_of(a) != team_of(b))`. `team_of` is 0 without a player record, so record-less test owners keep today's `owner !=` behaviour.
- The match is `won` when exactly one team has a surviving seat, `draw` when none has. `match.winner` holds the winning team id, so the 1v1 (teams 1 and 2) keeps `winner == 1`.

**Combat values (Zero Hour values; INI read in Task 1, recorded there):**
- Range test: `Combat.edge_gap(unit, target) ≤ range − 0.1`, in cells, computed as `sqrt(centre distance²) − r_attacker − r_target` (never in squared form). A building's centre is `_victim_centre`, and its radius is half its footprint diagonal (Zero Hour's box rule).
- Edge distance replaces centre distance in every weapon-reach comparison: `_in_range`, `_within`, `_approach`, `_left_range`, `_firing_cell`, the chase-destination check, and the human in-range acquisition.
- Unchanged and centre-based: the AI scan radius (vision × modifier), retaliation distance and friends radius, leash, and every movement distance.
- `_nearest`'s grid search bounds grow by `radius(attacker) + max radius` so no candidate in edge range is skipped.
- Rifle: `delay_ticks` 4, `clip_size` 3, `reload_ticks` 22.
- Cannon splash: step function, no falloff, victims by `centre distance − r_victim`, mask from INI `RadiusDamageAffects`. The primary victim always takes primary damage.

**Movement.**
- Classes: `infantry` legs, `tank` treads, `builder` and `vehicle` wheels, `collector` air (unchanged, instant).
- Acceleration and braking (cells/s²): infantry 4 / 4, builder 1.2 / 2.0, tank 40 / 40 (INI 1000 u/s² for both, braking to confirm in Task 1; the first-frame lurch is not copied), vehicle from INI.
- Turn rates (°/s): infantry 500, tank 180, builder 90, vehicle from INI.
- **Start delay: 2 ticks added to today's gap.** Task 0 records today's gap `g` from a move command's tick to its first changed position (expected `g = 1`, giving the measured 3).
  - **Rule:** when a ground unit's status becomes `moving` (in `_assign_route`, when its route arrives) while `speed == 0`, set `move_after = sim.tick() + 2`, overwriting any earlier value.
  - **Effect:** the first snapshot with a changed position is exactly 2 snapshots after the first snapshot showing `moving`. This covers orders, chase starts (`Combat._approach`) and production exits alike.
- **Initial heading:** every unit spawns with `heading = [1, 0]`, production exits included (departure, recorded: Zero Hour exits face out of the door). When `desired` has zero length (the unit is exactly on a waypoint), the heading is kept and the factor is 1.
- **Float boundaries:** range and splash tests compare with `EDGE_EPS = 1e-6` cells (`gap ≤ reach + EDGE_EPS`), defined once in `combat.gd`. Boundary tests use exactly `max` (hit) and `max + 0.01` (miss).
- Treads turn in place when the error is ≥ 45°; the goal speed is `(1 − error/45°) × speed`. Wheels never turn in place. Legs turn in place.

**Determinism.** No `sin`, `cos`, `tan`, `atan`, `atan2`, `acos`, `asin`, `exp`, `log` or `pow` with a non-integer exponent anywhere in `game/scripts/simulation/` (Task 9 adds `tools/test_sim_math.py`, run in CI). Allowed: `+ − × ÷`, `sqrt`, comparisons. Angles come from `Locomotion.angle_between(a, b)` (algorithm in Task 9), and turn steps use per-kind `cos`/`sin` constants written as literals (computed once offline, printed with 17 significant digits).

**Values table.** Task 1 writes a section "Values table" in the verification file, one row per value: name, value in Wargrid units, Zero Hour value, INI file and block. Its rows are `radius.<kind>` for the five unit kinds, `accel.<kind>`, `brake.<kind>`, `turn.<kind>`, `min_turn_speed.vehicle`, `min_turn_speed.builder`, `cannon.primary_radius`, `cannon.secondary_radius`, `cannon.primary_damage`, `cannon.secondary_damage`, `cannon.affects`, `boxes.<template>` and `box_value`. Later tasks use these values and nothing else; a missing row is a stop.

**Measured ticks.** Tests assert the exact ticks that the rules below produce. The measured Zero Hour values (11, 24, 3 frames; 122, 183 units) must come out within ±1 of the rule; if one does not, stop and record it. Never tune a rule constant to hit a measured value.

**Snapshot fields added (exactly these):**
- `players[].team: int`, `players[].alive: bool`.
- Entity `heading: [x, y]` (unit vector; air units `[1, 0]`), `speed: float` (cells/s), `move_after: int` (tick).
- Shot events gain `splash: bool` (`false` for the direct hit). A splash victim gets its own shot event with the same `attacker_id`, its own `target_id` and `splash: true`.
- Anything further needs a design question.

**Assertions.** No budget, tolerance or assertion is relaxed.
- **Pins.** Tasks 3–5 move no pin except `H1 pinned digest` for new fields; `S1_CORE_SERIES` must stay unchanged through Task 5.
- **Tasks 6–11** re-pin provisionally every pin their own change moves, so each task ends with the suite green:
  - `TERMINAL_TICK`, `S1_CORE_SERIES`, `PINNED`, R4 and the other replay tests;
  - the netplay s1 tick in `tools/run_netplay.sh`;
  - the BM6 ceiling and floor.
- **Limits on a provisional re-pin.** It may never leave its window, and never changes any other assertion:
  - S1: 9000–10799 with winner 1;
  - netplay s1: no tick window, but the same winner as the base and inside the script's tick limit;
  - the BM6 floor stays below its measured value;
  - digests (`PINNED`, `S1_CORE_SERIES`, R4) have no window and move only with a recorded cause.
- **Record and confirm.** Each one is recorded as `test / assertion / old → new / cause task`. Task 12 confirms every final value against its window and cause, and the BM6 values need user approval there.
- Every other assertion change is recorded the same way.

**Out of scope:** big-map presentation, more than two online seats, bot logic changes (harness constants only), turrets and turn-to-aim, elevation effects on combat, trees and civilian buildings, air movement feel, new units.

## Review Focus

1. **The exported build cannot find the map JSON.** `export_filter="all_resources"` may skip `.json`. Expected: the exported suite loads both maps. Task 3, `test_maps_load` runs in the CI export job; add `include_filter="data/maps/*.json"` to every preset if it fails there.
2. **A short hop shorter than the braking distance.** Expected: the unit stops exactly on its destination, never overshoots or oscillates, and status becomes `arrived`. Task 8, `test_short_hop_no_overshoot`.
3. **A re-order while a unit is turning or braking.** Expected: the heading turns toward the new route from where it is, position never jumps, and the start delay applies again only from standstill. Task 9, `test_reorder_mid_turn`.
4. **Splash kills the last builder of a seat on the same tick its ally's last building falls.** Expected: the team is out that tick, and a team with one surviving seat stays in. Task 7, `test_splash_last_builder_same_tick`.
5. **A seat whose start has no free base slot or no supply near it.** Expected: the conversion fails, not the bot at tick 3000. Task 2, `test_every_start_has_slots_and_supply`.

## Task contracts

Format per the milestone prompt. Stop gates (fresh-context Opus review, then restart): after Tasks 1, 4, 7, 9, 11 and 14. Models per task: see Model routing. At the start of Tasks 2, 8 and 9, the Sonnet session first checks that every values-table row the task needs exists; a missing row is a stop.

---

### Task 0: Baseline and resume record

**Task:** record the starting tree.
**Owns:** `docs/reference/m6-verification.md`.
**Invariant:** the suite count matches the latest record (221 cases / 104,553 checks).
**Stop:** the counts differ and no record explains why.

- [ ] Create branch `m6-teams-map` from local `main`. Run `sh tools/run_tests.sh > <log> 2>&1` and read the summary lines.
- [ ] Create the verification file with the resume-record block. Record branch, base commit, counts and the current pins: `TERMINAL_TICK` 9938 (`test_skirmish_match.gd`), netplay s1 8423 (`tools/run_netplay.sh`), `PINNED` `15df35ca15bcc43b` (`test_state_hash.gd`), BM6 ceiling 15500 and floor 13000 (`test_benchmark.gd`). Also record today's gap from a move command's tick to the first changed position (one scratch run).
- [ ] Add `test_skirmish_core_series` to `test_skirmish_match.gd`. It runs the S1 script (same loop as `test_mirror_match_script`, one sim), folds `StateHash.core_check(sim.snapshot())` of every tick into one value (`h = (h * 31 + c) & 0x7fffffffffffffff`), and checks it against `const S1_CORE_SERIES: int` pinned on this tree. Green on the base tree. Tasks 3–5 keep it unchanged; Tasks 6–11 re-pin it provisionally.
- [ ] Add "Departures and deferrals":
  - cliff dilation not copied;
  - trees, civilian and tech buildings not converted;
  - Crusader first-frame lurch not copied;
  - turrets and turn-to-aim deferred;
  - air movement unchanged;
  - cadence 4/4/22 measured on the source build (VC6 unverified).
- [ ] Commit `Start M6 verification record`.

### Task 1: Risk spike and source values (scratch)

**Task:** measure the five risks before any task depends on them, and read the values Global Constraints still name as "from INI".
**Owns:** the session scratchpad, the verification file, `docs/reference/m6-map-and-feel.md`.
**Invariant:** the repo's `game/` and `tools/` are unchanged.
**Stop:**
- a scratch cost over twice its share of the dev-machine budget with no named candidate fix;
- the resampled map loses a route between neighbouring starts at the 50 % rule;
- `BlendTileData` cliff bits cannot be located.

- [ ] **Source and INI.** Read `BlendTileData` in `WorldHeightMap.cpp` and record where the cliff bits sit, per version. Read the Legs locomotor (`Locomotor.cpp` 1608+). With `tools/check_reference.py`'s `load_archive`/`read_big` on `INIZH.big`, read and record:
  - the geometry of Ranger, Crusader, Dozer, Humvee and the four structures;
  - the locomotors (speed, acceleration, braking, turn rate, min turn speed) of the same units;
  - the Crusader weapon's damage radii and `RadiusDamageAffects`;
  - `StartingBoxes` of every supply template on the map;
  - GameData `ValuePerSupplyBox`.

  Check the arithmetic in the evidence note against the real geometry, and add each value with its file and block to the evidence note.
- [ ] **Map decode.** A scratch Python decode of `Twilight Flame.map`. Record:
  - size, border and boundary;
  - the eight `Player_N_Start` positions;
  - every object template name and its count;
  - water polygons;
  - cliff share;
  - a 196×196-scale ASCII preview at the 50 % rule, with every start-to-start route reachable and its narrowest width.
- [ ] **Costs on a synthetic 196×196 map** with the scratch decode's blocked cells, measured with the existing benchmark timing helpers (`game/scripts/debug/timing_stats.gd`):
  - navigation build;
  - `route` from start to start;
  - `Allocation.assign` for 40 units;
  - `snapshot()`;
  - six `Skirmish.issue_opponent` calls on one decision tick (with seats faked by a scratch hostility patch);
  - `StateHash.digest`.
- [ ] **Determinism probe.** A scratch polynomial `angle_between` and a literal-constant rotation run 10,000 turns, then record the final heading's `var_to_str`. CI will compare across platforms in Task 9; here only record the error against `atan2` (≤ 0.1°).
- [ ] Record everything in the verification file with each cost against its budget share. **Stop gate: review, restart.**

### Task 2: Map converter and Ashfall data

**Task:** convert the EA map into Wargrid map data, failing on any lost route or unusable start.
**Owns:** `tools/zh_map/convert.py`, `tools/zh_map/refpack.py`, `tools/zh_map/test_zh_map.py`, `game/data/maps/ashfall.json`, `game/data/maps/NOTICE.md`, one CI line in the Linux job (`python3 tools/zh_map/test_zh_map.py`).
**Invariant:** CI never needs the EA checkout or `INIZH.big`; template box counts live in a table in `convert.py` with the INI source cited.
**Boundary:** chunk versions older than the file's (cliff fallback `maxZ − minZ > 9.8`).

**Interfaces:**
- Produces `refpack.decode(data: bytes) -> bytes`. Ported from `refdecode.cpp`, with a header comment naming the repo, revision `eb595cfc9`, the path, EA's copyright line and a pointer to the additional terms (AGENTS.md porting rule).
- Produces `convert.read_map(data: bytes) -> dict`:
  - keys `width, height, border, boundary, heights, cliff, water_polygons, objects`;
  - `heights` and `cliff` are per sample, row-major lists of `width × height` (int bytes, bools);
  - `water_polygons` is a list of `[(x, y), …]` in world units;
  - `objects` is a list of `{template, x, y, z, angle, flags, props}` (`props` is the decoded Dict).
- Produces `convert.resample(raw: dict) -> dict` with keys `size, cells, heights`.
- Produces `convert.place(grid: dict, raw: dict) -> dict` with keys `starts, sources`.
  - **Builder cell:** the start's cell.
  - **Slot search:** kinds in the order `reactor` 2×2, `depot` 3×3, `barracks` 2×2, `factory` 3×3. For each kind, try origins (top-left cell) at Chebyshev distance d = 2, 3, …, 12 from the builder cell; within a ring, y ascending, then x ascending.
  - **Accepting an origin:** the first origin wins when its footprint is inside the map and open, and its footprint grown by one cell on every side (clipped to the map) is open and covers no earlier slot's footprint, the builder cell, or any source footprint.
  - **Supply:** each start needs a source within 20 cells (Chebyshev) of the builder cell.
- CLI `python3 tools/zh_map/convert.py <map> <out.json>` exits 1 with the failing check named. It also prints the two report tables below; neither has a pass/fail tolerance (a threshold is a user decision).
- Produces `convert.route_matrix(passable: list[list[bool]], step_units: float, starts: list) -> dict`, mapping `(seat_a, seat_b)` to path length in world units. It uses 8-neighbour Dijkstra with diagonal cost √2 × step, with no corner cutting past a blocked orthogonal neighbour. It runs on the source grid (10 units: a sample is passable unless cliff or water) and on the resampled grid (25 units); the report prints both lengths and their ratio per pair.
- Produces `convert.start_metrics(grid: dict, placed: dict, matrix: dict) -> list`, one row per seat:
  - buildable open cells within Chebyshev 12 of the builder cell;
  - Chebyshev distance to the nearest source origin;
  - route length to every other start, from the resampled matrix.

- [ ] Red `test_refpack_literals_and_copies`: a hand-built stream with one literal run, one 2-byte, one 3-byte and one 4-byte copy decodes to the expected bytes.
- [ ] Red `test_chunks_roundtrip`: a synthetic raw `CkMp` file (TOC, `HeightMapData` v4 4×4 plus border 1, `ObjectsList` with `Player_1_Start` and `Player_2_Start` waypoints and one supply object) parses to the expected dict.
- [ ] Red `test_resample_half_rule`: on a 10×10-sample map (4×4 cells), cell (0,0) covers samples x, y in [0, 2.5). Sample (2, y) counts half its area.
  - Cliff samples covering exactly 3.125 of the cell's 6.25 sample areas → cell (0,0) blocked.
  - One whole sample fewer → open.
- [ ] Red `test_lost_route_fails`: on a synthetic map whose only ramp is 1 sample wide, the conversion fails with `route lost: 1-2`.
  - Every pair of starts must be connected.
  - Route widths are reported for each start and its two nearest other starts.
- [ ] Red `test_every_start_has_slots_and_supply` (Review Focus 5): a start boxed in by cliffs fails with `no slots: seat 3`; a start with no source within 20 cells fails with `no supply: seat 3`.
- [ ] Red `test_route_matrix_straight_and_diagonal`: on an open 20×20 grid with step 10, the route from (0,0) to (10,0) is 100 and to (10,10) is 100√2 (within 1e-9). With a wall at x = 5 that has one gap at y = 19, the route is longer than 100 and passes the gap.
- [ ] Red `test_start_metrics_rows`: a synthetic two-start map gives one row per seat with the expected buildable count, supply distance and route length.
- [ ] Implement until green. Run the converter on the real map. Record the route-width table, the route-length matrix (source vs resampled, ratio) and the per-start metrics in the verification file. Task 5 picks `TeamMatch.SEATS` with the per-start metrics in view. Commit the JSON and NOTICE. Commit `Convert the Ashfall map from EA's GPL map source`.

### Task 3: Map loader; the skirmish loads from data

**Task:** the simulation is built from a map file. The 1v1 skirmish uses `skirmish.json` and stays identical.
**Owns:** `game/scripts/simulation/map_data.gd` (new), `simulation.gd` (`_map` field and `map_data()` getter, not in the snapshot), `skirmish.gd` (`create`; `origin` becomes a one-line wrapper over `MapData.slot` on the skirmish map, so its ~15 test call sites stay untouched), `game/data/maps/skirmish.json`, `test_map.gd` (new, added to `run_tests.gd` `Suites`), `test_state_hash.gd` (re-pin only if needed).
**Invariant:** the S1 per-tick `core_check` series and outcome equal Task 0's record.
**Boundary:** a blocked cell under a start slot or a source is a load error.

**Interfaces:**
- Produces `MapData.load(path: String) -> Dictionary` (the parsed JSON, validated; returns `{}` and pushes an error on a bad file).
- Produces `MapData.create(map: Dictionary, seats: Array[Dictionary]) -> RefCounted`. A seat is `{seat:int, team:int, controller:String, credits:int}`. It builds the `Simulation` with the map's blocked cells and size, stores the map (`sim._map`), adds the players, spawns each seat's builder and adds every source. In 1v1 skirmish order (builders, then sources), ids stay as today.
- `MapData.create` never calls `start_match`; callers do (`Skirmish.create(with_match, …)` as today).
- Produces `Simulation.map_data() -> Dictionary` (`{}` for sims built without a map).
- Bots read slots through `map_data()`, so `issue_opponent(sim, player, attack_tick)` keeps its signature and every caller stays unchanged. `Skirmish.create` always attaches `skirmish.json`. On a sim with no map, the bot uses the skirmish map's slots (`Skirmish.origin`), exactly today's placement.
- Produces `MapData.slot(map: Dictionary, seat: int, kind: String) -> Vector2i`. It replaces `Skirmish.origin`.

- [ ] Red `test_maps_load` (Review Focus 1): both files load, `skirmish.json` is 48×32 with the seat-1 slots equal to today's `LEFT_ORIGINS` and the seat-2 slots equal to today's mirror, and Ashfall is 196×196 ±4 per side (exact size from Task 1).
- [ ] Red `test_bad_map_rejected`: a slot on a `#` cell gives `{}`.
- [ ] Red `test_skirmish_identical`: `Skirmish.create()` matches Task 0's S1 `core_check` series digest.
- [ ] Implement until green. Suite green. Commit `Load maps from data`.

### Task 4: Seats, teams and team victory

**Task:** up to eight seats in teams, with one hostility rule and team victory.
**Owns:** `simulation.gd` (`add_player`, `start_match`, `_evaluate_match`, `_player_snapshots`: `alive` = `_survives`), `combat.gd` (`valid_target` and every other `owner` hostility check → `hostile`; `_retaliate_trigger` and `_can_join` skip non-hostile attackers; the friends join check at `combat.gd` 318 stays owner-based, so only the victim's own units join, as in Zero Hour), `skirmish.gd` (enemy filters), `test_teams.gd` (new). `scripted_human.gd` stays as is (a 1v1 script on owners 1 and 2). `match.players` stays the list of seat ids.
**Invariant:** the 1v1 stays identical (`test_skirmish_identical`); netplay scenarios pass unchanged.

**Interfaces:**
- Produces `Combat.hostile(sim: RefCounted, a: int, b: int) -> bool`.
- Produces `Simulation.team_of(player: int) -> int` (0 when there is no record).

- [ ] Red `test_allies_never_target`: P1 and P3 share team 1 with guard infantry 2 cells apart. Over 120 ticks there is no target and no shot.
- [ ] Red `test_team_victory`: three teams, one seat each, each with only a builder. Kill a seat by `sim.remove_object(builder_id)`. After team 2's builder goes, the match is `ongoing`; after team 3's goes too, it is `won` with `winner == 1`.
- [ ] Red `test_same_tick_team_cases`:
  1. two allies hit one enemy on one tick, and both damage events land;
  2. retaliation never joins against an ally;
  3. an attack-move unit ignores allied buildings;
  4. the last seats of both remaining teams die on one tick, giving `draw`;
  5. an explicit `attack` on an ally is rejected (`Invalid attack target`).
- [ ] Red `test_start_match_validation`: one seat, nine seats, a duplicate seat and all seats on one team are each rejected.
- [ ] Implement until green. Re-pin `H1` for `team`/`alive` (record it). Run all nine `sh tools/run_netplay.sh` scenarios, which must pass unchanged. Commit `Add teams and team victory`. **Stop gate: review, restart.**

### Task 5: Bots on any map and the 3v3 harness

**Task:** every bot seat plays on map slots against the nearest hostile seat; a headless 3v3 runs to a team victory.
**Owns:** `skirmish.gd` (`issue_opponent` and `_build` read slots from `MapData.slot`; `_attack`, `_defend` and `_produce` filters use `Combat.hostile`), `game/benchmarks/run_team_match.gd` (new), `tools/run_team_match.sh` (new, modelled on `tools/run_benchmark.sh`), `test_team_match.gd` (new).
**Invariant:** the 1v1 stays identical. The policy's rules (build order, production, defence, attack after `ATTACK_TICK`) are unchanged in logic.
**Stop:** no team wins under the cap (`TEAM_TICK_CAP = 27000`, 15 minutes) after harness-constant tuning. Report it and let the user decide.

**Interfaces:**
- Produces `TeamMatch.SEATS: Array[Dictionary]`: six seats chosen from Task 1's starts, teams split by map half, coordinates listed in the verification file.
- `run_team_match.gd` prints `TEAM MATCH <won|draw|cap> tick=<n> winner=<team> units_peak=<n>` plus a per-tick timing summary. It exits non-zero on `cap`.

- [ ] Red `test_bot_never_targets_ally`: three seats (P1 bot team 1, P3 team 1, P2 team 2). After `ATTACK_TICK`, every `attack` P1 issues targets a P2 object, even when a P3 builder is nearer.
- [ ] Red `test_dead_seat_bot_is_silent`: a seat with no objects issues no commands and raises no error.
- [ ] Red `test_team_match_prefix`: the 3v3 on Ashfall for 3000 ticks is deterministic (two runs, equal digest every 30 ticks), every seat completes its four buildings, and at least one seat produces a tank. It also writes `WARGRID_TEAM_REPLAY_TRACE` when set, in the same row format as the `WARGRID_COMBAT_REPLAY_TRACE` writer in `test_replay.gd`. Add that env var and a `compare_replays.py` line for `team-*.tsv` to CI (Linux, Windows, export jobs and compare-replays).
- [ ] Implement until green. Run `sh tools/run_team_match.sh > <log> 2>&1` once on current mechanics and record the outcome and timing as the **baseline row** (no gate). Commit `Run 3v3 bot matches on Ashfall`.

### Task 6: Edge-to-edge range and Ranger cadence

**Task:** firing, acquisition, chase and firing-cell search use edge-to-edge distance. The rifle cycles 4/4/22.
**Owns:** `combat_definitions.gd` (`radius(kind) -> float`, rifle values), `combat.gd` (`distance_squared` callers, `_in_range`, `_firing_cell` including its scan box, `_nearest` grid radius, chase destination, `_reach_by_kind`), `test_combat.gd`.
**Invariant:** building distance stays measured to the footprint for movement. Only range tests subtract radii.
**Boundary:** exactly at `range − 0.1 + rA + rB` fires; 0.01 cells beyond does not.

**Interfaces:**
- Produces `CombatDefinitions.radius(kind: String) -> float` (cells, from Task 1's geometry; a building's radius is half its footprint diagonal).
- Produces `Combat.edge_gap(unit: Dictionary, target: Dictionary) -> float` (centre distance − both radii, not below 0).

- [ ] Red `test_ranger_fires_at_edge_max`: with `max = 4.0 − 0.1 + radius.infantry + radius.builder` (values table), a stationary Ranger fires at a Dozer at `max` cells centre to centre and not at `max + 0.01`. `max × 25` must lie within ±1 of the measured 122, else stop.
- [ ] Red `test_crusader_fires_at_edge_max`: the same with `6.0 − 0.1 + radius.tank + radius.builder` against the measured 183.
- [ ] Red `test_rifle_cycle_30`: the gaps between consecutive shots are 4, 4, 22, repeated.
- [ ] Red `test_firing_cell_uses_edge`: a chase toward a tank stops at the first cell inside edge range, not the centre range.
- [ ] Implement until green. Update the combat tests whose geometry encoded centre range (record each). Commit `Use edge-to-edge range and the measured rifle cadence`.

### Task 7: Tank splash

**Task:** cannon hits damage nearby objects per Zero Hour's step rule and mask.
**Owns:** `combat_definitions.gd` (cannon `primary_radius`, `secondary_radius`, `secondary_damage`, `affects`), `combat.gd` (`fire` damage application), `test_combat.gd`.
**Invariant:** the primary victim's damage is unchanged; splash goes through armour like a direct hit. Splash victims are ground units and buildings within the secondary radius, excluding the attacker and collectors (air, untargetable today), filtered by the `cannon.affects` mask: own and allied owners count as ALLIES, hostile as ENEMIES. Victims are processed in ascending id order.
**Boundary:** a victim exactly at the secondary radius edge (by `centre distance − r_victim`) is hit.

Damage per victim: within `cannon.primary_radius` (by `centre distance from the impact − r_victim`) it takes `primary_damage`, else within `secondary_radius` it takes `secondary_damage`. The impact is the target's position, or `_victim_centre` for a building. Splash shots feed `_retaliate_trigger` like any shot, which Task 4 limits to hostile attackers.

- [ ] Red `test_splash_cluster`: five P2 infantry in a row 0.6 cells apart (15 units), with no orders. One P1 Crusader 5 cells from the middle one fires one shell at it (explicit `attack`). Assert that exactly the infantry the radii cover take damage, with the expected amounts after armour, each with `splash: true`, and the middle one with `splash: false`. Record in the verification file how many splash hits per shell this implies, against the measured 9 hits in 30 shells.
- [ ] Red `test_splash_mask`: with the INI mask, own and allied infantry next to the target are damaged (if the mask excludes allies, they are not, and the test says which). The attacker itself is never damaged.
- [ ] Red `test_splash_last_builder_same_tick` (Review Focus 4).
- [ ] Red `test_splash_event_flag`: damage events carry `splash: true` only for secondary victims.
- [ ] Implement until green. Commit `Add Crusader splash damage`. **Stop gate: review, restart.**

### Task 8: Start delay, acceleration and braking

**Task:** ground units start 3 ticks after the command's tick, accelerate to speed and brake onto their destination.
**Owns:** `game/scripts/simulation/locomotion.gd` (new), `simulation.gd` (`_advance`, `_apply_orders` sets `move_after`, `spawn` fields), `economy_definitions.gd` (`accel`, `brake` per kind), `test_locomotion.gd` (new), and the movement, group and repath tests whose arrival ticks change (record each).
**Invariant:**
- M2 allocation and arrival contracts hold: same destinations, same slots, `arrived` exactly on the destination;
- `collector` moves exactly as today.
**Boundary:** a re-order while moving keeps the current speed (no new start delay); a re-order from standstill gets the delay.

**Interfaces:**
- Produces `Locomotion.step(unit: Dictionary, kind_def: Dictionary, tick: int) -> float`: the distance to travel this tick, after updating `unit.speed`. `_advance` uses it in place of `speed / 30.0`.
- Produces `Locomotion.braking_distance(speed: float, brake: float) -> float` = `speed² / (2 × brake)`.

**Per-tick rule (ground units, status `moving`), in this order:**
1. If `tick < unit.move_after`, return 0 (the unit may turn in Task 9, but does not move).
2. `remaining` = path length left along `unit.route` (sum of the segments from the position).
3. `cap` = the kind's speed × the heading factor (1 until Task 9).
4. `stoppable` = `sqrt(2 × brake × remaining)`, the highest speed that still stops by the destination.
5. `speed = min(speed + accel / 30, cap, stoppable)`.
6. Travel = `min(speed / 30, remaining)`. When `remaining − travel < 1e-5`, snap to the destination, set `speed = 0` and `arrived`. Because `stoppable > 0` whenever `remaining > 0`, the unit never stalls short and never overshoots.
7. The position still follows the route polyline exactly as today (`_advance`'s waypoint loop with `travel` in place of `speed / 30.0`).

**Status changes.** `speed` resets to 0 only on `idle`, `blocked`, `arrived` and on `stop`. `path_pending` keeps `speed` (a re-order or a chase repath does not restart the unit), and the unit does not move while pending. Halts set by `stop` and by attack-move engagement stay instant (no braking), recorded as a departure.

- [ ] Red `test_start_delay_three_ticks`:
  - For move, attack-move, chase (`attack` on a target 6 cells away) and production exit (first infantry from a barracks), the first snapshot with a changed position is exactly 2 snapshots after the first snapshot showing `moving`.
  - For move, it is also at the command tick + `g` + 2.
- [ ] Red `test_acceleration_curve`: on a long straight route, counting moving steps from `move_after`, a Ranger's `speed` is within 1e-9 of 0.8 after its 6th step and below 0.8 after its 5th; a Dozer's is within 1e-9 of 1.2 after its 30th step.
- [ ] Red `test_short_hop_no_overshoot` (Review Focus 2): a Dozer ordered 0.3 cells ends exactly on the destination, never beyond it on any tick, and becomes `arrived`.
- [ ] Red `test_group_arrival_unchanged`: the M2 group-to-slots test's final positions are unchanged; only the arrival ticks move.
- [ ] Implement until green. Commit `Add start delay, acceleration and braking`.

### Task 9: Heading and turning

**Task:** ground units have a heading and turn at their rate. Treads turn in place at ≥ 45°, wheels never do, legs do. The 48×32 view draws the heading.
**Owns:** `locomotion.gd` (`angle_between`, `turn`), `simulation.gd` (`_advance`), `economy_definitions.gd` (`turn_rate`, `turn_cos`, `turn_sin`, `locomotor` per kind), `world_view.gd` (heading mark), `test_locomotion.gd`, `test_view.gd`, `tools/test_sim_math.py` (new, plus one CI line: it scans `game/scripts/simulation/*.gd` for the banned calls as `\b(sin|cos|tan|atan2?|acos|asin|exp|log)\s*\(` and for `pow(` with a non-integer literal exponent).
**Invariant:** no banned function in the simulation; firing ignores heading; the position still follows the route polyline (heading never moves a unit off its route).

**`angle_between(a, b)`** (degrees, 0–180): with `x = a·b`, `y = |a×b|`, swap so that `z = min(x', y) / max(x', y)` lies in [0, 1] using absolute values. Then `t = z × (0.99997726 + z²(−0.33262347 + z²(0.19354346 + z²(−0.11643287 + z²(0.05265332 − 0.01172120 z²)))))`, unfolded to the octant and quadrant (y > |x| → 90° − t; x < 0 → 180° − t), × 57.295779513082323. The accuracy test is the arbiter, not these coefficients.

**`turn(heading, desired, c, s)`:** if `heading·desired ≥ c`, return `desired`. Otherwise rotate `heading` by ±step (sign of `heading × desired`, with 0 meaning +) using `c`, `s`, then normalize with `sqrt`.

**Per-tick rule, added to Task 8's:** each tick runs 1) turn, 2) factor, 3) Task 8 steps 1–7.
- `desired` = the direction to the next waypoint.
- While `path_pending` (no route yet), the heading is unchanged.
- Once `moving`, the heading turns every tick, including during the start delay.

The heading factor in Task 8 step 3, where `speed` is the kind's maximum speed and `min_turn_speed` comes from the values table (`min_turn_speed.builder` for the Dozer):
- treads: `max(0, 1 − angle_between/45)`;
- legs: 1 when `angle_between ≤ turn rate / 30` (one tick's turn), else 0;
- wheels: 1 when `angle_between ≤ 9`, else `max(min_turn_speed, speed / 4) / speed`;
- air: 1, and the heading snaps to `desired`.

Departure, recorded: wheels follow the route instead of arcing or reversing.

**Interfaces:**
- Produces `Locomotion.angle_between(a: Vector2, b: Vector2) -> float` (degrees, 0–180).
- Produces `Locomotion.turn(heading: Vector2, desired: Vector2, cos_step: float, sin_step: float) -> Vector2` (a unit vector, never past `desired`).
- Produces `Locomotion.heading_factor(locomotor: String, angle: float, kind_def: Dictionary) -> float` (the class factor below). `Locomotion.step` reads `unit.heading` and `unit.route[0]` itself, turns, calls `heading_factor`, then applies Task 8's steps.

- [ ] Red `test_angle_between_accuracy`: across 3600 directions the error against a precomputed table literal is ≤ 0.1°.
- [ ] Red `test_measured_turn_then_move`: for a 180° order, assert the rule-derived first-move tick for the Ranger, Crusader and Dozer (compute it by hand from the values table and write it into the test with the arithmetic in a comment). Each must lie within ±1 of the measured 11, 24 and 3, else stop (Global Constraints, measured ticks). The Dozer turns while driving.
- [ ] Red `test_heading_factors`:
  - `heading_factor("treads", 22.5, tank)` is 0.5, and at 45 it is 0;
  - `heading_factor("legs", 17, infantry)` is 0, and at 16 it is 1;
  - `heading_factor("wheels", 30, builder)` equals `max(min_turn_speed.builder, 1.2/4)/1.2`.
- [ ] Red `test_measured_turn_then_move` setup: spawn the unit (heading `[1, 0]`), then order a move to a point due west, which is a 180° turn.
- [ ] Red `test_reorder_mid_turn` (Review Focus 3).
- [ ] Red `tools/test_sim_math.py`: a fixture string with `cos(` fails the scan; the real simulation directory passes.
- [ ] Red `test_heading_mark_layout`: add `WorldView.heading_marks() -> Array[Dictionary]` (`{id, from: Vector2, to: Vector2}` in screen space), which `_draw` also uses. Assert one mark per ground unit, both ends inside the unit's drawn rectangle, and none for a collector.
- [ ] Implement until green. Commit `Add heading and Zero Hour turning`. **Stop gate: review, restart.**

### Task 10: Chinook supply scenario

**Task:** the parity harness measures a full Chinook supply trip. The M3 collector timing goes on the decision list.
**Owns:** `tools/zh_parity/parity.py` (scenario `chinook_supply`), `docs/reference/zero-hour-parity-spike.md`, the verification file.
**Invariant:** no Wargrid value changes here.
**Stop:** the fix needs a change to the fork (`../GeneralsGameCode-macOS`). Ask before touching it.

- [ ] Make the harness complete the supply centre's construction (the `onBuildComplete` cause in the evidence note) through an existing harness command if one exists. Otherwise stop.
- [ ] Run headless and silent (`-headless -noaudio`). Record load time, flight time, deposit amount and money per trip against M3's 8 × 75 per trip and 6 cells/s.
- [ ] Add the comparison to the spike's decision list. Commit `Measure the Chinook supply trip`.

### Task 11: Measure and scale

**Task:** measure the 3v3, then apply eight fixes that were measured and approved up front (11a–11h). Each keeps every trace identical. Re-measure and report each row against its budget.
**Source:** [performance spike](../../reference/performance-spike.md) and Task 1's Ashfall costs in the verification file. User approvals (2026-11-05): incremental navigation (11c), cached map lists (11d), shared bot snapshot (11e). The other five are replay-safe local changes.
**Owns:** `destination_allocation.gd`, `grid_navigation.gd`, `construction.gd` (`preview`), `simulation.gd` (`_replace_union`, `_terrain_snapshot`, counters), `skirmish.gd` (`issue_opponents`), `economy_definitions.gd` and `combat_definitions.gd` (lookup tables), `world_view.gd` (`set_state`), `main.gd` / `base_main.gd` (`_refresh`), `run_team_match.gd` (profiler hook), new `test_allocation.gd` and `test_navigation_incremental.gd` (both added to `Suites`), the tests named below, the verification file.
**Invariant:** after every sub-task, all of these are identical to the start of Task 11: `S1_CORE_SERIES`, `TERMINAL_TICK`, `PINNED`, every replay test, the netplay s1 tick, BM6, and the team-match fold recorded in 11.0. No budget changes.
**Allowed assertion changes (record each as `test / assertion / old → new / 11x`):**
- Cn8 counts (11c);
- V1 "set_state copies" (11g);
- a test that writes into a snapshot's `map` or `terrain_cells` lists gets `.duplicate(true)` first (11d).

**Stop:**
- `game/scripts/debug/profiler.gd` or `tools/run_profile.sh` is missing (the spike is not merged).
- An invariant value changes in a sub-task. Revert that sub-task's files (`git checkout -- <files>`), record what changed, and stop.
- An equivalence test (AL1, NI1, VW2) fails with the code as specified. Never edit the reference copy to make it pass.
- Any other failing assertion.
- A row still exceeds its budget after 11h (report it; the user decides).

Commands: run every suite or benchmark with output to a file and read only summary lines (`CASES`, `TESTS PASSED`, `PROFILE COMPLETE`, failing lines). Commit each sub-task on its own with the message given.

- [ ] **11.0 Baseline.**
  1. In `run_team_match.gd`: set `Profiler.reset()` and `Profiler.enabled = true` before tick 0, and call `Profiler.end_tick()` after every `step()`. At tick 300, and again at the end, print the report the way `run_profile.gd` `_phase()` does: `Profiler.report(label)` lines, the 10 slowest `Profiler.slow` lines, and the slow count, with labels `team_match.warmup` and `team_match`, then `Profiler.reset()`. Disable the profiler at the end.
  2. Write a scratch fold of the team match: the same loop as the harness, folding `StateHash.core_check(sim.snapshot())` of every tick with `h = (h * 31 + c) & 0x7fffffffffffffff`. Record the fold value and the terminal tick as the **team-match fold**.
  3. Run `sh tools/run_team_match.sh`, `sh tools/run_profile.sh` and `sh tools/run_benchmark.sh`. Record in the verification file, per log:
     - `step` p50/p95/p99/max;
     - the top 8 zones by `mean_ms`;
     - the 5 slowest calls;
     - for `team_match.warmup` and `team_match`, the max of `allocation.assign`, `navigation.build`, `navigation.replace`, `opponent.decide` and `snapshot`.
  4. Commit `Profile the team match`.

- [ ] **11a Allocation by rings** (largest spike: 85 ms per 40-unit order on Ashfall).
  - Add `func size() -> Vector2i: return _map_size` to `grid_navigation.gd`.
  - Copy today's `assign`, `_before`, `_assign_by_scan` and `SCAN_MAX_UNITS` unchanged into `test_allocation.gd` as `_ref_assign`, `_ref_before`, `_ref_assign_by_scan` and `REF_SCAN_MAX_UNITS`. Rename only the references between them.
  - Red **AL1** `test_rings_match_reference`:
    - `RandomNumberGenerator` with `seed = 11`, 300 cases. Per case:
      - map `rng.randi_range(8, 40)` × `rng.randi_range(8, 40)`;
      - each cell blocked with `rng.randf() < 0.25`;
      - a unit count from `[1, 2, 5, 8, 9, 20, 60]` (`rng.randi_range(0, 6)`);
      - units `{"id": i + 1, "position": [cx + 0.5, cy + 0.5]}` on random open cells (repeats allowed);
      - `target = Vector2(rng.randf_range(0, w), rng.randf_range(0, h))`;
      - 0–10 random `unavailable` cells.
    - Check `Allocation.assign(...) == _ref_assign(...)` for every case.
    - Also check that at least 30 cases have a non-empty result, and at least 30 cases have a target on a blocked cell.
  - Replace `assign` and delete `_assign_by_scan` and `SCAN_MAX_UNITS`. The `allocation.sort` zone goes away with the sort; the `allocation.assign` zone in `simulation.gd` stays. New code (keep `_before` as it is):

    ```gdscript
    static var last_cells_examined: int = 0

    static func assign(navigation: RefCounted, units: Array[Dictionary], target: Vector2, unavailable: Array[Vector2i]) -> Dictionary:
    	# … ordered, goals, occupants exactly as today …
    	last_cells_examined = 0
    	var component: int = navigation.component_at(target)
    	if component < 0:
    		return goals
    	var excluded: Dictionary = {}
    	for cell in unavailable:
    		excluded[cell] = true
    	var target_cell := Vector2i(target.floor())
    	var max_radius: int = maxi(navigation.size().x, navigation.size().y)
    	var pool: Array[Vector2i] = []
    	var radius: int = -1
    	for unit in ordered:
    		if navigation.component_at(Vector2(unit.position[0], unit.position[1])) != component:
    			continue
    		var index: int = 0
    		var chosen: Variant = null
    		while chosen == null:
    			if index < pool.size() and (radius >= max_radius or _settled(pool[index], target, target_cell, radius)):
    				var cell: Vector2i = pool[index]
    				if occupants.has(cell) and (occupants[cell].size() != 1 or not occupants[cell].has(unit.id)):
    					index += 1
    				else:
    					chosen = cell
    			elif radius < max_radius:
    				radius += 1
    				_add_ring(navigation, component, excluded, target_cell, radius, pool)
    				# shortcut: re-sorts the whole pool per ring; fine while pools stay small (AL2), switch to a merge if a profile shows it.
    				pool.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _before(a, b, target, target_cell))
    			else:
    				break
    		if chosen == null:
    			continue
    		pool.remove_at(index)
    		goals[unit.id] = target if chosen == target_cell else Vector2(chosen) + Vector2(0.5, 0.5)
    	return goals

    # Every cell in Chebyshev ring r + 1 lies at least r + 0.5 from a target inside the target cell.
    static func _settled(cell: Vector2i, target: Vector2, target_cell: Vector2i, radius: int) -> bool:
    	return cell == target_cell or (Vector2(cell) + Vector2(0.5, 0.5)).distance_squared_to(target) < (radius + 0.5) * (radius + 0.5)

    static func _add_ring(navigation: RefCounted, component: int, excluded: Dictionary, center: Vector2i, radius: int, pool: Array[Vector2i]) -> void:
    	if radius == 0:
    		_try_cell(navigation, component, excluded, center, pool)
    		return
    	for x in range(center.x - radius, center.x + radius + 1):
    		_try_cell(navigation, component, excluded, Vector2i(x, center.y - radius), pool)
    		_try_cell(navigation, component, excluded, Vector2i(x, center.y + radius), pool)
    	for y in range(center.y - radius + 1, center.y + radius):
    		_try_cell(navigation, component, excluded, Vector2i(center.x - radius, y), pool)
    		_try_cell(navigation, component, excluded, Vector2i(center.x + radius, y), pool)

    static func _try_cell(navigation: RefCounted, component: int, excluded: Dictionary, cell: Vector2i, pool: Array[Vector2i]) -> void:
    	last_cells_examined += 1
    	if navigation.component_at(Vector2(cell) + Vector2(0.5, 0.5)) == component and not excluded.has(cell):
    		pool.append(cell)
    ```

  - Red **AL2** `test_ring_work_ceiling`: a 196×196 open map, 60 units at x 5–14, y 95–100, target `(150.5, 98.5)`. Check `Allocation.last_cells_examined <= CEILING` and that every unit got a goal. Pin `CEILING` to the measured value. Record it.
  - Green: AL1, AL2, the full suite, the invariant values.
  - Measure with `sh tools/run_profile.sh` the `large_196.warmup` max of `allocation.assign` (the spike measured 566 ms; expected under 5 ms, an estimate). Record it.
  - Commit `Allocate destinations by rings`.

- [ ] **11b Component lists without a comparator sort** (about 44 of the 70 ms per rebuild at 196×196).
  - In `grid_navigation.gd` `_rebuild_component_cells`:
    - Label cells with the same flood fill, but use a reused local `queue: Array[Vector2i]` (`clear()` per seed) instead of the per-component `cells` list.
    - Count the components.
    - After labelling, append one empty `Array[Vector2i]` per component to `_component_cells`. Then walk `y` and then `x` in row-major order and append each open cell to `_component_cells[label]`.
    - Delete the `cells.sort_custom` line.
  - N7 (row-major order) must stay green unchanged.
  - Measure `navigation.components` max in `large_196` and record before → after.
  - Commit `Build component lists in row order`.

- [ ] **11c Incremental navigation** (approved). It targets the 420 ms opening tick of six bot previews and the 65 ms per placement or death on Ashfall. Rule: blocking one rectangle cannot change connectivity outside it when the open cells on its surrounding ring form at most one unbroken arc. Freeing one rectangle cannot merge components when all open cells 4-adjacent to it carry one label. Every other change does today's full rebuild.
  - In `grid_navigation.gd`:
    - `_is_rectangle(cells) -> bool`: true when `cells` is non-empty and its bounding box area equals `cells.size()` (cells are unique after `_normalize`).
    - `_open(cell) -> bool`: `_grid.region.has_point(cell) and not _grid.is_point_solid(cell)`.
    - `_ring(min_c, max_c) -> Array[Vector2i]`: the cells of the box `min_c − 1 … max_c + 1` border, in cyclic order:
      1. top row, left to right, from `(min.x−1, min.y−1)` to `(max.x+1, min.y−1)`;
      2. right column, top to bottom, `y = min.y … max.y+1`;
      3. bottom row, right to left, `x = max.x … min.x−1`;
      4. left column, bottom to top, `y = max.y … min.y`.
    - `_ring_arcs(cells) -> int`: over `_ring(...)` of the bounding box, the number of positions `i` where `_open(ring[i])` and not `_open(ring[i − 1])` (cyclic). Return 1 when every ring cell is open.
    - `blocks_locally(cells: Array[Vector2i]) -> bool`: `_is_rectangle(cells)`, every cell `_open`, and `_ring_arcs(cells) <= 1`.
    - `replace_blocked_cells(cells) -> String` returns `"none"`, `"local"` or `"full"`. Keep its `navigation.replace` zone around the whole body and end it before every `return`:
      - Normalize the cells. If the result equals `_blocked`, return `"none"`.
      - Build `added` (in new, not old) and `removed` (in old, not new) through Dictionaries.
      - If `removed` is empty and `blocks_locally(added)`: for each added cell, `set_point_solid(cell, true)`, `_component_cells[label].erase(cell)` and set the label to −1.
      - Else, if `added` is empty and `_is_rectangle(removed)`: collect the labels of open cells 4-adjacent to the rectangle and outside it. If there is exactly one label: for each removed cell, `set_point_solid(cell, false)`, set the label, and insert the cell into `_component_cells[label]` at `bsearch_custom(cell, _cell_before)`.
      - On either local path, set `_blocked = normalized`, invalidate the 11d cache once it exists, and return `"local"`. Otherwise call `_apply_blocked(normalized)` and return `"full"`.
  - In `simulation.gd`:
    - Add `var _navigation_local: int` and `func navigation_local_updates() -> int`.
    - `_replace_union` without `prebuilt`: `var how: String = _navigation.replace_blocked_cells(cells)`; on `"full"` do `_navigation_builds += 1`, on `"local"` do `_navigation_local += 1`, on `"none"` neither. The rest (snapshot compare and requeue) stays.
  - In `construction.gd` `preview`: when `sim._navigation.blocks_locally(footprint)`, set `result.navigation = null` and compute `result.approach` with `sim._navigation`, with no build and no counter. Otherwise keep today's full build. `place` stays as is: a `null` prebuilt goes through `_replace_union`'s local path.
  - Red **NI1** `test_incremental_matches_rebuild`:
    - Seed 23, 40 maps of 12–40 per side, blocked with p = 0.2.
    - Per map, 30 operations: block a random 2×2 or 3×3 rectangle that is fully open, or free a rectangle this test blocked earlier. Each one goes through `replace_blocked_cells` on one long-lived `Navigation`.
    - After each operation, compare with `Navigation.new(same cells, size)`:
      - `snapshot()` is equal;
      - for every cell, `cells_in_component(component_at(c))` is equal (same partition and same row-major lists; labels may differ);
      - `route` is equal for 10 random open pairs.
    - Check that both `"local"` and `"full"` occurred at least 50 times each.
  - Rewrite **Cn8** (`test_build_navigation_cost`, allowed change): an open-ground build causes 0 full builds at issue and at placement, and `navigation_local_updates()` is +1 after placement. Keep "reused grid equals a rebuilt one".
  - Red **NI2** `test_pinch_build_falls_back`:
    - Start from `Fixture.make_world()` (32×32, builder 1 at `(4.5, 4.5)`).
    - Add a wall with `sim.replace_blocked_cells` at x = 10 for every y except y 4–5.
    - `place(sim, [10, 4])` (a 2×2 reactor that closes the gap; its ring has two open arcs). Check that the issue-time check counts exactly 1 full build (`navigation_builds()` +1).
    - Check that the command result and the building's `approach` after one `step()` equal today's. Run the test on today's code first and write those values in.
  - Red **NI3** `test_death_updates_locally`: removing a building on open ground gives `navigation_local_updates()` +1, no full build, and `snapshot().map` equal to a rebuilt simulation's.
  - Green: NI1–NI3, Cn8, Bs6 (stays green unchanged), the full suite, the invariant values.
  - Record `opponent.decide` and `navigation.*` max in `team_match.warmup`, before → after.
  - Commit `Update navigation in place around one footprint`.

- [ ] **11d Cached map lists** (approved; 0.47 of 0.74 ms per snapshot on Ashfall).
  - `GridNavigation.snapshot()` builds `{"size", "blocked_cells"}` once into `_snapshot_cache` and returns that same Dictionary. Before returning it, call `make_read_only()` on every inner `[x, y]` array, then on the `blocked_cells` and `size` arrays, then on the Dictionary.
  - Clear `_snapshot_cache = {}` in `_apply_blocked` and on both local paths of 11c.
  - `Simulation._terrain_snapshot()` caches the same way in `_terrain_cache`. Clear it wherever `_terrain_cells` changes (`_init`, `replace_blocked_cells`; `rg -n '_terrain_cells' game/scripts/simulation` must show no other writer).
  - Red **SM1** `test_map_lists_shared_read_only`:
    - two `snapshot()` calls return `is_same` `map.blocked_cells` and `is_same` `terrain_cells`, and both are `is_read_only()`;
    - after a placement, `snapshot().map` equals a rebuilt simulation's.
  - `PINNED` and every replay test must pass unchanged. That is the hash check.
  - A test that writes into those lists fails with a read-only error: give it `.duplicate(true)` (allowed change). A non-test writer is a stop.
  - Commit `Share read-only map lists across snapshots`.

- [ ] **11e Shared bot snapshot** (approved; about 4.5 ms of the 8.85 ms attack tick).
  - `skirmish.gd`:
    - Add `static func issue_opponents(sim: RefCounted, players: Array[int], attack_tick: int = ATTACK_TICK) -> void`: return unless `sim.tick() % DECISION_TICKS == 0`; then, inside one `opponent.decide` zone that covers the snapshot and the loop, take one `state := sim.snapshot()` and call `_decide(sim, player, attack_tick, state)` for each player in the given order.
    - `_decide` takes `state` as a parameter instead of taking its own snapshot.
    - `issue_opponent(sim, player, attack_tick)` becomes `issue_opponents(sim, [player], attack_tick)`.
  - Every place that calls `issue_opponent` for several seats on the same tick (`rg -n 'issue_opponent' game`) switches to one `issue_opponents` call with the same seats in the same order.
  - Green: the team-match fold and terminal tick equal 11.0's, the full suite, the invariant values. If the fold differs, revert 11e, record it as "rejected: changes the trace", and continue with 11f (this one case is not a stop).
  - Record the `opponent.decide` max in `team_match`.
  - Commit `Share one snapshot across bot decisions`.

- [ ] **11f Definition lookups without allocation** (`advance` is 72 % of a movement tick).
  - In `economy_definitions.gd` and `combat_definitions.gd`, turn each `match kind:` lookup that returns a Dictionary literal (`unit`, `building`, `profile`, `weapon`, and any per-kind lookup Tasks 6–9 added that returns a Dictionary) into a `const` table keyed by kind, holding the identical literals.
    - A shared arm such as `"depot", "factory"` becomes two keys with the same literal.
    - The function becomes `return TABLE.get(kind, {})`.
    - Functions that return a number stay as they are.
    - `CombatDefinitions.initial_combat` stays as it is: it builds a fresh per-unit record that the simulation mutates.
  - Red **DF1** `test_definitions_shared`: `is_same(Definitions.unit("tank"), Definitions.unit("tank"))`, `is_same(CombatDefinitions.weapon("rifle"), CombatDefinitions.weapon("rifle"))`, and unknown kinds return empty.
  - A read-only error from a caller that writes into a definition is a stop.
  - Record `step.advance` mean in `movement_open`, before → after.
  - Commit `Serve definitions from constant tables`.

- [ ] **11g View without a deep copy; depth sort on packed keys** (view copy 0.70 ms and sort 0.59 ms per tick at 300 units).
  - In `world_view.gd` `set_state`:
    - `_state = state.duplicate()` (shallow);
    - if `_state.has("entities")`, `_state.entities = _depth_sorted(state.entities)`;
    - delete `_draw_before` and keep the profiler zones;
    - add `const DEPTH_SCALE := 1024.0`, `const INDEX_BITS := 20`, `const INDEX_MASK := (1 << 20) - 1`.

    ```gdscript
    # Input is in id order (snapshot order), so equal depths keep id order like the old comparator.
    func _depth_sorted(entities: Array) -> Array:
    	assert(entities.size() <= INDEX_MASK)
    	var keys := PackedInt64Array()
    	keys.resize(entities.size())
    	for i in range(entities.size()):
    		var unit: Dictionary = entities[i]
    		keys[i] = (int(floor((float(unit.position[0]) + float(unit.position[1])) * DEPTH_SCALE)) << INDEX_BITS) | i
    	keys.sort()
    	var sorted: Array = []
    	sorted.resize(entities.size())
    	for i in range(keys.size()):
    		sorted[i] = entities[keys[i] & INDEX_MASK]
    	return sorted
    ```

  - Rewrite **V1** (allowed change): delete the line that writes `state.entities[0].position[0]` and keep `state.entities.clear()`. The message becomes `"V1 set_state keeps its own entity list"`.
  - Red **VW2** `test_depth_order_matches_comparator`: take the 300-unit `MovementWorkload.create("open")` after 40 steps. Check that the view's entity id order equals a `sort_custom` with today's `_draw_before`, copied into the test.
  - V2 and every skirmish-scene view test stay green unchanged.
  - Record `view.copy` and `view.sort` mean in `movement_open`, before → after.
  - Commit `Hand the snapshot to the view without copying`.

- [ ] **11h One snapshot per refresh.**
  - `main.gd`: `_refresh()` becomes `_show(simulation.snapshot())`, and the old body moves into `func _show(state: Dictionary) -> void`.
  - `base_main.gd` `_refresh()`: take one `state`, run the selected-building check on it, call `_show(state)` instead of `super._refresh()`, then the Economy line.
  - Red **RF1** in `test_base_scene.gd`: with a building selected, `Profiler.reset()`, `Profiler.enabled = true`, one `main._refresh()`, then `Profiler.calls(&"snapshot") == 1`. Disable and reset the profiler afterwards.
  - Commit `Take one snapshot per refresh`.

- [ ] **11.9 Re-measure.** Rerun the three commands of 11.0. In the verification file, write one table: row, before → after, budget, status. The rows:
  - team-match `step` p95 and p99 (budgets 1.67 and 3.3);
  - team-match warm-up max;
  - `opponent.decide` max;
  - movement plumbing, which is `snapshot + view.copy + view.sort` mean in `movement_open` (budget 0.83);
  - `large_196` warm-up max;
  - every benchmark p95.

  Mark any row over budget **exceeded**; never loosen a budget. Presentation changed (11g), so Task 13's rendered rerun is required.
- [ ] Record the deferred items, all not approved:
  - static terrain as one batch: the spike measured about 5 fps at 196×196, but big-map presentation is out of M6 scope;
  - persistent combat bins;
  - presentation reading live state;
  - struct-of-arrays entities.

  **Stop gate: review, restart.**

### Task 12: Confirm final pins

**Task:** every pin re-pinned provisionally in Tasks 6–11 is confirmed on the final tree, with one row per pin: base value → final value and the cause tasks.
**Owns:** `test_skirmish_match.gd` (`TERMINAL_TICK`, `S1_CORE_SERIES`, `WINNER` must stay 1), `tools/run_netplay.sh` (s1, base 8423), `test_state_hash.gd` (`PINNED`), `test_replay.gd`, `test_benchmark.gd` (BM6, user approval at the Task 13 stop).
**Invariant:** S1 stays inside its 9000–10799 window with winner 1; a pin outside its window is a stop, not a re-pin.

- [ ] Run each pinned test and the nine netplay scenarios on the final tree. Write the consolidated table (base → final, cause tasks) into the verification file.
- [ ] Commit `Confirm M6 pins` (only the table, unless a pin still needs its final value).

### Task 13: Benchmarks and ledger

**Task:** benchmark and ledger rows for the final tree.
**Owns:** `docs/reference/performance.md`, the verification file.
**Stop:** any budget exceeded; the BM6 re-pin needs user approval here.

- [ ] Run `sh tools/run_benchmark.sh > <log> 2>&1` and read the summary lines.
- [ ] Ask the user, in one request, for the rendered rerun (`sh tools/run_game.sh res://scenes/movement_benchmark.tscn`), the BM6 re-pin and the heading-mark look.
- [ ] Add the ledger rows: benchmark, rendered rerun, and the 3v3 rows from Task 11 with units peak and mean. Commit `Record M6 ledger rows`.

### Task 14: Exit gate

- [ ] Run the milestone-prompt exit gate on the final tree:
  - full suite;
  - benchmark;
  - rendered rerun;
  - CI on Linux and Windows, including the team trace;
  - `sh tools/compare_local_traces.sh <run id>`;
  - one substantive Opus review;
  - `/ponytail-review`.
- [ ] Update README status, blueprint §7 M6 status and the verification file. Report implemented, verified and pending separately. **Stop gate: user playtest of the 1v1 feel (the only playable view) and merge approval.**
