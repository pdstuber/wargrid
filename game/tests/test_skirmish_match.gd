@warning_ignore_start("untyped_declaration")
extends RefCounted

const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const ScriptedHuman = preload("res://scripts/simulation/scripted_human.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")

const TICK_LIMIT: int = 18000
const TERMINAL_TICK: int = 9473
const WINNER: int = 1

const S1_CORE_SERIES: int = 8505231937702596599

func cases() -> Array[Callable]:
	return [test_mirror_match_script, test_skirmish_core_series, test_china_skirmish_match, test_frc_skirmish_match]

func test_skirmish_core_series(runner) -> bool:
	var sim = Skirmish.create()
	var series: int = 0
	for tick in range(TERMINAL_TICK + 1):
		ScriptedHuman.issue(sim)
		Skirmish.issue_opponent(sim)
		sim.step()
		series = (series * 31 + StateHash.core_check(sim.snapshot())) & 0x7fffffffffffffff
		if tick % 600 == 599: await runner.process_frame
	runner.check(series == S1_CORE_SERIES, "S1 core series pinned, got " + str(series))
	return true

func _credits(state: Dictionary, player: int) -> int:
	for entry in state.players:
		if entry.id == player: return entry.credits
	return -1

func test_mirror_match_script(runner) -> bool:
	var a = Skirmish.create()
	var b = Skirmish.create()
	var first := {"deposit": -1, "shot": -1, "death": -1, "usa_rifle_infantry": -1, "usa_tank": -1}
	var completed := {}
	var kinds := {}
	var deposits := {1: 0, 2: 0}
	var credits := {1: 10000, 2: 10000}
	var cargo_before := {}
	var delivered: int = 0
	var boxes_ok: bool = true
	var known_buildings: Array = []
	var created: int = 0
	var negatives: int = 0
	var diverged: int = -1
	var terminal: int = -1
	for tick in range(TICK_LIMIT):
		ScriptedHuman.issue(a)
		ScriptedHuman.issue(b)
		Skirmish.issue_opponent(a)
		Skirmish.issue_opponent(b)
		a.step()
		b.step()
		var state: Dictionary = a.snapshot()
		if diverged == -1 and state != b.snapshot(): diverged = tick
		var building_ids: Array = state.buildings.map(func(building: Dictionary) -> int: return building.id)
		var building_lost: bool = known_buildings.any(func(id: int) -> bool: return not building_ids.has(id))
		known_buildings = building_ids
		for building in state.buildings:
			if building.completed and not completed.has(building.id): completed[building.id] = tick
			if building.completed: kinds.get_or_add(building.owner, {})[building.kind] = true
		for event in state.combat_events:
			if event.type == "shot" and first.shot == -1: first.shot = tick
			if event.type == "death" and first.death == -1: first.death = tick
		var carried: int = 0
		var deposit := {1: 0, 2: 0}
		var cargo_now := {}
		for unit in state.entities:
			if unit.hp <= 0: negatives += 1
			if (unit.kind == "usa_rifle_infantry" or unit.kind == "usa_tank") and first[unit.kind] == -1: first[unit.kind] = tick
			if unit.collection == null: continue
			carried += unit.collection.cargo
			cargo_now[unit.id] = unit.collection.cargo
			if cargo_before.get(unit.id, 0) > 0 and unit.collection.cargo == 0: deposit[unit.owner] += cargo_before[unit.id] * 75
		cargo_before = cargo_now
		var stock: int = 0
		for source in state.sources:
			if source.boxes < 0: negatives += 1
			stock += source.boxes
		for player in [1, 2]:
			var now: int = _credits(state, player)
			if now < 0: negatives += 1
			if now > credits[player] + deposit[player] and not building_lost: boxes_ok = false
			if deposit[player] > 0:
				deposits[player] += deposit[player]
				delivered += deposit[player] / 75
				if first.deposit == -1: first.deposit = tick
			credits[player] = now
		if stock + carried + delivered != 400: boxes_ok = false
		if state.match.status != "ongoing":
			terminal = tick
			break
		if tick % 600 == 599: await runner.process_frame
	var end: Dictionary = a.snapshot()
	runner.check(diverged == -1, "S1 two fresh worlds stay identical, first divergence " + str(diverged))
	runner.check(terminal == TERMINAL_TICK and end.match.winner == WINNER and end.match.ended_tick == TERMINAL_TICK and end.tick == TERMINAL_TICK + 1, "S1 pinned outcome, got " + str(terminal) + " " + str(end.match))
	runner.check(terminal >= 7000 and terminal <= TICK_LIMIT - 1, "S1 terminal inside the six-minute window")
	runner.check([1, 2].all(func(owner: int) -> bool: return Skirmish.build_order(Skirmish.default_faction()).all(func(kind: String) -> bool: return kinds.get(owner, {}).has(kind))) and not first.values().has(-1) and first.values().all(func(tick: int) -> bool: return tick < terminal), "S1 economy, production and combat all happened before the end, got " + str(first) + " " + str(kinds))
	runner.check(deposits[1] > 0 and deposits[2] > 0 and boxes_ok and negatives == 0, "S1 both owners deposited, supply conserved, nothing negative: " + str(deposits))
	return true

