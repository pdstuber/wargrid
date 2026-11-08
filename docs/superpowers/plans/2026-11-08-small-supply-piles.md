# Small Supply Piles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each Zero Hour `SupplyPileSmall` on Dry Wells becomes its own 50-box, 1 × 1 source that is removed in the step that takes its last box.

**Architecture:** A source record and a map source entry may carry `footprint: [w, h]` and `delete_when_empty: true`; both keys exist only on non-default sources. One lookup, `Registry.source_footprint(source)`, replaces every source use of `SOURCE_FOOTPRINT` in simulation, loader, construction, docking and view. The supply step calls the existing `remove_object` when a `delete_when_empty` source hands over its last box; the converter emits piles as such sources and Dry Wells is regenerated.

**Tech Stack:** Godot 4.7, typed GDScript (`game/`), Python 3 converter (`tools/zh_map/`).

**Spec:** [docs/superpowers/specs/2026-11-08-small-supply-piles-design.md](../specs/2026-11-08-small-supply-piles-design.md). Context: [more maps](../../reference/more-maps.md), [M7 economy parity](../../reference/m7-economy-parity.md).

Status: **planned, not started** (2026-11-08, branch `spike-more-maps` at `a55dcef`). Small task, not a milestone.

## Global Constraints

- `footprint` and `delete_when_empty` keys exist only on non-default sources (sim records, snapshots, map JSON). Absent `footprint` means `Registry.SOURCE_FOOTPRINT` (4 × 5); absent `delete_when_empty` means false.
- Small pile: 50 boxes, footprint 1 × 1, `delete_when_empty: true`. Docks: 400 boxes, 4 × 5, never removed, record shape unchanged.
- Unchanged: `skirmish.json`, `ashfall.json`, `broken_crown.json`, every pin and replay trace, every benchmark and budget. Never loosen a budget or change an expected value to pass.
- No faction branches in simulation code. One active collector per source; dock cells are the footprint's one-cell ring.
- Supply-center `supply_clearance` is measured from each source's own footprint; every source is tested, not only the nearest.
- Typed GDScript in `game/scripts` (tests exempt from `untyped_declaration` only). Comments: one line, why only.
- Suite: `sh tools/run_tests.sh > FILE 2>&1` with Bash `timeout: 600000`, then read only `rg -n '^(CASES|TESTS PASSED|FAIL)|SCRIPT ERROR' FILE`. Same timeout for lint, warnings and benchmark. Output files go to the scratchpad, not the repo.
- New test cases are added to their suite's `cases()` list, or the runner never calls them.
- Commits: the coordinator commits locally (or allows the implementer to); never push. Messages are given per task.
- No EA data copied; the converter keeps citing `object/civilianbuilding.ini` (INIZH.big) for box counts.

## Review Focus

1. A collector whose cargo fills on the pile's last box (China truck, capacity 4, pile of 4) leaves at once with all 4 boxes and delivers 300 credits; no box lost, no dock left held. Test: Task 3 `test_small_pile_removed_with_last_box` (ground part).
2. A malformed map footprint (`[0, 1]`, `[1]`, `"1x1"`, `[1.5, 1]`) or a non-bool `delete_when_empty` rejects the map instead of crashing the loader. Test: Task 2 `test_small_source_from_map`.
3. Overlapping sources are dropped silently at load (`add_supply_source` returns -1 and `MapData.create` ignores it), so a converter overlap must fail loudly. Tests: Task 5 `test_overlapping_sources_fail` and MP6 counting 16 sources in the simulation, not only in the file.
4. A ground unit walking near the pile when it vanishes (navigation is rebuilt inside the supply step and every moving ground unit is re-pathed, as on a building death) still reaches its move target. Test: Task 3 `test_waiters_reseek_when_small_pile_vanishes` (the mover).
5. A pile that vanishes while selected leaves the view drawable and pick-safe. Test: Task 4 `test_small_pile_view` (selected removed pile).

## Decisions this plan makes (the design left them open)

- Shared lookup: `static func source_footprint(source: Dictionary) -> Vector2i` in `definitions.gd` (Registry), used by sim, loader and view alike; it reads JSON floats too.
- `add_supply_source(origin, boxes, footprint := Registry.SOURCE_FOOTPRINT, delete_when_empty := false)`; a footprint below 1 × 1 returns -1.
- The collector that takes the last box skips Zero Hour's extra trailing delay (Wargrid's `Gt2`/`Gd11` rule) because the pile is gone in that step: Zero Hour's `action()` returns FALSE right after `destroyObject` (`SupplyWarehouseDockUpdate.cpp:118-121`), so the dock ends at once there too. It goes `seeking` next tick with its cargo, like every collector whose source disappears.
- `preferred_source_id` is not cleared on removal: `choose_target` already ignores a missing id and ids are never reused.
- Bots: `skirmish.gd` never names a source (`"gather"` is sent only by `base_main.gd` and `debug/combat_workload.gd`); bot collectors seek automatically through `Supply.choose_target`, so the bot case is the re-seek test plus the scratch bot run.
- Labels: pile label positions use only the origin and stay as they are. Two label lines per pile on piles 1.3 cells apart will overlap; reported as a playtest item, not changed here.
- Converter: `BOXES` becomes `SOURCES` (boxes, footprint, delete flag per template); overlapping sources raise `ConvertError("sources overlap")`. The `SUPPLY_REACH` check keeps its `origin + 1` centre estimate (docks satisfy it on every map).
- No performance-ledger row and no rendered rerun: no benchmark workload contains a small pile; `sh tools/run_benchmark.sh` still has to pass. Rendered frame time on Dry Wells stays "not re-measured" (needs a window, ask first).

