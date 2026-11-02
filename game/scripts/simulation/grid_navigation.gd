extends RefCounted

const SIZE := Vector2i(16, 16)
var _grid := AStarGrid2D.new()
var _blocked: Array[Vector2i] = []

var _map_size: Vector2i
var _components := PackedInt32Array()
var _component_cells: Array[Array] = []
const Neighbors: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

func _init(blocked_cells: Array[Vector2i] = [], size: Vector2i = SIZE) -> void:
	assert(size.x > 0 and size.y > 0 and size.x <= 64 and size.y <= 64)
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
	for cell in _blocked:
		_grid.set_point_solid(cell, false)
	_blocked = cells
	for cell in _blocked:
		_grid.set_point_solid(cell, true)
	_rebuild_components()

func _index(cell: Vector2i) -> int:
	return cell.y * _map_size.x + cell.x

func _rebuild_components() -> void:
	_components.resize(_map_size.x * _map_size.y)
	_components.fill(-1)
	_component_cells.clear()
	for y in range(_map_size.y):
		for x in range(_map_size.x):
			var seed := Vector2i(x, y)
			if _grid.is_point_solid(seed) or _components[_index(seed)] != -1:
				continue
			var component: int = _component_cells.size()
			var cells: Array[Vector2i] = [seed]
			_components[_index(seed)] = component
			var read: int = 0
			while read < cells.size():
				var cell: Vector2i = cells[read]
				read += 1
				for offset in Neighbors:
					var neighbor: Vector2i = cell + offset
					if not _grid.region.has_point(neighbor) or _grid.is_point_solid(neighbor):
						continue
					if _components[_index(neighbor)] == -1:
						_components[_index(neighbor)] = component
						cells.append(neighbor)
			cells.sort_custom(_cell_before)
			_component_cells.append(cells)

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
	var cells: Array[Vector2i] = _grid.get_id_path(start, end, false)
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
	var cells: Array = []
	for cell in _blocked:
		cells.append([cell.x, cell.y])
	return {"size": [_map_size.x, _map_size.y], "blocked_cells": cells}

func component_at(point: Vector2) -> int:
	if not is_walkable(point):
		return -1
	return _components[_index(Vector2i(point.floor()))]

func cells_in_component(component: int) -> Array[Vector2i]:
	if component < 0 or component >= _component_cells.size():
		return []
	return _component_cells[component].duplicate()

func replace_blocked_cells(cells: Array[Vector2i]) -> void:
	var normalized: Array[Vector2i] = _normalize(cells)
	if normalized != _blocked:
		_apply_blocked(normalized)
