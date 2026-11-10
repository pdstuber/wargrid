extends RefCounted

const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Economy = preload("res://scripts/simulation/economy_definitions.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Shapes = preload("res://scripts/presentation/shapes.gd")
const Bake = preload("res://scripts/presentation/shape_bake.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const Director = preload("res://scripts/presentation/visual_director.gd")

const LAYER_DECAL := 0
const LAYER_GROUND := 1
const LAYER_AIR := 2
const DEPTH_SCALE := 1024.0
const ID_BITS := 20
const DEPTH_BITS := 22
const AIR_LIFT := 18.0
const SHADOW_RADIUS := 8.0
const MARK_RADIUS := 3.0
const GROUND_SHADOW_RADIUS := 6.0
const MUZZLE_LIFT := 12.0
const MUZZLE_COLOR := Color("ffe680")
const HIT_COLOR := Color("ff8a3c")
const FADE_COLOR := Color("1c1a18")
const FLAG_SHADOWS := GraphicsSettings.FLAG_SHADOWS
const FLAG_OUTLINES := GraphicsSettings.FLAG_OUTLINES
const FLAG_EFFECTS := GraphicsSettings.FLAG_EFFECTS

var points := PackedVector2Array()
var colors := PackedColorArray()
var triangle_count: int = 0

static func objects(state: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for unit: Dictionary in state.get("entities", []):
		var heading: Array = unit.get("heading", [1.0, 0.0])
		var combat: Variant = unit.get("combat")
		var kind: String = unit.get("kind", "")
		found.append(_item(unit, kind, Shapes.role(kind), LAYER_AIR if Registry.air_kinds.has(kind) else LAYER_GROUND, Vector2(unit.position[0], unit.position[1]), Vector2i.ONE, atan2(heading[1], heading[0]), 1.0, -1 if combat == null or combat.target_id == null else combat.target_id))
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
	var keys := PackedInt64Array()
	keys.resize(entities.size())
	var by_key := {}
	for i in entities.size():
		var unit: Dictionary = entities[i]
		keys[i] = sort_key(LAYER_GROUND, Vector2(unit.position[0], unit.position[1]), unit.id)
		by_key[keys[i]] = unit
	keys.sort()
	var sorted: Array = []
	sorted.resize(keys.size())
	for i in keys.size():
		sorted[i] = by_key[keys[i]]
	return sorted

func build(items: Array[Dictionary], turret_angles: Dictionary, detail: int, flags: int, marks: Array[Vector2] = [], effects: Array[Dictionary] = []) -> void:
	points.clear()
	colors.clear()
	var keys := PackedInt64Array()
	var by_key := {}
	for item in items:
		var key: int = sort_key(item.layer, item.anchor, item.id)
		keys.append(key)
		by_key[key] = item
	keys.sort()
	if flags & FLAG_SHADOWS:
		for key in keys:
			if by_key[key].shadow > 0.0: _append_shadow(by_key[key])
	for key in keys:
		_append_body(by_key[key], detail, turret_angles)
	for effect in effects: _append_effect(effect)
	for mark in marks:
		_append_quad(mark, MARK_RADIUS, Color.WHITE)
	@warning_ignore("integer_division")
	triangle_count = points.size() / 3

func submit(item: RID) -> void:
	if points.is_empty(): return
	RenderingServer.canvas_item_add_triangle_array(item, PackedInt32Array(), points, colors)

func _append_body(item: Dictionary, detail: int, turret_angles: Dictionary) -> void:
	var owner: int = item.owner
	var move := Transform2D(0.0, Iso.world_to_plane(item.anchor) + Vector2(0, -AIR_LIFT if item.layer == LAYER_AIR else 0.0))
	var bucket: int = Bake.bucket(item.heading)
	var rise: float = item.rise
	var specs: Array[Dictionary] = Shapes.parts(item.role, detail, item.variant)
	var turret_bucket: int = Bake.bucket(turret_angles[item.id]) if turret_angles.has(item.id) else bucket
	for part in specs.size():
		var mesh: Dictionary = Bake.mesh(item.role, part, turret_bucket if specs[part].name == &"turret" else bucket, detail, item.variant)
		var mesh_points: PackedVector2Array = mesh.points
		if rise < 1.0:
			var lifts: PackedFloat32Array = mesh.lifts
			var lowered := PackedVector2Array(mesh_points)
			for i in lowered.size(): lowered[i].y += lifts[i] * (1.0 - rise)
			mesh_points = lowered
		points.append_array(move * mesh_points)
		colors.append_array(_mesh_colors(mesh, owner))

# Cached on the baked mesh itself, so a rebaked mesh drops its colours with it.
func _mesh_colors(mesh: Dictionary, owner: int) -> PackedColorArray:
	var by_owner: Dictionary = mesh.get_or_add("colors", {})
	if not by_owner.has(owner):
		var palette: PackedColorArray = Palette.owner_colors(owner)
		var slots: PackedByteArray = mesh.slots
		var built := PackedColorArray()
		built.resize(slots.size())
		for i in slots.size(): built[i] = palette[slots[i]]
		by_owner[owner] = built
	return by_owner[owner]

func _append_effect(effect: Dictionary) -> void:
	var at: Vector2 = Iso.world_to_plane(effect.anchor)
	var age: float = effect.age
	match effect.type:
		&"muzzle": _append_quad(at + Vector2(0, -MUZZLE_LIFT), maxf(6.0 - age, 2.0), MUZZLE_COLOR)
		&"hit": _append_quad(at + Vector2(0, -8), 3.0 + age, Color(HIT_COLOR, 1.0 - age / 6.0))
		&"fade": _append_quad(at, 9.0, Color(FADE_COLOR, 0.6 * (1.0 - age / Director.FADE_TICKS)))

func _append_shadow(item: Dictionary) -> void:
	_append_quad(Iso.world_to_plane(item.anchor), item.shadow, Palette.owner_colors(0)[Shapes.SLOT_SHADOW])

func _append_quad(center: Vector2, radius: float, color: Color) -> void:
	var corners: Array[Vector2] = [center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]
	for index: int in [0, 1, 2, 0, 2, 3]:
		points.append(corners[index])
		colors.append(color)
