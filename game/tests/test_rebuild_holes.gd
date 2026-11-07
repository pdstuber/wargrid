@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/combat_fixture.gd")
const EconomyFixture = preload("res://tests/economy_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")

const BARRACKS := Vector2i(10, 10)
const RESPAWN: int = 600

func cases() -> Array[Callable]:
	return [test_hole_replaces_destroyed_building, test_no_hole_cases, test_hole_counts_for_victory, test_hole_regen_83_per_tick, test_rebuild_after_600_ticks, test_rebuilt_supply_cache_spawns_nothing, test_worker_death_restarts_timer, test_site_death_restarts_timer, test_hole_death_leaves_ordinary_foundation, test_rebuild_laborer_not_commandable, test_player_resumes_waiting_site, test_masked_hole_not_targeted, test_site_completes_before_worker_dies, test_hole_masks_on_spawn_tick, test_hole_same_tick_cases, test_site_and_second_laborer_die_together]

func _world() -> RefCounted:
	var sim = Fixture.world()
	sim.add_player(1, 10000)
	sim.add_player(2, 0)
	return sim

func _holes(sim) -> Array:
	return sim.snapshot().buildings.filter(func(b: Dictionary) -> bool: return b.has("rebuild"))

func _hole(sim) -> Dictionary:
	var found: Array = _holes(sim)
	return found[0] if not found.is_empty() else {}

func _site(sim) -> Dictionary:
	var found: Array = sim.snapshot().buildings.filter(func(b: Dictionary) -> bool: return b.has("hole_id"))
	return found[0] if not found.is_empty() else {}

func _laborer(sim) -> Dictionary:
	var found: Array = sim.snapshot().entities.filter(func(u: Dictionary) -> bool: return u.has("hole_id"))
	return found[0] if not found.is_empty() else {}

func _deaths(sim) -> int:
	return sim.snapshot().combat_events.filter(func(e: Dictionary) -> bool: return e.type == "death").size()

# Destroys a fresh FRC building; the hole's respawn_tick is tick + RESPAWN.
func _destroyed(kind: String = "frc_barracks", origin: Vector2i = BARRACKS) -> Array:
	var sim = _world()
	var id: int = EconomyFixture.add_completed(sim, 1, kind, origin)
	sim.remove_object(id)
	return [sim, id]

func _step_to_respawn(sim) -> void:
	sim.step()
	while sim.tick() < _hole(sim).rebuild.respawn_tick: sim.step()

# A hole whose laborer exists and stands at the site: step to the respawn tick, then one more.
func _masked() -> RefCounted:
	var sim = _destroyed()[0]
	_step_to_respawn(sim)
	sim.step()
	return sim

func _rifleman(sim, at: Vector2) -> int:
	return sim.spawn(2, at, "usa_rifle_infantry")

func test_hole_replaces_destroyed_building(runner) -> bool:
	var sim = _world()
	var id: int = EconomyFixture.add_completed(sim, 1, "frc_barracks", BARRACKS)
	sim._buildings[id].hp = 1000
	var shooter: int = _rifleman(sim, Vector2(8.5, 10.5))
	var death_tick: int = -1
	for i in range(10):
		sim.step()
		for event in sim.snapshot().combat_events:
			if event.type == "death" and event.object_id == id: death_tick = event.tick
		if death_tick >= 0: break
	var hole: Dictionary = _hole(sim)
	runner.check(shooter > 0 and death_tick >= 0 and not hole.is_empty(), "RH1 a destroyed completed FRC building leaves a hole")
	runner.check(hole.kind == "frc_hole_2" and hole.owner == 1 and hole.origin == [10, 10] and hole.completed, "RH1 hole kind, owner, origin by footprint")
	runner.check(hole.hp == 500000 and hole.max_hp == 500000, "RH1 a new hole starts at full 500000")
	runner.check(hole.rebuild == {"kind": "frc_barracks", "respawn_tick": death_tick + RESPAWN, "worker_id": null, "site_id": null}, "RH1 rebuild record, got %s" % str(hole.get("rebuild")))
	var blocked: bool = true
	for cell in [Vector2(10.5, 10.5), Vector2(11.5, 10.5), Vector2(10.5, 11.5), Vector2(11.5, 11.5)]: blocked = blocked and not sim._navigation.is_walkable(cell)
	runner.check(blocked, "RH1 the four cells stay unwalkable")
	var tower = _world()
	EconomyFixture.add_completed(tower, 1, "frc_barracks", Vector2i(20, 20))
	tower.remove_object(EconomyFixture.add_completed(tower, 1, "frc_defence", Vector2i(12, 12)))
	runner.check(_hole(tower).get("kind") == "frc_hole_1", "RH1 a 1x1 building leaves a 1x1 hole")
	return true

