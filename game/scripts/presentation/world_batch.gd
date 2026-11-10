extends RefCounted

const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Economy = preload("res://scripts/simulation/economy_definitions.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Shapes = preload("res://scripts/presentation/shapes.gd")
const Bake = preload("res://scripts/presentation/shape_bake.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const Director = preload("res://scripts/presentation/visual_director.gd")

const LAYER_GROUND := 1
const LAYER_AIR := 2
const DEPTH_SCALE := 1024.0
const ID_BITS := 20
const DEPTH_BITS := 22
const INDEX_BITS := 16
const BODY_CACHE_CAP := 4096
const AIR_LIFT := 30.0
const SHADOW_RADIUS := 8.0
const MARK_RADIUS := 3.0
const GROUND_SHADOW_RADIUS := 6.0
const MUZZLE_LIFT := 16.0
const MUZZLE_COLOR := Color("ffe680")
const HIT_COLOR := Color("ff8a3c")
const FADE_COLOR := Color("1c1a18")
const FLAG_SHADOWS := GraphicsSettings.FLAG_SHADOWS
const INFANTRY_ROLES := [&"infantry", &"rocket_infantry", &"laborer"]

var points := PackedVector2Array()
var colors := PackedColorArray()
var triangle_count: int = 0
# Role -> variant bits OR-ed into the item's own; the A/B lab fills it, empty keeps every shape as it is.
var role_variants: Dictionary = {}
# Lab: true greys for vertical faces, and a brighter set of owner hues.
var neutral_sides: bool = false
var bright_owners: bool = false

static var _top_lifts: Dictionary = {}
static var _pick_extents: Dictionary = {}
static var _kind_info: Dictionary = {}
static var _kind_air: Dictionary = {}
static var _bodies: Dictionary = {}
static var _body_count: int = 0
static var _quads: Dictionary = {}
static var _quad_colors: Dictionary = {}
static var _turreted: Dictionary = {}

# [role, layer] per unit kind; test kinds replace Registry.air_kinds, which drops the cache.
static func kind_info(kind: String) -> Array:
	if not is_same(Registry.air_kinds, _kind_air):
		_kind_info.clear()
		_kind_air = Registry.air_kinds
	if not _kind_info.has(kind):
		_kind_info[kind] = [Shapes.role(kind), LAYER_AIR if Registry.air_kinds.has(kind) else LAYER_GROUND]
	return _kind_info[kind]

# Roof height in px of a building kind's baked shape, for things drawn above it.
static func top_lift(kind: String) -> float:
	var role: StringName = Shapes.role(kind)
	if not _top_lifts.has(role):
		var top: float = 0.0
		for part in Shapes.parts(role, 0).size(): top = maxf(top, Array(Bake.mesh(role, part, 0, 0).lifts).max())
		_top_lifts[role] = top
	return _top_lifts[role]

# Screen box around the anchor that covers the baked body at every heading (detail 1), so a click on any drawn pixel picks the unit.
static func pick_extent(kind: String) -> Rect2:
	var role: StringName = kind_info(kind)[0]
	if not _pick_extents.has(role):
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for part in Shapes.parts(role, 1).size():
			for bucket in Shapes.HEADING_BUCKETS:
				for point: Vector2 in Bake.mesh(role, part, bucket, 1).points:
					lo = lo.min(point)
					hi = hi.max(point)
		_pick_extents[role] = Rect2(lo, hi - lo)
	var extent: Rect2 = _pick_extents[role]
	return Rect2(extent.position + Vector2(0, -AIR_LIFT), extent.size) if kind_info(kind)[1] == LAYER_AIR else extent

static func objects(state: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for unit: Dictionary in state.get("entities", []):
		var heading: Array = unit.get("heading", [1.0, 0.0])
		var combat: Variant = unit.get("combat")
		var kind: String = unit.get("kind", "")
		var info: Array = kind_info(kind)
		found.append(_item(unit, kind, info[0], info[1], Vector2(unit.position[0], unit.position[1]), Vector2i.ONE, atan2(heading[1], heading[0]), 1.0, -1 if combat == null or combat.target_id == null else combat.target_id))
		found[-1].shadow = SHADOW_RADIUS if found[-1].layer == LAYER_AIR else GROUND_SHADOW_RADIUS
	for building: Dictionary in state.get("buildings", []):
		var definition: Dictionary = Economy.building(building.kind)
		if definition.is_empty(): continue
		var size: Vector2i = definition.footprint
		var rise: float = 1.0 if building.completed else float(building.work) / (definition.ticks * 1000)
		found.append(_item(building, building.kind, Shapes.role(building.kind), LAYER_GROUND, Vector2(building.origin[0], building.origin[1]) + Vector2(size) / 2.0, size, 0.0, rise, -1))
		found[-1].variant = damage_stage(found[-1].hp, found[-1].max_hp)
		var battery: Variant = building.get("combat")
		if battery != null and battery.target_id != null: found[-1].target_id = battery.target_id
	for source: Dictionary in state.get("sources", []):
		var size: Vector2i = Registry.source_footprint(source)
		var item := _item(source, "", &"supply_source", LAYER_GROUND, Vector2(source.origin[0], source.origin[1]) + Vector2(size) / 2.0, size, 0.0, 1.0, -1)
		item.boxes = source.get("boxes", 0)
		item.variant = Shapes.source_variant(item.boxes, size)
		found.append(item)
	return found

static func _item(row: Dictionary, kind: String, role: StringName, layer: int, anchor: Vector2, footprint: Vector2i, heading: float, rise: float, target_id: int) -> Dictionary:
	return {"id": row.id, "kind": kind, "owner": row.get("owner", 0), "role": role, "layer": layer, "anchor": anchor, "footprint": footprint, "heading": heading, "target_id": target_id, "hp": row.get("hp", 0), "max_hp": row.get("max_hp", 0), "rise": rise, "boxes": 0, "variant": 0, "shadow": 0.0}

# Integer percent maths: exactly 70 % and 35 % count as the worse stage.
static func damage_stage(hp: int, max_hp: int) -> int:
	if max_hp <= 0 or hp * 100 > max_hp * 70: return 0
	return 2 if hp * 100 <= max_hp * 35 else 1

static func sort_key(layer: int, anchor: Vector2, id: int) -> int:
	assert(id < (1 << ID_BITS))
	var depth: int = int(floor((anchor.x + anchor.y) * DEPTH_SCALE))
	return (layer << (ID_BITS + DEPTH_BITS)) | (depth << ID_BITS) | id

# Input is in id order, so equal depths keep id order like the old comparator.
static func depth_sorted(entities: Array) -> Array:
	assert(entities.size() < (1 << INDEX_BITS))
	var keys := PackedInt64Array()
	keys.resize(entities.size())
	for i in entities.size():
		var unit: Dictionary = entities[i]
		keys[i] = (sort_key(LAYER_GROUND, Vector2(unit.position[0], unit.position[1]), unit.id) << INDEX_BITS) | i
	keys.sort()
	var sorted: Array = []
	sorted.resize(keys.size())
	for i in keys.size():
		sorted[i] = entities[keys[i] & ((1 << INDEX_BITS) - 1)]
	return sorted

func build(items: Array[Dictionary], turret_angles: Dictionary, detail: int, flags: int, marks: Array[Vector2] = [], effects: Array[Dictionary] = []) -> void:
	points.clear()
	colors.clear()
	assert(items.size() < (1 << INDEX_BITS))
	var keys := PackedInt64Array()
	keys.resize(items.size())
	for i in items.size():
		var item: Dictionary = items[i]
		keys[i] = (sort_key(item.layer, item.anchor, item.id) << INDEX_BITS) | i
	keys.sort()
	var mask: int = (1 << INDEX_BITS) - 1
	if flags & FLAG_SHADOWS:
		var shadow_colors: PackedColorArray = _quad_colors_for(Palette.owner_colors(0)[Shapes.SLOT_SHADOW])
		for key in keys:
			var item: Dictionary = items[key & mask]
			if item.shadow > 0.0: _append_quad(Iso.world_to_plane(item.anchor), item.shadow, shadow_colors)
	for key in keys:
		_append_body(items[key & mask], detail, turret_angles)
	for effect in effects: _append_effect(effect)
	var mark_colors: PackedColorArray = _quad_colors_for(Color.WHITE)
	for mark in marks:
		_append_quad(mark, MARK_RADIUS, mark_colors)
	@warning_ignore("integer_division")
	triangle_count = points.size() / 3

func submit(item: RID) -> void:
	if points.is_empty(): return
	RenderingServer.canvas_item_add_triangle_array(item, PackedInt32Array(), points, colors)

func _append_body(item: Dictionary, detail: int, turret_angles: Dictionary) -> void:
	var move := Transform2D(0.0, Iso.world_to_plane(item.anchor) + Vector2(0, -AIR_LIFT if item.layer == LAYER_AIR else 0.0))
	var bucket: int = Bake.bucket(item.heading)
	var variant: int = item.variant if role_variants.is_empty() else item.variant | role_variants.get(item.role, 0)
	var turret_bucket: int = Bake.bucket(turret_angles[item.id]) if turret_angles.has(item.id) and _has_turret(item.role, detail, variant) else bucket
	var body: Dictionary = _body(item.role, detail, variant, bucket, turret_bucket)
	var mesh_points: PackedVector2Array = body.points
	var rise: float = item.rise
	if rise < 1.0:
		var lifts: PackedFloat32Array = body.lifts
		var lowered := PackedVector2Array(mesh_points)
		for i in lowered.size(): lowered[i].y += lifts[i] * (1.0 - rise)
		mesh_points = lowered
	points.append_array(move * mesh_points)
	colors.append_array(_mesh_colors(body, item.owner))

static func _has_turret(role: StringName, detail: int, variant: int) -> bool:
	var by_role: Dictionary = _turreted.get_or_add(role, {})
	var key: int = detail | (variant << 2)
	if not by_role.has(key):
		by_role[key] = Shapes.parts(role, detail, variant).any(func(part: Dictionary) -> bool: return part.angle == &"turret")
	return by_role[key]

# All parts of one object at one heading, concatenated in draw order.
static func _body(role: StringName, detail: int, variant: int, bucket: int, turret_bucket: int) -> Dictionary:
	var by_role: Dictionary = _bodies.get_or_add(role, {})
	var key: int = variant | (detail << 12) | (bucket << 14) | (turret_bucket << 20)
	if not by_role.has(key):
		if _body_count >= BODY_CACHE_CAP:
			_bodies.clear()
			_body_count = 0
			by_role = _bodies.get_or_add(role, {})
		var merged := {"points": PackedVector2Array(), "lifts": PackedFloat32Array(), "slots": PackedByteArray()}
		var specs: Array[Dictionary] = Shapes.parts(role, detail, variant)
		for part in specs.size():
			var mesh: Dictionary = Bake.mesh(role, part, turret_bucket if specs[part].angle == &"turret" else bucket, detail, variant, bucket)
			merged.points.append_array(mesh.points)
			merged.lifts.append_array(mesh.lifts)
			merged.slots.append_array(mesh.slots)
		by_role[key] = merged
		_body_count += 1
	return by_role[key]

# Cached on the merged body itself, so a dropped body drops its colours with it.
func _mesh_colors(mesh: Dictionary, owner: int) -> PackedColorArray:
	var by_owner: Dictionary = mesh.get_or_add("colors", {})
	var key: int = owner + (1000 if neutral_sides else 0) + (2000 if bright_owners else 0)
	if not by_owner.has(key):
		var palette: PackedColorArray = Palette.extended_colors(owner, neutral_sides, bright_owners)
		var slots: PackedByteArray = mesh.slots
		var built := PackedColorArray()
		built.resize(slots.size())
		for i in slots.size(): built[i] = palette[slots[i]]
		by_owner[key] = built
	return by_owner[key]

func _append_effect(effect: Dictionary) -> void:
	var at: Vector2 = Iso.world_to_plane(effect.anchor)
	var age: float = effect.age
	match effect.type:
		&"muzzle": _append_quad(at + Vector2(0, -MUZZLE_LIFT), maxf(6.0 - age, 2.0), _quad_colors_for(MUZZLE_COLOR))
		&"hit": _append_quad(at + Vector2(0, -8), 3.0 + age, _quad_colors_for(Color(HIT_COLOR, 1.0 - age / 6.0)))
		&"fade": _append_quad(at, 9.0, _quad_colors_for(Color(FADE_COLOR, 0.6 * (1.0 - age / Director.FADE_TICKS))))

static func _quad_colors_for(color: Color) -> PackedColorArray:
	if not _quad_colors.has(color):
		if _quad_colors.size() >= BODY_CACHE_CAP: _quad_colors.clear()
		_quad_colors[color] = PackedColorArray([color, color, color, color, color, color])
	return _quad_colors[color]

func _append_quad(center: Vector2, radius: float, quad_colors: PackedColorArray) -> void:
	if not _quads.has(radius):
		if _quads.size() >= BODY_CACHE_CAP: _quads.clear()
		var corners: Array[Vector2] = [Vector2(0, -radius), Vector2(radius, 0), Vector2(0, radius), Vector2(-radius, 0)]
		_quads[radius] = PackedVector2Array([corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]])
	points.append_array(Transform2D(0.0, center) * _quads[radius])
	colors.append_array(quad_colors)
