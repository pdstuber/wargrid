@warning_ignore_start("untyped_declaration")
extends RefCounted

const Skirmish = preload("res://scenes/skirmish.tscn")
const SkirmishRules = preload("res://scripts/simulation/skirmish.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const SessionForm = preload("res://scripts/playtest/session_form.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const MarkerCapture = preload("res://scripts/playtest/marker_capture.gd")
const LAUNCHER: String = "res://scenes/launcher.tscn"
const CARD_ECONOMY := "p1-frc-economy"
const CARD_TUNNELS := "p1-frc-tunnels-online"
var scratch: String = "user://test-overlay-settings-%d.cfg" % OS.get_process_id()
var sessions: String = "user://test-overlay-playtests-%d" % OS.get_process_id()
var saved_dir: String = ""

class FakeTransport extends RefCounted:
	var polls: int = 0
	var close_calls: int = 0
	func poll() -> PackedStringArray:
		polls += 1
		return PackedStringArray()
	func send_text(_text: String) -> void: pass
	func closed() -> bool: return close_calls > 0
	func silent(_now: int) -> bool: return false
	func close() -> void: close_calls += 1
	func rtt_samples() -> PackedInt64Array: return PackedInt64Array()

class Camera extends RefCounted:
	var seen_dialog_visible: Array[bool] = []
	var image: Image = null
	var overlay: Control = null
	func shot() -> Image:
		seen_dialog_visible.append(overlay.get_node("MarkerDialog").visible)
		return image

func cases() -> Array[Callable]:
	return [test_marker_pauses_offline, test_marker_does_not_pause_online, test_capture_before_dialog, test_note_typing_is_not_a_hotkey, test_marker_ignored_when_menu_or_over, test_checklist_triggers, test_helper_off_changes_nothing, test_overlay_layout, test_leave_flow, test_match_end_opens_review_once, test_leave_after_closed_sitting, test_two_match_session_file, test_web_save_downloads, test_desktop_write_error_keeps_session, test_form_layout, test_resume_uses_stored_card, test_restart_drops_pending_markers, test_scale_legend]

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
	WargridTestRunner.remove_dir(sessions)
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
	var main = Skirmish.instantiate()
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
	for unit: Dictionary in main.driver.sim.snapshot().entities:
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
	var tick: int = main.driver.sim.tick()
	var camera := _camera(main)
	_key(runner, KEY_N)
	runner.check(_dialog(main).visible and main.menu_open(), "PO1 N opens the note and the match counts it as an open menu")
	for i in 5: main._physics_process(0.0)
	runner.check(main.driver.sim.tick() == tick, "PO1 tick frozen while the note is open")
	main.get_node("HUD/Playtest").save_marker("good", "nice")
	runner.check(not _dialog(main).visible and not main.menu_open(), "PO1 saving closes the note")
	main._physics_process(0.0)
	runner.check(main.driver.sim.tick() == tick + 1, "PO1 tick advances after saving")
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
	for building: Dictionary in main.driver.sim.snapshot().buildings: main.driver.sim.remove_object(building.id)
	main._physics_process(0.0)
	runner.check(main.driver.sim.match_over(), "PO5 fixture: match over")
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
	main.driver.sim = sim
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
	PlaytestSession.current.discard() # a stored sitting keeps its own card
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
	_key(runner, KEY_ESCAPE)
	var sim = SkirmishRules.create(true, "ai", {1: "frc", 2: "usa"})
	main.driver.sim = sim
	var pile: Dictionary = sim.snapshot().sources[0]
	var laborer: int = sim.spawn(1, Vector2(pile.origin[0] + 6.5, pile.origin[1] + 8.5), "frc_builder")
	main._submit({"type": "gather", "entity_ids": [laborer], "source_id": pile.id})
	runner.check(main._error.is_empty() and not overlay.get_node("Checklist").find_child("collect", true, false).button_pressed and PlaytestSession.current == null, "PO7 off: an accepted gather ticks nothing and opens no session, error '%s'" % main._error)
	_key(runner, KEY_ESCAPE)
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

func _form(main) -> Control:
	return main.get_node_or_null("HUD/Playtest/SessionForm")

func _form_shown(main) -> bool:
	var form: Control = _form(main)
	return form != null and form.visible

func _press(main, button_name: String) -> bool:
	var form: Control = _form(main)
	var button: Button = form.find_child(button_name, true, false) if form != null else null
	if button == null or not button.is_visible_in_tree(): return false
	if button.toggle_mode: button.button_pressed = true
	else: button.pressed.emit()
	return true

func _form_text(main) -> String:
	var form: Control = _form(main)
	if form == null: return ""
	return "\n".join(form.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree()).map(func(label: Label) -> String: return label.text))

