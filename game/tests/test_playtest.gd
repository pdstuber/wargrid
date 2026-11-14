@warning_ignore_start("untyped_declaration")
extends RefCounted

const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const MarkerCapture = preload("res://scripts/playtest/marker_capture.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const Launcher = preload("res://scenes/launcher.tscn")
const SHIPPED := ["p2.1-new-launcher", "p2-you-clicked", "p1-frc-economy", "p1-frc-tunnels-online", "p1-look-and-m6-fixes"]
var scratch: String = "user://test-playtest-settings-%d.cfg" % OS.get_process_id()
var commit_scratch: String = "user://test-playtest-commit-%d.txt" % OS.get_process_id()
var sessions: String = "user://test-playtests-%d" % OS.get_process_id()
var saved_dir: String = ""

func cases() -> Array[Callable]:
	return [test_shipped_focus_file_valid, test_focus_validation, test_trigger_matching, test_switch_defaults_and_override, test_build_id, test_launcher_focus_card, test_switch_saves_without_cards, test_launcher_shows_open_sitting_card, test_capture_bounds, test_marker_fields, test_session_schema, test_session_web_download, test_session_desktop_write, test_session_resumes_after_restart, test_suite_playtest_dir_redirected]

func _begin() -> String:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	saved_dir = PlaytestSession.dir
	PlaytestSession.dir = sessions
	PlaytestSession.current = null
	WargridTestRunner.remove_dir(sessions)
	return saved

func _end(saved: String) -> void:
	DirAccess.remove_absolute(scratch)
	DirAccess.remove_absolute(commit_scratch)
	WargridTestRunner.remove_dir(sessions)
	PlaytestSession.dir = saved_dir
	PlaytestSession.current = null
	AudioSettings.path = saved
	FocusCards.chosen = ""

func _shipped() -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(FocusCards.PATH))

func _valid_card(id: String = "c1") -> Dictionary:
	return {"id": id, "title": "T", "new": ["a"],
		"try": [{"id": "t1", "text": "x"}, {"id": "t2", "text": "y", "trigger": "gather"}],
		"questions": [{"id": "q1", "text": "a"}, {"id": "q2", "text": "b"}, {"id": "q3", "text": "c"}]}

func _questions(count: int) -> Array:
	var list: Array = []
	for i in count: list.append({"id": "q%d" % i, "text": "q"})
	return list

func test_shipped_focus_file_valid(runner) -> bool:
	var errors: PackedStringArray = FocusCards.errors(_shipped())
	runner.check(errors.is_empty(), "PT1 shipped focus file is valid, got %s" % [errors])
	var ids: Array = FocusCards.load_cards().map(func(card: Dictionary) -> String: return card.id)
	runner.check(ids == SHIPPED, "PT1 shipped cards in file order, got %s" % [ids])
	return true

func test_focus_validation(runner) -> bool:
	runner.check(FocusCards.errors([_valid_card()]).is_empty(), "PT2 a valid card has no errors, got %s" % [FocusCards.errors([_valid_card()])])
	var duplicate_try := _valid_card()
	duplicate_try.try[1].id = "t1"
	var two := _valid_card()
	two.questions = _questions(2)
	var six := _valid_card()
	six.questions = _questions(6)
	var unknown_trigger := _valid_card()
	unknown_trigger.try[1].trigger = "fly"
	var unknown_kind := _valid_card()
	unknown_kind.try[1].trigger = "build:no_such_kind"
	var bad_key := _valid_card()
	bad_key.try[1].trigger = "key:NotAKey"
	var no_title := _valid_card()
	no_title.erase("title")
	var broken: Dictionary = {
		"duplicate card id": [_valid_card("same"), _valid_card("same")],
		"duplicate try id": [duplicate_try], "2 questions": [two], "6 questions": [six],
		"unknown trigger": [unknown_trigger], "unknown kind": [unknown_kind], "bad key": [bad_key],
		"missing title": [no_title], "not a list": {"id": "x"}, "empty list": []}
	for label: String in broken:
		runner.check(not FocusCards.errors(broken[label]).is_empty(), "PT2 %s is rejected" % label)
	for trigger in ["gather", "build:frc_supply_center", "produce:frc_builder", "esc_menu", "key:F3"]:
		runner.check(FocusCards.trigger_error(trigger) == "", "PT2 trigger %s is valid, got %s" % [trigger, FocusCards.trigger_error(trigger)])
	runner.check("choose_faction" not in FocusCards.COMMAND_TYPES and "gather" in FocusCards.COMMAND_TYPES, "PT2 command types leave out choose_faction")
	runner.check(FocusCards.card("p1-frc-tunnels-online", FocusCards.load_cards()).get("id") == "p1-frc-tunnels-online", "PT2 card by id")
	runner.check(FocusCards.card("nope", FocusCards.load_cards()).get("id") == SHIPPED[0] and FocusCards.card("", FocusCards.load_cards()).get("id") == SHIPPED[0], "PT2 unknown or empty id gives the first card")
	return true

