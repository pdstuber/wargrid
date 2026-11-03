extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Fixture = preload("res://tests/combat_fixture.gd")

func cases() -> Array[Callable]:
	return [test_attack_chase, test_unreachable_attack, test_attack_move_resumes, test_attack_move_resume_keeps_slots, test_guard_retarget, test_pursuit_respects_reservations, test_new_attack_plans_immediately]

func _events(sim) -> Array:
	return sim.snapshot().combat_events

func _shots_by(events: Array, attacker: int) -> Array:
	var shots: Array = []
	for event in events:
		if event.type == "shot" and event.attacker_id == attacker:
			shots.append(event)
	return shots

func test_attack_chase(runner) -> bool:
	var sim = Fixture.world()
	var attacker: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var target: int = sim.spawn(2, Vector2(12.5, 2.5), "builder")
	runner.check(Fixture.send(sim, {"type": "attack", "entity_ids": [attacker], "target_id": target}).ok, "A1 attack accepted")
	var first_shot: int = -1
	for tick in range(600):
		var before: Array = Fixture.object(sim, attacker).position
		sim.step()
		var after: Array = Fixture.object(sim, attacker).position
		var shots: Array = _shots_by(_events(sim), attacker)
		if not shots.is_empty():
			runner.check(before == after, "A1 never shoots on a tick it moved")
			first_shot = tick
			break
	runner.check(first_shot > 0, "A1 shoots only after closing the distance")
	var attacker_pos: Array = Fixture.object(sim, attacker).position
	var target_pos: Array = Fixture.object(sim, target).position
	runner.check(Vector2(attacker_pos[0], attacker_pos[1]).distance_to(Vector2(target_pos[0], target_pos[1])) <= 4.0 + 1e-6, "A1 fires from inside rifle range")
	runner.check(Vector2i(Vector2(attacker_pos[0], attacker_pos[1]).floor()) != Vector2i(Vector2(target_pos[0], target_pos[1]).floor()), "A1 never enters the target cell")
	var old_destination: Variant = Fixture.object(sim, attacker).destination
	runner.check(Fixture.send(sim, {"player": 2, "type": "move", "entity_ids": [target], "target": [12.5, 14.5]}).ok, "A1 target relocation accepted")
	var refreshed: int = -1
	for tick in range(40):
		sim.step()
		var destination: Variant = Fixture.object(sim, attacker).destination
		if destination != null and destination != old_destination:
			refreshed = tick
			break
	runner.check(refreshed != -1 and refreshed <= 16, "A1 pursuit refresh within 15 ticks (plus the tick that applies the command)")
	var second: int = sim.spawn(1, Vector2(2.5, 3.5), "infantry")
	runner.check(Fixture.send(sim, {"type": "attack", "entity_ids": [attacker, second], "target_id": target}).ok, "A1 two attackers")
	sim.step()
	var state: Dictionary = sim.snapshot()
	var seen := {}
	for id in state.path_queue:
		runner.check(not seen.has(id), "A1 no duplicate path queue entry")
		seen[id] = true
	var a: Variant = Fixture.object(sim, attacker).destination
	var b: Variant = Fixture.object(sim, second).destination
	runner.check(a == null or b == null or a != b, "A1 distinct pursuit destinations")
	var pair = Fixture.world()
	var left: int = pair.spawn(1, Vector2(2.5, 2.5), "infantry")
	var right: int = pair.spawn(1, Vector2(2.5, 3.5), "infantry")
	var far: int = pair.spawn(2, Vector2(20.5, 10.5), "builder")
	Fixture.send(pair, {"type": "attack", "entity_ids": [left, right], "target_id": far})
	pair.step()
	var da: Variant = Fixture.object(pair, left).destination
	var db: Variant = Fixture.object(pair, right).destination
	runner.check(da != null and db != null and da != db, "A1 two fresh attackers get unique firing cells")
	return true

