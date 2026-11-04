extends RefCounted

const Definitions = preload("res://scripts/simulation/combat_definitions.gd")
const Economy = preload("res://scripts/simulation/economy_definitions.gd")
const Construction = preload("res://scripts/simulation/construction.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Fixture = preload("res://tests/combat_fixture.gd")
const EconomyFixture = preload("res://tests/economy_fixture.gd")

func cases() -> Array[Callable]:
	return [test_combat_definitions, test_health_snapshot_isolation, test_weapon_range_boundary, test_damage_armor_matrix, test_weapon_cooldown, test_guard_priority, test_attack_validation_atomic, test_combat_intent_order, test_orders_preserve_reload, test_acquisition_throttle, test_mutual_lethal_fire, test_target_removed_cleanup, test_destroyed_unit_no_actions, test_destroyed_producer_accounting, test_same_tick_attack_and_cancel, test_removed_target_rescans, test_controller_and_scan_radius, test_scan_acquires_beyond_weapon_range, test_scan_radius_by_controller, test_scan_radius_boundary, test_removed_chaser_clears_chase, test_scan_keeps_target_leaving_radius, test_attack_move_resumes_after_chase, test_scan_same_tick_orders, test_scan_includes_buildings]

func test_combat_definitions(runner) -> bool:
	runner.check(Definitions.profile("infantry") == {"max_hp": 180000, "armor": "human", "weapon": "rifle"}, "D1 infantry")
	runner.check(Definitions.profile("tank") == {"max_hp": 480000, "armor": "tank", "weapon": "cannon"}, "D1 tank")
	runner.check(Definitions.profile("builder") == {"max_hp": 250000, "armor": "dozer", "weapon": ""}, "D1 builder")
	runner.check(Definitions.profile("collector") == {"max_hp": 300000, "armor": "chinook", "weapon": ""}, "D1 collector")
	runner.check(Definitions.profile("vehicle") == {"max_hp": 240000, "armor": "humvee", "weapon": ""}, "D1 legacy vehicle")
	var hp := {"reactor": 800000, "depot": 2000000, "factory": 2000000, "barracks": 1000000}
	for kind in hp:
		runner.check(Definitions.profile(kind) == {"max_hp": hp[kind], "armor": "structure", "weapon": ""}, "D1 " + kind)
	runner.check(Definitions.profile("nothing").is_empty() and Definitions.weapon("nothing").is_empty(), "D1 unknown empty")
	runner.check(Definitions.weapon("rifle") == {"damage": 5000, "damage_type": "small_arms", "range": 4.0, "delay_ticks": 3, "clip_size": 3, "reload_ticks": 21}, "D1 rifle")
	runner.check(Definitions.weapon("cannon") == {"damage": 60000, "damage_type": "armor_piercing", "range": 6.0, "delay_ticks": 60, "clip_size": 0, "reload_ticks": 0}, "D1 cannon")
	var rows := {"human": [100, 10], "tank": [25, 100], "dozer": [25, 100], "humvee": [50, 100], "structure": [50, 100], "chinook": [50, 50]}
	for armor in rows:
		runner.check(Definitions.armor_percent(armor, "small_arms") == rows[armor][0] and Definitions.armor_percent(armor, "armor_piercing") == rows[armor][1], "D1 armor " + armor)
	runner.check(Definitions.armor_percent("x", "small_arms") == 0 and Definitions.armor_percent("human", "x") == 0, "D1 unknown armor is zero")
	var changed: Dictionary = Definitions.profile("tank")
	changed.max_hp = 1
	var weapon: Dictionary = Definitions.weapon("rifle")
	weapon.damage = 1
	runner.check(Definitions.profile("tank").max_hp == 480000 and Definitions.weapon("rifle").damage == 5000, "D1 fresh dictionaries")
	var infantry: Dictionary = Economy.unit("infantry")
	runner.check(infantry == {"cost": 225, "ticks": 150, "speed": 0.8, "air": false, "producer": "barracks"}, "D1 infantry economy")
	runner.check(Economy.unit("tank") == {"cost": 900, "ticks": 300, "speed": 1.2, "air": false, "producer": "factory"}, "D1 tank economy")
	runner.check(Economy.building("barracks") == {"cost": 600, "ticks": 300, "power": 0, "footprint": Vector2i(2, 2), "prerequisite": "", "produces": "infantry"}, "D1 barracks economy")
	runner.check(Economy.unit("vehicle").cost == 700 and Economy.building("factory").produces == "vehicle", "D1 legacy vehicle unchanged")
	return true

func test_health_snapshot_isolation(runner) -> bool:
	var sim = Fixture.world()
	var rifle: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var builder: int = sim.spawn(1, Vector2(4.5, 2.5), "builder")
	var unit: Dictionary = Fixture.object(sim, rifle)
	runner.check(unit.hp == 180000 and unit.max_hp == 180000, "H1 full infantry health")
	runner.check(unit.combat == {"mode": "guard", "target_id": null, "goal": null, "next_fire_tick": 0, "shots_left": 3, "repath_tick": 0}, "H1 combat record")
	var worker: Dictionary = Fixture.object(sim, builder)
	runner.check(worker.hp == 250000 and worker.combat == null, "H1 unarmed has no combat")
	var tank: Dictionary = Fixture.object(sim, sim.spawn(2, Vector2(8.5, 2.5), "tank"))
	runner.check(tank.combat.shots_left == 0 and tank.max_hp == 480000, "H1 cannon unlimited clip")
	var state: Dictionary = sim.snapshot()
	runner.check(state.combat_events == [] and state.match == null, "H1 roots")
	state.entities[0].hp = 1
	state.entities[0].combat.goal = [1.0, 1.0]
	state.combat_events.append({})
	state.match = {}
	var again: Dictionary = sim.snapshot()
	runner.check(again.entities[0].hp == 180000 and again.entities[0].combat.goal == null and again.combat_events == [] and again.match == null, "H1 snapshot isolation")
	var next: int = again.next_entity_id
	runner.check(sim.spawn(1, Vector2(1.5, 1.5), "nothing") == -1 and sim.snapshot().next_entity_id == next, "H1 unknown kind consumes no ID")
	var world = EconomyFixture.make_world()
	runner.check(EconomyFixture.send(world, {"type": "build", "builder_id": 1, "building_kind": "reactor", "origin": [8, 8]}).ok, "H1 build accepted")
	world.step()
	var foundation: Dictionary = world.snapshot().buildings[0]
	runner.check(foundation.hp == 800000 and foundation.max_hp == 800000 and not foundation.completed, "H1 foundation full health")
	return true

func _shots(sim: RefCounted) -> Array:
	var shots: Array = []
	for event in sim.snapshot().combat_events:
		if event.type == "shot": shots.append(event)
	return shots

func _first_damage(sim: RefCounted) -> int:
	var shots: Array = _shots(sim)
	return shots[0].damage if not shots.is_empty() else 0

func _hit(shooter_kind: String, shooter_at: Vector2, target_kind: String, target_at: Vector2) -> int:
	var sim = Fixture.world()
	sim.spawn(1, shooter_at, shooter_kind)
	sim.spawn(2, target_at, target_kind)
	sim.step()
	return _first_damage(sim)

func test_weapon_range_boundary(runner) -> bool:
	runner.check(_hit("infantry", Vector2(2.5, 2.5), "builder", Vector2(6.5, 2.5)) == 1250, "R1 exact range hits")
	runner.check(_hit("infantry", Vector2(2.5, 2.5), "builder", Vector2(6.499, 2.5)) == 1250, "R1 inside hits")
	runner.check(_hit("infantry", Vector2(2.5, 2.5), "builder", Vector2(6.501, 2.5)) == 0, "R1 outside misses")
	for at in [Vector2(26.0, 21.0), Vector2(26.001, 21.0)]:
		var world = EconomyFixture.make_world()
		runner.check(EconomyFixture.send(world, {"type": "build", "builder_id": 1, "building_kind": "reactor", "origin": [20, 20]}).ok, "R1 foundation placed")
		world.spawn(2, at, "infantry")
		world.step()
		var foundation: Dictionary = world.snapshot().buildings[0]
		var expect_hit: bool = at.x < 26.0005
		runner.check((foundation.hp == 800000 - 2500) == expect_hit and (foundation.hp == 800000) != expect_hit, "R1 footprint nearest point " + str(at.x))
	var sim = Fixture.world()
	var shooter: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var friend: int = sim.spawn(1, Vector2(3.5, 2.5), "builder")
	var air: int = sim.spawn(2, Vector2(4.5, 2.5), "collector")
	var source: int = sim.add_supply_source(Vector2i(5, 5), 10)
	var enemy: int = sim.spawn(2, Vector2(2.5, 6.5), "builder")
	runner.check(not Combat.valid_target(sim, 1, friend) and not Combat.valid_target(sim, 1, air), "R1 friend and collector excluded")
	runner.check(not Combat.valid_target(sim, 1, source) and not Combat.valid_target(sim, 1, 999), "R1 source and missing excluded")
	runner.check(Combat.valid_target(sim, 1, enemy) and not Combat.valid_target(sim, 2, enemy), "R1 enemy included")
	sim.step()
	runner.check(_shots(sim).size() == 1 and _shots(sim)[0].target_id == enemy and _shots(sim)[0].attacker_id == shooter, "R1 only legal target shot")
	runner.check(Combat.distance_squared(Vector2(4, 3), {"kind": "reactor", "origin": [8, 2]}) == 16.0, "R1 distance to footprint")
	return true

func test_damage_armor_matrix(runner) -> bool:
	var rifle := {"infantry": 5000, "tank": 1250, "builder": 1250, "vehicle": 2500}
	for kind in rifle:
		runner.check(_hit("infantry", Vector2(2.5, 2.5), kind, Vector2(5.5, 2.5)) == rifle[kind], "A1 rifle vs " + kind)
	var cannon := {"infantry": 6000, "tank": 60000, "builder": 60000, "vehicle": 60000}
	for kind in cannon:
		runner.check(_hit("tank", Vector2(2.5, 2.5), kind, Vector2(5.5, 2.5)) == cannon[kind], "A1 cannon vs " + kind)
	var sim = Fixture.world()
	sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var victim: int = sim.spawn(2, Vector2(5.5, 2.5), "tank")
	sim.step()
	runner.check(Fixture.object(sim, victim).hp == 480000 - 1250, "A1 no whole-HP rounding")
	return true

func test_weapon_cooldown(runner) -> bool:
	var sim = Fixture.world()
	var rifle: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var victim: int = sim.spawn(2, Vector2(5.5, 2.5), "builder")
	var fired: Array[int] = []
	for tick in range(34):
		sim.step()
		for event in sim.snapshot().combat_events:
			if event.type == "shot" and event.attacker_id == rifle:
				fired.append(event.tick)
		if tick == 6:
			runner.check(Fixture.object(sim, victim).hp == 246250, "W1 three armor-adjusted shots")
			sim.snapshot()
			sim.snapshot()
	runner.check(fired == [0, 3, 6, 27, 30, 33], "W1 burst and reload boundaries")
	var big = Fixture.world()
	var tank: int = big.spawn(1, Vector2(2.5, 2.5), "tank")
	var target: int = big.spawn(2, Vector2(6.5, 2.5), "vehicle")
	var cannon: Array[int] = []
	for tick in range(121):
		big.step()
		for event in big.snapshot().combat_events:
			if event.type == "shot" and event.attacker_id == tank: cannon.append(event.tick)
	runner.check(cannon == [0, 60, 120] and Fixture.object(big, target).hp == 60000, "W1 cannon cadence and damage")
	return true

func test_guard_priority(runner) -> bool:
	var sim = Fixture.world()
	var shooter: int = sim.spawn(1, Vector2(10.5, 10.5), "infantry")
	var high: int = sim.spawn(2, Vector2(12.5, 10.5), "builder")
	var low: int = sim.spawn(2, Vector2(8.5, 10.5), "builder")
	sim.spawn(1, Vector2(10.5, 9.5), "builder")
	sim.step()
	runner.check(_shots(sim)[0].target_id == min(high, low), "G1 equal distance ties by ID")
	var retained: int = Fixture.object(sim, shooter).combat.target_id
	var nearer: int = sim.spawn(2, Vector2(10.5, 11.5), "builder")
	sim.step()
	runner.check(Fixture.object(sim, shooter).combat.target_id == retained and retained != nearer, "G1 retained valid target stays")
	var idle = Fixture.world()
	var walker: int = idle.spawn(1, Vector2(2.5, 2.5), "infantry")
	idle.spawn(2, Vector2(12.5, 2.5), "builder")
	var start: Array = Fixture.object(idle, walker).position
	for tick in range(30): idle.step()
	var unit: Dictionary = Fixture.object(idle, walker)
	runner.check(unit.position == start and unit.status == "idle" and idle.snapshot().combat_events.is_empty(), "G1 guard never chases")
	return true

func _rejected(runner, sim: RefCounted, payload: Dictionary, label: String) -> void:
	var before: Dictionary = sim.snapshot()
	var result: Dictionary = Fixture.send(sim, payload)
	runner.check(not result.ok and not result.error.is_empty(), label + " rejected with reason")
	runner.check(sim.snapshot() == before, label + " snapshot unchanged")

func test_attack_validation_atomic(runner) -> bool:
	var sim = Fixture.world()
	var rifle: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var tank: int = sim.spawn(1, Vector2(2.5, 4.5), "tank")
	var worker: int = sim.spawn(1, Vector2(2.5, 6.5), "builder")
	var enemy: int = sim.spawn(2, Vector2(20.5, 2.5), "builder")
	var enemy_unit: int = sim.spawn(2, Vector2(20.5, 4.5), "infantry")
	var friend: int = sim.spawn(1, Vector2(4.5, 6.5), "builder")
	var air: int = sim.spawn(2, Vector2(20.5, 6.5), "collector")
	var source: int = sim.add_supply_source(Vector2i(10, 10), 5)
	runner.check(Fixture.send(sim, {"type": "attack", "entity_ids": [rifle, tank], "target_id": enemy}).ok, "V1 mixed armed group accepted")
	for case in [
		["missing ids", {"type": "attack", "target_id": enemy}],
		["bool id", {"type": "attack", "entity_ids": [true], "target_id": enemy}],
		["string id", {"type": "attack", "entity_ids": ["1"], "target_id": enemy}],
		["duplicate", {"type": "attack", "entity_ids": [rifle, rifle], "target_id": enemy}],
		["missing target", {"type": "attack", "entity_ids": [rifle], "target_id": 999}],
		["bool target", {"type": "attack", "entity_ids": [rifle], "target_id": true}],
		["enemy member", {"type": "attack", "entity_ids": [enemy_unit], "target_id": enemy}],
		["unarmed member", {"type": "attack", "entity_ids": [rifle, worker], "target_id": enemy}],
		["friend target", {"type": "attack", "entity_ids": [rifle], "target_id": friend}],
		["source target", {"type": "attack", "entity_ids": [rifle], "target_id": source}],
		["collector target", {"type": "attack", "entity_ids": [rifle], "target_id": air}],
		["attack_move unarmed", {"type": "attack_move", "entity_ids": [rifle, worker], "target": [9.5, 9.5]}],
		["attack_move off map", {"type": "attack_move", "entity_ids": [rifle], "target": [99.5, 9.5]}],
		["attack_move string", {"type": "attack_move", "entity_ids": [rifle], "target": ["a", 9.5]}],
		["attack_move missing target", {"type": "attack_move", "entity_ids": [rifle]}],
	]:
		_rejected(runner, sim, case[1], "V1 " + case[0])
	sim.remove_object(enemy)
	_rejected(runner, sim, {"type": "attack", "entity_ids": [rifle], "target_id": enemy}, "V1 dead target")
	var ids: Array = [rifle]
	var target: Array = [9.5, 9.5]
	var tick: int = sim.snapshot().tick + 2
	var last: int = sim.snapshot().last_sequences[0].sequence + 1
	runner.check(sim.issue_command({"tick": tick, "player": 1, "sequence": last, "type": "attack_move", "entity_ids": ids, "target": target}).ok, "V1 future accepted")
	ids.append(tank)
	target[0] = 1.5
	var pending: Dictionary = {}
	for command in sim.snapshot().pending_commands:
		if command.type == "attack_move": pending = command
	runner.check(pending.get("entity_ids") == [rifle] and pending.get("target") == [9.5, 9.5], "V1 future command deep copied")
	return true

func _mode(sim: RefCounted, id: int) -> Dictionary:
	return Fixture.object(sim, id).combat

func test_combat_intent_order(runner) -> bool:
	var sim = Fixture.world()
	var rifle: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var enemy: int = sim.spawn(2, Vector2(20.5, 2.5), "builder")
	Fixture.send(sim, {"type": "attack", "entity_ids": [rifle], "target_id": enemy})
	Fixture.send(sim, {"type": "move", "entity_ids": [rifle], "target": [2.5, 10.5]})
	sim.step()
	runner.check(_mode(sim, rifle).mode == "move" and _mode(sim, rifle).target_id == null, "I1 attack then move ends move")
	Fixture.send(sim, {"type": "attack", "entity_ids": [rifle], "target_id": enemy})
	sim.step()
	var unit: Dictionary = Fixture.object(sim, rifle)
	runner.check(unit.combat.mode == "attack" and unit.combat.target_id == enemy and unit.destination == [16.5, 2.5], "I1 move then attack replaces the move with a chase")
	Fixture.send(sim, {"type": "attack_move", "entity_ids": [rifle], "target": [5.5, 2.5]})
	sim.step()
	unit = Fixture.object(sim, rifle)
	runner.check(unit.combat.mode == "attack_move" and unit.combat.goal == [5.5, 2.5] and unit.order.target == [5.5, 2.5], "I1 attack_move keeps goal and ordinary movement order")
	Fixture.send(sim, {"type": "attack", "entity_ids": [rifle], "target_id": enemy})
	Fixture.send(sim, {"type": "stop", "entity_ids": [rifle]})
	sim.step()
	unit = Fixture.object(sim, rifle)
	runner.check(unit.combat.mode == "guard" and unit.combat.target_id == null and unit.combat.goal == null, "I1 attack then stop ends guard")
	# A due-invalid attack must not supersede an earlier valid move.
	Fixture.send(sim, {"type": "move", "entity_ids": [rifle], "target": [2.5, 12.5]})
	Fixture.send(sim, {"type": "attack", "entity_ids": [rifle], "target_id": enemy})
	sim.remove_object(enemy)
	sim.step()
	unit = Fixture.object(sim, rifle)
	var results: Array = sim.snapshot().command_results
	runner.check(unit.combat.mode == "move" and unit.order != null and not results[results.size() - 1].ok, "I1 invalid later attack keeps valid move")
	# Two queued attacks on a target removed before due: both fail, nothing stale remains.
	var other = Fixture.world()
	var shooter: int = other.spawn(1, Vector2(2.5, 2.5), "infantry")
	var victim: int = other.spawn(2, Vector2(3.5, 2.5), "builder")
	Fixture.send(other, {"type": "attack", "entity_ids": [shooter], "target_id": victim})
	Fixture.send(other, {"type": "attack", "entity_ids": [shooter], "target_id": victim})
	other.remove_object(victim)
	other.step()
	var state: Dictionary = other.snapshot()
	runner.check(state.command_results.size() == 2 and not state.command_results[0].ok and not state.command_results[1].ok, "I1 both stale attacks fail")
	runner.check(state.path_queue.is_empty() and state.entities[0].destination == null and state.entities[0].combat.mode == "guard", "I1 nothing stale remains")
	return true

func test_orders_preserve_reload(runner) -> bool:
	var sim = Fixture.world()
	var rifle: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var enemy: int = sim.spawn(2, Vector2(5.5, 2.5), "builder")
	for tick in range(7): sim.step()
	runner.check(_mode(sim, rifle).next_fire_tick == 27 and _mode(sim, rifle).shots_left == 3, "L1 reload scheduled after clip")
	var fired := 0
	var commands: Array = [
		{"type": "stop", "entity_ids": [rifle]},
		{"type": "attack", "entity_ids": [rifle], "target_id": enemy},
		{"type": "move", "entity_ids": [rifle], "target": [3.5, 2.5]},
		{"type": "stop", "entity_ids": [rifle]},
		{"type": "attack", "entity_ids": [rifle], "target_id": enemy},
	]
	for index in range(20):
		if index < commands.size(): Fixture.send(sim, commands[index])
		sim.step()
		fired += _shots(sim).size()
	runner.check(fired == 0, "L1 no extra shot before reload ends")
	runner.check(_mode(sim, rifle).next_fire_tick == 27 and _mode(sim, rifle).shots_left == 3, "L1 intent changes keep timer and ammo")
	var partial = Fixture.world()
	var shooter: int = partial.spawn(1, Vector2(2.5, 2.5), "infantry")
	var first: int = partial.spawn(2, Vector2(5.5, 2.5), "builder")
	var second: int = partial.spawn(2, Vector2(2.5, 5.5), "builder")
	Fixture.send(partial, {"type": "attack", "entity_ids": [shooter], "target_id": first})
	partial.step()
	Fixture.send(partial, {"type": "attack", "entity_ids": [shooter], "target_id": second})
	partial.step()
	runner.check(_mode(partial, shooter).shots_left == 2 and _mode(partial, shooter).next_fire_tick == 3 and _mode(partial, shooter).target_id == second, "L1 retarget keeps partial clip")
	partial.step()
	partial.step()
	runner.check(_shots(partial).size() == 1 and _shots(partial)[0].target_id == second, "L1 next shot hits new target on schedule")
	return true

func _first_shot_tick(sim: RefCounted, from: int, limit: int, runner, label: String) -> int:
	for tick in range(from, limit):
		sim.step()
		if not _shots(sim).is_empty(): return tick
		runner.check(sim.combat_work() == 0, label + " no scan work on tick " + str(tick))
	return -1

func test_acquisition_throttle(runner) -> bool:
	var sim = Fixture.world()
	var guard: int = sim.spawn(1, Vector2(10.5, 10.5), "infantry")
	sim.step()
	runner.check(Fixture.object(sim, guard).combat.repath_tick == 14, "T1 idle scan schedules the unit's next phase tick")
	sim.spawn(2, Vector2(12.5, 10.5), "builder")
	runner.check(_first_shot_tick(sim, 1, 30, runner, "T1") == 14, "T1 throttled guard first fires at its phase tick")
	var fresh = Fixture.world()
	var other: int = fresh.spawn(1, Vector2(10.5, 10.5), "infantry")
	fresh.step()
	fresh.spawn(2, Vector2(12.5, 10.5), "builder")
	Fixture.send(fresh, {"type": "stop", "entity_ids": [other]})
	runner.check(_first_shot_tick(fresh, 1, 30, runner, "T2") == 14, "T2 stop delays the next scan to the unit's phase tick like Zero Hour idle")
	return true

func _events(sim: RefCounted) -> Array:
	return sim.snapshot().combat_events

func test_mutual_lethal_fire(runner) -> bool:
	for owners in [[1, 2], [2, 1]]:
		var sim = Fixture.world()
		var a: int = sim.spawn(owners[0], Vector2(10.5, 10.5), "tank")
		var b: int = sim.spawn(owners[1], Vector2(14.5, 10.5), "tank")
		var shot_ticks := {a: [], b: []}
		var death_tick: int = -1
		for tick in range(480):
			sim.step()
			var events: Array = _events(sim)
			for event in events:
				if event.type == "shot": shot_ticks[event.attacker_id].append(event.tick)
				elif event.type == "death" and death_tick == -1: death_tick = event.tick
			if death_tick == tick:
				var kinds: Array = events.map(func(event: Dictionary) -> String: return event.type)
				runner.check(kinds == ["shot", "shot", "death", "death"], "L1 shots first, then deaths")
				runner.check(events[2].object_id < events[3].object_id, "L1 deaths in ascending ID order")
		var expected: Array = [0, 60, 120, 180, 240, 300, 360, 420]
		runner.check(shot_ticks[a] == expected and shot_ticks[b] == expected, "L1 eight shots each, no ninth")
		runner.check(death_tick == 420, "L1 both die in the same fire phase")
		var state: Dictionary = sim.snapshot()
		runner.check(state.entities.is_empty() and state.path_queue.is_empty() and state.next_entity_id == 3, "L1 nothing left behind, no IDs consumed")
	var group = Fixture.world()
	for at in [Vector2(10.5, 10.5), Vector2(10.5, 11.5), Vector2(10.5, 9.5)]: group.spawn(1, at, "tank")
	var victim: int = group.spawn(2, Vector2(14.5, 10.5), "tank")
	var deaths: Array[int] = []
	for tick in range(240):
		group.step()
		for event in _events(group):
			if event.type == "death" and event.object_id == victim: deaths.append(event.tick)
	runner.check(deaths == [120], "L1 three volleys kill the target exactly once at tick 120")
	return true

func test_target_removed_cleanup(runner) -> bool:
	var sim = Fixture.world()
	var chaser: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var target: int = sim.spawn(2, Vector2(12.5, 2.5), "builder")
	Fixture.send(sim, {"type": "attack", "entity_ids": [chaser], "target_id": target})
	sim.step()
	runner.check(Fixture.object(sim, chaser).destination != null, "R1 chase under way")
	runner.check(sim.remove_object(target).ok, "R1 target removed")
	runner.check(not sim.remove_object(target).ok, "R1 second removal rejected")
	sim.step()
	var unit: Dictionary = Fixture.object(sim, chaser)
	runner.check(unit.combat.mode == "guard" and unit.combat.target_id == null and unit.status == "idle" and unit.destination == null and not sim.snapshot().path_queue.has(chaser), "R1 attacker guards and stops chasing")
	var before: Dictionary = sim.snapshot()
	runner.check(not sim.remove_object(999).ok and sim.snapshot() == before, "R1 unknown removal leaves state unchanged")
	var mover = Fixture.world()
	var scout: int = mover.spawn(1, Vector2(2.5, 2.5), "infantry")
	var enemy: int = mover.spawn(2, Vector2(9.5, 4.5), "builder")
	Fixture.send(mover, {"type": "attack_move", "entity_ids": [scout], "target": [20.5, 2.5]})
	for tick in range(400):
		mover.step()
		if Fixture.object(mover, scout).combat.target_id == enemy: break
	runner.check(Fixture.object(mover, scout).combat.target_id == enemy, "R1 scout engaged before removal")
	mover.remove_object(enemy)
	mover.step()
	unit = Fixture.object(mover, scout)
	runner.check(unit.combat.mode == "attack_move" and unit.combat.goal == [20.5, 2.5] and unit.combat.target_id == null, "R1 attack_move keeps its goal")
	var duel = Fixture.world()
	var killer: int = duel.spawn(1, Vector2(10.5, 10.5), "tank")
	var victim: int = duel.spawn(2, Vector2(14.5, 10.5), "builder")
	Fixture.send(duel, {"type": "attack", "entity_ids": [killer], "target_id": victim})
	for tick in range(400):
		duel.step()
		if not duel.snapshot().entities.any(func(entity: Dictionary) -> bool: return entity.id == victim): break
	duel.step()
	unit = Fixture.object(duel, killer)
	runner.check(unit.combat.mode == "guard" and unit.combat.target_id == null, "R1 combat death clears the attacker")
	return true

func test_destroyed_unit_no_actions(runner) -> bool:
	var sim = EconomyFixture.make_world(10000)
	sim.add_player(2, 0)
	var result: Dictionary = EconomyFixture.send(sim, {"type": "build", "builder_id": 1, "building_kind": "reactor", "origin": [8, 4]})
	runner.check(result.ok, "D1 build accepted")
	var site: int = sim.snapshot().next_entity_id
	var guard: int = 0
	while guard < 600 and EconomyFixture.object(sim, site).get("work", 0) == 0:
		sim.step()
		guard += 1
	var builder: Dictionary = EconomyFixture.object(sim, 1)
	runner.check(EconomyFixture.object(sim, site).get("work", 0) > 0 and builder.position == [7.5, 4.5], "D1 builder working")
	for offset in [Vector2(-3, 0), Vector2(-3, 1), Vector2(-3, -1), Vector2(-4, 0), Vector2(-4, 1)]:
		sim.spawn(2, Vector2(builder.position[0], builder.position[1]) + offset, "tank")
	var before: int = EconomyFixture.object(sim, site).work
	sim.step()
	var foundation: Dictionary = EconomyFixture.object(sim, site)
	runner.check(EconomyFixture.object(sim, 1).is_empty(), "D1 builder killed in one volley")
	runner.check(foundation.work == before + 1000, "D1 the death tick still gets its work step")
	runner.check(foundation.builder_id == null and not foundation.completed, "D1 foundation unbound")
	EconomyFixture.steps(sim, 30)
	runner.check(EconomyFixture.object(sim, site).work == before + 1000, "D1 no later work")
	var armed = Fixture.world()
	var doomed: int = armed.spawn(1, Vector2(10.5, 10.5), "tank")
	for at in [Vector2(14.5, 10.5), Vector2(14.5, 11.5), Vector2(14.5, 9.5), Vector2(15.5, 10.5), Vector2(15.5, 11.5)]: armed.spawn(2, at, "tank")
	var ticks: Array[int] = []
	for tick in range(120):
		armed.step()
		for event in _events(armed):
			if event.type == "shot" and event.attacker_id == doomed: ticks.append(event.tick)
	runner.check(ticks == [0, 60] and Fixture.object(armed, doomed).is_empty(), "D1 a unit killed in the fire phase still shoots that phase, never after")
	return true

func test_destroyed_producer_accounting(runner) -> bool:
	var sim = EconomyFixture.make_world(10000, Vector2i(32, 32))
	sim.add_player(2, 0)
	EconomyFixture.build(runner, sim, "reactor", Vector2i(8, 12))
	EconomyFixture.build(runner, sim, "depot", Vector2i(8, 5))
	var factory: int = EconomyFixture.build(runner, sim, "factory", Vector2i(12, 18))
	runner.check(factory != -1, "P1 factory built")
	var attackers: Array = []
	for at in [Vector2(20.5, 18.5), Vector2(20.5, 19.5), Vector2(20.5, 20.5), Vector2(19.5, 18.5), Vector2(19.5, 19.5)]:
		attackers.append(sim.spawn(2, at, "tank"))
	for i in range(3):
		runner.check(EconomyFixture.send(sim, {"type": "produce", "building_id": factory, "unit_kind": "tank"}).ok, "P1 tank queued")
	Fixture.send(sim, {"player": 2, "type": "attack", "entity_ids": attackers, "target_id": factory})
	var start: int = sim.snapshot().tick
	var before_death: int = -1
	var after_death: int = -1
	var death_tick: int = -1
	for tick in range(400):
		var credits: int = sim.snapshot().players[0].credits
		sim.step()
		for event in _events(sim):
			if event.type == "death" and event.object_id == factory:
				before_death = credits
				after_death = sim.snapshot().players[0].credits
				death_tick = event.tick
		if after_death != -1: break
	runner.check(death_tick == start + 360, "P1 factory dies at the seventh volley, got " + str(death_tick - start))
	runner.check(after_death - before_death == 1800, "P1 two unfinished paid entries refunded once")
	var tanks: int = sim.snapshot().entities.filter(func(entity: Dictionary) -> bool: return entity.owner == 1 and entity.kind == "tank").size()
	runner.check(tanks == 1, "P1 the tank finished before the death tick survives")
	runner.check(EconomyFixture.object(sim, factory).is_empty(), "P1 producer removed")
	EconomyFixture.steps(sim, 60)
	runner.check(sim.snapshot().players[0].credits == after_death, "P1 no second refund")
	return true

func test_same_tick_attack_and_cancel(runner) -> bool:
	var sim = EconomyFixture.make_world(10000)
	sim.add_player(2, 10000)
	var builder: int = sim.spawn(2, Vector2(20.5, 20.5), "builder")
	var site: int = sim.snapshot().next_entity_id
	EconomyFixture.send(sim, {"player": 2, "type": "build", "builder_id": builder, "building_kind": "reactor", "origin": [24, 20]})
	sim.step()
	runner.check(not EconomyFixture.object(sim, site).is_empty(), "C1 foundation exists")
	var attacker: int = sim.spawn(1, Vector2(10.5, 20.5), "infantry")
	EconomyFixture.send(sim, {"type": "attack", "entity_ids": [attacker], "target_id": site})
	EconomyFixture.send(sim, {"player": 2, "type": "cancel_build", "building_id": site})
	sim.step()
	sim.step()
	var unit: Dictionary = EconomyFixture.object(sim, attacker)
	runner.check(EconomyFixture.object(sim, site).is_empty() and unit.combat.target_id == null and unit.combat.mode == "guard", "C1 cancelled target never becomes an attack target")
	return true

func test_removed_target_rescans(runner) -> bool:
	var sim = Fixture.world()
	var chaser: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var target: int = sim.spawn(2, Vector2(12.5, 2.5), "builder")
	sim.spawn(2, Vector2(2.5, 5.0), "builder")
	Fixture.send(sim, {"type": "attack", "entity_ids": [chaser], "target_id": target})
	sim.step()
	sim.remove_object(target)
	runner.check(_first_shot_tick(sim, 1, 30, runner, "S1") == 1, "S1 a chaser whose target vanished rescans at once")
	return true

func test_controller_and_scan_radius(runner) -> bool:
	var sim = Fixture.world()
	runner.check(not sim.add_player(3, 0, "bot").ok, "C1 unknown controller is rejected")
	runner.check(sim.add_player(3, 0, "bot").error == "Invalid controller", "C1 rejection names the controller")
	var skirmish = Skirmish.create()
	var players: Array = skirmish.snapshot().players
	runner.check(players[0].id == 1 and players[0].controller == "human", "C2 player 1 is human")
	runner.check(players[1].id == 2 and players[1].controller == "ai", "C2 player 2 is ai")
	var infantry: int = skirmish.spawn(1, Vector2(10.5, 10.5), "infantry")
	var tank: int = skirmish.spawn(1, Vector2(12.5, 10.5), "tank")
	var ai_infantry: int = skirmish.spawn(2, Vector2(20.5, 10.5), "infantry")
	var ai_tank: int = skirmish.spawn(2, Vector2(22.5, 10.5), "tank")
	runner.check(is_equal_approx(Combat.scan_radius(skirmish, skirmish._entities[infantry]), 8.8), "C3 human infantry radius")
	runner.check(is_equal_approx(Combat.scan_radius(skirmish, skirmish._entities[tank]), 13.2), "C3 human tank radius")
	runner.check(is_equal_approx(Combat.scan_radius(skirmish, skirmish._entities[ai_infantry]), 5.332), "C3 ai infantry radius")
	runner.check(is_equal_approx(Combat.scan_radius(skirmish, skirmish._entities[ai_tank]), 7.998), "C3 ai tank radius")
	var orphan: int = sim.spawn(9, Vector2(5.5, 5.5), "infantry")
	runner.check(is_equal_approx(Combat.scan_radius(sim, sim._entities[orphan]), 8.8), "C4 owner without player record is human")
	var builder: int = skirmish.spawn(1, Vector2(14.5, 10.5), "builder")
	runner.check(Combat.scan_radius(skirmish, skirmish._entities[builder]) == 0.0, "C5 unarmed unit has no scan radius")
	return true

func _scan_shot_within(sim: RefCounted, limit: int) -> bool:
	for tick in range(limit):
		sim.step()
		if not _shots(sim).is_empty(): return true
	return false

func test_scan_acquires_beyond_weapon_range(runner) -> bool:
	var sim = Fixture.world()
	var guard: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var builder: int = sim.spawn(2, Vector2(10.5, 2.5), "builder")
	sim.step()
	var unit: Dictionary = Fixture.object(sim, guard)
	runner.check(unit.combat.target_id == builder and unit.combat.mode == "guard", "X1 guard acquires an enemy 8 cells away and stays in guard")
	runner.check(unit.status != "idle", "X1 guard approaches the out-of-range target")
	runner.check(_scan_shot_within(sim, 300), "X1 chasing guard later fires")
	var far = Fixture.world()
	var idle: int = far.spawn(1, Vector2(2.5, 2.5), "infantry")
	far.spawn(2, Vector2(11.5, 2.5), "builder")
	far.step()
	runner.check(Fixture.object(far, idle).combat.target_id == null, "X2 enemy 9 cells away is outside the 8.8 radius")
	return true

func test_scan_radius_by_controller(runner) -> bool:
	var near = Fixture.world()
	near.add_player(2, 0, "ai")
	var scanner: int = near.spawn(2, Vector2(2.5, 2.5), "infantry")
	var prey: int = near.spawn(1, Vector2(7.8, 2.5), "builder")
	near.step()
	runner.check(Fixture.object(near, scanner).combat.target_id == prey, "R1 ai infantry acquires at 5.3 cells")
	var far = Fixture.world()
	far.add_player(2, 0, "ai")
	var blind: int = far.spawn(2, Vector2(2.5, 2.5), "infantry")
	far.spawn(1, Vector2(7.9, 2.5), "builder")
	far.step()
	runner.check(Fixture.object(far, blind).combat.target_id == null, "R1 ai infantry ignores an enemy at 5.4 cells")
	return true

func test_scan_radius_boundary(runner) -> bool:
	for case in [[11.29, true], [11.31, false]]:
		var sim = Fixture.world()
		var guard: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
		sim.spawn(2, Vector2(case[0], 2.5), "builder")
		sim.step()
		runner.check((Fixture.object(sim, guard).combat.target_id != null) == case[1], "R2 enemy at x=" + str(case[0]) + " (radius 8.8): acquired=" + str(case[1]))
	return true

func test_removed_chaser_clears_chase(runner) -> bool:
	var sim = Fixture.world()
	var guard: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	sim.spawn(2, Vector2(10.5, 2.5), "builder")
	sim.step()
	runner.check(sim._chases.has(guard), "R3 chase started")
	sim.remove_object(guard)
	runner.check(not sim._chases.has(guard), "R3 removing the chaser clears its chase")
	return true

func test_scan_keeps_target_leaving_radius(runner) -> bool:
	var sim = Fixture.world()
	var guard: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var builder: int = sim.spawn(2, Vector2(10.5, 2.5), "builder")
	sim.step()
	runner.check(Fixture.object(sim, guard).combat.target_id == builder, "K1 chase started")
	sim._entities[builder].position = [30.5, 2.5]
	sim.step()
	var unit: Dictionary = Fixture.object(sim, guard)
	runner.check(unit.combat.target_id == builder and unit.combat.mode == "guard", "K1 acquired target outside the radius is kept, like Zero Hour and OpenRA")
	runner.check(unit.status != "idle", "K1 the unit keeps chasing")
	sim.remove_object(builder)
	sim.step()
	runner.check(Fixture.object(sim, guard).combat.target_id == null, "K1 a removed target is dropped")
	return true

func test_attack_move_resumes_after_chase(runner) -> bool:
	var sim = Fixture.world()
	var walker: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var goal := [2.5, 20.5]
	Fixture.send(sim, {"type": "attack_move", "entity_ids": [walker], "target": goal})
	var prey: int = sim.spawn(2, Vector2(10.5, 8.5), "builder")
	sim._entities[prey].hp = 1
	var killed: bool = false
	for tick in range(600):
		sim.step()
		for event in sim.snapshot().combat_events:
			if event.type == "death" and event.object_id == prey: killed = true
		if killed: break
	runner.check(killed, "M1 the off-path enemy is chased and killed")
	sim.step()
	var unit: Dictionary = Fixture.object(sim, walker)
	runner.check(unit.combat.mode == "attack_move" and unit.combat.goal == goal, "M1 combat goal is unchanged after the chase")
	for tick in range(1500):
		sim.step()
		if Vector2(Fixture.object(sim, walker).position[0], Fixture.object(sim, walker).position[1]).distance_to(Vector2(goal[0], goal[1])) < 1.0: break
	var end: Dictionary = Fixture.object(sim, walker)
	runner.check(Vector2(end.position[0], end.position[1]).distance_to(Vector2(goal[0], goal[1])) < 1.0, "M1 the unit reaches the original goal")
	return true

func _chasing_world() -> Array:
	var sim = Fixture.world()
	var guard: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var builder: int = sim.spawn(2, Vector2(10.5, 2.5), "builder")
	var other: int = sim.spawn(2, Vector2(2.5, 11.5), "builder")
	sim.step()
	return [sim, guard, builder, other]

func test_scan_same_tick_orders(runner) -> bool:
	var moved: Array = _chasing_world()
	Fixture.send(moved[0], {"type": "move", "entity_ids": [moved[1]], "target": [2.5, 20.5]})
	moved[0].step()
	var unit: Dictionary = Fixture.object(moved[0], moved[1])
	runner.check(unit.combat.mode == "move" and unit.combat.target_id == null and unit.destination != null and unit.destination[1] > 15.0, "O1 move replaces the chase")
	var stopped: Array = _chasing_world()
	Fixture.send(stopped[0], {"type": "stop", "entity_ids": [stopped[1]]})
	stopped[0].step()
	var halted: Dictionary = Fixture.object(stopped[0], stopped[1])
	runner.check(halted.combat.mode == "guard" and halted.combat.target_id == null and halted.status == "idle", "O2 stop returns to guard and does not re-acquire in the same tick")
	for tick in range(20): stopped[0].step()
	runner.check(Fixture.object(stopped[0], stopped[1]).combat.target_id != null, "O2 guard re-acquires after the delay")
	var attacking: Array = _chasing_world()
	Fixture.send(attacking[0], {"type": "attack", "entity_ids": [attacking[1]], "target_id": attacking[3]})
	attacking[0].step()
	var attacker: Dictionary = Fixture.object(attacking[0], attacking[1])
	runner.check(attacker.combat.mode == "attack" and attacker.combat.target_id == attacking[3], "O3 attack replaces the chase")
	var marching: Array = _chasing_world()
	Fixture.send(marching[0], {"type": "attack_move", "entity_ids": [marching[1]], "target": [2.5, 20.5]})
	marching[0].step()
	var marcher: Dictionary = Fixture.object(marching[0], marching[1])
	runner.check(marcher.combat.mode == "attack_move" and marcher.combat.goal == [2.5, 20.5], "O4 attack_move replaces the chase")
	var removed: Array = _chasing_world()
	removed[0].remove_object(removed[2])
	removed[0].remove_object(removed[3])
	removed[0].step()
	var orphan: Dictionary = Fixture.object(removed[0], removed[1])
	runner.check(orphan.combat.target_id == null and orphan.status == "idle", "O5 a target removed on a scan tick leaves no stale target and ends the chase")
	return true

func test_scan_includes_buildings(runner) -> bool:
	var sim = EconomyFixture.make_world()
	sim.add_player(2, 0, "human")
	var placed: Dictionary = EconomyFixture.send(sim, {"type": "build", "builder_id": 1, "building_kind": "reactor", "origin": [14, 4]})
	runner.check(placed.ok, "B1 foundation placement accepted")
	EconomyFixture.steps(sim, 2)
	sim.remove_object(1)
	var scanner: int = sim.spawn(2, Vector2(6.0, 4.5), "infantry")
	sim.step()
	var foundation: Array = sim.snapshot().buildings
	runner.check(not foundation.is_empty() and Fixture.object(sim, scanner).combat.target_id == foundation[0].id, "B1 an enemy foundation 8 cells away is acquired")
	return true
