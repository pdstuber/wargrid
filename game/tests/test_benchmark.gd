extends RefCounted

const Stats = preload("res://scripts/debug/timing_stats.gd")
const Workload = preload("res://scripts/debug/movement_workload.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Navigation = preload("res://scripts/simulation/grid_navigation.gd")
const Probe = preload("res://scenes/movement_benchmark.tscn")

func cases() -> Array[Callable]:
	return [test_statistics, test_fixtures, test_progression, test_rendered_probe_ticks, test_snapshot_size_ceiling, test_combat_fixtures, test_skirmish3v3_fixture, test_combat_work_ceiling]

func test_statistics(runner) -> bool:
	runner.check(Stats.summary(PackedFloat64Array()) == {"n": 0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}, "BM1 empty")
	runner.check(Stats.summary(PackedFloat64Array([7])) == {"n": 1, "p50": 7.0, "p95": 7.0, "p99": 7.0, "max": 7.0}, "BM1 single")
	var samples := PackedFloat64Array()
	for i in range(100, 0, -1):
		samples.append(i)
	var before := samples.duplicate()
	runner.check(Stats.summary(samples) == {"n": 100, "p50": 50.0, "p95": 95.0, "p99": 99.0, "max": 100.0}, "BM1 nearest rank")
	runner.check(samples == before, "BM1 input copied")
	return true

func test_fixtures(runner) -> bool:
	for layout in ["open", "dense"]:
		var sim: RefCounted = Workload.create(layout)
		var state: Dictionary = sim.snapshot()
		runner.check(state.entities.size() == 300 and state.map.size == [64, 64], "BM2 sized 300-unit " + layout)
		var starts: Dictionary = {}
		for unit in state.entities:
			starts[unit.position] = true
			runner.check(unit.position[0] >= 2.5 and unit.position[0] <= 21.5 and unit.position[1] >= 2.5 and unit.position[1] <= 16.5, "BM2 authored starts")
		runner.check(starts.size() == 300, "BM2 unique starts")
		var solids: Array[Vector2i] = []
		for cell in state.map.blocked_cells:
			solids.append(Vector2i(cell[0], cell[1]))
		var nav = Navigation.new(solids, Vector2i(64, 64))
		for y in range(64):
			for x in [26, 34, 42]:
				var blocked: bool = layout == "dense" and not (y >= 20 and y <= 27 or y >= 44 and y <= 51)
				runner.check(state.map.blocked_cells.has([x, y]) == blocked, "BM2 walls/gaps")
		runner.check(solids.size() == (144 if layout == "dense" else 0), "BM2 exact solid count")
		runner.check(nav.component_at(Vector2(11.5, 9.5)) == nav.component_at(Vector2(52.5, 48.5)), "BM2 anchors connected")
		Workload.issue_leg(sim, 0)
		var pending: Array = sim.snapshot().pending_commands
		runner.check(pending.size() == 1 and pending[0].entity_ids.size() == 300 and pending[0].target == [52.5, 48.5], "BM2 first leg group anchor")
	return true

func test_progression(runner) -> bool:
	var sim = Simulation.new([], Vector2i(64, 64))
	sim.spawn(1, Vector2(51.5, 48.5))
	runner.check(not Workload.settled(sim), "BM3 idle not arrived")
	Workload.issue_leg(sim, 0)
	var before: Dictionary = sim.snapshot()
	Workload.issue_leg(sim, 1)
	runner.check(sim.snapshot() == before, "BM3 no early restart")
	for i in range(10):
		sim.step()
	runner.check(Workload.settled(sim), "BM3 arrival settles")
	Workload.issue_leg(sim, 1)
	var state: Dictionary = sim.snapshot()
	runner.check(state.pending_commands.size() == 1 and state.pending_commands[0].sequence == 1 and state.pending_commands[0].target == [11.5, 9.5], "BM3 alternating next leg")
	sim.replace_blocked_cells([Vector2i(11, 9)])
	sim.step()
	runner.check(sim.snapshot().entities[0].status == "blocked" and not Workload.settled(sim), "BM3 blocked is failure")
	return true

func test_rendered_probe_ticks(runner) -> bool:
	var probe = Probe.instantiate()
	runner.root.add_child(probe)
	await runner.physics_frame
	await runner.physics_frame
	runner.check(probe.get_node("HUD/Status").text.contains("tick"), "BM4 probe reaches view update")
	probe.free()
	return true

func test_snapshot_size_ceiling(runner) -> bool:
	# Step 38 is the peak (routes full, queue just drained). The snapshot is copied twice per tick; raise a ceiling only deliberately and add a performance-ledger row.
	var ceilings := {"open": 81285, "dense": 82149}
	for layout in ceilings:
		var sim: RefCounted = Workload.create(layout)
		Workload.issue_leg(sim, 0)
		for i in range(38):
			sim.step()
		var state: Dictionary = sim.snapshot()
		var busiest: int = 0
		for unit in state.entities:
			busiest = maxi(busiest, _nodes(unit))
		runner.check(_nodes(state) <= ceilings[layout], "BM5 snapshot node ceiling " + layout)
		runner.check(busiest <= 328, "BM5 per-unit node ceiling " + layout)
	return true

func _nodes(value: Variant) -> int:
	var count: int = 1
	if value is Dictionary:
		for key in value:
			count += 1 + _nodes(value[key])
	elif value is Array:
		for item in value:
			count += _nodes(item)
	return count

func test_combat_fixtures(runner) -> bool:
	for layout in ["open", "dense", "contact"]:
		var sim: RefCounted = CombatWorkload.create(layout)
		var state: Dictionary = sim.snapshot()
		var size: Array = state.map.size
		var kinds := {1: {"infantry": 0, "tank": 0}, 2: {"infantry": 0, "tank": 0}}
		var cells := {}
		for unit in state.entities:
			kinds[unit.owner][unit.kind] += 1
			cells[Vector2i(Vector2(unit.position[0], unit.position[1]).floor())] = true
			runner.check(unit.position[0] > 0.0 and unit.position[1] > 0.0 and unit.position[0] < size[0] and unit.position[1] < size[1], "BM5 inside the map " + layout)
		runner.check(state.entities.size() == 300 and cells.size() == 300, "BM5 300 unique cells " + layout)
		runner.check(kinds[1] == {"infantry": 100, "tank": 50} and kinds[2] == {"infantry": 100, "tank": 50}, "BM5 100/50 mix per side " + layout)
		runner.check(state.players.size() == 2 and CombatWorkload.create(layout).snapshot() == state, "BM5 players and deterministic creation " + layout)
		var first_shot: int = -1
		for tick in range(60):
			sim.step()
			if first_shot == -1 and not sim.snapshot().combat_events.is_empty(): first_shot = tick
		runner.check((first_shot != -1) == (layout == "contact"), "BM5 only contact fires inside 60 ticks: " + layout)
		if layout == "contact":
			var kinds_fired := {}
			var fresh: RefCounted = CombatWorkload.create("contact")
			for tick in range(60):
				fresh.step()
				for event in fresh.snapshot().combat_events:
					if event.type == "shot": kinds_fired[fresh.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.id == event.attacker_id)[0].kind] = true
			runner.check(kinds_fired.has("infantry") and kinds_fired.has("tank"), "BM5 contact exercises both rifles and cannons")
	return true

