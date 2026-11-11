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
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const Director = preload("res://scripts/presentation/visual_director.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const ViewRows = preload("res://scripts/simulation/view_rows.gd")
var _preview_cells: Array[Vector2i] = []
var _preview_valid: bool = false
var _state: Dictionary = {}
var _rows: ViewRows = ViewRows.from_units([])
var _order := PackedInt32Array()
var _unit_items: Array[Dictionary] = []
var _last_points: Dictionary = {}
var _selection := {}
var _inspected_id: int = -1
var local_player: int = 1
var _hints: Array[Dictionary] = []
var _hovered_id: int = -1
var _biome: int = Palette.DEFAULT_BIOME
var _terrain: Node2D = Terrain.new()
var _structures: Node2D = StructureLayer.new()
var _bodies: Node2D = BodyLayer.new()
var _batch := WorldBatch.new()
var _structure_key: Array = []
var _visuals: Director
var _visual_tick: int = -1
var _waiting: Dictionary = {}
var _canvas: CanvasItem
var draw_usec: int = 0
var _items: Array[Dictionary] = []
var time_draws: bool = false
var _quality: int = GraphicsSettings.HIGH
var _zoom: float = 1.0
var _bright: bool = false
var _smooth: bool = true
var _show_destinations: bool = false
var batch_builds: int = 0
var _tick_usec: int = 0
var _alpha: float = 1.0
var _fresh: bool = false
var _blend_tick: int = -1
var _pose := {}
var _prev_pose := {}
var _moves: Array = []
var _drawn := {}
const WIDE_PICK_WIDTH: float = 36.0
const HINT_TICKS: int = 40
const MUZZLE_LIFT: float = 20.0
const HEALTH_BAR := Vector2(24, 3)
const SELECT_COLOR := Color("8cff87")
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

static func owner_color(owner_id: int, bright: bool = false) -> Color:
	return Palette.owner_colors(owner_id, bright)[0]

func _tint(owner_id: int) -> Color:
	return owner_color(owner_id, _bright)

static func health_color(fraction: float) -> Color:
	var f: float = clampf(fraction, 0.0, 1.0)
	if f >= 1.0: return Palette.HEALTH_GREEN
	if f < 0.5: return Palette.HEALTH_RED.lerp(Palette.HEALTH_YELLOW, f * 2.0)
	return Palette.HEALTH_YELLOW.lerp(Palette.HEALTH_GREEN, (f - 0.5) * 2.0)

static func shows_health(selected: bool, hp: int, max_hp: int, hovered: bool) -> bool:
	return selected or hovered or hp < max_hp

func set_quality(quality: int) -> void:
	_quality = quality
	_settle_if_not_interpolating()
	_rebuild_batch()

func set_smooth(smooth: bool) -> void:
	_smooth = smooth
	_settle_if_not_interpolating()
	_rebuild_batch()

func _interpolating() -> bool:
	return _smooth and _quality == GraphicsSettings.HIGH

func _settle_if_not_interpolating() -> void:
	if _interpolating() or _moves.is_empty(): return
	_apply_alpha(1.0)
	_moves.clear()
	_drawn.clear()

func set_zoom(zoom: float) -> void:
	_zoom = zoom
	_rebuild_batch()

func detail() -> int:
	return GraphicsSettings.detail(_quality, _zoom)

func set_visuals(director: Director) -> void:
	_visuals = director

# Neon mode: brighter owner hues on bodies, rings and structure footprints.
func set_bright_owners(bright: bool) -> void:
	_bright = bright
	_batch.bright_owners = bright
	_structure_key = []
	_structures.queue_redraw()
	_rebuild_batch()

# Lab: any ground colours; the next set_biome call applies again.
func set_ground_colors(colors: Dictionary) -> void:
	_biome = -1
	_terrain.set_palette(colors)

func set_biome(biome: int) -> void:
	if biome == _biome: return
	_biome = biome
	_terrain.set_palette(Palette.ground(biome))

func selected_unit_lines() -> PackedVector2Array:
	var lines := PackedVector2Array()
	if _selection.is_empty(): return lines
	for i in _order:
		if _selection.has(_rows.id[i]): lines.append_array(_ground_diamond(_kind_of(i), _drawn_position(i)))
	return lines

func _ground_diamond(kind: String, point: Vector2) -> PackedVector2Array:
	var anchor: Vector2 = Iso.world_to_plane(point)
	var rx: float = _half_width(kind) + 4.0
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
	var base: Vector2 = Iso.world_to_plane(_drawn.get(unit.id, Vector2(unit.position[0], unit.position[1]))) + Vector2(_half_width(unit.kind) + 6.0, -8.0)
	for i in rank:
		var tip: Vector2 = base + Vector2(0, -3.0 * i)
		lines.append_array([tip + Vector2(-CHEVRON_WIDTH / 2.0, -2.0), tip, tip, tip + Vector2(CHEVRON_WIDTH / 2.0, -2.0)])
	return lines

static func hp_fraction(hp: int, max_hp: int) -> float:
	return clampf(float(hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 1.0

func set_state(state: Dictionary, selected_ids: Array[int]) -> void:
	var view: Dictionary = state.duplicate()
	view.units = ViewRows.from_units(view.get("entities", []))
	view.erase("entities")
	set_view(view, selected_ids)

func set_view(view: Dictionary, selected_ids: Array[int]) -> void:
	_state = view
	_rows = view.units
	_selection = {}
	for id in selected_ids: _selection[id] = true
	_terrain.set_map(_state.get("map", {}))
	_prune_hints()
	var zone: int = Profiler.begin()
	_order = WorldBatch.depth_order(_rows)
	Profiler.end(&"view.sort", zone)
	zone = Profiler.begin()
	_remember_points()
	Profiler.end(&"view.points", zone)
	zone = Profiler.begin()
	_refresh_structures()
	Profiler.end(&"view.structures_key", zone)
	var batch_zone: int = Profiler.begin()
	zone = Profiler.begin()
	_rebuild_items(WorldBatch.structure_items(_state))
	Profiler.end(&"view.objects", zone)
	zone = Profiler.begin()
	_track_poses()
	_apply_alpha(_alpha)
	Profiler.end(&"view.poses", zone)
	zone = Profiler.begin()
	if _visuals != null and _state.get("tick", 0) != _visual_tick:
		_visual_tick = _state.get("tick", 0)
		_visuals.update(_items)
	Profiler.end(&"view.visuals", zone)
	zone = Profiler.begin()
	_rebuild_batch()
	Profiler.end(&"view.build", zone)
	Profiler.end(&"view.batch", batch_zone)

# Ids only ascend, so one merge pass keeps a unit's item across ticks.
func _rebuild_items(structures: Array[Dictionary]) -> void:
	var old: Array[Dictionary] = _unit_items
	var next: Array[Dictionary] = []
	var j: int = 0
	for i in _rows.size():
		var id: int = _rows.id[i]
		while j < old.size() and old[j].id < id: j += 1
		var item: Dictionary = old[j] if j < old.size() and old[j].id == id else {}
		WorldBatch.write_unit_item(item, _rows, i)
		next.append(item)
	_unit_items = next
	_items = next.duplicate()
	_items.append_array(structures)

# Interpolation (High only): each moving unit is drawn between its previous and its current tick.
# More than one tick at once (online catch-up, a restart) snaps instead of blending.
func _track_poses() -> void:
	var tick: int = _state.get("tick", 0)
	if tick != _blend_tick:
		_prev_pose = _pose if tick == _blend_tick + 1 else {}
		_pose = {}
		if _interpolating():
			for item: Dictionary in _unit_items: _pose[item.id] = _pose_of(item)
		_blend_tick = tick
		_alpha = 0.0
		_tick_usec = Time.get_ticks_usec()
		_fresh = true
	_moves = []
	if not _interpolating(): return
	for item: Dictionary in _unit_items:
		var old: Variant = _prev_pose.get(item.id)
		var now: Vector3 = _pose_of(item)
		if old != null and old != now: _moves.append([item, old, now])

static func _pose_of(item: Dictionary) -> Vector3:
	return Vector3(item.anchor.x, item.anchor.y, item.heading)

func _apply_alpha(alpha: float) -> void:
	_alpha = alpha
	_drawn.clear()
	for move: Array in _moves:
		var item: Dictionary = move[0]
		var from: Vector3 = move[1]
		var to: Vector3 = move[2]
		item.anchor = Vector2(lerpf(from.x, to.x, alpha), lerpf(from.y, to.y, alpha))
		item.heading = lerp_angle(from.z, to.z, alpha)
		_drawn[item.id] = item.anchor

# alpha runs 0 to 1 over one tick and stays at 1 while no tick arrives (a lockstep stall), so nothing rubber-bands.
func blend(alpha: float) -> void:
	if _moves.is_empty(): return
	_apply_alpha(clampf(alpha, 0.0, 1.0))
	_rebuild_batch()

# Called once per rendered frame. The frame that carried a tick already drew alpha 0.
func advance_frame(now_usec: int = -1) -> void:
	if _fresh:
		_fresh = false
		return
	if _moves.is_empty(): return
	var now: int = Time.get_ticks_usec() if now_usec < 0 else now_usec
	var alpha: float = clampf(float(now - _tick_usec) * Engine.physics_ticks_per_second / 1.0e6, 0.0, 1.0)
	if alpha == _alpha: return
	var started: int = Time.get_ticks_usec() if time_draws else 0
	blend(alpha)
	if time_draws: draw_usec += Time.get_ticks_usec() - started

func _drawn_position(i: int) -> Vector2:
	return _drawn.get(_rows.id[i], Vector2(_rows.x[i], _rows.y[i]))

func _kind_of(i: int) -> String:
	return _rows.kinds[_rows.kind[i]]

func _rebuild_batch() -> void:
	if not _state.has("map"): return
	batch_builds += 1
	var angles := {}
	var effects: Array[Dictionary] = []
	if _visuals != null:
		angles = _visuals.turret_angles()
		effects = _visuals.effects()
	_batch.build(_items, angles, detail(), _quality == GraphicsSettings.HIGH, effects)
	_bodies.queue_redraw()
	queue_redraw()

static func hint_alpha(age: float) -> float:
	return clampf(1.0 - age, 0.0, 1.0)

func add_hint(point: Vector2, tick: int) -> void:
	_hints = [{"point": point, "tick": tick}]
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
	if _selection.size() != 1: return -1
	var i: int = _rows.index_of(_selection.keys()[0])
	if i == -1 or _rows.owner[i] != local_player or not Registry.is_builder(_kind_of(i)): return -1
	for building: Dictionary in _state.get("buildings", []):
		if building.id == _hovered_id and building.owner == local_player and not building.completed and building.builder_id == null: return building.id
	return -1

func _half_width(kind: String) -> float:
	var row: Dictionary = Registry.kind(kind)
	if row.get("class", "") == "infantry": return 6.0
	var weapon: Dictionary = CombatDefinitions.weapon(row.get("weapon", ""))
	return 15.0 if weapon.get("damage_type", "") == "armor_piercing" else 12.0

func _vehicle_bounds(kind: String, point: Vector2) -> Rect2:
	var extent: Rect2 = WorldBatch.pick_extent(kind)
	return Rect2(extent.position + Iso.world_to_plane(point), extent.size)

func _pick_bounds(i: int) -> Rect2:
	var kind: String = _kind_of(i)
	var bounds: Rect2 = _vehicle_bounds(kind, _drawn_position(i))
	if not WorldBatch.INFANTRY_ROLES.has(WorldBatch.kind_info(kind)[0]): return bounds
	var centre: float = bounds.get_center().x
	return Rect2(centre - WIDE_PICK_WIDTH / 2.0, bounds.position.y, WIDE_PICK_WIDTH, bounds.size.y)

func set_show_destinations(on: bool) -> void:
	_show_destinations = on
	queue_redraw()

func order_marks() -> Array[Vector2]:
	var marks: Array[Vector2] = []
	if not _show_destinations: return marks
	for i in _order:
		if _rows.owner[i] == local_player and (_rows.flags[i] & ViewRows.ORDERED) != 0: marks.append(Iso.world_to_plane(Vector2(_rows.order_x[i], _rows.order_y[i])))
	return marks

# Above the focus box's outer stroke (grow 4 + half of 3 px), so the bar stays readable under a target box.
func health_rect(bounds: Rect2) -> Rect2:
	return Rect2(bounds.position + Vector2(0, -10), HEALTH_BAR)

func horde_count() -> int:
	return _items.filter(func(item: Dictionary) -> bool: return item.horde).size()

# Zero Hour draws a salvage crate only for the faction that can pick it up.
func crate_marks() -> Array[Vector2]:
	var marks: Array[Vector2] = []
	for player: Dictionary in _state.get("players", []):
		if player.id != local_player or not Registry.kind(Registry.faction(player.get("faction", "")).get("start_unit", "")).has("salvage"): continue
		for crate: Dictionary in _state.get("crates", []): marks.append(Iso.world_to_plane(Vector2(crate.cell[0] + 0.5, crate.cell[1] + 0.5)))
	return marks

func pick_target(plane_point: Vector2, own: int) -> int:
	for n in range(_order.size() - 1, -1, -1):
		var i: int = _order[n]
		if _rows.owner[i] != own and (_rows.flags[i] & ViewRows.CONTAINED) == 0 and not Registry.air_kinds.has(_kind_of(i)) and _pick_bounds(i).has_point(plane_point): return _rows.id[i]
	var point: Vector2 = Iso.plane_to_world(plane_point)
	for building: Dictionary in _state.get("buildings", []):
		var definition: Dictionary = Definitions.building(building.kind)
		if building.owner == own or definition.is_empty() or Combat.masked(building): continue
		if Rect2(Vector2(building.origin[0], building.origin[1]), Vector2(definition.footprint)).has_point(point): return building.id
	return -1

func pick_entity(plane_point: Vector2, any_owner: bool = false) -> int:
	for n in range(_order.size() - 1, -1, -1):
		var i: int = _order[n]
		if (any_owner or _rows.owner[i] == local_player) and (_rows.flags[i] & (ViewRows.HOLE | ViewRows.CONTAINED)) == 0 and _pick_bounds(i).has_point(plane_point):
			return _rows.id[i]
	return -1

func _draw() -> void:
	if not _state.has("map"):
		return
	var started: int = Time.get_ticks_usec() if time_draws else 0
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
	if time_draws: draw_usec += Time.get_ticks_usec() - started

# One pass per command type: all rects here, then all lines, then text.
func _draw_rects() -> void:
	for mark in crate_marks(): draw_rect(Rect2(mark - Vector2(2, 2), Vector2(4, 4)), Color("e8c547"))
	for i in _order:
		var selected: bool = _selection.has(_rows.id[i])
		if _wants_bar(_unit_items[i], selected): _draw_health(health_rect(_vehicle_bounds(_kind_of(i), _drawn_position(i))).position, _unit_items[i], selected)
	for building: Dictionary in _state.get("buildings", []):
		var definition: Dictionary = Definitions.building(building.kind)
		if definition.is_empty(): continue
		_draw_health(Iso.world_to_plane(Vector2(building.origin[0], building.origin[1]) + Vector2(definition.footprint) / 2.0) + Vector2(-HEALTH_BAR.x / 2.0, -WorldBatch.top_lift(building.kind) - 10.0), building, _selection.has(building.id))

func _draw_lines() -> void:
	var grid: PackedVector2Array = grid_lines()
	if not grid.is_empty(): draw_multiline(grid, GRID_COLOR, 1.0)
	var green: PackedVector2Array = selected_unit_lines()
	for point in order_marks():
		green.append_array([point - Vector2(6, 0), point + Vector2(6, 0), point - Vector2(0, 6), point + Vector2(0, 6)])
	if not green.is_empty(): draw_multiline(green, SELECT_COLOR, 2.0)

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
	var started: int = Time.get_ticks_usec() if time_draws else 0
	_batch.submit(_bodies.get_canvas_item())
	if time_draws: draw_usec += Time.get_ticks_usec() - started

# Drawn into the child layer, which redraws only when `_structure_key` changes.
func draw_structures() -> void:
	_canvas = _structures
	var zone: int = Profiler.begin()
	for source: Dictionary in _state.get("sources",[]):
		_draw_footprint(source.origin,Registry.source_footprint(source),Color("9f8045"),_selection.has(source.id))
	for building: Dictionary in _state.get("buildings",[]):
		var definition: Dictionary = Definitions.building(building.kind)
		if definition.is_empty(): continue
		var tint: Color = _tint(building.owner)
		_draw_footprint(building.origin,definition.footprint,tint.lerp(Color("687b8c"),0.4) if building.completed else tint.lerp(Color("887966"),0.6),_selection.has(building.id))
	Profiler.end(&"draw.structures", zone)
	_canvas = self

func _refresh_structures() -> void:
	_waiting = _waiting_counts()
	var key: Array = []
	for source: Dictionary in _state.get("sources", []):
		key.append_array([source.id, source.origin[0], source.origin[1], _selection.has(source.id)])
	for building: Dictionary in _state.get("buildings", []):
		key.append_array([building.id, building.owner, building.kind, building.origin[0], building.origin[1], building.completed, _selection.has(building.id)])
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
	if _selection.is_empty(): return targets
	for i in _order:
		var aim: int = _rows.target[i]
		if aim == -1 or not _selection.has(_rows.id[i]): continue
		targets[aim] = targets.get(aim, false) or (_rows.flags[i] & ViewRows.ATTACKING) != 0
	return targets

func _draw_focus() -> void:
	var targets: Dictionary = focus_targets()
	if targets.is_empty(): return
	for i in _order:
		var id: int = _rows.id[i]
		if targets.has(id): draw_rect(_vehicle_bounds(_kind_of(i), _drawn_position(i)).grow(4.0), Color("ff3b30"), false, 3.0 if targets[id] else 1.5)
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
	if _inspected_id == -1: return
	var i: int = _rows.index_of(_inspected_id)
	if i != -1: draw_rect(_vehicle_bounds(_kind_of(i), _drawn_position(i)).grow(2.0), Color("ff3b30"), false, 2.0)
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
		draw_arc(center, 14.0 * age + 4.0, 0.0, TAU, 16, Color(SELECT_COLOR, hint_alpha(age)), 2.0)

func rally_marker() -> Array:
	for building: Dictionary in _state.get("buildings", []):
		if _selection.has(building.id) and building.owner == local_player and Registry.can_rally(building.kind) and building.has("rally"): return building.rally
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
	for i in _rows.size():
		if (_rows.flags[i] & ViewRows.WAITING_SOURCE) != 0: counts[_rows.queue[i]] = counts.get(_rows.queue[i], 0) + 1
	return counts

static func line_position(entities: Array, unit: Dictionary) -> int:
	var place: int = 1
	for other: Variant in entities:
		if other.get("collection") != null and other.id < unit.id and other.collection.target_id == unit.collection.target_id and other.collection.phase.begins_with("waiting_"): place += 1
	return place

func _draw_cues() -> void:
	for line: Dictionary in battery_target_lines(): draw_line(line.from, line.to, Color("ff3b30"), 1.5)

func battery_target_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for building: Dictionary in _state.get("buildings", []):
		var combat: Variant = building.get("combat")
		if not _selection.has(building.id) or combat == null or combat.target_id == null or not _last_points.has(combat.target_id): continue
		lines.append({"from": _last_points[building.id] + Vector2(0, -MUZZLE_LIFT), "to": _last_points[combat.target_id]})
	return lines

# Points only for selected batteries and their targets.
func _remember_points() -> void:
	var wanted := {}
	for building: Dictionary in _state.get("buildings", []):
		var combat: Variant = building.get("combat")
		if _selection.has(building.id) and combat != null and combat.target_id != null:
			wanted[building.id] = true
			wanted[combat.target_id] = true
	_last_points = _points_of(wanted, _state.get("buildings", []))

func _points_of(wanted: Dictionary, buildings: Array) -> Dictionary:
	var points := {}
	if wanted.is_empty(): return points
	for id: int in wanted:
		var i: int = _rows.index_of(id)
		if i != -1: points[id] = Iso.world_to_plane(Vector2(_rows.x[i], _rows.y[i])) + Vector2(0, -8)
	for building: Dictionary in buildings:
		if not wanted.has(building.id): continue
		var definition: Dictionary = Definitions.building(building.kind)
		if not definition.is_empty(): points[building.id] = Iso.world_to_plane(Vector2(building.origin[0], building.origin[1]) + Vector2(definition.footprint) / 2.0)
	return points

func _cell_polygon(origin: Vector2, size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([Iso.world_to_plane(origin), Iso.world_to_plane(origin + Vector2(size.x, 0)),
		Iso.world_to_plane(origin + size), Iso.world_to_plane(origin + Vector2(0, size.y))])

func pick_entities(plane_rect: Rect2) -> Array[int]:
	var rect := plane_rect.abs()
	var ids: Array[int] = []
	for i in _rows.size():
		var point: Vector2 = Iso.world_to_plane(_drawn_position(i))
		if _rows.owner[i] == local_player and (_rows.flags[i] & (ViewRows.HOLE | ViewRows.CONTAINED)) == 0 and point.x >= rect.position.x and point.y >= rect.position.y and point.x <= rect.end.x and point.y <= rect.end.y:
			ids.append(_rows.id[i])
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
