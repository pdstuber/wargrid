@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/combat_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Horde = preload("res://scripts/simulation/horde.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")

func cases() -> Array[Callable]:
	return [test_horde_needs_five, test_horde_infantry_mix_counts, test_horde_vehicle_exact_kind, test_horde_rub_off, test_horde_cadence, test_horde_allies_only, test_horde_change_restarts_delay, test_horde_spread_all_checked, test_horde_step_matches_oracle]

func _world() -> RefCounted:
	var sim = Fixture.world()
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	return sim

# Spawns on distinct cells (spawn refuses shared cells), then packs the units into a ring around the centre.
func _cluster(sim, kinds: Array, centre: Vector2, owner: int = 1, ring: float = 0.3) -> Array[int]:
	var ids: Array[int] = []
	for i in kinds.size():
		var id: int = sim.spawn(owner, Vector2(2.5 + i, 2.5 + owner * 3), kinds[i])
		sim._entities[id].position = [centre.x + ring * cos(i * TAU / kinds.size()), centre.y + ring * sin(i * TAU / kinds.size())]
		ids.append(id)
	return ids

func _run(sim, ticks: int) -> void:
	for i in range(ticks): sim.step()

func _levels(sim, ids: Array[int]) -> Array:
	return ids.map(func(id: int) -> int: return sim._entities[id].combat.horde)

func _weapon(sim, id: int) -> Dictionary:
	return CombatDefinitions.weapon(CombatDefinitions.profile(sim._entities[id].kind).weapon)

func _militia(count: int) -> Array:
	var kinds: Array = []
	kinds.resize(count)
	kinds.fill("china_rifle_infantry")
	return kinds

func test_horde_needs_five(runner) -> bool:
	var four = _world()
	var few: Array[int] = _cluster(four, _militia(4), Vector2(10.5, 10.5))
	_run(four, 32)
	runner.check(_levels(four, few) == [0, 0, 0, 0], "H1 four militia in a cluster have no bonus")
	var five = _world()
	var ids: Array[int] = _cluster(five, _militia(5), Vector2(10.5, 10.5))
	_run(five, 32)
	runner.check(_levels(five, ids) == [2, 2, 2, 2, 2], "H1 a fifth gives all five the true bonus")
	var combat: Dictionary = five._entities[ids[0]].combat
	var weapon: Dictionary = _weapon(five, ids[0])
	runner.check(weapon.delay_ticks == 30 and Combat.bonus_delay(combat, weapon, weapon.delay_ticks) == 20, "H1 delay 30 becomes floor(30 / 1.5) = 20")
	runner.check(Combat.bonus_delay(four._entities[few[0]].combat, weapon, 30) == 30, "H1 no horde keeps the delay")
	return true

func test_horde_infantry_mix_counts(runner) -> bool:
	var sim = _world()
	var ids: Array[int] = _cluster(sim, ["china_rifle_infantry", "china_rifle_infantry", "china_rifle_infantry", "china_rocket_infantry", "china_rocket_infantry"], Vector2(10.5, 10.5))
	_run(sim, 32)
	runner.check(_levels(sim, ids) == [2, 2, 2, 2, 2], "H2 militia and anti-tank troopers count together")
	var other = _world()
	var four: Array[int] = _cluster(other, _militia(4) + ["usa_rifle_infantry"], Vector2(10.5, 10.5))
	_run(other, 32)
	runner.check(_levels(other, four.slice(0, 4)) == [0, 0, 0, 0] and not other._entities[four[4]].combat.has("horde"), "H2 a USA rifleman does not count and has no horde state")
	return true

