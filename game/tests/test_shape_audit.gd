@warning_ignore_start("untyped_declaration")
extends RefCounted

const Shapes = preload("res://scripts/presentation/shapes.gd")
const Bake = preload("res://scripts/presentation/shape_bake.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")

# Rules from the shape audit (wargrid-art-work/shape-audit.md, 2026-11-10).
# Ground units: parts that turn with the hull stay inside r 0.5 of the anchor, so an identical unit one cell away never overlaps them;
# a turret part (cannon, barrel) may reach 0.75, short of the neighbour's centre.
const HULL_RADIUS := 0.5
const TURRET_RADIUS := 0.75
const AIR_RADIUS := 0.65
const FOOTPRINT_SLACK := 0.001
const GROUND_UNITS: Array[StringName] = [&"light_vehicle", &"bulldozer", &"collector_truck", &"tank_usa", &"tank_china", &"tank_china_gatling", &"tank_frc", &"infantry", &"laborer", &"rocket_infantry"]
const BUILDINGS := {&"power_plant": 2, &"war_factory": 3, &"supply_depot": 3, &"command_center": 3, &"barracks": 2, &"defence_usa": 1, &"defence_china": 1, &"defence_frc": 1, &"rubble_1": 1, &"rubble_2": 2, &"rubble_3": 3}
const DEPTH_EPSILON := 0.02
const STEP := 1.0
const OWNER_SLOTS: Array[int] = [Shapes.SLOT_ROOF, Shapes.SLOT_ROOF_DARK, Shapes.SLOT_GLOW]

func cases() -> Array[Callable]:
	return [test_units_fit_one_cell, test_buildings_stay_in_footprint, test_identity_at_every_detail, test_painter_order_matches_depth, test_owner_colour_share, test_weapons_and_distinct_silhouettes]

func _world(mesh: Dictionary) -> PackedVector2Array:
	var found := PackedVector2Array()
	for i in mesh.points.size():
		found.append(Iso.plane_to_world(mesh.points[i] + Vector2(0, mesh.lifts[i])))
	return found

func _radius(points: PackedVector2Array) -> float:
	var far: float = 0.0
	for point in points:
		far = maxf(far, point.length())
	return far

func test_units_fit_one_cell(runner) -> bool:
	for role: StringName in GROUND_UNITS + [&"helicopter" as StringName]:
		var worst_hull: float = 0.0
		var worst_turret: float = 0.0
		for detail in 3:
			var specs: Array[Dictionary] = Shapes.parts(role, detail)
			for part in specs.size():
				for bucket in Shapes.HEADING_BUCKETS:
					var reach: float = _radius(_world(Bake.mesh(role, part, bucket, detail)))
					if specs[part].angle == &"turret": worst_turret = maxf(worst_turret, reach)
					else: worst_hull = maxf(worst_hull, reach)
		var hull_limit: float = AIR_RADIUS if role == &"helicopter" else HULL_RADIUS
		runner.check(worst_hull > 0.0 and worst_hull <= hull_limit + FOOTPRINT_SLACK, "SA1 %s hull parts stay within %.2f of the anchor at every detail and heading, got %.3f" % [role, hull_limit, worst_hull])
		runner.check(worst_turret <= TURRET_RADIUS + FOOTPRINT_SLACK, "SA1 %s turret parts stay within %.2f, got %.3f" % [role, TURRET_RADIUS, worst_turret])
	return true

func test_buildings_stay_in_footprint(runner) -> bool:
	for role: StringName in BUILDINGS:
		var half: float = BUILDINGS[role] / 2.0
		var worst: float = 0.0
		var present: int = 0
		for variant in 3:
			for detail in 3:
				var specs: Array[Dictionary] = Shapes.parts(role, detail, variant)
				for part in specs.size():
					for bucket in (Shapes.HEADING_BUCKETS if specs[part].angle == &"turret" else 1):
						for point in _world(Bake.mesh(role, part, bucket, detail, variant)):
							present += 1
							worst = maxf(worst, point.length() if specs[part].angle == &"turret" else maxf(absf(point.x), absf(point.y)))
		runner.check(present > 0 and worst <= half + FOOTPRINT_SLACK, "SA2 %s stays inside its footprint (half %.1f), got %.3f" % [role, half, worst])
	return true

func _signature(role: StringName, detail: int, variant: int) -> Array:
	return Shapes.parts(role, detail, variant).map(func(part: Dictionary) -> Array: return [part.name, part.prims.size()])

func test_identity_at_every_detail(runner) -> bool:
	for role: StringName in GROUND_UNITS + BUILDINGS.keys() + [&"helicopter" as StringName]:
		for variant in 3:
			var low: Array = _signature(role, 0, variant)
			runner.check(low == _signature(role, 1, variant) and low == _signature(role, 2, variant), "SA3 %s variant %d keeps every part and prim from detail 0 to 2" % [role, variant])
	return true