func test_no_hole_cases(runner) -> bool:
	var sim = _world()
	var laborer: int = sim.spawn(1, Vector2(4.5, 4.5), "frc_builder")
	runner.check(Fixture.send(sim, {"type": "build", "builder_id": laborer, "building_kind": "frc_barracks", "origin": [10, 10]}).ok, "RH2 foundation placed")
	sim.step()
	var site: int = sim.snapshot().buildings[0].id
	runner.check(Fixture.send(sim, {"type": "cancel_build", "building_id": site}).ok, "RH2 cancel accepted")
	sim.step()
	runner.check(_holes(sim).is_empty() and sim.snapshot().buildings.is_empty(), "RH2 a cancelled foundation leaves no hole")
	Fixture.send(sim, {"type": "build", "builder_id": laborer, "building_kind": "frc_barracks", "origin": [10, 10]})
	sim.step()
	sim.remove_object(sim.snapshot().buildings[0].id)
	runner.check(_holes(sim).is_empty(), "RH2 a killed foundation leaves no hole")
	var usa = _world()
	usa.remove_object(EconomyFixture.add_completed(usa, 1, "usa_barracks", BARRACKS))
	runner.check(_holes(usa).is_empty(), "RH2 a non-FRC building leaves no hole")
	var alone = _world()
	alone.remove_object(EconomyFixture.add_completed(alone, 1, "frc_defence", Vector2i(12, 12)))
	runner.check(_holes(alone).is_empty(), "RH2 the defence of a seat with no counting building leaves no hole")
	return true

func test_hole_counts_for_victory(runner) -> bool:
	var sim = _world()
	EconomyFixture.add_completed(sim, 2, "usa_barracks", Vector2i(20, 20))
	var id: int = EconomyFixture.add_completed(sim, 1, "frc_barracks", BARRACKS)
	runner.check(sim.start_match([1, 2] as Array[int]).ok, "RH3 match starts")
	sim.remove_object(id)
	sim.step()
	var state: Dictionary = sim.snapshot()
	runner.check(state.match.status == "ongoing" and state.players[0].alive, "RH3 the seat stays alive through its hole")
	sim.remove_object(_hole(sim).id)
	sim.step()
	state = sim.snapshot()
	runner.check(state.match.status == "won" and state.match.winner == 2 and state.match.ended_tick == 1 and not state.players[0].alive, "RH3 the hole's death defeats the seat that tick")
	return true

func test_hole_regen_83_per_tick(runner) -> bool:
	var sim = _destroyed()[0]
	var id: int = _hole(sim).id
	sim._buildings[id].hp = 400000
	sim.step()
	runner.check(_hole(sim).hp == 400083, "RH4 regen is 83 per tick, got %d" % _hole(sim).hp)
	sim._buildings[id].hp = 499950
	sim.step()
	runner.check(_hole(sim).hp == 500000, "RH4 regen caps at max_hp")
	_step_to_respawn(sim)
	sim.step()
	runner.check(Combat.masked(_hole(sim)), "RH4 hole is masked")
	sim._buildings[id].hp = 400000
	sim.step()
	runner.check(_hole(sim).hp == 400083, "RH4 a masked hole regenerates too")
	return true

