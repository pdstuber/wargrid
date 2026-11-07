@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/combat_fixture.gd")
const EconomyFixture = preload("res://tests/economy_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")

func cases() -> Array[Callable]:
	return [test_weapon_tiers_share_range, test_crate_drop_rules, test_killer_is_first_lethal_shot, test_crate_expires, test_weapon_salvager_tiers, test_money_salvagers, test_salvage_same_tick_cases, test_pickup_splash_vs_infantry, test_crate_drops_when_killer_dies_same_volley]

func _world() -> RefCounted:
	var sim = Fixture.world()
	sim.add_player(1, 1000)
	sim.add_player(2, 1000)
	return sim

func _crates(sim) -> Array:
	return sim.snapshot().get("crates", [])

func _credits(sim, player: int) -> int:
	return sim.snapshot().players.filter(func(p: Dictionary) -> bool: return p.id == player)[0].credits

func _quiet(sim, id: int) -> void:
	sim._entities[id].combat = null

func _attack(sim, ids: Array, target: int) -> void:
	Fixture.send(sim, {"type": "attack", "entity_ids": ids, "target_id": target})

func _shots(sim, attacker: int) -> Array:
	return sim.snapshot().combat_events.filter(func(e: Dictionary) -> bool: return e.type == "shot" and e.attacker_id == attacker)

# Runs until the victim is gone; returns the crates left.
func _kill(killers: Array, victim_kind: String, victim_hp: int = 1) -> Array:
	var sim = _world()
	var ids: Array = []
	for index in killers.size():
		ids.append(sim.spawn(1, Vector2(10.5 + index, 10.5), killers[index]))
	var victim: int = sim.spawn(2, Vector2(10.5, 13.5), victim_kind)
	_quiet(sim, victim)
	sim._entities[victim].hp = victim_hp
	_attack(sim, ids, victim)
	for tick in range(40):
		sim.step()
		if not sim._entities.has(victim): break
	return [sim, victim, _crates(sim)]

func test_weapon_tiers_share_range(runner) -> bool:
	var tiered: Array = Registry.units().filter(func(kind: String) -> bool: return Registry.kind(kind).has("weapon_tiers"))
	runner.check(tiered.size() == 2, "Sv1 two kinds have weapon tiers")
	for kind: String in tiered:
		var row: Dictionary = Registry.kind(kind)
		var weapons: Array = row.weapon_tiers.map(func(name: String) -> Dictionary: return CombatDefinitions.weapon(name))
		runner.check(row.weapon_tiers[0] == row.weapon, "Sv1 %s tier 0 is its weapon" % kind)
		runner.check(weapons.all(func(w: Dictionary) -> bool: return w.range == weapons[0].range), "Sv1 %s tiers share one range" % kind)
	return true

func test_crate_drop_rules(runner) -> bool:
	var run: Array = _kill(["frc_rifle_infantry"], "usa_light_vehicle")
	runner.check(run[2].size() == 1 and run[2][0].cell == [10, 13], "Sv2 an insurgent's kill drops one crate at the wreck's cell, got " + str(run[2]))
	var deaths: Array = run[0].snapshot().combat_events.filter(func(e: Dictionary) -> bool: return e.type == "death")
	var life: int = run[2][0].until - deaths[0].tick if not run[2].is_empty() and not deaths.is_empty() else 0
	runner.check(life >= 900 and life <= 1050, "Sv2 the crate lives 900 to 1050 ticks, got %d" % life)
	runner.check(_kill(["usa_rifle_infantry"], "usa_light_vehicle")[2].is_empty(), "Sv2 a non-salvager's kill drops none")
	runner.check(_kill(["frc_rifle_infantry"], "usa_rifle_infantry")[2].is_empty(), "Sv2 infantry victims drop none")
	var sim = _world()
	var shooter: int = sim.spawn(1, Vector2(10.5, 10.5), "frc_rifle_infantry")
	var barracks: int = EconomyFixture.add_completed(sim, 2, "usa_barracks", Vector2i(10, 13))
	sim._buildings[barracks].hp = 1
	_attack(sim, [shooter], barracks)
	for tick in range(40): sim.step()
	runner.check(not sim._buildings.has(barracks) and _crates(sim).is_empty(), "Sv2 building victims drop none")
	for hostile in [true, false]:
		var splash = _world()
		splash.add_player(3, 0, "human", 1)
		var pickup: int = splash.spawn(1, Vector2(10.5, 10.5), "frc_light_vehicle")
		splash._entities[pickup].combat.tier = 1
		var target: int = splash.spawn(2, Vector2(10.5, 15.5), "usa_tank")
		_quiet(splash, target)
		var casualty: int = splash.spawn(2 if hostile else 3, Vector2(10.5, 17.0), "usa_light_vehicle")
		_quiet(splash, casualty)
		splash._entities[casualty].hp = 1
		_attack(splash, [pickup], target)
		for tick in range(5): splash.step()
		runner.check(not splash._entities.has(casualty) and _crates(splash).size() == (1 if hostile else 0), "Sv2 a splash kill drops a crate only when the victim is hostile (hostile %s)" % hostile)
	return true

