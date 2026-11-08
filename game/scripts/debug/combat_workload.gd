extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")

static func create(layout: String) -> Simulation:
	assert(layout == "open" or layout == "dense" or layout == "contact" or layout == "skirmish3v3" or layout == "transports" or layout == "defences" or layout == "docks" or layout == "hordes300" or layout == "horde_render" or layout == "ramp" or layout == "frc")
	if layout == "skirmish3v3": return _skirmish3v3()
	if layout == "transports": return _transports()
	if layout == "defences": return _defences()
	if layout == "docks": return _docks()
	if layout == "hordes300": return _hordes300()
	if layout == "horde_render": return _horde_render()
	if layout == "ramp": return _ramp()
	if layout == "frc": return _frc()
	var solids: Array[Vector2i] = []
	if layout == "dense":
		for x: int in [26, 34, 42]:
			for y in range(64):
				if not (y >= 20 and y <= 27 or y >= 44 and y <= 51):
					solids.append(Vector2i(x, y))
	var sim: Simulation = Simulation.new(solids, Vector2i(64, 64))
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	var contact: bool = layout == "contact"
	var columns: int = 3 if contact else 15
	var left_front: int = 31 if contact else 18
	var right_front: int = 33 if contact else 45
	var top: int = 7 if contact else 20
	_block(sim, 1, left_front, -1, columns, top, contact)
	_block(sim, 2, right_front, 1, columns, top, contact)
	if layout != "contact":
		for player: int in [1, 2]:
			var ids: Array[int] = []
			for unit: Dictionary in sim.snapshot().entities:
				if unit.owner == player: ids.append(unit.id)
			var target: Array = [52.5, 24.5] if player == 1 else [11.5, 24.5]
			var result: Dictionary = sim.issue_command({"tick": 0, "player": player, "sequence": 0, "type": "attack_move", "entity_ids": ids, "target": target})
			assert(result.ok, result.error)
	return sim

static func _block(sim: Simulation, player: int, front_x: int, direction: int, columns: int, top: int, interleave: bool) -> void:
	@warning_ignore("integer_division")
	var rows: int = 150 / columns
	var placed: int = 0
	for column in range(columns):
		for row in range(rows):
			var tank: bool = placed % 3 == 0 if interleave else placed < 50
			var id: int = sim.spawn(player, Vector2(front_x + direction * column + 0.5, top + row + 0.5), "usa_tank" if tank else "usa_rifle_infantry")
			assert(id > 0)
			placed += 1

# 20 scout cars with 5 riflemen each march on a block of 100 riflemen; contact comes after the warm-up, so passenger fire lands in the timed window.
static func _transports() -> Simulation:
	var sim: Simulation = Simulation.new([], Vector2i(64, 64))
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	var cars: Array[int] = []
	for index in range(20):
		var car_position := Vector2(3.5, 4.5 + 3 * index)
		var car: int = sim.spawn(1, car_position, "usa_light_vehicle")
		assert(car > 0)
		cars.append(car)
		var riders: Array[int] = []
		for offset: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(0.9, 0.9)]:
			riders.append(sim.spawn(1, car_position + offset, "usa_rifle_infantry"))
		var entered: Dictionary = sim.issue_command({"tick": 0, "player": 1, "sequence": index, "type": "enter", "entity_ids": riders, "target_id": car})
		assert(entered.ok, entered.error)
	for column in range(10):
		for row in range(10):
			var target: int = sim.spawn(2, Vector2(48.5 + column, 19.5 + row), "usa_rifle_infantry")
			assert(target > 0)
	sim.step()
	var marched: Dictionary = sim.issue_command({"tick": sim.tick(), "player": 1, "sequence": 20, "type": "attack_move", "entity_ids": cars, "target": [60.5, 24.5]})
	assert(marched.ok, marched.error)
	return sim