func test_horde_vehicle_exact_kind(runner) -> bool:
	var mixed = _world()
	Registry.add_test_kind("test_horde_vehicle", Registry.kind("china_light_vehicle").duplicate(true))
	var ids: Array[int] = _cluster(mixed, ["china_light_vehicle", "china_light_vehicle", "china_light_vehicle", "china_light_vehicle", "test_horde_vehicle"], Vector2(10.5, 10.5), 1, 1.0)
	_run(mixed, 32)
	Registry.clear_test_kinds()
	runner.check(_levels(mixed, ids.slice(0, 4)) == [0, 0, 0, 0], "H3 four medium tanks and a same-class, same-rule vehicle of another kind stay at 0")
	var same = _world()
	var tanks: Array[int] = _cluster(same, ["china_light_vehicle", "china_light_vehicle", "china_light_vehicle", "china_light_vehicle", "china_light_vehicle"], Vector2(10.5, 10.5), 1, 1.0)
	_run(same, 32)
	runner.check(_levels(same, tanks) == [2, 2, 2, 2, 2], "H3 five medium tanks within 3.0 reach 2")
	return true

func test_horde_rub_off(runner) -> bool:
	var sim = _world()
	var ids: Array[int] = _cluster(sim, _militia(5), Vector2(10.5, 10.5))
	var sixth: int = sim.spawn(1, Vector2(20.5, 20.5), "china_rifle_infantry")
	sim._entities[sixth].position = [12.5, 10.5]
	_run(sim, 70)
	runner.check(_levels(sim, ids) == [2, 2, 2, 2, 2], "H4 the cluster stays at 2")
	var combat: Dictionary = sim._entities[sixth].combat
	runner.check(combat.horde == 1 and Combat.bonus_delay(combat, _weapon(sim, sixth), 30) == 20, "H4 a sixth touching one true member gets level 1 and the bonus")
	return true

func _first_checks(ticks: int, kind: String) -> Array:
	var sim = _world()
	var ids: Array[int] = _cluster(sim, [kind, kind, kind], Vector2(10.5, 10.5))
	var due: Array = ids.map(func(id: int) -> int: return sim._entities[id].combat.horde_tick)
	var seen: Array = []
	for i in range(ticks):
		var before: Array = ids.map(func(id: int) -> int: return sim._entities[id].combat.horde_tick)
		var tick: int = sim.tick()
		sim.step()
		for n in ids.size():
			if sim._entities[ids[n]].combat.horde_tick != before[n]: seen.append([n, tick, sim._entities[ids[n]].combat.horde_tick])
	return [due, seen]

func test_horde_cadence(runner) -> bool:
	for pair in [["china_rifle_infantry", 30], ["china_light_vehicle", 31]]:
		var run: Array = _first_checks(100, pair[0])
		var due: Array = run[0]
		var first: Dictionary = {}
		var spaced: bool = true
		for entry in run[1]:
			if first.has(entry[0]): spaced = spaced and entry[1] == first[entry[0]].last + pair[1]
			else: first[entry[0]] = {"tick": entry[1], "last": 0}
			first[entry[0]].last = entry[1]
		runner.check(first.size() == 3 and due.all(func(t: int) -> bool: return t >= 1 and t <= pair[1]), "H5 %s first check lies in [1, %d]" % [pair[0], pair[1]])
		runner.check(first.keys().all(func(n: int) -> bool: return first[n].tick == due[n]), "H5 %s first check happens at its drawn tick" % pair[0])
		runner.check(spaced and run[1].all(func(e: Array) -> bool: return e[2] == e[1] + pair[1]), "H5 %s re-checks every %d ticks" % [pair[0], pair[1]])
		runner.check(run == _first_checks(100, pair[0]), "H5 %s two identical runs give identical checks" % pair[0])
	return true

func test_horde_allies_only(runner) -> bool:
	var sim = _world()
	sim.add_player(3, 0, "human", 1)
	var ids: Array[int] = _cluster(sim, _militia(3), Vector2(10.5, 10.5))
	var ally: Array[int] = _cluster(sim, _militia(2), Vector2(10.5, 10.5), 3)
	_run(sim, 32)
	runner.check(_levels(sim, ids + ally) == [2, 2, 2, 2, 2], "H6 an allied seat's militia count")
	var hostile = _world()
	var mine: Array[int] = _cluster(hostile, _militia(3), Vector2(10.5, 10.5))
	var foes: Array[int] = _cluster(hostile, _militia(2), Vector2(10.5, 10.5), 2)
	_run(hostile, 32)
	runner.check(_levels(hostile, mine + foes) == [0, 0, 0, 0, 0], "H6 an enemy's militia do not count")
	var carried = _world()
	var car: int = carried.spawn(1, Vector2(20.5, 20.5), "usa_light_vehicle")
	var group: Array[int] = _cluster(carried, _militia(5), Vector2(10.5, 10.5))
	carried._entities[group[0]].container_id = car
	_run(carried, 100)
	runner.check(_levels(carried, group.slice(1)) == [0, 0, 0, 0], "H6 a contained unit does not count")
	runner.check(carried._entities[group[0]].combat.horde == 0, "H6 a contained unit is not checked")
	return true