## Pins and traces that prove "unchanged"

Run in every task's full suite, never edited: `test_state_hash.gd` `test_pinned_digest` (`PINNED`), `test_skirmish_match.gd` `test_skirmish_core_series` (`S1_CORE_SERIES`) and the three match scripts, `test_team_match.gd` `test_team_match_prefix` (`FINAL_DIGEST`, Ashfall) and `test_team_core_series` (`TEAM_CORE_SERIES`), `test_replay.gd` `test_trace`, `test_economy_repeatability`, `test_combat_repeatability`, `test_map.gd` `test_skirmish_identical` (MP3). Cross-OS trace comparison (`tools/compare_local_traces.sh RUN_ID`) needs a CI run of the branch; not run here unless the coordinator has one.

---

### Task 0: Baseline

**Files:** none changed.

- [ ] **Step 1: Record the unchanged tree's numbers**

Run (each with `timeout: 600000`): `sh tools/run_tests.sh > $S/base_tests.txt 2>&1`, `sh tools/run_benchmark.sh > $S/base_bench.txt 2>&1`, `python3 tools/zh_map/test_zh_map.py > $S/base_py.txt 2>&1` (`$S` = scratchpad).
Expected: `TESTS PASSED`, the `CASES n CHECKS m FAILURES 0` line, the benchmark's final pass lines, `OK` from unittest. Note `n`, `m`, the Python test count and any exceeded budget (accepted until the post-M7 perf spike; report, never loosen). Later tasks compare against these.

---

### Task 1: Per-source footprint in the simulation

**Files:**
- Modify: `game/scripts/simulation/definitions/definitions.gd` (next to `SOURCE_FOOTPRINT`, line 9)
- Modify: `game/scripts/simulation/simulation.gd` (`_union_cells` ~764-770, `add_supply_source` ~818-825)
- Modify: `game/scripts/simulation/construction.gd` (`_near_source` ~40-46)
- Modify: `game/scripts/simulation/supply_collection.gd` (`_size` ~19-20)
- Test: `game/tests/test_supply.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `Registry.source_footprint(source: Dictionary) -> Vector2i` (static, `definitions.gd`): `Vector2i(int(source.footprint[0]), int(source.footprint[1]))` when the key exists, else `SOURCE_FOOTPRINT`. Works on sim records, snapshot copies and parsed map JSON.
  - `Simulation.add_supply_source(origin: Vector2i, boxes: int, footprint: Vector2i = Registry.SOURCE_FOOTPRINT, delete_when_empty: bool = false) -> int`: returns -1 for `boxes < 0`, `footprint.x < 1 or footprint.y < 1`, or a blocked footprint. Record: `{"id","origin","boxes","active_collector_id"}` plus `"footprint": [w, h]` only when `footprint != SOURCE_FOOTPRINT`, plus `"delete_when_empty": true` only when set.
  - `_union_cells`, `Construction._near_source` and `Supply._size` (and so `center`, `_arrival`, `_ring`, `_claim_dock`) use `Registry.source_footprint`.

- [ ] **Step 1: Write the failing tests** (add all four to `cases()`)

```gdscript
func test_source_footprint_records(runner) -> bool:
	var sim = Fixture.make_world()
	var plain: Array = ["active_collector_id","boxes","id","origin"]
	var dock: int = sim.add_supply_source(Vector2i(24,4),200)
	var same: int = sim.add_supply_source(Vector2i(24,12),200,Registry.SOURCE_FOOTPRINT,false)
	var dock_keys: Array = Fixture.object(sim,dock).keys()
	dock_keys.sort()
	var same_keys: Array = Fixture.object(sim,same).keys()
	same_keys.sort()
	runner.check(dock_keys == plain and same_keys == plain,"Fp1 default sources keep today's record keys")
	var pile: int = sim.add_supply_source(Vector2i(20,4),50,Vector2i.ONE,true)
	var record: Dictionary = Fixture.object(sim,pile)
	runner.check(record.footprint == [1,1] and record.delete_when_empty == true and record.boxes == 50,"Fp1 small pile record")
	var blocked: Array = sim.snapshot().map.blocked_cells
	runner.check(blocked.size() == 41 and blocked.has([20,4]) and not blocked.has([21,4]) and not blocked.has([20,5]),"Fp1 a 1x1 pile blocks one cell")
	runner.check(Registry.source_footprint(record) == Vector2i.ONE and Registry.source_footprint(Fixture.object(sim,dock)) == Vector2i(4,5) and Registry.source_footprint({"footprint":[1.0,1.0]}) == Vector2i.ONE,"Fp1 one lookup for records and parsed JSON")
	var before: Dictionary = sim.snapshot()
	for row in [[Vector2i(10,20),Vector2i(0,1)],[Vector2i(10,20),Vector2i(1,-1)],[Vector2i(25,5),Vector2i.ONE]]:
		runner.check(sim.add_supply_source(row[0],50,row[1],true) == -1 and sim.snapshot() == before,"Fp1 invalid or overlapping footprint refused " + str(row))
	runner.check(sim.add_supply_source(Vector2i(21,5),50,Vector2i.ONE,true) > 0,"Fp1 diagonal neighbour piles are allowed, as on Dry Wells")
	return true

