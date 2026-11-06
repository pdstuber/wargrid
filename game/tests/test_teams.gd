@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/combat_fixture.gd")
const Economy = preload("res://tests/economy_fixture.gd")
const Combat = preload("res://scripts/simulation/combat.gd")

func cases() -> Array[Callable]:
	return [test_allies_never_target, test_team_victory, test_same_tick_team_cases, test_start_match_validation, test_team_defaults, test_winner_is_team_id, test_friendly_fire_never_retaliates]

func _shots(sim: RefCounted) -> Array:
	return sim.snapshot().combat_events.filter(func(event: Dictionary) -> bool: return event.type == "shot")

func _teamed(seats: Array) -> RefCounted:
	var sim = Fixture.world()
	for seat in seats: sim.add_player(seat[0], 0, "human", seat[1])
	return sim

func test_team_defaults(runner) -> bool:
	var sim = Fixture.world()
	sim.add_player(1, 0)
	sim.add_player(3, 0, "human", 1)
	runner.check(sim.team_of(1) == 1 and sim.team_of(3) == 1 and sim.team_of(9) == 0, "TM1 team defaults to the seat id, no record is team 0")
	runner.check(not sim.add_player(4, 0, "human", -1).ok, "TM1 negative team rejected")
	runner.check(Combat.hostile(sim, 9, 1) and Combat.hostile(sim, 1, 9) and not Combat.hostile(sim, 9, 9) and not Combat.hostile(sim, 1, 3), "TM1 record-less owners stay hostile to everyone but themselves")
	return true

func test_allies_never_target(runner) -> bool:
	var sim = _teamed([[1, 1], [3, 1]])
	sim.spawn(1, Vector2(10.5, 10.5), "usa_tank")
	sim.spawn(3, Vector2(12.5, 10.5), "usa_tank")
	var shots: int = 0
	var targets: int = 0
	for tick in range(120):
		sim.step()
		shots += _shots(sim).size()
		for unit in sim.snapshot().entities:
			if unit.combat.target_id != null: targets += 1
	runner.check(shots == 0 and targets == 0, "TM2 allies never target or shoot over 120 ticks")
	return true

func test_team_victory(runner) -> bool:
	var sim = _teamed([[1, 1], [2, 2], [3, 3]])
	var builders: Dictionary = {}
	for seat in [1, 2, 3]: builders[seat] = sim.spawn(seat, Vector2(4.5 + seat * 4, 4.5), "usa_builder")
	runner.check(sim.start_match([3, 1, 2] as Array[int]).ok, "TM3 three-team match starts")
	sim.remove_object(builders[2])
	sim.step()
	runner.check(sim.snapshot().match.status == "ongoing", "TM3 ongoing with two teams left")
	runner.check(sim.snapshot().players.filter(func(p: Dictionary) -> bool: return p.alive).size() == 2, "TM3 snapshot alive flag")
	sim.remove_object(builders[3])
	sim.step()
	var match_state: Dictionary = sim.snapshot().match
	runner.check(match_state.status == "won" and match_state.winner == 1, "TM3 last team wins with its team id")
	return true