func test_rebuild_after_600_ticks(runner) -> bool:
	var pair = _destroyed()
	var sim = pair[0]
	var tick0: int = sim.tick()
	_step_to_respawn(sim)
	runner.check(_laborer(sim).is_empty(), "RH5 no laborer before respawn_tick")
	sim.step()
	var worker: Dictionary = _laborer(sim)
	var site: Dictionary = _site(sim)
	var hole: Dictionary = _hole(sim)
	runner.check(not worker.is_empty() and worker.kind == "frc_builder" and worker.hole_id == hole.id, "RH5 a laborer with hole_id spawns")
	runner.check(not site.is_empty() and site.kind == "frc_barracks" and site.hole_id == hole.id and site.paid_cost == 0 and not site.completed, "RH5 a rebuild foundation with hole_id and paid_cost 0")
	runner.check(sim.snapshot().players[0].credits == 10000, "RH5 the rebuild costs nothing")
	runner.check(hole.rebuild.worker_id == worker.id and hole.rebuild.site_id == site.id and Combat.masked(hole), "RH5 the hole is masked and names laborer and site")
	var start: int = sim.tick()
	var deaths: int = 0
	while not _site(sim).is_empty() and not _site(sim).completed and sim.tick() - start < 400:
		sim.step()
		deaths += _deaths(sim)
	var took: int = sim.tick() - start
	runner.check(took >= 299 and took <= 310, "RH5 the barracks takes about 300 ticks, took %d" % took)
	var done: Array = sim.snapshot().buildings
	runner.check(done.size() == 1 and done[0].kind == "frc_barracks" and done[0].completed and not done[0].has("hole_id"), "RH5 the barracks is completed and the hole is gone")
	runner.check(_laborer(sim).is_empty() and sim.snapshot().entities.is_empty() and deaths == 0, "RH5 the laborer is gone with no death event")
	runner.check(tick0 >= 0, "RH5 ran")
	return true

func test_rebuilt_supply_cache_spawns_nothing(runner) -> bool:
	var sim = _destroyed("frc_supply_center", BARRACKS)[0]
	_step_to_respawn(sim)
	for i in range(500):
		sim.step()
		if _site(sim).is_empty(): break
	var kinds: Array = sim.snapshot().buildings.map(func(b: Dictionary) -> String: return b.kind)
	runner.check(kinds == ["frc_supply_center"] and sim.snapshot().buildings[0].completed, "RH6 the supply cache is rebuilt")
	runner.check(sim.snapshot().entities.is_empty(), "RH6 a rebuilt supply cache spawns no free laborer")
	return true

func test_worker_death_restarts_timer(runner) -> bool:
	var sim = _masked()
	for i in range(50): sim.step()
	var work: int = _site(sim).work
	var dead: int = _laborer(sim).id
	var tick: int = sim.tick()
	sim.remove_object(dead)
	var hole: Dictionary = _hole(sim)
	var site: Dictionary = _site(sim)
	runner.check(not Combat.masked(hole) and hole.rebuild.worker_id == null and hole.rebuild.respawn_tick == tick + RESPAWN, "RH7 the hole unmasks and restarts the timer")
	runner.check(site.work == work and work > 0 and site.builder_id == null and hole.rebuild.site_id == site.id, "RH7 the site keeps its work")
	_step_to_respawn(sim)
	sim.step()
	var fresh: Dictionary = _laborer(sim)
	runner.check(not fresh.is_empty() and fresh.id != dead and _site(sim).builder_id == fresh.id and _site(sim).work >= work, "RH7 the next laborer resumes the same site")
	return true