func test_ground_dock_on_small_pile(runner) -> bool:
	var sim = Fixture.make_world()
	var pile: int = sim.add_supply_source(Vector2i(24,4),8,Vector2i.ONE,true)
	runner.check(Supply._ring(Fixture.object(sim,pile)).size() == 8 and Supply.center(Fixture.object(sim,pile)) == [24.5,4.5],"Fp2 1x1 ring and centre")
	var unit: int = truck(sim,Vector2(30.5,4.5))
	gather(sim,[unit],pile)
	runner.check(until_phase(sim,unit,"loading",400),"Fp2 truck loads at a small pile")
	var loaded: Dictionary = Fixture.object(sim,unit)
	runner.check(loaded.collection.dock == [25,4] and loaded.position == [25.25,4.5],"Fp2 dock on the ring, a quarter cell toward the pile")
	return true

func test_neighbouring_small_piles_load_at_once(runner) -> bool:
	var sim = Fixture.make_world()
	var upper: int = sim.add_supply_source(Vector2i(24,4),8,Vector2i.ONE,true)
	var lower: int = sim.add_supply_source(Vector2i(24,6),8,Vector2i.ONE,true)
	var a: int = truck(sim,Vector2(30.5,4.5))
	var b: int = truck(sim,Vector2(30.5,6.5))
	gather(sim,[a],upper)
	gather(sim,[b],lower)
	var both: bool = false
	for index in range(400):
		sim.step()
		if Fixture.object(sim,a).collection.phase == "loading" and Fixture.object(sim,b).collection.phase == "loading":
			both = true
			break
	runner.check(both and Fixture.object(sim,upper).active_collector_id == a and Fixture.object(sim,lower).active_collector_id == b,"Fp3 two piles two cells apart serve one collector each at the same time")
	return true

func test_depot_clearance_from_small_pile(runner) -> bool:
	var pile := Vector2i(10,10)
	for kind in ["usa_supply_center","china_supply_center","frc_supply_center"]:
		for origin in [Vector2i(11,10),Vector2i(7,10),Vector2i(10,11),Vector2i(10,7),Vector2i(7,7)]:
			runner.check(not placement(kind,origin,pile,Vector2i.ONE),"Fp4 %s at %s within one cell of a 1x1 pile is refused" % [kind,origin])
		for origin in [Vector2i(12,10),Vector2i(6,10),Vector2i(10,12),Vector2i(10,6),Vector2i(6,6)]:
			runner.check(placement(kind,origin,pile,Vector2i.ONE),"Fp4 %s at %s one free cell from a 1x1 pile is accepted" % [kind,origin])
	runner.check(placement("usa_power_plant",Vector2i(11,10),pile,Vector2i.ONE),"Fp4 other buildings may touch a small pile")
	return true
```

Extend the existing helper to `func placement(kind: String, origin: Vector2i, pile: Variant = null, size: Vector2i = Registry.SOURCE_FOOTPRINT) -> bool`, passing `size` to `add_supply_source(pile,50,size)`. Add `const Supply = preload("res://scripts/simulation/supply_collection.gd")` to the suite.

- [ ] **Step 2: Run to verify they fail**

Run: `sh tools/run_tests.sh > $S/t1_red.txt 2>&1` then `rg -n '^(CASES|TESTS PASSED|FAIL)|SCRIPT ERROR' $S/t1_red.txt`
Expected: `SCRIPT ERROR` (too many arguments to `add_supply_source`) or `FAIL: Fp…` lines; no `TESTS PASSED`.

- [ ] **Step 3: Implement** `source_footprint`, the new `add_supply_source` signature and record rule, and the three call-site swaps listed under Interfaces. Build the record dict first, then add each optional key behind its condition.

- [ ] **Step 4: Run to verify they pass**

Run: same command to `$S/t1_green.txt`. Expected: `TESTS PASSED`, `FAILURES 0`, cases = baseline + 4; every pin listed above passes.

- [ ] **Step 5: Lint and warnings**

Run: `sh tools/run_lint.sh > $S/t1_lint.txt 2>&1; echo $?` and `sh tools/run_warnings.sh > $S/t1_warn.txt 2>&1; echo $?`. Expected: both exit 0.

- [ ] **Step 6: Commit**

```bash
git add game/scripts/simulation/definitions/definitions.gd game/scripts/simulation/simulation.gd game/scripts/simulation/construction.gd game/scripts/simulation/supply_collection.gd game/tests/test_supply.gd
git commit -m "Give each supply source its own footprint" -m "Small piles are 1x1; default sources keep their record shape so pins hold."
```

---

### Task 2: Map loader reads footprint and delete flag

**Files:**
- Modify: `game/scripts/simulation/map_data.gd` (`create` line 50, `_valid` ~65-68)
- Test: `game/tests/test_map.gd`

**Interfaces:**
- Consumes: `Registry.source_footprint(source: Dictionary) -> Vector2i`; `Simulation.add_supply_source(origin, boxes, footprint, delete_when_empty)` (Task 1).
- Produces: `MapData.parse`/`load` accept a source entry `{"origin": [x, y], "boxes": n, "footprint": [w, h], "delete_when_empty": true}`; `footprint` must be a 2-element Array of whole numbers ≥ 1, `delete_when_empty` must be a bool, else the map is rejected (`{}`). `MapData.create` passes both to `add_supply_source` (`source.get("delete_when_empty", false)`).

- [ ] **Step 1: Write the failing test** (add to `cases()`)

```gdscript
func test_small_source_from_map(runner) -> bool:
	var text := FileAccess.get_file_as_string("res://data/maps/skirmish.json")
	var map: Dictionary = JSON.parse_string(text)
	map.sources.append({"origin": [24, 28], "boxes": 50, "footprint": [1, 1], "delete_when_empty": true})
	map.cells[28] = ".".repeat(25) + "#" + ".".repeat(22)
	var parsed := MapData.parse(JSON.stringify(map))
	runner.check(not parsed.is_empty(), "MP7 a 1x1 pile beside a cliff cell is valid")
	var seats: Array[Dictionary] = []
	var sources: Array = MapData.create(parsed, seats).snapshot().sources
	runner.check(sources.size() == 3 and sources[2].footprint == [1, 1] and sources[2].delete_when_empty == true and sources[2].boxes == 50, "MP7 the loader keeps footprint and delete flag")
	var keys: Array = sources[0].keys()
	keys.sort()
	runner.check(keys == ["active_collector_id", "boxes", "id", "origin"], "MP7 default sources keep their keys")
	for bad: Variant in [[0, 1], [1], "1x1", [1.5, 1]]:
		map.sources[2].footprint = bad
		runner.check(MapData.parse(JSON.stringify(map)).is_empty(), "MP7 footprint %s is rejected" % str(bad))
	map.sources[2].footprint = [1, 1]
	map.sources[2].delete_when_empty = "yes"
	runner.check(MapData.parse(JSON.stringify(map)).is_empty(), "MP7 non-bool delete flag is rejected")
	map.sources[2].delete_when_empty = true
	map.sources[2].origin = [25, 28]
	runner.check(MapData.parse(JSON.stringify(map)).is_empty(), "MP7 a 1x1 pile on the cliff cell is rejected")
	return true
