@warning_ignore_start("untyped_declaration")
extends RefCounted

const OnlineScene = preload("res://scenes/skirmish.tscn")
const Launcher = preload("res://scenes/launcher.tscn")
const LauncherScript = preload("res://scripts/launcher.gd")
const LauncherSettings = preload("res://scripts/launcher_settings.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const SkirmishMain = preload("res://scripts/match/match_screen.gd")
const BaseScene = preload("res://tests/test_base_scene.gd")
const IcRows = preload("res://tests/input_script_rows.gd")
const JoinLink = preload("res://scripts/join_link.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const Wire = preload("res://scripts/net/wire.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
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
	func close() -> void:
		close_calls += 1
		is_closed = true
	func rtt_samples() -> PackedInt64Array: return PackedInt64Array([40000])

func cases() -> Array[Callable]:
	return [test_seat_two_controls_player_two, test_status_lines_and_layout, test_rejection_line, test_funds_rejection_is_announced, test_overlay_net_line, test_match_end_reports_latency, test_runs_at_tick_rate, test_catch_up_is_bounded, test_two_tick_frame_keeps_earlier_results, test_stall_frames_are_not_step_frames, test_notices_reach_the_hud_while_processing, test_launcher_sections, test_launcher_faction_rows, test_plays_dry_wells_from_each_seat, test_offline_uses_chosen_map, test_online_start_saves_picks, test_restart_keeps_map_and_starts, test_restart_drops_old_stepped_results, test_joiner_refuses_other_map, test_old_relay_mismatch_is_shown, test_cancel_and_copy_while_waiting, test_start_without_settings_is_a_protocol_error, test_both_seats_share_map_and_starts, test_host_told_opponent_left_before_start, test_credits_panel_layout, test_online_playtest_record, test_launcher_release_hides_relay, test_launcher_prefills_from_page, test_launcher_relay_help, test_copy_link_on_web, test_launcher_reads_no_page_off_web, test_input_script_online]

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
		var commands: Array = [{"type": "choose_faction", "faction": "usa", "tick": 4, "player": peer, "sequence": 0}] if tick == 4 else []
		transport.frames.append(Wire.encode(Wire.tick_message(peer, tick, commands, null)))

func _run(main, frames: int) -> void:
	for i in frames: main._physics_process(0.0)

func _entity(main, id: int) -> Dictionary:
	for unit in main.driver.sim.snapshot().entities:
		if unit.id == id: return unit
	return {}

func _own_commands(transport: FakeTransport) -> Array:
	var commands: Array = []
	for text in transport.sent:
		commands.append_array(Wire.decode(text).message.get("commands", []).filter(func(command: Dictionary) -> bool: return command.type != "choose_faction"))
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
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(main, 8)
	var mine: Dictionary = _entity(main, 5)
	var theirs: Dictionary = _entity(main, 3)
	runner.check(mine.owner == 2 and theirs.owner == 1, "N1 fixture: entity 5 is player 2's builder")
	var mine_plane: Vector2 = Iso.world_to_plane(Vector2(mine.position[0], mine.position[1])) + Vector2(0, -8)
	var theirs_plane: Vector2 = Iso.world_to_plane(Vector2(theirs.position[0], theirs.position[1])) + Vector2(0, -8)
	runner.check(view.pick_entity(mine_plane) == 5, "N1 seat 2 picks its own unit")
	runner.check(view.pick_entity(theirs_plane) == -1, "N1 seat 2 cannot select player 1's unit")
	main.orders.selected_ids.assign([5])
	main.orders._move(Vector2(40.5, 10.5))
	_run(main, 20)
	var commands: Array = _own_commands(online.transport)
	runner.check(commands.size() == 1 and commands[0].type == "move" and commands[0].player == 2, "N1 move leaves as a player 2 command, got " + str(commands))
	runner.check(_entity(main, 5).order != null, "N1 the move order reached player 2's builder through lockstep")
	runner.check(main.driver.sim.tick() > 4 and online.lockstep.status() == "running", "N1 ticks advance with peer packets")
	main.free()
	var seat1: Dictionary = await _online(runner, 1)
	seat1.main.orders.selected_ids.assign([3])
	seat1.main.orders._move(Vector2(10.5, 14.5))
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
	var before_seed: int = SkirmishMain.match_seed
	SkirmishMain.match_seed = 7
	var desync: Dictionary = await _online(runner, 2)
	SkirmishMain.match_seed = before_seed
	desync.transport.frames.append(Wire.encode(Wire.tick_message(1, 4, [], {"tick": 0, "value": "0000000000000000"})))
	_run(desync.main, 12)
	var text: String = desync.main.get_node("HUD/Status").text
	runner.check(desync.lockstep.status() == "ended_desync" and text.contains("Desync — report saved to") and FileAccess.file_exists("user://desync/desync-seat2.json"), "N2 desync line and report file, got " + text)
	var report = JSON.parse_string(FileAccess.get_file_as_string("user://desync/desync-seat2.json"))
	runner.check(report is Dictionary and report.get("seed") == 7 and report.get("map") == SkirmishMain.map_path.get_file().get_basename() and report.get("starts") == SkirmishMain.starts and not report.get("hash_ring", []).is_empty(), "N2 desync report carries the screen's seed, map, starts and the sim's hash ring, got " + str(report))
	_layout_ok(runner, desync.main, "desync")
	DirAccess.remove_absolute("user://desync/desync-seat2.json")
	desync.main.free()

	var web_desync: Dictionary = await _online(runner, 2)
	var downloads: Array = []
	web_desync.main.driver.web = true
	web_desync.main.driver.download = func(buffer: PackedByteArray, file_name: String, mime: String) -> void: downloads.append([buffer.size(), file_name, mime])
	web_desync.transport.frames.append(Wire.encode(Wire.tick_message(1, 4, [], {"tick": 0, "value": "0000000000000000"})))
	_run(web_desync.main, 12)
	var web_text: String = web_desync.main.get_node("HUD/Status").text
	runner.check(downloads.size() == 1 and downloads[0][0] > 0 and downloads[0][1] == "desync-seat2.json" and web_text.contains("report downloaded as desync-seat2.json") and not FileAccess.file_exists("user://desync/desync-seat2.json"), "N2w web desync downloads the report and writes no file, got " + web_text)
	web_desync.main.free()
	return true

func test_match_end_reports_latency(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(main, 8)
	runner.check(main.driver.sim.snapshot().match.status == "ongoing", "N4 fixture: the match started")
	main.driver.sim.remove_object(4)
	main.driver.sim.remove_object(6)
	_run(main, 2)
	runner.check(online.transport.close_calls == 1, "N4 transport closed once at match end")
	runner.check(main.driver.latency_line().contains("RTT n=1 p95=40.0 ms"), "N4 latency line carries RTT p95, got " + main.driver.latency_line())
	runner.check(FileAccess.file_exists("user://netplay-latency.txt"), "N4 latency file written")
	_run(main, 2)
	runner.check(online.lockstep.status() != "ended_relay" and main.driver.notice() == "", "N4 own close after the match is not a relay loss, got " + main.driver.notice())
	main.free()
	return true

func test_runs_at_tick_rate(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(online.main, 20)
	runner.check(online.main.driver.sim.tick() <= 20, "N5 never faster than one tick per physics frame, got %d" % online.main.driver.sim.tick())
	runner.check(online.main.driver.sim.tick() >= 19, "N5 keeps pace when packets are available, got %d" % online.main.driver.sim.tick())
	online.main.free()
	return true

func test_catch_up_is_bounded(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	_run(online.main, 10)
	runner.check(online.main.driver.sim.tick() == 4, "N5 waits for the first peer packet, got %d" % online.main.driver.sim.tick())
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(online.main, 1)
	runner.check(online.main.driver.sim.tick() == 6, "N5 catch-up is two ticks per frame, got %d" % online.main.driver.sim.tick())
	_run(online.main, 19)
	var tick: int = online.main.driver.sim.tick()
	runner.check(tick > 24 and tick <= 24 + online.main.driver.MAX_CATCH_UP_CREDIT, "N5 catch-up debt is capped, got %d" % tick)
	online.main.free()
	return true

const DUE_REJECTION: String = "Footprint outside map or overlaps obstacle"

func _double_build(online: Dictionary) -> void:
	var order := {"type": "build", "builder_id": 3, "building_kind": "usa_power_plant", "origin": [10, 10]}
	online.main.driver.submit(order)
	online.main.driver.submit(order)

func test_two_tick_frame_keeps_earlier_results(runner) -> bool:
	var control: Dictionary = await _online(runner, 1)
	_double_build(control)
	_peer_packets(control.transport, 2, 4, PEER_TICKS)
	_run(control.main, 6)
	runner.check(control.main.get_node("HUD/Status").text.contains(DUE_REJECTION), "N27 control: a one-tick frame shows the own due-time rejection")
	control.main.free()
	var online: Dictionary = await _online(runner, 1)
	_double_build(online)
	_run(online.main, 10)
	_peer_packets(online.transport, 2, 4, 4)
	_run(online.main, 1)
	_peer_packets(online.transport, 2, 5, PEER_TICKS)
	_run(online.main, 1)
	runner.check(online.main.driver.sim.tick() == 7, "N27 fixture: the frame advanced ticks 5 and 6, got %d" % online.main.driver.sim.tick())
	runner.check(online.main.get_node("HUD/Status").text.contains(DUE_REJECTION), "N27 a two-tick frame keeps the earlier tick's own rejection")
	online.main.free()
	return true

func test_stall_frames_are_not_step_frames(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	_run(main, 10)
	main.set_process(true)
	_run(main, 3)
	await runner.process_frame
	await runner.process_frame
	runner.check(main.driver.sim.tick() == 4 and main._clock.split_share() == 0.0, "N5 stall frames neither count as step frames nor refresh, got tick %d share %s" % [main.driver.sim.tick(), main._clock.split_share()])
	_peer_packets(online.transport, 1, 4, PEER_TICKS)
	_run(main, 1)
	await runner.process_frame
	await runner.process_frame
	runner.check(main._clock.split_share() == 1.0, "N5 an advancing frame still splits, got %s" % main._clock.split_share())
	main.free()
	return true

func test_notices_reach_the_hud_while_processing(runner) -> bool:
	var waiting: Dictionary = await _online(runner, 2)
	waiting.main.set_process(true)
	_run(waiting.main, 6)
	runner.check(waiting.main.get_node("HUD/Status").text.contains("Waiting for player 1"), "N2 waiting line shows while processing")
	runner.check(waiting.main._clock.split_share() == 0.0, "N2 notice refresh leaves the clock alone")
	waiting.transport.is_closed = true
	_run(waiting.main, 3)
	runner.check(waiting.main.get_node("HUD/Status").text.contains("Connection to relay lost"), "N2 ended match shows its message while processing")
	waiting.main.free()
	return true

const LAUNCHER_PAGE_PATHS: Dictionary = {
	"Play:bot": ["Title", "Subtitle", "Body/OwnLabel", "Body/MapLabel", "Body/Own", "Body/Map", "Body/OpponentLabel", "Body/MapInfo", "Body/Opponent", "Body/BotLabel", "Body/Bot", "ThisBuild", "Footer/Status", "Footer/Start"],
	"Play:friend": ["Title", "Subtitle", "Body/OwnLabel", "Body/MapLabel", "Body/Own", "Body/Map", "Body/OpponentLabel", "Body/MapInfo", "Body/Opponent", "Body/OpenSlot", "Body/Advanced/Toggle", "Body/Advanced/RelayHelp", "Body/Advanced/RelayUrl", "ThisBuild", "Footer/Status", "Footer/Create"],
	"Join": ["Title", "Subtitle", "Body/CodeLabel", "Body/MapLabel", "Body/Code", "Body/MapHint", "Body/CodeHint", "Body/OwnLabel", "Body/Own", "Body/Advanced/Toggle", "Body/Advanced/RelayHelp", "Body/Advanced/RelayUrl", "ThisBuild", "Footer/Status", "Footer/Join"],
	"Settings": ["Title", "Subtitle", "Body/Audio/AudioHeader", "Body/Audio/Volume/MusicLabel", "Body/Audio/Volume/Music", "Body/Audio/Volume/MusicValue", "Body/Audio/Volume/EffectsLabel", "Body/Audio/Volume/Effects", "Body/Audio/Volume/EffectsValue", "Body/Audio/Volume/VoiceLabel", "Body/Audio/Volume/Voice", "Body/Audio/Volume/VoiceValue", "Body/Audio/Volume/MuteLabel", "Body/Audio/Volume/Mute", "Body/Audio/DisplayHeader", "Body/Audio/Fullscreen", "Body/Playtest/GraphicsHeader", "Body/Playtest/Quality", "Body/Playtest/Neon", "Body/Playtest/Smooth", "Body/Playtest/Destinations", "Body/Playtest/PlaytestHeader", "Body/Playtest/PlaytestSwitch", "Body/Playtest/PlaytestHint"],
	"Credits": ["Title", "Subtitle", "Body/Text", "Body/Legal"],
	"Waiting": ["Title", "Subtitle", "Body/Left/Invite/Link", "Body/Left/Invite/Copy", "Body/Left/One", "Body/Left/Two", "Body/Right/Map", "Footer/Status", "Footer/Cancel"],
}
const LAUNCHER_NAV_ORDER: Array[String] = ["Play", "Join", "Divider", "Settings", "Credits"]
const PAGE_TITLES: Dictionary = {"Play": "Play", "Join": "Join a match", "Settings": "Settings", "Credits": "Credits", "Waiting": "Waiting for your friend"}

func _force_visible(launcher: Node) -> void:
	launcher.set_opponent("friend")
	for page_name: String in ["Play", "Join"]: launcher.get_node("Pages/%s/ThisBuild" % page_name).visible = true

func _page_controls_ok(runner, launcher: Node, size: Vector2i, id: String, skip: Array = []) -> void:
	var view := Rect2(Vector2.ZERO, Vector2(size))
	var content: Control = launcher.get_node("Pages")
	var opponent: String = launcher.opponent
	for key: String in LAUNCHER_PAGE_PATHS:
		var page_name: String = key.get_slice(":", 0)
		if ":" in key: launcher.set_opponent(key.get_slice(":", 1))
		launcher.show_page(page_name)
		await runner.process_frame
		await runner.process_frame
		var rects: Array[Rect2] = []
		for path: String in LAUNCHER_PAGE_PATHS[key]:
			if path in skip: continue
			var control: Control = launcher.get_node_or_null("Pages/%s/%s" % [page_name, path])
			runner.check(control != null and control.visible and view.encloses(control.get_global_rect()) and content.get_global_rect().grow(0.5).encloses(control.get_global_rect()), "%s %s/%s inside %s" % [id, key, path, size])
			if control != null: rects.append(control.get_global_rect())
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				runner.check(not rects[i].intersects(rects[j]), "%s %s controls %d and %d do not overlap at %s" % [id, key, i, j, size])
	launcher.set_opponent(opponent)

func test_launcher_sections(runner) -> bool:
	var saved_settings: String = AudioSettings.path
	var scratch: String = "user://test-launcher-sections-%d.cfg" % OS.get_process_id()
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var launcher = Launcher.instantiate()
		launcher.prerelease = true
		port.add_child(launcher)
		_force_visible(launcher)
		await runner.process_frame
		await runner.process_frame
		for page_name: String in PAGE_TITLES:
			var header: Label = launcher.get_node_or_null("Pages/%s/Title" % page_name)
			runner.check(header != null and header.text == PAGE_TITLES[page_name], "N20 %s page reads %s at %s" % [page_name, PAGE_TITLES[page_name], size])
		var nav: Control = launcher.get_node("Sidebar/Nav")
		var indexes: Array[int] = []
		for name in LAUNCHER_NAV_ORDER:
			var node: Node = nav.get_node_or_null(name)
			indexes.append(node.get_index() if node != null else -1)
		var in_order: bool = not indexes.has(-1)
		for i in range(1, indexes.size()):
			in_order = in_order and indexes[i - 1] < indexes[i]
		runner.check(in_order, "N20 sections are in order at %s, got %s" % [size, indexes])
		var play: Control = launcher.get_node("Pages/Play")
		var advanced: Button = play.get_node_or_null("Body/Advanced/Toggle")
		var relay: LineEdit = play.get_node_or_null("Body/Advanced/RelayUrl")
		if advanced != null and relay != null:
			runner.check(not advanced.button_pressed and not relay.visible and advanced.text == "Advanced settings" and not advanced.flat, "N20 Advanced starts closed, as a visible button, at %s" % size)
			runner.check(relay.text == "wss://relay.pdstuber.dev/ws", "N20 closed fold keeps the default relay URL at %s" % size)
			advanced.button_pressed = true
			runner.check(relay.visible and advanced.button_pressed, "N20 opening Advanced shows the relay field at %s" % size)
			runner.check(advanced.text.to_utf8_buffer().size() == advanced.text.length(), "N20 toggle text is plain ASCII, the default font has no arrow glyphs, at %s" % size)
			await _page_controls_ok(runner, launcher, size, "N20")
		launcher.show_page("Play")
		var status: Label = play.get_node("Footer/Status")
		for text in ["Match code: ABC234 — waiting for player 2", "Connection to relay lost"] + MatchSettings.PLAY_MAPS.values().map(func(label: String) -> String: return "Your copy of %s differs from the host's" % label):
			launcher._show_status(status, text, true)
			await runner.process_frame
			runner.check(status.get_line_count() == 1, "N20 Status stays one line at %s: %s" % [size, text])
			runner.check(status.get_global_rect().end.x <= play.get_node("Footer/Start").get_global_rect().position.x, "N20 Status ends left of Start at %s: %s" % [size, text])
		launcher.show_page("Settings")
		await runner.process_frame
		await runner.process_frame
		runner.check(launcher.get_node("Pages/Settings/Body/Audio").get_global_rect().encloses(launcher.get_node("Pages/Settings/Body/Audio/Volume").get_global_rect()), "N5 Volume inside the audio column at %s" % size)
		var legal: String = launcher.get_node("Pages/Credits/Body/Legal").text
		for part in ["Electronic Arts", "GNU GPL", "no warranty", "github.com/pdstuber/wargrid"]:
			runner.check(part in legal, "N5 launcher legal notice names %s" % part)
		launcher.free()
		port.free()
	AudioSettings.path = saved_settings
	DirAccess.remove_absolute(scratch)
	var offline = load(LauncherScript.OFFLINE_SCENE).instantiate()
	runner.check(offline.get_script().resource_path == "res://scripts/match/match_screen.gd", "N5 Play offline loads the offline skirmish")
	offline.free()
	return true

func test_overlay_net_line(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var overlay = online.main.get_node("HUD/PerfOverlay")
	overlay.toggle()
	runner.check(overlay.text.contains("RTT p95 40 ms"), "N9 overlay shows the transport RTT")
	online.main.free()
	return true

func test_rejection_line(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	online.lockstep._rejections.append({"tick": 5, "sequence": 0, "error": "No units left"})
	_run(main, 1)
	runner.check(main.get_node("HUD/Status").text.contains("Rejected: No units left"), "H5 online rejection line, got " + main.get_node("HUD/Status").text)
	_layout_ok(runner, main, "rejection")
	main.free()
	return true

func test_funds_rejection_is_announced(runner) -> bool:
	var online: Dictionary = await _online(runner, 2)
	var main = online.main
	online.lockstep._rejections.append({"tick": 5, "sequence": 0, "error": "Insufficient credits"})
	_run(main, 1)
	var cues: Array = main._sound.last_requests().map(func(request: Dictionary) -> String: return request.cue)
	var stream: AudioStream = main._sound._voice.stream
	runner.check(stream != null and stream.resource_path.get_file() == "insufficient_funds.wav", "N6 online funds rejection says insufficient_funds")
	runner.check(not cues.has("error"), "N6 online funds rejection gives no error beep, got %s" % [cues])
	main.free()
	return true

func _row_texts(row: Node) -> Array:
	return row.get_children().map(func(node: Node) -> String: return node.text if node is Label else node.name)

func _faction_row_controls(page: Control) -> Array[Control]:
	var controls: Array[Control] = []
	for path in ["Body/OwnLabel", "Body/MapLabel", "Body/Own", "Body/Map", "Body/BotLabel", "Body/Bot", "Footer/Start", "Footer/Create"]:
		controls.append(page.get_node(path))
	return controls

func test_launcher_faction_rows(runner) -> bool:
	var before := [SkirmishMain.factions, SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var launcher = Launcher.instantiate()
		port.add_child(launcher)
		await runner.process_frame
		await runner.process_frame
		var page: Control = launcher.get_node("Pages/Play")
		page.get_node("Footer/Create").visible = true
		await runner.process_frame
		await runner.process_frame
		var body: Control = page.get_node("Body")
		runner.check(_row_texts(body) == ["You", "Map", "Own", "Map", "Opponent", launcher._map_info("dry_wells"), "Opponent", "Spacer1", "Bot", "Spacer2", "Bot", "Spacer3", "OpenSlot", "Spacer4", "Advanced"], "N25 Play body children at %s, got %s" % [size, _row_texts(body)])
		runner.check(page.find_children("Own", "OptionButton", true, false).size() == 1, "N25 Play has one Own selector at %s" % size)
		runner.check(page.get_node("Footer/Create").text == "Create match" and page.get_node("Footer/Start").text == "Start match", "N25 button texts kept at %s" % size)
		var controls: Array[Control] = _faction_row_controls(page)
		var inside: bool = true
		var clear: bool = true
		for i in controls.size():
			inside = inside and Rect2(Vector2.ZERO, Vector2(size)).encloses(controls[i].get_global_rect()) and page.get_global_rect().encloses(controls[i].get_global_rect())
			for j in range(i + 1, controls.size()):
				clear = clear and not controls[i].get_global_rect().intersects(controls[j].get_global_rect())
		runner.check(inside and clear, "N25 row controls inside the viewport and clear of each other at %s" % size)
		for path in ["Body/OwnLabel", "Body/BotLabel", "Body/MapLabel"]:
			var label: Label = page.get_node(path)
			runner.check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE and label.text.to_utf8_buffer().size() == label.text.length(), "N25 %s is plain ASCII and ignores the mouse at %s" % [path, size])
		var own: OptionButton = page.get_node("Body/Own")
		var bot: OptionButton = page.get_node("Body/Bot")
		runner.check(own.item_count == 3 and bot.item_count == 3 and own.selected == bot.selected, "N25 Own and Bot list the factions and start equal at %s" % size)
		runner.check(body.get_global_rect().size.x < 1100.0, "F5 Play body stays under 1100 px wide at %s" % size)
		runner.check(own.get_item_text(0) == "China" and own.get_item_text(1) == "Free Resistance Coalition" and own.get_item_text(own.selected) == "United States", "F5 selector lists faction display names and defaults to the United States")
		var default_index: int = own.selected
		bot.select(0)
		runner.check(default_index != 0 and own.selected == default_index, "N25 Bot leaves Own alone at %s" % size)
		own.select(1)
		runner.check(bot.selected == 0, "N25 Own leaves Bot alone at %s" % size)
		var second: String = own.get_item_metadata(1)
		var third: String = own.get_item_metadata(2)
		bot.select(2)
		launcher._offline_setup()
		runner.check(SkirmishMain.factions == {1: second, 2: third}, "N25 offline Start passes Own and Bot at %s, got %s" % [size, SkirmishMain.factions])
		own.select(2)
		runner.check(runner.root.get_tree().root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "N25 the launcher keeps expand until the match starts at %s" % size)
		launcher._transport = FakeTransport.new()
		launcher._seat = 1
		launcher._start(_start_message("dry_wells", 3))
		runner.check(runner.root.get_tree().root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "N25 the match scene is added under keep, before any frame, at %s" % size)
		var main = runner.root.get_tree().current_scene
		runner.check(main.driver._own_faction == third, "N25 online match carries Own's faction at %s, got %s" % [size, main.driver._own_faction])
		main.free()
		await runner.process_frame
		runner.check(runner.root.get_tree().root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "N25 a match start restores keep at %s" % size)
		port.free()
	SkirmishMain.factions = before[0]
	SkirmishMain.map_path = before[1]
	SkirmishMain.starts = before[2]
	SkirmishMain.match_seed = before[3]
	return true

func _start_message(id: String, match_seed: int) -> Dictionary:
	return {"type": "start", "seats": [1, 2], "delay": 4, "seed": match_seed, "settings": MatchSettings.for_map(id)}

func test_plays_dry_wells_from_each_seat(runner) -> bool:
	var before: String = SkirmishMain.map_path
	var before_starts: Array[int] = SkirmishMain.starts
	var before_seed: int = SkirmishMain.match_seed
	runner.check(before == "res://data/maps/skirmish.json", "N7 without the launcher the scenes keep the test map")
	for seat in [1, 2]:
		var launcher = Launcher.instantiate()
		runner.root.add_child(launcher)
		await runner.process_frame
		launcher._transport = FakeTransport.new()
		launcher._seat = seat
		launcher._start(_start_message("dry_wells", 3))
		var main = runner.root.get_tree().current_scene
		var map: Dictionary = main.driver.sim.map_data()
		var start: Vector2i = MapData.start_cell(map, seat)
		runner.check(map.name == "Dry Wells" and main.get_node("Camera2D").position == Iso.world_to_plane(Vector2(start) + Vector2(0.5, 0.5)), "N7 seat %d plays the host's map with the camera on its own base" % seat)
		main.free()
		await runner.process_frame
	SkirmishMain.map_path = before
	SkirmishMain.starts = before_starts
	SkirmishMain.match_seed = before_seed
	return true

func test_online_start_saves_picks(runner) -> bool:
	var before := [SkirmishMain.map_path, SkirmishMain.starts, SkirmishMain.match_seed]
	for seat in [1, 2]:
		LauncherSettings.save_picks({"faction": "usa", "bot_faction": "china", "map": "dry_wells"})
		var launcher = Launcher.instantiate()
		runner.root.add_child(launcher)
		await runner.process_frame
		launcher._set_own("frc")
		launcher._transport = FakeTransport.new()
		launcher._seat = seat
		launcher._start(_start_message("ashfall", 3))
		var picks: Dictionary = LauncherSettings.load_picks()
		var expected: Dictionary = {"faction": "frc", "bot_faction": "china", "map": "ashfall" if seat == 1 else "dry_wells"}
		runner.check(picks == expected, "L9e seat %d start saves %s, got %s" % [seat, expected, picks])
		runner.root.get_tree().current_scene.free()
		await runner.process_frame
	SkirmishMain.map_path = before[0]
	SkirmishMain.starts = before[1]
	SkirmishMain.match_seed = before[2]
	return true

func test_offline_uses_chosen_map(runner) -> bool:
	var before_path: String = SkirmishMain.map_path
	var before_starts: Array[int] = SkirmishMain.starts
	var before_seed: int = SkirmishMain.match_seed
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var map_row: OptionButton = launcher.get_node("Pages/Play/Body/Map")
	var labels: Array = MatchSettings.PLAY_MAPS.values()
	runner.check(map_row.item_count == 3 and launcher._map_id() == "dry_wells", "N11 three maps, Dry Wells selected by default")
	for i in map_row.item_count:
		runner.check(map_row.get_item_text(i) == labels[i], "N11 dropdown item %d is %s" % [i, labels[i]])
	for i in map_row.item_count:
		map_row.select(i)
		var id: String = launcher._map_id()
		launcher._offline_setup()
		runner.check(SkirmishMain.map_path == MatchSettings.map_path(id), "N11 %s: Play offline uses the chosen map" % id)
		runner.check(SkirmishMain.starts.size() == 2, "N11 %s: two start spots chosen" % id)
		runner.check(SkirmishMain.starts == MatchSettings.starts(id, SkirmishMain.match_seed), "N11 %s: the starts come from the recorded match seed" % id)
		if id == "ashfall":
			runner.check((SkirmishMain.starts[0] - SkirmishMain.starts[1] + 8) % 8 == 4, "N11 Ashfall pair is diagonal, got %s" % str(SkirmishMain.starts))
	launcher.free()
	SkirmishMain.map_path = before_path
	SkirmishMain.starts = before_starts
	SkirmishMain.match_seed = before_seed
	return true

func test_restart_keeps_map_and_starts(runner) -> bool:
	var before_path: String = SkirmishMain.map_path
	var before_starts: Array[int] = SkirmishMain.starts
	var before_seed: int = SkirmishMain.match_seed
	SkirmishMain.map_path = MatchSettings.map_path("broken_crown")
	SkirmishMain.starts = [3, 1]
	var main = load(LauncherScript.OFFLINE_SCENE).instantiate()
	runner.root.add_child(main)
	await runner.process_frame
	var old_sim = main.driver.sim
	main._restart()
	runner.check(not is_same(old_sim, main.driver.sim), "N12 Restart builds a new simulation")
	var start: Vector2i = MapData.start_cell(main.driver.sim.map_data(), 1)
	var seat3: Vector2i = MapData.start_cell(MapData.load(SkirmishMain.map_path), 3)
	runner.check(start == seat3, "N12 Restart keeps seat 1 on the chosen start, got %s want %s" % [start, seat3])
	runner.check(main.get_node("Camera2D").position == Iso.world_to_plane(Vector2(start) + Vector2(0.5, 0.5)), "N12 camera on the chosen start after Restart")
	main.free()
	SkirmishMain.map_path = before_path
	SkirmishMain.starts = before_starts
	SkirmishMain.match_seed = before_seed
	return true

func test_restart_drops_old_stepped_results(runner) -> bool:
	var main = load(LauncherScript.OFFLINE_SCENE).instantiate()
	runner.root.add_child(main)
	await runner.process_frame
	main.stepped_results.append({"ok": false, "error": "old match", "player": main.local_player, "tick": 50, "sequence": 0})
	main._restart()
	runner.check(not main.get_node("HUD/Status").text.contains("old match"), "N12 Restart drops the old match's stepped results")
	main.free()
	return true

func test_joiner_refuses_other_map(runner) -> bool:
	var before_path: String = SkirmishMain.map_path
	var before_starts: Array[int] = SkirmishMain.starts
	var before_seed: int = SkirmishMain.match_seed
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var transport := FakeTransport.new()
	launcher._transport = transport
	launcher._seat = 2
	var message: Dictionary = _start_message("ashfall", 5)
	message.settings.map_hash = "0"
	var scene_before = runner.root.get_tree().current_scene
	launcher._origin = "Join"
	launcher._set_busy(true)
	runner.check(not launcher._handle(Wire.encode(message)), "N13 the joiner refuses a different map before the simulation exists")
	runner.check(runner.root.get_tree().current_scene == scene_before and transport.close_calls == 1, "N13 no online scene, transport closed once")
	runner.check(launcher.get_node("Pages/Join/Footer/Status").text == "Your copy of Ashfall differs from the host's", "N13 the reason is shown in Join's footer")
	runner.check(not launcher.get_node("Pages/Join/Footer/Join").disabled, "N13 Join usable again")
	launcher._process(0.0)
	launcher.free()
	SkirmishMain.map_path = before_path
	SkirmishMain.starts = before_starts
	SkirmishMain.match_seed = before_seed
	return true

func test_old_relay_mismatch_is_shown(runner) -> bool:
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	launcher._transport = FakeTransport.new()
	launcher._set_busy(true)
	launcher._handle('{"type":"error","reason":"protocol mismatch"}')
	runner.check(launcher.get_node("Pages/Play/Footer/Status").text == "protocol mismatch" and not launcher.get_node("Pages/Play/Footer/Create").disabled, "N14 a protocol mismatch from an old relay is shown")
	launcher.free()
	return true

func test_cancel_and_copy_while_waiting(runner) -> bool:
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var transport := FakeTransport.new()
	launcher._transport = transport
	launcher._set_busy(true)
	launcher.set_process(true)
	var wait: Control = launcher.get_node("Pages/Waiting")
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	runner.check(wait.visible and launcher.get_node("Pages/Play/Footer/Start").disabled and launcher.get_node("Pages/Play/Footer/Create").disabled and not launcher.get_node("Pages/Waiting/Body/Left/Invite/Copy").disabled and not launcher.get_node("Pages/Waiting/Footer/Cancel").disabled, "N17 waiting shows Copy and Cancel, launcher stays busy")
	runner.check(launcher._code == "ABC234", "N18 welcome stores the match code for Copy")
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		launcher.get_node("Pages/Waiting/Body/Left/Invite/Copy").pressed.emit()
		runner.check(DisplayServer.clipboard_get() == "ABC234", "N18 Copy puts the match code on the clipboard")
	launcher.get_node("Pages/Waiting/Footer/Cancel").pressed.emit()
	var enabled: bool = true
	for path in ["Play/Footer/Start", "Play/Footer/Create", "Join/Footer/Join", "Play/Body/Map", "Play/Body/Own", "Play/Body/Bot"]:
		enabled = enabled and not launcher.get_node("Pages/" + path).disabled
	runner.check(transport.close_calls == 1 and not wait.visible and enabled, "N17 Cancel restores the launcher")
	runner.check(launcher.get_node("Pages/Play/Footer/Status").text == "Match cancelled" and not launcher.is_processing(), "N17 Cancel says so and stops polling")
	launcher._handle('{"type":"welcome","seat":2,"match":"ABC234"}')
	runner.check(not wait.visible, "N18 seat 2 never sees the wait row")
	await runner.process_frame
	launcher.free()
	return true

func test_start_without_settings_is_a_protocol_error(runner) -> bool:
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var transport := FakeTransport.new()
	launcher._transport = transport
	launcher._set_busy(true)
	var message: Dictionary = _start_message("ashfall", 5)
	message.erase("settings")
	runner.check(not launcher._handle(JSON.stringify(message)), "N15 a start without settings is not accepted")
	runner.check(launcher.get_node("Pages/Play/Footer/Status").text.begins_with("Protocol error"), "N15 protocol error shown")
	runner.check(transport.close_calls == 1 and not launcher.get_node("Pages/Play/Footer/Create").disabled, "N15 transport closed once, Create usable")
	var other := FakeTransport.new()
	launcher._transport = other
	runner.check(not launcher._handle('{"type":"tick","seat":1,"tick":0}') and other.close_calls == 1, "N15 an unexpected message type closes the transport")
	launcher.free()
	return true

func test_both_seats_share_map_and_starts(runner) -> bool:
	var before_path: String = SkirmishMain.map_path
	var before_starts: Array[int] = SkirmishMain.starts
	var before_seed: int = SkirmishMain.match_seed
	var chosen: Array[int] = MatchSettings.starts("ashfall", 11)
	var raw: Dictionary = MapData.load(MatchSettings.map_path("ashfall"))
	runner.check((chosen[0] - chosen[1] + 8) % 8 == 4, "N19 the seeded pair is diagonal, got %s" % str(chosen))
	for seat in [1, 2]:
		var launcher = Launcher.instantiate()
		runner.root.add_child(launcher)
		await runner.process_frame
		launcher._transport = FakeTransport.new()
		launcher._seat = seat
		launcher._start(_start_message("ashfall", 11))
		runner.check(SkirmishMain.match_seed == 11, "N19 seat %d records the host's seed for reports, got %d" % [seat, SkirmishMain.match_seed])
		var main = runner.root.get_tree().current_scene
		var map: Dictionary = main.driver.sim.map_data()
		var cells: Array = [MapData.start_cell(map, 1), MapData.start_cell(map, 2)]
		runner.check(cells == [MapData.start_cell(raw, chosen[0]), MapData.start_cell(raw, chosen[1])], "N19 seat %d sim starts on the seeded cells, got %s" % [seat, str(cells)])
		runner.check(main.get_node("Camera2D").position == Iso.world_to_plane(Vector2(cells[seat - 1]) + Vector2(0.5, 0.5)), "N19 seat %d camera on its own base" % seat)
		main.free()
		await runner.process_frame
	SkirmishMain.map_path = before_path
	SkirmishMain.starts = before_starts
	SkirmishMain.match_seed = before_seed
	return true

func test_host_told_opponent_left_before_start(runner) -> bool:
	var notice: String = "Opponent left before the start (a different map or version, or their game tab was hidden)"
	var early: Dictionary = await _online(runner, 1)
	early.lockstep.receive('{"type":"left","seat":2,"after_tick":3}')
	_run(early.main, 12)
	runner.check(early.main.get_node("HUD/Status").text.contains(notice), "N16 left before the start is explained")
	_layout_ok(runner, early.main, "left before start")
	early.main.free()
	var late: Dictionary = await _online(runner, 1)
	_peer_packets(late.transport, 2, 4, 40)
	late.lockstep.receive('{"type":"left","seat":2,"after_tick":40}')
	_run(late.main, 80)
	var text: String = late.main.get_node("HUD/Status").text
	runner.check(text.contains("Player 2 disconnected") and not text.contains(notice), "N16 a later leave keeps the plain text, got " + text)
	late.main.free()
	return true

func _credits_wired(runner, shown: String, size: Vector2i) -> void:
	runner.check("Electronic Arts" in FileAccess.get_file_as_string("res://data/maps/NOTICE.md") and "Electronic Arts" in shown, "N10 Credits text carries the maps notice at %s" % size)
	var license_line: String = ""
	for line in Engine.get_license_text().split("\n"):
		if line.length() > 40:
			license_line = line
			break
	runner.check(not license_line.is_empty() and license_line in shown, "N10 Credits text carries Godot's licence text at %s" % size)
	var info: Dictionary = Engine.get_license_info()
	var info_line: String = ""
	for line in info[info.keys()[0]].split("\n"):
		if line.length() > 40 and "[" not in line:
			info_line = line
			break
	runner.check(Engine.get_copyright_info()[-1].name in shown, "N10 Credits text names an engine component at %s" % size)
	runner.check(not info_line.is_empty() and info_line in shown, "N10 Credits text carries an engine licence text at %s" % size)
	var at: Array[int] = []
	for heading in ["Wargrid ©", "\nMusic\n", "\nVoice: ", "\nMaps\n", "\nGodot Engine\n", "\nThird-party components in Godot\n"]:
		at.append(shown.find(heading))
	var ordered: bool = at[0] >= 0
	for i in range(1, at.size()):
		ordered = ordered and at[i] > at[i - 1]
	runner.check(ordered, "N10 Credits sections run Wargrid, Music, Voice, Maps, Godot, third-party at %s, got %s" % [size, at])

func test_credits_panel_layout(runner) -> bool:
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var launcher = Launcher.instantiate()
		port.add_child(launcher)
		await runner.process_frame
		await runner.process_frame
		var panel: Control = launcher.get_node("Pages/Credits")
		runner.check(not panel.visible and launcher.get_node("Pages/Play").visible, "N10 Credits page starts hidden at %s" % size)
		launcher.get_node("Sidebar/Nav/Credits").button_pressed = true
		await runner.process_frame
		await runner.process_frame
		var text: RichTextLabel = panel.get_node("Body/Text")
		var legal: Control = panel.get_node("Body/Legal")
		var view := Rect2(Vector2.ZERO, Vector2(size))
		runner.check(panel.visible and view.encloses(panel.get_global_rect()), "N10 Credits page inside the viewport at %s" % size)
		runner.check(not launcher.get_node("Pages/Play").visible, "N10 launcher controls hidden behind Credits at %s" % size)
		runner.check(panel.get_global_rect().encloses(text.get_global_rect()) and panel.get_global_rect().encloses(legal.get_global_rect()) and not text.get_global_rect().intersects(legal.get_global_rect()), "N10 Text and Legal fit the page at %s" % size)
		runner.check("Zhelanov" in text.get_parsed_text(), "N10 Credits text names the composers at %s" % size)
		_credits_wired(runner, text.get_parsed_text(), size)
		launcher.get_node("Sidebar/Nav/Play").button_pressed = true
		runner.check(not panel.visible and launcher.get_node("Pages/Play").visible, "N10 Play returns to the launcher at %s" % size)
		launcher.free()
		port.free()
	return true

func test_online_playtest_record(runner) -> bool:
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	_peer_packets(online.transport, 2, 4, PEER_TICKS)
	_run(main, 10)
	var record: Dictionary = main.playtest_match()
	runner.check(record.mode == "online" and record.build == PlaytestSettings.build_id(), "N-PT1 the online record names its mode and build")
	runner.check(record.commands == Lockstep.log_lines(online.lockstep.command_log()) and record.commands.size() >= 1, "N-PT1 the record holds the lockstep command lines")
	runner.check(main.playtest_context().over == false, "N-PT1 a running online match is not over")
	main.free()
	return true

func _launcher(runner, parent: Node, prerelease: bool, search: String = "", page: String = "", first_visit: bool = true):
	if first_visit: LauncherScript.code_applied = false
	var launcher = Launcher.instantiate()
	launcher.prerelease = prerelease
	launcher.search = search
	launcher.page = page
	parent.add_child(launcher)
	await runner.process_frame
	await runner.process_frame
	return launcher

func test_launcher_release_hides_relay(runner) -> bool:
	var saved_settings: String = AudioSettings.path
	var scratch: String = "user://test-launcher-release-%d.cfg" % OS.get_process_id()
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var launcher = await _launcher(runner, port, false)
		_force_visible(launcher)
		await runner.process_frame
		await runner.process_frame
		var box: Control = launcher.get_node("Pages/Play/Body")
		var relay: LineEdit = box.get_node("Advanced/RelayUrl")
		runner.check(not box.get_node("Advanced").visible and not relay.visible, "N21 release hides the fold and the relay field at %s" % size)
		runner.check(relay.text == JoinLink.DEFAULT_RELAY, "N21 release keeps the default relay at %s" % size)
		launcher._set_busy(true)
		runner.check(not relay.editable, "N21 busy locks the hidden relay field at %s" % size)
		launcher._set_busy(false)
		runner.check(relay.editable, "N21 idle unlocks the hidden relay field at %s" % size)
		await _page_controls_ok(runner, launcher, size, "N21", ["Body/Advanced/Toggle", "Body/Advanced/RelayHelp", "Body/Advanced/RelayUrl"])
		launcher.free()
		port.free()
	AudioSettings.path = saved_settings
	DirAccess.remove_absolute(scratch)
	return true

func _page_case(runner, prerelease: bool, search: String, label: String) -> Dictionary:
	var launcher = await _launcher(runner, runner.root, prerelease, search)
	var pages: Control = launcher.get_node("Pages")
	runner.check(launcher._transport == null and not launcher.is_processing(), "N22 page address never connects: %s" % label)
	var result := {"code": pages.get_node("Join/Body/Code").text, "relay": pages.get_node("Play/Body/Advanced/RelayUrl").text, "relay_visible": pages.get_node("Play/Body/Advanced/RelayUrl").visible, "open": pages.get_node("Play/Body/Advanced/Toggle").button_pressed}
	launcher.free()
	return result

func test_launcher_prefills_from_page(runner) -> bool:
	var saved_settings: String = AudioSettings.path
	var scratch: String = "user://test-launcher-prefill-%d.cfg" % OS.get_process_id()
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	var both: String = "?code=abc234&relay=wss%3A%2F%2Fx.example%2Fws"
	var release: Dictionary = await _page_case(runner, false, both, "release")
	runner.check(release.code == "ABC234" and release.relay == JoinLink.DEFAULT_RELAY and not release.relay_visible, "N22 release takes the code and ignores ?relay=")
	var dev: Dictionary = await _page_case(runner, true, both, "prerelease")
	runner.check(dev.code == "ABC234" and dev.relay == "wss://x.example/ws" and dev.relay_visible and dev.open, "N22 prerelease takes the code and the relay and opens the fold")
	var bad_relay: Dictionary = await _page_case(runner, true, "?relay=https%3A%2F%2Fx.example%2Fws&code=ABC2345", "bad relay and code")
	runner.check(bad_relay.relay == JoinLink.DEFAULT_RELAY and not bad_relay.open and bad_relay.code == "", "N22 a bad relay and a 7-character code are ignored")
	var oversize: Dictionary = await _page_case(runner, true, "?code=" + "A".repeat(3000), "oversize")
	runner.check(oversize.code == "", "N22 an oversize query is ignored")
	var first = await _launcher(runner, runner.root, true, both)
	var back = await _launcher(runner, runner.root, true, both, "", false)
	var back_pages: Control = back.get_node("Pages")
	runner.check(first.get_node("Pages/Join/Body/Code").text == "ABC234", "N22 the first visit takes the code")
	runner.check(back_pages.get_node("Join/Body/Code").text == "" and back_pages.get_node("Play/Body/Advanced/RelayUrl").text == "wss://x.example/ws" and back_pages.get_node("Play/Body/Advanced/Toggle").button_pressed, "N22 a return to the launcher drops the code and keeps the relay")
	first.free()
	back.free()
	AudioSettings.path = saved_settings
	DirAccess.remove_absolute(scratch)
	return true

const RELAY_HELP := "Relay server: matches players online. Test builds only; leave it unless you are trying another relay."

func test_launcher_relay_help(runner) -> bool:
	var saved_settings: String = AudioSettings.path
	var scratch: String = "user://test-launcher-relay-help-%d.cfg" % OS.get_process_id()
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var launcher = await _launcher(runner, port, true)
		_force_visible(launcher)
		await runner.process_frame
		var box: Control = launcher.get_node("Pages/Play/Body")
		var help: Label = box.get_node_or_null("Advanced/RelayHelp")
		runner.check(help != null and not help.visible, "N26 RelayHelp exists and is hidden while the fold is closed at %s" % size)
		if help == null:
			launcher.free()
			port.free()
			continue
		box.get_node("Advanced/Toggle").button_pressed = true
		await runner.process_frame
		await runner.process_frame
		var relay: LineEdit = box.get_node("Advanced/RelayUrl")
		runner.check(help.visible and help.text == RELAY_HELP, "N26 opening the fold shows the exact caption at %s" % size)
		runner.check(help.get_index() == relay.get_index() - 1, "N26 caption sits directly above the relay field at %s" % size)
		var view := Rect2(Vector2.ZERO, Vector2(size))
		runner.check(view.encloses(help.get_global_rect()), "N26 caption inside %s" % size)
		for path: String in LAUNCHER_PAGE_PATHS["Play:friend"]:
			var control: Control = launcher.get_node_or_null("Pages/Play/" + path)
			if control == null or control == help or not control.visible: continue
			runner.check(not control.get_global_rect().intersects(help.get_global_rect()), "N26 caption does not overlap %s at %s" % [path, size])
		var height: float = box.get_combined_minimum_size().y
		print("N26 prerelease fold-open worst-case Pages/Play/Body at %s: %s x %s" % [size, box.get_global_rect().size.x, height])
		runner.check(height <= 720.0 and box.get_global_rect().size.x < 1100.0, "N26 worst-case body %s fits 720 high and under 1100 wide at %s" % [box.get_global_rect().size, size])
		launcher._fail("A very long relay reason that wraps over many lines. ".repeat(8))
		await runner.process_frame
		await runner.process_frame
		var pages: Control = launcher.get_node("Pages")
		var view_rect := Rect2(Vector2.ZERO, Vector2(size))
		runner.check(pages.get_combined_minimum_size().y <= 720.0, "N26 a long Status keeps the worst-case Play page needing at most 720 high at %s, got %s" % [size, pages.get_combined_minimum_size().y])
		runner.check(view_rect.encloses(launcher.get_node("Pages/Play/Footer/Status").get_global_rect()) and view_rect.encloses(launcher.get_node("Pages/Play/Footer/Start").get_global_rect()), "N26 a long Status keeps Status and Start inside the viewport at %s" % size)
		launcher.free()
		var opened = await _launcher(runner, port, true, "?relay=wss%3A%2F%2Fx.example%2Fws")
		runner.check(opened.get_node("Pages/Play/Body/Advanced/RelayHelp").visible, "N26 ?relay= opens the fold with the caption at %s" % size)
		opened.free()
		var release = await _launcher(runner, port, false, "?relay=wss%3A%2F%2Fx.example%2Fws")
		runner.check(not release.get_node("Pages/Play/Body/Advanced/RelayHelp").visible, "N26 release hides the caption on load and ignores ?relay= at %s" % size)
		runner.check(release.get_node("Pages/Play/Body").get_combined_minimum_size().y <= 720.0 or size.y > 720, "N26 release box fits at %s" % size)
		release.free()
		port.free()
	AudioSettings.path = saved_settings
	DirAccess.remove_absolute(scratch)
	return true

func test_copy_link_on_web(runner) -> bool:
	var saved_settings: String = AudioSettings.path
	var scratch: String = "user://test-launcher-copy-%d.cfg" % OS.get_process_id()
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	var launcher = await _launcher(runner, runner.root, true, "", "https://wargrid-web-test.fly.dev/")
	launcher._code = "ABC234"
	runner.check(launcher.get_node("Pages/Waiting/Body/Left/Invite/Copy").text == "Copy link", "N23 Copy reads Copy link on the web")
	runner.check(launcher._copy_text() == "https://wargrid-web-test.fly.dev/?code=ABC234", "N23 the link carries the code only for the default relay")
	launcher.get_node("Pages/Play/Body/Advanced/RelayUrl").text = "wss://x.example/ws"
	runner.check(launcher._copy_text().ends_with("&relay=wss%3A%2F%2Fx.example%2Fws"), "N23 a non-default relay rides along")
	launcher.free()
	var desktop = await _launcher(runner, runner.root, true)
	desktop._code = "ABC234"
	runner.check(desktop.get_node("Pages/Waiting/Body/Left/Invite/Copy").text == "Copy code" and desktop._copy_text() == "ABC234", "N23 off the web Copy copies the bare code")
	desktop.free()
	AudioSettings.path = saved_settings
	DirAccess.remove_absolute(scratch)
	return true

func _ic_row(main, transport: FakeTransport, step: int, seen: Array, status: bool = false) -> String:
	var sent: Array = _own_commands(transport)
	var added: PackedStringArray = []
	for command: Dictionary in sent.slice(mini(seen[0], sent.size())): added.append(JSON.stringify(command))
	seen[0] = sent.size()
	var row: String = "%d|sel=%s|bld=%d|insp=%d|place=%s|pend=%s|am=%s|esc=%s|menu=%s|perf=%s|%s" % [step, main.orders.selected_ids, main.orders.selected_building_id, main.orders.inspected_id, main.orders._placement_kind, main.orders._pending_placement, main.orders._attack_move_mode, main._escape_pending(), main.menu_open(), main._perf.visible, ";".join(added)]
	return row + "|" + main.get_node("HUD/Status").text if status else row

func _ic_esc(main) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	var pass_on: bool = not main._pause.visible and main._escape_pending()
	main._input(event)
	if pass_on: main._unhandled_input(event)

func _ic_plane(main, id: int) -> Vector2:
	var unit: Dictionary = _entity(main, id)
	return Iso.world_to_plane(Vector2(unit.position[0], unit.position[1]))

func _ic_first_difference(rows: PackedStringArray, expected: PackedStringArray) -> int:
	for i in maxi(rows.size(), expected.size()):
		if i >= rows.size() or i >= expected.size() or rows[i] != expected[i]: return i
	return -1

func test_input_script_online(runner) -> bool:
	var helper = BaseScene.new()
	var online: Dictionary = await _online(runner, 1)
	var main = online.main
	var transport: FakeTransport = online.transport
	_peer_packets(transport, 2, 4, 200)
	_run(main, 8)
	runner.check(not _entity(main, 3).is_empty(), "IC2 fixture: the own start unit exists")
	var seen: Array = [0]
	var rows := PackedStringArray()
	var step = func(number: int, frames: int, status: bool = false) -> void:
		_run(main, frames)
		rows.append(_ic_row(main, transport, number, seen, status))
	var commands = func(type: String) -> int: return _own_commands(transport).filter(func(command: Dictionary) -> bool: return command.type == type).size()
	var box = func() -> Array: return [_ic_plane(main, 3) - Vector2.ONE * 40.0, _ic_plane(main, 3) + Vector2.ONE * 40.0]
	var corners: Array = box.call()
	helper.pointer(main, corners[0], MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, corners[1], MOUSE_BUTTON_LEFT, false)
	step.call(1, 3)
	runner.check(main.orders.selected_ids.has(3), "IC2 step 1 took effect")
	helper.pointer(main, Iso.world_to_plane(Vector2(12.5, 18.5)), MOUSE_BUTTON_RIGHT, true)
	step.call(2, 3)
	runner.check(commands.call("move") == 1, "IC2 step 2 took effect")
	helper.key(main, KEY_S)
	step.call(4, 3)
	runner.check(commands.call("stop") == 1, "IC2 step 4 took effect")
	corners = box.call()
	helper.pointer(main, corners[0], MOUSE_BUTTON_LEFT, true)
	helper.key(main, KEY_S)
	helper.pointer(main, corners[1], MOUSE_BUTTON_LEFT, false)
	step.call(6, 3)
	runner.check(commands.call("stop") == 1 and main.orders.selected_ids.has(3), "IC2 step 6 took effect")
	_ic_esc(main)
	step.call(7, 3)
	runner.check(main.orders.selected_ids.is_empty(), "IC2 step 7 took effect")
	_ic_esc(main)
	runner.check(main.menu_open(), "IC2 step 8 opened the menu")
	_ic_esc(main)
	step.call(8, 3)
	runner.check(not main.menu_open(), "IC2 step 8 took effect")
	var at: Vector2 = _ic_plane(main, 3) + Vector2(0, -8)
	helper.pointer(main, at, MOUSE_BUTTON_LEFT, true)
	helper.pointer(main, at, MOUSE_BUTTON_LEFT, false)
	helper.key(main, KEY_1)
	step.call(9, 3, true)
	runner.check(not main.orders._placement_kind.is_empty(), "IC2 step 9 took effect")
	helper.key(main, KEY_F3)
	step.call(10, 3)
	helper.pointer(main, Iso.world_to_plane(Vector2(10.5, 10.5)), MOUSE_BUTTON_LEFT, false)
	step.call(11, 3)
	runner.check(commands.call("build") == 1, "IC2 step 11 took effect")
	corners = box.call()
	helper.pointer(main, corners[0], MOUSE_BUTTON_LEFT, true)
	helper.key(main, KEY_1)
	helper.pointer(main, corners[1], MOUSE_BUTTON_LEFT, false)
	step.call(17, 3)
	runner.check(not main.orders._placement_kind.is_empty() and main.orders._pending_placement.is_empty(), "IC2 step 17 took effect")
	_ic_esc(main)
	_ic_esc(main)
	step.call(18, 3)
	runner.check(main.orders._placement_kind.is_empty() and main.orders.selected_ids.is_empty(), "IC2 step 18 took effect")
	var first: int = _ic_first_difference(rows, IcRows.IC2_ROWS)
	runner.check(first == -1, "IC2 row %d matches the chain recorded 2026-11-14, got %s" % [first, rows[first] if first >= 0 and first < rows.size() else "no row"])
	main.free()
	return true

func test_launcher_reads_no_page_off_web(runner) -> bool:
	var launcher = Launcher.instantiate()
	runner.check(launcher.get("page") == "" and launcher.get("search") == "", "N24 a headless launcher reads no page address")
	launcher.free()
	return true
