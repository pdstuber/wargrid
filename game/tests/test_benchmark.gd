@warning_ignore_start("untyped_declaration")
extends RefCounted

const Stats = preload("res://scripts/debug/timing_stats.gd")
const Workload = preload("res://scripts/debug/movement_workload.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Navigation = preload("res://scripts/simulation/grid_navigation.gd")
const Economy = preload("res://tests/economy_fixture.gd")
const View = preload("res://scripts/presentation/world_view.gd")
const Probe = preload("res://scenes/movement_benchmark.tscn")

func cases() -> Array[Callable]:
	return [test_statistics, test_fixtures, test_progression, test_rendered_probe_ticks, test_snapshot_size_ceiling, test_combat_fixtures, test_transports_fixture, test_defences_fixture, test_skirmish3v3_fixture, test_combat_work_ceiling, test_volley_retaliation_work, test_horde_render_layout, test_workload_asserts_pure, test_settled_matches_snapshot_predicate]

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
	return Economy.run_legacy_speed(runner, _test_progression)

func _test_progression(runner) -> bool:
	var sim = Simulation.new([], Vector2i(64, 64))
	sim.spawn(1, Vector2(51.5, 48.5))
	runner.check(not Workload.settled(sim), "BM3 idle not arrived")
	Workload.issue_leg(sim, 0)
	var before: Dictionary = sim.snapshot()
	Workload.issue_leg(sim, 1)
	runner.check(sim.snapshot() == before, "BM3 no early restart")
	for i in range(14):
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
	return Economy.run_legacy_speed(runner, _test_snapshot_size_ceiling)

func _test_snapshot_size_ceiling(runner) -> bool:
	# Step 38 is the peak (routes full, queue just drained). The snapshot is copied twice per tick; raise a ceiling only deliberately and add a performance-ledger row.
	var ceilings := {"open": 84119, "dense": 84983}
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
		runner.check(busiest <= 336, "BM5 per-unit node ceiling " + layout)
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
		var kinds := {1: {"usa_rifle_infantry": 0, "usa_tank": 0}, 2: {"usa_rifle_infantry": 0, "usa_tank": 0}}
		var cells := {}
		for unit in state.entities:
			kinds[unit.owner][unit.kind] += 1
			cells[Vector2i(Vector2(unit.position[0], unit.position[1]).floor())] = true
			runner.check(unit.position[0] > 0.0 and unit.position[1] > 0.0 and unit.position[0] < size[0] and unit.position[1] < size[1], "BM5 inside the map " + layout)
		runner.check(state.entities.size() == 300 and cells.size() == 300, "BM5 300 unique cells " + layout)
		runner.check(kinds[1] == {"usa_rifle_infantry": 100, "usa_tank": 50} and kinds[2] == {"usa_rifle_infantry": 100, "usa_tank": 50}, "BM5 100/50 mix per side " + layout)
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
			runner.check(kinds_fired.has("usa_rifle_infantry") and kinds_fired.has("usa_tank"), "BM5 contact exercises both rifles and cannons")
	return true

func test_transports_fixture(runner) -> bool:
	var sim: RefCounted = CombatWorkload.create("transports")
	var state: Dictionary = sim.snapshot()
	var riders: int = state.entities.filter(func(unit: Dictionary) -> bool: return unit.has("container_id")).size()
	var cars: int = state.entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "usa_light_vehicle" and unit.get("passengers", []).size() == 5).size()
	runner.check(state.entities.size() == 220 and riders == 100 and cars == 20, "BM5 transports: 20 full cars against 100 riflemen")
	return true

func test_defences_fixture(runner) -> bool:
	var sim: RefCounted = CombatWorkload.create("defences")
	var state: Dictionary = sim.snapshot()
	runner.check(state.buildings.filter(func(building: Dictionary) -> bool: return building.kind == "usa_defence").size() == 12 and state.entities.size() == 100, "BM5 defences: 12 batteries against 100 riflemen")
	var shots: int = 0
	for tick in range(900):
		sim.step()
		shots += sim.snapshot().combat_events.filter(func(event: Dictionary) -> bool: return event.type == "shot" and event.attacker_id <= 20).size()
	runner.check(shots > 0, "BM5 defences fire once the attackers close in")
	return true