```

- [ ] **Step 2: Run to verify it fails**

Run: `sh tools/run_tests.sh > $S/t2_red.txt 2>&1`, read summary lines. Expected: `FAIL: MP7 …` (today a 4 × 5 at y 28 is out of bounds, so the map is rejected).

- [ ] **Step 3: Implement** a `static func _source_valid(map: Dictionary, size: Vector2i, source: Variant) -> bool` in `map_data.gd` (shape checks first, then `_open` with `Registry.source_footprint(source)`), called from `_valid`; pass footprint and flag in `create`.

- [ ] **Step 4: Run to verify it passes**

Run: suite to `$S/t2_green.txt`. Expected: `TESTS PASSED`, cases = Task 1 + 1, MP1/MP2/MP3/MP6/Pl3 and all pins pass. Then lint and warnings exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/scripts/simulation/map_data.gd game/tests/test_map.gd
git commit -m "Load per-source footprint and delete flag from map files"
```

---

### Task 3: Remove an empty small pile in the step that takes its last box

**Files:**
- Modify: `game/scripts/simulation/supply_collection.gd` (`step`, the `loading` branch ~178-185)
- Test: `game/tests/test_supply.gd`

**Interfaces:**
- Consumes: `add_supply_source(origin, boxes, Vector2i.ONE, true)` (Task 1); existing `Simulation.remove_object(id: int) -> Dictionary`, which calls `Supply.object_removed` (releases and stops every collector targeting the source, `retry_tick = tick + 1`, cargo kept), erases the source and rebuilds navigation.
- Produces: in `step`, right after `_load_box(collection, target)`: when `target.boxes == 0 and target.get("delete_when_empty", false)`, call `sim.remove_object(target.id)` and `continue` (do not reset `remaining_ticks`). Sources without the flag are untouched (existing `Gt2` and `Gd11` keep proving the extra delay).

Same-tick interaction cases (all tested below):

| Same tick as the last box | Expected |
|---|---|
| active collector (air, ground, cargo full on that box) | keeps every box, `seeking` with `target_id == null`, delivers next; no trailing delay |
| another collector `waiting_source` on the pile | released (no dock, target null), re-seeks another source within 2 steps |
| another collector `flying_source` toward the pile | same as the waiter |
| unrelated ground mover | re-pathed by the navigation rebuild, still reaches its target |
| `gather` on the pile due this tick | applied before supply: `ok: true`; that collector picks another source in the same step |
| `gather` on the pile queued for the next tick | `ok: false`, `Missing supply source` at its due tick; unit unchanged |
| `gather` on the pile issued after the step | refused at issue, `Missing supply source`, state unchanged |
| supply-center `build` within clearance, issued this tick | refused `Too close to a supply source` (orders apply before supply) |
| same `build` issued after the step, and one over the freed cell | accepted |

- [ ] **Step 1: Write the failing tests** (add all four to `cases()`)

