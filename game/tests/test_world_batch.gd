@warning_ignore_start("untyped_declaration")
extends RefCounted

const WorldBatch = preload("res://scripts/presentation/world_batch.gd")
const Director = preload("res://scripts/presentation/visual_director.gd")
const Shapes = preload("res://scripts/presentation/shapes.gd")
const Bake = preload("res://scripts/presentation/shape_bake.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const ViewRows = preload("res://scripts/simulation/view_rows.gd")

func cases() -> Array[Callable]:
	return [test_sort_key_orders_layers_then_depth, test_unit_in_front_of_factory_draws_later, test_unit_behind_factory_draws_earlier, test_air_kind_draws_above_ground, test_build_one_submission, test_empty_state, test_rise_from_work, test_damage_stage_edges, test_building_rises_with_work, test_supply_stack_shrinks, test_small_pile_inside_footprint, test_shadow_only_with_flag, test_lab_roles_mapped, test_back_to_front_across_objects, test_lifts_clear_unit_height, test_top_lift_by_role, test_golden_output, test_shot_dash, test_depth_order_matches_sorted, test_unit_item_rewrite_leaves_nothing_stale, test_structure_items_follow_units]

func _find(items: Array[Dictionary], id: int) -> Dictionary:
	for item in items:
		if item.id == id: return item
	return {}

func _key(item: Dictionary) -> int:
	return WorldBatch.sort_key(item.layer, item.anchor, item.id)

func test_sort_key_orders_layers_then_depth(runner) -> bool:
	runner.check(WorldBatch.sort_key(WorldBatch.LAYER_AIR, Vector2(0, 0), 9) > WorldBatch.sort_key(WorldBatch.LAYER_GROUND, Vector2(90, 90), 1), "WB1 air above ground at any depth")
	runner.check(WorldBatch.sort_key(1, Vector2(4, 4), 1) > WorldBatch.sort_key(1, Vector2(3, 4), 99), "WB1 larger x+y later")
	runner.check(WorldBatch.sort_key(1, Vector2(4, 4), 2) > WorldBatch.sort_key(1, Vector2(4, 4), 1), "WB1 equal depth, lower id first")
	return true

func _factory_world(unit_at: Vector2) -> Array[Dictionary]:
	var sim = Fixture.make_world()
	var factory: int = Fixture.add_completed(sim, 1, "usa_factory", Vector2i(10, 10))
	var unit: int = sim.spawn(1, unit_at, "usa_tank")
	var items: Array[Dictionary] = WorldBatch.objects(sim.snapshot())
	return [_find(items, factory), _find(items, unit)]

func test_unit_in_front_of_factory_draws_later(runner) -> bool:
	for at in [Vector2(11.5, 13.5), Vector2(13.5, 11.5)]:
		var pair := _factory_world(at)
		runner.check(not pair[0].is_empty() and not pair[1].is_empty(), "WB2 both objects listed")
		runner.check(_key(pair[1]) > _key(pair[0]), "WB2 unit at %s sorts after the factory" % at)
	return true

func test_unit_behind_factory_draws_earlier(runner) -> bool:
	for at in [Vector2(11.5, 9.5), Vector2(9.5, 11.5)]:
		var pair := _factory_world(at)
		runner.check(_key(pair[1]) < _key(pair[0]), "WB3 unit at %s sorts before the factory" % at)
	return true

func test_air_kind_draws_above_ground(runner) -> bool:
	var sim = Fixture.make_world()
	var factory: int = Fixture.add_completed(sim, 1, "usa_factory", Vector2i(10, 10))
	var heli: int = sim.spawn(1, Vector2(9.0, 9.0), "usa_collector")
	var items: Array[Dictionary] = WorldBatch.objects(sim.snapshot())
	var air: Dictionary = _find(items, heli)
	runner.check(air.layer == WorldBatch.LAYER_AIR, "WB4 helicopter in the air layer")
	runner.check(_key(air) > _key(_find(items, factory)), "WB4 sorts after a building in front of it")
	return true

func test_build_one_submission(runner) -> bool:
	var sim = Fixture.make_world()
	for i in 300: sim.spawn(1, Vector2(2.0 + i % 20, 2.0 + floorf(i / 20.0)), "usa_tank")
	var batch = WorldBatch.new()
	batch.build(WorldBatch.objects(sim.snapshot()), {}, 1, false)
	runner.check(batch.points.size() % 3 == 0 and batch.points.size() > 0, "WB5 whole triangles")
	runner.check(batch.colors.size() == batch.points.size(), "WB5 one colour per vertex")
	runner.check(float(batch.triangle_count) == batch.points.size() / 3.0, "WB5 triangle count")
	return true

func test_empty_state(runner) -> bool:
	var batch = WorldBatch.new()
	batch.build(WorldBatch.objects({}), {}, 1, false)
	runner.check(batch.points.is_empty() and batch.colors.is_empty() and batch.triangle_count == 0, "WB6 empty arrays")
	batch.submit(RID())
	return true

func test_rise_from_work(runner) -> bool:
	var sim = Fixture.make_world()
	var done: int = Fixture.add_completed(sim, 1, "usa_factory", Vector2i(10, 10))
	var half: int = Fixture.add_completed(sim, 1, "usa_factory", Vector2i(16, 10))
	var ticks: int = preload("res://scripts/simulation/economy_definitions.gd").building("usa_factory").ticks
	sim._buildings[half].completed = false
	sim._buildings[half].work = ticks * 500
	var items: Array[Dictionary] = WorldBatch.objects(sim.snapshot())
	runner.check(_find(items, done).rise == 1.0, "WB8 completed building is fully risen")
	runner.check(is_equal_approx(_find(items, half).rise, 0.5), "WB8 half the work is half risen")
	return true

func test_lab_roles_mapped(runner) -> bool:
	var sim = Fixture.make_world()
	var factory: int = Fixture.add_completed(sim, 1, "usa_factory", Vector2i(10, 10))
	var tank: int = sim.spawn(1, Vector2(5.5, 5.5), "usa_tank")
	var pile: int = sim.add_supply_source(Vector2i(20, 20), 8)
	var items: Array[Dictionary] = WorldBatch.objects(sim.snapshot())
	runner.check(_find(items, factory).role == &"war_factory", "WB9 factory role")
	runner.check(_find(items, tank).role == &"tank_usa", "WB9 tank role")
	runner.check(_find(items, pile).role == &"supply_source", "WB9 source role")
	return true

func test_damage_stage_edges(runner) -> bool:
	runner.check(WorldBatch.damage_stage(70, 100) == 1, "WB10 70 percent is stage 1")
	runner.check(WorldBatch.damage_stage(71, 100) == 0, "WB10 71 percent is stage 0")
	runner.check(WorldBatch.damage_stage(35, 100) == 2, "WB10 35 percent is stage 2")
	runner.check(WorldBatch.damage_stage(36, 100) == 1, "WB10 36 percent is stage 1")
	runner.check(WorldBatch.damage_stage(0, 0) == 0, "WB10 no max hp is stage 0")
	return true

func _single(item: Dictionary, shadows: bool = false) -> Object:
	var batch = WorldBatch.new()
	batch.build([item] as Array[Dictionary], {}, 2, shadows)
	return batch

func _top(batch: Object) -> float:
	var top: float = 1e9
	for point in batch.points: top = minf(top, point.y)
	return top

func test_building_rises_with_work(runner) -> bool:
	var sim = Fixture.make_world()
	var factory: int = Fixture.add_completed(sim, 1, "usa_factory", Vector2i(10, 10))
	var item: Dictionary = _find(WorldBatch.objects(sim.snapshot()), factory)
	runner.check(item.role == &"war_factory", "WB11 factory role")
	var done = _single(item)
	var before: int = Bake.bake_count
	item.rise = 0.5
	var half = _single(item)
	var full_height: float = _ground_top()
	runner.check(absf((_top(half) - _top(done)) - full_height / 2.0) <= 1.0, "WB11 half risen is half the height")
	item.rise = 0.0
	var flat = _single(item)
	runner.check(is_equal_approx(_top(flat) - _top(done), full_height), "WB11 rise 0 is flat")
	runner.check(Bake.bake_count == before, "WB11 no new bake for rise")
	return true

func _ground_top() -> float:
	var lift: float = 0.0
	var mesh: Dictionary = Bake.mesh(&"war_factory", 0, 0, 2)
	for value in mesh.lifts: lift = maxf(lift, value)
	return lift

var _next_pile_x: int = 0

func _pile(sim, boxes: int, footprint: Vector2i = Vector2i(4, 5)) -> Dictionary:
	_next_pile_x += 6
	var id: int = sim.add_supply_source(Vector2i(_next_pile_x, 10), boxes, footprint)
	return _find(WorldBatch.objects(sim.snapshot()), id)

func test_supply_stack_shrinks(runner) -> bool:
	var sim = Fixture.make_world()
	var base: int = _single(_pile(sim, 0)).triangle_count
	var one: int = _single(_pile(sim, 1)).triangle_count
	var many: int = _single(_pile(sim, 400)).triangle_count
	runner.check(base > 0, "WB12 empty pile still draws its base")
	runner.check(one < many and base < one, "WB12 stack grows with boxes (%d, %d, %d)" % [base, one, many])
	return true

func test_small_pile_inside_footprint(runner) -> bool:
	var sim = Fixture.make_world(10000, Vector2i(96, 32))
	for footprint in [Vector2i(1, 1), Vector2i(2, 2), Vector2i(4, 5)]:
		for boxes in [0, 3, 400]:
			var item: Dictionary = _pile(sim, boxes, footprint)
			var batch = _single(item)
			var origin: Vector2 = item.anchor - Vector2(footprint) / 2.0
			var inside: bool = true
			var lifts := PackedFloat32Array()
			for mesh_part in Shapes.parts(item.role, 2, item.variant).size():
				lifts.append_array(Bake.mesh(item.role, mesh_part, 0, 2, item.variant).lifts)
			for i in batch.points.size():
				var ground: Vector2 = Iso.plane_to_world(batch.points[i] + Vector2(0, lifts[i]))
				if ground.x < origin.x - 0.01 or ground.y < origin.y - 0.01 or ground.x > origin.x + footprint.x + 0.01 or ground.y > origin.y + footprint.y + 0.01: inside = false
			runner.check(inside and batch.points.size() > 0, "WB13 pile %s boxes %d inside footprint" % [footprint, boxes])
	return true

func test_shadow_only_with_flag(runner) -> bool:
	var sim = Fixture.make_world()
	var tank: int = sim.spawn(1, Vector2(5.5, 5.5), "usa_tank")
	var item: Dictionary = _find(WorldBatch.objects(sim.snapshot()), tank)
	var plain = _single(item)
	var shadowed = _single(item, true)
	runner.check(shadowed.triangle_count == plain.triangle_count + 2, "WB14 shadow adds two triangles only with the flag")
	return true

func test_back_to_front_across_objects(runner) -> bool:
	var pair := _factory_world(Vector2(11.5, 13.5))
	var factory_only = _single(pair[0])
	var both = WorldBatch.new()
	both.build([pair[1], pair[0]] as Array[Dictionary], {}, 2, false)
	runner.check(factory_only.points.size() > 0 and both.points.slice(0, factory_only.points.size()) == factory_only.points, "WB15 the factory behind the tank is painted first")
	runner.check(both.points.size() > factory_only.points.size(), "WB15 the tank follows")
	return true

func test_lifts_clear_unit_height(runner) -> bool:
	runner.check(WorldBatch.MUZZLE_LIFT >= 15.75, "WB16 muzzle flash sits at or above a tank top (15.75 px), got %f" % WorldBatch.MUZZLE_LIFT)
	runner.check(WorldBatch.AIR_LIFT >= 30.0, "WB16 aircraft fly at least 30 px above their ground point, got %f" % WorldBatch.AIR_LIFT)
	return true

func test_top_lift_by_role(runner) -> bool:
	runner.check(is_equal_approx(WorldBatch.top_lift("usa_factory"), 49.0), "WB17 factory roof is 49 px")
	runner.check(is_equal_approx(WorldBatch.top_lift("usa_command_center"), 63.0), "WB17 command centre is 63 px")
	runner.check(WorldBatch.top_lift("usa_power_plant") > WorldBatch.top_lift("usa_barracks"), "WB17 the power plant's drums rise above a barracks")
	return true

const GOLDEN_COLORS := "d9194cc1dd8caaaa9e9b9f24cb420b851fd2bcfe02790bd44128b35f29e1df5e"
const GOLDEN_SHAPES: Array = [
	[3606, 1924921.03890061, 4240275.69687653], [3620, 1929742.65306306, 4252157.39672852],
	[3880, 2140575.43968797, 4500032.49620819], [3894, 2145397.05385041, 4511914.19606018],
	[4304, 2581625.30891448, 4990904.65343475], [4318, 2586446.92307693, 5002786.35328674],
	[4578, 2797279.70970184, 5250661.45276642], [4592, 2802101.32386428, 5262543.15261841],
	[4932, 3179080.32181478, 5650658.75281525], [4946, 3183901.93597722, 5662540.45266724],
	[5206, 3394734.72260213, 5910415.55214691], [5220, 3399556.33676457, 5922297.2519989],
]
const SUM_TOLERANCE := 0.01 # libm trig differs by 1 ulp across platforms (1.5e-5 px, CI run 43101932602)

func _golden_state() -> Dictionary:
	var sim = Fixture.make_world(10000, Vector2i(96, 96))
	var state: Dictionary = sim.snapshot()
	var entities: Array = state.entities
	var next_id: int = 5000
	var n: int = 0
	for kind: String in Registry.units():
		for h in 8:
			var unit: Dictionary = entities[0].duplicate(true)
			unit.id = next_id
			next_id += 1
			unit.kind = kind
			unit.owner = 1 + n % 3
			if n % 7 == 0 and unit.combat != null: unit.combat.horde = 1
			unit.position = [2.0 + (n % 20) * 1.3, 2.0 + floorf(n / 20.0) * 1.3]
			unit.heading = [cos(h * TAU / 8.0 + n * 0.07), sin(h * TAU / 8.0 + n * 0.07)]
			entities.append(unit)
			n += 1
	for kind in ["usa_factory", "usa_power_plant", "usa_barracks", "usa_command_center", "china_factory", "frc_supply_center"]:
		var building: int = Fixture.add_completed(sim, 1 + n % 3, kind, Vector2i(10 + (n % 5) * 8, 60 + (n % 2) * 8))
		sim._buildings[building].hp = sim._buildings[building].max_hp * (n % 3 + 1) / 3
		if n % 4 == 0:
			sim._buildings[building].completed = false
			sim._buildings[building].work = 1500
		n += 1
	state = sim.snapshot()
	state.entities.append_array(entities.slice(1))
	state.entities.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	for i in 4: state.sources.append({"id": 9000 + i, "origin": [50 + i * 5, 50], "boxes": [0, 3, 20, 400][i]})
	return state

func test_golden_output(runner) -> bool:
	var items: Array[Dictionary] = WorldBatch.objects(_golden_state())
	var angles := {}
	for i in items.size():
		if i % 3 == 0: angles[items[i].id] = i * 0.31
	var effects: Array[Dictionary] = []
	for i in 6: effects.append({"type": [&"muzzle", &"hit", &"fade", &"dash"][i % 4], "anchor": Vector2(5 + i, 5 + i), "to": Vector2(9 + i, 4), "age": i % 4, "id": i})
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	var shapes: Array = []
	for detail in 3:
		for shadows in [false, true]:
			for with_extras in [false, true]:
				var batch = WorldBatch.new()
				if with_extras: batch.build(items, angles, detail, shadows, effects)
				else: batch.build(items, {}, detail, shadows)
				hasher.update(batch.colors.to_byte_array())
				var sum_x: float = 0.0
				var sum_y: float = 0.0
				for p in batch.points:
					sum_x += p.x
					sum_y += p.y
				shapes.append([batch.triangle_count, sum_x, sum_y])
	var warm = WorldBatch.new()
	warm.build(items, angles, 1, true)
	WorldBatch._bodies.clear()
	WorldBatch._body_count = WorldBatch.BODY_CACHE_CAP
	var cold = WorldBatch.new()
	cold.build(items, angles, 1, true)
	runner.check(cold.points == warm.points and cold.colors == warm.colors and WorldBatch._body_count < WorldBatch.BODY_CACHE_CAP, "WB19 a full body cache clears and output is unchanged")
	var colors: String = hasher.finish().hex_encode()
	var triangles: int = shapes.reduce(func(total: int, shape: Array) -> int: return total + shape[0], 0)
	print("GOLDEN %s %d %s" % [colors, triangles, JSON.stringify(shapes)])
	runner.check(triangles > 20000, "WB18 fixture is big (%d triangles)" % triangles)
	runner.check(colors == GOLDEN_COLORS, "WB18 colours equal the pinned digest (was 412a2fbb over points and colours at 52520 triangles)")
	runner.check(shapes.size() == GOLDEN_SHAPES.size(), "WB18 one shape row per batch")
	for i in mini(shapes.size(), GOLDEN_SHAPES.size()):
		var got: Array = shapes[i]
		var want: Array = GOLDEN_SHAPES[i]
		runner.check(got[0] == want[0] and absf(got[1] - want[1]) < SUM_TOLERANCE and absf(got[2] - want[2]) < SUM_TOLERANCE, "WB18 batch %d triangles and coordinate sums: got %s, want %s" % [i, got, want])
	return true

func _shot(attacker: int, target: int) -> Array[Dictionary]:
	return [{"type": "shot", "tick": 1, "attacker_id": attacker, "target_id": target, "damage": 1, "splash": false}]

func _objects() -> Array[Dictionary]:
	return [{"id": 1, "role": &"tank_usa", "anchor": Vector2(2, 2), "heading": 0.0, "target_id": -1}, {"id": 2, "role": &"tank_usa", "anchor": Vector2(6, 2), "heading": 0.0, "target_id": -1}]

func test_shot_dash(runner) -> bool:
	var director = Director.new()
	var none: Array[Dictionary] = []
	director.collect_step(1, _shot(1, 2), none)
	director.collect_step(1, _shot(1, 2), none)
	director.update(_objects())
	var dashes: Array = director.effects().filter(func(effect: Dictionary) -> bool: return effect.type == &"dash")
	runner.check(dashes.size() == 1 and dashes[0].anchor == Vector2(2, 2) and dashes[0].to == Vector2(6, 2), "W7 a shot makes one dash from attacker to target, got %s" % [dashes])
	for i in Director.DASH_TICKS - 1: director.update(_objects())
	runner.check(director.effects().any(func(effect: Dictionary) -> bool: return effect.type == &"dash"), "W7 the dash lasts several ticks")
	director.update(_objects())
	runner.check(not director.effects().any(func(effect: Dictionary) -> bool: return effect.type == &"dash"), "W7 the dash is gone after %d ticks" % Director.DASH_TICKS)
	var first := WorldBatch.new()
	var later := WorldBatch.new()
	first.build([], {}, 0, false, [{"type": &"dash", "anchor": Vector2(2, 2), "to": Vector2(6, 2), "age": 0, "id": 1}])
	later.build([], {}, 0, false, [{"type": &"dash", "anchor": Vector2(2, 2), "to": Vector2(6, 2), "age": 4, "id": 1}])
	runner.check(first.triangle_count == 2 and later.triangle_count == 2, "W7 a dash is one quad (2 triangles), got %d" % first.triangle_count)
	var reach: float = 0.0
	for a: Vector2 in first.points:
		for b: Vector2 in first.points: reach = maxf(reach, a.distance_to(b))
	runner.check(reach > 11.0 and reach < 14.0, "W7 the dash is about 12 px long, got %f" % reach)
	runner.check(first.points != later.points and (later.points[0].x - first.points[0].x) > 0.0, "W7 the dash flies toward the target")
	return true

func test_depth_order_matches_sorted(runner) -> bool:
	var state: Dictionary = _golden_state()
	var order: PackedInt32Array = WorldBatch.depth_order(ViewRows.from_units(state.entities))
	var sorted: Array = state.entities.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return WorldBatch.sort_key(WorldBatch.LAYER_GROUND, Vector2(a.position[0], a.position[1]), a.id) < WorldBatch.sort_key(WorldBatch.LAYER_GROUND, Vector2(b.position[0], b.position[1]), b.id))
	var expected: Array = sorted.map(func(unit: Dictionary) -> int: return unit.id)
	var got: Array = []
	for row in order: got.append(state.entities[row].id)
	runner.check(order.size() == state.entities.size() and got == expected and expected.size() > 100, "WB20 depth_order lists the rows in depth order")
	return true

func test_unit_item_rewrite_leaves_nothing_stale(runner) -> bool:
	var state: Dictionary = _golden_state()
	var units: Array = state.entities.slice(0, 40)
	var rows = ViewRows.from_units(units)
	var item := {}
	var same: bool = true
	for i in units.size():
		WorldBatch.write_unit_item(item, rows, i)
		same = same and item == WorldBatch.objects({"entities": [units[i]]})[0]
	runner.check(same, "WB21 one item rewritten across 40 different units equals a fresh item each time")
	return true

func test_structure_items_follow_units(runner) -> bool:
	var state: Dictionary = _golden_state()
	var all: Array[Dictionary] = WorldBatch.objects(state)
	var structures: Array[Dictionary] = WorldBatch.structure_items(state)
	runner.check(structures.size() == 10 and all.slice(state.entities.size()) == structures, "WB22 structure_items are the buildings then sources of objects()")
	return true