func test_killer_is_first_lethal_shot(runner) -> bool:
	var rifle_first: Array = _kill(["usa_rifle_infantry", "frc_rifle_infantry"], "usa_light_vehicle", 2000)
	runner.check(rifle_first[2].is_empty(), "Sv3 the first shot kills, from a non-salvager: no crate")
	var salvager_first: Array = _kill(["frc_rifle_infantry", "usa_rifle_infantry"], "usa_light_vehicle", 2000)
	runner.check(salvager_first[2].size() == 1, "Sv3 the first shot kills, from a salvager: a crate")
	var second_lethal: Array = _kill(["usa_rifle_infantry", "frc_rifle_infantry"], "usa_light_vehicle", 4000)
	runner.check(second_lethal[2].size() == 1, "Sv3 the second shot reaches the HP: the salvager is the killer")
	var other: Array = _kill(["frc_rifle_infantry", "usa_rifle_infantry"], "usa_light_vehicle", 4000)
	runner.check(other[2].is_empty(), "Sv3 reversed, the non-salvager's second shot kills: no crate")
	return true

func test_crate_expires(runner) -> bool:
	var sim = _world()
	sim._crates.append({"cell": [5, 5], "until": 3})
	for tick in range(3):
		sim.step()
		runner.check(_crates(sim).size() == 1, "Sv4 crate present before its tick (step %d)" % tick)
	sim.step()
	runner.check(_crates(sim).is_empty() and not sim.snapshot().has("crates"), "Sv4 crate gone at until, key erased")
	return true

func _crate_at(sim, unit: int) -> void:
	var at: Array = sim._entities[unit].position
	sim._crates.append({"cell": [floori(at[0]), floori(at[1])], "until": sim.tick() + 500})

func _tier_run(runner, kind: String, expected: Array, label: String) -> void:
	var sim = _world()
	var salvager: int = sim.spawn(1, Vector2(10.5, 10.5), kind)
	var target: int = sim.spawn(2, Vector2(10.5, 15.5), "usa_rifle_infantry")
	_quiet(sim, target)
	sim._entities[target].hp = 100000000
	_attack(sim, [salvager], target)
	for step in expected.size():
		_crate_at(sim, salvager)
		sim.step()
		runner.check(sim._entities[salvager].combat.tier == mini(step + 1, 2) and _crates(sim).is_empty(), "%s crate %d: tier %d, crate consumed" % [label, step + 1, mini(step + 1, 2)])
		sim._entities[salvager].combat.next_fire_tick = 0
		sim._entities[target].hp = 100000000
		sim.step()
		var shot: Array = _shots(sim, salvager)
		runner.check(shot.size() == 1 and shot[0].target_id == target and shot[0].damage == expected[step], "%s after crate %d the shot deals %d, got %s" % [label, step + 1, expected[step], str(shot.map(func(s: Dictionary) -> int: return s.damage))])

