extends RefCounted

const Navigation = preload("res://scripts/simulation/grid_navigation.gd")
const Allocation = preload("res://scripts/simulation/destination_allocation.gd")
const CEILING: int = 81

func cases() -> Array[Callable]:
	return [test_rings_match_reference, test_ring_work_ceiling]

func test_rings_match_reference(runner) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var counts: Array[int] = [1, 2, 5, 8, 9, 20, 60]
	var mismatches: int = 0
	var non_empty: int = 0
	var blocked_targets: int = 0
	for case_index in range(300):
		var w: int = rng.randi_range(8, 40)
		var h: int = rng.randi_range(8, 40)
		var blocked: Array[Vector2i] = []
		var open: Array[Vector2i] = []
		for y in range(h):
			for x in range(w):
				if rng.randf() < 0.25: blocked.append(Vector2i(x, y))
				else: open.append(Vector2i(x, y))
		if open.is_empty(): continue
		var nav = Navigation.new(blocked, Vector2i(w, h))
		var units: Array[Dictionary] = []
		for i in range(counts[rng.randi_range(0, 6)]):
			var c: Vector2i = open[rng.randi_range(0, open.size() - 1)]
			units.append({"id": i + 1, "position": [c.x + 0.5, c.y + 0.5]})
		var target := Vector2(rng.randf_range(0, w), rng.randf_range(0, h))
		var unavailable: Array[Vector2i] = []
		for i in range(rng.randi_range(0, 10)):
			unavailable.append(Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1)))
		var got: Dictionary = Allocation.assign(nav, units, target, unavailable)
		var want: Dictionary = _ref_assign(nav, units, target, unavailable)
		if got != want: mismatches += 1
		if not want.is_empty() and want.values().any(func(v): return v != null): non_empty += 1
		if nav.component_at(target) < 0: blocked_targets += 1
	runner.check(mismatches == 0, "AL1 rings match the reference (%d mismatches)" % mismatches)
	runner.check(non_empty >= 30, "AL1 at least 30 non-empty results (%d)" % non_empty)
	runner.check(blocked_targets >= 30, "AL1 at least 30 blocked-cell targets (%d)" % blocked_targets)
	return true

func test_ring_work_ceiling(runner) -> bool:
	var nav = Navigation.new([], Vector2i(196, 196))
	var units: Array[Dictionary] = []
	for i in range(60):
		units.append({"id": i + 1, "position": [5.5 + i % 10, 95.5 + i / 10]})
	var goals: Dictionary = Allocation.assign(nav, units, Vector2(150.5, 98.5), [])
	runner.check(Allocation.last_cells_examined <= CEILING, "AL2 ring work %d within ceiling %d" % [Allocation.last_cells_examined, CEILING])
	runner.check(goals.values().all(func(v): return v != null), "AL2 every unit got a goal")
	return true


func _ref_assign(navigation: RefCounted, units: Array[Dictionary], target: Vector2, unavailable: Array[Vector2i]) -> Dictionary:
	var ordered: Array[Dictionary] = units.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	var goals: Dictionary = {}
	var occupants: Dictionary = {}
	for unit in ordered:
		goals[unit.id] = null
		var cell := Vector2i(Vector2(unit.position[0], unit.position[1]).floor())
		if not occupants.has(cell):
			occupants[cell] = {}
		occupants[cell][unit.id] = true
	var component: int = navigation.component_at(target)
	if component < 0:
		return goals
	var excluded: Dictionary = {}
	for cell in unavailable:
		excluded[cell] = true
	var candidates: Array[Vector2i] = []
	for cell in navigation.cells_in_component(component):
		if not excluded.has(cell):
			candidates.append(cell)
	var target_cell := Vector2i(target.floor())
	if ordered.size() <= REF_SCAN_MAX_UNITS:
		_ref_assign_by_scan(navigation, component, ordered, candidates, target, target_cell, occupants, goals)
		return goals
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _ref_before(a, b, target, target_cell))
	for unit in ordered:
		if navigation.component_at(Vector2(unit.position[0], unit.position[1])) != component:
			continue
		for i in range(candidates.size()):
			var cell: Vector2i = candidates[i]
			if occupants.has(cell) and (occupants[cell].size() != 1 or not occupants[cell].has(unit.id)):
				continue
			goals[unit.id] = target if cell == target_cell else Vector2(cell) + Vector2(0.5, 0.5)
			candidates.remove_at(i)
			break
	return goals

# A few units pick their cells by linear minimum search; sorting every cell of the component costs milliseconds per call.
const REF_SCAN_MAX_UNITS: int = 8

func _ref_before(a: Vector2i, b: Vector2i, target: Vector2, target_cell: Vector2i) -> bool:
	if a == target_cell or b == target_cell:
		return a == target_cell and b != target_cell
	var da: float = (Vector2(a) + Vector2(0.5, 0.5)).distance_squared_to(target)
	var db: float = (Vector2(b) + Vector2(0.5, 0.5)).distance_squared_to(target)
	if da != db:
		return da < db
	return a.y < b.y or (a.y == b.y and a.x < b.x)

func _ref_assign_by_scan(navigation: RefCounted, component: int, ordered: Array[Dictionary], candidates: Array[Vector2i], target: Vector2, target_cell: Vector2i, occupants: Dictionary, goals: Dictionary) -> void:
	var claimed: Dictionary = {}
	for unit in ordered:
		if navigation.component_at(Vector2(unit.position[0], unit.position[1])) != component:
			continue
		var best: Variant = null
		for cell in candidates:
			if claimed.has(cell) or (occupants.has(cell) and (occupants[cell].size() != 1 or not occupants[cell].has(unit.id))):
				continue
			if best == null or _ref_before(cell, best, target, target_cell): best = cell
		if best == null: continue
		claimed[best] = true
		goals[unit.id] = target if best == target_cell else Vector2(best) + Vector2(0.5, 0.5)
