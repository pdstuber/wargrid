@warning_ignore_start("untyped_declaration")
extends RefCounted

const JoinLink = preload("res://scripts/join_link.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const PasteShim = preload("res://scripts/presentation/paste_shim.gd")
const Launcher = preload("res://scenes/launcher.tscn")

const BASE := "https://wargrid-web-test.fly.dev/"
const EXP_RELAY := "wss://x.example/ws"
var scratch: String = "user://test-join-link-%d.cfg" % OS.get_process_id()

func cases() -> Array[Callable]:
	return [test_query_parses_like_the_browser, test_code_accepts_only_relay_codes, test_relay_accepts_only_wss, test_code_from_pasted_text, test_link_carries_relay_only_when_not_default, test_prerelease_is_the_dev_suffix, test_paste_join_field_takes_the_code, test_paste_inserts_at_caret, test_paste_refuses_unusable_targets, test_paste_cannot_reach_release_relay, test_shim_only_on_web, test_context_menu_paste_is_replaced]

func test_query_parses_like_the_browser(runner) -> bool:
	runner.check(JoinLink.parse("").is_empty(), "JL1 empty search is {}")
	runner.check(JoinLink.parse("?").is_empty(), "JL1 lone ? is {}")
	var both: Dictionary = JoinLink.parse("?code=ABC234&relay=wss%3A%2F%2Fx.example%2Fws")
	runner.check(both.get("code") == "ABC234", "JL1 code, got %s" % [both])
	runner.check(both.get("relay") == EXP_RELAY, "JL1 relay is decoded, got %s" % [both])
	runner.check(JoinLink.parse("?code=AAA222&code=BBB333").get("code") == "AAA222", "JL1 first duplicate wins")
	var bare: Dictionary = JoinLink.parse("?x=1&code")
	runner.check(bare.get("code") == "" and bare.get("x") == "1", "JL1 key without = is empty, got %s" % [bare])
	runner.check(JoinLink.parse("?code=" + "A".repeat(3000)).is_empty(), "JL1 oversize query is {}")
	return true

func test_code_accepts_only_relay_codes(runner) -> bool:
	runner.check(JoinLink.code("ABC234") == "ABC234", "JL2 valid code")
	runner.check(JoinLink.code("abc234") == "ABC234", "JL2 lower case goes upper")
	for bad: String in ["ABC23", "ABC2345", "ABC0O1", "ABCI34", "<b>A</b>", "ABC 23"]:
		runner.check(JoinLink.code(bad) == "", "JL2 rejects '%s'" % bad)
	return true

func test_relay_accepts_only_wss(runner) -> bool:
	for good: String in [EXP_RELAY, "wss://wargrid-relay-exp.fly.dev/ws"]:
		runner.check(JoinLink.relay(good) == good, "JL3 accepts %s" % good)
	for bad: String in ["ws://x.example/ws", "https://x.example/ws", "javascript:alert(1)", "wss://", "wss:///ws", "wss://x.example/ws extra", "wss://relay.pdstuber.dev@evil.example/ws", "wss://" + "a".repeat(260)]:
		runner.check(JoinLink.relay(bad) == "", "JL3 rejects '%s'" % bad.left(40))
	return true

func test_code_from_pasted_text(runner) -> bool:
	var wanted := {
		" abc234\n": "ABC234",
		"https://wargrid-web-test.fly.dev/?code=QRS234": "QRS234",
		"join me: https://x.example/?code=QRS234&relay=wss%3A%2F%2Fy.example%2Fws thanks": "QRS234",
		"https://player.example/?code=ABC234": "ABC234",
		"my code is QRS234 ok": "QRS234",
		"thanks, code QRS234": "QRS234",
		"please join QRS234": "QRS234",
		"hello": "",
		"ABC2345": "",
		"ABCI34": "",
	}
	for text: String in wanted:
		runner.check(JoinLink.code_from(text) == wanted[text], "JL4 '%s' -> '%s', got '%s'" % [text.left(40), wanted[text], JoinLink.code_from(text)])
	runner.check(JoinLink.code_from("x".repeat(2049 - 11) + "code=ABC234").is_empty(), "JL4 2049 characters are ignored")
	return true

func test_link_carries_relay_only_when_not_default(runner) -> bool:
	runner.check(JoinLink.link(BASE, "ABC234", JoinLink.DEFAULT_RELAY) == BASE + "?code=ABC234", "JL5 default relay is left out")
	var url: String = JoinLink.link(BASE, "ABC234", EXP_RELAY)
	runner.check(url == BASE + "?code=ABC234&relay=wss%3A%2F%2Fx.example%2Fws", "JL5 relay is encoded, got %s" % url)
	var back: Dictionary = JoinLink.parse(url.substr(url.find("?")))
	runner.check(back.get("code") == "ABC234" and back.get("relay") == EXP_RELAY, "JL5 round trip, got %s" % [back])
	return true

func test_prerelease_is_the_dev_suffix(runner) -> bool:
	runner.check(PlaytestSettings.prerelease("0.12.0-dev"), "JL6 -dev is prerelease")
	for release: String in ["0.12.0", "0.12.0-rc.1", ""]:
		runner.check(not PlaytestSettings.prerelease(release), "JL6 '%s' is not prerelease" % release)
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	for version: String in ["0.12.0-dev", "0.12.0"]:
		runner.check(PlaytestSettings.enabled(version) == PlaytestSettings.prerelease(version), "JL6 enabled follows prerelease for %s" % version)
	DirAccess.remove_absolute(scratch)
	AudioSettings.path = saved
	return true

func _edit(runner, text: String = "") -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	runner.root.add_child(edit)
	return edit

func test_paste_join_field_takes_the_code(runner) -> bool:
	var edit: LineEdit = _edit(runner, "XY")
	edit.max_length = 6
	edit.add_to_group("join_code")
	runner.check(PasteShim.insert(edit, "join me https://x.example/?code=qrs234 pls"), "PS1 a link with a code is taken")
	runner.check(edit.text == "QRS234" and edit.caret_column == 6, "PS1 the code replaces the text, got '%s' caret %d" % [edit.text, edit.caret_column])
	runner.check(not PasteShim.insert(edit, "hello"), "PS1 text without a code is refused")
	runner.check(edit.text == "QRS234", "PS1 refused text leaves the field alone")
	edit.free()
	return true

func test_paste_inserts_at_caret(runner) -> bool:
	var edit: LineEdit = _edit(runner, "wss://old")
	edit.select(6, 9)
	var seen: Array[String] = []
	edit.text_changed.connect(func(value: String) -> void: seen.append(value))
	runner.check(PasteShim.insert(edit, "x.example/ws\n"), "PS2 plain text is taken")
	runner.check(edit.text == "wss://x.example/ws", "PS2 the selection is replaced, got '%s'" % edit.text)
	runner.check(seen == ["wss://x.example/ws"], "PS2 text_changed fires once with the new text, got %s" % [seen])
	edit.free()
	return true

func test_paste_refuses_unusable_targets(runner) -> bool:
	runner.check(not PasteShim.insert(null, "abc"), "PS3 no focus owner")
	var button := Button.new()
	runner.check(not PasteShim.insert(button, "abc"), "PS3 a Button")
	button.free()
	var locked: LineEdit = _edit(runner, "keep")
	locked.editable = false
	var hidden: LineEdit = _edit(runner, "keep")
	hidden.visible = false
	var plain: LineEdit = _edit(runner, "keep")
	runner.check(not PasteShim.insert(locked, "abc"), "PS3 non-editable")
	runner.check(not PasteShim.insert(hidden, "abc"), "PS3 hidden")
	runner.check(not PasteShim.insert(plain, "a".repeat(2049)), "PS3 oversize")
	runner.check(locked.text == "keep" and hidden.text == "keep" and plain.text == "keep", "PS3 refused targets keep their text")
	for edit: LineEdit in [locked, hidden, plain]:
		edit.free()
	return true

func test_paste_cannot_reach_release_relay(runner) -> bool:
	var launcher = Launcher.instantiate()
	launcher.prerelease = false
	runner.root.add_child(launcher)
	await runner.process_frame
	await runner.process_frame
	var relay: LineEdit = launcher.get_node("Pages/Play/Body/Advanced/RelayUrl")
	runner.check(not PasteShim.insert(relay, "wss://evil.example/ws"), "PS4 the hidden relay field refuses a paste")
	runner.check(relay.text == JoinLink.DEFAULT_RELAY, "PS4 the relay stays the default, got '%s'" % relay.text)
	launcher.free()
	return true

func test_shim_only_on_web(runner) -> bool:
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	await runner.process_frame
	runner.check(launcher.get_node("Pages/Join/Body/Code").is_in_group("join_code"), "PS5 the join field is in group join_code")
	runner.check(not runner.root.has_node("PasteShim"), "PS5 no shim off web")
	launcher.free()
	return true

func test_context_menu_paste_is_replaced(runner) -> bool:
	var edit: LineEdit = _edit(runner)
	edit.add_to_group("join_code")
	var reads: Array[int] = []
	var reader := func() -> void:
		reads.append(1)
		PasteShim.insert(edit, "QRS234")
	PasteShim.adopt(edit, reader)
	PasteShim.adopt(edit, reader)
	var menu: PopupMenu = edit.get_menu()
	runner.check(menu.get_item_index(LineEdit.MENU_PASTE) == -1, "PS6 the stock Paste item is gone")
	var custom := 0
	for i in menu.item_count:
		if menu.get_item_text(i) == "Paste" and menu.get_item_id(i) == PasteShim.MENU_PASTE_ID:
			custom += 1
	runner.check(custom == 1, "PS6 exactly one custom Paste item after two adopts, got %d" % custom)
	menu.id_pressed.emit(LineEdit.MENU_COPY)
	runner.check(reads.is_empty(), "PS6 another item does not read the clipboard")
	menu.id_pressed.emit(PasteShim.MENU_PASTE_ID)
	runner.check(reads.size() == 1 and edit.text == "QRS234", "PS6 the custom item reads once and fills the field, got %d '%s'" % [reads.size(), edit.text])
	edit.free()
	return true