func test_horde_change_restarts_delay(runner) -> bool:
	var sim = _world()
	var ids: Array[int] = _cluster(sim, _militia(5), Vector2(10.5, 10.5))
	var target: int = sim.spawn(2, Vector2(14.5, 10.5), "usa_builder")
	sim._entities[target].hp = 100000000
	sim._entities[target].max_hp = 100000000
	_run(sim, 40)
	runner.check(_levels(sim, ids) == [2, 2, 2, 2, 2] and ids.all(func(id: int) -> bool: return sim._entities[id].combat.target_id == target), "H7 a horde of five engages the target")
	sim.remove_object(ids[0])
	var survivors: Array[int] = ids.slice(1)
	var restarts: int = 0
	var wrong: int = 0
	for i in range(100):
		var tick: int = sim.tick()
		var before: Dictionary = {}
		for id in survivors: before[id] = [sim._entities[id].combat.horde > 0, sim._entities[id].combat.next_fire_tick > tick]
		sim.step()
		for id in survivors:
			var combat: Dictionary = sim._entities[id].combat
			if before[id][0] and combat.horde == 0 and before[id][1]:
				restarts += 1
				if combat.next_fire_tick != tick + 30: wrong += 1
	runner.check(_levels(sim, survivors) == [0, 0, 0, 0], "H7 the survivors lose the bonus")
	runner.check(restarts > 0 and wrong == 0, "H7 a pending delay restarts at the slow rate from the tick of the change (restarts %d, wrong %d)" % [restarts, wrong])
	return true

func test_horde_spread_all_checked(runner) -> bool:
	var sim = Simulation.new([], Vector2i(100, 100))
	sim.add_player(1, 0)
	var count: int = 0
	for y in range(19):
		for x in range(16):
			var id: int = sim.spawn(1, Vector2(2.5 + 5 * x, 2.5 + 5 * y), "china_rifle_infantry")
			if id > 0: count += 1
	runner.check(count >= 300, "H8 spread layout has 300 militia, got " + str(count))
	var checks: int = 0
	for tick in range(40):
		sim.step()
		checks += sim.horde_checks()
	runner.check(checks >= count, "H8 every militia was checked in 40 ticks")
	return true

const _ORACLE_KINDS: Array[String] = ["china_rifle_infantry", "china_rifle_infantry", "china_rocket_infantry", "china_light_vehicle", "usa_rifle_infantry"]

# Reference copy of the pre-optimisation Horde.step, levels only (no delay restart).
func _oracle_step(sim, armed: Array[int]) -> void:
	var members: Array[Dictionary] = []
	for id in armed:
		if sim._entities.has(id) and sim._entities[id].combat.has("horde"): members.append(sim._entities[id])
	var grid: Dictionary = {}
	var size: float = 0.0
	for unit in members:
		if unit.combat.horde_tick > sim._tick or unit.has("container_id"): continue
		if grid.is_empty():
			size = 0.0
			var widest: float = 0.0
			var largest: float = 0.0
			for m in members:
				widest = maxf(widest, Registry.kind(m.kind).horde.radius)
				largest = maxf(largest, CombatDefinitions.radius(m.kind))
			size = widest + 2.0 * largest
			for m in members:
				var cell := Vector2i(floori(m.position[0] / size), floori(m.position[1] / size))
				if not grid.has(cell): grid[cell] = [] as Array[Dictionary]
				grid[cell].append(m)
		sim._horde_checks += 1
		unit.combat.horde_tick = sim._tick + Horde.rate(unit.kind)
		unit.combat.horde = _oracle_level(sim, unit, grid, size)

