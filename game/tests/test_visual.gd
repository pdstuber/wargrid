@warning_ignore_start("untyped_declaration")
extends RefCounted

const Director = preload("res://scripts/presentation/visual_director.gd")
const WorldBatch = preload("res://scripts/presentation/world_batch.gd")

func cases() -> Array[Callable]:
	return [test_visual_catch_up_and_stall, test_coalesced_muzzle, test_unknown_position_skipped, test_dead_target_hit_at_last_known, test_fade_lasts_two_seconds, test_reset_clears_presentation_state, test_turret_turns_at_fixed_rate, test_turret_returns_to_hull, test_cues_draw_on_low, test_pending_bounded, test_turret_angle_changes_triangles]

func _shot(tick: int, attacker: int, target: int, splash: bool = false) -> Dictionary:
	return {"type": "shot", "tick": tick, "attacker_id": attacker, "target_id": target, "damage": 1, "splash": splash}

func _obj(id: int, at: Vector2, target: int = -1, heading: float = 0.0) -> Dictionary:
	return {"id": id, "role": &"tank_usa", "anchor": at, "heading": heading, "target_id": target}

func _events(list: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	typed.assign(list)
	return typed

func _types(director, type: StringName) -> Array:
	return director.effects().filter(func(e: Dictionary) -> bool: return e.type == type)

func _world() -> Array[Dictionary]:
	return _events([_obj(1, Vector2(2, 2)), _obj(2, Vector2(6, 2))])

func test_visual_catch_up_and_stall(runner) -> bool:
	var director = Director.new()
	var none := _events([])
	director.collect_step(10, _events([_shot(10, 1, 2)]), none)
	director.collect_step(11, _events([_shot(11, 2, 1)]), none)
	director.update(_world())
	runner.check(_types(director, &"muzzle").size() == 2, "VI1 two muzzles from two steps, got %d" % _types(director, &"muzzle").size())
	var again = Director.new()
	again.collect_step(10, _events([_shot(10, 1, 2)]), none)
	again.collect_step(10, _events([_shot(10, 1, 2)]), none)
	again.update(_world())
	runner.check(_types(again, &"muzzle").size() == 1 and _types(again, &"hit").size() == 1, "VI1 same tick twice gives one muzzle and one hit")
	again.update(_world())
	runner.check(_types(again, &"muzzle").size() == 1, "VI1 a second update consumes nothing new")
	return true

func test_coalesced_muzzle(runner) -> bool:
	var director = Director.new()
	var world: Array[Dictionary] = _world()
	world.append(_obj(3, Vector2(7, 3)))
	world.append(_obj(4, Vector2(7, 1)))
	director.collect_step(5, _events([_shot(5, 1, 2), _shot(5, 1, 3, true), _shot(5, 1, 4, true)]), _events([]))
	director.update(world)
	runner.check(_types(director, &"muzzle").size() == 1, "VI2 three damage records of one attack give one muzzle, got %d" % _types(director, &"muzzle").size())
	runner.check(_types(director, &"hit").size() == 3, "VI2 each victim still gets a hit")
	return true

func test_unknown_position_skipped(runner) -> bool:
	var director = Director.new()
	director.collect_step(5, _events([_shot(5, 99, 2), _shot(5, 1, 98), {"type": "death", "tick": 5, "object_id": 97}]), _events([]))
	director.update(_world())
	var kinds: Array = director.effects().map(func(e: Dictionary) -> StringName: return e.type)
	runner.check(kinds == [&"hit", &"muzzle"] or kinds == [&"muzzle", &"hit"], "VI3 only the known ends draw, got %s" % [kinds])
	return true

func test_dead_target_hit_at_last_known(runner) -> bool:
	var director = Director.new()
	director.update(_world())
	director.collect_step(6, _events([_shot(6, 1, 2), {"type": "death", "tick": 6, "object_id": 2}]), _events([]))
	director.update(_events([_obj(1, Vector2(2, 2))]))
	var hits: Array = _types(director, &"hit")
	runner.check(hits.size() == 1 and hits[0].anchor == Vector2(6, 2), "VI4 hit at the dead target's last anchor, got %s" % [hits])
	runner.check(_types(director, &"fade").size() == 1, "VI4 the death fades at its last anchor")
	return true

func test_fade_lasts_two_seconds(runner) -> bool:
	var director = Director.new()
	director.update(_world())
	director.collect_step(6, _events([{"type": "death", "tick": 6, "object_id": 2}]), _events([]))
	director.update(_events([_obj(1, Vector2(2, 2))]))
	runner.check(_types(director, &"fade").size() == 1, "VI5 fade starts")
	for i in 59: director.update(_events([]))
	runner.check(_types(director, &"fade").size() == 1, "VI5 fade still shown after 59 more updates")
	director.update(_events([]))
	runner.check(_types(director, &"fade").is_empty(), "VI5 fade gone after 60 updates")
	return true

func test_reset_clears_presentation_state(runner) -> bool:
	var director = Director.new()
	director.collect_step(5, _events([_shot(5, 1, 2)]), _events([]))
	director.update(_events([_obj(1, Vector2(2, 2), 2), _obj(2, Vector2(2, 6))]))
	director.update(_events([_obj(1, Vector2(2, 2), 2), _obj(2, Vector2(2, 6))]))
	runner.check(director.turret_angles().has(1) and not director.effects().is_empty(), "VI6 state exists before reset")
	director.reset()
	director.update(_events([_obj(1, Vector2(2, 2))]))
	runner.check(director.turret_angles().is_empty() and director.effects().is_empty(), "VI6 a reused id carries nothing over")
	director.collect_step(5, _events([_shot(5, 1, 2)]), _events([]))
	director.update(_world())
	runner.check(_types(director, &"muzzle").size() == 1, "VI6 a new match can start at a low tick")
	return true

func _aim(director, steps: int) -> void:
	for i in steps: director.update(_events([_obj(1, Vector2(0, 0), 2), _obj(2, Vector2(0, 5))]))

func test_turret_turns_at_fixed_rate(runner) -> bool:
	var director = Director.new()
	var needed: int = ceili((PI / 2.0) / Director.TURRET_RATE)
	_aim(director, needed - 1)
	runner.check(absf(director.turret_angles()[1] - PI / 2.0) > 0.001, "VI7 not there after %d updates" % (needed - 1))
	_aim(director, 1)
	runner.check(is_equal_approx(director.turret_angles()[1], PI / 2.0), "VI7 there after %d updates, got %f" % [needed, director.turret_angles().get(1, -1.0)])
	return true

func test_turret_returns_to_hull(runner) -> bool:
	var director = Director.new()
	_aim(director, 4)
	var aimed: float = director.turret_angles()[1]
	director.update(_events([_obj(1, Vector2(0, 0), -1), _obj(2, Vector2(0, 5))]))
	runner.check(is_equal_approx(director.turret_angles()[1], aimed - Director.TURRET_RATE), "VI8 steps back by the rate")
	for i in 10: director.update(_events([_obj(1, Vector2(0, 0), -1)]))
	runner.check(not director.turret_angles().has(1), "VI8 back on the hull heading, no override left")
	return true

func test_cues_draw_on_low(runner) -> bool:
	for type: StringName in [&"muzzle", &"hit", &"fade"]:
		var batch := WorldBatch.new()
		var effects: Array[Dictionary] = [{"type": type, "anchor": Vector2(3, 3), "age": 0, "id": 1}]
		batch.build([], {}, 0, false, effects)
		runner.check(batch.triangle_count > 0, "VI9 %s draws on Low" % type)
	return true

func test_pending_bounded(runner) -> bool:
	var director = Director.new()
	for i in 20: director.collect_step(i, _events([_shot(i, 1, 2)]), _events([]))
	director.update(_world())
	runner.check(_types(director, &"muzzle").size() == Director.MAX_PENDING, "VI10 only the newest steps are shown, got %d" % _types(director, &"muzzle").size())
	runner.check(director.dropped == 12, "VI10 dropped counted, got %d" % director.dropped)
	return true

func test_turret_angle_changes_triangles(runner) -> bool:
	var tank: Array[Dictionary] = [_obj(1, Vector2(3, 3))]
	tank[0].merge({"owner": 1, "layer": 1, "footprint": Vector2i.ONE, "rise": 1.0, "boxes": 0, "variant": 0, "shadow": 0.0, "horde": false, "hp": 1, "max_hp": 1}, true)
	var plain := WorldBatch.new()
	plain.build(tank, {}, 1, false)
	var turned := WorldBatch.new()
	turned.build(tank, {1: PI / 2.0}, 1, false)
	runner.check(plain.points.size() == turned.points.size() and plain.points != turned.points, "VI12 a turret angle moves the turret triangles")
	return true
