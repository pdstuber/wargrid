extends Node2D

const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
var _preview_cells: Array[Vector2i] = []
var _preview_valid: bool = false
var _state: Dictionary = {}
var _selected_ids: Array[int] = []
var _last_points: Dictionary = {}
var _inspected_id: int = -1
var local_player: int = 1
var _hints: Array[Dictionary] = []
var _hovered_id: int = -1
const HINT_TICKS: int = 40
const OwnerColors := {1: Color("376eac"), 2: Color("b04a3a")}

static func owner_color(owner: int) -> Color:
	return OwnerColors.get(owner, Color("808080"))

static func hp_fraction(hp: int, max_hp: int) -> float:
	return clampf(float(hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 1.0

func set_state(state: Dictionary, selected_ids: Array[int]) -> void:
	var zone: int = Profiler.begin()
	_state = state.duplicate(true)
	Profiler.end(&"view.copy", zone)
	_selected_ids = selected_ids.duplicate()
	_prune_hints()
	zone = Profiler.begin()
	_state.get("entities", []).sort_custom(_draw_before)
	Profiler.end(&"view.sort", zone)
	zone = Profiler.begin()
	_remember_points()
	Profiler.end(&"view.points", zone)
	queue_redraw()

func add_hint(point: Vector2, tick: int) -> void:
	_hints.append({"point": point, "tick": tick})
	queue_redraw()

func hints() -> Array:
	_prune_hints()
	return _hints.duplicate()

func _prune_hints() -> void:
	var tick: int = _state.get("tick", 0)
	_hints = _hints.filter(func(hint: Dictionary) -> bool: return tick < hint.tick + HINT_TICKS)

func hovered_id() -> int:
	return _hovered_id

func set_hovered(id: int) -> void:
	if id != _hovered_id: queue_redraw()
	_hovered_id = id

static func building_label(building: Dictionary) -> String:
	var definition: Dictionary = Definitions.building(building.kind)
	if building.completed: return "P%d %s" % [building.owner,building.kind]
	var label: String = "P%d %s %d%%" % [building.owner,building.kind,building.work * 100 / (definition.ticks * 1000)]
	return label + " paused" if building.builder_id == null else label

func resume_candidate() -> int:
	var builders: int = 0
	for unit in _state.get("entities", []):
		if _selected_ids.has(unit.id) and unit.owner == local_player and unit.kind == "builder": builders += 1
	if builders != 1 or _selected_ids.size() != 1: return -1
	for building in _state.get("buildings", []):
		if building.id == _hovered_id and building.owner == local_player and not building.completed and building.builder_id == null: return building.id
	return -1

func _vehicle_bounds(unit: Dictionary) -> Rect2:
	var point := Vector2(unit.position[0], unit.position[1])
	var half: float = {"infantry": 6.0, "tank": 15.0}.get(unit.get("kind"), 12.0)
	return Rect2(Iso.world_to_plane(point) + Vector2(-half, -34 if unit.get("kind") == "collector" else -16), Vector2(half * 2.0, 16))

func pick_target(plane_point: Vector2, own: int) -> int:
	for i in range(_state.get("entities", []).size() - 1, -1, -1):
		var unit: Dictionary = _state.entities[i]
		if unit.owner != own and unit.get("kind") != "collector" and _vehicle_bounds(unit).has_point(plane_point): return unit.id
	var point: Vector2 = Iso.plane_to_world(plane_point)
	for building in _state.get("buildings", []):
		var definition: Dictionary = Definitions.building(building.kind)
		if building.owner == own or definition.is_empty(): continue
		if Rect2(Vector2(building.origin[0], building.origin[1]), Vector2(definition.footprint)).has_point(point): return building.id
	return -1

func pick_entity(plane_point: Vector2, any_owner: bool = false) -> int:
	for i in range(_state.get("entities", []).size() - 1, -1, -1):
		var unit: Dictionary = _state.entities[i]
		if (any_owner or unit.owner == local_player) and _vehicle_bounds(unit).has_point(plane_point):
			return unit.id
	return -1

func _draw() -> void:
	if not _state.has("map"):
		return
	var total: int = Profiler.begin()
	var zone: int = Profiler.begin()
	_draw_terrain()
	Profiler.end(&"draw.terrain", zone)
	zone = Profiler.begin()
	for source in _state.get("sources",[]):
		_draw_footprint(source.origin,Vector2i(3,3),Color("9f8045"),_selected_ids.has(source.id))
		var lines: PackedStringArray = pile_lines(source)
		_draw_text(source.origin,lines[0])
		_draw_text([source.origin[0],source.origin[1] + 0.8],lines[1])
	for building in _state.get("buildings",[]):
		var definition: Dictionary = Definitions.building(building.kind)
		if definition.is_empty(): continue
		var tint: Color = owner_color(building.owner)
		_draw_footprint(building.origin,definition.footprint,tint.lerp(Color("687b8c"),0.4) if building.completed else tint.lerp(Color("887966"),0.6),_selected_ids.has(building.id))
		_draw_text(building.origin,building_label(building))
		_draw_health(Iso.world_to_plane(Vector2(building.origin[0],building.origin[1]) + Vector2(definition.footprint) / 2.0) + Vector2(-16,-26),building,_selected_ids.has(building.id))
	Profiler.end(&"draw.structures", zone)
	zone = Profiler.begin()
	for cell in _preview_cells:
		_draw_footprint([cell.x,cell.y],Vector2i.ONE,Color(0.2,0.9,0.3,0.55) if _preview_valid else Color(0.9,0.2,0.2,0.55),false)
	for unit in _state.get("entities",[]):
		if unit.get("kind") == "collector": draw_circle(Iso.world_to_plane(Vector2(unit.position[0],unit.position[1])),8,Color(0,0,0,.35))
		var bounds: Rect2 = _vehicle_bounds(unit)
		draw_rect(bounds, owner_color(unit.owner))
		_draw_health(bounds.position + Vector2(0, -6), unit, _selected_ids.has(unit.id))
		if _selected_ids.has(unit.id):
			draw_rect(bounds, Color("8cff87"), false, 2.0)
		if unit.order != null:
			var target := Vector2(unit.order.target[0], unit.order.target[1])
			var point: Vector2 = Iso.world_to_plane(target)
			draw_line(point - Vector2(6, 0), point + Vector2(6, 0), Color("8cff87"), 2.0)
			draw_line(point - Vector2(0, 6), point + Vector2(0, 6), Color("8cff87"), 2.0)
	Profiler.end(&"draw.units", zone)
	zone = Profiler.begin()
	_draw_focus()
	_draw_inspected()
	_draw_resume_outline()
	_draw_rally()
	_draw_hints()
	_draw_cues()
	Profiler.end(&"draw.overlays", zone)
	Profiler.end(&"draw", total)

func _draw_health(top_left: Vector2, object: Dictionary, selected: bool) -> void:
	if not object.has("hp") or (not selected and object.hp >= object.max_hp): return
	draw_rect(Rect2(top_left, Vector2(24, 3)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(top_left, Vector2(24.0 * hp_fraction(object.hp, object.max_hp), 3)), Color("e0d060"))

func focus_targets() -> Dictionary:
	var targets := {}
	for unit in _state.get("entities", []):
		var combat: Variant = unit.get("combat")
		if not _selected_ids.has(unit.id) or combat == null or combat.target_id == null: continue
		targets[combat.target_id] = targets.get(combat.target_id, false) or combat.mode == "attack"
	return targets

func _draw_focus() -> void:
	var targets: Dictionary = focus_targets()
	if targets.is_empty(): return
	for unit in _state.get("entities", []):
		if targets.has(unit.id): draw_rect(_vehicle_bounds(unit).grow(4.0), Color("ff3b30"), false, 3.0 if targets[unit.id] else 1.5)
	for building in _state.get("buildings", []):
		var definition: Dictionary = Definitions.building(building.kind)
		if not targets.has(building.id) or definition.is_empty(): continue
		var polygon := _cell_polygon(Vector2(building.origin[0], building.origin[1]), Vector2(definition.footprint))
		polygon.append(polygon[0])
		draw_polyline(polygon, Color("ff3b30"), 3.0 if targets[building.id] else 1.5)

func set_inspected(id: int) -> void:
	_inspected_id = id
	queue_redraw()

func _draw_inspected() -> void:
	for unit in _state.get("entities", []):
		if unit.id == _inspected_id: draw_rect(_vehicle_bounds(unit).grow(2.0), Color("ff3b30"), false, 2.0)
	for building in _state.get("buildings", []):
		var definition: Dictionary = Definitions.building(building.kind)
		if building.id != _inspected_id or definition.is_empty(): continue
		var polygon := _cell_polygon(Vector2(building.origin[0], building.origin[1]), Vector2(definition.footprint))
		polygon.append(polygon[0])
		draw_polyline(polygon, Color("ff3b30"), 2.0)

func _draw_resume_outline() -> void:
	var id: int = resume_candidate()
	if id == -1: return
	for building in _state.get("buildings", []):
		if building.id != id: continue
		var polygon := _cell_polygon(Vector2(building.origin[0], building.origin[1]), Vector2(Definitions.building(building.kind).footprint))
		polygon.append(polygon[0])
		draw_polyline(polygon, Color("8cff87"), 2.0)

func _draw_hints() -> void:
	for hint in _hints:
		var age: float = float(_state.tick - hint.tick) / HINT_TICKS
		var center: Vector2 = Iso.world_to_plane(hint.point)
		draw_arc(center, 14.0 * age + 4.0, 0.0, TAU, 16, Color("8cff87"), 2.0)

func rally_marker() -> Array:
	for building in _state.get("buildings", []):
		if _selected_ids.has(building.id) and building.owner == local_player and building.kind in ["barracks", "factory"] and building.has("rally"): return building.rally
	return []

func _draw_rally() -> void:
	var marker: Array = rally_marker()
	if marker.is_empty(): return
	var point: Vector2 = Iso.world_to_plane(Vector2(marker[0], marker[1]))
	draw_line(point, point + Vector2(0, -22), Color("8cff87"), 2.0)
	draw_colored_polygon(PackedVector2Array([point + Vector2(0, -22), point + Vector2(12, -18), point + Vector2(0, -14)]), Color("8cff87"))

func pile_lines(source: Dictionary) -> PackedStringArray:
	var waiting: int = 0
	for unit in _state.get("entities", []):
		if unit.get("collection") != null and unit.collection.target_id == source.id and unit.collection.phase == "waiting_source": waiting += 1
	return PackedStringArray(["Boxes %d" % source.boxes, "docked %d · waiting %d" % [0 if source.active_collector_id == null else 1, waiting]])

static func line_position(entities: Array, unit: Dictionary) -> int:
	var place: int = 1
	for other in entities:
		if other.get("collection") != null and other.id < unit.id and other.collection.target_id == unit.collection.target_id and other.collection.phase.begins_with("waiting_"): place += 1
	return place

func _draw_cues() -> void:
	for event in _state.get("combat_events", []):
		if event.type == "shot" and _last_points.has(event.attacker_id) and _last_points.has(event.target_id):
			draw_line(_last_points[event.attacker_id], _last_points[event.target_id], Color("ffe680"), 2.0)
		elif event.type == "death" and _last_points.has(event.object_id):
			var at: Vector2 = _last_points[event.object_id]
			draw_line(at - Vector2(7, 7), at + Vector2(7, 7), Color("ff5030"), 3.0)
			draw_line(at - Vector2(7, -7), at + Vector2(7, -7), Color("ff5030"), 3.0)

func _remember_points() -> void:
	var points := {}
	for unit in _state.get("entities", []): points[unit.id] = Iso.world_to_plane(Vector2(unit.position[0], unit.position[1])) + Vector2(0, -8)
	for building in _state.get("buildings", []):
		var definition: Dictionary = Definitions.building(building.kind)
		if not definition.is_empty(): points[building.id] = Iso.world_to_plane(Vector2(building.origin[0], building.origin[1]) + Vector2(definition.footprint) / 2.0)
	for event in _state.get("combat_events", []):
		if event.type == "death" and _last_points.has(event.object_id): points[event.object_id] = _last_points[event.object_id]
	_last_points = points

func _draw_terrain() -> void:
	var size := Vector2(_state.map.size[0], _state.map.size[1])
	draw_colored_polygon(_cell_polygon(Vector2.ZERO, size), Color("c4a568"))
	for cell in _state.map.blocked_cells:
		draw_colored_polygon(_cell_polygon(Vector2(cell[0], cell[1]), Vector2.ONE), Color("665744"))
	var lines := PackedVector2Array()
	for x in range(int(size.x) + 1):
		lines.append(Iso.world_to_plane(Vector2(x, 0)))
		lines.append(Iso.world_to_plane(Vector2(x, size.y)))
	for y in range(int(size.y) + 1):
		lines.append(Iso.world_to_plane(Vector2(0, y)))
		lines.append(Iso.world_to_plane(Vector2(size.x, y)))
	draw_multiline(lines, Color("a88b55"), 1.0)

func _cell_polygon(origin: Vector2, size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([Iso.world_to_plane(origin), Iso.world_to_plane(origin + Vector2(size.x, 0)),
		Iso.world_to_plane(origin + size), Iso.world_to_plane(origin + Vector2(0, size.y))])

func _draw_before(a: Dictionary, b: Dictionary) -> bool:
	var depth_a: float = a.position[0] + a.position[1]
	var depth_b: float = b.position[0] + b.position[1]
	return a.id < b.id if depth_a == depth_b else depth_a < depth_b

func pick_entities(plane_rect: Rect2) -> Array[int]:
	var rect := plane_rect.abs()
	var ids: Array[int] = []
	for unit in _state.get("entities", []):
		var point: Vector2 = Iso.world_to_plane(Vector2(unit.position[0], unit.position[1]))
		if unit.owner == local_player and point.x >= rect.position.x and point.y >= rect.position.y and point.x <= rect.end.x and point.y <= rect.end.y:
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
	var polygon := _cell_polygon(point, Vector2(size))
	draw_colored_polygon(polygon,color)
	if selected:
		polygon.append(polygon[0])
		draw_polyline(polygon,Color("8cff87"),2.0)

func _draw_text(origin: Array, text: String) -> void:
	draw_string(ThemeDB.fallback_font,Iso.world_to_plane(Vector2(origin[0],origin[1])) + Vector2(0,-8),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