func test_trigger_matching(runner) -> bool:
	runner.check(FocusCards.matches_command("build:frc_supply_center", {"type": "build", "building_kind": "frc_supply_center"}), "PT3 build trigger matches its kind")
	runner.check(not FocusCards.matches_command("build:frc_supply_center", {"type": "build", "building_kind": "usa_barracks"}), "PT3 build trigger ignores another kind")
	runner.check(FocusCards.matches_command("produce:frc_builder", {"type": "produce", "unit_kind": "frc_builder"}), "PT3 produce trigger matches its kind")
	runner.check(FocusCards.matches_command("gather", {"type": "gather"}), "PT3 plain trigger matches the command type")
	runner.check(not FocusCards.matches_command("gather", {"type": "attack"}), "PT3 plain trigger ignores another type")
	runner.check(not FocusCards.matches_command("esc_menu", {"type": "gather"}) and not FocusCards.matches_command("esc_menu", {"type": "esc_menu"}), "PT3 esc_menu matches no command")
	return true

func _write_switch(value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(scratch)
	config.set_value("playtest", "enabled", value)
	config.save(scratch)

func test_switch_defaults_and_override(runner) -> bool:
	var saved := _begin()
	runner.check(PlaytestSettings.enabled("0.11.0-dev") and not PlaytestSettings.enabled("0.11.0"), "PT4 unset: on for a dev build, off for a release")
	PlaytestSettings.save_enabled(false)
	runner.check(not PlaytestSettings.enabled("0.11.0-dev"), "PT4 stored off beats the dev default")
	PlaytestSettings.save_enabled(true)
	runner.check(PlaytestSettings.enabled("0.11.0"), "PT4 stored on beats the release default")
	_write_switch("yes")
	runner.check(PlaytestSettings.enabled("0.11.0-dev") and not PlaytestSettings.enabled("0.11.0"), "PT4 a stored string counts as unset")
	_write_switch(1)
	runner.check(PlaytestSettings.enabled("0.11.0-dev") and not PlaytestSettings.enabled("0.11.0"), "PT4 a stored number counts as unset")
	DirAccess.remove_absolute(scratch)
	AudioSettings.save_volumes({"music": 0.5, "effects": 0.25, "voice": 0.75})
	PlaytestSettings.save_enabled(false)
	var volumes: Dictionary = AudioSettings.load_volumes()
	runner.check(volumes.music == 0.5 and volumes.effects == 0.25 and volumes.voice == 0.75, "PT4 saving the switch keeps the volumes, got %s" % [volumes])
	AudioSettings.save_volumes({"music": 0.5, "effects": 0.25, "voice": 0.75})
	runner.check(not PlaytestSettings.enabled("0.11.0-dev"), "PT4 saving the volumes keeps the switch")
	_end(saved)
	return true

func test_build_id(runner) -> bool:
	var saved := _begin()
	var file := FileAccess.open(commit_scratch, FileAccess.WRITE)
	file.store_string("abc1234\n")
	file.close()
	runner.check(PlaytestSettings.build_id("0.11.0-dev", commit_scratch) == "0.11.0-dev+abc1234", "PT5 build id joins version and commit, got %s" % PlaytestSettings.build_id("0.11.0-dev", commit_scratch))
	DirAccess.remove_absolute(commit_scratch)
	runner.check(PlaytestSettings.build_id("0.11.0-dev", commit_scratch) == "0.11.0-dev+unknown", "PT5 a missing commit file gives unknown")
	runner.check(PlaytestSettings.build_id("0.11.0", commit_scratch) == "0.11.0+unknown", "PT5 a release version has no dev suffix")
	_end(saved)
	return true

func _clear_of_siblings(runner, box: Control, control: Control, view: Rect2, label: String) -> void:
	runner.check(control.is_visible_in_tree() and view.encloses(control.get_global_rect()), "PT6 %s inside the viewport" % label)
	for other in box.get_children():
		if other != control and other is Control and other.visible:
			runner.check(not control.get_global_rect().intersects(other.get_global_rect()), "PT6 %s clear of %s" % [label, other.name])

func _launcher(runner, port: SubViewport, page_name: String = "Settings"):
	var launcher = Launcher.instantiate()
	port.add_child(launcher)
	launcher.show_page(page_name)
	await runner.process_frame
	await runner.process_frame
	return launcher

func _labels_inside(runner, node: Node, view: Rect2, label: String) -> void:
	for child in node.get_children():
		if child is Label: runner.check(view.encloses(child.get_global_rect()), "PT6 %s label %s inside the viewport" % [label, child.name])
		_labels_inside(runner, child, view, label)

func test_launcher_focus_card(runner) -> bool:
	var saved := _begin()
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var port := SubViewport.new()
		port.size = size
		runner.root.add_child(port)
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var label := str(size)
		for page_name: String in ["Play", "Join"]:
			await _check_this_build(runner, port, view, "%s %s" % [page_name, label], page_name)
		port.free()
	_end(saved)
	return true

func _check_this_build(runner, port: SubViewport, view: Rect2, label: String, page_name: String) -> void:
	PlaytestSettings.save_enabled(true)
	var launcher = await _launcher(runner, port, page_name)
	runner.check(launcher.get_viewport().get_visible_rect().size == view.size, "PT6 the viewport really is %s" % label)
	var page: Control = launcher.get_node("Pages/" + page_name)
	var button: Button = launcher.get_node_or_null("Pages/%s/ThisBuild" % page_name)
	runner.check(button != null and button.visible, "PT6 ThisBuild shows with the helper on at %s" % label)
	if button != null:
		_clear_of_siblings(runner, page, button, view, "ThisBuild " + label)
		runner.check(page.get_child(button.get_index() + 1).name == "Divider", "PT6 ThisBuild sits just above the footer divider at %s" % label)
		button.pressed.emit()
		await runner.process_frame
		await runner.process_frame
		var panel: Control = launcher.get_node_or_null("FocusPanel")
		runner.check(panel != null and panel.visible and not launcher.get_node("Pages").visible, "PT6 ThisBuild opens FocusPanel and hides the pages at %s" % label)
		if panel != null:
			runner.check(view.encloses(panel.get_global_rect()), "PT6 FocusPanel inside the viewport at %s" % label)
			_labels_inside(runner, panel, view, label)
			var picker: OptionButton = panel.find_child("Picker", true, false)
			runner.check(picker.item_count == 5, "PT6 Picker lists 5 cards, got %d" % picker.item_count)
			picker.select(2)
			picker.item_selected.emit(2)
			runner.check(FocusCards.chosen == "p1-frc-economy", "PT6 choosing item 3 sets the chosen card, got %s" % FocusCards.chosen)
			panel.find_child("Close", true, false).pressed.emit()
			runner.check(not panel.visible and launcher.get_node("Pages").visible, "PT6 Close returns to the launcher at %s" % label)
	launcher.free()
	FocusCards.chosen = ""
	PlaytestSettings.save_enabled(false)
	launcher = await _launcher(runner, port, "Settings")
	var box: Control = launcher.get_node("Pages/Settings/Body/Playtest")
	var kept: Array = []
	for child in box.get_children(): kept.append(str(child.name))
	runner.check(kept == ["GraphicsHeader", "Quality", "Neon", "Smooth", "Destinations", "PlaytestHeader", "PlaytestSwitch", "PlaytestHint"], "PT6 the Playtest column keeps only Graphics, then the switch and its hint at %s, got %s" % [label, kept])
	var toggle: CheckButton = launcher.get_node_or_null("Pages/Settings/Body/Playtest/PlaytestSwitch")
	runner.check(toggle != null and not toggle.button_pressed, "PT6 PlaytestSwitch shows and starts off at %s" % label)
	button = launcher.get_node_or_null("Pages/%s/ThisBuild" % page_name)
	runner.check(button == null or not button.visible, "PT6 ThisBuild hidden with the switch off at %s" % label)
	if toggle != null:
		_clear_of_siblings(runner, box, toggle, view, "PlaytestSwitch " + label)
		toggle.button_pressed = true
		await runner.process_frame
		launcher.show_page(page_name)
		await runner.process_frame
		await runner.process_frame
		button = launcher.get_node_or_null("Pages/%s/ThisBuild" % page_name)
		runner.check(button != null and button.visible, "PT6 pressing the switch shows ThisBuild at %s" % label)
		runner.check(PlaytestSettings.enabled("0.11.0"), "PT6 pressing the switch stores it at %s" % label)
		if button != null: _clear_of_siblings(runner, launcher.get_node("Pages/" + page_name), button, view, "ThisBuild after switch " + label)
		launcher.show_page("Settings")
		toggle.button_pressed = false
		await runner.process_frame
		runner.check(button == null or not button.visible, "PT6 switching off hides ThisBuild at %s" % label)
	launcher.free()

func test_switch_saves_without_cards(runner) -> bool:
	var saved := _begin()
	var launcher = Launcher.instantiate()
	var none: Array[Dictionary] = []
	launcher.focus_cards = none
	runner.root.add_child(launcher)
	await runner.process_frame
	var toggle: CheckButton = launcher.get_node("Pages/Settings/Body/Playtest/PlaytestSwitch")
	runner.check(launcher.get_node_or_null("FocusPanel") == null, "R6 fixture: with no focus cards the launcher builds no FocusPanel")
	# Flip from the version's default twice; each read uses the opposite default, so only a stored value passes.
	for i in 2:
		toggle.button_pressed = not toggle.button_pressed
		if toggle.button_pressed: runner.check(PlaytestSettings.enabled("0.11.0"), "R6 the switch stores on without focus cards")
		else: runner.check(not PlaytestSettings.enabled("0.11.0-dev"), "R6 the switch stores off without focus cards")
	launcher.free()
	_end(saved)
	return true

func _image(width: int, height: int) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	image.fill(Color(0.2, 0.5, 0.3))
	return image

func _grainy(width: int, height: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bytes := PackedByteArray()
	bytes.resize(width * height * 3)
	for i in bytes.size(): bytes[i] = clampi(128 + rng.randi_range(-128, 128), 0, 255)
	return Image.create_from_data(width, height, false, Image.FORMAT_RGB8, bytes)

func _decode(encoded: String) -> Image:
	var image := Image.new()
	image.load_jpg_from_buffer(Marshalls.base64_to_raw(encoded))
	return image

func test_launcher_shows_open_sitting_card(runner) -> bool:
	var saved := _begin()
	PlaytestSettings.save_enabled(true)
	var port := SubViewport.new()
	port.size = Vector2i(1280, 720)
	runner.root.add_child(port)
	var launcher = await _launcher(runner, port, "Play")
	var picker: OptionButton = launcher.get_node("FocusPanel").find_child("Picker", true, false)
	runner.check(not picker.disabled, "PT6b with no sitting the picker is enabled")
	launcher.free()
	var stored := PlaytestSession.resume_or_open(SHIPPED[2], "0.11.0-dev+abc")
	stored.finish_match({"mode": "offline", "end_tick": 10})
	PlaytestSession.current = null
	FocusCards.chosen = ""
	launcher = await _launcher(runner, port, "Play")
	var title: String = FocusCards.card(SHIPPED[2], FocusCards.load_cards()).title
	var panel: Control = launcher.get_node("FocusPanel")
	runner.check(launcher.get_node("Pages/Play/ThisBuild").text == "This build: " + title, "PT6b ThisBuild names the open sitting's card, got %s" % launcher.get_node("Pages/Play/ThisBuild").text)
	runner.check(panel.find_child("Picker", true, false).disabled, "PT6b the picker is disabled while a sitting is open")
	var shown := PackedStringArray()
	for label: Label in panel.find_children("*", "Label", true, false): shown.append(label.text)
	runner.check(title in shown, "PT6b the panel shows the open sitting's card, got %s" % [shown])
	launcher.free()
	port.free()
	_end(saved)
	return true

func test_capture_bounds(runner) -> bool:
	runner.check(MarkerCapture.jpg_base64(null) == "", "PT7 a null image gives no jpg")
	runner.check(MarkerCapture.jpg_base64(Image.new()) == "", "PT7 an empty image gives no jpg")
	var flat := _image(1920, 1080)
	var decoded := _decode(MarkerCapture.jpg_base64(flat))
	runner.check(decoded.get_size() == Vector2i(640, 360), "PT7 1920x1080 is scaled to 640x360, got %s" % decoded.get_size())
	runner.check(flat.get_size() == Vector2i(1920, 1080), "PT7 the caller's image keeps its size, got %s" % flat.get_size())
	var tiny := _image(1, 1)
	runner.check(_decode(MarkerCapture.jpg_base64(tiny)).get_size() == Vector2i(1, 1), "PT7 a 1x1 image stays 1x1")
	var noisy := _grainy(1920, 1080)
	var encoded := MarkerCapture.jpg_base64(noisy)
	runner.check(encoded == "" or Marshalls.base64_to_raw(encoded).size() <= MarkerCapture.MAX_JPG_BYTES, "PT7 a noise image is bounded or dropped")
	runner.check(noisy.get_size() == Vector2i(1920, 1080), "PT7 the noise image keeps its size")
	var grainy := _grainy(640, 360)
	runner.check(grainy.save_jpg_to_buffer(MarkerCapture.QUALITY).size() > MarkerCapture.MAX_JPG_BYTES and grainy.save_jpg_to_buffer(MarkerCapture.FALLBACK_QUALITY).size() <= MarkerCapture.MAX_JPG_BYTES, "PT7 fixture: the grainy image is too big at the first quality and fits at the fallback")
	var kept_size: int = Marshalls.base64_to_raw(MarkerCapture.jpg_base64(grainy)).size()
	runner.check(kept_size > 0 and kept_size <= MarkerCapture.MAX_JPG_BYTES, "PT7 the fallback quality keeps a screenshot the first quality cannot")
	return true

func test_marker_fields(runner) -> bool:
	var context := {"tick": 90, "camera": [3.5, 4.0], "selected": [7], "over": false, "menu": false}
	var marker := MarkerCapture.marker("bad", "stuck", context, "QUJD")
	var keys: Array = marker.keys()
	keys.sort()
	runner.check(keys == ["camera", "comment", "jpg", "kind", "selected", "text", "tick"], "PT8 marker has exactly seven keys, got %s" % [keys])
	runner.check(marker.tick == 90 and marker.kind == "bad" and marker.text == "stuck" and marker.camera == [3.5, 4.0] and marker.selected == [7] and marker.comment == "" and marker.jpg == "QUJD", "PT8 marker values, got %s" % [marker])
	return true

func _record(seed_value: int) -> Dictionary:
	return {"mode": "offline", "map": "dry_wells", "seed": seed_value, "factions": ["frc", "china"], "seat": 0, "end_tick": 600, "end_digest": "abc", "result": "won", "commands": ["l1"], "build": "0.11.0-dev+abc"}

func _marker(tick: int) -> Dictionary:
	return MarkerCapture.marker("good", "ok", {"tick": tick, "camera": [1.0, 2.0], "selected": []}, "")

func _two_match_session() -> PlaytestSession:
	var session := PlaytestSession.resume_or_open("c1", "0.11.0-dev+abc")
	session.add_marker(_marker(10))
	session.finish_match(_record(1))
	session.add_marker(_marker(20))
	session.finish_match(_record(2))
	return session

func test_session_schema(runner) -> bool:
	var saved := _begin()
	var session := _two_match_session()
	session.set_answer("q1", 4, "fine")
	session.set_checked("t1", true)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(session.data))
	var keys: Array = parsed.keys()
	keys.sort()
	runner.check(keys == ["answers", "build", "checklist", "focus", "format", "matches", "started"], "PT9 session keys, got %s" % [keys])
	runner.check(parsed.format == 1 and parsed.build == "0.11.0-dev+abc" and parsed.focus == "c1", "PT9 format, build and focus")
	runner.check(parsed.matches.size() == 2 and parsed.matches[1].markers[0].tick == 20 and parsed.matches[0].markers.size() == 1, "PT9 each match keeps its own marker")
	runner.check(int(parsed.answers.q1.score) == 4 and parsed.answers.q1.text == "fine" and parsed.checklist.t1 == true, "PT9 answer and checklist, got %s" % [parsed.answers])
	var match_keys: Array = parsed.matches[0].keys()
	match_keys.sort()
	runner.check(match_keys == ["build", "commands", "end_digest", "end_tick", "factions", "map", "markers", "mode", "result", "seat", "seed"], "PT9 match keys, got %s" % [match_keys])
	session.set_comment(0, 0, "why")
	runner.check(session.data.matches[0].markers[0].comment == "why", "PT9 set_comment reaches the marker")
	_end(saved)
	return true

func test_session_web_download(runner) -> bool:
	var saved := _begin()
	var session := _two_match_session()
	var downloads: Array = []
	var name := session.write(true, func(buffer: PackedByteArray, file_name: String, mime: String) -> void: downloads.append([buffer, file_name, mime]))
	runner.check(downloads.size() == 1 and downloads[0][2] == "application/json" and downloads[0][1] == PlaytestSession.file_name(session.data.started) and name == downloads[0][1], "PT10 one download with the session file name, got %s" % [name])
	var parsed: Variant = JSON.parse_string(downloads[0][0].get_string_from_utf8())
	runner.check(parsed is Dictionary and JSON.stringify(parsed) == JSON.stringify(JSON.parse_string(JSON.stringify(session.data, "\t"))), "PT10 the buffer parses back to data")
	var written: Array = Array(DirAccess.get_files_at(sessions))
	runner.check(not written.any(func(file: String) -> bool: return file.begins_with("session-")), "PT10 the browser path writes no session file, got %s" % [written])
	runner.check(PlaytestSession.current == null and not FileAccess.file_exists(sessions.path_join("current.json")), "PT10 the sitting is closed")
	var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(sessions.path_join("last-session.json")))
	runner.check(kept is Dictionary and kept.started == session.data.started and kept.matches.size() == 2, "PT10 the written JSON is kept as last-session.json in case the browser blocks the download")
	var next := _two_match_session()
	next.data.started = "2099-01-01T00:00:00"
	next.write(true, func(_buffer: PackedByteArray, _file_name: String, _mime: String) -> void: pass)
	runner.check(JSON.parse_string(FileAccess.get_file_as_string(sessions.path_join("last-session.json"))).started == "2099-01-01T00:00:00", "PT10 last-session.json is overwritten by the next save")
	_end(saved)
	return true

