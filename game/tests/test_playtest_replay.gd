@warning_ignore_start("untyped_declaration")
extends RefCounted

const Scene = preload("res://scenes/skirmish.tscn")
const CommandRecorder = preload("res://scripts/playtest/command_recorder.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Client = preload("res://scripts/net/headless_client.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const Wire = preload("res://scripts/net/wire.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const SkirmishMain = preload("res://scripts/match/match_screen.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")

const STEPS: int = 600
const MOVE_STEP: int = 30

class OracleClient extends Client:
	func _exit() -> void:
		pass

func cases() -> Array[Callable]:
	return [test_recorder_logs_accepted_commands, test_bot_through_recorder_keeps_memory, test_log_lines_format, test_offline_scene_replays_to_same_digest, test_restart_starts_new_record, test_oracle_factions_arg, test_oracle_state_rows, test_oracle_ring_log]

func _stop(sim, sequence: int, tick: int = 0) -> Dictionary:
	var builder: int = sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.owner == 1)[0].id
	return {"type": "stop", "entity_ids": [builder], "tick": tick, "player": 1, "sequence": sequence}

func test_recorder_logs_accepted_commands(runner) -> bool:
	var sim = Skirmish.create(true, "ai", {1: "usa", 2: "china"})
	var recorder = CommandRecorder.new(sim)
	runner.check(recorder.issue_command(_stop(sim, 0)).ok, "RP1 a valid stop is accepted")
	runner.check(recorder.commands().size() == 1, "RP1 the accepted command is recorded")
	runner.check(not recorder.issue_command(_stop(sim, 0)).ok, "RP1 the same sequence is rejected")
	runner.check(recorder.commands().size() == 1, "RP1 a rejected command is not recorded")
	runner.check(is_same(recorder.simulation(), sim), "RP1 simulation() is the wrapped simulation")
	runner.check(recorder.tick() == 0 and recorder.snapshot() == sim.snapshot() and recorder.map_data() == sim.map_data(), "RP1 reads pass through")
	return true

func test_bot_through_recorder_keeps_memory(runner) -> bool:
	var sim = Skirmish.create(true, "ai", {1: "usa", 2: "china"})
	var recorder = CommandRecorder.new(sim)
	Skirmish.issue_opponents(recorder, [2] as Array[int], 0)
	runner.check(sim.has_meta(Skirmish.BOT_META), "RP2 the bot keeps its memory on the real simulation")
	var commands: Array[Dictionary] = recorder.commands()
	runner.check(not commands.is_empty() and commands.all(func(command: Dictionary) -> bool: return command.player == 2), "RP2 only player 2 commands are recorded, got %d" % commands.size())
	return true

func test_log_lines_format(runner) -> bool:
	var rows: Array[Dictionary] = [
		{"type": "stop", "tick": 3, "player": 1, "sequence": 0, "entity_ids": [1]},
		{"type": "stop", "tick": 3, "player": 2, "sequence": 0, "entity_ids": [3]},
		{"type": "stop", "tick": 5, "player": 1, "sequence": 1, "entity_ids": [1]}]
	var lines: PackedStringArray = Lockstep.log_lines(rows)
	runner.check(lines.size() == 2, "RP3 one line per tick, got %d" % lines.size())
	var decoded: Dictionary = Wire.decode(lines[0])
	runner.check(decoded.ok and decoded.message.seat == 0 and decoded.message.tick == 3, "RP3 first line is tick 3, seat 0")
	runner.check(decoded.ok and decoded.message.commands.size() == 2 and decoded.message.commands[0].player == 1 and decoded.message.commands[1].player == 2, "RP3 both commands in order")
	return true

func _step_main(main, steps: int, on_step: Callable = Callable()) -> void:
	for i in steps:
		if on_step.is_valid(): on_step.call(i)
		main._physics_process(1.0 / 30.0)

func _scene(runner, factions: Dictionary, map_id: String, seed_value: int):
	SkirmishMain.factions = factions
	SkirmishMain.map_path = MatchSettings.map_path(map_id)
	SkirmishMain.match_seed = seed_value
	SkirmishMain.starts = MatchSettings.starts(map_id, seed_value)
	var main = Scene.instantiate()
	runner.root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await runner.process_frame
	return main

func _send_move(i: int, main) -> void:
	if i != MOVE_STEP: return
	var builder: Dictionary = main.driver.sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.owner == 1)[0]
	var size: Array = main.driver.sim.snapshot().map.size
	var target := Vector2(size[0] / 2.0, size[1] / 2.0)
	if Vector2(builder.position[0], builder.position[1]).distance_to(target) < 10.0: target = Vector2(2.5, 2.5)
	main.orders.selected_ids.assign([builder.id])
	main._submit({"type": "move", "entity_ids": [builder.id], "target": [target.x, target.y]})

