@warning_ignore_start("untyped_declaration")
extends RefCounted

const Skirmish = preload("res://scenes/skirmish.tscn")
const OnlineScene = preload("res://scenes/online_skirmish.tscn")
const SkirmishRules = preload("res://scripts/simulation/skirmish.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const CARD_ECONOMY := "p1-frc-economy"
const CARD_TUNNELS := "p1-frc-tunnels-online"
var scratch: String = "user://test-overlay-settings-%d.cfg" % OS.get_process_id()
var sessions: String = "user://test-overlay-playtests-%d" % OS.get_process_id()
var saved_dir: String = ""

class FakeTransport extends RefCounted:
	var polls: int = 0
	func poll() -> PackedStringArray:
		polls += 1
		return PackedStringArray()
	func send_text(_text: String) -> void: pass
	func closed() -> bool: return false
	func silent(_now: int) -> bool: return false
	func close() -> void: pass
	func rtt_samples() -> PackedInt64Array: return PackedInt64Array()

class Camera extends RefCounted:
	var seen_dialog_visible: Array[bool] = []
	var image: Image = null
	var overlay: Control = null
	func shot() -> Image:
		seen_dialog_visible.append(overlay.get_node("MarkerDialog").visible)
		return image

func cases() -> Array[Callable]:
	return [test_marker_pauses_offline, test_marker_does_not_pause_online, test_capture_before_dialog, test_note_typing_is_not_a_hotkey, test_marker_ignored_when_menu_or_over, test_checklist_triggers, test_helper_off_changes_nothing, test_overlay_layout]

func _begin(helper_on: bool = true, card: String = CARD_ECONOMY) -> String:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	PlaytestSettings.save_enabled(helper_on)
	saved_dir = PlaytestSession.dir
	PlaytestSession.dir = sessions
	PlaytestSession.current = null
	FocusCards.chosen = card
	return saved

func _end(saved: String) -> void:
	DirAccess.remove_absolute(scratch)
	if DirAccess.dir_exists_absolute(sessions):
		for file in DirAccess.get_files_at(sessions): DirAccess.remove_absolute(sessions.path_join(file))
		DirAccess.remove_absolute(sessions)
	PlaytestSession.dir = saved_dir
	PlaytestSession.current = null
	AudioSettings.path = saved
	FocusCards.chosen = ""

func _scene(runner, packed = Skirmish, parent = null):
	var main = packed.instantiate()
	(parent if parent != null else runner.root).add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	await runner.process_frame
	return main

func _online(runner):
	var transport := FakeTransport.new()
	var seats: Array[int] = [1, 2]
	var main = OnlineScene.instantiate()
	main.setup(transport, Lockstep.new(1, seats), 1)
	runner.root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	await runner.process_frame
	return {"main": main, "transport": transport}

func _camera(main, image: Image = Image.create(1280, 720, false, Image.FORMAT_RGB8)) -> Camera:
	var camera := Camera.new()
	camera.overlay = main.get_node("HUD/Playtest")
	camera.image = image
	camera.overlay.image_source = camera.shot
	main.set_meta("camera", camera) # a Callable does not keep its RefCounted alive
	return camera

func _key(runner, code: Key, unicode: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	event.pressed = true
	runner.root.push_input(event)

func _click(main, name: String) -> void:
	for button: Button in main.get_node("HUD/PauseMenu").find_children("*", "Button", true, false):
		if button.text == name and button.is_visible_in_tree():
			button.pressed.emit()
			return
	assert(false, "no visible button " + name)

func _own_unit(main) -> int:
	for unit: Dictionary in main.simulation.snapshot().entities:
		if unit.owner == main.local_player: return unit.id
	return -1

func _dialog(main) -> Control:
	return main.get_node("HUD/Playtest/MarkerDialog")

func test_marker_pauses_offline(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	main._physics_process(0.0)
	var unit: int = _own_unit(main)
	main.selected_ids.assign([unit])
	var tick: int = main.simulation.tick()
	var camera := _camera(main)
	_key(runner, KEY_N)
	runner.check(_dialog(main).visible and main.menu_open(), "PO1 N opens the note and the match counts it as an open menu")
	for i in 5: main._physics_process(0.0)
	runner.check(main.simulation.tick() == tick, "PO1 tick frozen while the note is open")
	main.get_node("HUD/Playtest").save_marker("good", "nice")
	runner.check(not _dialog(main).visible and not main.menu_open(), "PO1 saving closes the note")
	main._physics_process(0.0)
	runner.check(main.simulation.tick() == tick + 1, "PO1 tick advances after saving")
	var markers: Array[Dictionary] = PlaytestSession.current.pending_markers()
	runner.check(markers.size() == 1 and markers[0].kind == "good" and markers[0].text == "nice" and markers[0].tick == tick and markers[0].selected == [unit] and not markers[0].jpg.is_empty(), "PO1 marker holds kind, text, tick, selection and a screenshot, got %s" % [markers.map(func(m: Dictionary) -> Dictionary: return m.merged({"jpg": m.jpg.length()}, true))])
	runner.check(camera.seen_dialog_visible.size() == 1, "PO1 one capture per note")
	main.free()
	_end(saved)
	return true

func test_marker_does_not_pause_online(runner) -> bool:
	var saved: String = _begin()
	var online: Dictionary = await _online(runner)
	var main = online.main
	_camera(main)
	main._physics_process(0.0)
	_key(runner, KEY_N)
	runner.check(_dialog(main).visible and main.menu_open(), "PO2 online N opens the note")
	var polls: int = online.transport.polls
	for i in 4: main._physics_process(0.0)
	runner.check(online.transport.polls == polls + 4, "PO2 online still polls the transport while the note is open, got %d" % (online.transport.polls - polls))
	main.free()
	_end(saved)
	return true

func test_capture_before_dialog(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var camera := _camera(main)
	main.get_node("HUD/Playtest").open_marker()
	runner.check(camera.seen_dialog_visible == [false] and _dialog(main).visible, "PO3 the screenshot is taken before the note is shown, saw %s" % [camera.seen_dialog_visible])
	main.get_node("HUD/Playtest").cancel_marker()
	camera.image = null
	main.get_node("HUD/Playtest").open_marker()
	main.get_node("HUD/Playtest").save_marker("bad", "no shot")
	var markers: Array[Dictionary] = PlaytestSession.current.pending_markers()
	runner.check(markers.size() == 1 and markers[0].jpg == "" and markers[0].kind == "bad", "PO3 a failed capture still saves the marker with an empty jpg")
	main.free()
	_end(saved)
	return true

func test_note_typing_is_not_a_hotkey(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	_camera(main)
	main.selected_ids.assign([_own_unit(main)])
	var commands: int = main.playtest_match().commands.size()
	_key(runner, KEY_N)
	var text: LineEdit = main.get_node("HUD/Playtest/MarkerDialog").find_child("Text", true, false)
	runner.check(text.has_focus(), "PO4 the note's text field has focus")
	_key(runner, KEY_A, 97)
	_key(runner, KEY_S, 115)
	_key(runner, KEY_1, 49)
	_key(runner, KEY_N, 110)
	runner.check(text.text == "as1n" and not main._attack_move_mode, "PO4 letters go into the text, not attack-move, got '%s'" % text.text)
	runner.check(main.playtest_match().commands.size() == commands and _dialog(main).visible, "PO4 typing issues no command and keeps the note open")
	main.selected_ids.clear()
	_key(runner, KEY_ESCAPE)
	runner.check(not _dialog(main).visible and not main.get_node("HUD/PauseMenu").visible, "PO4 Esc closes the note and leaves the pause menu closed")
	main.free()
	_end(saved)
	return true

func test_marker_ignored_when_menu_or_over(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	_camera(main)
	_key(runner, KEY_ESCAPE)
	runner.check(main.get_node("HUD/PauseMenu").visible, "PO5 fixture: pause menu open")
	_key(runner, KEY_N)
	runner.check(not _dialog(main).visible, "PO5 N with the pause menu open opens nothing")
	_key(runner, KEY_ESCAPE)
	for building: Dictionary in main.simulation.snapshot().buildings: main.simulation.remove_object(building.id)
	main._physics_process(0.0)
	runner.check(main.simulation.match_over(), "PO5 fixture: match over")
	_key(runner, KEY_N)
	runner.check(not _dialog(main).visible and PlaytestSession.current.pending_markers().is_empty(), "PO5 N after the match ended opens nothing")
	main.free()
	_end(saved)
	return true

func test_checklist_triggers(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	var list: Control = overlay.get_node("Checklist")
	runner.check(list.visible and list.find_child("collect", true, false) is CheckBox, "PO6 checklist visible at match start with one box per item")
	var sim = SkirmishRules.create(true, "ai", {1: "frc", 2: "usa"})
	main.simulation = sim
	var pile: Dictionary = sim.snapshot().sources[0]
	var laborer: int = sim.spawn(1, Vector2(pile.origin[0] + 6.5, pile.origin[1] + 8.5), "frc_builder")
	main._submit({"type": "gather", "entity_ids": [999999], "source_id": pile.id})
	runner.check(not main._error.is_empty() and not overlay.checked("collect"), "PO6 a rejected gather ticks nothing, error '%s'" % main._error)
	main._submit({"type": "gather", "entity_ids": [laborer], "source_id": pile.id})
	runner.check(main._error.is_empty() and overlay.checked("collect") and list.find_child("collect", true, false).button_pressed, "PO6 an accepted gather ticks collect, error '%s'" % main._error)
	overlay.observe_command({"type": "build", "building_kind": "frc_supply_center"})
	runner.check(overlay.checked("cache") and not overlay.checked("workers"), "PO6 build:frc_supply_center ticks cache only")
	list.find_child("income", true, false).button_pressed = true
	runner.check(overlay.checked("income") and PlaytestSession.current.data.checklist.income == true, "PO6 a click ticks income and saves it")
	var saved_ticks: int = PlaytestSession.current.data.checklist.size()
	overlay.observe_command({"type": "gather"})
	runner.check(PlaytestSession.current.data.checklist.size() == saved_ticks, "PO6 an already ticked item is not written again")
	_key(runner, KEY_QUOTELEFT)
	runner.check(not list.visible, "PO6 ` hides the checklist")
	_key(runner, KEY_QUOTELEFT)
	runner.check(list.visible, "PO6 ` shows it again")
	main.free()
	PlaytestSession.current = null
	FocusCards.chosen = CARD_TUNNELS
	main = await _scene(runner)
	overlay = main.get_node("HUD/Playtest")
	runner.check(not overlay.checked("esc"), "PO6 fixture: esc item open")
	_key(runner, KEY_ESCAPE)
	runner.check(overlay.checked("esc"), "PO6 opening the Esc menu ticks the esc_menu item")
	main.free()
	_end(saved)
	return true

func test_helper_off_changes_nothing(runner) -> bool:
	var saved: String = _begin(false)
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	_key(runner, KEY_QUOTELEFT)
	_key(runner, KEY_N)
	runner.check(not overlay.get_node("Checklist").visible and not _dialog(main).visible and not overlay.is_active(), "PO7 off: ` and N do nothing")
	runner.check(main.menu_open() == main.get_node("HUD/PauseMenu").visible and PlaytestSession.current == null, "PO7 off: menu_open is the pause menu and no session exists")
	_key(runner, KEY_ESCAPE)
	runner.check(main.menu_open(), "PO7 off: Esc still opens the pause menu")
	_click(main, "Playtest helper: Off")
	runner.check(overlay.is_active() and overlay.get_node("Checklist").visible and PlaytestSettings.enabled(), "PO7 the pause menu switch turns the helper on mid-match and stores it")
	_click(main, "Playtest helper: On")
	runner.check(not overlay.is_active() and not overlay.get_node("Checklist").visible and not PlaytestSettings.enabled(), "PO7 and off again")
	main.free()
	_end(saved)
	return true

func test_overlay_layout(runner) -> bool:
	var saved: String = _begin()
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var main = await _scene(runner, Skirmish, port)
		_camera(main)
		main.selected_ids.assign([_own_unit(main)])
		main._refresh()
		main.get_node("HUD/Playtest").open_marker()
		await runner.process_frame
		await runner.process_frame
		runner.check(main.get_viewport().get_visible_rect().size == Vector2(size), "PO8 the viewport really is %s, got %s" % [size, main.get_viewport().get_visible_rect().size])
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		var panels: Array[Rect2] = []
		for path in ["HUD/Playtest/Checklist", "HUD/Playtest/MarkerDialog"]:
			var panel: Control = main.get_node(path)
			runner.check(panel.visible and screen.encloses(panel.get_global_rect()), "PO8 %s inside %s, rect %s" % [path, size, panel.get_global_rect()])
			panels.append(panel.get_global_rect())
			for other in ["HUD/Status", "HUD/Economy", "HUD/Result", "HUD/Restart"]:
				var control: Control = main.get_node(other)
				runner.check(not panel.get_global_rect().intersects(Rect2(control.global_position, control.get_combined_minimum_size())), "PO8 %s clear of %s at %s" % [path, other, size])
		runner.check(not panels[0].intersects(panels[1]), "PO8 checklist and note apart at %s" % size)
		port.free()
	_end(saved)
	return true
