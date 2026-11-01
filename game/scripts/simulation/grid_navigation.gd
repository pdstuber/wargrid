extends RefCounted

const SIZE := Vector2i(16, 16)
var _grid := AStarGrid2D.new()
var _blocked: Array[Vector2i] = []

func _init(blocked_cells: Array[Vector2i] = []) -> void:
	_grid.region = Rect2i(Vector2i.ZERO, SIZE)
	_grid.cell_size = Vector2.ONE
	_grid.cell_shape = AStarGrid2D.CELL_SHAPE_SQUARE
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.jumping_enabled = false
	_grid.update()
	for cell in blocked_cells:
		assert(_grid.region.has_point(cell))
		if not _blocked.has(cell):
			_blocked.append(cell)
			_grid.set_point_solid(cell)
	_blocked.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))

func is_walkable(point: Vector2) -> bool:
	if not point.is_finite() or point.x < 0 or point.y < 0 or point.x >= SIZE.x or point.y >= SIZE.y:
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
	return {"size": [SIZE.x, SIZE.y], "blocked_cells": cells}