# 12 powered batteries (8 power plants) face 100 riflemen that attack-move in; battery fire lands once they close within range.
static func _defences() -> Simulation:
	var sim: Simulation = Simulation.new([], Vector2i(64, 64))
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	for index in range(8): _building(sim, "usa_power_plant", Vector2i(2, 4 + 4 * index))
	for index in range(12): _building(sim, "usa_defence", Vector2i(10, 4 + 4 * index))
	var attackers: Array[int] = []
	for column in range(10):
		for row in range(10):
			var id: int = sim.spawn(2, Vector2(26.5 + column, 19.5 + row), "usa_rifle_infantry")
			assert(id > 0)
			attackers.append(id)
	var marched: Dictionary = sim.issue_command({"tick": 0, "player": 2, "sequence": 0, "type": "attack_move", "entity_ids": attackers, "target": [4.5, 24.5]})
	assert(marched.ok, marched.error)
	return sim

# 12 supply trucks gather from 2 piles of 400 boxes around one supply center; six per pile, so docks fill and trucks queue; 100 idle riflemen make the per-tick entity scans count.
static func _docks() -> Simulation:
	var sim: Simulation = Simulation.new([], Vector2i(64, 64))
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	_building(sim, "china_supply_center", Vector2i(30, 30))
	var piles: Array[int] = [sim.add_supply_source(Vector2i(18, 30), 400), sim.add_supply_source(Vector2i(42, 30), 400)]
	assert(piles[0] > 0 and piles[1] > 0)
	for index in range(2):
		var trucks: Array[int] = []
		for row in range(6):
			var id: int = sim.spawn(1, Vector2(33.5 + 4 * index, 26.5 + row), "china_collector")
			assert(id > 0)
			trucks.append(id)
		var gathered: Dictionary = sim.issue_command({"tick": 0, "player": 1, "sequence": index, "type": "gather", "entity_ids": trucks, "source_id": piles[index]})
		assert(gathered.ok, gathered.error)
	for index in range(100):
		var idle: int = sim.spawn(2, Vector2(2.5 + index % 10, 2.5 + floorf(index / 10.0)), "china_rifle_infantry")
		assert(idle > 0)
	return sim

# 300 packed militia (20 by 15) attack-move onto 100 riflemen; packed ranks keep five neighbours in reach, so hordes form and re-check.
static func _hordes300() -> Simulation:
	var sim: Simulation = Simulation.new([], Vector2i(64, 64))
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	var army: Array[int] = []
	for column in range(20):
		for row in range(15):
			army.append(sim.spawn(1, Vector2(3.5 + column, 10.5 + row), "china_rifle_infantry"))
	for column in range(10):
		for row in range(10):
			var enemy: int = sim.spawn(2, Vector2(48.5 + column, 19.5 + row), "usa_rifle_infantry")
			assert(enemy > 0)
	assert(army.all(func(id: int) -> bool: return id > 0))
	_attack_move(sim, army, [60.5, 24.5])
	return sim

# Rendered benchmark: 300 packed China units (rifle, rocket, light vehicle, tank rows) attack-move onto 100 riflemen so hordes form on screen.
static func _horde_render() -> Simulation:
	var sim: Simulation = Simulation.new([], Vector2i(64, 64))
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	var kinds: Array[String] = ["china_rifle_infantry", "china_rifle_infantry", "china_rocket_infantry", "china_light_vehicle", "china_tank"]
	var army: Array[int] = []
	for column in range(20):
		for row in range(15):
			army.append(sim.spawn(1, Vector2(3.5 + column, 10.5 + row), kinds[row % kinds.size()]))
	for column in range(10):
		for row in range(10):
			var enemy: int = sim.spawn(2, Vector2(48.5 + column, 19.5 + row), "usa_rifle_infantry")
			assert(enemy > 0)
	assert(army.all(func(id: int) -> bool: return id > 0))
	_attack_move(sim, army, [60.5, 24.5])
	return sim

