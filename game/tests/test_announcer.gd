@warning_ignore_start("untyped_declaration")
extends RefCounted

const Announcer = preload("res://scripts/presentation/announcer.gd")
const Director = preload("res://scripts/presentation/sound_director.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const SkirmishScene = preload("res://scenes/skirmish.tscn")

func cases() -> Array[Callable]:
	return [test_second_base_attack_within_30s_is_silent, test_building_lost_cooldown_30s, test_low_power_cooldown_120s, test_insufficient_funds_has_no_cooldown, test_line_expires_after_5s, test_one_line_at_a_time_by_priority, test_waiting_line_not_queued_twice, test_triggers_from_snapshots, test_unit_ready_not_fired_by_spawns, test_rubble_is_not_base, test_unit_attack_is_not_base_attack, test_frc_never_low_power, test_announcer_follows_local_seat, test_match_end_lines, test_online_start_says_nothing, test_restart_starts_silent]

func _starts(announcer, line: String, tick: int) -> bool:
	announcer.request(line, tick)
	return announcer.next(tick, false) == line

func test_second_base_attack_within_30s_is_silent(runner) -> bool:
	var announcer = Announcer.new()
	runner.check(_starts(announcer, "base_under_attack", 100), "AN1 first base attack starts")
	runner.check(not _starts(announcer, "base_under_attack", 999), "AN1 second base attack within 900 ticks started")
	runner.check(_starts(announcer, "base_under_attack", 1000), "AN1 base attack 900 ticks after the start is heard")
	return true

func test_building_lost_cooldown_30s(runner) -> bool:
	var announcer = Announcer.new()
	runner.check(_starts(announcer, "building_lost", 0), "AN2 first building_lost starts")
	runner.check(not _starts(announcer, "building_lost", 899), "AN2 building_lost at 899 ticks dropped")
	runner.check(_starts(announcer, "building_lost", 900), "AN2 building_lost at 900 ticks starts")
	return true

func test_low_power_cooldown_120s(runner) -> bool:
	var announcer = Announcer.new()
	runner.check(_starts(announcer, "low_power", 0), "AN3 first low_power starts")
	runner.check(not _starts(announcer, "low_power", 3599), "AN3 low_power at 3599 ticks dropped")
	runner.check(_starts(announcer, "low_power", 3600), "AN3 low_power at 3600 ticks starts")
	return true

func test_insufficient_funds_has_no_cooldown(runner) -> bool:
	var announcer = Announcer.new()
	runner.check(_starts(announcer, "insufficient_funds", 0) and _starts(announcer, "insufficient_funds", 1), "AN4 insufficient_funds repeats at once")
	return true

func test_line_expires_after_5s(runner) -> bool:
	var announcer = Announcer.new()
	announcer.request("unit_ready", 0)
	runner.check(announcer.next(151, false) == "", "AN5 line requested at tick 0 expired at tick 151")
	announcer.request("unit_ready", 0)
	runner.check(announcer.next(150, false) == "unit_ready", "AN5 line still starts at tick 150")
	return true

func test_one_line_at_a_time_by_priority(runner) -> bool:
	var announcer = Announcer.new()
	for line in ["low_power", "insufficient_funds", "base_under_attack", "building_lost"]: announcer.request(line, 10)
	runner.check(announcer.next(10, true) == "", "AN6 nothing starts while busy")
	var order: Array = []
	for i in 4: order.append(announcer.next(10, false))
	runner.check(order == ["building_lost", "base_under_attack", "insufficient_funds", "low_power"], "AN6 order was %s" % [order])
	return true

func test_waiting_line_not_queued_twice(runner) -> bool:
	var announcer = Announcer.new()
	announcer.request("unit_ready", 0)
	announcer.request("unit_ready", 5)
	runner.check(announcer.next(5, false) == "unit_ready" and announcer.next(5, false) == "", "AN7 a waiting line is queued once")
	return true

func _unit(id: int, kind: String, owner: int) -> Dictionary:
	return {"id": id, "owner": owner, "kind": kind, "position": [5.0, 5.0], "combat": {"tier": 0}}

func _building(id: int, kind: String, owner: int, extra: Dictionary = {}) -> Dictionary:
	var row := {"id": id, "owner": owner, "kind": kind, "origin": [3.0, 3.0], "completed": true, "queue": []}
	row.merge(extra, true)
	return row

func _state(tick: int, entities: Array, buildings: Array, extra: Dictionary = {}) -> Dictionary:
	var row := {"tick": tick, "entities": entities, "buildings": buildings, "players": [_player(1, 1), _player(2, 2)], "match": {"status": "ongoing", "winner": null}}
	row.merge(extra, true)
	return row

func _player(id: int, team: int, supply: int = 0, demand: int = 0) -> Dictionary:
	return {"id": id, "team": team, "power_supply": supply, "power_demand": demand}

func _typed(items: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for item: Dictionary in items: typed.append(item)
	return typed

func _director(state: Dictionary, local: int = 1):
	var director = Director.new(local)
	director.update(state)
	return director

func _lines(director, tick: int) -> Array:
	var lines: Array = []
	for i in 12:
		var line: String = director.announcer.next(tick, false)
		if line.is_empty(): break
		lines.append(line)
	return lines

func _step(director, tick: int, events: Array, results: Array = []) -> void:
	director.collect_step(tick, _typed(events), _typed(results))

func _hit(tick: int, attacker: int, target: int, splash: bool = false) -> Dictionary:
	return {"type": "shot", "tick": tick, "attacker_id": attacker, "target_id": target, "damage": 1, "splash": splash}

func test_triggers_from_snapshots(runner) -> bool:
	var site := _building(7, "usa_barracks", 1, {"completed": false})
	var director = _director(_state(1, [], [site]))
	director.update(_state(2, [], [_building(7, "usa_barracks", 1)]))
	runner.check(_lines(director, 2) == ["construction_complete"], "AN8 completing own building gives construction_complete")
	var producer := _building(8, "usa_barracks", 1, {"queue": [{"id": 1, "kind": "usa_rifle_infantry", "work": 0}]})
	director = _director(_state(1, [], [producer]))
	director.update(_state(2, [_unit(30, "usa_rifle_infantry", 1)], [_building(8, "usa_barracks", 1)]))
	runner.check(_lines(director, 2) == ["unit_ready"], "AN8 finished queue head gives unit_ready")
	director = _director(_state(1, [], []))
	director.update(_state(2, [], [], {"players": [_player(1, 1, 1, 3), _player(2, 2)]}))
	director.update(_state(3, [], [], {"players": [_player(1, 1, 1, 4), _player(2, 2)]}))
	runner.check(_lines(director, 3) == ["low_power"], "AN8 power demand over supply says low_power once")
	director = _director(_state(1, [], []))
	director.update(_state(2, [], [], {"match": {"status": "won", "winner": 1}}))
	runner.check(_lines(director, 2) == ["victory"], "AN8 won with own team gives victory")
	director = _director(_state(1, [], []))
	director.update(_state(2, [], [], {"match": {"status": "won", "winner": 2}}))
	runner.check(_lines(director, 2) == ["defeat"], "AN8 won by the other team gives defeat")
	director = _director(_state(1, [], [_building(7, "usa_factory", 1)]))
	_step(director, 2, [{"type": "death", "tick": 2, "object_id": 7}])
	director.update(_state(2, [], []))
	runner.check(_lines(director, 2) == ["building_lost"], "AN8 own destroyed building gives building_lost")
	return true

func test_unit_ready_not_fired_by_spawns(runner) -> bool:
	var supply := _building(4, "usa_supply_center", 1, {"completed": false})
	var director = _director(_state(1, [], [supply]))
	director.update(_state(2, [_unit(31, "usa_collector", 1)], [_building(4, "usa_supply_center", 1)]))
	runner.check(_lines(director, 2) == ["construction_complete"], "AN9 supply center and its collector give construction_complete only")
	director = _director(_state(1, [], [_building(5, "china_tunnel_hub", 1)]))
	director.update(_state(2, [_unit(32, "china_rocket_infantry", 1), _unit(33, "china_rocket_infantry", 1)], [_building(5, "china_tunnel_hub", 1)]))
	runner.check(_lines(director, 2).is_empty(), "AN9 tunnel hub spawns give no unit_ready")
	director = _director(_state(1, [], [_building(6, "frc_hole_1", 1, {"rebuild": {}})]))
	director.update(_state(2, [_unit(34, "frc_worker", 1)], [_building(6, "frc_hole_1", 1, {"rebuild": {}})]))
	runner.check(_lines(director, 2).is_empty(), "AN9 hole worker gives no unit_ready")
	var queued := _building(8, "usa_barracks", 1, {"queue": [{"id": 1, "kind": "usa_rifle_infantry", "work": 0}]})
	director = _director(_state(1, [], [queued]))
	director.update(_state(2, [], [_building(8, "usa_barracks", 1)]))
	runner.check(_lines(director, 2).is_empty(), "AN9 cancelled queue entry gives no unit_ready")
	return true

func test_rubble_is_not_base(runner) -> bool:
	var hole := _building(5, "frc_hole_2", 1, {"rebuild": {}})
	var site := _building(6, "frc_barracks", 1, {"completed": false, "hole_id": 5})
	var director = _director(_state(1, [_unit(9, "usa_tank", 2)], [hole]))
	_step(director, 2, [_hit(2, 9, 5), {"type": "death", "tick": 2, "object_id": 5}])
	director.update(_state(2, [_unit(9, "usa_tank", 2)], []))
	runner.check(_lines(director, 2).is_empty(), "AN10 shot at and death of an own hole say nothing")
	director = _director(_state(1, [_unit(9, "usa_tank", 2)], [site]))
	_step(director, 2, [_hit(2, 9, 6)])
	director.update(_state(2, [_unit(9, "usa_tank", 2)], [site]))
	runner.check(_lines(director, 2) == ["base_under_attack"], "AN10 shot at an own construction site gives base_under_attack")
	return true

func test_unit_attack_is_not_base_attack(runner) -> bool:
	var state := _state(1, [_unit(1, "usa_tank", 1), _unit(9, "usa_tank", 2)], [])
	var director = _director(state)
	_step(director, 2, [_hit(2, 9, 1)])
	director.update(state)
	runner.check(_lines(director, 2).is_empty(), "AN11 a shot at an own unit says nothing")
	return true

func test_frc_never_low_power(runner) -> bool:
	for kind in Registry.buildings():
		if kind.begins_with("frc_"): runner.check(Definitions.building(kind).power >= 0, "AN12 %s draws no power" % kind)
	var director = _director(_state(1, [], []))
	director.update(_state(2, [], [], {"players": [_player(1, 1, 0, 0), _player(2, 2)]}))
	runner.check(_lines(director, 2).is_empty(), "AN12 zero demand says no low_power")
	return true

func test_announcer_follows_local_seat(runner) -> bool:
	var players := [_player(1, 1), _player(2, 2), _player(3, 2)]
	var state := _state(1, [], [_building(7, "usa_factory", 3), _building(8, "usa_factory", 2)], {"players": players})
	var director = _director(state, 2)
	_step(director, 2, [{"type": "death", "tick": 2, "object_id": 7}])
	director.update(_state(2, [], [_building(8, "usa_factory", 2)], {"players": players}))
	runner.check(_lines(director, 2).is_empty(), "AN13 an ally's lost building says nothing")
	_step(director, 3, [{"type": "death", "tick": 3, "object_id": 8}])
	director.update(_state(3, [], [], {"players": players}))
	runner.check(_lines(director, 3) == ["building_lost"], "AN13 own lost building gives building_lost")
	director.update(_state(4, [], [], {"players": players, "match": {"status": "won", "winner": 2}}))
	runner.check(_lines(director, 4) == ["victory"], "AN13 win by the team of seat 2 gives victory")
	return true

func test_match_end_lines(runner) -> bool:
	var director = _director(_state(1, [], []))
	director.update(_state(2, [], [], {"match": {"status": "draw", "winner": null}}))
	runner.check(_lines(director, 2).is_empty(), "AN14 draw says nothing")
	director = _director(_state(1, [], []))
	director.update(_state(2, [], []))
	runner.check(_lines(director, 2).is_empty(), "AN14 a lockstep end with status ongoing says nothing")
	return true

func test_online_start_says_nothing(runner) -> bool:
	var director = _director(_state(1, [], [], {"match": {"status": "setup", "winner": null}}))
	director.update(_state(2, [_unit(2, "usa_builder", 1)], [_building(1, "usa_command_center", 1)]))
	runner.check(_lines(director, 2).is_empty(), "AN15 setup to ongoing with a builder and an HQ says nothing")
	return true

func test_restart_starts_silent(runner) -> bool:
	var state := _state(1, [], [])
	var director = _director(state)
	director.announcer.request("unit_ready", 1)
	director.reset()
	director.update(state)
	runner.check(_lines(director, 2).is_empty(), "AN16 reset drops queued lines")
	var skirmish = SkirmishScene.instantiate()
	runner.root.add_child(skirmish)
	await runner.process_frame
	await runner.process_frame
	skirmish._restart()
	skirmish._refresh()
	var cues: Array = skirmish._sound.last_requests().map(func(request: Dictionary) -> String: return request.cue)
	runner.check(not cues.has("placement") and not cues.has("unit_ready"), "AN16 restart plus refresh requested %s" % [cues])
	skirmish.free()
	return true
