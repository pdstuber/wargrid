extends RefCounted

static func assign(navigation: RefCounted, units: Array[Dictionary], target: Vector2, unavailable: Array[Vector2i]) -> Dictionary:
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
	if ordered.size() <= SCAN_MAX_UNITS:
		_assign_by_scan(navigation, component, ordered, candidates, target, target_cell, occupants, goals)
		return goals
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _before(a, b, target, target_cell))
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
const SCAN_MAX_UNITS: int = 8

static func _before(a: Vector2i, b: Vector2i, target: Vector2, target_cell: Vector2i) -> bool:
	if a == target_cell or b == target_cell:
		return a == target_cell and b != target_cell
	var da: float = (Vector2(a) + Vector2(0.5, 0.5)).distance_squared_to(target)
	var db: float = (Vector2(b) + Vector2(0.5, 0.5)).distance_squared_to(target)
	if da != db:
		return da < db
	return a.y < b.y or (a.y == b.y and a.x < b.x)

static func _assign_by_scan(navigation: RefCounted, component: int, ordered: Array[Dictionary], candidates: Array[Vector2i], target: Vector2, target_cell: Vector2i, occupants: Dictionary, goals: Dictionary) -> void:
	var claimed: Dictionary = {}
	for unit in ordered:
		if navigation.component_at(Vector2(unit.position[0], unit.position[1])) != component:
			continue
		var best: Variant = null
		for cell in candidates:
			if claimed.has(cell) or (occupants.has(cell) and (occupants[cell].size() != 1 or not occupants[cell].has(unit.id))):
				continue
			if best == null or _before(cell, best, target, target_cell): best = cell
		if best == null: continue
		claimed[best] = true
		goals[unit.id] = target if best == target_cell else Vector2(best) + Vector2(0.5, 0.5)