func _replay(lines: PackedStringArray, args: Dictionary):
	var log_path := "user://rp-replay-%d.log" % OS.get_process_id()
	var file := FileAccess.open(log_path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	var client = OracleClient.new()
	var full := {"replay-log": log_path}
	full.merge(args)
	client._args = full
	client._replay_oracle()
	DirAccess.remove_absolute(log_path)
	return client

func test_offline_scene_replays_to_same_digest(runner) -> bool:
	var before := [SkirmishMain.factions, SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	var main = await _scene(runner, {1: "frc", 2: "china"}, "dry_wells", 7)
	_step_main(main, STEPS, _send_move.bind(main))
	var record: Dictionary = main.playtest_match()
	runner.check(record.mode == "offline" and record.map == "dry_wells" and record.seed == 7, "RP4 record names mode, map and seed")
	runner.check(record.factions == ["frc", "china"] and record.seat == 1, "RP4 record names factions and seat")
	runner.check(record.build == PlaytestSettings.build_id(), "RP4 record names its build, got %s" % record.get("build"))
	runner.check(record.end_tick == STEPS, "RP4 end tick is %d, got %d" % [STEPS, record.end_tick])
	runner.check(record.end_digest == StateHash.digest(main.driver.sim.snapshot()), "RP4 end digest is the live digest")
	var lines: PackedStringArray = record.commands
	var players: Dictionary = {}
	for line in lines:
		for command in Wire.decode(line).message.commands: players[command.player] = true
	runner.check(players.has(1) and players.has(2), "RP4 lines hold commands of both players, got %s" % str(players.keys()))
	var args := {"map": "dry_wells", "seed": "7", "factions": "frc,china", "oracle-ticks": str(STEPS)}
	var client = _replay(lines, args)
	runner.check(client._sim.tick() == STEPS, "RP4 the oracle reaches tick %d" % STEPS)
	runner.check(StateHash.digest(client._sim.snapshot()) == record.end_digest, "RP4 the oracle replays to the recorded digest")
	client.free()
	var without := PackedStringArray()
	for line in lines:
		var message: Dictionary = Wire.decode(line).message
		var kept: Array = message.commands.filter(func(command: Dictionary) -> bool: return not (command.player == 1 and command.type == "move"))
		if not kept.is_empty(): without.append(Wire.encode(Wire.tick_message(0, message.tick, kept, null)))
	client = _replay(without, args)
	runner.check(StateHash.digest(client._sim.snapshot()) != record.end_digest, "RP4 a dropped command line changes the digest")
	client.free()
	main.free()
	SkirmishMain.factions = before[0]
	SkirmishMain.map_path = before[1]
	SkirmishMain.starts = before[2]
	SkirmishMain.match_seed = before[3]
	return true

func test_restart_starts_new_record(runner) -> bool:
	var before := [SkirmishMain.factions, SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	var main = await _scene(runner, {1: "usa", 2: "china"}, "dry_wells", 3)
	_step_main(main, 30, _send_move.bind(main))
	runner.check(main.playtest_match().end_tick == 30, "RP5 30 steps recorded before the restart")
	main._restart()
	var record: Dictionary = main.playtest_match()
	runner.check(record.commands.is_empty() and record.end_tick == 0, "RP5 a restart starts an empty record at tick 0")
	main.free()
	SkirmishMain.factions = before[0]
	SkirmishMain.map_path = before[1]
	SkirmishMain.starts = before[2]
	SkirmishMain.match_seed = before[3]
	return true

func test_oracle_factions_arg(runner) -> bool:
	var client = _replay(PackedStringArray(), {"factions": "frc,china", "oracle-ticks": "1"})
	var state: Dictionary = client._sim.snapshot()
	runner.check(state.match.status == "ongoing", "RP6 --factions starts the match, got %s" % state.match.status)
	runner.check(state.players.map(func(player: Dictionary) -> String: return player.faction) == ["frc", "china"], "RP6 --factions sets both factions")
	client.free()
	client = _replay(PackedStringArray(), {"oracle-ticks": "1"})
	runner.check(client._sim.snapshot().match.status != "ongoing", "RP6 without --factions the match waits for faction choices")
	client.free()
	client = OracleClient.new()
	client._args = {"factions": "frc,nope"}
	runner.check(client._faction_error() != "", "RP6 an unknown --factions entry is refused")
	client._args = {"factions": "frc,china"}
	runner.check(client._faction_error() == "", "RP6 known --factions entries pass")
	client.free()
	return true

func test_oracle_state_rows(runner) -> bool:
	var dir := "user://rp-state-%d" % OS.get_process_id()
	var client = _replay(PackedStringArray(), {"state-ticks": "0,30,31", "oracle-ticks": "31", "snapshot-dir": dir})
	runner.check(client.state_rows.size() == 3, "RP7 three state rows, got %d" % client.state_rows.size())
	runner.check(client.state_rows.size() == 3 and client.state_rows[0].begins_with("ORACLE STATE 0 ") and client.state_rows[1].begins_with("ORACLE STATE 30 ") and client.state_rows[2].begins_with("ORACLE STATE 31 "), "RP7 rows name their ticks, the end tick included")
	var path := "%s/tick-30.json" % dir
	runner.check(FileAccess.file_exists(path), "RP7 the snapshot file exists")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	runner.check(parsed is Dictionary and int(parsed.tick) == 30, "RP7 the snapshot file is tick 30")
	var summary: Variant = JSON.parse_string(Client.state_summary(client._sim.snapshot()))
	runner.check(summary is Dictionary and summary.has("match") and summary.has("players") and summary.has("units") and summary.has("buildings"), "RP7 summary has match, players, units, buildings")
	for file_name in ["tick-0.json", "tick-30.json", "tick-31.json"]: DirAccess.remove_absolute("%s/%s" % [dir, file_name])
	DirAccess.remove_absolute(dir)
	client.free()
	return true

func test_oracle_ring_log(runner) -> bool:
	var path := "user://rp-ring-%d.tsv" % OS.get_process_id()
	var client = _replay(PackedStringArray(), {"ring-log": path, "oracle-ticks": "5"})
	var rows: PackedStringArray = FileAccess.get_file_as_string(path).split("\n", false)
	runner.check(rows.size() == 5, "RP8 one ring row per tick, got %d" % rows.size())
	runner.check(rows.size() == 5 and rows[0].begins_with("1\t") and rows[4] == client._sim.hash_ring()[-1], "RP8 rows run from tick 1 to the live ring's last row")
	DirAccess.remove_absolute(path)
	client.free()
	return true