func test_unreachable_attack(runner) -> bool:
	var wall: Array[Vector2i] = []
	for y in range(32):
		wall.append(Vector2i(16, y))
	var sim = Simulation.new(wall, Vector2i(32, 32))
	var attacker: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var target: int = sim.spawn(2, Vector2(28.5, 2.5), "builder")
	var full_hp: int = Fixture.object(sim, target).hp
	Fixture.send(sim, {"type": "attack", "entity_ids": [attacker], "target_id": target})
	var blocked_tick: int = -1
	var enqueued_after_block: int = 0
	for tick in range(90):
		sim.step()
		var unit: Dictionary = Fixture.object(sim, attacker)
		if blocked_tick == -1 and unit.status == "blocked":
			blocked_tick = tick
		elif blocked_tick != -1 and tick <= blocked_tick + 14:
			if sim.snapshot().path_queue.has(attacker): enqueued_after_block += 1
			runner.check(sim.combat_work() <= 2, "A2 no replanning work during the retry interval")
	runner.check(blocked_tick != -1, "A2 unreachable target ends blocked")
	runner.check(enqueued_after_block == 0, "A2 no path request during the retry interval")
	runner.check(Fixture.object(sim, target).hp == full_hp, "A2 target untouched")
	var none: Array[Vector2i] = []
	runner.check(sim.replace_blocked_cells(none).ok, "A2 wall removed")
	var progressed: bool = false
	for tick in range(90):
		sim.step()
		var unit: Dictionary = Fixture.object(sim, attacker)
		if unit.status == "moving" or unit.status == "path_pending":
			progressed = true
			break
	runner.check(progressed, "A2 opening the wall lets the attack progress at the next retry")
	var many := Simulation.new([], Vector2i(32, 32))
	var victim: int = many.spawn(2, Vector2(28.5, 16.5), "builder")
	var ids: Array = []
	for i in range(20):
		ids.append(many.spawn(1, Vector2(2.5 + i % 5, 2.5 + i / 5), "infantry"))
	Fixture.send(many, {"type": "attack", "entity_ids": ids, "target_id": victim})
	for tick in range(30):
		var before := {}
		for entity in many.snapshot().entities:
			before[entity.id] = entity.status
		many.step()
		var assigned: int = 0
		for entity in many.snapshot().entities:
			if before[entity.id] == "path_pending" and entity.status != "path_pending":
				assigned += 1
		runner.check(assigned <= 8, "A2 at most 8 path queries per tick")
	var late: int = many.spawn(1, Vector2(1.5, 20.5), "infantry")
	Fixture.send(many, {"type": "attack", "entity_ids": [late], "target_id": victim})
	many.step()
	Fixture.send(many, {"type": "stop", "entity_ids": [late]})
	many.step()
	runner.check(not many.snapshot().path_queue.has(late), "A2 stop removes a queued path")
	return true

func _run_to_first_shot(sim: RefCounted, attacker: int, limit: int) -> int:
	for tick in range(limit):
		sim.step()
		if not _shots_by(_events(sim), attacker).is_empty(): return tick
	return -1

