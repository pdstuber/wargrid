extends Node2D

const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
var _preview_cells: Array[Vector2i] = []
var _preview_valid: bool = false
var _state: Dictionary = {}
var _selected_ids: Array[int] = []

func set_state(state: Dictionary, selected_ids: Array[int]) -> void:
	_state = state.duplicate(true)
	_selected_ids = selected_ids.duplicate()
	_state.get("entities", []).sort_custom(_draw_before)
	queue_redraw()

func _vehicle_bounds(unit: Dictionary) -> Rect2:
	var point := Vector2(unit.position[0], unit.position[1])
	return Rect2(Iso.world_to_plane(point) + Vector2(-12, -34 if unit.get("kind") == "collector" else -16), Vector2(24, 16))

func pick_entity(plane_point: Vector2) -> int:
	for i in range(_state.get("entities", []).size() - 1, -1, -1):
		var unit: Dictionary = _state.entities[i]
		if unit.owner == 1 and _vehicle_bounds(unit).has_point(plane_point):
			return unit.id
	return -1

func _draw() -> void:
	if not _state.has("map"):
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
	for source in _state.get("sources",[]):
		_draw_footprint(source.origin,Vector2i(3,3),Color("9f8045"),_selected_ids.has(source.id))
		_draw_text(source.origin,"Boxes %d" % source.boxes)
	for building in _state.get("buildings",[]):
		var definition: Dictionary = Definitions.building(building.kind)
		if definition.is_empty(): continue
		_draw_footprint(building.origin,definition.footprint,Color("687b8c") if building.completed else Color("887966"),_selected_ids.has(building.id))
		var label: String = building.kind if building.completed else "%s %d%%" % [building.kind,building.work * 100 / (definition.ticks * 1000)]
		_draw_text(building.origin,label)
	for cell in _preview_cells:
		_draw_footprint([cell.x,cell.y],Vector2i.ONE,Color(0.2,0.9,0.3,0.55) if _preview_valid else Color(0.9,0.2,0.2,0.55),false)
	for unit in _state.get("entities",[]):
		if unit.get("kind") == "collector": draw_circle(Iso.world_to_plane(Vector2(unit.position[0],unit.position[1])),8,Color(0,0,0,.35))
		var bounds: Rect2 = _vehicle_bounds(unit)
		draw_rect(bounds, Color("376eac"))
		if _selected_ids.has(unit.id):
			draw_rect(bounds, Color("8cff87"), false, 2.0)
		if unit.order != null:
			var target := Vector2(unit.order.target[0], unit.order.target[1])
			var point: Vector2 = Iso.world_to_plane(target)
			draw_line(point - Vector2(6, 0), point + Vector2(6, 0), Color("8cff87"), 2.0)
			draw_line(point - Vector2(0, 6), point + Vector2(0, 6), Color("8cff87"), 2.0)

func _draw_before(a: Dictionary, b: Dictionary) -> bool:
	var depth_a: float = a.position[0] + a.position[1]
	var depth_b: float = b.position[0] + b.position[1]
	return a.id < b.id if depth_a == depth_b else depth_a < depth_b

func pick_entities(plane_rect: Rect2) -> Array[int]:
	var rect := plane_rect.abs()
	var ids: Array[int] = []
	for unit in _state.get("entities", []):
		var point: Vector2 = Iso.world_to_plane(Vector2(unit.position[0], unit.position[1]))
		if unit.owner == 1 and point.x >= rect.position.x and point.y >= rect.position.y and point.x <= rect.end.x and point.y <= rect.end.y:
			ids.append(unit.id)
	ids.sort()
	return ids

func pick_object(plane_point: Vector2) -> int:
	var mobile: int = pick_entity(plane_point)
	if mobile != -1: return mobile
	var point: Vector2 = Iso.plane_to_world(plane_point)
	var objects: Array = _state.get("buildings",[]).duplicate()
	objects.append_array(_state.get("sources",[]))
	objects.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.id < b.id)
	for object in objects:
		var size := Vector2i(3,3)
		if object.has("kind"):
			var definition: Dictionary = Definitions.building(object.kind)
			if definition.is_empty(): continue
			size = definition.footprint
		var origin := Vector2(object.origin[0],object.origin[1])
		if point.x >= origin.x and point.y >= origin.y and point.x <= origin.x + size.x and point.y <= origin.y + size.y: return object.id
	return -1

func set_build_preview(cells: Array[Vector2i], valid: bool) -> void:
	_preview_cells = cells.duplicate()
	_preview_valid = valid
	queue_redraw()

func _draw_footprint(origin: Array, size: Vector2i, color: Color, selected: bool) -> void:
	var point := Vector2(origin[0],origin[1])
	var polygon := PackedVector2Array([Iso.world_to_plane(point),Iso.world_to_plane(point + Vector2(size.x,0)),Iso.world_to_plane(point + Vector2(size)),Iso.world_to_plane(point + Vector2(0,size.y))])
	draw_colored_polygon(polygon,color)
	if selected:
		polygon.append(polygon[0])
		draw_polyline(polygon,Color("8cff87"),2.0)

func _draw_text(origin: Array, text: String) -> void:
	draw_string(ThemeDB.fallback_font,Iso.world_to_plane(Vector2(origin[0],origin[1])) + Vector2(0,-8),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
