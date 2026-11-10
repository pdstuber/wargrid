extends Node2D

const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const UiStyle = preload("res://scripts/presentation/ui_style.gd")
const LABEL_WIDTH: float = 160.0
const Terrain = preload("res://scripts/presentation/terrain_view.gd")
const StructureLayer = preload("res://scripts/presentation/structure_layer.gd")
const WorldBatch = preload("res://scripts/presentation/world_batch.gd")
const BodyLayer = preload("res://scripts/presentation/body_layer.gd")
const BODY_DETAIL := 1
const Palette = preload("res://scripts/presentation/palette.gd")
var _preview_cells: Array[Vector2i] = []
var _preview_valid: bool = false
var _state: Dictionary = {}
var _selected_ids: Array[int] = []
var _last_points: Dictionary = {}
var _inspected_id: int = -1
var local_player: int = 1
var _hints: Array[Dictionary] = []
var _hovered_id: int = -1
var _biome: int = 0
var _building_shots: Dictionary = {}
var _terrain: Node2D = Terrain.new()
var _structures: Node2D = StructureLayer.new()
var _bodies: Node2D = BodyLayer.new()
var _batch := WorldBatch.new()
var _structure_key: Array = []
var _waiting: Dictionary = {}
var _canvas: CanvasItem
const HINT_TICKS: int = 40
const SHOT_TICKS: int = 6
const MUZZLE_LIFT: float = 20.0
const HEALTH_BAR := Vector2(24, 3)
const SELECT_COLOR := Color("8cff87")
const CHEVRON_COLOR := Color("f0e6a0")
const GRID_COLOR := Color(0, 0, 0, 0.18)
const CHEVRON_WIDTH: float = 5.0

func _init() -> void:
	_terrain.name = "Terrain"
	_terrain.show_behind_parent = true
	add_child(_terrain)
	_structures.name = "Structures"
	_structures.show_behind_parent = true
	add_child(_structures)
	_bodies.name = "Bodies"
	_bodies.show_behind_parent = true
	add_child(_bodies)
	_canvas = self

static func owner_color(owner_id: int) -> Color:
	return Palette.owner_colors(owner_id)[0]

static func health_color(fraction: float) -> Color:
	var f: float = clampf(fraction, 0.0, 1.0)
	if f >= 1.0: return Palette.HEALTH_GREEN
	if f < 0.5: return Palette.HEALTH_RED.lerp(Palette.HEALTH_YELLOW, f * 2.0)
	return Palette.HEALTH_YELLOW.lerp(Palette.HEALTH_GREEN, (f - 0.5) * 2.0)

static func shows_health(selected: bool, hp: int, max_hp: int, hovered: bool) -> bool:
	return selected or hovered or hp < max_hp

func set_biome(biome: int) -> void:
	if biome == _biome: return
	_biome = biome
	_terrain.set_palette(Palette.ground(biome))

func selected_unit_lines() -> PackedVector2Array:
	var lines := PackedVector2Array()
	for unit: Dictionary in _state.get("entities", []):
		if _selected_ids.has(unit.id): lines.append_array(_ground_diamond(unit))
	return lines

func _ground_diamond(unit: Dictionary) -> PackedVector2Array:
	var anchor: Vector2 = Iso.world_to_plane(Vector2(unit.position[0], unit.position[1]))
	var rx: float = _half_width(unit.kind) + 4.0
	var top: Vector2 = anchor + Vector2(0, -rx * 0.5)
	var right: Vector2 = anchor + Vector2(rx, 0)
	var bottom: Vector2 = anchor + Vector2(0, rx * 0.5)
	var left: Vector2 = anchor + Vector2(-rx, 0)
	return PackedVector2Array([top, right, right, bottom, bottom, left, left, top])

func grid_lines() -> PackedVector2Array:
	var lines := PackedVector2Array()
	if _preview_cells.is_empty() or not _state.has("map"): return lines
	var size := Vector2(_state.map.size[0], _state.map.size[1])
	for x in range(int(size.x) + 1):
		lines.append(Iso.world_to_plane(Vector2(x, 0)))
		lines.append(Iso.world_to_plane(Vector2(x, size.y)))
	for y in range(int(size.y) + 1):
		lines.append(Iso.world_to_plane(Vector2(0, y)))
		lines.append(Iso.world_to_plane(Vector2(size.x, y)))
	return lines