```gdscript
func test_small_pile_removed_with_last_box(runner) -> bool:
	var sim = Fixture.make_world()
	var depot: int = Fixture.add_completed(sim,1,"usa_supply_center",Vector2i(10,4))
	var pile: int = sim.add_supply_source(Vector2i(24,4),2,Vector2i.ONE,true)
	var air: int = sim.spawn(1,Vector2(24.5,4.5),"usa_collector")
	var delay: int = Registry.collects("usa_collector").load_ticks
	gather(sim,[air],pile)
	runner.check(until_phase(sim,air,"loading"),"Sp1 air loads at the pile")
	Fixture.steps(sim,2 * delay - 1)
	runner.check(Fixture.object(sim,pile).boxes == 1 and Fixture.object(sim,air).collection.cargo == 1,"Sp1 one box left before the last action")
	sim.step()
	var unit: Dictionary = Fixture.object(sim,air)
	runner.check(Fixture.object(sim,pile).is_empty() and sim.snapshot().sources.is_empty(),"Sp1 the pile is gone in the step that takes its last box")
	runner.check(unit.collection.cargo == 2 and unit.collection.target_id == null and unit.collection.phase == "seeking","Sp1 the collector keeps the box and leaves without the extra delay")
	runner.check(not sim.snapshot().map.blocked_cells.has([24,4]),"Sp1 the pile's cell is free")
	runner.check(until_phase(sim,air,"unloading") and Fixture.object(sim,air).collection.target_id == depot,"Sp1 carries the boxes to its depot")
	var credits: int = sim.snapshot().players[0].credits
	Fixture.steps(sim,Registry.collects("usa_collector").unload_ticks)
	runner.check(sim.snapshot().players[0].credits == credits + 150,"Sp1 both boxes paid")
	var ground = Fixture.make_world()
	Fixture.add_completed(ground,1,"china_supply_center",Vector2i(10,4))
	var small: int = ground.add_supply_source(Vector2i(24,4),4,Vector2i.ONE,true)
	var unit_id: int = truck(ground,Vector2(26.5,4.5))
	gather(ground,[unit_id],small)
	runner.check(until_phase(ground,unit_id,"loading"),"Sp1 truck loads at the pile")
	Fixture.steps(ground,4 * Registry.collects("china_collector").load_ticks)
	var full: Dictionary = Fixture.object(ground,unit_id)
	runner.check(Fixture.object(ground,small).is_empty() and full.collection.cargo == 4 and full.collection.phase == "seeking" and not full.collection.has("dock"),"Sp1 a truck filled by the last box leaves with all four")
	runner.check(until_phase(ground,unit_id,"unloading"),"Sp1 truck reaches its depot")
	credits = ground.snapshot().players[0].credits
	Fixture.steps(ground,Registry.collects("china_collector").unload_ticks)
	runner.check(ground.snapshot().players[0].credits == credits + 300,"Sp1 truck pays 300")
	return true

func test_waiters_reseek_when_small_pile_vanishes(runner) -> bool:
	var sim = Fixture.make_world()
	var pile: int = sim.add_supply_source(Vector2i(24,4),2,Vector2i.ONE,true)
	var other: int = sim.add_supply_source(Vector2i(24,20),40)
	var loader: int = truck(sim,Vector2(26.5,4.5))
	var waiter: int = truck(sim,Vector2(26.5,5.5))
	var flyer: int = truck(sim,Vector2(2.5,28.5))
	var mover: int = sim.spawn(1,Vector2(20.5,2.5),"usa_builder")
	gather(sim,[loader],pile)
	runner.check(until_phase(sim,loader,"loading"),"Sp2 first truck loads")
	gather(sim,[waiter,flyer],pile)
	Fixture.send(sim,{"type":"move","entity_ids":[mover],"target":[28.5,8.5]})
	runner.check(until_phase(sim,waiter,"waiting_source",70),"Sp2 second truck waits before the pile empties")
	runner.check(Fixture.object(sim,flyer).collection.phase == "flying_source","Sp2 third truck is still on its way")
	for index in range(200):
		if Fixture.object(sim,pile).is_empty(): break
		sim.step()
	runner.check(Fixture.object(sim,pile).is_empty() and Fixture.object(sim,loader).collection.cargo == 2,"Sp2 the loader took both boxes")
	for id in [waiter,flyer]:
		var lost: Dictionary = Fixture.object(sim,id).collection
		runner.check(lost.target_id == null and not lost.has("dock") and lost.cargo == 0,"Sp2 released at once %d" % id)
	Fixture.steps(sim,2)
	for id in [waiter,flyer]:
		var again: Dictionary = Fixture.object(sim,id).collection
		runner.check(again.target_id == other and again.has("dock"),"Sp2 re-seeks the remaining source %d" % id)
	for index in range(2000):
		if Fixture.object(sim,mover).position == [28.5,8.5]: break
		sim.step()
	runner.check(Fixture.object(sim,mover).position == [28.5,8.5],"Sp2 an unrelated mover still arrives after the navigation rebuild")
	return true

func test_gather_on_vanishing_small_pile(runner) -> bool:
	var sim = Fixture.make_world()
	var pile: int = sim.add_supply_source(Vector2i(24,4),1,Vector2i.ONE,true)
	var other: int = sim.add_supply_source(Vector2i(24,20),40)
	var loader: int = sim.spawn(1,Vector2(24.5,4.5),"usa_collector")
	var same_tick: int = sim.spawn(1,Vector2(4.5,20.5),"usa_collector")
	var queued: int = sim.spawn(1,Vector2(6.5,20.5),"usa_collector")
	gather(sim,[loader],pile)
	runner.check(until_phase(sim,loader,"loading"),"Sp3 loader loads")
	Fixture.steps(sim,Registry.collects("usa_collector").load_ticks - 1)
	var tick: int = sim.snapshot().tick
	runner.check(Fixture.send(sim,{"type":"gather","entity_ids":[same_tick],"source_id":pile}).ok,"Sp3 gather due this tick accepted")
	runner.check(Fixture.send(sim,{"type":"gather","entity_ids":[queued],"source_id":pile,"tick":tick + 1}).ok,"Sp3 gather queued for the next tick accepted at issue")
	sim.step()
	runner.check(Fixture.object(sim,pile).is_empty(),"Sp3 the last box removed the pile")
	runner.check(sim.snapshot().command_results.any(func(r) -> bool: return r.ok and r.tick == tick),"Sp3 the same-tick gather applied before supply")
	runner.check(Fixture.object(sim,same_tick).collection.target_id == other,"Sp3 its collector picks the remaining source in the same step")
	sim.step()
	runner.check(sim.snapshot().command_results.any(func(r) -> bool: return not r.ok and r.error == "Missing supply source" and r.tick == tick + 1),"Sp3 the queued gather fails at its due tick")
	runner.check(Fixture.object(sim,queued).collection.enabled == false,"Sp3 the queued unit is unchanged")
	var before: Dictionary = sim.snapshot()
	var late: Dictionary = Fixture.send(sim,{"type":"gather","entity_ids":[queued],"source_id":pile})
	runner.check(not late.ok and late.error == "Missing supply source" and sim.snapshot() == before,"Sp3 gather after removal refused")
	return true

func test_pile_clearance_frees_after_removal(runner) -> bool:
	var sim = Fixture.make_world(50000)
	Fixture.add_completed(sim,1,"usa_power_plant",Vector2i(2,26))
	var pile: int = sim.add_supply_source(Vector2i(20,10),1,Vector2i.ONE,true)
	var air: int = sim.spawn(1,Vector2(20.5,10.5),"usa_collector")
	gather(sim,[air],pile)
	runner.check(until_phase(sim,air,"loading"),"Sp4 loader loads")
	Fixture.steps(sim,Registry.collects("usa_collector").load_ticks - 1)
	var early: Dictionary = Fixture.send(sim,{"type":"build","builder_id":1,"building_kind":"usa_supply_center","origin":[21,10]})
	runner.check(not early.ok and early.error == "Too close to a supply source","Sp4 a build issued in the emptying tick still sees the pile")
	sim.step()
	runner.check(Fixture.object(sim,pile).is_empty(),"Sp4 pile removed")
	runner.check(sim.preview_build(1,1,"usa_supply_center",Vector2i(19,9)).ok,"Sp4 a depot may cover the freed cell")
	runner.check(Fixture.send(sim,{"type":"build","builder_id":1,"building_kind":"usa_supply_center","origin":[21,10]}).ok,"Sp4 the same build is accepted after the step")
	return true
```

