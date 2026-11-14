@warning_ignore_start("untyped_declaration")
extends RefCounted

const Definitions = preload("res://scripts/simulation/combat_definitions.gd")
const Economy = preload("res://scripts/simulation/economy_definitions.gd")
const Construction = preload("res://scripts/simulation/construction.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Fixture = preload("res://tests/combat_fixture.gd")
const EconomyFixture = preload("res://tests/economy_fixture.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")

func cases() -> Array[Callable]:
	return [test_leash_square_matches_pow, test_combat_definitions, test_definitions_shared, test_health_snapshot_isolation, test_weapon_range_boundary, test_ranger_fires_at_edge_max, test_crusader_fires_at_edge_max, test_rifle_cycle_30, test_firing_cell_uses_edge, test_building_edge_range, test_damage_armor_matrix, test_weapon_cooldown, test_guard_priority, test_attack_validation_atomic, test_combat_intent_order, test_orders_preserve_reload, test_acquisition_throttle, test_mutual_lethal_fire, test_target_removed_cleanup, test_destroyed_unit_no_actions, test_destroyed_producer_accounting, test_same_tick_attack_and_cancel, test_removed_target_rescans, test_controller_and_scan_radius, test_scan_acquires_beyond_weapon_range, test_scan_radius_by_controller, test_scan_radius_boundary, test_removed_chaser_clears_chase, test_scan_keeps_target_leaving_radius, test_attack_move_resumes_after_chase, test_scan_same_tick_orders, test_scan_includes_buildings, test_human_guard_in_range_only, test_human_guard_holds_against_kiting, test_ai_guard_unchanged, test_human_attack_move_marches_in_range, test_human_attack_move_post_kill_rescan, test_human_attack_move_follows_retreat, test_rescan_same_tick_orders, test_human_attack_move_drops_target_out_of_range, test_human_attack_move_first_approach_has_no_leash, test_retarget_only_for_attack_move, test_missing_id_skipped, test_due_tick_death_skips_member, test_foreign_id_rejects, test_attack_move_mixed_selection, test_retaliate_trigger_distance, test_retaliate_joiners, test_retaliate_leash_and_return, test_retaliate_return_scan_and_rehit, test_retaliate_same_tick_cases, test_retaliate_go_home_queues_once, test_rng_sequence, test_splash_victims_boundary, test_splash_cluster, test_splash_mask, test_splash_last_builder_same_tick, test_splash_event_flag, test_rocket_splash_and_scatter, test_damage_table_new_types, test_damage_table_gattling, test_damage_table_frc_weapons, test_nearest_matches_oracle, test_radius_cache, test_splash_index_matches_oracle, test_splash_hits_passenger_unloaded_this_tick, test_splash_index_built_only_on_splash_ticks]

func test_combat_definitions(runner) -> bool:
	runner.check(Definitions.profile("usa_rifle_infantry") == {"max_hp": 180000, "armor": "human", "weapon": "rifle"}, "D1 infantry")
	runner.check(Definitions.profile("usa_tank") == {"max_hp": 480000, "armor": "tank", "weapon": "cannon"}, "D1 tank")
	runner.check(Definitions.profile("usa_builder") == {"max_hp": 250000, "armor": "builder_vehicle", "weapon": ""}, "D1 builder")
	runner.check(Definitions.profile("usa_collector") == {"max_hp": 300000, "armor": "helicopter", "weapon": ""}, "D1 collector")
	runner.check(Definitions.profile("usa_light_vehicle") == {"max_hp": 240000, "armor": "light_vehicle", "weapon": "scout_gun"}, "D1 legacy vehicle")
	var hp := {"usa_power_plant": 800000, "usa_supply_center": 2000000, "usa_factory": 2000000, "usa_barracks": 1000000}
	for kind in hp:
		runner.check(Definitions.profile(kind) == {"max_hp": hp[kind], "armor": "structure", "weapon": ""}, "D1 " + kind)
	runner.check(Definitions.profile("nothing").is_empty() and Definitions.weapon("nothing").is_empty(), "D1 unknown empty")
	runner.check(Definitions.weapon("rifle") == {"damage": 5000, "damage_type": "small_arms", "range": 4.0, "delay_ticks": 4, "clip_size": 3, "reload_ticks": 22, "primary_radius": 0.0, "secondary_radius": 0.0, "secondary_damage": 0, "affects": []}, "D1 rifle")
	runner.check(Definitions.weapon("cannon") == {"damage": 60000, "damage_type": "armor_piercing", "range": 6.0, "delay_ticks": 60, "clip_size": 0, "reload_ticks": 0, "primary_radius": 0.2, "secondary_radius": 0.0, "secondary_damage": 0, "affects": ["allies", "enemies", "neutrals"]}, "D1 cannon")
	var rows := {"human": [100, 10], "tank": [25, 100], "builder_vehicle": [25, 100], "light_vehicle": [50, 100], "structure": [50, 100], "helicopter": [50, 50]}
	for armor in rows:
		runner.check(Definitions.armor_percent(armor, "small_arms") == rows[armor][0] and Definitions.armor_percent(armor, "armor_piercing") == rows[armor][1], "D1 armor " + armor)
	runner.check(Definitions.armor_percent("x", "small_arms") == 0 and Definitions.armor_percent("human", "x") == 0, "D1 unknown armor is zero")
	var changed: Dictionary = Definitions.profile("usa_tank").duplicate()
	changed.max_hp = 1
	var weapon: Dictionary = Definitions.weapon("rifle").duplicate()
	weapon.damage = 1
	runner.check(Definitions.profile("usa_tank").max_hp == 480000 and Definitions.weapon("rifle").damage == 5000, "D1 fresh dictionaries")
	var infantry: Dictionary = Economy.unit("usa_rifle_infantry")
	runner.check(infantry == {"cost": 225, "ticks": 150, "speed": 0.8, "accel": 4.0, "brake": 4.0, "locomotor": "legs", "turn_cos": 0.9579895123154889, "turn_sin": 0.28680323271109026, "air": false, "producer": "usa_barracks"}, "D1 infantry economy")
	runner.check(Economy.unit("usa_tank") == {"cost": 900, "ticks": 300, "speed": 1.2, "accel": 40.0, "brake": 40.0, "locomotor": "treads", "turn_cos": 0.9945218953682733, "turn_sin": 0.10452846326765347, "air": false, "producer": "usa_factory"}, "D1 tank economy")
	runner.check(Economy.building("usa_barracks") == {"cost": 600, "ticks": 300, "power": 0, "footprint": Vector2i(2, 2), "prerequisite": "", "produces": "usa_rifle_infantry"}, "D1 barracks economy")
	runner.check(Economy.unit("usa_light_vehicle").cost == 700 and Economy.building("usa_factory").produces == "usa_light_vehicle", "D1 legacy vehicle unchanged")
	return true

func test_health_snapshot_isolation(runner) -> bool:
	var sim = Fixture.world()
	var rifle: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var builder: int = sim.spawn(1, Vector2(4.5, 2.5), "usa_builder")
	var unit: Dictionary = Fixture.object(sim, rifle)
	runner.check(unit.hp == 180000 and unit.max_hp == 180000, "H1 full infantry health")
	runner.check(unit.combat == {"mode": "guard", "target_id": null, "goal": null, "next_fire_tick": 0, "shots_left": 3, "repath_tick": 0, "retarget": false, "until": 0}, "H1 combat record")
	var worker: Dictionary = Fixture.object(sim, builder)
	runner.check(worker.hp == 250000 and worker.combat == null, "H1 unarmed has no combat")
	var tank: Dictionary = Fixture.object(sim, sim.spawn(2, Vector2(8.5, 2.5), "usa_tank"))
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
	runner.check(EconomyFixture.send(world, {"type": "build", "builder_id": 1, "building_kind": "usa_power_plant", "origin": [8, 8]}).ok, "H1 build accepted")
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
	runner.check(_hit("usa_rifle_infantry", Vector2(2.5, 2.5), "usa_builder", Vector2(6.5, 2.5)) == 1250, "R1 exact range hits")
	runner.check(_hit("usa_rifle_infantry", Vector2(2.5, 2.5), "usa_builder", Vector2(6.499, 2.5)) == 1250, "R1 inside hits")
	runner.check(_hit("usa_rifle_infantry", Vector2(2.5, 2.5), "usa_builder", Vector2(7.5, 2.5)) == 0, "R1 outside misses")
	var edge: float = 21.0 + Definitions.weapon("rifle").range - 0.1 + Definitions.radius("usa_rifle_infantry") + Definitions.radius("usa_power_plant")
	for at in [Vector2(edge, 21.0), Vector2(edge + 0.001, 21.0)]:
		var world = EconomyFixture.make_world()
		runner.check(EconomyFixture.send(world, {"type": "build", "builder_id": 1, "building_kind": "usa_power_plant", "origin": [20, 20]}).ok, "R1 foundation placed")
		world.spawn(2, at, "usa_rifle_infantry")
		world.step()
		var foundation: Dictionary = world.snapshot().buildings[0]
		var expect_hit: bool = at.x < edge + 0.0005
		runner.check((foundation.hp == 800000 - 2500) == expect_hit and (foundation.hp == 800000) != expect_hit, "R1 footprint nearest point " + str(at.x))
	var sim = Fixture.world()
	var shooter: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var friend: int = sim.spawn(1, Vector2(3.5, 2.5), "usa_builder")
	var air: int = sim.spawn(2, Vector2(4.5, 2.5), "usa_collector")
	var source: int = sim.add_supply_source(Vector2i(5, 5), 10)
	var enemy: int = sim.spawn(2, Vector2(2.5, 6.5), "usa_builder")
	runner.check(not Combat.valid_target(sim, 1, friend) and not Combat.valid_target(sim, 1, air), "R1 friend and collector excluded")
	runner.check(not Combat.valid_target(sim, 1, source) and not Combat.valid_target(sim, 1, 999), "R1 source and missing excluded")
	runner.check(Combat.valid_target(sim, 1, enemy) and not Combat.valid_target(sim, 2, enemy), "R1 enemy included")
	sim.step()
	runner.check(_shots(sim).size() == 1 and _shots(sim)[0].target_id == enemy and _shots(sim)[0].attacker_id == shooter, "R1 only legal target shot")
	runner.check(Combat.distance_squared(Vector2(4, 3), {"kind": "usa_power_plant", "origin": [8, 2]}) == 16.0, "R1 distance to footprint")
	return true

func _edge_max(shooter: String, target: String) -> float:
	var weapon: Dictionary = Definitions.weapon(Definitions.profile(shooter).weapon)
	return weapon.range - 0.1 + Definitions.radius(shooter) + Definitions.radius(target)

func test_ranger_fires_at_edge_max(runner) -> bool:
	var reach: float = _edge_max("usa_rifle_infantry", "usa_builder")
	runner.check(absf(reach * 25.0 - 122.0) <= 1.0, "E1 Ranger reach is the measured 122 units")
	runner.check(_hit("usa_rifle_infantry", Vector2(2.5, 2.5), "usa_builder", Vector2(2.5 + reach, 2.5)) == 1250, "E1 Ranger fires at the edge maximum")
	runner.check(_hit("usa_rifle_infantry", Vector2(2.5, 2.5), "usa_builder", Vector2(2.5 + reach + 0.01, 2.5)) == 0, "E1 Ranger misses 0.01 beyond")
	return true

func test_crusader_fires_at_edge_max(runner) -> bool:
	var reach: float = _edge_max("usa_tank", "usa_builder")
	runner.check(absf(reach * 25.0 - 183.0) <= 1.0, "E2 Crusader reach is the measured 183 units")
	runner.check(_hit("usa_tank", Vector2(2.5, 2.5), "usa_builder", Vector2(2.5 + reach, 2.5)) == 60000, "E2 Crusader fires at the edge maximum")
	runner.check(_hit("usa_tank", Vector2(2.5, 2.5), "usa_builder", Vector2(2.5 + reach + 0.01, 2.5)) == 0, "E2 Crusader misses 0.01 beyond")
	return true

func test_rifle_cycle_30(runner) -> bool:
	var sim = Fixture.world()
	sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	sim.spawn(2, Vector2(5.5, 2.5), "usa_builder")
	var ticks: Array[int] = []
	for tick in range(70):
		sim.step()
		for event in sim.snapshot().combat_events:
			if event.type == "shot": ticks.append(event.tick)
	runner.check(ticks == [0, 4, 8, 30, 34, 38, 60, 64, 68], "E3 rifle gaps are 4, 4, 22 repeated: " + str(ticks))
	return true

func test_firing_cell_uses_edge(runner) -> bool:
	var sim = Fixture.world()
	var ranger: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var tank: int = sim.spawn(2, Vector2(20.3, 2.5), "usa_builder")
	runner.check(Fixture.send(sim, {"type": "attack", "entity_ids": [ranger], "target_id": tank}).ok, "E4 attack accepted")
	for tick in range(900):
		sim.step()
		if Fixture.object(sim, tank).hp < 250000: break
	var unit: Dictionary = Fixture.object(sim, ranger)
	runner.check(Fixture.object(sim, tank).hp < 250000 and 20.3 - unit.position[0] > 4.5 and Combat.edge_gap(unit, Fixture.object(sim, tank)) <= 3.9 + 1e-6, "E4 chase stops on the first cell inside edge range: " + str(unit.position))
	return true

func test_building_edge_range(runner) -> bool:
	var world = EconomyFixture.make_world()
	runner.check(EconomyFixture.send(world, {"type": "build", "builder_id": 1, "building_kind": "usa_power_plant", "origin": [20, 20]}).ok, "E5 foundation placed")
	var reach: float = Definitions.weapon("rifle").range - 0.1 + Definitions.radius("usa_rifle_infantry") + Definitions.radius("usa_power_plant")
	runner.check(is_equal_approx(Definitions.radius("usa_power_plant"), sqrt(2.0)) and is_equal_approx(Definitions.radius("usa_factory"), 1.5 * sqrt(2.0)), "E5 building radius is half the footprint diagonal")
	world.spawn(2, Vector2(21.0 - reach, 21.0), "usa_rifle_infantry")
	world.step()
	runner.check(world.snapshot().buildings[0].hp == 800000 - 2500, "E5 Ranger hits a building at the edge maximum")
	return true

func test_damage_armor_matrix(runner) -> bool:
	var rifle := {"usa_rifle_infantry": 5000, "usa_tank": 1250, "usa_builder": 1250, "usa_light_vehicle": 2500}
	for kind in rifle:
		runner.check(_hit("usa_rifle_infantry", Vector2(2.5, 2.5), kind, Vector2(5.5, 2.5)) == rifle[kind], "A1 rifle vs " + kind)
	var cannon := {"usa_rifle_infantry": 6000, "usa_tank": 60000, "usa_builder": 60000, "usa_light_vehicle": 60000}
	for kind in cannon:
		runner.check(_hit("usa_tank", Vector2(2.5, 2.5), kind, Vector2(5.5, 2.5)) == cannon[kind], "A1 cannon vs " + kind)
	var sim = Fixture.world()
	sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var victim: int = sim.spawn(2, Vector2(5.5, 2.5), "usa_tank")
	sim.step()
	runner.check(Fixture.object(sim, victim).hp == 480000 - 1250, "A1 no whole-HP rounding")
	return true

func test_weapon_cooldown(runner) -> bool:
	var sim = Fixture.world()
	var rifle: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var victim: int = sim.spawn(2, Vector2(5.5, 2.5), "usa_builder")
	var fired: Array[int] = []
	for tick in range(39):
		sim.step()
		for event in sim.snapshot().combat_events:
			if event.type == "shot" and event.attacker_id == rifle:
				fired.append(event.tick)
		if tick == 8:
			runner.check(Fixture.object(sim, victim).hp == 246250, "W1 three armor-adjusted shots")
			sim.snapshot()
			sim.snapshot()
	runner.check(fired == [0, 4, 8, 30, 34, 38], "W1 burst and reload boundaries")
	var big = Fixture.world()
	var tank: int = big.spawn(1, Vector2(2.5, 2.5), "usa_tank")
	var target: int = big.spawn(2, Vector2(6.5, 2.5), "usa_light_vehicle")
	var cannon: Array[int] = []
	for tick in range(121):
		big.step()
		for event in big.snapshot().combat_events:
			if event.type == "shot" and event.attacker_id == tank: cannon.append(event.tick)
	runner.check(cannon == [0, 60, 120] and Fixture.object(big, target).hp == 60000, "W1 cannon cadence and damage")
	return true

func test_guard_priority(runner) -> bool:
	var sim = Fixture.world()
	var shooter: int = sim.spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry")
	var high: int = sim.spawn(2, Vector2(12.5, 10.5), "usa_builder")
	var low: int = sim.spawn(2, Vector2(8.5, 10.5), "usa_builder")
	sim.spawn(1, Vector2(10.5, 9.5), "usa_builder")
	sim.step()
	runner.check(_shots(sim)[0].target_id == min(high, low), "G1 equal distance ties by ID")
	var retained: int = Fixture.object(sim, shooter).combat.target_id
	var nearer: int = sim.spawn(2, Vector2(10.5, 11.5), "usa_builder")
	sim.step()
	runner.check(Fixture.object(sim, shooter).combat.target_id == retained and retained != nearer, "G1 retained valid target stays")
	var idle = Fixture.world()
	var walker: int = idle.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	idle.spawn(2, Vector2(12.5, 2.5), "usa_builder")
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
	var rifle: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var tank: int = sim.spawn(1, Vector2(2.5, 4.5), "usa_tank")
	var worker: int = sim.spawn(1, Vector2(2.5, 6.5), "usa_builder")
	var enemy: int = sim.spawn(2, Vector2(20.5, 2.5), "usa_builder")
	var enemy_unit: int = sim.spawn(2, Vector2(20.5, 4.5), "usa_rifle_infantry")
	var friend: int = sim.spawn(1, Vector2(4.5, 6.5), "usa_builder")
	var air: int = sim.spawn(2, Vector2(20.5, 6.5), "usa_collector")
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
		["unarmed only", {"type": "attack", "entity_ids": [worker], "target_id": enemy}],
		["friend target", {"type": "attack", "entity_ids": [rifle], "target_id": friend}],
		["source target", {"type": "attack", "entity_ids": [rifle], "target_id": source}],
		["collector target", {"type": "attack", "entity_ids": [rifle], "target_id": air}],
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

func _group_world() -> Dictionary:
	var sim = Fixture.world()
	return {"sim": sim, "a": sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry"), "b": sim.spawn(1, Vector2(2.5, 4.5), "usa_rifle_infantry"),
		"worker": sim.spawn(1, Vector2(2.5, 6.5), "usa_builder"), "enemy": sim.spawn(2, Vector2(20.5, 2.5), "usa_builder"),
		"foe": sim.spawn(2, Vector2(20.5, 4.5), "usa_rifle_infantry")}

func _step(sim: RefCounted, ticks: int) -> void:
	for i in ticks: sim.step()

func test_missing_id_skipped(runner) -> bool:
	for type in ["move", "stop", "attack", "attack_move"]:
		var w: Dictionary = _group_world()
		var sim = w.sim
		var payload: Dictionary = {"type": type, "entity_ids": [w.a, 999, w.b]}
		if type == "attack": payload.target_id = w.enemy
		elif type != "stop": payload.target = [9.5, 9.5]
		runner.check(Fixture.send(sim, payload).ok, "G1 " + type + " with a missing id accepted")
		_step(sim, 2)
		var applied: bool = _mode(sim, w.a).mode != "guard" or type == "stop"
		if type == "move": applied = Fixture.object(sim, w.a).destination != null and Fixture.object(sim, w.b).destination != null
		runner.check(applied and (type == "move" or _mode(sim, w.b).mode == _mode(sim, w.a).mode), "G1 " + type + " applies to the remaining ids")
	var econ = EconomyFixture.make_world()
	var collector: int = econ.spawn(1, Vector2(6.5, 4.5), "usa_collector")
	var source: int = econ.add_supply_source(Vector2i(10, 10), 5)
	var gathered: Dictionary = Fixture.send(econ, {"type": "gather", "entity_ids": [collector, 999], "source_id": source})
	runner.check(gathered.ok, "G1 gather with a missing id accepted " + gathered.error)
	return true

func test_due_tick_death_skips_member(runner) -> bool:
	var w: Dictionary = _group_world()
	var sim = w.sim
	var tick: int = sim.snapshot().tick + 4
	var seq: int = 1
	runner.check(sim.issue_command({"tick": tick, "player": 1, "sequence": seq, "type": "attack_move", "entity_ids": [w.a, w.b], "target": [9.5, 9.5]}).ok, "G2 future order accepted")
	_step(sim, 2)
	sim.remove_object(w.a)
	_step(sim, 3)
	runner.check(_mode(sim, w.b).mode == "attack_move", "G2 live member gets the order after the other died")
	var w2: Dictionary = _group_world()
	var sim2 = w2.sim
	runner.check(sim2.issue_command({"tick": sim2.snapshot().tick + 2, "player": 1, "sequence": 1, "type": "attack_move", "entity_ids": [w2.a], "target": [9.5, 9.5]}).ok, "G2 single-unit order accepted")
	sim2.remove_object(w2.a)
	var results: Array = []
	for i in 3:
		sim2.step()
		results.append_array(sim2.snapshot().command_results)
	runner.check(results.size() == 1 and not results[0].ok and results[0].error == "No units left", "G2 all members gone gives No units left " + str(results))
	return true

func test_foreign_id_rejects(runner) -> bool:
	var w: Dictionary = _group_world()
	_rejected(runner, w.sim, {"type": "move", "entity_ids": [w.a, w.foe], "target": [9.5, 9.5]}, "G3 foreign id move")
	var result: Dictionary = Fixture.send(w.sim, {"type": "stop", "entity_ids": [w.a, w.foe]})
	runner.check(not result.ok and result.error == "Missing entity or wrong owner", "G3 foreign id error text")
	return true

func test_attack_move_mixed_selection(runner) -> bool:
	var w: Dictionary = _group_world()
	var sim = w.sim
	runner.check(Fixture.send(sim, {"type": "attack_move", "entity_ids": [w.a, w.worker], "target": [9.5, 9.5]}).ok, "G4 mixed attack_move accepted")
	_step(sim, 2)
	var builder: Dictionary = Fixture.object(sim, w.worker)
	runner.check(builder.combat == null and builder.destination != null and _mode(sim, w.a).mode == "attack_move", "G4 builder moves plainly, rifle attack-moves")
	var w2: Dictionary = _group_world()
	runner.check(Fixture.send(w2.sim, {"type": "attack_move", "entity_ids": [w2.worker], "target": [9.5, 9.5]}).ok, "G4 builder alone accepted")
	_step(w2.sim, 2)
	runner.check(Fixture.object(w2.sim, w2.worker).destination != null, "G4 builder alone moves")
	var w3: Dictionary = _group_world()
	runner.check(Fixture.send(w3.sim, {"type": "attack", "entity_ids": [w3.a, w3.worker], "target_id": w3.enemy}).ok, "G4 attack with builder accepted")
	_step(w3.sim, 2)
	runner.check(_mode(w3.sim, w3.a).mode == "attack" and Fixture.object(w3.sim, w3.worker).combat == null, "G4 only the rifle attacks")
	return true

func _mode(sim: RefCounted, id: int) -> Dictionary:
	return Fixture.object(sim, id).combat

func test_combat_intent_order(runner) -> bool:
	var sim = Fixture.world()
	var rifle: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var enemy: int = sim.spawn(2, Vector2(20.5, 2.5), "usa_builder")
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
	var shooter: int = other.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var victim: int = other.spawn(2, Vector2(3.5, 2.5), "usa_builder")
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
	var rifle: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var enemy: int = sim.spawn(2, Vector2(5.5, 2.5), "usa_builder")
	for tick in range(9): sim.step()
	runner.check(_mode(sim, rifle).next_fire_tick == 30 and _mode(sim, rifle).shots_left == 3, "L1 reload scheduled after clip")
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
	runner.check(_mode(sim, rifle).next_fire_tick == 30 and _mode(sim, rifle).shots_left == 3, "L1 intent changes keep timer and ammo")
	var partial = Fixture.world()
	var shooter: int = partial.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var first: int = partial.spawn(2, Vector2(5.5, 2.5), "usa_builder")
	var second: int = partial.spawn(2, Vector2(2.5, 5.5), "usa_builder")
	Fixture.send(partial, {"type": "attack", "entity_ids": [shooter], "target_id": first})
	partial.step()
	Fixture.send(partial, {"type": "attack", "entity_ids": [shooter], "target_id": second})
	partial.step()
	runner.check(_mode(partial, shooter).shots_left == 2 and _mode(partial, shooter).next_fire_tick == 4 and _mode(partial, shooter).target_id == second, "L1 retarget keeps partial clip")
	partial.step()
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
	var guard: int = sim.spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry")
	sim.step()
	runner.check(Fixture.object(sim, guard).combat.repath_tick == Combat.REPATH_TICKS - 1, "T1 idle scan schedules the unit's next phase tick")
	sim.spawn(2, Vector2(12.5, 10.5), "usa_builder")
	runner.check(_first_shot_tick(sim, 1, 30, runner, "T1") == Combat.REPATH_TICKS - 1, "T1 throttled guard first fires at its phase tick")
	var fresh = Fixture.world()
	var other: int = fresh.spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry")
	fresh.step()
	fresh.spawn(2, Vector2(12.5, 10.5), "usa_builder")
	Fixture.send(fresh, {"type": "stop", "entity_ids": [other]})
	runner.check(_first_shot_tick(fresh, 1, 30, runner, "T2") == Combat.REPATH_TICKS - 1, "T2 stop delays the next scan to the unit's phase tick like Zero Hour idle")
	return true

func _events(sim: RefCounted) -> Array:
	return sim.snapshot().combat_events

func test_mutual_lethal_fire(runner) -> bool:
	for owners in [[1, 2], [2, 1]]:
		var sim = Fixture.world()
		var a: int = sim.spawn(owners[0], Vector2(10.5, 10.5), "usa_tank")
		var b: int = sim.spawn(owners[1], Vector2(14.5, 10.5), "usa_tank")
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
	for at in [Vector2(10.5, 10.5), Vector2(10.5, 11.5), Vector2(10.5, 9.5)]: group.spawn(1, at, "usa_tank")
	var victim: int = group.spawn(2, Vector2(14.5, 10.5), "usa_tank")
	var deaths: Array[int] = []
	for tick in range(240):
		group.step()
		for event in _events(group):
			if event.type == "death" and event.object_id == victim: deaths.append(event.tick)
	runner.check(deaths == [120], "L1 three volleys kill the target exactly once at tick 120")
	return true

func test_target_removed_cleanup(runner) -> bool:
	var sim = Fixture.world()
	var chaser: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var target: int = sim.spawn(2, Vector2(12.5, 2.5), "usa_builder")
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
	var scout: int = mover.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var enemy: int = mover.spawn(2, Vector2(9.5, 4.5), "usa_builder")
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
	var killer: int = duel.spawn(1, Vector2(10.5, 10.5), "usa_tank")
	var victim: int = duel.spawn(2, Vector2(14.5, 10.5), "usa_builder")
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
	var result: Dictionary = EconomyFixture.send(sim, {"type": "build", "builder_id": 1, "building_kind": "usa_power_plant", "origin": [8, 4]})
	runner.check(result.ok, "D1 build accepted")
	var site: int = sim.snapshot().next_entity_id
	var guard: int = 0
	while guard < 600 and EconomyFixture.object(sim, site).get("work", 0) == 0:
		sim.step()
		guard += 1
	var builder: Dictionary = EconomyFixture.object(sim, 1)
	runner.check(EconomyFixture.object(sim, site).get("work", 0) > 0 and builder.position == [7.5, 4.5], "D1 builder working")
	for offset in [Vector2(-3, 0), Vector2(-3, 1), Vector2(-3, -1), Vector2(-4, 0), Vector2(-4, 1)]:
		sim.spawn(2, Vector2(builder.position[0], builder.position[1]) + offset, "usa_tank")
	var before: int = EconomyFixture.object(sim, site).work
	sim.step()
	var foundation: Dictionary = EconomyFixture.object(sim, site)
	runner.check(EconomyFixture.object(sim, 1).is_empty(), "D1 builder killed in one volley")
	runner.check(foundation.work == before + 1000, "D1 the death tick still gets its work step")
	runner.check(foundation.builder_id == null and not foundation.completed, "D1 foundation unbound")
	EconomyFixture.steps(sim, 30)
	runner.check(EconomyFixture.object(sim, site).work == before + 1000, "D1 no later work")
	var armed = Fixture.world()
	var doomed: int = armed.spawn(1, Vector2(10.5, 10.5), "usa_tank")
	for at in [Vector2(14.5, 10.5), Vector2(14.5, 11.5), Vector2(14.5, 9.5), Vector2(15.5, 10.5), Vector2(15.5, 11.5)]: armed.spawn(2, at, "usa_tank")
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
	EconomyFixture.build(runner, sim, "usa_power_plant", Vector2i(8, 12))
	EconomyFixture.build(runner, sim, "usa_supply_center", Vector2i(8, 5))
	var factory: int = EconomyFixture.build(runner, sim, "usa_factory", Vector2i(12, 18))
	runner.check(factory != -1, "P1 factory built")
	var attackers: Array = []
	for at in [Vector2(20.5, 18.5), Vector2(20.5, 19.5), Vector2(20.5, 20.5), Vector2(19.5, 18.5), Vector2(19.5, 19.5)]:
		attackers.append(sim.spawn(2, at, "usa_tank"))
	for i in range(3):
		runner.check(EconomyFixture.send(sim, {"type": "produce", "building_id": factory, "unit_kind": "usa_tank"}).ok, "P1 tank queued")
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
	var tanks: int = sim.snapshot().entities.filter(func(entity: Dictionary) -> bool: return entity.owner == 1 and entity.kind == "usa_tank").size()
	runner.check(tanks == 1, "P1 the tank finished before the death tick survives")
	runner.check(EconomyFixture.object(sim, factory).is_empty(), "P1 producer removed")
	EconomyFixture.steps(sim, 60)
	runner.check(sim.snapshot().players[0].credits == after_death, "P1 no second refund")
	return true

func test_same_tick_attack_and_cancel(runner) -> bool:
	var sim = EconomyFixture.make_world(10000)
	sim.add_player(2, 10000)
	var builder: int = sim.spawn(2, Vector2(20.5, 20.5), "usa_builder")
	var site: int = sim.snapshot().next_entity_id
	EconomyFixture.send(sim, {"player": 2, "type": "build", "builder_id": builder, "building_kind": "usa_power_plant", "origin": [24, 20]})
	sim.step()
	runner.check(not EconomyFixture.object(sim, site).is_empty(), "C1 foundation exists")
	var attacker: int = sim.spawn(1, Vector2(10.5, 20.5), "usa_rifle_infantry")
	EconomyFixture.send(sim, {"type": "attack", "entity_ids": [attacker], "target_id": site})
	EconomyFixture.send(sim, {"player": 2, "type": "cancel_build", "building_id": site})
	sim.step()
	sim.step()
	var unit: Dictionary = EconomyFixture.object(sim, attacker)
	runner.check(EconomyFixture.object(sim, site).is_empty() and unit.combat.target_id == null and unit.combat.mode == "guard", "C1 cancelled target never becomes an attack target")
	return true

func test_removed_target_rescans(runner) -> bool:
	var sim = Fixture.world()
	var chaser: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var target: int = sim.spawn(2, Vector2(12.5, 2.5), "usa_builder")
	sim.spawn(2, Vector2(2.5, 5.0), "usa_builder")
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
	var infantry: int = skirmish.spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry")
	var tank: int = skirmish.spawn(1, Vector2(12.5, 10.5), "usa_tank")
	var ai_infantry: int = skirmish.spawn(2, Vector2(20.5, 10.5), "usa_rifle_infantry")
	var ai_tank: int = skirmish.spawn(2, Vector2(22.5, 10.5), "usa_tank")
	runner.check(is_equal_approx(Combat.scan_radius(skirmish, skirmish._entities[infantry]), 8.8), "C3 human infantry radius")
	runner.check(is_equal_approx(Combat.scan_radius(skirmish, skirmish._entities[tank]), 13.2), "C3 human tank radius")
	runner.check(is_equal_approx(Combat.scan_radius(skirmish, skirmish._entities[ai_infantry]), 5.332), "C3 ai infantry radius")
	runner.check(is_equal_approx(Combat.scan_radius(skirmish, skirmish._entities[ai_tank]), 7.998), "C3 ai tank radius")
	var orphan: int = sim.spawn(9, Vector2(5.5, 5.5), "usa_rifle_infantry")
	runner.check(is_equal_approx(Combat.scan_radius(sim, sim._entities[orphan]), 8.8), "C4 owner without player record is human")
	var builder: int = skirmish.spawn(1, Vector2(14.5, 10.5), "usa_builder")
	runner.check(Combat.scan_radius(skirmish, skirmish._entities[builder]) == 0.0, "C5 unarmed unit has no scan radius")
	return true

func _scan_shot_within(sim: RefCounted, limit: int) -> bool:
	for tick in range(limit):
		sim.step()
		if not _shots(sim).is_empty(): return true
	return false

func _ai_world() -> RefCounted:
	var sim = Fixture.world()
	sim.add_player(1, 0, "ai")
	return sim

func test_scan_acquires_beyond_weapon_range(runner) -> bool:
	var sim = _ai_world()
	var guard: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var builder: int = sim.spawn(2, Vector2(7.5, 2.5), "usa_builder")
	sim.step()
	var unit: Dictionary = Fixture.object(sim, guard)
	runner.check(unit.combat.target_id == builder and unit.combat.mode == "guard", "X1 ai guard acquires an enemy 5 cells away and stays in guard")
	runner.check(unit.status != "idle", "X1 guard approaches the out-of-range target")
	runner.check(_scan_shot_within(sim, 300), "X1 chasing guard later fires")
	var far = _ai_world()
	var idle: int = far.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	far.spawn(2, Vector2(8.5, 2.5), "usa_builder")
	far.step()
	runner.check(Fixture.object(far, idle).combat.target_id == null, "X2 enemy 6 cells away is outside the ai 5.332 radius")
	return true

func test_scan_radius_by_controller(runner) -> bool:
	var near = Fixture.world()
	near.add_player(2, 0, "ai")
	var scanner: int = near.spawn(2, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var prey: int = near.spawn(1, Vector2(7.8, 2.5), "usa_builder")
	near.step()
	runner.check(Fixture.object(near, scanner).combat.target_id == prey, "R1 ai infantry acquires at 5.3 cells")
	var far = Fixture.world()
	far.add_player(2, 0, "ai")
	var blind: int = far.spawn(2, Vector2(2.5, 2.5), "usa_rifle_infantry")
	far.spawn(1, Vector2(7.9, 2.5), "usa_builder")
	far.step()
	runner.check(Fixture.object(far, blind).combat.target_id == null, "R1 ai infantry ignores an enemy at 5.4 cells")
	return true

func test_scan_radius_boundary(runner) -> bool:
	for case in [[7.82, true], [7.84, false]]:
		var sim = _ai_world()
		var guard: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
		sim.spawn(2, Vector2(case[0], 2.5), "usa_builder")
		sim.step()
		runner.check((Fixture.object(sim, guard).combat.target_id != null) == case[1], "R2 enemy at x=" + str(case[0]) + " (ai radius 5.332): acquired=" + str(case[1]))
	return true

func _chase(sim, id: int) -> Variant:
	for entry: Dictionary in sim.snapshot().get("chases", []):
		if entry.id == id: return entry
	return null

func test_removed_chaser_clears_chase(runner) -> bool:
	var sim = _ai_world()
	var guard: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	sim.spawn(2, Vector2(7.5, 2.5), "usa_builder")
	sim.step()
	runner.check(_chase(sim, guard) != null, "R3 chase started")
	sim.remove_object(guard)
	runner.check(_chase(sim, guard) == null, "R3 removing the chaser clears its chase")
	return true

func test_scan_keeps_target_leaving_radius(runner) -> bool:
	var sim = _ai_world()
	var guard: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var builder: int = sim.spawn(2, Vector2(7.5, 2.5), "usa_builder")
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
	var sim = _ai_world()
	var walker: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var goal := [2.5, 20.5]
	Fixture.send(sim, {"type": "attack_move", "entity_ids": [walker], "target": goal})
	var prey: int = sim.spawn(2, Vector2(7.5, 8.5), "usa_builder")
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
	var sim = _ai_world()
	var guard: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var builder: int = sim.spawn(2, Vector2(7.5, 2.5), "usa_builder")
	var other: int = sim.spawn(2, Vector2(2.5, 7.5), "usa_builder")
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
	var chase: Variant = _chase(marching[0], marching[1])
	var resume: Variant = chase.resume if chase != null else null
	runner.check(resume == null or Vector2(resume[0], resume[1]).distance_to(Vector2(2.5, 20.5)) < 1.5, "O4 any chase now resumes to the new attack_move goal, not the old one")
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
	var placed: Dictionary = EconomyFixture.send(sim, {"type": "build", "builder_id": 1, "building_kind": "usa_power_plant", "origin": [14, 4]})
	runner.check(placed.ok, "B1 foundation placement accepted")
	EconomyFixture.steps(sim, 2)
	sim.remove_object(1)
	var scanner: int = sim.spawn(2, Vector2(11.0, 4.5), "usa_rifle_infantry")
	sim.step()
	var foundation: Array = sim.snapshot().buildings
	runner.check(not foundation.is_empty() and Fixture.object(sim, scanner).combat.target_id == foundation[0].id, "B1 an enemy foundation 3 cells away is acquired")
	return true

func test_human_guard_in_range_only(runner) -> bool:
	var near = Fixture.world()
	var guard: int = near.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var builder: int = near.spawn(2, Vector2(6.5, 2.5), "usa_builder")
	near.step()
	runner.check(Fixture.object(near, guard).combat.target_id == builder, "G1 human guard acquires an enemy at exactly weapon range")
	runner.check(_scan_shot_within(near, 20), "G1 and fires")
	runner.check(Fixture.object(near, guard).position == [2.5, 2.5], "G1 the shot needs no movement")
	var far = Fixture.world()
	var idle: int = far.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	far.spawn(2, Vector2(7.5, 2.5), "usa_builder")
	for tick in range(40): far.step()
	var unit: Dictionary = Fixture.object(far, idle)
	runner.check(unit.combat.target_id == null and unit.position == [2.5, 2.5] and unit.destination == null, "G2 human guard ignores an enemy 5 cells away and never approaches")
	return true

func test_human_guard_holds_against_kiting(runner) -> bool:
	var sim = Fixture.world()
	var guard: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var builder: int = sim.spawn(2, Vector2(6.0, 2.5), "usa_builder")
	sim.step()
	runner.check(Fixture.object(sim, guard).combat.target_id == builder, "G3 target at 3.5 cells acquired")
	sim._entities[builder].position = [7.5, 2.5]
	sim.step()
	var unit: Dictionary = Fixture.object(sim, guard)
	runner.check(unit.combat.target_id == null and unit.position == [2.5, 2.5], "G3 target moved to 5 cells is dropped, the unit does not follow")
	sim._entities[builder].position = [6.0, 2.5]
	for tick in range(8): sim.step()
	runner.check(Fixture.object(sim, guard).combat.target_id == builder, "G3 target back at 3.5 cells is re-acquired by the next cadence tick")
	return true

func test_ai_guard_unchanged(runner) -> bool:
	var sim = _ai_world()
	var guard: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var builder: int = sim.spawn(2, Vector2(7.7, 2.5), "usa_builder")
	sim.step()
	var unit: Dictionary = Fixture.object(sim, guard)
	runner.check(unit.combat.target_id == builder and unit.status != "idle", "G4 ai guard acquires an enemy 5.2 cells away and approaches")
	return true

func _died(sim: RefCounted, id: int) -> bool:
	for event in sim.snapshot().combat_events:
		if event.type == "death" and event.object_id == id: return true
	return false

func _kill_first(sim: RefCounted, id: int) -> bool:
	for tick in range(200):
		sim.step()
		if _died(sim, id): return true
	return false

func _attack_move_world(first_x: float) -> Array:
	var sim = Fixture.world()
	var walker: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var first: int = sim.spawn(2, Vector2(first_x, 2.5), "usa_builder")
	sim._entities[first].hp = 1
	Fixture.send(sim, {"type": "attack_move", "entity_ids": [walker], "target": [2.5, 20.5]})
	return [sim, walker, first]

func test_human_attack_move_marches_in_range(runner) -> bool:
	var far = Fixture.world()
	var walker: int = far.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var off: int = far.spawn(2, Vector2(8.5, 10.5), "usa_builder")
	Fixture.send(far, {"type": "attack_move", "entity_ids": [walker], "target": [2.5, 20.5]})
	var acquired: bool = false
	for tick in range(1500):
		far.step()
		acquired = acquired or Fixture.object(far, walker).combat.target_id == off
	var end: Dictionary = Fixture.object(far, walker)
	runner.check(not acquired, "A1 human attack-move never acquires an enemy 6 cells off the route")
	runner.check(Vector2(end.position[0], end.position[1]).distance_to(Vector2(2.5, 20.5)) < 1.0, "A1 and arrives")
	var near = Fixture.world()
	var marcher: int = near.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var close: int = near.spawn(2, Vector2(6.0, 10.5), "usa_builder")
	Fixture.send(near, {"type": "attack_move", "entity_ids": [marcher], "target": [2.5, 20.5]})
	var halted: bool = false
	for tick in range(400):
		near.step()
		var unit: Dictionary = Fixture.object(near, marcher)
		if unit.combat.target_id == close and unit.status == "idle": halted = true
		if halted and not _shots(near).is_empty(): break
	runner.check(halted and not _shots(near).is_empty(), "A2 an enemy 3.5 cells off the route halts the march and is fired on")
	return true

func test_human_attack_move_post_kill_rescan(runner) -> bool:
	for case in [[8.5, true], [9.0, false]]:
		var world: Array = _attack_move_world(5.5)
		var sim = world[0]
		runner.check(_kill_first(sim, world[2]), "A3 first enemy killed")
		var unit: Dictionary = Fixture.object(sim, world[1])
		var second: int = sim.spawn(2, Vector2(unit.position[0] + case[0], unit.position[1]), "usa_builder")
		sim.step()
		unit = Fixture.object(sim, world[1])
		if case[1]:
			runner.check(unit.combat.target_id == second and unit.status != "idle", "A3 enemy " + str(case[0]) + " cells away is taken in the next plan and approached")
			var fired: bool = false
			for tick in range(300):
				sim.step()
				fired = fired or _shots(sim).any(func(e: Dictionary) -> bool: return e.target_id == second)
				if fired: break
			runner.check(fired, "A3 and fired on")
		else:
			runner.check(unit.combat.target_id == null and unit.combat.goal == [2.5, 20.5] and unit.destination != null, "A3 enemy " + str(case[0]) + " cells away is ignored and the march resumes")
	return true

func test_human_attack_move_follows_retreat(runner) -> bool:
	var sim = Fixture.world()
	var walker: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var prey: int = sim.spawn(2, Vector2(5.5, 2.5), "usa_builder")
	Fixture.send(sim, {"type": "attack_move", "entity_ids": [walker], "target": [2.5, 20.5]})
	var dropped: bool = false
	var started: bool = false
	for tick in range(120):
		sim.step()
		started = started or not _shots(sim).is_empty()
		if not started: continue
		var unit: Dictionary = Fixture.object(sim, walker)
		var gap: float = Vector2(unit.position[0], unit.position[1]).distance_to(Vector2(sim._entities[prey].position[0], sim._entities[prey].position[1]))
		if tick % 8 == 0 and gap + 1.0 < 8.5: sim._entities[prey].position[0] += 1.0
		dropped = dropped or unit.combat.target_id != prey
	var end: Dictionary = Fixture.object(sim, walker)
	runner.check(started and not dropped, "A4 attack-move keeps following a target that retreats inside the scan radius")
	runner.check(end.combat.goal == [2.5, 20.5] and end.combat.mode == "attack_move", "A4 the combat goal is unchanged")
	return true

func test_rescan_same_tick_orders(runner) -> bool:
	for order in ["move", "stop", "attack", "attack_move"]:
		var world: Array = _attack_move_world(5.5)
		var sim = world[0]
		var walker: int = world[1]
		var decoy: int = sim.spawn(2, Vector2(2.5, 2.5 + 5.2), "usa_builder")
		runner.check(_kill_first(sim, world[2]) and Fixture.object(sim, walker).combat.retarget, "A5 " + order + ": retarget set by the kill")
		var payload := {"type": order, "entity_ids": [walker]}
		if order == "move" or order == "attack_move": payload.target = [2.5, 20.5]
		if order == "attack": payload.target_id = decoy
		Fixture.send(sim, payload)
		sim.step()
		var unit: Dictionary = Fixture.object(sim, walker)
		runner.check(not unit.combat.retarget, "A5 " + order + " replaces the pending retarget")
		runner.check(unit.combat.target_id == (decoy if order == "attack" else null), "A5 " + order + " leaves no scanned target")
	return true

func test_human_attack_move_drops_target_out_of_range(runner) -> bool:
	for case in [[9.5, false], [6.0, true]]:
		var sim = Fixture.world()
		var walker: int = sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
		var prey: int = sim.spawn(2, Vector2(5.5, 2.5), "usa_builder")
		var other: int = sim.spawn(2, Vector2(2.5, 8.5), "usa_builder")
		Fixture.send(sim, {"type": "attack_move", "entity_ids": [walker], "target": [2.5, 20.5]})
		runner.check(_scan_shot_within(sim, 40) and Fixture.object(sim, walker).combat.target_id == prey, "A6 the unit fires on the near enemy")
		sim._entities[prey].position = [2.5 + case[0], 2.5]
		sim.step()
		var unit: Dictionary = Fixture.object(sim, walker)
		if case[1]:
			runner.check(unit.combat.target_id == prey, "A6 a target 6 cells away, inside the scan radius, is re-chased after the drop")
		else:
			runner.check(unit.combat.target_id == other or unit.combat.target_id == null, "A6 a target beyond the scan radius is not re-taken")
			runner.check(unit.combat.target_id != prey and not unit.combat.retarget, "A6 the drop rescans in the same plan and clears the flag")
	return true

func test_human_attack_move_first_approach_has_no_leash(runner) -> bool:
	var world: Array = _attack_move_world(5.5)
	var sim = world[0]
	runner.check(_kill_first(sim, world[2]), "A8 first enemy killed")
	var unit: Dictionary = Fixture.object(sim, world[1])
	var second: int = sim.spawn(2, Vector2(unit.position[0] + 8.0, unit.position[1]), "usa_builder")
	sim.step()
	unit = Fixture.object(sim, world[1])
	runner.check(unit.combat.target_id == second and unit.status != "idle", "A8 the unit approaches the enemy beyond weapon range")
	sim._entities[second].position = [unit.position[0] + 20.0, unit.position[1]]
	sim.step()
	runner.check(Fixture.object(sim, world[1]).combat.target_id == second, "A8 the first approach keeps a target that left the scan radius")
	return true

func test_retarget_only_for_attack_move(runner) -> bool:
	var guard = Fixture.world()
	var shooter: int = guard.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	var first: int = guard.spawn(2, Vector2(5.5, 2.5), "usa_builder")
	guard._entities[first].hp = 1
	runner.check(_kill_first(guard, first), "A7 guard kills its target")
	guard.spawn(2, Vector2(8.5, 2.5), "usa_builder")
	for tick in range(16): guard.step()
	var unit: Dictionary = Fixture.object(guard, shooter)
	runner.check(not unit.combat.retarget and unit.combat.target_id == null and unit.position == [2.5, 2.5], "A7 a human guard never rescans wide or moves after a kill")
	var world: Array = _attack_move_world(5.5)
	runner.check(_kill_first(world[0], world[2]), "A7 attack-move kills its target")
	world[0].step()
	runner.check(not Fixture.object(world[0], world[1]).combat.retarget, "A7 retarget is cleared once served")
	return true

func _ret_world() -> Array:
	var sim = Fixture.world()
	sim.add_player(2, 0, "ai")
	var victim: int = sim.spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry")
	var attacker: int = sim.spawn(2, Vector2(15.5, 10.5), "usa_tank")
	return [sim, victim, attacker]

func _shot(attacker: int, victim: int) -> Array[Dictionary]:
	return [{"attacker_id": attacker, "target_id": victim}] as Array[Dictionary]

func _mode_of(sim: RefCounted, id: int) -> String:
	return sim._entities[id].combat.mode

func test_retaliate_trigger_distance(runner) -> bool:
	for case in [[8.0, true], [8.01, false]]:
		var world: Array = _ret_world()
		var sim = world[0]
		var far: int = sim.spawn(2, Vector2(10.5 + case[0], 10.5), "usa_tank")
		Combat._retaliate_trigger(sim, _shot(far, world[1]))
		runner.check((_mode_of(sim, world[1]) == "retaliate") == case[1], "RT1 attacker at %s cells" % case[0])
	var ai_victim: Array = _ret_world()
	ai_victim[0]._players[1] = {"id": 1, "credits": 0, "controller": "ai"}
	Combat._retaliate_trigger(ai_victim[0], _shot(ai_victim[2], ai_victim[1]))
	runner.check(_mode_of(ai_victim[0], ai_victim[1]) == "guard", "RT1 ai-owned victim never triggers")
	var kill: Array = _ret_world()
	var neighbour: int = kill[0].spawn(1, Vector2(12.5, 10.5), "usa_rifle_infantry")
	kill[0]._entities[kill[1]].hp = 0
	Combat._retaliate_trigger(kill[0], _shot(kill[2], kill[1]))
	runner.check(_mode_of(kill[0], neighbour) == "retaliate" and _mode_of(kill[0], kill[1]) == "guard", "RT1 killing hit triggers the neighbour, not the dead victim")
	runner.check(kill[0].retaliations() == 1 and kill[0]._entities[neighbour].combat.target_id == kill[2], "RT1 counter and target")
	return true

func test_retaliate_joiners(runner) -> bool:
	var world: Array = _ret_world()
	var sim = world[0]
	var near: int = sim.spawn(1, Vector2(5.75, 10.5), "usa_rifle_infantry")
	var out: int = sim.spawn(1, Vector2(10.5, 5.6), "usa_rifle_infantry")
	var mover: int = sim.spawn(1, Vector2(9.5, 10.5), "usa_rifle_infantry")
	var attacking: int = sim.spawn(1, Vector2(9.5, 11.5), "usa_rifle_infantry")
	var builder: int = sim.spawn(1, Vector2(9.5, 9.5), "usa_builder")
	sim._entities[mover].status = "moving"
	sim._entities[attacking].combat.mode = "attack"
	Combat._retaliate_trigger(sim, _shot(world[2], world[1]))
	runner.check(_mode_of(sim, world[1]) == "retaliate" and _mode_of(sim, near) == "retaliate", "RJ1 victim and unit at 4.75 join")
	runner.check(_mode_of(sim, out) == "guard", "RJ1 unit at 4.9 does not")
	runner.check(_mode_of(sim, mover) == "guard" and _mode_of(sim, attacking) == "attack" and sim._entities[builder].combat == null, "RJ1 moving, attacking and unarmed do not join")
	runner.check(sim._entities[near].combat.goal == sim._entities[near].position and sim._entities[near].combat.until == sim.tick() + 300, "RJ1 home and leash tick")
	var shop = Fixture.world()
	shop.add_player(2, 0, "ai")
	shop._buildings[900] = {"id": 900, "owner": 1, "kind": "usa_barracks", "origin": [10, 10], "hp": 1000000, "max_hp": 1000000, "completed": true, "queue": []}
	var inside: int = shop.spawn(1, Vector2(17.0, 11.0), "usa_rifle_infantry")
	var outside: int = shop.spawn(1, Vector2(11.0, 17.4), "usa_rifle_infantry")
	var raider: int = shop.spawn(2, Vector2(15.0, 11.0), "usa_rifle_infantry")
	Combat._retaliate_trigger(shop, _shot(raider, 900))
	runner.check(_mode_of(shop, inside) == "retaliate" and _mode_of(shop, outside) == "guard", "RJ2 building radius 4.8 + half diagonal from the centre")
	return true

func _trigger_at(sim: RefCounted, victim: int, attacker: int) -> void:
	Combat._retaliate_trigger(sim, _shot(attacker, victim))

func test_retaliate_leash_and_return(runner) -> bool:
	var sim = Fixture.world()
	sim.add_player(2, 0, "ai")
	var rifle: int = sim.spawn(1, Vector2(5.5, 5.5), "usa_rifle_infantry")
	var bait: int = sim.spawn(2, Vector2(10.0, 5.5), "usa_builder")
	_trigger_at(sim, rifle, bait)
	var farthest: float = 0.0
	for tick in range(900):
		if _mode_of(sim, rifle) == "retaliate" and sim._entities[rifle].combat.target_id != null:
			sim._entities[rifle].combat.until = sim.tick() + 1000
			sim._entities[bait].position = [minf(sim._entities[rifle].position[0] + 5.0, 30.0), 5.5]
		sim.step()
		farthest = maxf(farthest, absf(sim._entities[rifle].position[0] - 5.5))
		if _mode_of(sim, rifle) == "guard": break
	var unit: Dictionary = sim._entities[rifle]
	runner.check(farthest > 7.0 and farthest < 8.5, "RL1 chase stops at the 7.2 unit leash, farthest %s" % farthest)
	runner.check(unit.combat.mode == "guard" and unit.combat.goal == null and absf(unit.position[0] - 5.5) < 1.5, "RL1 walks home and ends in guard")
	var far = _ret_world()
	var rifle2: int = far[1]
	_trigger_at(far[0], rifle2, far[2])
	far[0]._entities[far[2]].position = [28.5, 10.5]
	far[0].step()
	runner.check(far[0]._entities[rifle2].combat.target_id == null and _mode_of(far[0], rifle2) == "retaliate", "RL2 attacker beyond 16 cells from home: back home")
	var timed = _ret_world()
	_trigger_at(timed[0], timed[1], timed[2])
	timed[0]._entities[timed[1]].combat.until = timed[0].tick() + 1
	timed[0].step()
	timed[0].step()
	runner.check(timed[0]._entities[timed[1]].combat.target_id == null, "RL3 leash tick reached: back home")
	return true

func test_retaliate_return_scan_and_rehit(runner) -> bool:
	var sim = Fixture.world()
	sim.add_player(2, 0, "ai")
	var rifle: int = sim.spawn(1, Vector2(5.5, 5.5), "usa_rifle_infantry")
	var bait: int = sim.spawn(2, Vector2(9.0, 5.5), "usa_builder")
	_trigger_at(sim, rifle, bait)
	sim._entities[rifle].position = [13.5, 5.5]
	sim._entities[bait].position = [28.5, 5.5]
	sim.step()
	runner.check(sim._entities[rifle].combat.target_id == null and sim._entities[rifle].status != "idle", "RS1 returning")
	var enemy: int = sim.spawn(2, Vector2(5.5, 12.0), "usa_builder")
	var seen: bool = false
	for tick in range(31):
		sim.step()
		seen = seen or sim._entities[rifle].combat.target_id == enemy
	runner.check(seen, "RS1 enemy unit within 7.2 cells of home becomes the target")
	var rehit = _ret_world()
	_trigger_at(rehit[0], rehit[1], rehit[2])
	rehit[0]._entities[rehit[1]].position = [14.5, 10.5]
	rehit[0]._entities[rehit[2]].position = [28.5, 10.5]
	rehit[0].step()
	runner.check(rehit[0]._entities[rehit[1]].combat.target_id == null, "RS2 returning")
	for tick in range(5): rehit[0].step()
	var tank: int = rehit[0].spawn(2, Vector2(18.0, 11.0), "usa_tank")
	_trigger_at(rehit[0], rehit[1], tank)
	var unit: Dictionary = rehit[0]._entities[rehit[1]]
	runner.check(unit.combat.target_id == tank and unit.combat.until == rehit[0].tick() + 300 and rehit[0].retaliations() == 0, "RS2 hit while returning restarts the chase, leash refreshed")
	var shop = Fixture.world()
	var guard: int = shop.spawn(1, Vector2(5.5, 5.5), "usa_rifle_infantry")
	shop._entities[guard].combat.mode = "retaliate"
	shop._entities[guard].combat.goal = [5.5, 5.5]
	shop._entities[guard].position = [10.5, 5.5]
	shop._entities[guard].status = "moving"
	shop._entities[guard].destination = [5.5, 5.5]
	shop._buildings[900] = {"id": 900, "owner": 2, "kind": "usa_barracks", "origin": [4, 8], "hp": 1000000, "max_hp": 1000000, "completed": true, "queue": []}
	for tick in range(31): shop.step()
	runner.check(shop._entities[guard].combat.target_id == null, "RS3 an enemy building is never a return target")
	return true

func test_retaliate_same_tick_cases(runner) -> bool:
	var expected := {"move": "move", "attack": "attack", "attack_move": "attack_move", "stop": "retaliate"}
	for type in expected:
		var world: Array = _ret_world()
		var sim = world[0]
		var payload := {"type": type, "entity_ids": [world[1]]}
		if type == "move" or type == "attack_move": payload.target = [20.5, 20.5]
		if type == "attack": payload.target_id = world[2]
		Fixture.send(sim, payload)
		sim.step()
		runner.check(_mode_of(sim, world[1]) == expected[type], "RC1 %s due in the trigger tick leaves %s" % [type, expected[type]])
	for type in ["move", "stop", "attack", "attack_move"]:
		var world: Array = _ret_world()
		var sim = world[0]
		for tick in range(10):
			if _mode_of(sim, world[1]) == "retaliate": break
			sim.step()
		runner.check(_mode_of(sim, world[1]) == "retaliate", "RC2 %s: unit retaliating after the first shot" % type)
		var payload := {"type": type, "entity_ids": [world[1]]}
		if type == "move" or type == "attack_move": payload.target = [20.5, 20.5]
		if type == "attack": payload.target_id = world[2]
		Fixture.send(sim, payload)
		sim.step()
		runner.check(_mode_of(sim, world[1]) == ("guard" if type == "stop" else type), "RC2 %s replaces retaliate" % type)
	var gone: Array = _ret_world()
	_trigger_at(gone[0], gone[1], gone[2])
	gone[0]._entities[gone[1]].position = [15.5, 10.5]
	gone[0]._entities[gone[2]].position = [25.5, 10.5]
	gone[0].remove_object(gone[2])
	runner.check(gone[0]._entities[gone[1]].combat.target_id == null and gone[0]._entities[gone[1]].status == "path_pending", "RC3 attacker removed: unit sent home")
	gone[0].step()
	var dead_order: Dictionary = Fixture.send(gone[0], {"type": "attack", "entity_ids": [gone[1]], "target_id": gone[2]})
	gone[0].step()
	runner.check(_mode_of(gone[0], gone[1]) == "retaliate" and gone[0]._entities[gone[1]].combat.target_id == null, "RC3 attack on a dead target changes nothing, no crash")
	var joiner: Array = _ret_world()
	_trigger_at(joiner[0], joiner[1], joiner[2])
	joiner[0].remove_object(joiner[1])
	joiner[0].step()
	var swap: Array = _ret_world()
	var second: int = swap[0].spawn(2, Vector2(14.0, 11.5), "usa_rifle_infantry")
	_trigger_at(swap[0], swap[1], swap[2])
	swap[0].remove_object(swap[2])
	_trigger_at(swap[0], swap[1], second)
	swap[0].step()
	runner.check(swap[0]._entities[swap[1]].combat.target_id == second, "RC4 target dies as a new hit lands: restarts against the new attacker")
	return true

func test_retaliate_go_home_queues_once(runner) -> bool:
	var world: Array = _ret_world()
	var sim = world[0]
	_trigger_at(sim, world[1], world[2])
	sim._entities[world[1]].status = "path_pending"
	sim._path_queue.append(world[1])
	sim.remove_object(world[2])
	runner.check(sim._path_queue.count(world[1]) == 1, "RG1 going home replaces the queued path request")
	sim.remove_object(world[1])
	runner.check(not sim._path_queue.has(world[1]), "RG1 no stale id after the unit dies")
	return true

func test_rng_sequence(runner) -> bool:
	var sim = Fixture.world()
	var seen: Array = []
	for i in range(4): seen.append(sim.next_random())
	runner.check(seen == [3777279546, 2342155435, 1692513196, 1525286], "S7 xorshift32 sequence")
	runner.check(sim.snapshot().rng == 1525286, "S7 snapshot rng is the state")
	return true

func test_splash_victims_boundary(runner) -> bool:
	var sim = Fixture.world()
	var attacker: Dictionary = {"id": -1, "owner": 1}
	var edge: float = 0.52 + Definitions.radius("usa_rifle_infantry")
	for case in [[edge, true], [edge + 0.01, false]]:
		var fresh = Fixture.world()
		fresh.spawn(2, Vector2(5.0 + case[0], 5.0), "usa_rifle_infantry")
		runner.check(Combat.splash_victims(fresh, Vector2(5.0, 5.0), 0.52, ["enemies"], attacker).size() == (1 if case[1] else 0), "S7 blast edge " + str(case[0]))
	return true

func _cluster() -> Array:
	var sim = Fixture.world()
	var row: Array = []
	for x in range(5):
		var id: int = sim.spawn(2, Vector2(10.5 + x, 10.5), "usa_rifle_infantry")
		sim._entities[id].hp = 1000000000
		sim._entities[id].combat = null
		row.append(id)
	return [sim, row, sim.spawn(1, Vector2(12.5, 15.5), "usa_tank")]

func test_splash_cluster(runner) -> bool:
	var world: Array = _cluster()
	var sim = world[0]
	var row: Array = world[1]
	var tank: int = world[2]
	runner.check(Fixture.send(sim, {"type": "attack", "entity_ids": [tank], "target_id": row[2]}).ok, "S7 attack accepted")
	var shells: int = 0
	var middle_hits: int = 0
	var neighbour_hits: int = 0
	var wrong: int = 0
	for tick in range(2000):
		if shells == 300: break
		sim._entities[tank].combat.next_fire_tick = 0
		sim.step()
		var middle: bool = false
		for shot in _shots(sim):
			if shot.target_id == row[2]:
				middle = true
				wrong += 0 if not shot.splash and shot.damage == 6000 else 1
			else:
				neighbour_hits += 1
				wrong += 0 if shot.splash and shot.damage == 6000 else 1
		shells += 1 if middle else 0
		middle_hits += 1 if middle else 0
	var rate: float = float(neighbour_hits) / 300.0
	print("S7 cluster: shells ", shells, " middle ", middle_hits, " neighbour hits ", neighbour_hits, " rate ", rate)
	runner.check(shells == 300 and middle_hits == 300 and wrong == 0, "S7 aimed infantry hit by every shell, flags and damage right")
	runner.check(rate >= 0.30 and rate <= 0.42, "S7 neighbour hits per shell inside 0.30-0.42")
	runner.check(neighbour_hits == 105, "S7 draw order pinned: 105 neighbour hits")
	return true

func _teamed(seats: Array) -> RefCounted:
	var sim = Fixture.world()
	for seat in seats: sim.add_player(seat[0], 0, "human", seat[1])
	return sim

func test_splash_mask(runner) -> bool:
	var sim = _teamed([[1, 1], [2, 2], [3, 1]])
	var attacker: int = sim.spawn(1, Vector2(10.5, 10.5), "usa_tank")
	var target: int = sim.spawn(2, Vector2(10.5, 15.5), "usa_tank")
	var ally: int = sim.spawn(3, Vector2(11.4, 15.5), "usa_tank")
	var own: int = sim.spawn(1, Vector2(9.6, 15.5), "usa_tank")
	runner.check(Fixture.send(sim, {"type": "attack", "entity_ids": [attacker], "target_id": target}).ok, "S7 mask attack accepted")
	sim.step()
	var hit: Dictionary = {}
	for shot in _shots(sim):
		if shot.attacker_id == attacker: hit[shot.target_id] = shot.splash
	runner.check(hit == {target: false, ally: true, own: true}, "S7 INI mask hurts own and allied units, never the attacker")
	var close = _teamed([[1, 1], [2, 2]])
	var adjacent: int = close.spawn(1, Vector2(10.5, 10.5), "usa_tank")
	var foe: int = close.spawn(2, Vector2(11.4, 10.5), "usa_tank")
	Fixture.send(close, {"type": "attack", "entity_ids": [adjacent], "target_id": foe})
	close.step()
	runner.check(not _shots(close).any(func(e: Dictionary) -> bool: return e.attacker_id == adjacent and e.target_id == adjacent), "S7 attacker next to its target is not its own victim")
	var record: Dictionary = Combat.record(sim, target)
	runner.check(Combat.splash_victims(sim, Vector2(record.position[0], record.position[1]), 0.2, ["enemies"], Combat.record(sim, attacker)).size() == 1, "S7 an enemies-only mask would skip allies")
	return true

func _last_builder_world(keep_buildings: bool) -> Array:
	var sim = _teamed([[1, 1], [2, 2], [3, 1]])
	var target: int = sim.spawn(3, Vector2(10.5, 10.5), "usa_builder")
	var splashed: int = sim.spawn(1, Vector2(11.4, 10.5), "usa_builder")
	sim.spawn(2, Vector2(9.5, 15.5), "usa_tank")
	sim.spawn(2, Vector2(25.5, 25.5), "usa_builder")
	var homes: Array[int] = []
	for seat in [1, 2, 3]: homes.append(EconomyFixture.add_completed(sim, seat, "usa_barracks", Vector2i(2, seat * 6)))
	for id in [target, splashed]: sim._entities[id].hp = 1000
	sim.start_match([1, 2, 3] as Array[int])
	if not keep_buildings:
		sim.remove_object(homes[0])
		sim.remove_object(homes[2])
	return [sim, target, splashed]

func test_splash_last_builder_same_tick(runner) -> bool:
	var out: Array = _last_builder_world(false)
	out[0].step()
	var match_state: Dictionary = out[0].snapshot().match
	runner.check(not out[0].snapshot().entities.any(func(e: Dictionary) -> bool: return e.id in [out[1], out[2]]), "S7 target and splashed builder both die")
	runner.check(match_state.status == "won" and match_state.winner == 2 and match_state.ended_tick == out[0].tick() - 1, "S7 team out on that tick")
	var stays: Array = _last_builder_world(true)
	stays[0].step()
	runner.check(stays[0].snapshot().match.status == "ongoing", "S7 units dying never end a match while the team owns buildings")
	return true

func test_splash_event_flag(runner) -> bool:
	var sim = Fixture.world()
	var tank: int = sim.spawn(1, Vector2(10.5, 10.5), "usa_tank")
	sim.spawn(2, Vector2(10.5, 15.5), "usa_tank")
	sim.spawn(2, Vector2(14.5, 15.5), "usa_tank")
	var before: int = sim.snapshot().rng
	sim.step()
	var shots: Array = _shots(sim).filter(func(s: Dictionary) -> bool: return s.attacker_id == tank)
	runner.check(shots.size() == 1 and shots[0].splash == false, "S7 lone tank target gives one non-splash event")
	runner.check(sim.snapshot().rng == before, "S7 vehicle target draws nothing")
	return true

func test_definitions_shared(runner) -> bool:
	runner.check(is_same(Economy.unit("usa_tank"), Economy.unit("usa_tank")) and is_same(Economy.building("usa_supply_center"), Economy.building("usa_supply_center")), "DF1 economy definitions are shared")
	runner.check(is_same(Definitions.weapon("rifle"), Definitions.weapon("rifle")) and is_same(Definitions.profile("usa_factory"), Definitions.profile("usa_factory")), "DF1 combat definitions are shared")
	runner.check(Economy.unit("nope").is_empty() and Economy.building("nope").is_empty() and Definitions.profile("nope").is_empty() and Definitions.weapon("nope").is_empty(), "DF1 unknown kinds are empty")
	return true

func test_rocket_splash_and_scatter(runner) -> bool:
	var sim = Fixture.world()
	var rocket: int = sim.spawn(1, Vector2(10.5, 10.5), "usa_rocket_infantry")
	var tank: int = sim.spawn(2, Vector2(10.5, 15.5), "usa_tank")
	sim._entities[tank].combat = null
	runner.check(Fixture.send(sim, {"type": "attack", "entity_ids": [rocket], "target_id": tank}).ok, "S8 rocket attack accepted")
	var shots: Array = []
	for tick in range(40):
		sim.step()
		shots.append_array(_shots(sim).filter(func(shot: Dictionary) -> bool: return shot.attacker_id == rocket))
	runner.check(shots.size() == 2 and shots.all(func(shot: Dictionary) -> bool: return shot.target_id == tank and not shot.splash and shot.damage == 40000), "S8 vehicle takes the primary 40000, no scatter")
	var world: Array = _cluster()
	var cluster = world[0]
	var row: Array = world[1]
	var shooter: int = cluster.spawn(1, Vector2(13.5, 15.5), "usa_rocket_infantry")
	runner.check(Fixture.send(cluster, {"type": "attack", "entity_ids": [shooter], "target_id": row[2]}).ok, "S8 cluster attack accepted")
	var primary: int = 0
	var neighbours: int = 0
	for tick in range(600):
		cluster._entities[shooter].combat.next_fire_tick = 0
		cluster.step()
		for shot in _shots(cluster).filter(func(shot: Dictionary) -> bool: return shot.attacker_id == shooter):
			if shot.target_id == row[2]: primary += 1 if not shot.splash and shot.damage == 4000 else 1000
			else: neighbours += 1 if shot.splash and shot.damage == 4000 else 1000
	runner.check(primary == 600 and neighbours > 0 and neighbours < 1000, "S8 infantry impact scatters onto neighbours as the cannon's does")
	return true

func test_damage_table_new_types(runner) -> bool:
	var table := {
		"human": [100, 10, 10, 100, 100], "tank": [25, 100, 100, 100, 25], "builder_vehicle": [25, 100, 100, 100, 25],
		"light_vehicle": [50, 100, 50, 100, 50], "helicopter": [50, 50, 25, 50, 50], "structure": [50, 100, 50, 100, 50],
		"structure_tough": [50, 100, 50, 80, 50], "base_defense": [50, 100, 25, 100, 50]}
	var types := ["small_arms", "armor_piercing", "infantry_missile", "explosion", "rapid_fire"]
	var wrong: int = 0
	for armor in table:
		for i in range(types.size()):
			wrong += 0 if Definitions.armor_percent(armor, types[i]) == table[armor][i] else 1
	runner.check(wrong == 0, "S8 every damage type against every armor row equals the table")
	var rocket: Dictionary = Definitions.weapon("rocket")
	runner.check(rocket.damage == 40000 and rocket.damage_type == "infantry_missile" and rocket.range == 7.0 and rocket.delay_ticks == 30 and rocket.primary_radius == 0.2 and rocket.affects == Definitions.weapon("cannon").affects, "S8 rocket row")
	var gun: Dictionary = Definitions.weapon("scout_gun")
	runner.check(gun.damage == 10000 and gun.damage_type == "rapid_fire" and gun.range == 6.0 and gun.delay_ticks == 6 and gun.primary_radius == 0.0, "S8 scout gun row")
	return true

func test_damage_table_gattling(runner) -> bool:
	var column := {"human": 100, "tank": 10, "builder_vehicle": 10, "light_vehicle": 50, "structure": 10, "structure_tough": 10, "helicopter": 50, "base_defense": 25}
	var wrong: int = 0
	for armor in column: wrong += 0 if Definitions.armor_percent(armor, "gattling") == column[armor] else 1
	runner.check(wrong == 0, "S9 gattling against every armor row equals the column")
	var gun: Dictionary = Definitions.weapon("militia_gun")
	runner.check(gun.damage == 15000 and gun.damage_type == "small_arms" and gun.range == 4.0 and gun.delay_ticks == 30 and gun.clip_size == 0 and gun.primary_radius == 0.0 and gun.affects == [], "S9 militia gun row")
	return true

func test_damage_table_frc_weapons(runner) -> bool:
	var armors := ["human", "tank", "builder_vehicle", "light_vehicle", "structure", "structure_tough", "helicopter", "base_defense"]
	var columns := {
		"gattling": [100, 10, 10, 50, 10, 10, 50, 25],
		"explosion": [100, 100, 100, 100, 100, 80, 50, 100],
		"armor_piercing": [10, 100, 100, 100, 100, 100, 50, 100]}
	var rows := {
		"pickup_gun": [10000, "gattling", 6.0, 6, 0.0], "pickup_cannon": [45000, "gattling", 6.0, 30, 1.0], "pickup_rocket": [50000, "explosion", 6.0, 30, 0.2],
		"light_tank_gun": [20000, "armor_piercing", 6.0, 30, 0.2], "light_tank_gun_plus": [25000, "armor_piercing", 6.0, 30, 0.2]}
	var wrong: int = 0
	for weapon_name: String in rows:
		var weapon: Dictionary = Definitions.weapon(weapon_name)
		var row: Array = rows[weapon_name]
		runner.check(weapon.damage == row[0] and weapon.damage_type == row[1] and weapon.range == row[2] and weapon.delay_ticks == row[3] and weapon.clip_size == 0 and weapon.primary_radius == row[4], "S10 %s row" % weapon_name)
		runner.check(weapon.affects == (["allies", "enemies", "neutrals"] if row[4] > 0.0 else []), "S10 %s affects" % weapon_name)
		for index in armors.size():
			wrong += 0 if weapon.damage * Definitions.armor_percent(armors[index], row[1]) / 100 == weapon.damage * columns[row[1]][index] / 100 else 1
	runner.check(wrong == 0, "S10 every new weapon against every armor row equals the column x damage")
	runner.check(Definitions.weapon("pickup_cannon").infantry_blast == 1.8533333333333333 and Definitions.weapon("pickup_rocket").infantry_scatter == false and not Definitions.weapon("rocket").has("infantry_blast") and not Definitions.weapon("cannon").has("infantry_scatter"), "S10 the infantry fields exist on the two pickup weapons only")
	var sim = Fixture.world()
	var pickup: int = sim.spawn(1, Vector2(10.5, 10.5), "frc_light_vehicle")
	sim._entities[pickup].combat.tier = 1
	var target: int = sim.spawn(2, Vector2(10.5, 15.5), "usa_tank")
	var close: int = sim.spawn(2, Vector2(10.5, 15.5 + Definitions.radius("usa_tank") + 0.9), "usa_tank")
	var outside: int = sim.spawn(2, Vector2(10.5, 15.5 - Definitions.radius("usa_tank") - 1.1), "usa_tank")
	for id in [target, close, outside]: sim._entities[id].combat = null
	Fixture.send(sim, {"type": "attack", "entity_ids": [pickup], "target_id": target})
	sim.step()
	var hit: Dictionary = {}
	for shot in _shots(sim):
		if shot.attacker_id == pickup: hit[shot.target_id] = shot.splash
	runner.check(hit == {target: false, close: true}, "S10 the pickup cannon hits a vehicle whose edge is within 1.0 cell, not one at 1.1")
	return true

func test_leash_square_matches_pow(runner) -> bool:
	var kinds: Array[String] = Registry.units() + Registry.buildings()
	var bounds: int = 0
	var differ: int = 0
	for kind: String in kinds:
		var vision: float = Definitions.vision(kind)
		for scale: float in [Combat.LEASH_UNIT, Combat.LEASH_ATTACKER]:
			var bound: float = vision * scale
			bounds += 1
			differ += int(bound * bound != pow(bound, 2))
	runner.check(bounds >= 40 and differ == 0, "P-pow every real leash bound squares the same with x * x and pow (%d of %d differ)" % [differ, bounds])
	return true

func test_radius_cache(runner) -> bool:
	var mismatches: int = 0
	for id: String in Registry.units() + Registry.buildings():
		var row: Dictionary = Registry.kind(id)
		var footprint: Vector2i = row.get("footprint", Vector2i.ZERO)
		var expected: float = row.radius if row.has("radius") else 0.5 * sqrt(float(footprint.x * footprint.x + footprint.y * footprint.y))
		if Definitions.radius(id) != expected or Definitions.radius(id) != expected: mismatches += 1
	runner.check(mismatches == 0, "RAD1 cached radius equals the formula for every kind (%d mismatches)" % mismatches)
	var tank: Dictionary = Registry.kind("usa_tank").duplicate()
	tank.radius = 0.25
	Registry.add_test_kind("rc_test", tank)
	var first: float = Definitions.radius("rc_test")
	tank.radius = 0.75
	Registry.add_test_kind("rc_test", tank)
	var second: float = Definitions.radius("rc_test")
	Registry.clear_test_kinds()
	runner.check(first == 0.25 and second == 0.75, "RAD2 test kind radius is not stale after add_test_kind")
	runner.check(not Registry.radius_cache.has("rc_test"), "RAD3 clear_test_kinds drops cached radius")
	return true

func test_nearest_matches_oracle(runner) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261107
	var scans: int = 0
	var mismatches: int = 0
	for state in range(200):
		var sim = _oracle_world(rng)
		var grid: Dictionary = Combat._build_grid(sim)
		var old_grid: Dictionary = _oracle_build_grid(sim)
		for unit: Dictionary in sim._entities.values():
			var edge: bool = rng.randi() % 2 == 0
			var units_only: bool = rng.randi() % 3 == 0
			var radius: float = rng.randf_range(3.0, 7.0) if edge else rng.randf_range(4.0, 16.0)
			sim._combat_work = 0
			var expected: Variant = _oracle_nearest(sim, unit, old_grid, radius, units_only, edge)
			var expected_work: int = sim._combat_work
			sim._combat_work = 0
			var actual: Variant = Combat._nearest(sim, unit, grid, radius, units_only, edge)
			scans += 1
			if actual != expected or sim._combat_work != expected_work: mismatches += 1
	runner.check(scans >= 200 and mismatches == 0, "N1 per-owner _nearest equals the mixed-grid oracle (%d scans, %d mismatches)" % [scans, mismatches])
	return true

func _oracle_world(rng: RandomNumberGenerator) -> RefCounted:
	var sim = Fixture.world()
	var owners: int = 3 + rng.randi() % 5
	for player in range(1, owners):
		sim.add_player(player, 0, "human", 1 + rng.randi() % 3 if rng.randi() % 3 != 0 else 0)
	var kinds: Array[String] = ["usa_rifle_infantry", "usa_tank", "usa_collector"]
	var units: Array[int] = []
	for i in range(40):
		var position := Vector2(2.5 + rng.randi() % 24, 2.5 + rng.randi() % 24)
		var id: int = sim.spawn(1 + rng.randi() % owners, position, kinds[rng.randi() % 3])
		if id > 0: units.append(id)
	for id in units:
		if rng.randi() % 8 == 0: sim._entities[id].container_id = 0
	for i in range(6):
		var kind: String = "usa_power_plant" if rng.randi() % 2 == 0 else "usa_supply_center"
		var id: int = sim._next_entity_id
		sim._next_entity_id += 1
		sim._buildings[id] = {"id": id, "owner": 1 + rng.randi() % owners, "kind": kind, "hp": 1, "max_hp": 1, "origin": [rng.randi() % 26, rng.randi() % 26], "completed": true}
		if i == 0: sim._buildings[id].rebuild = {"worker_id": 7}
	return sim

func _oracle_build_grid(sim: Simulation) -> Dictionary:
	var grid: Dictionary = {}
	for entity: Dictionary in sim._entities.values():
		if Registry.air_kinds.has(entity.kind) or entity.has("container_id"): continue
		_oracle_bucket(grid, int(floorf(entity.position[0] / Combat.GRID_CELL)), int(floorf(entity.position[1] / Combat.GRID_CELL)), entity)
	for building: Dictionary in sim._buildings.values():
		if Combat.masked(building): continue
		var size: Vector2i = Economy.building(building.kind).footprint
		for y in range(int(floorf(building.origin[1] / Combat.GRID_CELL)), int(floorf((building.origin[1] + size.y) / Combat.GRID_CELL)) + 1):
			for x in range(int(floorf(building.origin[0] / Combat.GRID_CELL)), int(floorf((building.origin[0] + size.x) / Combat.GRID_CELL)) + 1):
				_oracle_bucket(grid, x, y, building)
	return grid

func _oracle_bucket(grid: Dictionary, x: int, y: int, target: Dictionary) -> void:
	var key := Vector2i(x, y)
	if not grid.has(key): grid[key] = []
	grid[key].append(target)

func _oracle_nearest(sim: Simulation, unit: Dictionary, grid: Dictionary, radius: float, units_only: bool, edge: bool) -> Variant:
	var best: Variant = null
	var best_distance: float = INF
	var position := Vector2(unit.position[0], unit.position[1])
	var window: float = radius + Definitions.radius(unit.kind) + Combat.MAX_TARGET_RADIUS if edge else radius
	for y in range(int(floorf((position.y - window) / Combat.GRID_CELL)), int(floorf((position.y + window) / Combat.GRID_CELL)) + 1):
		for x in range(int(floorf((position.x - window) / Combat.GRID_CELL)), int(floorf((position.x + window) / Combat.GRID_CELL)) + 1):
			for target: Variant in grid.get(Vector2i(x, y), []):
				if not Combat.hostile(sim, unit.owner, target.owner) or (units_only and target.has("origin")): continue
				sim._combat_work += 1
				var distance: float = Combat.edge_gap(unit, target) if edge else Combat.distance_squared(position, target)
				if distance > (radius + Combat.EDGE_EPS if edge else radius * radius): continue
				if distance < best_distance or (distance == best_distance and target.id < best):
					best = target.id
					best_distance = distance
	return best

func _oracle_splash(sim: Simulation, impact: Vector2, radius: float, affects: Array, attacker: Dictionary) -> Array[Dictionary]:
	var victims: Array[Dictionary] = []
	for pool: Variant in [sim._entities, sim._buildings]:
		for victim: Variant in pool.values():
			if victim.id == attacker.id or Registry.air_kinds.has(victim.kind) or victim.has("container_id") or Combat.masked(victim): continue
			if (Combat._victim_centre(victim).distance_to(impact) - Definitions.radius(victim.kind)) > radius + Combat.EDGE_EPS: continue
			if affects.has("enemies" if Combat.hostile(sim, attacker.owner, victim.owner) else "allies"): victims.append(victim)
	victims.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return victims

func _ids(victims: Array[Dictionary]) -> Array:
	return victims.map(func(victim: Dictionary) -> int: return victim.id)

func _impacts(sim: Simulation, rng: RandomNumberGenerator) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in range(10): points.append(Vector2(rng.randf_range(0.0, 32.0), rng.randf_range(0.0, 32.0)))
	var buildings: Array = sim._buildings.values()
	var units: Array = sim._entities.values()
	for i in range(5):
		points.append(Combat._victim_centre(buildings[rng.randi() % buildings.size()]))
		var unit: Dictionary = units[rng.randi() % units.size()]
		points.append(Vector2(unit.position[0], unit.position[1]))
	return points

func test_splash_index_matches_oracle(runner) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	var queries: int = 0
	var mismatches: int = 0
	var radii: Array[float] = [0.2, 0.52, 1.0, 1.8533333333333333]
	for state in range(50):
		var sim = _oracle_world(rng)
		var attackers: Array[Dictionary] = [sim._entities.values()[0], sim._buildings.values()[0], {"id": -1, "owner": 1 + rng.randi() % 3}]
		var index: Dictionary = Combat._splash_index(sim, {})
		var first: bool = true
		for impact in _impacts(sim, rng):
			for radius in radii:
				for attacker in attackers:
					var affects: Array = ["enemies"] if rng.randi() % 2 == 0 else ["allies", "enemies", "neutrals"]
					queries += 1
					var actual: Array[Dictionary] = Combat.splash_victims(sim, impact, radius, affects, attacker) if first else Combat.splash_victims(sim, impact, radius, affects, attacker, index)
					first = false
					if _ids(actual) != _ids(_oracle_splash(sim, impact, radius, affects, attacker)): mismatches += 1
	runner.check(queries >= 10000 and mismatches == 0, "SI1 indexed splash equals the full scan (%d queries, %d mismatches)" % [queries, mismatches])
	return true

func test_splash_hits_passenger_unloaded_this_tick(runner) -> bool:
	var row: Dictionary = Registry.kind("usa_rifle_infantry").duplicate(true)
	row.radius = 0.45
	Registry.add_test_kind("si_wide_infantry", row)
	var sim = Fixture.world()
	sim.add_player(1, 10000)
	sim.add_player(2, 0)
	var car: int = sim.spawn(2, Vector2(16.5, 15.5), "usa_light_vehicle")
	var passenger: int = sim.spawn(2, Vector2(18.5, 15.5), "si_wide_infantry")
	Fixture.send(sim, {"type": "enter", "player": 2, "entity_ids": [passenger], "target_id": car})
	for i in range(100): sim.step()
	runner.check(Fixture.object(sim, passenger).get("container_id", 0) == car, "SI2 setup: the passenger boarded")
	var target: int = sim.spawn(2, Vector2(15.99, 14.5), "usa_builder")
	var tank: int = sim.spawn(1, Vector2(10.5, 14.5), "usa_tank")
	runner.check(Fixture.send(sim, {"type": "attack", "entity_ids": [tank], "target_id": target}).ok, "SI2 attack accepted")
	var first: int = -1
	while first < 0 and sim.tick() < 200:
		sim.step()
		for shot in _shots(sim):
			if shot.attacker_id == tank and first < 0: first = shot.tick
	var next_shot: int = first + Definitions.weapon("cannon").delay_ticks
	while sim.tick() < next_shot: sim.step()
	runner.check(Fixture.send(sim, {"type": "unload", "player": 2, "target_id": car}).ok, "SI2 unload accepted")
	sim.step()
	var hits: Array = _shots(sim).filter(func(shot: Dictionary) -> bool: return shot.attacker_id == tank and shot.target_id == passenger)
	runner.check(first >= 0 and hits.size() == 1 and hits[0].splash and hits[0].tick == next_shot, "SI2 a passenger unloaded on the firing tick inside the blast is hit once, got %s" % str(_shots(sim)))
	Registry.clear_test_kinds()
	return true

func test_splash_index_built_only_on_splash_ticks(runner) -> bool:
	var sim = Fixture.world()
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	sim.spawn(1, Vector2(10.5, 10.5), "usa_tank")
	sim.spawn(2, Vector2(15.5, 10.5), "usa_tank")
	Profiler.reset()
	Profiler.enabled = true
	var splash_ticks: int = 0
	for i in range(200):
		sim.step()
		var splashing: bool = false
		for shot in _shots(sim):
			if not shot.splash and Definitions.weapon(Definitions.profile(Combat.record(sim, shot.attacker_id).kind).weapon).primary_radius > 0.0: splashing = true
		splash_ticks += 1 if splashing else 0
	var builds: int = Profiler.calls(&"combat.splash_index")
	Profiler.enabled = false
	Profiler.reset()
	runner.check(splash_ticks > 0 and builds == splash_ticks, "SI3 one index build per tick with a splash-weapon shot, none otherwise (%d ticks, %d builds)" % [splash_ticks, builds])
	return true