# Placeholder: the snapshot has no veterancy yet, so this is dormant until it does.
func veterancy_lines(unit: Dictionary) -> PackedVector2Array:
	var lines := PackedVector2Array()
	var rank: int = unit.get("veterancy", 0)
	if rank <= 0: return lines
	var base: Vector2 = Iso.world_to_plane(Vector2(unit.position[0], unit.position[1])) + Vector2(_half_width(unit.kind) + 6.0, -8.0)
	for i in rank:
		var tip: Vector2 = base + Vector2(0, -3.0 * i)
		lines.append_array([tip + Vector2(-CHEVRON_WIDTH / 2.0, -2.0), tip, tip, tip + Vector2(CHEVRON_WIDTH / 2.0, -2.0)])
	return lines

static func hp_fraction(hp: int, max_hp: int) -> float:
	return clampf(float(hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 1.0

func set_state(state: Dictionary, selected_ids: Array[int]) -> void:
	var zone: int = Profiler.begin()
	_state = state.duplicate()
	Profiler.end(&"view.copy", zone)
	_selected_ids = selected_ids.duplicate()
	_terrain.set_map(_state.get("map", {}))
	_prune_hints()
	zone = Profiler.begin()
	if _state.has("entities"): _state.entities = WorldBatch.depth_sorted(state.entities)
	Profiler.end(&"view.sort", zone)
	zone = Profiler.begin()
	_remember_points()
	_remember_building_shots()
	Profiler.end(&"view.points", zone)
	zone = Profiler.begin()
	_refresh_structures()
	Profiler.end(&"view.structures_key", zone)
	zone = Profiler.begin()
	_batch.build(WorldBatch.objects(_state), {}, BODY_DETAIL, WorldBatch.FLAG_SHADOWS, horde_marks())
	_bodies.queue_redraw()
	Profiler.end(&"view.batch", zone)
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
	for cell in _preview_cells:
		_draw_footprint([cell.x,cell.y],Vector2i.ONE,Color(0.2,0.9,0.3,0.55) if _preview_valid else Color(0.9,0.2,0.2,0.55),false)
	_draw_rects()
	_draw_lines()
	Profiler.end(&"draw.units", zone)
	zone = Profiler.begin()
	_draw_focus()
	_draw_inspected()
	_draw_resume_outline()
	_draw_rally()
	_draw_hints()
	_draw_cues()
	_draw_labels()
	Profiler.end(&"draw.overlays", zone)
	Profiler.end(&"draw", total)

# One pass per command type: all rects here, then all lines, then text.
func _draw_rects() -> void:
	for mark in crate_marks(): draw_rect(Rect2(mark - Vector2(2, 2), Vector2(4, 4)), Color("e8c547"))
	for unit: Dictionary in _state.get("entities", []):
		var selected: bool = _selected_ids.has(unit.id)
		if _wants_bar(unit, selected): _draw_health(health_rect(_vehicle_bounds(unit)).position, unit, selected)
	for building: Dictionary in _state.get("buildings", []):
		var definition: Dictionary = Definitions.building(building.kind)
		if definition.is_empty(): continue
		_draw_health(Iso.world_to_plane(Vector2(building.origin[0], building.origin[1]) + Vector2(definition.footprint) / 2.0) + Vector2(-16, -26), building, _selected_ids.has(building.id))

func _draw_lines() -> void:
	var grid: PackedVector2Array = grid_lines()
	if not grid.is_empty(): draw_multiline(grid, GRID_COLOR, 1.0)
	var green: PackedVector2Array = selected_unit_lines()
	for point in order_marks():
		green.append_array([point - Vector2(6, 0), point + Vector2(6, 0), point - Vector2(0, 6), point + Vector2(0, 6)])
	if not green.is_empty(): draw_multiline(green, SELECT_COLOR, 2.0)
	var chevrons := PackedVector2Array()
	for unit: Dictionary in _state.get("entities", []): chevrons.append_array(veterancy_lines(unit))
	if not chevrons.is_empty(): draw_multiline(chevrons, CHEVRON_COLOR, 2.0)

func _draw_labels() -> void:
	for building: Dictionary in _state.get("buildings", []):
		var definition: Dictionary = Definitions.building(building.kind)
		var progress: String = "" if definition.is_empty() else building_label(building)
		if not progress.is_empty(): _draw_label(Iso.world_to_plane(Vector2(building.origin[0], building.origin[1]) + Vector2(definition.footprint) / 2.0), progress)
	for source: Dictionary in _state.get("sources", []):
		var lines: PackedStringArray = _pile_lines(source, _waiting.get(source.id, 0))
		var points: PackedVector2Array = pile_text_points(source)
		for i in lines.size(): _draw_label(points[i], lines[i])

func draw_bodies() -> void:
	_batch.submit(_bodies.get_canvas_item())

# Drawn into the child layer, which redraws only when `_structure_key` changes.
func draw_structures() -> void:
	_canvas = _structures
	var zone: int = Profiler.begin()
	for source: Dictionary in _state.get("sources",[]):
		_draw_footprint(source.origin,Registry.source_footprint(source),Color("9f8045"),_selected_ids.has(source.id))
	for building: Dictionary in _state.get("buildings",[]):
		var definition: Dictionary = Definitions.building(building.kind)
		if definition.is_empty(): continue
		var tint: Color = owner_color(building.owner)
		_draw_footprint(building.origin,definition.footprint,tint.lerp(Color("687b8c"),0.4) if building.completed else tint.lerp(Color("887966"),0.6),_selected_ids.has(building.id))
	Profiler.end(&"draw.structures", zone)
	_canvas = self

func _refresh_structures() -> void:
	_waiting = _waiting_counts()
	var key: Array = []
	for source: Dictionary in _state.get("sources", []):
		key.append_array([source.id, source.origin[0], source.origin[1], _selected_ids.has(source.id)])
	for building: Dictionary in _state.get("buildings", []):
		key.append_array([building.id, building.owner, building.kind, building.origin[0], building.origin[1], building.completed, _selected_ids.has(building.id)])
	if key == _structure_key: return
	_structure_key = key
	_structures.queue_redraw()

func _wants_bar(object: Dictionary, selected: bool) -> bool:
	return object.has("hp") and shows_health(selected, object.hp, object.max_hp, object.id == _hovered_id)

func _draw_health(top_left: Vector2, object: Dictionary, selected: bool) -> void:
	if not _wants_bar(object, selected): return
	var fraction: float = hp_fraction(object.hp, object.max_hp)
	_canvas.draw_rect(Rect2(top_left, HEALTH_BAR), Color(0, 0, 0, 0.7))
	_canvas.draw_rect(Rect2(top_left, Vector2(HEALTH_BAR.x * fraction, HEALTH_BAR.y)), health_color(fraction))

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
	return _pile_lines(source, _waiting_counts().get(source.id, 0))

func _pile_lines(source: Dictionary, waiting: int) -> PackedStringArray:
	return PackedStringArray(["Boxes %d" % source.boxes, "docked %d · waiting %d" % [0 if source.active_collector_id == null else 1, waiting]])

func _waiting_counts() -> Dictionary:
	var counts := {}
	for unit: Dictionary in _state.get("entities", []):
		var collection: Variant = unit.get("collection")
		if collection != null and collection.phase == "waiting_source": counts[collection.target_id] = counts.get(collection.target_id, 0) + 1
	return counts

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

func _cell_polygon(origin: Vector2, size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([Iso.world_to_plane(origin), Iso.world_to_plane(origin + Vector2(size.x, 0)),
		Iso.world_to_plane(origin + size), Iso.world_to_plane(origin + Vector2(0, size.y))])

func pick_entities(plane_rect: Rect2) -> Array[int]:
	var rect := plane_rect.abs()
	var ids: Array[int] = []
	for unit: Dictionary in _state.get("entities", []):
		var point: Vector2 = Iso.world_to_plane(Vector2(unit.position[0], unit.position[1]))
		if unit.owner == local_player and not unit.has("hole_id") and not unit.has("container_id") and point.x >= rect.position.x and point.y >= rect.position.y and point.x <= rect.end.x and point.y <= rect.end.y:
			ids.append(unit.id)
	ids.sort()
	return ids

func pick_source(plane_point: Vector2) -> int:
	var point: Vector2 = Iso.plane_to_world(plane_point)
	for source: Dictionary in _state.get("sources",[]):
		var origin := Vector2(source.origin[0],source.origin[1])
		if Rect2(origin,Vector2(Registry.source_footprint(source))).has_point(point): return source.id
	return -1

func pick_object(plane_point: Vector2) -> int:
	var mobile: int = pick_entity(plane_point)
	if mobile != -1: return mobile
	var point: Vector2 = Iso.plane_to_world(plane_point)
	var objects: Array = _state.get("buildings",[]).duplicate()
	objects.append_array(_state.get("sources",[]))
	objects.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.id < b.id)
	for object: Variant in objects:
		var size: Vector2i = Registry.source_footprint(object)
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
	_canvas.draw_colored_polygon(polygon,color)
	if selected:
		polygon.append(polygon[0])
		_canvas.draw_polyline(polygon,Color("8cff87"),2.0)

func _draw_label(point: Vector2, text: String) -> void:
	_canvas.draw_string(ThemeDB.fallback_font,point + Vector2(-LABEL_WIDTH / 2.0,0),text,HORIZONTAL_ALIGNMENT_CENTER,LABEL_WIDTH,UiStyle.FONT_SIZE,Color.WHITE)