func _oracle_level(sim, unit: Dictionary, grid: Dictionary, size: float) -> int:
	var rule: Dictionary = Registry.kind(unit.kind).horde
	var near: int = 0
	var rubbed: bool = false
	var home := Vector2i(floori(unit.position[0] / size), floori(unit.position[1] / size))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for other: Dictionary in grid.get(home + Vector2i(dx, dy), []):
				if other.id == unit.id or other.has("container_id") or Combat.hostile(sim, unit.owner, other.owner): continue
				if rule.match == "kind":
					if other.kind != unit.kind: continue
				elif Registry.kind(other.kind).get("class", "") != Registry.kind(unit.kind).get("class", ""): continue
				var ox: float = other.position[0] - unit.position[0]
				var oy: float = other.position[1] - unit.position[1]
				if Combat._gap_between(ox, oy, CombatDefinitions.radius(unit.kind), CombatDefinitions.radius(other.kind)) > rule.radius: continue
				near += 1
				rubbed = rubbed or other.combat.horde == 2
	if near >= rule.count - 1: return 2
	return 1 if rubbed else 0

func _horde_snapshot(sim, armed: Array[int]) -> Array:
	var out: Array = [sim._horde_checks]
	for id in armed:
		if sim._entities.has(id) and sim._entities[id].combat.has("horde"): out.append([id, sim._entities[id].combat.horde, sim._entities[id].combat.horde_tick])
	return out

func test_horde_step_matches_oracle(runner) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261108
	var mismatches: int = 0
	var checked: int = 0
	var twos: int = 0
	for trial in range(220):
		var sim = Fixture.world()
		for owner in range(1, 5): sim.add_player(owner, 0, "human", [0, 1, 1, 2][owner - 1])
		var count: int = [0, 1, 2, 6, 25, 60][trial % 6]
		var centres: Array[Vector2] = [Vector2(8.5, 8.5), Vector2(11.0, 9.0), Vector2(20.5, 20.5)]
		var ids: Array[int] = []
		for round_n in range(3):
			for i in count:
				if round_n > 0 and rng.randi() % 4 != 0: continue
				var id: int = sim.spawn(1 + rng.randi() % 4, Vector2(1.5 + (ids.size() % 28), 1.5 + floorf(ids.size() / 28.0)), _ORACLE_KINDS[rng.randi() % _ORACLE_KINDS.size()])
				if id <= 0: continue
				var centre: Vector2 = centres[rng.randi() % 3]
				sim._entities[id].position = [centre.x + rng.randf_range(-1.6, 1.6), centre.y + rng.randf_range(-1.6, 1.6)]
				ids.append(id)
			for id in ids.duplicate():
				if sim._entities.has(id) and rng.randi() % 8 == 0 and round_n > 0:
					sim.remove_object(id)
					ids.erase(id)
			var armed: Array[int] = []
			for id in ids:
				if not sim._entities.has(id): continue
				var unit: Dictionary = sim._entities[id]
				if unit.combat.has("horde"):
					unit.combat.horde = rng.randi() % 3
					unit.combat.horde_tick = sim._tick - 1 + rng.randi() % 3
					if rng.randi() % 10 == 0: unit.container_id = 1
				armed.append(id)
			var saved: Array = _horde_snapshot(sim, armed)
			_oracle_step(sim, armed)
			var expected: Array = _horde_snapshot(sim, armed)
			for entry in saved.slice(1):
				sim._entities[entry[0]].combat.horde_tick = entry[2]
				sim._entities[entry[0]].combat.horde = entry[1]
			sim._horde_checks = saved[0]
			Horde.step(sim, armed)
			var actual: Array = _horde_snapshot(sim, armed)
			checked += 1
			twos += expected.slice(1).filter(func(e: Array) -> bool: return e[1] == 2).size()
			if actual != expected: mismatches += 1
			sim._tick += 1
	runner.check(checked == 660 and twos > 200, "H9 oracle states ran with real hordes (states %d, level-2 units %d)" % [checked, twos])
	runner.check(mismatches == 0, "H9 Horde.step levels, due ticks and check count equal the reference in all states (mismatches %d)" % mismatches)
	return true