func test_session_desktop_write(runner) -> bool:
	var saved := _begin()
	var session := _two_match_session()
	runner.check(FileAccess.file_exists(sessions.path_join("current.json")), "PT11 finishing a match mirrors current.json")
	var path := session.write(false, func(_buffer: PackedByteArray, _file_name: String, _mime: String) -> void: pass)
	var file := PlaytestSession.file_name(session.data.started)
	runner.check(path.ends_with(file) and FileAccess.file_exists(sessions.path_join(file)), "PT11 session file written, got %s" % path)
	runner.check(not FileAccess.file_exists(sessions.path_join("current.json")) and PlaytestSession.current == null, "PT11 current.json removed and sitting closed")
	runner.check(not file.contains(":") and file.begins_with("session-") and file.ends_with(".json"), "PT11 file name has no colon, got %s" % file)
	var again := PlaytestSession.resume_or_open("c1", "b")
	again.discard()
	runner.check(PlaytestSession.current == null and not FileAccess.file_exists(sessions.path_join("current.json")), "PT11 discard clears the sitting")
	_end(saved)
	return true

func test_session_resumes_after_restart(runner) -> bool:
	var saved := _begin()
	runner.check(PlaytestSession.open_count() == -1, "PT12 no sitting gives -1, got %d" % PlaytestSession.open_count())
	var session := PlaytestSession.resume_or_open("c1", "b")
	runner.check(PlaytestSession.resume_or_open("other", "x") == session, "PT12 resume returns the current sitting")
	var started: String = session.data.started
	runner.check(session.finish_match(_record(1)) == 0, "PT12 first match has index 0")
	PlaytestSession.current = null
	runner.check(PlaytestSession.open_count() == 1, "PT12 the file counts one match after a restart, got %d" % PlaytestSession.open_count())
	var resumed := PlaytestSession.resume_or_open("c1", "b")
	runner.check(resumed.data.matches.size() == 1 and resumed.data.started == started, "PT12 restart resumes the same sitting")
	PlaytestSession.current = null
	var file := FileAccess.open(sessions.path_join("current.json"), FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	runner.check(PlaytestSession.open_count() == -1, "PT12 a corrupt file counts as none")
	var fresh := PlaytestSession.resume_or_open("c1", "b")
	runner.check(fresh.data.matches.is_empty() and fresh.data.format == 1, "PT12 a corrupt file gives a new empty sitting")
	_end(saved)
	return true

func test_suite_playtest_dir_redirected(runner) -> bool:
	runner.check(PlaytestSession.dir != "user://playtests", "PT13 the suite never writes the player's real playtests folder, got %s" % PlaytestSession.dir)
	return true
