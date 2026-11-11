extends RefCounted

const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Economy = preload("res://scripts/simulation/economy_definitions.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Shapes = preload("res://scripts/presentation/shapes.gd")
const Bake = preload("res://scripts/presentation/shape_bake.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const Director = preload("res://scripts/presentation/visual_director.gd")
const ViewRows = preload("res://scripts/simulation/view_rows.gd")

const LAYER_GROUND := 1
const LAYER_AIR := 2
const DEPTH_SCALE := 1024.0
const ID_BITS := 20
const DEPTH_BITS := 22
const INDEX_BITS := 16
const BODY_CACHE_CAP := 4096
const AIR_LIFT := 30.0
const SHADOW_RADIUS := 8.0
const GROUND_SHADOW_RADIUS := 6.0
const RING_RADIUS := Vector2(11.0, 5.5)
const RING_WIDTH := Vector2(2.0, 1.0)
const RING_SEGMENTS := 8
const RING_FILL_ALPHA := 0.25
const RING_LINE_ALPHA := 0.9
const DASH_COLOR := Color("fff2b0")
const DASH_HALF_LENGTH := 6.0
const DASH_HALF_WIDTH := 1.0
const DASH_FROM_LIFT := 16.0
const DASH_TO_LIFT := 8.0
const PIVOT_PICK_MARGIN := 3.0
const MUZZLE_LIFT := 16.0
const MUZZLE_COLOR := Color("ffe680")
const HIT_COLOR := Color("ff8a3c")
const FADE_COLOR := Color("1c1a18")
const INFANTRY_ROLES := [&"infantry", &"rocket_infantry", &"laborer"]

var points := PackedVector2Array()
var colors := PackedColorArray()
var triangle_count: int = 0
# Neon mode: a brighter set of owner hues.
var bright_owners: bool = false

static var _top_lifts: Dictionary = {}
static var _pick_extents: Dictionary = {}
static var _kind_info: Dictionary = {}
static var _kind_air: Dictionary = {}
static var _bodies: Dictionary = {}
static var _body_count: int = 0
static var _quads: Dictionary = {}
static var _quad_colors: Dictionary = {}
static var _ring_mesh := PackedVector2Array()
static var _ring_colors: Dictionary = {}

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
		var extent := Rect2(lo, hi - lo)
		# shortcut: a margin instead of sweeping every hull-by-turret pose (4096 bakes); measured overshoot is under 2 px.
		if Shapes.parts(role, 1).any(func(part: Dictionary) -> bool: return part.pivot != Vector2.ZERO): extent = extent.grow(PIVOT_PICK_MARGIN)
		_pick_extents[role] = extent
	var extent: Rect2 = _pick_extents[role]
	return Rect2(extent.position + Vector2(0, -AIR_LIFT), extent.size) if kind_info(kind)[1] == LAYER_AIR else extent

static func objects(state: Dictionary) -> Array[Dictionary]:
	var rows: ViewRows = ViewRows.from_units(state.get("entities", []))
	var found: Array[Dictionary] = []
	for i in rows.size():
		var item := {}
		write_unit_item(item, rows, i)
		found.append(item)
	found.append_array(structure_items(state))
	return found

# Rewrites every per-tick field; the kind-derived ones only when the kind changed, so one item can live across ticks.
static func write_unit_item(item: Dictionary, rows: ViewRows, i: int) -> void:
	var kind: String = rows.kinds[rows.kind[i]]
	if item.get("kind") != kind:
		var info: Array = kind_info(kind)
		item.kind = kind
		item.role = info[0]
		item.layer = info[1]
		item.shadow = SHADOW_RADIUS if info[1] == LAYER_AIR else GROUND_SHADOW_RADIUS
		item.footprint = Vector2i.ONE
		item.rise = 1.0
		item.boxes = 0
		item.variant = 0
	item.id = rows.id[i]
	item.owner = rows.owner[i]
	item.anchor = Vector2(rows.x[i], rows.y[i])
	item.heading = atan2(rows.heading_y[i], rows.heading_x[i])
	item.target_id = rows.target[i]
	item.hp = rows.hp[i]
	item.max_hp = rows.max_hp[i]
	item.horde = (rows.flags[i] & ViewRows.HORDE) != 0

static func structure_items(state: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
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
	return {"id": row.id, "kind": kind, "owner": row.get("owner", 0), "role": role, "layer": layer, "anchor": anchor, "footprint": footprint, "heading": heading, "target_id": target_id, "hp": row.get("hp", 0), "max_hp": row.get("max_hp", 0), "rise": rise, "boxes": 0, "variant": 0, "shadow": 0.0, "horde": false}

# Integer percent maths: exactly 70 % and 35 % count as the worse stage.
static func damage_stage(hp: int, max_hp: int) -> int:
	if max_hp <= 0 or hp * 100 > max_hp * 70: return 0
	return 2 if hp * 100 <= max_hp * 35 else 1

static func sort_key(layer: int, anchor: Vector2, id: int) -> int:
	assert(id < (1 << ID_BITS))
	var depth: int = int(floor((anchor.x + anchor.y) * DEPTH_SCALE))
	return (layer << (ID_BITS + DEPTH_BITS)) | (depth << ID_BITS) | id

# Row indices in draw order; equal depths keep id order because rows are in id order.
static func depth_order(rows: ViewRows) -> PackedInt32Array:
	assert(rows.size() < (1 << INDEX_BITS))
	var keys := PackedInt64Array()
	keys.resize(rows.size())
	for i in rows.size():
		keys[i] = (sort_key(LAYER_GROUND, Vector2(rows.x[i], rows.y[i]), rows.id[i]) << INDEX_BITS) | i
	keys.sort()
	var order := PackedInt32Array()
	order.resize(keys.size())
	for i in keys.size(): order[i] = keys[i] & ((1 << INDEX_BITS) - 1)
	return order

func build(items: Array[Dictionary], turret_angles: Dictionary, detail: int, shadows: bool, effects: Array[Dictionary] = []) -> void:
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
	var shadow_colors: PackedColorArray = _quad_colors_for(Palette.SHADOW)
	for key in keys:
		var item: Dictionary = items[key & mask]
		if shadows and item.shadow > 0.0: _append_quad(Iso.world_to_plane(item.anchor), item.shadow, shadow_colors)
		if item.horde: _append_ring(Iso.world_to_plane(item.anchor), item.owner)
	for key in keys:
		_append_body(items[key & mask], detail, turret_angles)
	for effect in effects: _append_effect(effect)
	@warning_ignore("integer_division")
	triangle_count = points.size() / 3

func submit(item: RID) -> void:
	if points.is_empty(): return
	RenderingServer.canvas_item_add_triangle_array(item, PackedInt32Array(), points, colors)

func _append_body(item: Dictionary, detail: int, turret_angles: Dictionary) -> void:
	var move := Transform2D(0.0, Iso.world_to_plane(item.anchor) + Vector2(0, -AIR_LIFT if item.layer == LAYER_AIR else 0.0))
	var bucket: int = Bake.bucket(item.heading)
	var variant: int = item.variant
	var turret_bucket: int = Bake.bucket(turret_angles[item.id]) if turret_angles.has(item.id) and Shapes.has_turret(item.role) else bucket
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
	var key: int = owner + (1000 if bright_owners else 0)
	if not by_owner.has(key):
		var palette: PackedColorArray = Palette.owner_colors(owner, bright_owners)
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
		&"dash": _append_dash(at + Vector2(0, -DASH_FROM_LIFT), Iso.world_to_plane(effect.to) + Vector2(0, -DASH_TO_LIFT), (age + 1.0) / (Director.DASH_TICKS + 1))

# A short bright streak on its way from the attacker to the target, as one quad.
func _append_dash(from: Vector2, to: Vector2, along: float) -> void:
	var centre: Vector2 = from.lerp(to, along)
	var direction: Vector2 = (to - from).normalized()
	var half: Vector2 = direction * DASH_HALF_LENGTH
	var side: Vector2 = direction.orthogonal() * DASH_HALF_WIDTH
	var a: Vector2 = centre - half - side
	var b: Vector2 = centre + half - side
	var c: Vector2 = centre + half + side
	var d: Vector2 = centre - half + side
	points.append_array(PackedVector2Array([a, b, c, a, c, d]))
	colors.append_array(_quad_colors_for(DASH_COLOR))

# A flat ellipse under the unit: translucent fill, then a thin ring, 24 triangles in all.
func _append_ring(centre: Vector2, owner: int) -> void:
	if _ring_mesh.is_empty(): _ring_mesh = _build_ring()
	points.append_array(Transform2D(0.0, centre) * _ring_mesh)
	var key: int = owner + (1000 if bright_owners else 0)
	if not _ring_colors.has(key):
		var base: Color = Palette.owner_colors(owner, bright_owners)[0]
		var built := PackedColorArray()
		for i in RING_SEGMENTS * 3: built.append(Color(base, RING_FILL_ALPHA))
		for i in RING_SEGMENTS * 6: built.append(Color(base, RING_LINE_ALPHA))
		_ring_colors[key] = built
	colors.append_array(_ring_colors[key])

static func _build_ring() -> PackedVector2Array:
	var mesh := PackedVector2Array()
	var inner: Vector2 = RING_RADIUS - RING_WIDTH
	for i in RING_SEGMENTS:
		var a: float = TAU * i / RING_SEGMENTS
		var b: float = TAU * (i + 1) / RING_SEGMENTS
		var outer_a := Vector2(cos(a), sin(a)) * RING_RADIUS
		var outer_b := Vector2(cos(b), sin(b)) * RING_RADIUS
		mesh.append_array(PackedVector2Array([Vector2.ZERO, outer_a, outer_b]))
	for i in RING_SEGMENTS:
		var a: float = TAU * i / RING_SEGMENTS
		var b: float = TAU * (i + 1) / RING_SEGMENTS
		var outer_a := Vector2(cos(a), sin(a)) * RING_RADIUS
		var outer_b := Vector2(cos(b), sin(b)) * RING_RADIUS
		var inner_a := Vector2(cos(a), sin(a)) * inner
		var inner_b := Vector2(cos(b), sin(b)) * inner
		mesh.append_array(PackedVector2Array([inner_a, outer_a, outer_b, inner_a, outer_b, inner_b]))
	return mesh

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
