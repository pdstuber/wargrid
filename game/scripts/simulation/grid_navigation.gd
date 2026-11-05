extends RefCounted

const Profiler = preload("res://scripts/debug/profiler.gd")
const SIZE := Vector2i(16, 16)
var _grid := AStarGrid2D.new()
var _blocked: Array[Vector2i] = []

var _map_size: Vector2i
var _snapshot_cache: Dictionary = {}
var _components := PackedInt32Array()
var _component_cells: Array[Array] = []
const Neighbors: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

func _init(blocked_cells: Array[Vector2i] = [], size: Vector2i = SIZE) -> void:
	assert(size.x > 0 and size.y > 0 and size.x <= 256 and size.y <= 256)
	var zone: int = Profiler.begin()
	_map_size = size
	_grid.region = Rect2i(Vector2i.ZERO, size)
	_grid.cell_size = Vector2.ONE
	_grid.cell_shape = AStarGrid2D.CELL_SHAPE_SQUARE
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.jumping_enabled = false
	_grid.update()
	_apply_blocked(_normalize(blocked_cells))
	Profiler.end(&"navigation.build", zone)

func size() -> Vector2i:
	return _map_size

func _cell_before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)

func _normalize(cells: Array[Vector2i]) -> Array[Vector2i]:
	var unique: Dictionary = {}
	for cell in cells:
		assert(_grid.region.has_point(cell))
		unique[cell] = true
	var normalized: Array[Vector2i] = []
	normalized.assign(unique.keys())
	normalized.sort_custom(_cell_before)
	return normalized

func _apply_blocked(cells: Array[Vector2i]) -> void:
	_snapshot_cache = {}
	for cell in _blocked:
		_grid.set_point_solid(cell, false)
	_blocked = cells
	for cell in _blocked:
		_grid.set_point_solid(cell, true)
	_rebuild_components()

func _index(cell: Vector2i) -> int:
	return cell.y * _map_size.x + cell.x

func _rebuild_components() -> void:
	var zone: int = Profiler.begin()
	_rebuild_component_cells()
	Profiler.end(&"navigation.components", zone)

func _rebuild_component_cells() -> void:
	_components.resize(_map_size.x * _map_size.y)
	_components.fill(-1)
	_component_cells.clear()
	var queue: Array[Vector2i] = []
	var count: int = 0
	for y in range(_map_size.y):
		for x in range(_map_size.x):
			var seed := Vector2i(x, y)
			if _grid.is_point_solid(seed) or _components[_index(seed)] != -1:
				continue
			queue.clear()
			queue.append(seed)
			_components[_index(seed)] = count
			var read: int = 0
			while read < queue.size():
				var cell: Vector2i = queue[read]
				read += 1
				for offset in Neighbors:
					var neighbor: Vector2i = cell + offset
					if not _grid.region.has_point(neighbor) or _grid.is_point_solid(neighbor):
						continue
					if _components[_index(neighbor)] == -1:
						_components[_index(neighbor)] = count
						queue.append(neighbor)
			count += 1
	for i in range(count):
		var cells: Array[Vector2i] = []
		_component_cells.append(cells)
	for y in range(_map_size.y):
		for x in range(_map_size.x):
			var label: int = _components[_index(Vector2i(x, y))]
			if label >= 0:
				_component_cells[label].append(Vector2i(x, y))

func is_walkable(point: Vector2) -> bool:
	if not point.is_finite() or point.x < 0 or point.y < 0 or point.x >= _map_size.x or point.y >= _map_size.y:
		return false
	return not _grid.is_point_solid(Vector2i(point.floor()))