func test_site_death_restarts_timer(runner) -> bool:
	var sim = _masked()
	var tick: int = sim.tick()
	sim.remove_object(_site(sim).id)
	var hole: Dictionary = _hole(sim)
	runner.check(_laborer(sim).is_empty() and _deaths(sim) == 0, "RH8 a killed site removes the laborer without a death event")
	runner.check(not Combat.masked(hole) and hole.rebuild.site_id == null and hole.rebuild.respawn_tick == tick + RESPAWN and sim.snapshot().players[0].credits == 10000, "RH8 killed site: hole unmasks, timer restarts, no refund")
	var other = _masked()
	other.step()
	var tick2: int = other.tick()
	runner.check(Fixture.send(other, {"type": "cancel_build", "building_id": _site(other).id}).ok, "RH8 cancel_build on a rebuild site is accepted")
	other.step()
	hole = _hole(other)
	runner.check(_site(other).is_empty() and _laborer(other).is_empty() and _deaths(other) == 0 and not Combat.masked(hole), "RH8 cancelled site: laborer gone silently, hole unmasked")
	runner.check(hole.rebuild.respawn_tick == tick2 + RESPAWN and other.snapshot().players[0].credits == 10000, "RH8 cancelled site: timer restarts, credits unchanged")
	return true

func test_hole_death_leaves_ordinary_foundation(runner) -> bool:
	var sim = _masked()
	for i in range(20): sim.step()
	var own: int = sim.spawn(1, Vector2(5.5, 5.5), "frc_builder")
	var work: int = _site(sim).work
	var site_id: int = _site(sim).id
	sim.remove_object(_hole(sim).id)
	var site: Dictionary = EconomyFixture.object(sim, site_id)
	runner.check(_holes(sim).is_empty() and _laborer(sim).is_empty() and _deaths(sim) == 0, "RH9 the hole's death removes its laborer silently")
	runner.check(not site.is_empty() and not site.has("hole_id") and not site.completed and site.work == work and site.builder_id == null, "RH9 the site stays as an ordinary foundation")
	runner.check(Fixture.send(sim, {"type": "resume_build", "builder_id": own, "building_id": site_id}).ok, "RH9 the seat can resume it")
	return true

func test_rebuild_laborer_not_commandable(runner) -> bool:
	var sim = _masked()
	var worker: int = _laborer(sim).id
	var site: int = _site(sim).id
	var own: int = sim.spawn(1, Vector2(5.5, 5.5), "frc_builder")
	var commands := {
		"move": {"type": "move", "entity_ids": [worker], "target": [3.5, 3.5]},
		"stop": {"type": "stop", "entity_ids": [worker]},
		"gather": {"type": "gather", "entity_ids": [worker], "source_id": 99},
		"attack": {"type": "attack", "entity_ids": [worker], "target_id": 99},
		"attack_move": {"type": "attack_move", "entity_ids": [worker], "target": [3.5, 3.5]},
		"enter": {"type": "enter", "entity_ids": [worker], "target_id": 99}}
	for name: String in commands:
		var result: Dictionary = Fixture.send(sim, commands[name])
		runner.check(not result.ok and result.error == "Unit cannot be commanded", "RH10 %s: %s" % [name, result.error])
	var build: Dictionary = Fixture.send(sim, {"type": "build", "builder_id": worker, "building_kind": "frc_barracks", "origin": [20, 20]})
	runner.check(not build.ok and build.error == "Invalid builder or building kind", "RH10 build with it as builder: %s" % build.error)
	var resume: Dictionary = Fixture.send(sim, {"type": "resume_build", "builder_id": worker, "building_id": site})
	runner.check(not resume.ok and resume.error == "Invalid builder", "RH10 resume_build with it as builder: %s" % resume.error)
	var taken: Dictionary = Fixture.send(sim, {"type": "resume_build", "builder_id": own, "building_id": site})
	runner.check(not taken.ok and taken.error == "Foundation is being rebuilt", "RH10 the seat cannot resume a site its hole laborer builds: %s" % taken.error)
	return true