func test_weapon_salvager_tiers(runner) -> bool:
	var sim = _world()
	var pickup: int = sim.spawn(1, Vector2(10.5, 10.5), "frc_light_vehicle")
	var before: int = _credits(sim, 1)
	runner.check(sim._entities[pickup].combat.tier == 0, "Sv5 a pickup starts on tier 0")
	sim._entities[pickup].combat.next_fire_tick = 777
	for expected in [1, 2, 2]:
		_crate_at(sim, pickup)
		sim.step()
		runner.check(sim._entities[pickup].combat.tier == expected and sim._entities[pickup].combat.next_fire_tick == 777, "Sv5 pickup tier %d, next_fire_tick unchanged" % expected)
	var paid: int = _credits(sim, 1) - before
	runner.check(paid >= 25 and paid <= 75, "Sv5 the third crate pays 25-75, got %d" % paid)
	var tank = _world()
	var light: int = tank.spawn(1, Vector2(10.5, 10.5), "frc_tank")
	var money: int = _credits(tank, 1)
	for expected in [1, 2, 2]:
		_crate_at(tank, light)
		tank.step()
		runner.check(tank._entities[light].combat.tier == expected, "Sv5 light tank tier %d" % expected)
	runner.check(_credits(tank, 1) - money >= 25 and _credits(tank, 1) - money <= 75, "Sv5 the light tank's third crate pays")
	var cannon = _world()
	var gun: int = cannon.spawn(1, Vector2(10.5, 10.5), "frc_light_vehicle")
	var victim: int = cannon.spawn(2, Vector2(10.5, 15.5), "usa_rifle_infantry")
	_quiet(cannon, victim)
	cannon._entities[victim].hp = 100000000
	cannon._entities[gun].combat.tier = 1
	_attack(cannon, [gun], victim)
	var ticks: Array = []
	for tick in range(70):
		cannon.step()
		for shot in _shots(cannon, gun):
			if shot.damage == 45000: ticks.append(shot.tick)
	runner.check(ticks.size() >= 2 and ticks[1] - ticks[0] == 30, "Sv5 tier 1 fires the cannon, 45000 every 30 ticks, got " + str(ticks))
	_tier_run(runner, "frc_light_vehicle", [45000, 50000, 50000], "Sv5 pickup")
	_tier_run(runner, "frc_tank", [2500, 2500, 2500], "Sv5 light tank")
	return true

func test_money_salvagers(runner) -> bool:
	var sim = _world()
	var insurgent: int = sim.spawn(1, Vector2(5.5, 5.5), "frc_rifle_infantry")
	var laborer: int = sim.spawn(1, Vector2(15.5, 15.5), "frc_builder")
	var usa: int = sim.spawn(1, Vector2(20.5, 20.5), "usa_rifle_infantry")
	_crate_at(sim, insurgent)
	_crate_at(sim, laborer)
	_crate_at(sim, usa)
	var before: int = _credits(sim, 1)
	sim.step()
	var paid: int = _credits(sim, 1) - before
	runner.check(paid >= 50 and paid <= 150, "Sv6 the insurgent and the laborer each took 25-75, got %d" % paid)
	runner.check(_crates(sim).size() == 1 and _crates(sim)[0].cell == [20, 20], "Sv6 a USA unit takes nothing: its crate stays")
	var reach = _world()
	var near: int = reach.spawn(1, Vector2(10.5, 11.7), "frc_rifle_infantry")
	reach._crates.append({"cell": [10, 10], "until": 500})
	reach.step()
	runner.check(_crates(reach).size() == 1, "Sv6 a salvager outside crate reach takes nothing")
	reach._entities[near].position = [10.5, 11.5]
	reach.step()
	runner.check(_crates(reach).is_empty(), "Sv6 inside reach it collects")
	var pair = _world()
	var low: int = pair.spawn(2, Vector2(10.5, 9.5), "frc_rifle_infantry")
	_quiet(pair, low)
	_quiet(pair, pair.spawn(1, Vector2(10.5, 11.5), "frc_rifle_infantry"))
	pair._crates.append({"cell": [10, 10], "until": 500})
	var one: int = _credits(pair, 1)
	var two: int = _credits(pair, 2)
	pair.step()
	runner.check(low == 1 and _credits(pair, 1) == one and _credits(pair, 2) - two >= 25 and _crates(pair).is_empty(), "Sv6 two in reach: the lowest id, even a hostile seat, takes it")
	var car = _world()
	var carrier: int = car.spawn(1, Vector2(10.5, 10.5), "usa_light_vehicle")
	var rider: int = car.spawn(1, Vector2(10.5, 12.0), "frc_rifle_infantry")
	Fixture.send(car, {"type": "enter", "entity_ids": [rider], "target_id": carrier})
	car.step()
	var seated: int = _credits(car, 1)
	car._crates.append({"cell": [10, 10], "until": 500})
	car.step()
	runner.check(car._entities[rider].has("container_id") and _credits(car, 1) == seated and _crates(car).size() == 1, "Sv6 a passenger takes nothing")
	return true