func route(from: Vector2, to: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if not is_walkable(from) or not is_walkable(to):
		return points
	var start := Vector2i(from.floor())
	var end := Vector2i(to.floor())
	if start == end:
		return [to]
	var zone: int = Profiler.begin()
	var cells: Array[Vector2i] = _grid.get_id_path(start, end, false)
	Profiler.end(&"navigation.astar", zone)
	if cells.is_empty():
		return points
	for cell in cells:
		points.append(Vector2(cell) + Vector2(0.5, 0.5))
	if points.back() != to:
		points.append(to)
	if points.front() == from:
		points.pop_front()
	return points

func snapshot() -> Dictionary:
	if _snapshot_cache.is_empty():
		var cells: Array = []
		for cell in _blocked:
			var pair: Array = [cell.x, cell.y]
			pair.make_read_only()
			cells.append(pair)
		cells.make_read_only()
		var size: Array = [_map_size.x, _map_size.y]
		size.make_read_only()
		_snapshot_cache = {"size": size, "blocked_cells": cells}
		_snapshot_cache.make_read_only()
	return _snapshot_cache

func component_at(point: Vector2) -> int:
	if not is_walkable(point):
		return -1
	return _components[_index(Vector2i(point.floor()))]

func cells_in_component(component: int) -> Array[Vector2i]:
	if component < 0 or component >= _component_cells.size():
		return []
	return _component_cells[component].duplicate()

func _is_rectangle(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	var bounds: Array[Vector2i] = _bounds(cells)
	return (bounds[1].x - bounds[0].x + 1) * (bounds[1].y - bounds[0].y + 1) == cells.size()

func _open(cell: Vector2i) -> bool:
	return _grid.region.has_point(cell) and not _grid.is_point_solid(cell)

func _bounds(cells: Array[Vector2i]) -> Array[Vector2i]:
	var low: Vector2i = cells[0]
	var high: Vector2i = cells[0]
	for cell in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	return [low, high]

func _ring(low: Vector2i, high: Vector2i) -> Array[Vector2i]:
	var ring: Array[Vector2i] = []
	for x in range(low.x - 1, high.x + 2):
		ring.append(Vector2i(x, low.y - 1))
	for y in range(low.y, high.y + 2):
		ring.append(Vector2i(high.x + 1, y))
	for x in range(high.x, low.x - 2, -1):
		ring.append(Vector2i(x, high.y + 1))
	for y in range(high.y, low.y - 1, -1):
		ring.append(Vector2i(low.x - 1, y))
	return ring

func _ring_arcs(cells: Array[Vector2i]) -> int:
	var bounds: Array[Vector2i] = _bounds(cells)
	var ring: Array[Vector2i] = _ring(bounds[0], bounds[1])
	var arcs: int = 0
	for i in range(ring.size()):
		if _open(ring[i]) and not _open(ring[i - 1]):
			arcs += 1
	return arcs

func blocks_locally(cells: Array[Vector2i]) -> bool:
	return _is_rectangle(cells) and cells.all(_open) and _ring_arcs(cells) <= 1

func replace_blocked_cells(cells: Array[Vector2i]) -> String:
	var zone: int = Profiler.begin()
	var normalized: Array[Vector2i] = _normalize(cells)
	if normalized == _blocked:
		Profiler.end(&"navigation.replace", zone)
		return "none"
	var old: Dictionary = {}
	for cell in _blocked:
		old[cell] = true
	var new: Dictionary = {}
	for cell in normalized:
		new[cell] = true
	var added: Array[Vector2i] = []
	for cell in normalized:
		if not old.has(cell): added.append(cell)
	var removed: Array[Vector2i] = []
	for cell in _blocked:
		if not new.has(cell): removed.append(cell)
	var local: bool = false
	if removed.is_empty() and blocks_locally(added):
		for cell in added:
			_grid.set_point_solid(cell, true)
			_component_cells[_components[_index(cell)]].erase(cell)
			_components[_index(cell)] = -1
		local = true
	elif added.is_empty() and _is_rectangle(removed):
		var label: int = _single_neighbor_label(removed)
		if label >= 0:
			for cell in removed:
				_grid.set_point_solid(cell, false)
				_components[_index(cell)] = label
				var list: Array = _component_cells[label]
				list.insert(list.bsearch_custom(cell, _cell_before), cell)
			local = true
	if local:
		_blocked = normalized
		_snapshot_cache = {}
	else:
		_apply_blocked(normalized)
	Profiler.end(&"navigation.replace", zone)
	return "local" if local else "full"

# -1 unless every open cell 4-adjacent to the rectangle carries one label.
func _single_neighbor_label(rectangle: Array[Vector2i]) -> int:
	var inside: Dictionary = {}
	for cell in rectangle:
		inside[cell] = true
	var label: int = -1
	for cell in rectangle:
		for offset in Neighbors:
			var neighbor: Vector2i = cell + offset
			if inside.has(neighbor) or not _open(neighbor):
				continue
			var found: int = _components[_index(neighbor)]
			if label != -1 and found != label:
				return -1
			label = found
	return label