func test_player_resumes_waiting_site(runner) -> bool:
	var sim = _masked()
	for i in range(50): sim.step()
	sim.remove_object(_laborer(sim).id)
	var own: int = sim.spawn(1, Vector2(8.5, 8.5), "frc_builder")
	var site_id: int = _site(sim).id
	runner.check(Fixture.send(sim, {"type": "resume_build", "builder_id": own, "building_id": site_id}).ok, "RH11 the seat's laborer may resume a waiting site")
	for i in range(120): sim.step()
	var work: int = _site(sim).work
	runner.check(_site(sim).builder_id == own and work > 60000, "RH11 its work continues, got %d" % work)
	sim._buildings[_hole(sim).id].rebuild.respawn_tick = sim.tick()
	sim.step()
	var fresh: Dictionary = _laborer(sim)
	var mine: Dictionary = EconomyFixture.object(sim, own)
	runner.check(not fresh.is_empty() and _site(sim).builder_id == fresh.id and mine.construction_id == null, "RH11 the new hole laborer takes the site over and the seat's laborer stops")
	runner.check(_site(sim).work >= work, "RH11 the work is kept")
	return true

func test_masked_hole_not_targeted(runner) -> bool:
	var sim = _masked()
	EconomyFixture.add_completed(sim, 2, "usa_power_plant", Vector2i(1, 1))
	var defence: int = EconomyFixture.add_completed(sim, 2, "usa_defence", Vector2i(14, 10))
	var hole: int = _hole(sim).id
	var site: int = _site(sim).id
	var shooter: int = _rifleman(sim, Vector2(10.5, 14.5))
	var attack: Dictionary = Fixture.send(sim, {"type": "attack", "player": 2, "entity_ids": [shooter], "target_id": hole})
	runner.check(not attack.ok and attack.error == "Invalid attack target", "RH12 attack on a masked hole: %s" % attack.error)
	var battery: Dictionary = Fixture.send(sim, {"type": "defence_attack", "player": 2, "building_id": defence, "target_id": hole})
	runner.check(not battery.ok and battery.error == "Invalid attack target", "RH12 defence_attack on a masked hole: %s" % battery.error)
	var victims: Array = Combat.splash_victims(sim, Vector2(11, 11), 3.0, ["enemies"], {"id": -1, "owner": 2}).map(func(v: Dictionary) -> int: return v.id)
	runner.check(victims.has(site) and not victims.has(hole), "RH12 splash skips the masked hole and hits the site")
	var targets: Array = []
	for i in range(20):
		sim.step()
		for event in sim.snapshot().combat_events:
			if event.type == "shot" and event.attacker_id == shooter: targets.append(event.target_id)
	runner.check(not targets.is_empty() and targets.all(func(t: int) -> bool: return t != hole), "RH12 guards in reach fire at the site, never the hole")
	runner.check(targets.has(site), "RH12 the site is shot at")
	return true

func _doomed_laborer(work: int) -> RefCounted:
	var sim = _masked()
	for i in range(5): sim.step()
	sim._buildings[_site(sim).id].work = work
	var worker: int = _laborer(sim).id
	sim._entities[worker].hp = 1
	var shooter: int = _rifleman(sim, Vector2(8.5, 10.5))
	Fixture.send(sim, {"type": "attack", "player": 2, "entity_ids": [shooter], "target_id": worker})
	return sim

func test_site_completes_before_worker_dies(runner) -> bool:
	var control = _doomed_laborer(100000)
	control.step()
	runner.check(_deaths(control) == 1 and _hole(control).rebuild.worker_id == null, "RH13 control: the shot kills a laborer that is not about to finish")
	var sim = _doomed_laborer(299000)
	var site: Dictionary = _site(sim)
	var before: int = sim._buildings[site.id].work
	sim.step()
	runner.check(sim.snapshot().buildings.size() == 1 and sim.snapshot().buildings[0].completed and _holes(sim).is_empty(), "RH13 the building completes the tick its laborer would die (work %d)" % before)
	runner.check(sim.snapshot().entities.size() == 1 and _laborer(sim).is_empty() and _deaths(sim) == 0, "RH13 the laborer is gone silently, only the shooter is left")
	return true

