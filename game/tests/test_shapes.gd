@warning_ignore_start("untyped_declaration")
extends RefCounted

const Shapes = preload("res://scripts/presentation/shapes.gd")
const Bake = preload("res://scripts/presentation/shape_bake.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const Definitions = preload("res://scripts/simulation/definitions/definitions.gd")

func cases() -> Array[Callable]:
	return [test_bucket_wraps, test_box_top_face_on_top, test_bake_is_cached, test_unknown_kind_gets_default_role, test_every_registry_kind_has_parts, test_owner_palette_eight, test_lab_roles_mapped, test_damage_stage_changes_geometry, test_turret_pivot_on_hull_top, test_no_kind_uses_default_role, test_roster_shares_slots]

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
	runner.check(is_equal_approx(min_y, -32.0 - 14.0), "SH2 back corner lifted 14 px above its ground corner")
	runner.check(top_slot == Shapes.SLOT_ROOF, "SH2 topmost vertex is roof")
	runner.check(mesh.lifts.size() == points.size() and mesh.slots.size() == points.size(), "SH2 parallel arrays")
	runner.check(Array(mesh.lifts).max() == 14.0 and Array(mesh.lifts).min() == 0.0, "SH2 lifts span 0..14")
	return true

func test_bake_is_cached(runner) -> bool:
	var before: int = Bake.bake_count
	var first: Dictionary = Bake.mesh(&"default_vehicle", 0, 7, 1, 9001)
	var second: Dictionary = Bake.mesh(&"default_vehicle", 0, 7, 1, 9001)
	runner.check(first.points == second.points and first.slots == second.slots, "SH3 equal content")
	runner.check(Bake.bake_count == before + 1, "SH3 baked once")
	return true

func test_unknown_kind_gets_default_role(runner) -> bool:
	var role: StringName = Shapes.role("no_such_kind")
	runner.check(role == &"default_vehicle" and not Shapes.parts(role, 0).is_empty(), "SH4 default role with parts")
	return true

func test_every_registry_kind_has_parts(runner) -> bool:
	var kinds: Array[String] = Definitions.units() + Definitions.buildings()
	runner.check(kinds.size() > 10, "SH5 registry not empty")
	for kind in kinds:
		for detail in 3:
			runner.check(not Shapes.parts(Shapes.role(kind), detail).is_empty(), "SH5 %s detail %d" % [kind, detail])
	return true

func test_owner_palette_eight(runner) -> bool:
	var seen: Dictionary = {}
	for owner in range(1, 9):
		var colors: PackedColorArray = Palette.owner_colors(owner)
		runner.check(colors.size() == 8, "SH6 eight slots owner %d" % owner)
		seen[colors[Shapes.SLOT_ROOF]] = true
	runner.check(seen.size() == 8, "SH6 distinct roofs")
	runner.check(Palette.owner_colors(9)[Shapes.SLOT_ROOF] == Palette.FALLBACK, "SH6 grey fallback")
	return true

func test_lab_roles_mapped(runner) -> bool:
	var expected := {
		"usa_tank": &"tank_usa", "china_tank": &"tank_china", "frc_tank": &"tank_frc",
		"usa_builder": &"bulldozer", "china_builder": &"bulldozer",
		"usa_rifle_infantry": &"infantry", "china_rifle_infantry": &"infantry", "frc_rifle_infantry": &"infantry",
		"usa_rocket_infantry": &"rocket_infantry", "china_rocket_infantry": &"rocket_infantry", "frc_rocket_infantry": &"rocket_infantry", "frc_builder": &"infantry",
		"usa_power_plant": &"power_plant", "china_power_plant": &"power_plant",
		"usa_factory": &"war_factory", "china_factory": &"war_factory", "frc_factory": &"war_factory",
		"usa_supply_center": &"supply_depot", "china_supply_center": &"supply_depot", "frc_supply_center": &"supply_depot",
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
	var smoke: Array = [Shapes.SLOT_GLOW, Shapes.SLOT_SIDE_DARK]
	var stages: Array[Dictionary] = []
	for stage in 3:
		var merged := {"slots": PackedByteArray()}
		for part in Shapes.parts(&"war_factory", 2, stage).size():
			merged.slots.append_array(Bake.mesh(&"war_factory", part, 0, 2, stage).slots)
		stages.append(merged)
	runner.check(_count(stages[2], roofs) < _count(stages[0], roofs), "SH8 stage 2 has fewer roof triangles")
	runner.check(_count(stages[1], roofs) < _count(stages[0], roofs), "SH8 stage 1 has a missing corner")
	runner.check(_count(stages[1], [Shapes.SLOT_ROOF_DARK]) > 0 and _count(stages[0], [Shapes.SLOT_ROOF_DARK]) == 0, "SH8 stage 1 roof is darker")
	runner.check(_count(stages[2], [Shapes.SLOT_GLOW]) > 0 and _count(stages[1], [Shapes.SLOT_GLOW]) == 0 and _count(stages[0], [Shapes.SLOT_GLOW]) == 0, "SH8 smoke only at stage 2")
	runner.check(_count(stages[2], smoke) > _count(stages[1], smoke), "SH8 smoke triangles added")
	return true

func test_turret_pivot_on_hull_top(runner) -> bool:
	for role in [&"tank_usa", &"tank_china", &"tank_frc"]:
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
			runner.check(n > 0 and (sum / maxf(n, 1)).length() <= 1.0, "SH9 %s bucket %d turret centred on pivot" % [role, bucket])
	return true

func test_no_kind_uses_default_role(runner) -> bool:
	for kind in Definitions.units() + Definitions.buildings():
		var role: StringName = Shapes.role(kind)
		runner.check(role != &"default_vehicle" and role != &"default_building", "SH10 %s has a class role (%s)" % [kind, role])
	runner.check(Shapes.role("usa_collector") == &"helicopter", "SH10 helicopter role")
	runner.check(Shapes.parts(&"helicopter", 1)[1].angle == &"fixed", "SH10 rotor is a fixed-angle part")
	runner.check(Shapes.parts(&"defence", 1)[1].name == &"turret", "SH10 defence turret")
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
						runner.check(prim.slot is int and prim.slot >= Shapes.SLOT_ROOF and prim.slot <= Shapes.SLOT_SHADOW, "SH11 %s uses a slot constant" % role)
	return true