# 20 rotary gun tanks attack-move and 6 powered towers (2 power plants) hold the line against 100 riflemen, so shots ramp to level 2.
static func _ramp() -> Simulation:
	var sim: Simulation = Simulation.new([], Vector2i(64, 64))
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	for index in range(2): _building(sim, "china_power_plant", Vector2i(2, 4 + 4 * index))
	for index in range(6): _building(sim, "china_defence", Vector2i(10, 16 + 4 * index))
	var army: Array[int] = []
	for column in range(5):
		for row in range(4):
			army.append(sim.spawn(1, Vector2(12.5 + column, 20.5 + row), "china_tank"))
	for column in range(10):
		for row in range(10):
			var target: int = sim.spawn(2, Vector2(30.5 + column, 19.5 + row), "usa_rifle_infantry")
			assert(target > 0)
	assert(army.all(func(id: int) -> bool: return id > 0))
	_attack_move(sim, army, [48.5, 24.5])
	return sim

# Three scripted parts far from a 60 v 60 vehicle battle: ten riflemen board two tunnel hubs and heal, three barracks open holes whose hp regenerates, and a tank kills a builder and collects the crate.
static func _frc() -> Simulation:
	var sim: Simulation = Simulation.new([], Vector2i(64, 64))
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	var army: Array[int] = []
	for column in range(6):
		for row in range(10):
			army.append(sim.spawn(1, Vector2(3.5 + column, 6.5 + row), "frc_light_vehicle" if column < 3 else "frc_tank"))
			var enemy: int = sim.spawn(2, Vector2(28.5 + column, 6.5 + row), "usa_tank" if column < 4 else "usa_light_vehicle")
			assert(enemy > 0)
	assert(army.all(func(id: int) -> bool: return id > 0))
	_attack_move(sim, army, [60.5, 10.5])
	_tunnel_part(sim)
	for x: int in [20, 24, 28]:
		_building(sim, "frc_barracks", Vector2i(x, 40))
		sim.remove_object(sim._next_entity_id - 1)
	for building: Dictionary in sim._buildings.values():
		if building.has("rebuild"): building.hp = 1000
	_salvage_part(sim)
	return sim

static func _tunnel_part(sim: Simulation) -> void:
	_building(sim, "frc_defence", Vector2i(4, 40))
	var hub_a: int = sim._next_entity_id - 1
	_building(sim, "frc_defence", Vector2i(10, 40))
	var hub_b: int = sim._next_entity_id - 1
	var groups: Array = [[hub_a, [Vector2i(3, 39), Vector2i(4, 39), Vector2i(5, 39), Vector2i(3, 41), Vector2i(4, 41)]], [hub_b, [Vector2i(9, 39), Vector2i(10, 39), Vector2i(11, 39), Vector2i(9, 41), Vector2i(10, 41)]]]
	for index in range(2):
		var ids: Array[int] = []
		for cell: Vector2i in groups[index][1]:
			var id: int = sim.spawn(1, Vector2(cell) + Vector2(0.5, 0.5), "frc_rifle_infantry")
			assert(id > 0)
			sim._entities[id].hp = 1000
			ids.append(id)
		var entered: Dictionary = sim.issue_command({"tick": 400, "player": 1, "sequence": 1 + index, "type": "enter", "entity_ids": ids, "target_id": groups[index][0]})
		assert(entered.ok, entered.error)

static func _salvage_part(sim: Simulation) -> void:
	var tank: int = sim.spawn(1, Vector2(10.5, 56.5), "frc_tank")
	var victim: int = sim.spawn(2, Vector2(18.5, 56.5), "usa_builder")
	assert(tank > 0 and victim > 0)
	var attacked: Dictionary = sim.issue_command({"tick": 600, "player": 1, "sequence": 3, "type": "attack", "entity_ids": [tank], "target_id": victim})
	assert(attacked.ok, attacked.error)
	var collected: Dictionary = sim.issue_command({"tick": 1200, "player": 1, "sequence": 4, "type": "move", "entity_ids": [tank], "target": [18.5, 56.5]})
	assert(collected.ok, collected.error)