func _scenes(main) -> Array[String]:
	var scenes: Array[String] = []
	main.change_scene = func(path: String) -> void: scenes.append(path)
	return scenes

func _run(main, steps: int) -> void:
	for i in steps: main._physics_process(0.0)

func _move_own_unit(main) -> void:
	main.selected_ids.assign([_own_unit(main)])
	for unit: Dictionary in main.driver.sim.snapshot().entities:
		if unit.id == main.selected_ids[0]:
			main._move(Vector2(unit.position[0] + 4.0, unit.position[1]))
			return

func _mark(overlay, kind: String, text: String) -> void:
	overlay.open_marker()
	overlay.save_marker(kind, text)

func _saved_session() -> Dictionary:
	for file in DirAccess.get_files_at(sessions):
		if file.begins_with("session-"): return JSON.parse_string(FileAccess.get_file_as_string(sessions.path_join(file)))
	return {}

func _rate_all(runner, main, score: int) -> void:
	var card: Dictionary = FocusCards.card(CARD_ECONOMY, FocusCards.load_cards())
	for question: Dictionary in card.questions:
		runner.check(_press(main, "%s_%d" % [question.id, score]), "PO10 rating button %s_%d is shown" % [question.id, score])

func test_leave_flow(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var scenes := _scenes(main)
	_key(runner, KEY_ESCAPE)
	_click(main, "Back to main menu")
	runner.check(_form_shown(main) and scenes.is_empty(), "PO9 leaving with the helper on shows the form and does not change scene yet, scenes %s" % [scenes])
	runner.check(not main.get_node("HUD/PauseMenu").visible, "PO9 the pause menu closes behind the form")
	_key(runner, KEY_ESCAPE)
	runner.check(_form_shown(main) and not main.get_node("HUD/PauseMenu").visible, "PO9 Esc while the form is open does nothing")
	runner.check(_press(main, "NextMatch"), "PO9 the form offers NextMatch")
	runner.check(scenes == [LAUNCHER] and not _form_shown(main), "PO9 NextMatch leaves once, got %s" % [scenes])
	main.free()
	_end(saved)
	saved = _begin(false)
	main = await _scene(runner)
	scenes = _scenes(main)
	_key(runner, KEY_ESCAPE)
	_click(main, "Back to main menu")
	runner.check(scenes == [LAUNCHER] and _form(main) != null and not _form_shown(main) and PlaytestSession.current == null, "PO9 helper off: leaving changes scene at once and no form shows, got %s" % [scenes])
	main.free()
	_end(saved)
	saved = _begin()
	var online: Dictionary = await _online(runner)
	main = online.main
	scenes = _scenes(main)
	_key(runner, KEY_ESCAPE)
	_click(main, "Back to main menu")
	runner.check(online.transport.close_calls == 0 and scenes.is_empty() and not _form_shown(main), "PO9 online: asking to leave does nothing yet")
	_click(main, "Leave")
	runner.check(online.transport.close_calls == 1 and _form_shown(main) and scenes.is_empty(), "PO9 online leave closes the transport once and shows the form, closed %d" % online.transport.close_calls)
	var polls: int = online.transport.polls
	main._physics_process(0.0)
	runner.check(online.transport.polls == polls + 1, "PO9 online does not pause behind the form")
	runner.check(_press(main, "NextMatch"), "PO9 online form offers NextMatch")
	runner.check(scenes == [LAUNCHER] and online.transport.close_calls == 1, "PO9 online NextMatch leaves once and never closes the transport again, closed %d, scenes %s" % [online.transport.close_calls, scenes])
	main.free()
	_end(saved)
	return true

func test_match_end_opens_review_once(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	_mark(overlay, "bad", "before the end")
	var enemies: Dictionary = {}
	var state: Dictionary = main.driver.sim.snapshot()
	for object: Dictionary in state.entities + state.buildings:
		if object.owner == 2: enemies[object.id] = true
	for id: int in enemies: main.driver.sim.remove_object(id)
	main._physics_process(0.0)
	runner.check(main.driver.sim.match_over() and not _form_shown(main), "PO11 fixture: match over, no review before the overlay polls")
	overlay._process(0.0)
	var comment: LineEdit = _form(main).find_child("Comment_0_0", true, false) if _form(main) != null else null
	runner.check(_form_shown(main) and PlaytestSession.current.data.matches.size() == 1 and comment != null, "PO11 one poll shows the review with the marker's comment field")
	if comment != null:
		comment.text = "looks fine"
		comment.text_changed.emit(comment.text) # setting text does not emit, and typing emits deferred
		runner.check(PlaytestSession.current.data.matches[0].markers[0].comment == "looks fine", "PO11 typing a comment saves it on the marker, field '%s' stored '%s'" % [comment.text, PlaytestSession.current.data.matches[0].markers[0].comment])
	overlay._process(0.0)
	runner.check(PlaytestSession.current.data.matches.size() == 1, "PO11 a second poll adds no second match")
	runner.check(overlay.reviewing(), "PO11 reviewing() is true while the form is open")
	var scenes := _scenes(main)
	_press(main, "NextMatch")
	runner.check(not overlay.reviewing() and scenes.is_empty(), "PO11 NextMatch at match end closes the form and stays in the match")
	main.get_node("HUD/PauseMenu").leave_requested.emit()
	runner.check(scenes.is_empty() and _form_shown(main) and PlaytestSession.current.data.matches.size() == 1, "PO11 leaving after the review reopens the form without a second match, scenes %s" % [scenes])
	runner.check(_form(main).find_child("EndSession", true, false) != null and _form(main).find_child("NextMatch", true, false) == null, "PO11 the reopened form offers EndSession and no NextMatch")
	runner.check(_press(main, "Leave") and scenes == [LAUNCHER] and not _form_shown(main) and PlaytestSession.current.data.matches.size() == 1, "PO11 Leave changes scene once and keeps the sitting, scenes %s" % [scenes])
	main.free()
	_end(saved)
	return true

func test_leave_after_closed_sitting(runner) -> bool:
	for ending: String in ["SaveSession", "DiscardSession"]:
		var saved: String = _begin()
		var main = await _scene(runner)
		var overlay = main.get_node("HUD/Playtest")
		var state: Dictionary = main.driver.sim.snapshot()
		for object: Dictionary in state.entities + state.buildings:
			if object.owner == 2: main.driver.sim.remove_object(object.id)
		main._physics_process(0.0)
		overlay._process(0.0)
		_press(main, "EndSession")
		_rate_all(runner, main, 3)
		_press(main, ending)
		if ending == "SaveSession": _press(main, "Close")
		var scenes := _scenes(main)
		main.get_node("HUD/PauseMenu").leave_requested.emit()
		runner.check(scenes == [LAUNCHER] and not _form_shown(main), "PO11b leaving after %s does not offer the closed sitting again, scenes %s" % [ending, scenes])
		main.free()
		_end(saved)
	return true

func test_two_match_session_file(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	_move_own_unit(main)
	runner.check(main._error.is_empty(), "PO12 fixture: the first move is accepted, '%s'" % main._error)
	_run(main, 60)
	_mark(overlay, "good", "match one marker")
	var digests: Array[String] = [StateHash.digest(main.driver.sim.snapshot())]
	var commands: Array = [main.playtest_match().commands]
	overlay.end_match()
	runner.check(_form_shown(main), "PO12 ending match 1 shows its review")
	_press(main, "NextMatch")
	main._restart()
	runner.check(overlay.get_node("Checklist").visible and not _form_shown(main), "PO12 a restart brings the checklist back and closes the form")
	_move_own_unit(main)
	runner.check(main._error.is_empty(), "PO12 fixture: the second move is accepted, '%s'" % main._error)
	_run(main, 45)
	_mark(overlay, "bad", "match two first")
	_run(main, 45)
	_mark(overlay, "confusing", "match two second")
	digests.append(StateHash.digest(main.driver.sim.snapshot()))
	commands.append(main.playtest_match().commands)
	var scenes := _scenes(main)
	main.selected_ids.clear()
	_key(runner, KEY_ESCAPE)
	_click(main, "Back to main menu")
	runner.check(_form_shown(main) and scenes.is_empty(), "PO12 leaving match 2 shows its review")
	runner.check(_press(main, "EndSession"), "PO12 the review offers EndSession")
	var card: Dictionary = FocusCards.card(CARD_ECONOMY, FocusCards.load_cards())
	_rate_all(runner, main, 4)
	var first: LineEdit = _form(main).find_child("Answer_" + card.questions[0].id, true, false) if _form_shown(main) else null
	runner.check(first != null, "PO12 the first question has a text field")
	if first != null:
		first.text = "clear"
		first.text_changed.emit(first.text)
	runner.check(_press(main, "SaveSession"), "PO12 SaveSession is offered")
	var file: Dictionary = _saved_session()
	var matches: Array = file.get("matches", [])
	runner.check(matches.size() == 2, "PO12 the file holds 2 matches, got %d" % matches.size())
	if matches.size() == 2:
		runner.check(matches[0].markers.size() == 1 and matches[1].markers.size() == 2, "PO12 markers 1 and 2 land in their own match, got %d and %d" % [matches[0].markers.size(), matches[1].markers.size()])
		runner.check(matches[0].markers[0].text == "match one marker" and matches[1].markers[0].text == "match two first", "PO12 marker texts stay with their match")
		runner.check(int(matches[0].end_tick) == 60 and int(matches[1].end_tick) == 90, "PO12 end ticks are 60 and 90, got %s and %s" % [matches[0].end_tick, matches[1].end_tick])
		runner.check(matches[1].markers.all(func(marker: Dictionary) -> bool: return int(marker.tick) <= 90), "PO12 match 2 marker ticks start from 0 again")
		runner.check(matches[0].end_digest == digests[0] and matches[1].end_digest == digests[1], "PO12 each match keeps its own end digest")
		runner.check(Array(matches[0].commands) == Array(commands[0]) and Array(matches[1].commands) == Array(commands[1]) and not matches[1].commands.is_empty(), "PO12 each match keeps its own command log")
	var answers: Dictionary = file.get("answers", {})
	runner.check(card.questions.all(func(question: Dictionary) -> bool: return answers.has(question.id) and int(answers[question.id].score) == 4), "PO12 every question holds score 4, got %s" % [answers])
	runner.check(answers.get(card.questions[0].id, {}).get("text", "") == "clear", "PO12 the first answer keeps its text")
	runner.check(_form_text(main).contains("Saved to") and _form(main).find_child("ShowInFolder", true, false) != null, "PO12 the form shows the path and Show in folder")
	runner.check(scenes.is_empty() and _press(main, "Close") and scenes == [LAUNCHER], "PO12 Close leaves once")
	var out: String = OS.get_environment("WARGRID_SESSION_OUT")
	if not out.is_empty() and not file.is_empty():
		for name in DirAccess.get_files_at(sessions):
			if name.begins_with("session-"): DirAccess.copy_absolute(ProjectSettings.globalize_path(sessions.path_join(name)), out)
	main.free()
	_end(saved)
	return true

func test_web_save_downloads(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	overlay.web = true
	var downloads: Array = []
	overlay.download = func(buffer: PackedByteArray, file_name: String, mime: String) -> void: downloads.append([buffer.size(), file_name, mime])
	var done: Array[int] = []
	overlay.finished.connect(func() -> void: done.append(1))
	_mark(overlay, "good", "web")
	overlay.end_match()
	_press(main, "EndSession")
	_rate_all(runner, main, 3)
	_press(main, "SaveSession")
	runner.check(downloads.size() == 1 and downloads[0][0] > 0 and downloads[0][1].begins_with("session-") and downloads[0][2] == "application/json", "PO13 one download of the session JSON, got %s" % [downloads])
	runner.check(not FileAccess.file_exists(sessions.path_join(downloads[0][1] if not downloads.is_empty() else "x")) and _form_text(main).contains("Downloaded"), "PO13 no file is written and the form says Downloaded")
	var shown: Control = _form(main).find_child("ShowInFolder", true, false) if _form(main) != null else null
	runner.check(shown == null or not shown.is_visible_in_tree(), "PO13 no Show in folder on the web")
	runner.check(done.is_empty() and _press(main, "Close") and done.size() == 1, "PO13 Close emits finished once")
	main.free()
	_end(saved)
	return true

func test_desktop_write_error_keeps_session(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	overlay.web = false
	_mark(overlay, "good", "keep me")
	overlay.end_match()
	_press(main, "EndSession")
	_rate_all(runner, main, 5)
	var blocker: String = sessions.path_join(PlaytestSession.file_name(PlaytestSession.current.data.started))
	DirAccess.make_dir_recursive_absolute(blocker) # a directory in the file's place makes the open fail without an engine error
	_press(main, "SaveSession")
	runner.check(_form_text(main).contains("Could not save"), "PO14 a failed write says Could not save, got '%s'" % _form_text(main))
	runner.check(PlaytestSession.current != null and PlaytestSession.current.data.matches.size() == 1 and PlaytestSession.current.data.answers.size() > 0, "PO14 the session stays in memory with its match and answers")
	var again: Button = _form(main).find_child("SaveSession", true, false) if _form(main) != null else null
	runner.check(again != null and again.is_visible_in_tree(), "PO14 SaveSession is offered again")
	DirAccess.remove_absolute(blocker)
	_press(main, "SaveSession")
	runner.check(_form_text(main).contains("Saved to") and _saved_session().get("matches", []).size() == 1, "PO14 the retry writes the file")
	main.free()
	_end(saved)
	return true

func _fabricate(session: PlaytestSession, matches: int, markers: int) -> void:
	for m in matches:
		for k in markers: session.add_marker(MarkerCapture.marker(["good", "bad", "confusing"][k % 3], "marker %d.%d with a longish note to wrap" % [m, k], {"tick": k * 10}, ""))
		session.finish_match({"mode": "offline", "end_tick": 100})

func _visible_buttons(form: Control) -> Array[Button]:
	var found: Array[Button] = []
	for node in form.find_children("*", "Button", true, false):
		if node.is_visible_in_tree(): found.append(node)
	return found

func _in_scroll(node: Node, form: Node) -> bool:
	var up: Node = node.get_parent()
	while up != null and up != form:
		if up is ScrollContainer: return true
		up = up.get_parent()
	return false

func _check_form_layout(runner, main, form: Control, size: Vector2i, stage: String) -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(size))
	runner.check(form.visible and screen.encloses(form.get_global_rect()), "PO15 %s form inside %s, rect %s" % [stage, size, form.get_global_rect()])
	for other in ["HUD/Status", "HUD/Economy", "HUD/Result", "HUD/Restart"]:
		var control: Control = main.get_node(other)
		runner.check(not form.get_global_rect().intersects(Rect2(control.global_position, control.get_combined_minimum_size())), "PO15 %s form clear of %s at %s" % [stage, other, size])
	var scroll: Control = form.find_children("*", "ScrollContainer", true, false)[0]
	var shown: Array[Button] = []
	for button in _visible_buttons(form):
		var rect: Rect2 = button.get_global_rect()
		if _in_scroll(button, form):
			if scroll.get_global_rect().encloses(rect): shown.append(button)
		else:
			runner.check(form.get_global_rect().encloses(rect), "PO15 %s pinned button %s inside the form at %s" % [stage, button.name, size])
			shown.append(button)
	for i in shown.size():
		for j in range(i + 1, shown.size()):
			runner.check(not shown[i].get_global_rect().intersects(shown[j].get_global_rect()), "PO15 %s buttons %s and %s overlap at %s" % [stage, shown[i].name, shown[j].name, size])

func test_form_layout(runner) -> bool:
	var saved: String = _begin()
	var card: Dictionary = FocusCards.card(CARD_ECONOMY, FocusCards.load_cards())
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		PlaytestSession.current = null
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var main = await _scene(runner, Skirmish, port)
		var overlay = main.get_node("HUD/Playtest")
		_camera(main)
		_fabricate(PlaytestSession.current, 2, 6)
		for k in 6: PlaytestSession.current.add_marker(MarkerCapture.marker("bad", "pending %d with a longish note to wrap" % k, {"tick": k}, ""))
		overlay.match_record = func() -> Dictionary: return {"mode": "offline", "end_tick": 100}
		overlay.end_match()
		await runner.process_frame
		await runner.process_frame
		runner.check(main.get_viewport().get_visible_rect().size == Vector2(size) and PlaytestSession.current.data.matches.size() == 3, "PO15 fixture: a real %s viewport and 3 matches" % size)
		var form: Control = _form(main)
		if form == null:
			runner.check(false, "PO15 the form exists")
			port.free()
			continue
		_check_form_layout(runner, main, form, size, "review")
		_press(main, "EndSession")
		await runner.process_frame
		await runner.process_frame
		_check_form_layout(runner, main, form, size, "questions")
		_rate_all(runner, main, 2)
		_press(main, "SaveSession")
		await runner.process_frame
		await runner.process_frame
		_check_form_layout(runner, main, form, size, "saved")
		port.free()
	_end(saved)
	return true

func test_resume_uses_stored_card(runner) -> bool:
	var saved: String = _begin(true, CARD_TUNNELS)
	var stored := PlaytestSession.resume_or_open(CARD_TUNNELS, "0.11.0-dev+abc")
	stored.finish_match({"mode": "offline", "end_tick": 10})
	PlaytestSession.current = null
	FocusCards.chosen = ""
	var main = await _scene(runner)
	var list: Control = main.get_node("HUD/Playtest/Checklist")
	runner.check(PlaytestSession.current != null and PlaytestSession.current.data.focus == CARD_TUNNELS, "PO16 the resumed sitting keeps its card")
	runner.check(list.find_child("esc", true, false) != null and list.find_child("collect", true, false) == null, "PO16 the checklist is the stored card's, not card 1's")
	main.free()
	_end(saved)
	return true

func test_restart_drops_pending_markers(runner) -> bool:
	var saved: String = _begin()
	var main = await _scene(runner)
	var overlay = main.get_node("HUD/Playtest")
	_camera(main)
	_mark(overlay, "bad", "abandoned")
	main._restart()
	runner.check(PlaytestSession.current.pending_markers().is_empty(), "PO17 a restart drops the abandoned match's markers")
	_mark(overlay, "bad", "helper switched off")
	overlay.set_active(false)
	main._restart()
	overlay.set_active(true)
	runner.check(PlaytestSession.current.pending_markers().is_empty(), "PO17 a restart with the helper off drops them too, got %d" % PlaytestSession.current.pending_markers().size())
	main.free()
	_end(saved)
	return true

func test_scale_legend(runner) -> bool:
	var saved: String = _begin()
	var session := PlaytestSession.resume_or_open(CARD_ECONOMY, "0.11.0-dev+abc")
	session.finish_match({"mode": "offline", "end_tick": 10})
	var card: Dictionary = FocusCards.card(CARD_ECONOMY, FocusCards.load_cards())
	var form := SessionForm.new()
	runner.root.add_child(form)
	form.open_questions(session, card)
	var legends: Array[Node] = form.find_children("ScaleLegend", "Label", true, false)
	runner.check(legends.size() == 1 and (legends[0] as Label).text == SessionForm.SCALE_LEGEND, "PO18 one ScaleLegend with the exact text, got %d" % legends.size())
	if legends.size() == 1:
		var box: Node = legends[0].get_parent()
		var last: Control = box.find_child("%s_5" % card.questions[card.questions.size() - 1].id, true, false)
		var match_label: int = -1
		for child in box.get_children():
			if child is Label and child.text == "Match 1": match_label = child.get_index()
		runner.check(last != null and legends[0].get_index() > last.get_parent().get_index() and legends[0].get_index() < match_label, "PO18 the legend sits after the last question and before Match 1")
	form.free()
	_end(saved)
	return true
