@warning_ignore_start("untyped_declaration")
extends RefCounted

const Director = preload("res://scripts/presentation/sound_director.gd")
const Fixture = preload("res://tests/combat_fixture.gd")
const OnlineTests = preload("res://tests/test_online_scene.gd")

func cases() -> Array[Callable]:
	return [test_catch_up_collects_every_step, test_collect_step_copies, test_stalled_tick_is_collected_once, test_event_accessors_are_live]

func test_catch_up_collects_every_step(runner) -> bool:
	var suite = OnlineTests.new()
	var online: Dictionary = await suite._online(runner, 1)
	var main = online.main
	suite._run(main, 10)
	var before: int = main.simulation.tick()
	suite._peer_packets(online.transport, 2, before, before + 3)
	suite._run(main, 1)
	var ticks: Array[int] = main._sound.director.collected_ticks()
	runner.check(main.simulation.tick() == before + 2, "SD1 frame advanced two ticks, got %d" % (main.simulation.tick() - before))
	runner.check(ticks.slice(-2) == [before + 1, before + 2], "SD1 collected ticks %s lack t+1 in a two-step frame" % [ticks])
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
