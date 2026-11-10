@warning_ignore_start("untyped_declaration")
extends RefCounted

const WorldBatch = preload("res://scripts/presentation/world_batch.gd")
const Fixture = preload("res://tests/economy_fixture.gd")

func cases() -> Array[Callable]:
	return [test_sort_key_orders_layers_then_depth, test_unit_in_front_of_factory_draws_later, test_unit_behind_factory_draws_earlier, test_air_kind_draws_above_ground, test_build_one_submission, test_empty_state, test_marks_join_the_array, test_rise_from_work]

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