func test_skirmish3v3_fixture(runner) -> bool:
	var sim: RefCounted = CombatWorkload.create("skirmish3v3")
	var state: Dictionary = sim.snapshot()
	sim.step()
	var tanks := {1: 0, 2: 0}
	var idle := {1: 0, 2: 0}
	var cells := {}
	for unit in sim.snapshot().entities:
		if unit.kind == "usa_tank": tanks[unit.owner] += 1
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
	runner.check(peak <= 18500 and peak > 16000, "BM6 combat work ceiling, got " + str(peak))
	return true

func test_volley_retaliation_work(runner) -> bool:
	# A full volley (about 150 shots) must not rescan every armed unit per shot; no unit is an idle guard here.
	var sim: RefCounted = CombatWorkload.create("contact")
	sim.step()
	var peak: int = 0
	var shots: int = 0
	for tick in range(120):
		sim.step()
		peak = maxi(peak, sim.combat_work())
		shots += sim.snapshot().combat_events.size()
	runner.check(shots > 100, "BM6b volleys happen in the window, got " + str(shots))
	runner.check(peak <= 1500, "BM6b joiner query work per tick after tick 0, got " + str(peak))
	return true

func test_horde_render_layout(runner) -> bool:
	var sim: Simulation = CombatWorkload.create("horde_render")
	var start: Dictionary = {}
	var china: int = 0
	for unit in sim.snapshot().entities:
		if unit.owner == 1:
			china += 1
			start[unit.id] = unit.position
	runner.check(china == 300, "BM9 300 China units")
	var view = View.new()
	var peak: int = 0
	var marked_ticks: int = 0
	for tick in range(900):
		sim.step()
		if tick >= 300:
			view.set_state(sim.snapshot(), [])
			var count: int = view.horde_marks().size()
			peak = maxi(peak, count)
			marked_ticks += 1 if count > 0 else 0
	var moved: int = 0
	for unit in sim.snapshot().entities:
		if start.has(unit.id) and unit.position != start[unit.id]:
			moved += 1
	runner.check(moved > 100, "BM9 China units moved, got %d" % moved)
	runner.check(peak > 0, "BM9 horde marks drawn in the window")
	print("BM9 horde_render peak_marks=", peak, " marked_ticks=", marked_ticks, " moved=", moved)
	view.free()
	return true

func test_workload_asserts_pure(runner) -> bool:
	# Release builds strip assert(), so a sim call inside one would silently not run.
	for path in ["res://scripts/debug/combat_workload.gd", "res://scripts/debug/movement_workload.gd"]:
		var impure: Array[String] = []
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.strip_edges().begins_with("assert(") and "sim." in line:
				impure.append(line.strip_edges())
		runner.check(impure.is_empty(), "BM10 no sim call inside assert in " + path + " " + str(impure))
	return true

func test_settled_matches_snapshot_predicate(runner) -> bool:
	var mismatches: int = 0
	var flips: int = 0
	for layout in ["open", "dense"]:
		var sim = Workload.create(layout)
		var last: bool = false
		var leg: int = 0
		for tick in 1500:
			var state: Dictionary = sim.snapshot()
			var expected: bool = not state.entities.is_empty() and state.pending_commands.is_empty() and state.entities.all(func(unit: Dictionary) -> bool: return unit.status == "arrived")
			var actual: bool = Workload.settled(sim)
			mismatches += int(actual != expected)
			flips += int(actual != last)
			last = actual
			if tick == 0 or actual:
				Workload.issue_leg(sim, leg)
				leg += 1
			sim.step()
	runner.check(mismatches == 0 and flips >= 1, "BM6 settled equals the snapshot predicate on 3000 ticks (%d mismatches, %d flips)" % [mismatches, flips])
	return true
