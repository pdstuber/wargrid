extends RefCounted

const OnlineScene = preload("res://scenes/online_skirmish.tscn")
const Launcher = preload("res://scenes/launcher.tscn")
const LauncherScript = preload("res://scripts/launcher.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const Wire = preload("res://scripts/net/wire.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const PEER_TICKS: int = 60

class FakeTransport extends RefCounted:
	var frames := PackedStringArray()
	var sent: Array[String] = []
	var is_closed: bool = false
	var is_silent: bool = false
	var close_calls: int = 0
	func poll() -> PackedStringArray:
		var out := frames
		frames = PackedStringArray()
		return out
	func send_text(text: String) -> void: sent.append(text)
	func closed() -> bool: return is_closed
	func silent(_now: int) -> bool: return is_silent
	func close() -> void: close_calls += 1
	func rtt_samples() -> PackedInt64Array: return PackedInt64Array([40000])

func cases() -> Array[Callable]:
	return [test_seat_two_controls_player_two, test_status_lines_and_layout, test_match_end_reports_latency, test_launcher_layout]

func _online(runner, seat: int) -> Dictionary:
	var transport := FakeTransport.new()
	var seats: Array[int] = [1, 2]
	var lockstep = Lockstep.new(seat, seats)
	var main = OnlineScene.instantiate()
	main.setup(transport, lockstep, seat)
	runner.root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await runner.process_frame
	return {"main": main, "transport": transport, "lockstep": lockstep}

func _peer_packets(transport: FakeTransport, peer: int, from_tick: int, to_tick: int) -> void:
	for tick in range(from_tick, to_tick + 1):
		transport.frames.append(Wire.encode(Wire.tick_message(peer, tick, [], null)))

func _run(main, frames: int) -> void:
	for i in frames: main._physics_process(0.0)

func _entity(main, id: int) -> Dictionary:
	for unit in main.simulation.snapshot().entities:
		if unit.id == id: return unit
	return {}

func _own_commands(transport: FakeTransport) -> Array:
	var commands: Array = []
	for text in transport.sent:
		commands.append_array(Wire.decode(text).message.get("commands", []))
	return commands

func _layout_ok(runner, main, label: String) -> void:
	var status: Label = main.get_node("HUD/Status")
	var economy: Control = main.get_node("HUD/Economy")
	runner.check(economy.position.y >= status.position.y + status.get_minimum_size().y, "N3 buttons sit below every status line: " + label)
	runner.check(not main.get_node("HUD/Restart").visible, "N3 Restart hidden: " + label)

func test_seat_two_controls_player_two(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	var view = main.get_node("WorldView")
	var mine: Dictionary = _entity(main, 2)
	var theirs: Dictionary = _entity(main, 1)
	runner.check(mine.owner == 2 and theirs.owner == 1, "N1 fixture: entity 2 is player 2's builder")
	var mine_plane: Vector2 = Iso.world_to_plane(Vector2(mine.position[0], mine.position[1])) + Vector2(0, -8)
	var theirs_plane: Vector2 = Iso.world_to_plane(Vector2(theirs.position[0], theirs.position[1])) + Vector2(0, -8)
	runner.check(view.pick_entity(mine_plane) == 2, "N1 seat 2 picks its own unit")
	runner.check(view.pick_entity(theirs_plane) == -1, "N1 seat 2 cannot select player 1's unit")
	main.selected_ids.assign([2])
	main._move(Vector2(40.5, 10.5))
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(main, 20)
	var commands: Array = _own_commands(online.transport)
	runner.check(commands.size() == 1 and commands[0].type == "move" and commands[0].player == 2, "N1 move leaves as a player 2 command, got " + str(commands))
	runner.check(_entity(main, 2).order != null, "N1 the move order reached player 2's builder through lockstep")
	runner.check(main.simulation.tick() > 4 and online.lockstep.status() == "running", "N1 ticks advance with peer packets")
	main.free()
	var seat1: Dictionary = await _online(runner, 1)
	seat1.main.selected_ids.assign([1])
	seat1.main._move(Vector2(10.5, 14.5))
	_peer_packets(seat1.transport, 2, 4, 12)
	_run(seat1.main, 6)
	runner.check(_own_commands(seat1.transport).all(func(command: Dictionary) -> bool: return command.player == 1) and not _own_commands(seat1.transport).is_empty(), "N1 seat 1 commands carry player 1")
	seat1.main.free()
	return true

func test_status_lines_and_layout(runner) -> bool:
	var waiting: Dictionary = await _online(runner, 2)
	_run(waiting.main, 12)
	runner.check(waiting.lockstep.status() == "waiting" and waiting.main.get_node("HUD/Status").text.contains("Waiting for player 1"), "N2 waiting line")
	_layout_ok(runner, waiting.main, "waiting")
	waiting.main.free()
	var left: Dictionary = await _online(runner, 2)
	left.transport.frames.append(Wire.encode({"type": "left", "seat": 1, "after_tick": 4}))
	_run(left.main, 12)
	runner.check(left.main.get_node("HUD/Status").text.contains("Player 1 disconnected"), "N2 left line")
	_layout_ok(runner, left.main, "left")
	left.main.free()
	var lost: Dictionary = await _online(runner, 2)
	lost.transport.is_closed = true
	_run(lost.main, 2)
	runner.check(lost.main.get_node("HUD/Status").text.contains("Connection to relay lost"), "N2 relay lost line")
	_layout_ok(runner, lost.main, "relay lost")
	lost.main.free()
	var silent: Dictionary = await _online(runner, 2)
	silent.transport.is_silent = true
	_run(silent.main, 2)
	runner.check(silent.lockstep.status() == "ended_relay" and silent.lockstep.end_reason() == "connection to relay lost", "N2 silent relay ends the match with the relay-lost reason")
	silent.main.free()
	var desync: Dictionary = await _online(runner, 2)
	desync.transport.frames.append(Wire.encode(Wire.tick_message(1, 4, [], {"tick": 0, "value": "0000000000000000"})))
	_run(desync.main, 12)
	var text: String = desync.main.get_node("HUD/Status").text
	runner.check(desync.lockstep.status() == "ended_desync" and text.contains("Desync — report saved to") and FileAccess.file_exists("user://desync/desync-seat2.json"), "N2 desync line and report file, got " + text)
	_layout_ok(runner, desync.main, "desync")
	DirAccess.remove_absolute("user://desync/desync-seat2.json")
	desync.main.free()
	return true

func test_match_end_reports_latency(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	main.simulation.remove_object(1)
	main.simulation.remove_object(2)
	_run(main, 2)
	runner.check(online.transport.close_calls == 1, "N4 transport closed once at match end")
	runner.check(main.latency_line().contains("RTT n=1 p95=40.0 ms"), "N4 latency line carries RTT p95, got " + main.latency_line())
	runner.check(FileAccess.file_exists("user://netplay-latency.txt"), "N4 latency file written")
	main.free()
	return true

func test_launcher_layout(runner) -> bool:
	var original: Vector2i = runner.root.size
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		runner.root.size = size
		var launcher = Launcher.instantiate()
		runner.root.add_child(launcher)
		await runner.process_frame
		await runner.process_frame
		var rects: Array[Rect2] = []
		for path in ["Title", "Offline", "RelayUrl", "Create", "JoinRow/Code", "JoinRow/Join", "Status"]:
			var control: Control = launcher.get_node("Center/Box/" + path)
			rects.append(control.get_global_rect())
			runner.check(Rect2(Vector2.ZERO, Vector2(size)).encloses(control.get_global_rect()), "N5 %s inside %s" % [path, size])
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				runner.check(not rects[i].intersects(rects[j]), "N5 controls %d and %d do not overlap at %s" % [i, j, size])
		launcher.free()
	runner.root.size = original
	var offline = load(LauncherScript.OFFLINE_SCENE).instantiate()
	runner.check(offline.get_script().resource_path == "res://scripts/skirmish_main.gd", "N5 Play offline loads the offline skirmish")
	offline.free()
	return true