const CHINA_TICK_CAP: int = 45000
const CHINA_TERMINAL_TICK: int = 16258
const CHINA_WINNER: int = 2

func test_china_skirmish_match(runner) -> bool:
	var sim = Skirmish.create(true, "ai", {1: "china", 2: "usa"})
	var seen := {"horde2": false, "ramp2": false, "delivery": false, "pair": false}
	var cargo_before := {}
	var known := {}
	var terminal: int = -1
	for tick in range(CHINA_TICK_CAP):
		Skirmish.issue_opponents(sim, [1, 2])
		sim.step()
		var state: Dictionary = sim.snapshot()
		var born: int = 0
		var cargo_now := {}
		for unit in state.entities:
			if unit.owner == 1 and unit.kind == "china_rifle_infantry" and not known.has(unit.id): born += 1
			known[unit.id] = true
			if unit.combat != null:
				if unit.combat.get("horde", 0) == 2: seen.horde2 = true
				if unit.combat.get("ramp_level", 0) == 2: seen.ramp2 = true
			if unit.owner == 1 and unit.collection != null:
				cargo_now[unit.id] = unit.collection.cargo
				if cargo_before.get(unit.id, 0) > 0 and unit.collection.cargo == 0: seen.delivery = true
		if born >= 2: seen.pair = true
		cargo_before = cargo_now
		if state.match.status != "ongoing":
			terminal = tick
			break
		if tick % 600 == 599: await runner.process_frame
	var end: Dictionary = sim.snapshot()
	runner.check(end.match.status == "won", "Cs1 china match ends won inside the cap, got " + str(end.match))
	runner.check(terminal == CHINA_TERMINAL_TICK and end.match.winner == CHINA_WINNER, "Cs1 pinned outcome, got " + str(terminal) + " " + str(end.match))
	runner.check(not seen.values().has(false), "Cs1 horde level 2, ramp level 2, truck delivery and a quantity pair all happened: " + str(seen))
	return true

const FRC_TICK_CAP: int = 45000
const FRC_TERMINAL_TICK: int = 10512
const FRC_WINNER: int = 2

func test_frc_skirmish_match(runner) -> bool:
	var sim = Skirmish.create(true, "ai", {1: "frc", 2: "usa"})
	var seen := {"delivery": false, "hole": false, "hub_pair": false, "crate": false}
	var cargo_before := {}
	var known := {}
	var hubs := {}
	var terminal: int = -1
	for tick in range(FRC_TICK_CAP):
		Skirmish.issue_opponents(sim, [1, 2])
		sim.step()
		var state: Dictionary = sim.snapshot()
		var born: int = 0
		var cargo_now := {}
		for unit in state.entities:
			if unit.owner == 1 and unit.kind == "frc_rocket_infantry" and not known.has(unit.id): born += 1
			known[unit.id] = true
			if unit.owner == 1 and unit.collection != null:
				cargo_now[unit.id] = unit.collection.cargo
				if cargo_before.get(unit.id, 0) > 0 and unit.collection.cargo == 0: seen.delivery = true
		var hub_done: bool = false
		for building in state.buildings:
			if building.has("rebuild"): seen.hole = true
			if building.kind == "frc_defence":
				if building.completed and hubs.get(building.id, true) == false: hub_done = true
				hubs[building.id] = building.completed
		if hub_done and born >= 2: seen.hub_pair = true
		if not state.get("crates", []).is_empty(): seen.crate = true
		cargo_before = cargo_now
		if state.match.status != "ongoing":
			terminal = tick
			break
		if tick % 600 == 599: await runner.process_frame
	var end: Dictionary = sim.snapshot()
	runner.check(end.match.status == "won", "Fm1 frc match ends won inside the cap, got " + str(end.match))
	runner.check(terminal == FRC_TERMINAL_TICK and end.match.winner == FRC_WINNER, "Fm1 pinned outcome, got " + str(terminal) + " " + str(end.match))
	runner.check(not seen.values().has(false), "Fm1 laborer delivery, a hole, two rocket fighters on the hub tick and a crate all happened: " + str(seen))
	return true
