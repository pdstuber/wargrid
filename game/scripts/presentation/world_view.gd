extends Node2D

const Iso = preload("res://scripts/presentation/isometric.gd")
var _state: Dictionary = {}
var _selected_id: int = -1

func set_state(state: Dictionary, selected_id: int) -> void:
	_state = state.duplicate(true)
	_selected_id = selected_id
	queue_redraw()

func _vehicle_bounds(unit: Dictionary) -> Rect2:
	var point := Vector2(unit.position[0], unit.position[1])
	return Rect2(Iso.world_to_plane(point) + Vector2(-12, -16), Vector2(24, 16))

func pick_entity(plane_point: Vector2) -> int:
	for unit in _state.get("entities", []):
		if unit.owner == 1 and _vehicle_bounds(unit).has_point(plane_point):
			return unit.id
	return -1

func _draw() -> void:
	if _state.is_empty():
		return
	for y in range(_state.map.size[1]):
		for x in range(_state.map.size[0]):
			var origin := Vector2(x, y)
			var corners := PackedVector2Array([
				Iso.world_to_plane(origin), Iso.world_to_plane(origin + Vector2.RIGHT),
				Iso.world_to_plane(origin + Vector2.ONE), Iso.world_to_plane(origin + Vector2.DOWN),
			])
			var solid: bool = _state.map.blocked_cells.has([x, y])
			draw_colored_polygon(corners, Color("665744") if solid else Color("c4a568"))
			corners.append(corners[0])
			draw_polyline(corners, Color("a88b55"), 1.0)
	for unit in _state.entities:
		var bounds: Rect2 = _vehicle_bounds(unit)
		draw_rect(bounds, Color("376eac"))
		if unit.id == _selected_id:
			draw_rect(bounds, Color("8cff87"), false, 2.0)
		if unit.order != null:
			var target := Vector2(unit.order.target[0], unit.order.target[1])
			var point: Vector2 = Iso.world_to_plane(target)
			draw_line(point - Vector2(6, 0), point + Vector2(6, 0), Color("8cff87"), 2.0)
			draw_line(point - Vector2(0, 6), point + Vector2(0, 6), Color("8cff87"), 2.0)
