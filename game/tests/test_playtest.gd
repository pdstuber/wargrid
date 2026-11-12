@warning_ignore_start("untyped_declaration")
extends RefCounted

const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const Launcher = preload("res://scenes/launcher.tscn")
const SHIPPED := ["p1-frc-economy", "p1-frc-tunnels-online", "p1-look-and-m6-fixes"]
var scratch: String = "user://test-playtest-settings-%d.cfg" % OS.get_process_id()
var commit_scratch: String = "user://test-playtest-commit-%d.txt" % OS.get_process_id()

func cases() -> Array[Callable]:
	return [test_shipped_focus_file_valid, test_focus_validation, test_trigger_matching, test_switch_defaults_and_override, test_build_id, test_launcher_focus_card]

func _begin() -> String:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	return saved

func _end(saved: String) -> void:
	DirAccess.remove_absolute(scratch)
	DirAccess.remove_absolute(commit_scratch)
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

func _launcher(runner, size: Vector2i):
	runner.root.size = size
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	await runner.process_frame
	return launcher

func _labels_inside(runner, node: Node, view: Rect2, label: String) -> void:
	for child in node.get_children():
		if child is Label: runner.check(view.encloses(child.get_global_rect()), "PT6 %s label %s inside the viewport" % [label, child.name])
		_labels_inside(runner, child, view, label)

func test_launcher_focus_card(runner) -> bool:
	var saved := _begin()
	var original: Vector2i = runner.root.size
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var label := str(size)
		PlaytestSettings.save_enabled(true)
		var launcher = await _launcher(runner, size)
		var box: Control = launcher.get_node("Center/Box")
		var button: Button = launcher.get_node_or_null("Center/Box/ThisBuild")
		runner.check(button != null and button.visible, "PT6 ThisBuild shows with the helper on at %s" % label)
		if button != null:
			_clear_of_siblings(runner, box, button, view, "ThisBuild " + label)
			runner.check(box.get_child(box.get_node("Offline").get_index() + 1) == button, "PT6 ThisBuild sits right after Offline")
			button.pressed.emit()
			await runner.process_frame
			await runner.process_frame
			var panel: Control = launcher.get_node_or_null("FocusPanel")
			runner.check(panel != null and panel.visible and not launcher.get_node("Center").visible, "PT6 ThisBuild opens FocusPanel and hides Center at %s" % label)
			if panel != null:
				runner.check(view.encloses(panel.get_global_rect()), "PT6 FocusPanel inside the viewport at %s" % label)
				_labels_inside(runner, panel, view, label)
				var picker: OptionButton = panel.find_child("Picker", true, false)
				runner.check(picker.item_count == 3, "PT6 Picker lists 3 cards, got %d" % picker.item_count)
				picker.select(1)
				picker.item_selected.emit(1)
				runner.check(FocusCards.chosen == "p1-frc-tunnels-online", "PT6 choosing item 2 sets the chosen card, got %s" % FocusCards.chosen)
				panel.find_child("Close", true, false).pressed.emit()
				runner.check(not panel.visible and launcher.get_node("Center").visible, "PT6 Close returns to the launcher at %s" % label)
		launcher.free()
		FocusCards.chosen = ""
		PlaytestSettings.save_enabled(false)
		launcher = await _launcher(runner, size)
		box = launcher.get_node("Center/Box")
		button = launcher.get_node_or_null("Center/Box/ThisBuild")
		runner.check(button == null or not button.visible, "PT6 ThisBuild hidden with the switch off at %s" % label)
		var toggle: CheckButton = launcher.get_node_or_null("Center/Box/PlaytestSwitch")
		runner.check(toggle != null and not toggle.button_pressed, "PT6 PlaytestSwitch shows and starts off at %s" % label)
		if toggle != null:
			_clear_of_siblings(runner, box, toggle, view, "PlaytestSwitch " + label)
			toggle.button_pressed = true
			await runner.process_frame
			await runner.process_frame
			button = launcher.get_node_or_null("Center/Box/ThisBuild")
			runner.check(button != null and button.visible, "PT6 pressing the switch shows ThisBuild at %s" % label)
			runner.check(PlaytestSettings.enabled("0.11.0"), "PT6 pressing the switch stores it at %s" % label)
			if button != null: _clear_of_siblings(runner, box, button, view, "ThisBuild after switch " + label)
			toggle.button_pressed = false
			await runner.process_frame
			runner.check(button == null or not button.visible, "PT6 switching off hides ThisBuild at %s" % label)
		launcher.free()
	runner.root.size = original
	_end(saved)
	return true