func test_skirmish3v3_fixture(runner) -> bool:
	var sim: RefCounted = CombatWorkload.create("skirmish3v3")
	var state: Dictionary = sim.snapshot()
	sim.step()
	var tanks := {1: 0, 2: 0}
	var idle := {1: 0, 2: 0}
	var cells := {}
	for unit in sim.snapshot().entities:
		if unit.kind == "tank": tanks[unit.owner] += 1
		if unit.status == "idle": idle[unit.owner] += 1
		cells[Vector2i(Vector2(unit.position[0], unit.position[1]).floor())] = true
	runner.check(state.entities.size() == 210 and cells.size() == 210, "BM7 210 units on unique cells")
	runner.check(tanks == {1: 36, 2: 36} and idle == {1: 27, 2: 27}, "BM7 12 tanks and 9 idle units per lane and owner ")
	runner.check(CombatWorkload.create("skirmish3v3").snapshot() == state, "BM7 deterministic creation")
	return true

func test_combat_work_ceiling(runner) -> bool:
	# Machine-independent cost: target and distance checks per step in the 'contact' layout (tick 0 is the peak, every unit scans once). Raise only deliberately and add a performance-ledger row.
	var sim: RefCounted = CombatWorkload.create("contact")
	var peak: int = 0
	for tick in range(120):
		sim.step()
		peak = maxi(peak, sim.combat_work())
	runner.check(peak <= 23900 and peak > 20000, "BM6 combat work ceiling, got " + str(peak))
	return true