func test_salvage_same_tick_cases(runner) -> bool:
	var boards = _world()
	var carrier: int = boards.spawn(1, Vector2(10.5, 10.5), "usa_light_vehicle")
	var rider: int = boards.spawn(1, Vector2(10.5, 11.5), "frc_rifle_infantry")
	boards._crates.append({"cell": [10, 10], "until": 500})
	var cash: int = _credits(boards, 1)
	Fixture.send(boards, {"type": "enter", "entity_ids": [rider], "target_id": carrier})
	boards.step()
	runner.check(boards._entities[rider].has("container_id") and _credits(boards, 1) == cash and _crates(boards).size() == 1, "Sv7 boarding runs before the pickup: no crate taken")
	var expiry = _world()
	expiry.spawn(1, Vector2(10.5, 10.5), "frc_rifle_infantry")
	expiry._crates.append({"cell": [10, 10], "until": expiry.tick()})
	var purse: int = _credits(expiry, 1)
	expiry.step()
	runner.check(_credits(expiry, 1) == purse and _crates(expiry).is_empty(), "Sv7 expiry and pickup on one tick: the crate expires first")
	var killed = _world()
	var doomed: int = killed.spawn(1, Vector2(10.5, 10.5), "frc_rifle_infantry")
	killed._entities[doomed].hp = 1
	var shooter: int = killed.spawn(2, Vector2(10.5, 13.0), "usa_rifle_infantry")
	killed._crates.append({"cell": [10, 10], "until": 500})
	var pay: int = _credits(killed, 1)
	_attack(killed, [shooter], doomed)
	killed.step()
	runner.check(not killed._entities.has(doomed) and _credits(killed, 1) > pay, "Sv7 a salvager killed on its pickup tick still collects (pickup runs first)")
	return true

func test_pickup_splash_vs_infantry(runner) -> bool:
	var cannon = _world()
	var gun: int = cannon.spawn(1, Vector2(10.5, 10.5), "frc_light_vehicle")
	cannon._entities[gun].combat.tier = 1
	var target: int = cannon.spawn(2, Vector2(10.5, 15.5), "usa_rifle_infantry")
	var near: int = cannon.spawn(2, Vector2(10.5, 17.0), "usa_rifle_infantry")
	var far: int = cannon.spawn(2, Vector2(10.5, 19.0), "usa_rifle_infantry")
	for id in [target, near, far]: _quiet(cannon, id)
	_attack(cannon, [gun], target)
	var hit: int = 0
	for shot_index in range(8):
		for id in [target, near, far]: cannon._entities[id].hp = 120000
		cannon._entities[gun].combat.next_fire_tick = 0
		cannon.step()
		hit += _shots(cannon, gun).filter(func(s: Dictionary) -> bool: return s.target_id == near and s.splash).size()
	runner.check(hit == 8, "Sv8 the cannon reaches an infantry neighbour 1.5 cells away on every shell, got %d of 8" % hit)
	var rocket = _world()
	var launcher: int = rocket.spawn(1, Vector2(10.5, 10.5), "frc_light_vehicle")
	rocket._entities[launcher].combat.tier = 2
	var aim: int = rocket.spawn(2, Vector2(10.5, 15.5), "usa_rifle_infantry")
	var beside: int = rocket.spawn(2, Vector2(10.5, 16.2), "usa_rifle_infantry")
	var apart: int = rocket.spawn(2, Vector2(10.5, 17.0), "usa_rifle_infantry")
	for id in [aim, beside, apart]: _quiet(rocket, id)
	_attack(rocket, [launcher], aim)
	var seed_before: int = rocket.snapshot().rng
	rocket.step()
	var shots: Array = _shots(rocket, launcher)
	runner.check(shots.size() == 2 and shots.any(func(s: Dictionary) -> bool: return s.target_id == beside and s.splash) and not shots.any(func(s: Dictionary) -> bool: return s.target_id == apart), "Sv8 the rocket lands on the target's centre: the near neighbour is hit, the far one is not")
	runner.check(rocket.snapshot().rng == seed_before, "Sv8 the rocket draws no random number against infantry")
	return true

func test_crate_drops_when_killer_dies_same_volley(runner) -> bool:
	var sim = _world()
	var pickup: int = sim.spawn(1, Vector2(10.5, 10.5), "frc_light_vehicle")
	var foe: int = sim.spawn(2, Vector2(10.5, 13.5), "usa_light_vehicle")
	for id: int in [pickup, foe]: sim._entities[id].hp = 1
	_attack(sim, [pickup], foe)
	_attack(sim, [foe], pickup)
	for tick in range(40):
		sim.step()
		if not sim._entities.has(foe): break
	runner.check(not sim._entities.has(pickup) and not sim._entities.has(foe), "Sv9 both vehicles died on one tick")
	runner.check(_crates(sim).size() == 1, "Sv9 the lower-id killer died with its victim and the crate still drops: %s" % [_crates(sim)])
	return true
