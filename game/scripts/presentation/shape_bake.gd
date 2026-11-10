extends RefCounted

const Iso = preload("res://scripts/presentation/isometric.gd")
const Shapes = preload("res://scripts/presentation/shapes.gd")

static var bake_count: int = 0
static var _cache: Dictionary = {}

static func bucket(angle: float) -> int:
	return posmod(roundi(angle / TAU * Shapes.HEADING_BUCKETS), Shapes.HEADING_BUCKETS)

static func mesh(role: StringName, part: int, bucket_index: int, detail: int, variant: int = 0) -> Dictionary:
	var key := "%s/%d/%d/%d/%d" % [role, part, bucket_index, detail, variant]
	if not _cache.has(key):
		_cache[key] = _bake(role, part, bucket_index, detail)
		bake_count += 1
	return _cache[key]

static func _bake(role: StringName, part: int, bucket_index: int, detail: int) -> Dictionary:
	var out := {"points": PackedVector2Array(), "slots": PackedByteArray(), "lifts": PackedFloat32Array()}
	var spec: Dictionary = Shapes.parts(role, detail)[part]
	var angle: float = 0.0 if spec.angle == &"fixed" else bucket_index * TAU / Shapes.HEADING_BUCKETS
	var pivot: Vector3 = spec.pivot
	for prim: Dictionary in spec.prims:
		var size: Vector3 = prim.size
		var corners := PackedVector2Array()
		if prim.type == &"cylinder":
			var segments: int = [4, 6, 8][clampi(detail, 0, 2)]
			for i in segments:
				var a: float = TAU * (i + 0.5) / segments
				corners.append(Vector2(cos(a), sin(a)) * size.x / 2.0)
		else:
			var half := Vector2(size.x, size.y) / 2.0
			corners = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])
		var offset: Vector3 = prim.offset
		var ring := PackedVector2Array()
		for corner in corners:
			var local := Vector2(offset.x, offset.y) + corner
			ring.append(Vector2(pivot.x, pivot.y) + (local - Vector2(pivot.x, pivot.y)).rotated(angle))
		_append_prim(out, ring, offset.z, size.z, prim.slot)
	return out

static func _append_prim(out: Dictionary, ring: PackedVector2Array, base: float, height: float, slot: int) -> void:
	var top: float = base + height
	for i in range(1, ring.size() - 1):
		_tri(out, [ring[0], ring[i], ring[i + 1]], top, slot)
	var side_slots: Array[int] = [slot, slot]
	if slot == Shapes.SLOT_ROOF:
		side_slots = [Shapes.SLOT_SIDE, Shapes.SLOT_SIDE_DARK]
	for i in ring.size():
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % ring.size()]
		var normal: Vector2 = (b - a).rotated(-PI / 2.0)
		if normal.x + normal.y <= 0.0:
			continue
		var side_slot: int = side_slots[0] if normal.x - normal.y < 0.0 else side_slots[1]
		_tri(out, [a, b, b], base, side_slot, [top, top, base])
		_tri(out, [a, b, a], base, side_slot, [top, base, base])

# Side triangles pass a lift per vertex; flat faces use one lift.
static func _tri(out: Dictionary, cells: Array, lift: float, slot: int, lifts: Array = []) -> void:
	for i in 3:
		var v_lift: float = lift if lifts.is_empty() else lifts[i]
		var cell: Vector2 = cells[i]
		var point: Vector2 = Iso.world_to_plane(cell)
		point.y -= v_lift
		out.points.append(point)
		out.slots.append(slot)
		out.lifts.append(v_lift)