# Triangles of one baked body in draw order, with the depth (x + y of the ground point, toward the camera) at each vertex.
func _triangles(role: StringName, detail: int, variant: int, bucket: int, turret_bucket: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var specs: Array[Dictionary] = Shapes.parts(role, detail, variant)
	for part in specs.size():
		var mesh: Dictionary = Bake.mesh(role, part, turret_bucket if specs[part].angle == &"turret" else bucket, detail, variant)
		var world: PackedVector2Array = _world(mesh)
		for i in range(0, mesh.points.size(), 3):
			found.append({"part": part, "slot": mesh.slots[i], "p": [mesh.points[i], mesh.points[i + 1], mesh.points[i + 2]], "d": [world[i].x + world[i].y, world[i + 1].x + world[i + 1].y, world[i + 2].x + world[i + 2].y]})
	return found

# Painter result against the nearest surface: wrong samples show a surface that sits behind another yet is painted over it.
func _raster(triangles: Array[Dictionary], parts: int) -> Dictionary:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for tri in triangles:
		for point: Vector2 in tri.p:
			lo = lo.min(point)
			hi = hi.max(point)
	var width: int = ceili((hi.x - lo.x) / STEP) + 1
	var height: int = ceili((hi.y - lo.y) / STEP) + 1
	var painter := PackedInt32Array()
	painter.resize(width * height)
	painter.fill(-1)
	var near := PackedInt32Array(painter)
	var near_depth := PackedFloat32Array()
	near_depth.resize(width * height)
	for index in triangles.size():
		var tri: Dictionary = triangles[index]
		var a: Vector2 = tri.p[0]
		var b: Vector2 = tri.p[1]
		var c: Vector2 = tri.p[2]
		var den: float = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
		if absf(den) < 1e-9: continue
		var from := Vector2i(floori((minf(a.x, minf(b.x, c.x)) - lo.x) / STEP), floori((minf(a.y, minf(b.y, c.y)) - lo.y) / STEP))
		var to := Vector2i(ceili((maxf(a.x, maxf(b.x, c.x)) - lo.x) / STEP), ceili((maxf(a.y, maxf(b.y, c.y)) - lo.y) / STEP))
		for iy in range(maxi(from.y, 0), mini(to.y, height - 1) + 1):
			var py: float = lo.y + (iy + 0.5) * STEP
			for ix in range(maxi(from.x, 0), mini(to.x, width - 1) + 1):
				var px: float = lo.x + (ix + 0.5) * STEP
				var l0: float = ((b.y - c.y) * (px - c.x) + (c.x - b.x) * (py - c.y)) / den
				var l1: float = ((c.y - a.y) * (px - c.x) + (a.x - c.x) * (py - c.y)) / den
				var l2: float = 1.0 - l0 - l1
				if l0 < -1e-6 or l1 < -1e-6 or l2 < -1e-6: continue
				var depth: float = l0 * tri.d[0] + l1 * tri.d[1] + l2 * tri.d[2]
				var cell: int = iy * width + ix
				painter[cell] = index
				if near[cell] < 0 or depth > near_depth[cell]:
					near[cell] = index
					near_depth[cell] = depth
	var wrong: int = 0
	var drawn: int = 0
	var owner_pixels: int = 0
	var seen := PackedInt32Array()
	seen.resize(parts)
	var shown := PackedInt32Array(seen)
	for cell in painter.size():
		if painter[cell] < 0: continue
		var top: Dictionary = triangles[painter[cell]]
		var nearest: Dictionary = triangles[near[cell]]
		drawn += 1
		if OWNER_SLOTS.has(top.slot): owner_pixels += 1
		seen[nearest.part] += 1
		shown[top.part] += 1
		if painter[cell] != near[cell] and top.slot != nearest.slot and near_depth[cell] - _depth_at(top, lo + Vector2((cell % width + 0.5) * STEP, (floori(cell / float(width)) + 0.5) * STEP)) > DEPTH_EPSILON:
			wrong += 1
	var covered: Array[int] = []
	for part in parts:
		if seen[part] > 0 and shown[part] == 0: covered.append(part)
	return {"wrong": wrong, "drawn": drawn, "owner": owner_pixels, "covered": covered}

func _depth_at(tri: Dictionary, at: Vector2) -> float:
	var a: Vector2 = tri.p[0]
	var b: Vector2 = tri.p[1]
	var c: Vector2 = tri.p[2]
	var den: float = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
	var l0: float = ((b.y - c.y) * (at.x - c.x) + (c.x - b.x) * (at.y - c.y)) / den
	var l1: float = ((c.y - a.y) * (at.x - c.x) + (a.x - c.x) * (at.y - c.y)) / den
	return l0 * tri.d[0] + l1 * tri.d[1] + (1.0 - l0 - l1) * tri.d[2]

func _cases_for_depth() -> Array[Array]:
	var found: Array[Array] = []
	for role: StringName in GROUND_UNITS + [&"helicopter" as StringName]:
		for detail in [0, 2]:
			for bucket in [0, 32]:
				found.append([role, detail, 0, bucket, bucket])
				if role in [&"tank_usa", &"tank_china", &"tank_china_gatling", &"tank_frc", &"light_vehicle"]: found.append([role, detail, 0, bucket, (bucket + 16) % 64])
	for role: StringName in BUILDINGS:
		for variant in (3 if not String(role).begins_with("rubble") else 1):
			for detail in [0, 2]:
				found.append([role, detail, variant, 0, 0])
	for footprint in [Vector2i(4, 5), Vector2i(2, 2), Vector2i(1, 1)]:
		for boxes in [0, 1, 5, 15, 40]:
			found.append([&"supply_source", 2, Shapes.source_variant(boxes, footprint), 0, 0])
	return found

func test_painter_order_matches_depth(runner) -> bool:
	for job in _cases_for_depth():
		var triangles: Array[Dictionary] = _triangles(job[0], job[1], job[2], job[3], job[4])
		var found: Dictionary = _raster(triangles, Shapes.parts(job[0], job[1], job[2]).size())
		var label := "%s detail %d variant %d bucket %d/%d" % [job[0], job[1], job[2], job[3], job[4]]
		runner.check(found.wrong == 0, "SA4 %s has no surface painted over one in front of it, got %d samples" % [label, found.wrong])
		runner.check(found.covered.is_empty(), "SA4 %s has no part hidden entirely by later parts, got %s" % [label, found.covered])
	return true

func _owner_share(role: StringName, detail: int) -> float:
	var total: float = 0.0
	for bucket in [0, 8, 16, 24, 32, 40, 48, 56]:
		var found: Dictionary = _raster(_triangles(role, detail, 0, bucket, bucket), Shapes.parts(role, detail).size())
		total += float(found.owner) / maxf(found.drawn, 1)
	return total / 8.0

func test_owner_colour_share(runner) -> bool:
	var floors := {&"infantry": 0.3, &"laborer": 0.3, &"rocket_infantry": 0.2, &"tank_usa": 0.28, &"tank_china": 0.28, &"tank_china_gatling": 0.28, &"tank_frc": 0.28}
	for role: StringName in floors:
		for detail in [0, 2]:
			var share: float = _owner_share(role, detail)
			runner.check(share >= floors[role], "SA5 %s detail %d shows at least %d%% owner colour, got %.1f%%" % [role, detail, floors[role] * 100.0, share * 100.0])
	return true

func _all_prims(role: StringName) -> Array:
	var found: Array = []
	for part: Dictionary in Shapes.parts(role, 0):
		found.append_array(part.prims)
	return found

func _signature_of_role(role: StringName) -> String:
	return str(Shapes.parts(role, 0).map(func(part: Dictionary) -> Array: return part.prims.map(func(prim: Dictionary) -> Array: return [prim.offset, prim.size, prim.slot])))

func test_weapons_and_distinct_silhouettes(runner) -> bool:
	for role: StringName in [&"infantry", &"rocket_infantry"]:
		var guns: Array = _all_prims(role).filter(func(prim: Dictionary) -> bool: return prim.slot == Shapes.SLOT_MACHINE and prim.size.x >= 0.2 and prim.size.y <= 0.1)
		runner.check(guns.size() == 1, "SA6 %s carries one long thin weapon that shows the heading" % role)
		if role == &"rocket_infantry" and guns.size() == 1:
			var launcher: Dictionary = guns[0]
			runner.check(absf(launcher.offset.y) - launcher.size.y / 2.0 <= 0.08 and launcher.size.x < 0.4, "SA6 the launcher touches the soldier's torso and is shorter than 0.4 cell")
	var distinct: Array = [[&"tank_china", &"tank_china_gatling"], [&"infantry", &"laborer"], [&"defence_usa", &"defence_china"], [&"defence_usa", &"defence_frc"], [&"defence_china", &"defence_frc"]]
	for pair: Array in distinct:
		runner.check(_signature_of_role(pair[0]) != _signature_of_role(pair[1]), "SA7 %s and %s have different silhouettes" % pair)
	runner.check(Shapes.role("china_tank") == &"tank_china_gatling" and Shapes.role("china_light_vehicle") == &"tank_china", "SA7 the Rotary Gun Tank and the Medium Tank map to different roles")
	runner.check(Shapes.role("frc_builder") == &"laborer" and Shapes.role("usa_defence") == &"defence_usa" and Shapes.role("china_defence") == &"defence_china" and Shapes.role("frc_defence") == &"defence_frc", "SA7 laborer and each faction's defence have their own role")
	return true
