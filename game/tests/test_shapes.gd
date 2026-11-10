@warning_ignore_start("untyped_declaration")
extends RefCounted

const Shapes = preload("res://scripts/presentation/shapes.gd")
const Bake = preload("res://scripts/presentation/shape_bake.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const Definitions = preload("res://scripts/simulation/definitions/definitions.gd")

func cases() -> Array[Callable]:
	return [test_bucket_wraps, test_box_top_face_on_top, test_bake_is_cached, test_unknown_kind_gets_default_role, test_every_registry_kind_has_parts, test_owner_palette_eight]

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
	var first: Dictionary = Bake.mesh(&"default_vehicle", 0, 7, 1)
	var second: Dictionary = Bake.mesh(&"default_vehicle", 0, 7, 1)
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