func test_same_tick_team_cases(runner) -> bool:
	var sim = _teamed([[1, 1], [2, 2], [3, 1]])
	var ally_a: int = sim.spawn(1, Vector2(10.5, 10.5), "usa_tank")
	var ally_b: int = sim.spawn(3, Vector2(10.5, 12.5), "usa_tank")
	var enemy: int = sim.spawn(2, Vector2(14.5, 11.5), "usa_tank")
	var hp: int = Economy.object(sim, enemy).hp
	var both_tick: int = -1
	for tick in range(60):
		sim.step()
		var attackers: Dictionary = {}
		for shot in _shots(sim):
			if shot.target_id == enemy: attackers[shot.attacker_id] = shot.damage
		if attackers.has(ally_a) and attackers.has(ally_b):
			both_tick = sim.tick()
			runner.check(Economy.object(sim, enemy).hp <= hp - attackers[ally_a] - attackers[ally_b] or Economy.object(sim, enemy).is_empty(), "TM4 both allied hits land on one tick")
			break
	runner.check(both_tick > 0, "TM4 two allies hit one enemy on the same tick")

	var guard_world = _teamed([[1, 1], [2, 2], [3, 1]])
	var victim: int = guard_world.spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry")
	var bystander: int = guard_world.spawn(3, Vector2(10.5, 11.5), "usa_rifle_infantry")
	guard_world.spawn(2, Vector2(14.5, 10.5), "usa_tank")
	var joined: bool = false
	for tick in range(90):
		guard_world.step()
		joined = joined or Economy.object(guard_world, bystander).get("combat", {}).get("mode", "") == "retaliate"
	runner.check(not joined, "TM5 retaliation never recruits an ally's unit")
	runner.check(not Combat.hostile(guard_world, 2, 2) and Combat.hostile(guard_world, 2, 1), "TM5 hostile is symmetric across teams")

	var moving = Economy.make_world()
	moving.add_player(3, 0, "human", 1)
	var reactor: int = Economy.build(runner, moving, "usa_power_plant", Vector2i(8, 4))
	var raider: int = moving.spawn(3, Vector2(8.5, 8.5), "usa_tank")
	Economy.send(moving, {"type": "attack_move", "player": 3, "entity_ids": [raider], "target": [9.0, 9.0]})
	var targeted: bool = false
	for tick in range(120):
		moving.step()
		targeted = targeted or Economy.object(moving, raider).combat.target_id != null
	runner.check(not targeted and Economy.object(moving, reactor).hp == Economy.object(moving, reactor).max_hp, "TM6 attack-move ignores an allied building")

	var ordered = _teamed([[1, 1], [2, 2], [3, 1]])
	var mine: int = ordered.spawn(1, Vector2(10.5, 10.5), "usa_tank")
	var friend: int = ordered.spawn(3, Vector2(12.5, 10.5), "usa_tank")
	var foe: int = ordered.spawn(2, Vector2(20.5, 10.5), "usa_tank")
	runner.check(Economy.send(ordered, {"type": "attack", "entity_ids": [mine], "target_id": friend}).error == "Invalid attack target", "TM7 explicit attack on an ally is rejected")
	runner.check(Economy.send(ordered, {"type": "attack", "entity_ids": [mine], "target_id": foe}).ok, "TM7 explicit attack on an enemy is accepted")

	var draw = _teamed([[1, 1], [2, 2], [3, 3]])
	var kept: int = draw.spawn(1, Vector2(4.5, 4.5), "usa_builder")
	var left_b: int = draw.spawn(2, Vector2(8.5, 4.5), "usa_builder")
	var left_c: int = draw.spawn(3, Vector2(12.5, 4.5), "usa_builder")
	draw.start_match([1, 2, 3] as Array[int])
	draw.remove_object(kept)
	draw.remove_object(left_b)
	draw.remove_object(left_c)
	draw.step()
	runner.check(draw.snapshot().match.status == "draw" and draw.snapshot().match.winner == null, "TM8 every team out on one tick is a draw")
	return true

func test_start_match_validation(runner) -> bool:
	var sim = _teamed([[1, 1], [2, 2]])
	sim.spawn(1, Vector2(4.5, 4.5), "usa_builder")
	runner.check(not sim.start_match([1] as Array[int]).ok, "TM9 one seat rejected")
	runner.check(not sim.start_match([1, 1, 2] as Array[int]).ok, "TM9 duplicate seat rejected")
	var nine = Fixture.world()
	var seats: Array[int] = []
	for seat in range(1, 10):
		nine.add_player(seat, 0, "human", seat)
		nine.spawn(seat, Vector2(1.5 + seat, 1.5), "usa_builder")
		seats.append(seat)
	runner.check(not nine.start_match(seats).ok, "TM9 nine seats rejected")
	var one_team = _teamed([[1, 1], [2, 1]])
	one_team.spawn(1, Vector2(4.5, 4.5), "usa_builder")
	one_team.spawn(2, Vector2(6.5, 4.5), "usa_builder")
	runner.check(not one_team.start_match([1, 2] as Array[int]).ok, "TM9 all seats on one team rejected")
	sim.spawn(2, Vector2(6.5, 4.5), "usa_builder")
	runner.check(sim.start_match([1, 2] as Array[int]).ok, "TM9 valid two-seat match starts")
	return true

func test_winner_is_team_id(runner) -> bool:
	var sim = _teamed([[1, 1], [2, 2], [3, 1]])
	var first: int = sim.spawn(1, Vector2(4.5, 4.5), "usa_builder")
	var foe: int = sim.spawn(2, Vector2(8.5, 4.5), "usa_builder")
	sim.spawn(3, Vector2(12.5, 4.5), "usa_builder")
	sim.start_match([1, 2, 3] as Array[int])
	sim.remove_object(first)
	sim.step()
	runner.check(sim.snapshot().match.status == "ongoing", "TM10 an ally survives, the team stays in")
	sim.remove_object(foe)
	sim.step()
	var match_state: Dictionary = sim.snapshot().match
	runner.check(match_state.status == "won" and match_state.winner == 1, "TM10 seats 1 and 3 on team 1: winner is the team id")
	return true

func test_friendly_fire_never_retaliates(runner) -> bool:
	var sim = _teamed([[1, 1], [3, 1]])
	var victim: int = sim.spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry")
	var guard: int = sim.spawn(1, Vector2(11.5, 10.5), "usa_rifle_infantry")
	var ally: int = sim.spawn(3, Vector2(14.5, 10.5), "usa_tank")
	Combat._retaliate_trigger(sim, [{"attacker_id": ally, "target_id": victim}] as Array[Dictionary])
	runner.check(sim._entities[victim].combat.mode == "guard" and sim._entities[guard].combat.mode == "guard" and sim.retaliations() == 0, "TM6 an ally's splash hit starts no retaliation")
	return true
