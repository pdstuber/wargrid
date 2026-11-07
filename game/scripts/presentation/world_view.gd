extends Node2D

const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const UiStyle = preload("res://scripts/presentation/ui_style.gd")
const ICONS: Array[String] = ["command", "power", "supply", "barracks", "factory", "battery"]
const LABEL_WIDTH: float = 160.0
const DEPTH_SCALE := 1024.0
const INDEX_BITS := 20
const INDEX_MASK := (1 << 20) - 1
var _preview_cells: Array[Vector2i] = []
var _preview_valid: bool = false
var _state: Dictionary = {}
var _selected_ids: Array[int] = []
var _last_points: Dictionary = {}
var _inspected_id: int = -1
var local_player: int = 1
var _hints: Array[Dictionary] = []
var _hovered_id: int = -1
var _building_shots: Dictionary = {}
const HINT_TICKS: int = 40
const SHOT_TICKS: int = 6
const MUZZLE_LIFT: float = 20.0
const HEALTH_BAR := Vector2(24, 3)
const OWNER_COLORS := {1: Color("376eac"), 2: Color("b04a3a")}

static func owner_color(owner_id: int) -> Color:
	return OWNER_COLORS.get(owner_id, Color("808080"))

static func hp_fraction(hp: int, max_hp: int) -> float:
	return clampf(float(hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 1.0

func set_state(state: Dictionary, selected_ids: Array[int]) -> void:
	var zone: int = Profiler.begin()
	_state = state.duplicate()
	Profiler.end(&"view.copy", zone)
	_selected_ids = selected_ids.duplicate()
	_prune_hints()
	zone = Profiler.begin()
	if _state.has("entities"): _state.entities = _depth_sorted(state.entities)
	Profiler.end(&"view.sort", zone)
	zone = Profiler.begin()
	_remember_points()
	_remember_building_shots()
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
	if building.completed: return ""
	var label: String = "%d%%" % (building.work * 100 / (Definitions.building(building.kind).ticks * 1000))
	return label + " paused" if building.builder_id == null else label

static func icon_name(kind: String) -> String:
	var icon: String = Registry.icon(kind)
	return icon if ICONS.has(icon) else ""

static func fallback_letter(kind: String) -> String:
	return str(Registry.kind(kind).get("display_name", kind)).left(1).to_upper()

# Keeps the glyph's bounding box inside the footprint diamond and below the health bar.
static func icon_radius(footprint: Vector2i) -> float:
	return 4.0 + 5.0 * minf(footprint.x, footprint.y)

static func text_height() -> float:
	return ThemeDB.fallback_font.get_height(UiStyle.FONT_SIZE)

func pile_text_points(source: Dictionary) -> PackedVector2Array:
	var top: Vector2 = Iso.world_to_plane(Vector2(source.origin[0], source.origin[1])) + Vector2(0, -8)
	return PackedVector2Array([top - Vector2(0, text_height()), top])

func resume_candidate() -> int:
	var builders: int = 0
	for unit: Dictionary in _state.get("entities", []):
		if _selected_ids.has(unit.id) and unit.owner == local_player and Registry.is_builder(unit.kind): builders += 1
	if builders != 1 or _selected_ids.size() != 1: return -1
	for building: Dictionary in _state.get("buildings", []):
		if building.id == _hovered_id and building.owner == local_player and not building.completed and building.builder_id == null: return building.id
	return -1

func _half_width(kind: String) -> float:
	var row: Dictionary = Registry.kind(kind)
	if row.get("class", "") == "infantry": return 6.0
	var weapon: Dictionary = CombatDefinitions.weapon(row.get("weapon", ""))
	return 15.0 if weapon.get("damage_type", "") == "armor_piercing" else 12.0

func _vehicle_bounds(unit: Dictionary) -> Rect2:
	var point := Vector2(unit.position[0], unit.position[1])
	var half: float = _half_width(unit.get("kind"))
	return Rect2(Iso.world_to_plane(point) + Vector2(-half, -34 if Registry.air_kinds.has(unit.get("kind")) else -16), Vector2(half * 2.0, 16))

func order_marks() -> Array[Vector2]:
	var marks: Array[Vector2] = []
	for unit: Dictionary in _state.get("entities", []):
		if unit.owner == local_player and unit.order != null: marks.append(Iso.world_to_plane(Vector2(unit.order.target[0], unit.order.target[1])))
	return marks

# Above the focus box's outer stroke (grow 4 + half of 3 px), so the bar stays readable under a target box.
func health_rect(bounds: Rect2) -> Rect2:
	return Rect2(bounds.position + Vector2(0, -10), HEALTH_BAR)

# Top edge of the unit rectangle, just under its health bar.
func horde_marks() -> Array[Vector2]:
	var marks: Array[Vector2] = []
	for unit: Dictionary in _state.get("entities", []):
		if unit.get("combat") != null and unit.combat.get("horde", 0) > 0:
			var bounds: Rect2 = _vehicle_bounds(unit)
			marks.append(Vector2(bounds.get_center().x, bounds.position.y + 4.0))
	return marks

# Zero Hour draws a salvage crate only for the faction that can pick it up.
func crate_marks() -> Array[Vector2]:
	var marks: Array[Vector2] = []
	for player: Dictionary in _state.get("players", []):
		if player.id != local_player or not Registry.kind(Registry.faction(player.get("faction", "")).get("start_unit", "")).has("salvage"): continue
		for crate: Dictionary in _state.get("crates", []): marks.append(Iso.world_to_plane(Vector2(crate.cell[0] + 0.5, crate.cell[1] + 0.5)))
	return marks

func heading_marks() -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	for unit: Dictionary in _state.get("entities", []):
		if Registry.air_kinds.has(unit.get("kind")): continue
		var point := Vector2(unit.position[0], unit.position[1])
		var direction: Vector2 = (Iso.world_to_plane(point + Vector2(unit.heading[0], unit.heading[1])) - Iso.world_to_plane(point)).normalized()
		var from: Vector2 = _vehicle_bounds(unit).get_center()
		marks.append({"id": unit.id, "from": from, "to": from + direction * 5.0})
	return marks

func pick_target(plane_point: Vector2, own: int) -> int:
	for i in range(_state.get("entities", []).size() - 1, -1, -1):
		var unit: Dictionary = _state.entities[i]
		if unit.owner != own and not unit.has("container_id") and not Registry.air_kinds.has(unit.get("kind")) and _vehicle_bounds(unit).has_point(plane_point): return unit.id
	var point: Vector2 = Iso.plane_to_world(plane_point)
	for building: Dictionary in _state.get("buildings", []):
		var definition: Dictionary = Definitions.building(building.kind)
		if building.owner == own or definition.is_empty() or Combat.masked(building): continue
		if Rect2(Vector2(building.origin[0], building.origin[1]), Vector2(definition.footprint)).has_point(point): return building.id
	return -1

func pick_entity(plane_point: Vector2, any_owner: bool = false) -> int:
	for i in range(_state.get("entities", []).size() - 1, -1, -1):
		var unit: Dictionary = _state.entities[i]
		if (any_owner or unit.owner == local_player) and not unit.has("hole_id") and not unit.has("container_id") and _vehicle_bounds(unit).has_point(plane_point):
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
	for source: Dictionary in _state.get("sources",[]):
		_draw_footprint(source.origin,Vector2i(3,3),Color("9f8045"),_selected_ids.has(source.id))
		var lines: PackedStringArray = pile_lines(source)
		var points: PackedVector2Array = pile_text_points(source)
		for i in lines.size(): _draw_label(points[i],lines[i])
	for building: Dictionary in _state.get("buildings",[]):
		var definition: Dictionary = Definitions.building(building.kind)
		if definition.is_empty(): continue
		var tint: Color = owner_color(building.owner)
		_draw_footprint(building.origin,definition.footprint,tint.lerp(Color("687b8c"),0.4) if building.completed else tint.lerp(Color("887966"),0.6),_selected_ids.has(building.id))
		_draw_building_mark(building,definition)
		_draw_health(Iso.world_to_plane(Vector2(building.origin[0],building.origin[1]) + Vector2(definition.footprint) / 2.0) + Vector2(-16,-26),building,_selected_ids.has(building.id))
	Profiler.end(&"draw.structures", zone)
	zone = Profiler.begin()
	for cell in _preview_cells:
		_draw_footprint([cell.x,cell.y],Vector2i.ONE,Color(0.2,0.9,0.3,0.55) if _preview_valid else Color(0.9,0.2,0.2,0.55),false)
	for unit: Dictionary in _state.get("entities",[]):
		if Registry.air_kinds.has(unit.get("kind")): draw_circle(Iso.world_to_plane(Vector2(unit.position[0],unit.position[1])),8,Color(0,0,0,.35))
		var bounds: Rect2 = _vehicle_bounds(unit)
		draw_rect(bounds, owner_color(unit.owner))
		_draw_health(health_rect(bounds).position, unit, _selected_ids.has(unit.id))
		if _selected_ids.has(unit.id):
			draw_rect(bounds, Color("8cff87"), false, 2.0)
	for mark in crate_marks(): draw_rect(Rect2(mark - Vector2(2, 2), Vector2(4, 4)), Color("e8c547"))
	for point in order_marks():
		draw_line(point - Vector2(6, 0), point + Vector2(6, 0), Color("8cff87"), 2.0)
		draw_line(point - Vector2(0, 6), point + Vector2(0, 6), Color("8cff87"), 2.0)
	for mark in heading_marks(): draw_line(mark.from, mark.to, Color.WHITE, 2.0)
	for mark in horde_marks(): draw_colored_polygon(PackedVector2Array([mark + Vector2(0, -3), mark + Vector2(3, 0), mark + Vector2(0, 3), mark + Vector2(-3, 0)]), Color.WHITE)
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
	draw_rect(Rect2(top_left, HEALTH_BAR), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(top_left, Vector2(HEALTH_BAR.x * hp_fraction(object.hp, object.max_hp), HEALTH_BAR.y)), Color("e0d060"))

func focus_targets() -> Dictionary:
	var targets := {}
	for unit: Dictionary in _state.get("entities", []):
		var combat: Variant = unit.get("combat")
		if not _selected_ids.has(unit.id) or combat == null or combat.target_id == null: continue
		targets[combat.target_id] = targets.get(combat.target_id, false) or combat.mode == "attack"
	return targets

func _draw_focus() -> void:
	var targets: Dictionary = focus_targets()
	if targets.is_empty(): return
	for unit: Dictionary in _state.get("entities", []):
		if targets.has(unit.id): draw_rect(_vehicle_bounds(unit).grow(4.0), Color("ff3b30"), false, 3.0 if targets[unit.id] else 1.5)
	for building: Dictionary in _state.get("buildings", []):
		var definition: Dictionary = Definitions.building(building.kind)
		if not targets.has(building.id) or definition.is_empty(): continue
		var polygon := _cell_polygon(Vector2(building.origin[0], building.origin[1]), Vector2(definition.footprint))
		polygon.append(polygon[0])
		draw_polyline(polygon, Color("ff3b30"), 3.0 if targets[building.id] else 1.5)

func set_inspected(id: int) -> void:
	_inspected_id = id
	queue_redraw()

func _draw_inspected() -> void:
	for unit: Dictionary in _state.get("entities", []):
		if unit.id == _inspected_id: draw_rect(_vehicle_bounds(unit).grow(2.0), Color("ff3b30"), false, 2.0)
	for building: Dictionary in _state.get("buildings", []):
		var definition: Dictionary = Definitions.building(building.kind)
		if building.id != _inspected_id or definition.is_empty(): continue
		var polygon := _cell_polygon(Vector2(building.origin[0], building.origin[1]), Vector2(definition.footprint))
		polygon.append(polygon[0])
		draw_polyline(polygon, Color("ff3b30"), 2.0)

func _draw_resume_outline() -> void:
	var id: int = resume_candidate()
	if id == -1: return
	for building: Dictionary in _state.get("buildings", []):
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
	for building: Dictionary in _state.get("buildings", []):
		if _selected_ids.has(building.id) and building.owner == local_player and Registry.can_rally(building.kind) and building.has("rally"): return building.rally
	return []

func _draw_rally() -> void:
	var marker: Array = rally_marker()
	if marker.is_empty(): return
	var point: Vector2 = Iso.world_to_plane(Vector2(marker[0], marker[1]))
	draw_line(point, point + Vector2(0, -22), Color("8cff87"), 2.0)
	draw_colored_polygon(PackedVector2Array([point + Vector2(0, -22), point + Vector2(12, -18), point + Vector2(0, -14)]), Color("8cff87"))

func pile_lines(source: Dictionary) -> PackedStringArray:
	var waiting: int = 0
	for unit: Dictionary in _state.get("entities", []):
		if unit.get("collection") != null and unit.collection.target_id == source.id and unit.collection.phase == "waiting_source": waiting += 1
	return PackedStringArray(["Boxes %d" % source.boxes, "docked %d · waiting %d" % [0 if source.active_collector_id == null else 1, waiting]])

static func line_position(entities: Array, unit: Dictionary) -> int:
	var place: int = 1
	for other: Variant in entities:
		if other.get("collection") != null and other.id < unit.id and other.collection.target_id == unit.collection.target_id and other.collection.phase.begins_with("waiting_"): place += 1
	return place

func _draw_cues() -> void:
	for line: Dictionary in battery_target_lines(): draw_line(line.from, line.to, Color("ff3b30"), 1.5)
	for line: Dictionary in _building_shots.values(): draw_line(line.from, line.to, Color("ffe680"), 2.0)
	for event: Dictionary in _state.get("combat_events", []):
		if event.type == "shot" and not _building_shots.has(event.attacker_id) and _last_points.has(event.attacker_id) and _last_points.has(event.target_id):
			draw_line(_last_points[event.attacker_id], _last_points[event.target_id], Color("ffe680"), 2.0)
		elif event.type == "death" and _last_points.has(event.object_id):
			var at: Vector2 = _last_points[event.object_id]
			draw_line(at - Vector2(7, 7), at + Vector2(7, 7), Color("ff5030"), 3.0)
			draw_line(at - Vector2(7, -7), at + Vector2(7, -7), Color("ff5030"), 3.0)

# Keyed by attacker so a stalled tick re-seeing the same event stays one line.
func _remember_building_shots() -> void:
	var tick: int = _state.get("tick", 0)
	for id: int in _building_shots.keys():
		if tick > _building_shots[id].tick + SHOT_TICKS: _building_shots.erase(id)
	var building_ids := {}
	for building: Dictionary in _state.get("buildings", []): building_ids[building.id] = true
	for event: Dictionary in _state.get("combat_events", []):
		if event.type == "shot" and building_ids.has(event.attacker_id) and _last_points.has(event.attacker_id) and _last_points.has(event.target_id):
			_building_shots[event.attacker_id] = {"from": _last_points[event.attacker_id] + Vector2(0, -MUZZLE_LIFT), "to": _last_points[event.target_id], "tick": event.tick}

func building_shot_lines() -> Array:
	return _building_shots.values()

func battery_target_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for building: Dictionary in _state.get("buildings", []):
		var combat: Variant = building.get("combat")
		if not _selected_ids.has(building.id) or combat == null or combat.target_id == null or not _last_points.has(combat.target_id): continue
		lines.append({"from": _last_points[building.id] + Vector2(0, -MUZZLE_LIFT), "to": _last_points[combat.target_id]})
	return lines

func _remember_points() -> void:
	var points := {}
	for unit: Dictionary in _state.get("entities", []): points[unit.id] = Iso.world_to_plane(Vector2(unit.position[0], unit.position[1])) + Vector2(0, -8)
	for building: Dictionary in _state.get("buildings", []):
		var definition: Dictionary = Definitions.building(building.kind)
		if not definition.is_empty(): points[building.id] = Iso.world_to_plane(Vector2(building.origin[0], building.origin[1]) + Vector2(definition.footprint) / 2.0)
	for event: Dictionary in _state.get("combat_events", []):
		if event.type == "death" and _last_points.has(event.object_id): points[event.object_id] = _last_points[event.object_id]
	_last_points = points

func _draw_terrain() -> void:
	var size := Vector2(_state.map.size[0], _state.map.size[1])
	draw_colored_polygon(_cell_polygon(Vector2.ZERO, size), Color("c4a568"))
	for cell: Variant in _state.map.blocked_cells:
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

# Input is in id order (snapshot order), so equal depths keep id order like the old comparator.
func _depth_sorted(entities: Array) -> Array:
	assert(entities.size() <= INDEX_MASK)
	var keys := PackedInt64Array()
	keys.resize(entities.size())
	for i in range(entities.size()):
		var unit: Dictionary = entities[i]
		keys[i] = (int(floor((float(unit.position[0]) + float(unit.position[1])) * DEPTH_SCALE)) << INDEX_BITS) | i
	keys.sort()
	var sorted: Array = []
	sorted.resize(entities.size())
	for i in range(keys.size()):
		sorted[i] = entities[keys[i] & INDEX_MASK]
	return sorted

func pick_entities(plane_rect: Rect2) -> Array[int]:
	var rect := plane_rect.abs()
	var ids: Array[int] = []
	for unit: Dictionary in _state.get("entities", []):
		var point: Vector2 = Iso.world_to_plane(Vector2(unit.position[0], unit.position[1]))
		if unit.owner == local_player and not unit.has("hole_id") and not unit.has("container_id") and point.x >= rect.position.x and point.y >= rect.position.y and point.x <= rect.end.x and point.y <= rect.end.y:
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
	for object: Variant in objects:
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

func _draw_label(point: Vector2, text: String) -> void:
	draw_string(ThemeDB.fallback_font,point + Vector2(-LABEL_WIDTH / 2.0,0),text,HORIZONTAL_ALIGNMENT_CENTER,LABEL_WIDTH,UiStyle.FONT_SIZE,Color.WHITE)

func _draw_building_mark(building: Dictionary, definition: Dictionary) -> void:
	var center: Vector2 = Iso.world_to_plane(Vector2(building.origin[0],building.origin[1]) + Vector2(definition.footprint) / 2.0)
	var radius: float = icon_radius(definition.footprint)
	var alpha: float = 0.9 if building.completed else 0.5
	_draw_glyph(building.kind,center + Vector2.ONE,radius,Color(0,0,0,alpha * 0.5))
	_draw_glyph(building.kind,center,radius,Color(1,1,1,alpha))
	var progress: String = building_label(building)
	if not progress.is_empty(): _draw_label(center + Vector2(0,radius + text_height()),progress)

func _draw_glyph(kind: String, c: Vector2, r: float, color: Color) -> void:
	match icon_name(kind):
		"command": draw_colored_polygon(_star(c,r),color)
		"power": draw_colored_polygon(_bolt(c,r),color)
		"supply":
			draw_rect(Rect2(c - Vector2(r,r) * 0.8,Vector2(r,r) * 1.6),color,false,2.0)
			draw_line(c - Vector2(r * 0.8,0),c + Vector2(r * 0.8,0),color,2.0)
			draw_line(c - Vector2(0,r * 0.8),c + Vector2(0,r * 0.8),color,2.0)
		"barracks":
			for dy: float in [-0.6,0.0,0.6]:
				draw_polyline(PackedVector2Array([c + Vector2(-r * 0.8,r * (dy - 0.2)),c + Vector2(0,r * (dy + 0.2)),c + Vector2(r * 0.8,r * (dy - 0.2))]),color,2.0)
		"factory":
			draw_circle(c,r * 0.55,color)
			for i in 8: draw_line(c + Vector2.RIGHT.rotated(i * TAU / 8.0) * r * 0.5,c + Vector2.RIGHT.rotated(i * TAU / 8.0) * r,color,3.0)
		"battery": draw_colored_polygon(_missile(c,r),color)
		_: draw_string(ThemeDB.fallback_font,c + Vector2(-r,r * 0.6),fallback_letter(kind),HORIZONTAL_ALIGNMENT_CENTER,r * 2.0,int(r * 1.8),color)

static func _star(c: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10: points.append(c + Vector2.UP.rotated(i * TAU / 10.0) * (r if i % 2 == 0 else r * 0.45))
	return points

static func _bolt(c: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2(0.2,-1),Vector2(-0.6,0.1),Vector2(-0.05,0.1),Vector2(-0.25,1),Vector2(0.6,-0.15),Vector2(0.05,-0.15)])
	for i in points.size(): points[i] = c + points[i] * r
	return points

static func _missile(c: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2(0,-1),Vector2(0.3,-0.4),Vector2(0.3,0.5),Vector2(0.75,1),Vector2(-0.75,1),Vector2(-0.3,0.5),Vector2(-0.3,-0.4)])
	for i in points.size(): points[i] = c + points[i] * r
	return points