static func _attack_move(sim: Simulation, army: Array[int], target: Array) -> void:
	var marched: Dictionary = sim.issue_command({"tick": 0, "player": 1, "sequence": 0, "type": "attack_move", "entity_ids": army, "target": target})
	assert(marched.ok, marched.error)

static func _building(sim: Simulation, kind: String, origin: Vector2i) -> void:
	var id: int = sim._next_entity_id
	sim._next_entity_id += 1
	var hp: int = CombatDefinitions.profile(kind).max_hp
	sim._buildings[id] = {"id": id, "owner": 1, "kind": kind, "hp": hp, "max_hp": hp, "origin": [origin.x, origin.y], "completed": true, "work": 0, "paid_cost": 0, "builder_id": null, "approach": null, "queue": [], "active_collector_id": null}
	var combat: Variant = CombatDefinitions.initial_combat(kind)
	if combat != null: sim._buildings[id].combat = combat
	sim._replace_union(sim._union_cells())

# Three staggered lanes, 35 units per owner per lane (12 tanks); the last 9 of each group stay idle behind.
static func _skirmish3v3() -> Simulation:
	var sim: Simulation = Simulation.new([], Vector2i(64, 64))
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	var lanes := [[10, 28], [30, 40], [50, 16]]
	for index in range(3):
		var lane: Array = lanes[index]
		for player: int in [1, 2]:
			var direction: int = -1 if player == 1 else 1
			var front: int = 32 + direction * (lane[1] / 2)
			var ids: Array[int] = []
			for placed in range(35):
				var kind: String = "usa_tank" if placed % 3 == 0 else "usa_rifle_infantry"
				@warning_ignore("integer_division")
				var position := Vector2(front + direction * (placed / 5) + 0.5, lane[0] - 2 + placed % 5 + 0.5)
				var id: int = sim.spawn(player, position, kind)
				assert(id > 0)
				if placed < 26: ids.append(id)
			var target: Array = [58.5 if player == 1 else 5.5, lane[0] + 0.5]
			var result: Dictionary = sim.issue_command({"tick": 0, "player": player, "sequence": index, "type": "attack_move", "entity_ids": ids, "target": target})
			assert(result.ok, result.error)
	return sim

# Profiling-only M6-scale probe: 196x196 with 8x8 mesas every 20 cells (10.5 % blocked), 3 lanes x 60 units per owner.
const LARGE := Vector2i(196, 196)

static func create_large() -> Simulation:
	var solids: Array[Vector2i] = []
	for top in range(10, 186, 20):
		for left in range(30, 166, 20):
			for y in range(top, top + 8):
				for x in range(left, left + 8): solids.append(Vector2i(x, y))
	var sim: Simulation = Simulation.new(solids, LARGE)
	sim.add_player(1, 0)
	sim.add_player(2, 0)
	var lanes := [38, 98, 158]
	for index in range(lanes.size()):
		for player: int in [1, 2]:
			var front: int = 14 if player == 1 else 181
			var direction: int = -1 if player == 1 else 1
			var ids: Array[int] = []
			for placed in range(60):
				@warning_ignore("integer_division")
				var position := Vector2(front + direction * (placed / 6) + 0.5, lanes[index] - 3 + placed % 6 + 0.5)
				var id: int = sim.spawn(player, position, "usa_tank" if placed % 3 == 0 else "usa_rifle_infantry")
				assert(id > 0)
				ids.append(id)
			var target: Array = [190.5 if player == 1 else 5.5, lanes[index] + 0.5]
			var result: Dictionary = sim.issue_command({"tick": 0, "player": player, "sequence": index, "type": "attack_move", "entity_ids": ids, "target": target})
			assert(result.ok, result.error)
	return sim