func test_hole_masks_on_spawn_tick(runner) -> bool:
	var sim = _destroyed()[0]
	sim.step()
	while sim.tick() < _hole(sim).rebuild.respawn_tick: sim.step()
	var hole: int = _hole(sim).id
	sim._buildings[hole].hp = 400000
	var shooter: int = _rifleman(sim, Vector2(10.5, 14.5))
	runner.check(Fixture.send(sim, {"type": "attack", "player": 2, "entity_ids": [shooter], "target_id": hole}).ok, "RH14 attack on a hole due this tick validates")
	sim.step()
	var result: Dictionary = sim.snapshot().command_results.filter(func(r: Dictionary) -> bool: return r.player == 2)[0]
	runner.check(result.ok, "RH14 and applies")
	runner.check(Combat.masked(_hole(sim)) and _hole(sim).hp == 400083, "RH14 the hole is masked the same tick and took no damage")
	runner.check(EconomyFixture.object(sim, shooter).combat.target_id != hole and sim.snapshot().combat_events.all(func(e: Dictionary) -> bool: return e.type != "shot" or e.target_id != hole), "RH14 the attacker lost the target and never fired at the hole")
	var next: Dictionary = Fixture.send(sim, {"type": "attack", "player": 2, "entity_ids": [shooter], "target_id": hole})
	runner.check(not next.ok and next.error == "Invalid attack target", "RH14 the next attack is rejected")
	var shots: Array = []
	for i in range(10):
		sim.step()
		for event in sim.snapshot().combat_events:
			if event.type == "shot": shots.append(event.target_id)
	runner.check(shots.has(_site(sim).id) and not shots.has(hole), "RH14 guards fire at the site instead")
	return true

func test_hole_same_tick_cases(runner) -> bool:
	var sim = _masked()
	var tick: int = sim.tick()
	var cancel: Dictionary = Fixture.send(sim, {"type": "cancel_build", "building_id": _site(sim).id})
	sim.step()
	runner.check(cancel.ok and _site(sim).is_empty() and _laborer(sim).is_empty() and not Combat.masked(_hole(sim)) and _hole(sim).rebuild.respawn_tick == tick + RESPAWN, "RH15 cancel_build on a freshly arrived laborer: orders first, the hole restarts")
	var queue = _world()
	var cache: int = EconomyFixture.add_completed(queue, 1, "frc_supply_center", BARRACKS)
	queue._buildings[cache].hp = 1000
	_rifleman(queue, Vector2(8.5, 10.5))
	runner.check(Fixture.send(queue, {"type": "produce", "building_id": cache, "unit_kind": "frc_builder"}).ok, "RH15 produce accepted")
	for i in range(10):
		queue.step()
		if queue.snapshot().buildings.any(func(b: Dictionary) -> bool: return b.id == cache): continue
		break
	runner.check(_hole(queue).get("rebuild", {}).get("kind") == "frc_supply_center" and queue.snapshot().players[0].credits == 10000, "RH15 produce at a building that dies: queue refunded, hole opened")
	return true

func test_site_and_second_laborer_die_together(runner) -> bool:
	var sim = _masked()
	sim.remove_object(_laborer(sim).id)
	_step_to_respawn(sim)
	sim.step()
	var site: int = _site(sim).id
	var worker: int = _laborer(sim).id
	sim._buildings[site].hp = 1
	sim._entities[worker].hp = 1
	for target in [site, worker]:
		var shooter: int = _rifleman(sim, Vector2(8.5, 10.5 + (0.0 if target == site else 2.0)))
		Fixture.send(sim, {"type": "attack", "player": 2, "entity_ids": [shooter], "target_id": target})
	var tick: int = sim.tick()
	var deaths: Array = []
	for i in range(40):
		tick = sim.tick()
		sim.step()
		deaths.append_array(sim.snapshot().combat_events.filter(func(e: Dictionary) -> bool: return e.type == "death"))
		if not deaths.is_empty(): break
	runner.check(worker > site and deaths.size() == 1 and deaths[0].object_id == site, "RH16 one death event, the site, got " + str(deaths))
	runner.check(_site(sim).is_empty() and _laborer(sim).is_empty() and not Combat.masked(_hole(sim)) and _hole(sim).rebuild.respawn_tick == tick + RESPAWN, "RH16 hole unmasked, respawn timer restarted")
	return true
