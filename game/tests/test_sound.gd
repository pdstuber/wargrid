@warning_ignore_start("untyped_declaration")
extends RefCounted

const Director = preload("res://scripts/presentation/sound_director.gd")
const Cues = preload("res://scripts/presentation/sound_cues.gd")
const Player = preload("res://scripts/presentation/sound_player.gd")
const Music = preload("res://scripts/presentation/music_player.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Shared = preload("res://scripts/simulation/definitions/shared.gd")
const SkirmishScene = preload("res://scenes/skirmish.tscn")
const Fixture = preload("res://tests/combat_fixture.gd")
const OnlineTests = preload("res://tests/test_online_scene.gd")

func cases() -> Array[Callable]:
	return [test_catch_up_collects_every_step, test_collect_step_copies, test_stalled_tick_is_collected_once, test_event_accessors_are_live, test_every_weapon_and_kind_has_a_cue, test_cue_by_weapon_then_damage_type, test_tier_picks_weapon, test_rifle_burst_plays_once_per_burst, test_splash_weapons_add_impact, test_death_cues, test_death_uses_previous_snapshot, test_unknown_dead_object_is_skipped, test_limits_and_cap, test_far_shot_takes_no_voice, test_mass_death_batch, test_container_burst, test_placement_and_errors, test_hole_and_site_are_not_placements, test_setup_phase_is_silent, test_stalled_tick_is_silent, test_first_shot_after_restart_is_heard, test_scenes_boot_with_sound, test_bus_layout, test_update_drains_pending]

func test_catch_up_collects_every_step(runner) -> bool:
	var suite = OnlineTests.new()
	var online: Dictionary = await suite._online(runner, 1)
	var main = online.main
	suite._run(main, 10)
	var before: int = main.simulation.tick()
	suite._peer_packets(online.transport, 2, before, before + 3)
	suite._run(main, 1)
	var ticks: Array[int] = main._sound.director.consumed_ticks()
	runner.check(main.simulation.tick() == before + 2, "SD1 frame advanced two ticks, got %d" % (main.simulation.tick() - before))
	runner.check(ticks.slice(-2) == [before + 1, before + 2], "SD1 update consumed ticks %s, lacks t+1 in a two-step frame" % [ticks])
	runner.check(main._sound.director.collected_ticks().is_empty(), "SD1 update left steps pending")
	main.free()
	return true

func test_collect_step_copies(runner) -> bool:
	var director = Director.new(1)
	var events: Array[Dictionary] = [{"type": "shot", "tick": 5, "attacker_id": 1, "target_id": 2, "damage": 10, "splash": false}]
	var results: Array[Dictionary] = [{"tick": 5, "player": 1, "sequence": 0, "ok": true, "error": ""}]
	director.collect_step(5, events, results)
	events[0].damage = 99
	events.clear()
	results.clear()
	var stored: Dictionary = director.pending_step(0)
	runner.check(stored.events.size() == 1 and stored.events[0].damage == 10 and stored.results.size() == 1, "SD2 stored step is a copy")
	return true

func test_stalled_tick_is_collected_once(runner) -> bool:
	var director = Director.new(1)
	var events: Array[Dictionary] = []
	director.collect_step(20, events, events)
	director.collect_step(20, events, events)
	runner.check(director.collected_ticks() == [20], "SD3 tick 20 collected once, got %s" % [director.collected_ticks()])
	director.reset()
	director.collect_step(20, events, events)
	runner.check(director.collected_ticks() == [20], "SD3 reset allows a new match to start at a low tick")
	return true

func test_event_accessors_are_live(runner) -> bool:
	var sim = Fixture.world()
	sim.spawn(1, Vector2(2.5, 2.5), "usa_rifle_infantry")
	sim.spawn(2, Vector2(5.5, 2.5), "usa_builder")
	sim.step()
	runner.check(not sim.combat_events().is_empty() and sim.combat_events() == sim.snapshot().combat_events, "SD4 accessor matches snapshot after a shot")
	runner.check(sim.command_results() == sim.snapshot().command_results, "SD4 results match snapshot")
	var quiet := false
	for i in 3:
		sim.step()
		if sim.combat_events().is_empty(): quiet = true
	runner.check(quiet, "SD4 events cleared by a step without fire")
	return true

func _shot(tick: int, attacker: int, target: int, splash: bool = false) -> Dictionary:
	return {"type": "shot", "tick": tick, "attacker_id": attacker, "target_id": target, "damage": 1, "splash": splash}

func _death(tick: int, id: int) -> Dictionary:
	return {"type": "death", "tick": tick, "object_id": id}

func _unit(id: int, kind: String, owner: int, at: Vector2, tier: int = 0) -> Dictionary:
	return {"id": id, "owner": owner, "kind": kind, "position": [at.x, at.y], "combat": {"tier": tier}}

func _building(id: int, kind: String, owner: int, origin: Vector2, extra: Dictionary = {}) -> Dictionary:
	var row := {"id": id, "owner": owner, "kind": kind, "origin": [origin.x, origin.y], "completed": true}
	row.merge(extra)
	return row

func _state(entities: Array, buildings: Array = [], status: String = "ongoing") -> Dictionary:
	return {"entities": entities, "buildings": buildings, "match": {"status": status}}

func _events(items: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for item: Dictionary in items: typed.append(item)
	return typed

func _feed(director, tick: int, events: Array, results: Array = []) -> void:
	director.collect_step(tick, _events(events), _events(results))

func _director(state: Dictionary):
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var director = Director.new(1, rng)
	director.update(state)
	return director

func _cues(requests: Array[Dictionary]) -> Array:
	return requests.map(func(request: Dictionary) -> String: return request.cue)

func test_every_weapon_and_kind_has_a_cue(runner) -> bool:
	for weapon: String in Shared.WEAPONS: runner.check(Cues.shot_cue(weapon) != "", "SD5 %s has a shot cue, got ''" % weapon)
	var kinds: Array[String] = Registry.units() + Registry.buildings()
	for kind in kinds:
		var tiers: Array = Registry.kind(kind).get("weapon_tiers", [])
		for tier in tiers: runner.check(Cues.shot_cue(tier) != "", "SD5 %s tier %s has a shot cue" % [kind, tier])
		var is_building: bool = Registry.buildings().has(kind)
		var cue: String = Cues.death_cue(kind, is_building)
		runner.check(cue != "", "SD5 %s has a death cue" % kind)
		if not is_building and Registry.kind(kind).get("armor", "") != "human": runner.check(cue == "vehicle_death", "SD5 %s is vehicle_death" % kind)
		if Registry.kind(kind).get("armor", "") == "human": runner.check(cue == "infantry_death", "SD5 %s is infantry_death" % kind)
	for cue: String in Cues.CUES:
		runner.check(ResourceLoader.exists(Cues.path(Cues.CUES[cue].sound)), "SD5 sound file of %s exists" % cue)
	for kind in Registry.buildings(): runner.check(ResourceLoader.exists(Cues.path(Cues.building_sound(kind))), "SD5 building sound of %s exists" % kind)
	return true

func test_cue_by_weapon_then_damage_type(runner) -> bool:
	var expected := {"rifle": "rifle_burst", "militia_gun": "carbine", "scout_gun": "carbine", "rotary_gun": "carbine", "rotary_tower_gun": "carbine", "pickup_gun": "carbine", "tunnel_gun": "carbine", "cannon": "cannon", "pickup_cannon": "cannon", "light_tank_gun": "cannon", "light_tank_gun_plus": "cannon", "rocket": "launch", "battery": "launch", "pickup_rocket": "launch", "no_such": ""}
	for weapon: String in expected: runner.check(Cues.shot_cue(weapon) == expected[weapon], "SD6 %s gives %s, got '%s'" % [weapon, expected[weapon], Cues.shot_cue(weapon)])
	return true

func test_tier_picks_weapon(runner) -> bool:
	for tier in 3:
		var director = _director(_state([_unit(1, "frc_light_vehicle", 1, Vector2(5, 5), tier)]))
		_feed(director, 1, [_shot(1, 1, 1)])
		var got: Array = _cues(director.update(_state([_unit(1, "frc_light_vehicle", 1, Vector2(5, 5), tier)])))
		runner.check(got.has(["carbine", "cannon", "launch"][tier]), "SD7 tier %d gives %s" % [tier, ["carbine", "cannon", "launch"][tier]])
	return true

func test_rifle_burst_plays_once_per_burst(runner) -> bool:
	var state := _state([_unit(1, "usa_rifle_infantry", 1, Vector2(5, 5)), _unit(2, "usa_rifle_infantry", 1, Vector2(8, 5)), _unit(3, "usa_tank", 2, Vector2(6, 6))])
	var director = _director(state)
	var by_tick := {100: [1], 104: [1, 2], 108: [1, 2], 130: [1], 134: [1], 138: [1]}
	for tick: int in by_tick: _feed(director, tick, by_tick[tick].map(func(attacker: int) -> Dictionary: return _shot(tick, attacker, 3)))
	var got: Array[Dictionary] = director.update(state)
	runner.check(got.size() == 3 and _cues(got).all(func(cue: String) -> bool: return cue == "rifle_burst"), "SD8 expected three rifle_burst, got %s" % [_cues(got)])
	runner.check(got.size() == 3 and got[0].position == Vector2(5, 5) and got[1].position == Vector2(8, 5) and got[2].position == Vector2(5, 5), "SD8 order A, B, A")
	return true

func test_splash_weapons_add_impact(runner) -> bool:
	var state := _state([_unit(1, "usa_tank", 1, Vector2(5, 5)), _unit(2, "usa_rifle_infantry", 1, Vector2(6, 5)), _unit(3, "usa_tank", 2, Vector2(9, 9))])
	var director = _director(state)
	_feed(director, 1, [_shot(1, 1, 3)])
	var got: Array[Dictionary] = director.update(state)
	runner.check(_cues(got) == ["cannon", "impact"] and got[0].position == Vector2(5, 5) and got[1].position == Vector2(9, 9), "SD9 cannon then impact at target, got %s" % [_cues(got)])
	_feed(director, 2, [_shot(2, 2, 3)])
	runner.check(_cues(director.update(state)) == ["rifle_burst"], "SD9 rifle has no impact")
	_feed(director, 3, [_shot(3, 1, 3, true)])
	runner.check(director.update(state).is_empty(), "SD9 splash hit is silent")
	return true

func _death_request(kind: String, building: bool, extra: Dictionary = {}) -> Dictionary:
	var state := _state([] if building else [_unit(5, kind, 2, Vector2(4, 4))], [_building(5, kind, 2, Vector2(4, 4), extra)] if building else [])
	var director = _director(state)
	_feed(director, 1, [_death(1, 5)])
	var got: Array[Dictionary] = director.update(_state([]))
	return got[0] if not got.is_empty() else {}

func test_death_cues(runner) -> bool:
	runner.check(_death_request("usa_rifle_infantry", false).get("cue") == "infantry_death", "SD10 infantry")
	var tank: Dictionary = _death_request("usa_tank", false)
	runner.check(tank.get("cue") == "vehicle_death" and tank.pitch >= 0.95 and tank.pitch <= 1.05, "SD10 tank vehicle_death with pitch in range")
	runner.check(_death_request("usa_collector", false).get("cue") == "vehicle_death", "SD10 helicopter")
	for row in [["usa_barracks", "building_small"], ["usa_factory", "building_large"], ["frc_hole_3", "building_small"], ["usa_defence", "building_small"]]:
		var request: Dictionary = _death_request(row[0], true, {"rebuild": {}} if row[0] == "frc_hole_3" else {})
		runner.check(request.get("cue") == "building" and request.get("sound") == row[1], "SD10 %s gives %s, got %s" % [row[0], row[1], request])
	var site: Dictionary = _death_request("usa_factory", true, {"completed": false})
	runner.check(site.get("sound") == "building_large", "SD10 unfinished factory site is large")
	return true

func test_death_uses_previous_snapshot(runner) -> bool:
	var director = _director(_state([], [_building(7, "usa_factory", 2, Vector2(10, 4))]))
	_feed(director, 1, [_death(1, 7)])
	var got: Array[Dictionary] = director.update(_state([]))
	runner.check(got.size() == 1 and got[0].position == Vector2(11.5, 5.5) and got[0].cue == "building", "SD11 building death at origin + footprint / 2, got %s" % [got])
	return true

func test_unknown_dead_object_is_skipped(runner) -> bool:
	var director = _director(_state([]))
	_feed(director, 1, [_death(1, 99), _shot(1, 98, 99)])
	runner.check(director.update(_state([])).is_empty(), "SD12 unknown ids give nothing")
	return true

func _playing(count: int, cue: String) -> Array[String]:
	var playing: Array[String] = []
	playing.resize(25)
	playing.fill("")
	for i in count: playing[i] = cue
	return playing

func _request(cue: String, position: Variant = Vector2.ZERO) -> Dictionary:
	return {"cue": cue, "sound": Cues.CUES[cue].sound, "pitch": 1.0, "position": position}

func test_limits_and_cap(runner) -> bool:
	var one: Array[Dictionary] = [_request("carbine")]
	runner.check(Player.plan(one, _playing(4, "carbine"), Vector2.ZERO, Player.MAX_DISTANCE_PX) == [-1], "SD13 fifth carbine dropped")
	runner.check(Player.plan(one, _playing(3, "carbine"), Vector2.ZERO, Player.MAX_DISTANCE_PX) == [3], "SD13 fourth carbine takes the first free slot")
	var cannon: Array[Dictionary] = [_request("cannon")]
	runner.check(Player.plan(cannon, _playing(2, "cannon"), Vector2.ZERO, Player.MAX_DISTANCE_PX) == [-1], "SD13 third cannon dropped")
	var full: Array[String] = []
	for cue in [["rifle_burst", 4], ["carbine", 4], ["cannon", 2], ["launch", 4], ["infantry_death", 3], ["vehicle_death", 4], ["building", 2], ["impact", 2]]:
		for i in cue[1]: full.append(cue[0])
	var impact: Array[Dictionary] = [_request("impact")]
	runner.check(full.size() == 25 and Player.plan(impact, full, Vector2.ZERO, Player.MAX_DISTANCE_PX) == [-1], "SD13 impact dropped with all 25 slots busy")
	var click: Array[Dictionary] = [_request("click", null)]
	runner.check(Player.plan(click, ["error", "error"], Vector2.ZERO, Player.MAX_DISTANCE_PX) == [-1], "SD13 click dropped with both UI slots busy")
	return true

func test_far_shot_takes_no_voice(runner) -> bool:
	var edge := Vector2(0, 1) * Player.MAX_DISTANCE_PX
	var far: Array[Dictionary] = [_request("carbine", _cells(edge + Vector2(0, 1)))]
	var near: Array[Dictionary] = [_request("carbine", _cells(edge))]
	runner.check(Player.plan(far, _playing(0, ""), Vector2.ZERO, Player.MAX_DISTANCE_PX) == [-1], "SD14 beyond MAX_DISTANCE_PX gets no voice")
	runner.check(Player.plan(near, _playing(0, ""), Vector2.ZERO, Player.MAX_DISTANCE_PX) == [0], "SD14 at MAX_DISTANCE_PX gets a slot")
	return true

func _cells(plane: Vector2) -> Vector2:
	return Player.Iso.plane_to_world(plane)

func _admitted(requests: Array[Dictionary]) -> Dictionary:
	var slots: Array[int] = Player.plan(requests, _playing(0, ""), Vector2.ZERO, Player.MAX_DISTANCE_PX)
	var counts := {}
	for i in requests.size():
		if slots[i] != -1: counts[requests[i].cue] = counts.get(requests[i].cue, 0) + 1
	return counts

func test_mass_death_batch(runner) -> bool:
	var entities: Array = []
	var events: Array = []
	for i in 20: entities.append(_unit(100 + i, "usa_rifle_infantry", 2, Vector2(2, 2)))
	for i in 6: entities.append(_unit(200 + i, "usa_tank", 2, Vector2(2, 2)))
	for unit: Dictionary in entities: events.append(_death(1, unit.id))
	var director = _director(_state(entities))
	_feed(director, 1, events)
	var counts: Dictionary = _admitted(director.update(_state([])))
	runner.check(counts.get("infantry_death") == 3 and counts.get("vehicle_death") == 4, "SD15 admitted %s" % [counts])
	return true

func test_container_burst(runner) -> bool:
	var entities: Array = [_unit(1, "frc_light_vehicle", 2, Vector2(2, 2))]
	var events: Array = [_death(1, 1)]
	for i in 5:
		entities.append(_unit(10 + i, "frc_rifle_infantry", 2, Vector2(2, 2)))
		events.append(_death(1, 10 + i))
	var director = _director(_state(entities))
	_feed(director, 1, events)
	var counts: Dictionary = _admitted(director.update(_state([])))
	runner.check(counts.get("vehicle_death") == 1 and counts.get("infantry_death") == 3, "SD16 admitted %s" % [counts])
	return true

func test_placement_and_errors(runner) -> bool:
	var director = _director(_state([]))
	var mine := _building(5, "usa_barracks", 1, Vector2(3, 3), {"completed": false})
	runner.check(_cues(director.update(_state([], [mine]))) == ["placement"], "SD17 own foundation gives placement")
	var enemy := _building(6, "usa_barracks", 2, Vector2(9, 9), {"completed": false})
	runner.check(director.update(_state([], [mine, enemy])).is_empty(), "SD17 enemy foundation is silent")
	var failed := {"tick": 2, "player": 1, "sequence": 1, "ok": false, "error": "No units left"}
	_feed(director, 2, [], [failed])
	runner.check(_cues(director.update(_state([], [mine, enemy]))) == ["error"], "SD17 own failed result gives error")
	_feed(director, 3, [], [{"tick": 3, "player": 2, "sequence": 1, "ok": false, "error": "No units left"}])
	runner.check(director.update(_state([], [mine, enemy])).is_empty(), "SD17 player 2 failure is silent")
	director.rejected("No units left")
	runner.check(_cues(director.update(_state([], [mine, enemy]))) == ["error"], "SD17 rejected gives error")
	director.rejected("Insufficient credits")
	_feed(director, 4, [], [{"tick": 4, "player": 1, "sequence": 2, "ok": false, "error": "Insufficient credits"}])
	runner.check(director.update(_state([], [mine, enemy])).is_empty(), "SD17 funds error gives no error cue")
	return true

func test_hole_and_site_are_not_placements(runner) -> bool:
	var director = _director(_state([]))
	var hole := _building(5, "frc_hole_2", 1, Vector2(3, 3), {"rebuild": {}})
	var site := _building(6, "frc_barracks", 1, Vector2(8, 8), {"completed": false, "hole_id": 5})
	runner.check(director.update(_state([], [hole, site])).is_empty(), "SD18 hole and rebuild site are silent")
	return true

func test_setup_phase_is_silent(runner) -> bool:
	var director = _director(_state([], [], "setup"))
	var hq := _building(1, "usa_command_center", 1, Vector2(3, 3))
	runner.check(director.update(_state([_unit(2, "usa_builder", 1, Vector2(6, 6))], [hq])).is_empty(), "SD19 online start is silent")
	var fresh := _building(3, "usa_power_plant", 1, Vector2(9, 9), {"completed": false})
	runner.check(_cues(director.update(_state([], [hq, fresh]))) == ["placement"], "SD19 a later foundation is heard")
	return true

func test_stalled_tick_is_silent(runner) -> bool:
	var state := _state([_unit(1, "usa_tank", 1, Vector2(5, 5)), _unit(3, "usa_tank", 2, Vector2(6, 6))])
	var director = _director(state)
	_feed(director, 20, [_shot(20, 1, 3)])
	_feed(director, 20, [_shot(20, 1, 3)])
	runner.check(_cues(director.update(state)) == ["cannon", "impact"], "SD20 one request per event")
	runner.check(director.update(state).is_empty(), "SD20 second update is silent")
	return true

func test_first_shot_after_restart_is_heard(runner) -> bool:
	var state := _state([_unit(1, "usa_tank", 1, Vector2(5, 5)), _unit(3, "usa_tank", 2, Vector2(6, 6))])
	var director = _director(state)
	_feed(director, 300, [_shot(300, 1, 3)])
	director.update(state)
	director.reset()
	runner.check(director.update(state).is_empty(), "SD21 storing update is silent")
	_feed(director, 1, [_shot(1, 1, 3)])
	runner.check(_cues(director.update(state)).has("cannon"), "SD21 first shot after restart is heard")
	return true

func test_update_drains_pending(runner) -> bool:
	var state := _state([_unit(1, "usa_tank", 1, Vector2(5, 5))])
	var director = _director(state)
	for tick in 200: _feed(director, tick + 1, [])
	runner.check(director.collected_ticks().size() <= Director.MAX_PENDING, "SD1b pending steps are bounded, got %d" % director.collected_ticks().size())
	director.update(state)
	runner.check(director.collected_ticks().is_empty() and director.consumed_ticks().size() <= Director.MAX_CONSUMED, "SD1b update drains pending, consumed bounded")
	return true

func test_scenes_boot_with_sound(runner) -> bool:
	var skirmish = SkirmishScene.instantiate()
	runner.root.add_child(skirmish)
	await runner.process_frame
	await runner.process_frame
	runner.check(skirmish.get_node_or_null("Sound") != null, "SD22 skirmish has a Sound child")
	runner.check(skirmish.get_children().any(func(c: Node) -> bool: return c.get_script() == Music), "SD22 skirmish has a Music player")
	skirmish.free()
	var suite = OnlineTests.new()
	var online: Dictionary = await suite._online(runner, 1)
	await runner.process_frame
	runner.check(online.main.get_node_or_null("Sound") != null, "SD22 online has a Sound child")
	online.main.free()
	for path in ["res://scenes/main.tscn", "res://scenes/base.tscn"]:
		var scene = load(path).instantiate()
		runner.root.add_child(scene)
		await runner.process_frame
		await runner.process_frame
		runner.check(scene.get_node_or_null("Sound") == null, "SD22 %s has no Sound child" % path)
		scene.free()
	return true

func test_bus_layout(runner) -> bool:
	AudioSettings.apply(AudioSettings.DEFAULTS)
	for bus in ["Music", "Effects", "Voice"]:
		var index: int = AudioServer.get_bus_index(bus)
		runner.check(index > 0 and is_zero_approx(AudioServer.get_bus_volume_db(index) - (-6.0 if bus == "Effects" else 0.0)) and AudioServer.get_bus_send(index) == &"Master", "SD23 bus %s at its trim level sending to Master" % bus)
	return true
