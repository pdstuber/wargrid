@warning_ignore_start("untyped_declaration")
extends RefCounted

const Shapes = preload("res://scripts/presentation/shapes.gd")
const Bake = preload("res://scripts/presentation/shape_bake.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Definitions = preload("res://scripts/simulation/definitions/definitions.gd")
const TURRET_OFFSET := {&"tank_frc": 0.055}
const TANK_ROLES: Array[StringName] = [&"tank_usa", &"tank_china", &"tank_china_gatling", &"tank_frc"]
const Z: float = 3.5
const PRIM_SLOTS: Array[int] = [Shapes.SLOT_ROOF, Shapes.SLOT_ROOF_DARK, Shapes.SLOT_SIDE, Shapes.SLOT_SIDE_DARK, Shapes.SLOT_MACHINE, Shapes.SLOT_GLOW, Shapes.SLOT_SMOKE, Shapes.SLOT_OWNER_FLAT, Shapes.SLOT_SKIN]

func cases() -> Array[Callable]:
	return [test_bucket_wraps, test_box_top_face_on_top, test_bake_is_cached, test_unknown_kind_gets_default_role, test_owner_palette_eight, test_lab_roles_mapped, test_damage_stage_changes_geometry, test_turret_pivot_on_hull_top, test_offset_turret_pivot_follows_hull, test_no_kind_uses_default_role, test_roster_shares_slots, test_unit_heights, test_hulls_fit_one_cell, test_tracks_deck_and_cannon, test_neutral_faces, test_infantry_narrow_with_head, test_prims_sorted_per_heading, test_cylinder_segments_by_detail, test_back_faces_not_baked]

func test_bucket_wraps(runner) -> bool:
	runner.check(Bake.bucket(0.0) == 0, "SH1 zero")
	runner.check(Bake.bucket(TAU) == 0, "SH1 TAU wraps to 0")
	runner.check(Bake.bucket(-TAU / 64.0) == 63, "SH1 negative step")
	return true

func test_box_top_face_on_top(runner) -> bool:
	var mesh: Dictionary = Bake.mesh(&"default_building", 0, 0, 2)
	var points: PackedVector2Array = mesh.points
	var min_y: float = 1e9
	var top_slot: int = -1
	for i in points.size():
		if points[i].y < min_y:
			min_y = points[i].y
			top_slot = mesh.slots[i]
	runner.check(is_equal_approx(min_y, -32.0 - 49.0), "SH2 back corner lifted 49 px (14 units x 3.5) above its ground corner")
	runner.check(top_slot == Shapes.SLOT_ROOF, "SH2 topmost vertex is roof")
	runner.check(mesh.lifts.size() == points.size() and mesh.slots.size() == points.size(), "SH2 parallel arrays")
	runner.check(Array(mesh.lifts).max() == 49.0 and Array(mesh.lifts).min() == 0.0, "SH2 lifts span 0..49")
	return true

func test_bake_is_cached(runner) -> bool:
	var before: int = Bake.bake_count
	var first: Dictionary = Bake.mesh(&"default_vehicle", 0, 7, 1, 4001)
	var second: Dictionary = Bake.mesh(&"default_vehicle", 0, 7, 1, 4001)
	runner.check(first.points == second.points and first.slots == second.slots, "SH3 equal content")
	runner.check(Bake.bake_count == before + 1, "SH3 baked once")
	return true

func test_unknown_kind_gets_default_role(runner) -> bool:
	var role: StringName = Shapes.role("no_such_kind")
	runner.check(role == &"default_vehicle" and not Shapes.parts(role, 0).is_empty(), "SH4 default role with parts")
	return true

func test_owner_palette_eight(runner) -> bool:
	var seen: Dictionary = {}
	for owner in range(1, 9):
		var colors: PackedColorArray = Palette.owner_colors(owner)
		runner.check(colors.size() == 10, "SH6 ten slots owner %d" % owner)
		seen[colors[Shapes.SLOT_ROOF]] = true
	runner.check(seen.size() == 8, "SH6 distinct roofs")
	runner.check(Palette.owner_colors(9)[Shapes.SLOT_ROOF] == Palette.FALLBACK, "SH6 grey fallback")
	return true

func test_lab_roles_mapped(runner) -> bool:
	var expected := {
		"usa_tank": &"tank_usa", "china_tank": &"tank_china_gatling", "china_light_vehicle": &"tank_china", "frc_tank": &"tank_frc",
		"usa_builder": &"bulldozer", "china_builder": &"bulldozer",
		"usa_rifle_infantry": &"infantry", "china_rifle_infantry": &"infantry", "frc_rifle_infantry": &"infantry",
		"usa_rocket_infantry": &"rocket_infantry", "china_rocket_infantry": &"rocket_infantry", "frc_rocket_infantry": &"rocket_infantry", "frc_builder": &"laborer",
		"usa_power_plant": &"power_plant", "china_power_plant": &"power_plant",
		"usa_factory": &"war_factory", "china_factory": &"war_factory", "frc_factory": &"war_factory",
		"usa_supply_center": &"supply_depot", "china_supply_center": &"supply_depot", "frc_supply_center": &"supply_depot",
		"usa_defence": &"defence_usa", "china_defence": &"defence_china", "frc_defence": &"defence_frc",
	}
	for kind: String in expected:
		runner.check(Shapes.role(kind) == expected[kind], "SH7 %s maps to %s" % [kind, expected[kind]])
	return true

func _count(mesh: Dictionary, slots: Array) -> int:
	var found: int = 0
	for slot in mesh.slots:
		if slots.has(slot): found += 1
	@warning_ignore("integer_division")
	return found / 3

func test_damage_stage_changes_geometry(runner) -> bool:
	var roofs: Array = [Shapes.SLOT_ROOF, Shapes.SLOT_ROOF_DARK]
	var smoke: Array = [Shapes.SLOT_SMOKE, Shapes.SLOT_SIDE_DARK]
	var stages: Array[Dictionary] = []
	for stage in 3:
		var merged := {"slots": PackedByteArray()}
		for part in Shapes.parts(&"war_factory", 2, stage).size():
			merged.slots.append_array(Bake.mesh(&"war_factory", part, 0, 2, stage).slots)
		stages.append(merged)
	runner.check(_count(stages[2], roofs) < _count(stages[0], roofs), "SH8 stage 2 has fewer roof triangles")
	runner.check(_count(stages[1], roofs) < _count(stages[0], roofs), "SH8 stage 1 has a missing corner")
	runner.check(_count(stages[1], [Shapes.SLOT_ROOF_DARK]) > 0 and _count(stages[0], [Shapes.SLOT_ROOF_DARK]) == 0, "SH8 stage 1 roof is darker")
	runner.check(_count(stages[2], [Shapes.SLOT_SMOKE]) > 0 and _count(stages[1], [Shapes.SLOT_SMOKE]) == 0 and _count(stages[0], [Shapes.SLOT_SMOKE]) == 0, "SH8 smoke only at stage 2")
	runner.check(_count(stages[2], smoke) > _count(stages[1], smoke), "SH8 smoke triangles added")
	return true

func test_turret_pivot_on_hull_top(runner) -> bool:
	for role in TANK_ROLES:
		var parts: Array[Dictionary] = Shapes.parts(role, 2)
		runner.check(parts.size() == 2 and parts[1].name == &"turret", "SH9 %s has a turret part" % role)
		if parts.size() < 2: continue
		for bucket in Shapes.HEADING_BUCKETS:
			var mesh: Dictionary = Bake.mesh(role, 1, bucket, 2)
			var sum := Vector2.ZERO
			var n: int = 0
			for i in mesh.points.size():
				if mesh.slots[i] != Shapes.SLOT_ROOF: continue
				sum += Vector2(mesh.points[i].x, mesh.points[i].y + mesh.lifts[i])
				n += 1
			var centre: Vector2 = Iso.plane_to_world(sum / maxf(n, 1))
			var expected: float = TURRET_OFFSET.get(role, 0.0)
			runner.check(n > 0 and absf(centre.length() - expected) <= 0.02, "SH9 %s bucket %d turret turns about the hull centre (offset %.2f)" % [role, bucket, expected])
	return true

func test_offset_turret_pivot_follows_hull(runner) -> bool:
	for hull_bucket in [0, 9, 16, 40]:
		for bucket in [0, 5, 21, 50]:
			var mesh: Dictionary = Bake.mesh(&"tank_frc", 1, bucket, 2, 0, hull_bucket)
			var sum := Vector2.ZERO
			var n: int = 0
			for i in mesh.points.size():
				if mesh.slots[i] != Shapes.SLOT_ROOF: continue
				sum += Vector2(mesh.points[i].x, mesh.points[i].y + mesh.lifts[i])
				n += 1
			var centre: Vector2 = Iso.plane_to_world(sum / maxf(n, 1))
			var expected: Vector2 = Vector2(0, 0.055).rotated(hull_bucket * TAU / Shapes.HEADING_BUCKETS)
			runner.check(n > 0 and centre.distance_to(expected) <= 0.02, "SH9b frc turret at hull %d aims %d sits on the hull's offset point (got %s want %s)" % [hull_bucket, bucket, centre, expected])
	return true

func test_no_kind_uses_default_role(runner) -> bool:
	for kind in Definitions.units() + Definitions.buildings():
		var role: StringName = Shapes.role(kind)
		runner.check(role != &"default_vehicle" and role != &"default_building", "SH10 %s has a class role (%s)" % [kind, role])
	runner.check(Shapes.role("usa_collector") == &"helicopter", "SH10 helicopter role")
	runner.check(Shapes.parts(&"helicopter", 1)[1].angle == &"fixed", "SH10 rotor is a fixed-angle part")
	runner.check(Shapes.parts(&"defence_china", 1)[1].name == &"turret", "SH10 gatling tower turret")
	return true

func test_roster_shares_slots(runner) -> bool:
	var roles: Dictionary = {}
	for kind in Definitions.units() + Definitions.buildings():
		roles[Shapes.role(kind)] = true
	for role: StringName in roles:
		for detail in 3:
			for variant in 3:
				for part: Dictionary in Shapes.parts(role, detail, variant):
					for prim: Dictionary in part.prims:
						runner.check(PRIM_SLOTS.has(prim.slot), "SH11 %s uses a drawable slot, got %d" % [role, prim.slot])
	return true

func _max_lift(role: StringName, detail: int) -> float:
	var top: float = 0.0
	for part in Shapes.parts(role, detail).size():
		top = maxf(top, Array(Bake.mesh(role, part, 0, detail).lifts).max())
	return top

func test_unit_heights(runner) -> bool:
	for role: StringName in TANK_ROLES:
		for detail in 3:
			runner.check(is_equal_approx(_max_lift(role, detail), 3.0 * Z), "SH12 %s detail %d is 10.5 px tall (Zero Hour height to length ratio), got %f" % [role, detail, _max_lift(role, detail)])
	var roles: Array[StringName] = [&"infantry", &"laborer", &"rocket_infantry", &"light_vehicle", &"bulldozer", &"collector_truck"]
	for role: StringName in roles:
		for detail in 3:
			runner.check(is_equal_approx(_max_lift(role, detail), 4.5 * Z), "SH12 %s detail %d is 15.75 px tall, got %f" % [role, detail, _max_lift(role, detail)])
	runner.check(is_equal_approx(_max_lift(&"war_factory", 1), 14.0 * Z), "SH12 factory roof 49 px")
	runner.check(is_equal_approx(_max_lift(&"barracks", 0), 6.0 * Z), "SH12 barracks 21 px")
	return true

func _extent(part: Dictionary) -> Vector2:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for prim: Dictionary in part.prims:
		var half := Vector2(prim.size.x, prim.size.y) / 2.0
		var centre := Vector2(prim.offset.x, prim.offset.y)
		lo = lo.min(centre - half)
		hi = hi.max(centre + half)
	return hi - lo

func test_hulls_fit_one_cell(runner) -> bool:
	var expected := {&"tank_usa": Vector2(0.75, 0.5), &"tank_china": Vector2(0.8, 0.6), &"tank_china_gatling": Vector2(0.8, 0.6), &"tank_frc": Vector2(0.7, 0.45)}
	for role: StringName in expected:
		var got: Vector2 = _extent(Shapes.parts(role, 0)[0])
		runner.check(got.is_equal_approx(expected[role]), "SH13 %s hull %s, got %s" % [role, expected[role], got])
	return true

func test_tracks_deck_and_cannon(runner) -> bool:
	for role: StringName in TANK_ROLES:
		for detail in 3:
			var parts: Array[Dictionary] = Shapes.parts(role, detail)
			var tracks: Array = parts[0].prims.filter(func(prim: Dictionary) -> bool: return prim.slot == Shapes.SLOT_SIDE)
			runner.check(tracks.size() == 2 and tracks.all(func(prim: Dictionary) -> bool: return is_equal_approx(prim.size.y, 0.1) and prim.size.z == 1.5 and prim.offset.z == 0.0), "SH14 %s detail %d has two dark neutral 0.1 wide, 1.5 tall tracks" % [role, detail])
			runner.check(tracks.size() == 2 and signf(tracks[0].offset.y) != signf(tracks[1].offset.y), "SH14 %s tracks on opposite sides" % role)
			runner.check(parts[0].prims.any(func(prim: Dictionary) -> bool: return prim.slot == Shapes.SLOT_ROOF_DARK and prim.size.z == 2.0), "SH14 %s deck is the dark roof slot, 2 tall" % role)
			runner.check(parts[1].prims[0].slot == Shapes.SLOT_ROOF and parts[1].prims[0].offset.z == 2.0, "SH14 %s turret top is the roof slot on the deck" % role)
			var cannon: Array = parts[1].prims.filter(func(prim: Dictionary) -> bool: return prim.slot == Shapes.SLOT_MACHINE)
			var barrels: int = 2 if role == &"tank_china_gatling" else 1
			runner.check(cannon.size() == barrels and cannon.all(func(prim: Dictionary) -> bool: return prim.size.z <= 0.8), "SH14 %s detail %d has %d light cannon barrel(s)" % [role, detail, barrels])
	return true

func test_neutral_faces(runner) -> bool:
	for owner in range(0, 9):
		var colors: PackedColorArray = Palette.owner_colors(owner)
		runner.check(colors[Shapes.SLOT_SIDE] == Color("3D515F") and colors[Shapes.SLOT_SIDE_DARK] == Color("263842") and colors[Shapes.SLOT_MACHINE] == Color("8098A5"), "SH15 owner %d has neutral sides and machinery" % owner)
		runner.check(colors[Shapes.SLOT_SMOKE] != colors[Shapes.SLOT_GLOW] and colors[Shapes.SLOT_SMOKE].v < 0.3, "SH15 owner %d smoke is a dark neutral" % owner)
	return true

func test_infantry_narrow_with_head(runner) -> bool:
	for role: StringName in [&"infantry", &"laborer", &"rocket_infantry"]:
		for detail in 3:
			var prims: Array = Shapes.parts(role, detail)[0].prims.filter(func(prim: Dictionary) -> bool: return prim.type == &"cylinder")
			runner.check(prims.size() == 3 and prims.all(func(prim: Dictionary) -> bool: return prim.size.x <= 0.16), "SH16 %s is three cylinders at most 0.16 wide" % role)
			runner.check(prims[1].slot == Shapes.SLOT_OWNER_FLAT and prims[0].slot == Shapes.SLOT_SIDE_DARK, "SH16 %s has a full owner colour torso over dark legs" % role)
			runner.check(is_equal_approx(prims[2].offset.z, 3.2) and is_equal_approx(prims[2].size.z, 1.3) and prims[2].size.x < prims[1].size.x and prims[2].slot == Shapes.SLOT_SKIN, "SH16 %s detail %d has a narrower light head" % [role, detail])
	return true

func _first_and_last(mesh: Dictionary, slot: int) -> Vector2i:
	var at: Array = []
	for i in mesh.slots.size():
		if mesh.slots[i] == slot: at.append(i)
	return Vector2i(at[0], at[-1])

func test_prims_sorted_per_heading(runner) -> bool:
	var away: Dictionary = Bake.mesh(&"bulldozer", 0, 32, 0)
	var front: Dictionary = Bake.mesh(&"bulldozer", 0, 0, 0)
	runner.check(_first_and_last(away, Shapes.SLOT_MACHINE).y < _first_and_last(away, Shapes.SLOT_ROOF).x, "SH17 blade behind the body at bucket 32 is drawn first")
	runner.check(_first_and_last(front, Shapes.SLOT_MACHINE).x > _first_and_last(front, Shapes.SLOT_ROOF).y, "SH17 blade in front of the body at bucket 0 is drawn last")
	return true

func test_cylinder_segments_by_detail(runner) -> bool:
	for detail in 3:
		var mesh: Dictionary = Bake.mesh(&"infantry", 0, 0, detail)
		var tops: int = 0
		for i in range(0, mesh.slots.size(), 3):
			if mesh.slots[i] == Shapes.SLOT_SKIN and [0, 1, 2].all(func(k: int) -> bool: return is_equal_approx(mesh.lifts[i + k], 4.5 * Z)): tops += 1
		runner.check(tops == [2, 4, 6][detail], "SH18 detail %d head top fan has %d triangles, got %d" % [detail, [2, 4, 6][detail], tops])
	return true

func test_back_faces_not_baked(runner) -> bool:
	var out := {"points": PackedVector2Array(), "slots": PackedByteArray(), "lifts": PackedFloat32Array()}
	Bake._append_prim(out, PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]), 0.0, 1.0, Shapes.SLOT_ROOF)
	runner.check(out.points.size() == 18, "SH19 a unit box has six triangles (top plus two visible sides), got %d" % [out.points.size() / 3])
	return true
