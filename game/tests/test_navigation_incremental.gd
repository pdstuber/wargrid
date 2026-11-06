@warning_ignore_start("untyped_declaration")
extends RefCounted

const Navigation = preload("res://scripts/simulation/grid_navigation.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

func cases() -> Array[Callable]:
	return [test_map_lists_shared_read_only, test_incremental_matches_rebuild, test_pinch_build_falls_back, test_death_updates_locally]

func test_incremental_matches_rebuild(runner) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var local: int = 0
	var full: int = 0
	var mismatches: int = 0
	for map_index in range(40):
		var size := Vector2i(rng.randi_range(12, 40), rng.randi_range(12, 40))
		var blocked: Array[Vector2i] = []
		for y in range(size.y):
			for x in range(size.x):
				if rng.randf() < 0.2: blocked.append(Vector2i(x, y))
		var nav = Navigation.new(blocked, size)
		var mine: Array[Array] = []
		for step in range(30):
			var current: Array[Vector2i] = []
			current.assign(nav.snapshot().blocked_cells.map(func(c): return Vector2i(c[0], c[1])))
			var rect: Array[Vector2i] = []
			if not mine.is_empty() and rng.randf() < 0.5:
				var index: int = rng.randi_range(0, mine.size() - 1)
				rect.assign(mine[index])
				mine.remove_at(index)
				current = current.filter(func(c): return not rect.has(c))
			else:
				var side: int = rng.randi_range(2, 3)
				var origin := Vector2i(rng.randi_range(0, size.x - side), rng.randi_range(0, size.y - side))
				for y in range(side):
					for x in range(side): rect.append(origin + Vector2i(x, y))
				if rect.any(func(c): return current.has(c)): continue
				mine.append(rect)
				current.append_array(rect)
			var how: String = nav.replace_blocked_cells(current)
			if how == "local": local += 1
			elif how == "full": full += 1
			if not _same_as_rebuild(nav, current, size, rng): mismatches += 1
	runner.check(mismatches == 0, "NI1 incremental equals rebuild (%d mismatches)" % mismatches)
	runner.check(local >= 50 and full >= 50, "NI1 both paths exercised (local %d, full %d)" % [local, full])
	return true

func _same_as_rebuild(nav, cells: Array[Vector2i], size: Vector2i, rng: RandomNumberGenerator) -> bool:
	var fresh = Navigation.new(cells, size)
	if nav.snapshot() != fresh.snapshot(): return false
	var open: Array[Vector2] = []
	for y in range(size.y):
		for x in range(size.x):
			var point := Vector2(x + 0.5, y + 0.5)
			if nav.cells_in_component(nav.component_at(point)) != fresh.cells_in_component(fresh.component_at(point)): return false
			if nav.is_walkable(point): open.append(point)
	if open.is_empty(): return true
	for i in range(10):
		var from: Vector2 = open[rng.randi_range(0, open.size() - 1)]
		var to: Vector2 = open[rng.randi_range(0, open.size() - 1)]
		if nav.route(from, to) != fresh.route(from, to): return false
	return true

func test_pinch_build_falls_back(runner) -> bool:
	var sim = Fixture.make_world()
	var wall: Array[Vector2i] = []
	for y in range(32):
		if y != 4 and y != 5: wall.append(Vector2i(10, y))
	sim.replace_blocked_cells(wall)
	var before: int = sim.navigation_builds()
	var result: Dictionary = Fixture.send(sim, {"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[10,4]})
	runner.check(sim.navigation_builds() == before + 1, "NI2 the gap-closing build does one full build at issue")
	sim.step()
	runner.check(result == {"ok": true, "error": ""}, "NI2 command result as before the change")
	runner.check(sim.snapshot().buildings[0].approach == [9.5, 4.5], "NI2 approach as before the change")
	return true

func test_death_updates_locally(runner) -> bool:
	var sim = Fixture.make_world()
	runner.check(Fixture.send(sim, {"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,4]}).ok, "NI3 build accepted")
	sim.step()
	var id: int = sim.snapshot().buildings[0].id
	var builds: int = sim.navigation_builds()
	var local: int = sim.navigation_local_updates()
	sim._remove_building(id)
	runner.check(sim.navigation_builds() == builds and sim.navigation_local_updates() == local + 1, "NI3 removal updates in place")
	var rebuilt = Simulation.new(sim._union_cells(), Vector2i(32, 32))
	runner.check(sim.snapshot().map == rebuilt.snapshot().map, "NI3 map equals a rebuilt simulation's")
	return true

func test_map_lists_shared_read_only(runner) -> bool:
	var sim = Fixture.make_world()
	var a: Dictionary = sim.snapshot()
	var b: Dictionary = sim.snapshot()
	runner.check(is_same(a.map.blocked_cells, b.map.blocked_cells) and is_same(a.terrain_cells, b.terrain_cells), "SM1 map lists are shared between snapshots")
	runner.check(a.map.blocked_cells.is_read_only() and a.terrain_cells.is_read_only(), "SM1 map lists are read-only")
	runner.check(Fixture.send(sim, {"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,4]}).ok, "SM1 build accepted")
	sim.step()
	var rebuilt = Simulation.new(sim._union_cells(), Vector2i(32, 32))
	runner.check(sim.snapshot().map == rebuilt.snapshot().map, "SM1 map after placement equals a rebuilt simulation's")
	var wall: Array[Vector2i] = [Vector2i(20, 20)]
	runner.check(sim.replace_blocked_cells(wall).ok and sim.snapshot().terrain_cells == [[20, 20]], "SM1 terrain cache follows replace_blocked_cells")
	return true