func test_attack_move_resumes(runner) -> bool:
	var sim = Fixture.world()
	var attacker: int = sim.spawn(1, Vector2(2.5, 2.5), "infantry")
	var enemy: int = sim.spawn(2, Vector2(9.5, 4.5), "builder")
	runner.check(Fixture.send(sim, {"type": "attack_move", "entity_ids": [attacker], "target": [20.5, 2.5]}).ok, "M1 attack_move accepted")
	runner.check(_run_to_first_shot(sim, attacker, 400) > 0, "M1 in-range enemy interrupts the advance")
	var halted: Dictionary = Fixture.object(sim, attacker)
	runner.check(halted.status == "idle" and halted.destination == [20.5, 2.5] and halted.combat.mode == "attack_move" and halted.combat.goal == [20.5, 2.5], "M1 halted keeps the goal")
	runner.check(sim.remove_object(enemy).ok, "M1 enemy removed through public API")
	sim.step()
	runner.check(sim.allocation_calls() == 0, "M1 resume reuses the slot without allocation")
	var resumed: Dictionary = Fixture.object(sim, attacker)
	runner.check(resumed.combat.target_id == null and resumed.destination == [20.5, 2.5] and (resumed.status == "path_pending" or resumed.status == "moving"), "M1 resumes the original goal, not the enemy position")
	for tick in range(900):
		sim.step()
		if Fixture.object(sim, attacker).status == "arrived": break
	sim.step()
	var arrived: Dictionary = Fixture.object(sim, attacker)
	runner.check(arrived.position == [20.5, 2.5] and arrived.combat.mode == "guard" and arrived.combat.goal == null, "M1 goal arrival switches to guard")
	var plain = Fixture.world()
	var scout: int = plain.spawn(1, Vector2(2.5, 2.5), "infantry")
	var scout_mate: int = plain.spawn(1, Vector2(2.5, 3.5), "infantry")
	var move = Fixture.world()
	var walker: int = move.spawn(1, Vector2(2.5, 2.5), "infantry")
	var walker_mate: int = move.spawn(1, Vector2(2.5, 3.5), "infantry")
	Fixture.send(plain, {"type": "attack_move", "entity_ids": [scout, scout_mate], "target": [12.5, 8.5]})
	Fixture.send(move, {"type": "move", "entity_ids": [walker, walker_mate], "target": [12.5, 8.5]})
	plain.step()
	move.step()
	runner.check(Fixture.object(plain, scout).destination == Fixture.object(move, walker).destination and Fixture.object(plain, scout_mate).destination == Fixture.object(move, walker_mate).destination, "M1 quiet attack_move allocates like move")
	var pass_by = Fixture.world()
	var mover: int = pass_by.spawn(1, Vector2(2.5, 2.5), "infantry")
	pass_by.spawn(2, Vector2(18.5, 5.5), "builder")
	Fixture.send(pass_by, {"type": "move", "entity_ids": [mover], "target": [20.5, 2.5]})
	var arrival: int = -1
	var first_shot: int = -1
	for tick in range(900):
		pass_by.step()
		if arrival == -1 and Fixture.object(pass_by, mover).status == "arrived": arrival = tick
		if first_shot == -1 and not _shots_by(_events(pass_by), mover).is_empty(): first_shot = tick
		if first_shot != -1: break
	runner.check(arrival != -1 and first_shot > arrival, "M1 ordinary move never fires before arrival")
	var group = Fixture.world()
	var ids: Array = []
	for i in range(6):
		ids.append(group.spawn(1, Vector2(2.5, 2.5 + i), "infantry"))
	var victim: int = group.spawn(2, Vector2(7.5, 4.5), "builder")
	Fixture.send(group, {"type": "attack_move", "entity_ids": ids, "target": [24.5, 6.5]})
	var engaged: bool = false
	for tick in range(400):
		group.step()
		if not group.snapshot().combat_events.is_empty():
			engaged = true
			break
	runner.check(engaged, "M1 group engages")
	group.remove_object(victim)
	group.step()
	var destinations := {}
	for entity in group.snapshot().entities:
		if entity.destination != null: destinations[entity.destination] = true
	runner.check(destinations.size() == ids.size(), "M1 resumed group gets unique destinations")
	return true

func test_attack_move_resume_keeps_slots(runner) -> bool:
	var sim = Fixture.world()
	var enemy: int = sim.spawn(2, Vector2(8.5, 8.5), "builder")
	var group_a: Array = []
	for at in [Vector2(6.5, 7.5), Vector2(6.5, 8.5), Vector2(6.5, 9.5), Vector2(10.5, 7.5), Vector2(10.5, 8.5), Vector2(10.5, 9.5)]:
		group_a.append(sim.spawn(1, at, "infantry"))
	var group_b: Array = [sim.spawn(1, Vector2(8.5, 6.5), "infantry"), sim.spawn(1, Vector2(8.5, 10.5), "infantry")]
	Fixture.send(sim, {"type": "attack_move", "entity_ids": group_a, "target": [20.5, 8.5]})
	Fixture.send(sim, {"type": "attack_move", "entity_ids": group_b, "target": [2.5, 20.5]})
	sim.step()
	var halted: int = 0
	for entity in sim.snapshot().entities:
		if entity.owner == 1 and entity.status == "idle" and entity.combat.target_id == enemy: halted += 1
	runner.check(halted == 8, "B1 all eight halt on the same enemy")
	var kept := {}
	for entity in sim.snapshot().entities:
		if entity.owner == 1: kept[entity.id] = entity.destination
	var distinct := {}
	for destination in kept.values(): distinct[destination] = true
	runner.check(not kept.values().has(null) and distinct.size() == 8, "B1 halted units keep eight unique destinations")
	sim.remove_object(enemy)
	sim.step()
	runner.check(sim.allocation_calls() == 0, "B1 resume allocates nothing, got " + str(sim.allocation_calls()))
	for entity in sim.snapshot().entities:
		if entity.owner == 1: runner.check(entity.destination == kept[entity.id] and (entity.status == "path_pending" or entity.status == "moving"), "B1 unit resumes toward its unchanged slot")
	sim.step()
	runner.check(sim.allocation_calls() == 0, "B1 counter resets each step")
	return true