- [ ] **Step 2: Run to verify they fail**

Run: suite to `$S/t3_red.txt`, read summary. Expected: `FAIL: Sp1 the pile is gone…`, `FAIL: Sp2 …`, `FAIL: Sp3 …`, `FAIL: Sp4 …` (the pile stays with 0 boxes today).

- [ ] **Step 3: Implement** the removal call described under Interfaces. If a fixture timing in Sp2 is off (the waiter must arrive within the loader's two boxes, 76 ticks), fix the fixture's positions, never an expected outcome.

- [ ] **Step 4: Run to verify they pass**

Run: suite to `$S/t3_green.txt`. Expected: `TESTS PASSED`, cases = Task 2 + 4; `Gt2`, `Gd11`, `Su6`, `Gl1` and all pins pass. Lint and warnings exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/scripts/simulation/supply_collection.gd game/tests/test_supply.gd
git commit -m "Remove a small pile in the step that takes its last box" -m "As Zero Hour's DeleteWhenEmpty: the collector keeps the box and delivers it."
```

---

### Task 4: View draws and picks each source's own footprint

**Files:**
- Modify: `game/scripts/presentation/world_view.gd` (`draw_structures` ~225, `pick_source` ~412, `pick_object` ~423)
- Test: `game/tests/test_view.gd`

**Interfaces:**
- Consumes: `Registry.source_footprint(source: Dictionary) -> Vector2i` (Task 1); `add_supply_source(..., Vector2i.ONE, true)`; `Simulation.remove_object(id)`.
- Produces: drawing, `pick_source(plane_point: Vector2) -> int` and `pick_object(plane_point: Vector2) -> int` use the source's own footprint. `_structure_key` and `pile_text_points` unchanged (the key already changes when a source disappears).

- [ ] **Step 1: Write the failing tests** (add both to `cases()`)

```gdscript
class SourceSizeView extends View:
	var sizes: Array[Vector2i] = []

	func _draw_footprint(_origin: Array, size: Vector2i, color: Color, _selected: bool) -> void:
		if color == Color("9f8045"): sizes.append(size)

func test_small_pile_view(runner) -> bool:
	var sim = Fixture.make_world()
	var pile: int = sim.add_supply_source(Vector2i(24,4),50,Vector2i.ONE,true)
	var dock: int = sim.add_supply_source(Vector2i(10,20),8)
	var view = SourceSizeView.new()
	runner.root.add_child(view)
	view.set_state(sim.snapshot(),[])
	runner.check(view.pick_object(Iso.world_to_plane(Vector2(24.5,4.5))) == pile and view.pick_source(Iso.world_to_plane(Vector2(24.5,4.5))) == pile,"V13 the pile's own cell picks it")
	runner.check(view.pick_object(Iso.world_to_plane(Vector2(25.5,5.5))) == -1 and view.pick_source(Iso.world_to_plane(Vector2(25.5,5.5))) == -1,"V13 a cell a 4x5 pile would cover does not")
	runner.check(view.pick_source(Iso.world_to_plane(Vector2(12,22))) == dock,"V13 docks still pick over 4x5")
	await runner.process_frame
	runner.check(view.sizes == [Vector2i.ONE,Vector2i(4,5)],"V13 each source drawn at its own footprint, got " + str(view.sizes))
	sim.remove_object(pile)
	var selected: Array[int] = [pile]
	view.set_state(sim.snapshot(),selected)
	view.queue_redraw()
	await runner.process_frame
	runner.check(view.pick_source(Iso.world_to_plane(Vector2(24.5,4.5))) == -1,"V13 a selected pile that vanished is neither drawn nor picked")
	view.free()
	return true

func test_structures_redraw_when_a_pile_vanishes(runner) -> bool:
	var sim = Fixture.make_world()
	var pile: int = sim.add_supply_source(Vector2i(10,10),1,Vector2i.ONE,true)
	var view = View.new()
	runner.root.add_child(view)
	var layer = view.get_node("Structures")
	view.set_state(sim.snapshot(),[])
	await runner.process_frame
	var first: int = layer.draws
	sim.remove_object(pile)
	view.set_state(sim.snapshot(),[])
	await runner.process_frame
	runner.check(layer.draws == first + 1,"V14 the structure layer redraws when a pile disappears")
	view.free()
	return true
```

`V14` already passes before Step 3 (the key loses the source's entries); it guards the requirement. `V13` must fail.

- [ ] **Step 2: Run to verify V13 fails**

Run: suite to `$S/t4_red.txt`. Expected: `FAIL: V13 a cell a 4x5 pile would cover does not` and `FAIL: V13 each source drawn…`.

- [ ] **Step 3: Implement** the three swaps to `Registry.source_footprint`.

- [ ] **Step 4: Run to verify they pass**

Run: suite to `$S/t4_green.txt`. Expected: `TESTS PASSED`, cases = Task 3 + 2; V3, V11, V12 pass. Lint and warnings exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/scripts/presentation/world_view.gd game/tests/test_view.gd
git commit -m "Draw and pick supply sources at their own footprint"
```

---

### Task 5: Converter emits small piles; regenerate Dry Wells

**Files:**
- Modify: `tools/zh_map/convert.py` (`BOXES` line 28, `place` ~287-296)
- Modify: `tools/zh_map/test_zh_map.py` (replace `test_small_piles_are_not_sources_yet` ~209-212, add two tests to `PlaceTest`)
- Modify: `game/tests/test_map.gd` (`test_converted_maps_load` line 20: Dry Wells 4 → 16)
- Regenerate: `game/data/maps/dry_wells.json`

**Interfaces:**
- Consumes: the loader contract from Task 2 (`footprint`, `delete_when_empty` keys on non-default sources only).
- Produces: `SOURCES = {"SupplyDock": (400, (SOURCE_W, SOURCE_H), False), "SupplyPileSmall": (50, (1, 1), True)}` replacing `BOXES` (comment keeps the `object/civilianbuilding.ini` citation: `StartingBoxes`, `DeleteWhenEmpty`; 1 × 1 is Wargrid's choice so Dry Wells' piles do not overlap). `place` centres each source with `c - w // 2`, `c - h // 2`, clamped inside the map; emits `dict(origin=…, boxes=…)` plus `footprint=[w, h]` only when `(w, h) != (SOURCE_W, SOURCE_H)` and `delete_when_empty=True` only when set; `source_cells` uses each source's size; overlapping sources raise `ConvertError("sources overlap")`. `write_json` unchanged (`json.dumps` gives `{"origin": [40, 5], "boxes": 50, "footprint": [1, 1], "delete_when_empty": true}`).

- [ ] **Step 1: Write the failing tests**

```python
    def test_small_piles_are_separate_sources(self):
        raw = raw_map(80, 30, starts=[(10, 15), (70, 15)], sources=[(16, 15), (64, 15)], piles=[(40, 5), (41, 6)])
        out = convert.convert(raw, "T", "n")
        pile = dict(boxes=50, footprint=[1, 1], delete_when_empty=True)
        self.assertEqual(
            out["sources"],
            [
                {"origin": [14, 13], "boxes": 400},
                {"origin": [62, 13], "boxes": 400},
                dict(origin=[40, 5], **pile),
                dict(origin=[41, 6], **pile),
            ],
        )

    def test_overlapping_sources_fail(self):
        raw = raw_map(80, 30, starts=[(10, 15), (70, 15)], sources=[(16, 15), (64, 15)], piles=[(40, 5), (40, 5)])
        with self.assertRaisesRegex(convert.ConvertError, "sources overlap"):
            convert.convert(raw, "T", "n")

    def test_slots_keep_clearance_from_small_piles(self):
        raw = raw_map(80, 30, starts=[(10, 15), (70, 15)], sources=[(24, 15), (64, 15)], piles=[(13, 15)])
        out = convert.convert(raw, "T", "n")
        sizes = dict(convert.FOOTPRINTS)
        for kind, (x, y) in out["starts"][0]["slots"].items():
            gap = min(max(abs(x + i - 13), abs(y + j - 15)) for i in range(sizes[kind]) for j in range(sizes[kind]))
            self.assertGreater(gap, 1, kind + " clearance from the 1x1 pile")
```

In `game/tests/test_map.gd` line 20 change `"dry_wells": ["Dry Wells", Vector2i(81, 108), 2, 4]` to `… 2, 16]`.

- [ ] **Step 2: Run to verify they fail**

Run: `python3 tools/zh_map/test_zh_map.py > $S/t5_py_red.txt 2>&1; tail -3 $S/t5_py_red.txt`. Expected: `FAILED (failures=…)` naming `test_small_piles_are_separate_sources` and `test_overlapping_sources_fail` (`test_slots_keep_clearance_from_small_piles` may already pass: piles are skipped today, so it is a guard).

- [ ] **Step 3: Implement** `SOURCES` and the `place` changes from Interfaces.

- [ ] **Step 4: Run converter tests and Python checks**

Run: `python3 tools/zh_map/test_zh_map.py > $S/t5_py.txt 2>&1; tail -3 $S/t5_py.txt` → `OK` with baseline + 2 tests. Then `sh tools/run_python_checks.sh > $S/t5_pychk.txt 2>&1; echo $?` → 0.

- [ ] **Step 5: Regenerate and compare the three maps**

```sh
M="$HOME/projects/CnC_Modding_Support/Zero Hour/Maps/official"
python3 tools/zh_map/convert.py "$M/Twilight Flame/Twilight Flame.map" $S/ashfall.json "Ashfall" > $S/r_ash.txt && cmp $S/ashfall.json game/data/maps/ashfall.json
python3 tools/zh_map/convert.py "$M/Fallen Empire/Fallen Empire.map" $S/broken_crown.json "Broken Crown" > $S/r_bc.txt && cmp $S/broken_crown.json game/data/maps/broken_crown.json
python3 tools/zh_map/convert.py "$M/Tournament Desert/Tournament Desert.map" game/data/maps/dry_wells.json "Dry Wells" > $S/r_dw.txt
git diff --stat game/data/maps/
```

Expected: both `cmp` silent (exit 0); `git diff --stat` lists only `dry_wells.json`, and `git diff` touches only lines inside its `sources` block. Then check the Dry Wells content:

```sh
python3 -c "
import json, subprocess
new = json.load(open('game/data/maps/dry_wells.json'))
old = json.loads(subprocess.check_output(['git', 'show', 'HEAD:game/data/maps/dry_wells.json']))
assert all(new[k] == old[k] for k in old if k != 'sources'), 'only sources may change'
piles = [s for s in new['sources'] if 'footprint' in s]
assert len(new['sources']) == 16 and sum(s['boxes'] for s in new['sources']) == 2200
assert all(s['footprint'] == [1, 1] and s['delete_when_empty'] is True and s['boxes'] == 50 for s in piles) and len(piles) == 12
assert sorted(tuple(s['origin']) for s in piles) == sorted([(60,49),(61,50),(60,51),(19,55),(21,56),(20,57),(56,47),(25,58),(30,49),(28,49),(54,55),(51,57)])
print('dry wells ok')"
```

Expected: `dry wells ok`. Compare `$S/r_dw.txt` against the converter report in `more-maps.md` (routes, widths, buildable 625 / 625, supply Chebyshev 20 / 15); any difference is a stop.

- [ ] **Step 6: Run the suite**

Run: suite to `$S/t5_green.txt`. Expected: `TESTS PASSED`; MP6 (16 sources in the file and in the simulation), Pl3 (start slots on every map) and all pins pass; cases = Task 4 total.

- [ ] **Step 7: Commit**

```bash
git add tools/zh_map/convert.py tools/zh_map/test_zh_map.py game/tests/test_map.gd game/data/maps/dry_wells.json
git commit -m "Convert small supply piles as separate 50-box sources" -m "Dry Wells gets its 12 piles back (2,200 boxes); Ashfall and Broken Crown regenerate unchanged."
```

---

### Task 6: Verification, bot run, docs

**Files:**
- Modify: `docs/reference/more-maps.md` (intro, table row, the "Small piles: not converted yet" section)
- Modify: `docs/reference/m7-economy-parity.md` (mismatch list items 1 and 2: mark resolved, link the design)
- Unchanged, check only: `game/data/maps/NOTICE.md`
- Scratch only: `$S/dw_piles.gd`

**Interfaces:**
- Consumes: everything above; `Skirmish.create(with_match: bool, second_controller: String, factions: Dictionary, map_path: String)`, `Skirmish.issue_opponents(sim, seats: Array[int])`.
- Produces: evidence lines in `more-maps.md`.

- [ ] **Step 1: Full checks on the final tree**

Run, each with `timeout: 600000`, output to `$S`: `sh tools/run_tests.sh`, `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/run_python_checks.sh`, `python3 tools/zh_map/test_zh_map.py`, `sh tools/run_benchmark.sh`. Expected: all exit 0; suite cases = baseline + 11, `FAILURES 0`; benchmark results within baseline noise, any exceeded budget the same one as in Task 0 (report, never loosen). Record `git rev-parse --short HEAD` with the numbers.

- [ ] **Step 2: Bot-vs-bot scratch run on Dry Wells**

Copy `$S/dw_bots.gd` to `$S/dw_piles.gd` and add, per pair: the tick a small pile (a source with `footprint`) first drops below 50 boxes (checked every 300 ticks, -1 if never), piles removed by the end (`12 - remaining`), small-pile boxes left. Add a second, forced run for the pair `usa`-`china`: at tick 0 set `boxes = 0` on every source without `footprint` (`sim._sources`), cap 15,000 ticks. Every path calls `quit()`.
Run: `godot --headless --path game --script $S/dw_piles.gd > $S/dw_piles.txt 2>&1` in the background (if Godot refuses a script outside the project, copy it into `game/` untracked, run it as `res://dw_piles.gd`, delete it afterwards).
Expected: no `SCRIPT ERROR`; forced run: at least 1 pile removed and small-pile boxes left < 600 and seat credits rose. Natural runs: report the numbers as they are (collectors may still be on their base docks at the cap; that is data, not a failure).

- [ ] **Step 3: Update docs**

`more-maps.md`: intro "Sources are 4 × 5 cells" → docks 4 × 5, small piles 1 × 1; table row Dry Wells → "4 docks of 400 + 12 small piles of 50"; replace the "Small piles: not converted yet" section with "Small piles (2026-11-08)": link the design and this plan, the rule (1 × 1, 50 boxes, removed with the last box, collector keeps it), the converter change and overlap check, Ashfall and Broken Crown byte-identical, the Step 1 and Step 2 numbers with commit hash, "not measured: parity-harness timing (design non-goal), rendered frame time", the label overlap as a playtest item, and "builds before and after this change must not play Dry Wells online together". `m7-economy-parity.md`: mismatch items 1 and 2 → resolved (link). Check every link and path resolves; `NOTICE.md` shows no diff.

- [ ] **Step 4: Commit**

```bash
git add docs/reference/more-maps.md docs/reference/m7-economy-parity.md
git commit -m "Record small supply piles on Dry Wells"
```

Then end with `/ponytail-review` on the branch diff `a55dcef..HEAD` and one fresh reviewer per the project rules; the coordinator reports to the user. No push, PR or merge without the user.
