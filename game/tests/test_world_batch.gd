@warning_ignore_start("untyped_declaration")
extends RefCounted

const WorldBatch = preload("res://scripts/presentation/world_batch.gd")
const Shapes = preload("res://scripts/presentation/shapes.gd")
const Bake = preload("res://scripts/presentation/shape_bake.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Fixture = preload("res://tests/economy_fixture.gd")

func cases() -> Array[Callable]:
	return [test_sort_key_orders_layers_then_depth, test_unit_in_front_of_factory_draws_later, test_unit_behind_factory_draws_earlier, test_air_kind_draws_above_ground, test_build_one_submission, test_empty_state, test_marks_join_the_array, test_rise_from_work, test_damage_stage_edges, test_building_rises_with_work, test_supply_stack_shrinks, test_small_pile_inside_footprint, test_shadow_only_with_flag, test_lab_roles_mapped]

func _find(items: Array[Dictionary], id: int) -> Dictionary:
	for item in items:
		if item.id == id: return item
	return {}

func _key(item: Dictionary) -> int:
	return WorldBatch.sort_key(item.layer, item.anchor, item.id)

func test_sort_key_orders_layers_then_depth(runner) -> bool:
	runner.check(WorldBatch.sort_key(WorldBatch.LAYER_AIR, Vector2(0, 0), 9) > WorldBatch.sort_key(WorldBatch.LAYER_GROUND, Vector2(90, 90), 1), "WB1 air above ground at any depth")
	runner.check(WorldBatch.sort_key(WorldBatch.LAYER_GROUND, Vector2(5, 5), 1) > WorldBatch.sort_key(WorldBatch.LAYER_DECAL, Vector2(90, 90), 1), "WB1 ground above decal")
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
	batch.build(WorldBatch.objects(sim.snapshot()), {}, 1, 0)
	runner.check(batch.points.size() % 3 == 0 and batch.points.size() > 0, "WB5 whole triangles")
	runner.check(batch.colors.size() == batch.points.size(), "WB5 one colour per vertex")
	runner.check(float(batch.triangle_count) == batch.points.size() / 3.0, "WB5 triangle count")
	return true

func test_empty_state(runner) -> bool:
	var batch = WorldBatch.new()
	batch.build(WorldBatch.objects({}), {}, 1, 0)
	runner.check(batch.points.is_empty() and batch.colors.is_empty() and batch.triangle_count == 0, "WB6 empty arrays")
	batch.submit(RID())
	runner.check(true, "WB6 submit of nothing does not error")
	return true

func test_marks_join_the_array(runner) -> bool:
	var sim = Fixture.make_world()
	var objects: Array[Dictionary] = WorldBatch.objects(sim.snapshot())
	var plain = WorldBatch.new()
	plain.build(objects, {}, 1, 0)
	var marked = WorldBatch.new()
	marked.build(objects, {}, 1, 0, [Vector2(0, 0), Vector2(10, 0), Vector2(20, 0)])
	runner.check(marked.triangle_count == plain.triangle_count + 6, "WB7 three marks add six triangles")
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

func _single(item: Dictionary, flags: int = 0) -> Object:
	var batch = WorldBatch.new()
	batch.build([item] as Array[Dictionary], {}, 2, flags)
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
	var shadowed = _single(item, WorldBatch.FLAG_SHADOWS)
	runner.check(shadowed.triangle_count == plain.triangle_count + 2, "WB14 shadow adds two triangles only with the flag")
	return true