func test_guard_retarget(runner) -> bool:
	var sim = Fixture.world()
	var guard: int = sim.spawn(1, Vector2(10.5, 10.5), "infantry")
	var leaving: int = sim.spawn(2, Vector2(13.5, 10.5), "builder")
	var staying: int = sim.spawn(2, Vector2(10.5, 13.9), "builder")
	sim.step()
	runner.check(Fixture.object(sim, guard).combat.target_id == leaving, "G2 nearest enemy acquired first")
	sim._entities[leaving].position = [13.5, 31.5]
	var dropped_shots: bool = false
	sim.step()
	for event in _shots_by(_events(sim), guard): dropped_shots = dropped_shots or event.target_id == leaving
	runner.check(not dropped_shots, "G2 never fires at a target beyond weapon range")
	runner.check(Fixture.object(sim, guard).combat.target_id == leaving, "G2 keeps the acquired target after it leaves the radius")
	runner.check(Fixture.object(sim, guard).combat.mode == "guard", "G2 guard stays in guard while chasing")
	return true

func test_pursuit_respects_reservations(runner) -> bool:
	var sim = Fixture.world()
	var reserver: int = sim.spawn(1, Vector2(16.5, 3.5), "vehicle")
	sim.spawn(1, Vector2(17.5, 10.5), "vehicle")
	var attacker: int = sim.spawn(1, Vector2(2.5, 10.5), "infantry")
	var target: int = sim.spawn(2, Vector2(20.5, 10.5), "builder")
	Fixture.send(sim, {"type": "move", "entity_ids": [reserver], "target": [16.5, 10.5]})
	Fixture.send(sim, {"type": "attack", "entity_ids": [attacker], "target_id": target})
	sim.step()
	runner.check(Fixture.object(sim, reserver).destination == [16.5, 10.5], "P2 nearest firing cell is reserved")
	runner.check(Fixture.object(sim, attacker).destination == [17.5, 9.5], "P2 skips reserved and occupied cells, ties by y")
	var release = Fixture.world()
	var first: int = release.spawn(1, Vector2(2.5, 10.5), "infantry")
	var second: int = release.spawn(1, Vector2(2.5, 12.5), "infantry")
	var moving: int = release.spawn(2, Vector2(20.5, 10.5), "builder")
	Fixture.send(release, {"type": "attack", "entity_ids": [first], "target_id": moving})
	Fixture.send(release, {"player": 2, "type": "move", "entity_ids": [moving], "target": [20.5, 0.5]})
	for tick in range(15): release.step()
	runner.check(Fixture.object(release, first).destination == [16.5, 10.5], "P2 first attacker holds the old firing cell")
	var still: int = release.spawn(2, Vector2(20.5, 10.5), "builder")
	runner.check(still > 0, "P2 stationary second target spawned")
	Fixture.send(release, {"type": "attack", "entity_ids": [second], "target_id": still})
	release.step()
	runner.check(Fixture.object(release, first).destination != [16.5, 10.5], "P2 first attacker re-picks for its moving target")
	runner.check(Fixture.object(release, second).destination == [16.5, 10.5], "P2 released cell is available later in the same tick")
	return true

func test_new_attack_plans_immediately(runner) -> bool:
	var sim = Fixture.world()
	var attacker: int = sim.spawn(1, Vector2(2.5, 10.5), "infantry")
	var first: int = sim.spawn(2, Vector2(20.5, 10.5), "builder")
	var second: int = sim.spawn(2, Vector2(2.5, 28.5), "builder")
	Fixture.send(sim, {"type": "attack", "entity_ids": [attacker], "target_id": first})
	for tick in range(5): sim.step()
	runner.check(Fixture.object(sim, attacker).combat.repath_tick == 15, "N1 chase refresh scheduled")
	Fixture.send(sim, {"type": "attack", "entity_ids": [attacker], "target_id": second})
	sim.step()
	var unit: Dictionary = Fixture.object(sim, attacker)
	runner.check(unit.destination != null and Vector2(unit.destination[0], unit.destination[1]).distance_to(Vector2(2.5, 28.5)) <= 4.0, "N1 new attack picks a firing cell on its first tick")
	runner.check(unit.combat.repath_tick == 20, "N1 new attack restarts the refresh interval")
	return true
