extends RefCounted

static var last_cells_examined: int = 0

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

static func _before(a: Vector2i, b: Vector2i, target: Vector2, target_cell: Vector2i) -> bool:
	if a == target_cell or b == target_cell:
		return a == target_cell and b != target_cell
	var da: float = (Vector2(a) + Vector2(0.5, 0.5)).distance_squared_to(target)
	var db: float = (Vector2(b) + Vector2(0.5, 0.5)).distance_squared_to(target)
	if da != db:
		return da < db
	return a.y < b.y or (a.y == b.y and a.x < b.x)
