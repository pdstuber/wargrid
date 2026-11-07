extends RefCounted

const Combat = preload("res://scripts/simulation/combat.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Shared = preload("res://scripts/simulation/definitions/shared.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

# Zero Hour CreateCrateDie.cpp:69-229: a vehicle killed by a hostile salvager leaves a crate.
static func on_death(sim: Simulation, victim: Dictionary, killer: Dictionary) -> void:
	if Registry.kind(victim.kind).get("class", "") != "vehicle": return
	if killer.is_empty() or not Combat.hostile(sim, killer.owner, victim.owner) or not Registry.kind(killer.kind).has("salvage"): return
	var crate: Dictionary = Shared.SALVAGE_CRATE
	var cell := Vector2i(floori(victim.position[0]), floori(victim.position[1]))
	sim._crates.append({"cell": [cell.x, cell.y], "until": sim._tick + crate.min_ticks + sim.next_random() % (crate.max_ticks - crate.min_ticks + 1)})

# shortcut: crates x units per tick; grid it if the frc layout shows in the ledger.
static func step(sim: Simulation) -> void:
	if sim._crates.is_empty(): return
	sim._crates = sim._crates.filter(func(crate: Dictionary) -> bool: return crate.until > sim._tick)
	if sim._crates.is_empty(): return
	var salvagers: Array[int] = []
	for id: int in sim._entities:
		if Registry.kind(sim._entities[id].kind).has("salvage") and not sim._entities[id].has("container_id"): salvagers.append(id)
	salvagers.sort()
	var left: Array[Dictionary] = []
	for crate: Dictionary in sim._crates:
		var taker: int = _taker(sim, crate, salvagers)
		if taker == -1: left.append(crate)
		else: collect(sim, sim._entities[taker])
	sim._crates = left

static func _taker(sim: Simulation, crate: Dictionary, salvagers: Array[int]) -> int:
	var point := Vector2(crate.cell[0] + 0.5, crate.cell[1] + 0.5)
	for id in salvagers:
		var unit: Dictionary = sim._entities[id]
		var reach: float = CombatDefinitions.radius(unit.kind) + Shared.SALVAGE_CRATE.radius + Combat.EDGE_EPS
		if Vector2(unit.position[0], unit.position[1]).distance_squared_to(point) <= reach * reach: return id
	return -1

# Zero Hour's 25 percent level branch is money here (no veterancy; design section 6).
static func collect(sim: Simulation, unit: Dictionary) -> void:
	var row: Dictionary = Registry.kind(unit.kind)
	if row.salvage == "weapon" and unit.combat.tier < row.weapon_tiers.size() - 1:
		unit.combat.tier += 1
		return
	var crate: Dictionary = Shared.SALVAGE_CRATE
	sim._players[unit.owner].credits += crate.min_money + sim.next_random() % (crate.max_money - crate.min_money + 1)
