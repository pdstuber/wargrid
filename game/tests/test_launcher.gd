@warning_ignore_start("untyped_declaration")
extends RefCounted

const LauncherSettings = preload("res://scripts/launcher_settings.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const Launcher = preload("res://scenes/launcher.tscn")
const LauncherScript = preload("res://scripts/launcher.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const OnlineTests = preload("res://tests/test_online_scene.gd")
const LOOPBACK := "wss://127.0.0.1:9/ws"
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")
const SELECTED := Color(0.18, 0.43, 0.33)
const FIELD := Color(0.165, 0.165, 0.165)
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2576, 1145)]
# canvas_items + expand lays a window out at 720 logical px high; 2576x1145 becomes roundi(720 * 2576 / 1145) wide
const STRETCHED: Array[Array] = [[Vector2i(1280, 720), Vector2i(1280, 720)], [Vector2i(1920, 1080), Vector2i(1280, 720)], [Vector2i(2576, 1145), Vector2i(1620, 720)]]

func cases() -> Array[Callable]:
	return [test_picks_defaults, test_picks_fallback_per_field, test_picks_keep_other_sections, test_fullscreen_round_trip, test_fullscreen_switch, test_this_build_line, test_sidebar_switches_pages, test_version_in_sidebar, test_aspect_expand_and_restore, test_layout_every_page, test_opens_on_bot_with_picks, test_toggle_friend, test_map_info_and_summary, test_own_faction_shared, test_start_saves_picks, test_advanced_only_prerelease, test_link_opens_join, test_lock_while_connecting, test_waiting_view, test_back_to_menu, test_join_error_footer, test_relay_fields_follow]

func scratch_for(name: String) -> String:
	var scratch := "user://test-launcher-%s-%d.cfg" % [name, OS.get_process_id()]
	DirAccess.remove_absolute(scratch)
	return scratch

func test_picks_defaults(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("defaults")
	var picks: Dictionary = LauncherSettings.load_picks()
	AudioSettings.path = saved
	runner.check(picks == {"faction": "usa", "bot_faction": "usa", "map": "dry_wells"}, "L1 defaults without a file, got %s" % [picks])
	return true

func test_picks_fallback_per_field(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("fallback")
	var config := ConfigFile.new()
	config.set_value("launcher", "faction", "frc")
	config.set_value("launcher", "bot_faction", "gla")
	config.set_value("launcher", "map", 3)
	config.save(AudioSettings.path)
	var picks: Dictionary = LauncherSettings.load_picks()
	AudioSettings.path = saved
	runner.check(picks == {"faction": "frc", "bot_faction": "usa", "map": "dry_wells"}, "L2 bad fields fall back one by one, got %s" % [picks])
	return true

func test_picks_keep_other_sections(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("sections")
	var config := ConfigFile.new()
	config.set_value("audio", "music", 0.5)
	config.set_value("playtest", "enabled", false)
	config.save(AudioSettings.path)
	LauncherSettings.save_picks({"faction": "china"})
	var after := ConfigFile.new()
	after.load(AudioSettings.path)
	AudioSettings.path = saved
	runner.check(after.get_value("audio", "music", null) == 0.5, "L3 audio survives")
	runner.check(after.get_value("playtest", "enabled", null) == false, "L3 playtest survives")
	runner.check(after.get_value("launcher", "faction", null) == "china", "L3 faction saved")
	runner.check(not after.has_section_key("launcher", "bot_faction") and not after.has_section_key("launcher", "map"), "L3 absent keys stay absent")
	return true

func test_fullscreen_round_trip(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("fullscreen")
	var before: bool = LauncherSettings.fullscreen()
	LauncherSettings.save_fullscreen(true)
	var after: bool = LauncherSettings.fullscreen()
	AudioSettings.path = saved
	runner.check(before == false, "L4 fullscreen defaults off")
	runner.check(after == true, "L4 fullscreen round trip")
	return true

func _visible_pages(launcher: Node) -> Array[String]:
	var shown: Array[String] = []
	for page_name: String in LauncherScript.PAGES:
		var page: Control = launcher.get_node_or_null("Pages/" + page_name)
		if page != null and page.visible: shown.append(page_name)
	return shown

func test_sidebar_switches_pages(runner) -> bool:
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	runner.check(launcher.current_page == "Play" and _visible_pages(launcher) == ["Play"], "L5 opens on Play only, got %s" % [_visible_pages(launcher)])
	for page_name: String in ["Join", "Settings", "Credits"]:
		var nav: Button = launcher.get_node_or_null("Sidebar/Nav/" + page_name)
		runner.check(nav != null, "L5 nav button %s exists" % page_name)
		if nav == null: continue
		nav.button_pressed = true
		runner.check(launcher.current_page == page_name and _visible_pages(launcher) == [page_name] and nav.button_pressed, "L5 %s shows only its page, got %s" % [page_name, _visible_pages(launcher)])
	launcher.show_page("Waiting")
	runner.check(_visible_pages(launcher) == ["Waiting"] and launcher.get_node("Sidebar/Nav/Play").button_pressed, "L5 Waiting shows alone and presses Play")
	launcher.free()
	return true

func test_version_in_sidebar(runner) -> bool:
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var version: Label = launcher.get_node_or_null("Sidebar/Version")
	runner.check(version != null and str(ProjectSettings.get_setting("application/config/version")) in version.text, "L6 the sidebar shows the version")
	launcher.free()
	return true

func test_aspect_expand_and_restore(runner) -> bool:
	var root: Window = runner.root.get_tree().root
	runner.check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "L7 fixture: aspect starts on keep")
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	runner.check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "L7 the launcher sets expand")
	launcher.free()
	runner.check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "L7 leaving the tree restores keep")
	return true

func _visible_controls(node: Node, found: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control and child.visible:
			found.append(child)
			_visible_controls(child, found)

func _overlap_free(runner, node: Control, label: String) -> void:
	var rows: Array[Control] = []
	for child in node.get_children():
		if child is Control and child.visible: rows.append(child)
	for i in rows.size():
		for j in range(i + 1, rows.size()):
			runner.check(not rows[i].get_global_rect().intersects(rows[j].get_global_rect()), "L8 %s: %s and %s do not overlap" % [label, rows[i].name, rows[j].name])

func test_layout_every_page(runner) -> bool:
	var saved: String = AudioSettings.path
	var scratch := "user://test-launcher-layout-%d.cfg" % OS.get_process_id()
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	var layouts: Array[Array] = []
	for size in SIZES: layouts.append([size, size])
	layouts.append_array(STRETCHED)
	for pair in layouts:
		var size: Vector2i = pair[1]
		var port := SubViewport.new()
		port.size = pair[0]
		port.size_2d_override = size
		port.size_2d_override_stretch = true
		runner.root.add_child(port)
		runner.check(port.get_visible_rect().size == Vector2(size), "L8 fixture: the viewport lays out at %s, got %s" % [size, port.get_visible_rect().size])
		var launcher = Launcher.instantiate()
		launcher.prerelease = true
		port.add_child(launcher)
		var advanced: Button = launcher.get_node_or_null("Pages/Play/Body/Advanced/Toggle")
		if advanced != null: advanced.button_pressed = true
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var content: Control = launcher.get_node_or_null("Pages")
		var sidebar: Control = launcher.get_node_or_null("Sidebar")
		runner.check(content != null and sidebar != null, "L8 sidebar and pages exist at %s" % size)
		if content == null or sidebar == null:
			launcher.free()
			port.free()
			continue
		var visits: Array[String] = LauncherScript.PAGES.duplicate()
		visits.append("Play")
		for visit in visits.size():
			var page_name: String = visits[visit]
			launcher.set_opponent("friend" if visit == LauncherScript.PAGES.size() else "bot")
			launcher.show_page(page_name)
			await runner.process_frame
			await runner.process_frame
			var label := "%s at %s (window %s)" % [page_name, size, pair[0]]
			runner.check(sidebar.get_global_rect().position.y == 0.0 and absf(sidebar.get_global_rect().size.y - size.y) <= 1.0, "L8 sidebar spans the full height, %s" % label)
			runner.check(absf(content.get_global_rect().end.x - size.x) <= 1.0 and absf(content.get_global_rect().end.y - size.y) <= 1.0, "L8 content reaches the right and bottom edge, %s, got %s" % [label, content.get_global_rect()])
			runner.check(view.encloses(content.get_global_rect()) and not content.get_global_rect().intersects(sidebar.get_global_rect()), "L8 sidebar and content sit side by side inside the viewport, %s" % label)
			var controls: Array[Control] = []
			_visible_controls(launcher.get_node("Pages/" + page_name), controls)
			var inside: bool = true
			for control in controls:
				inside = inside and content.get_global_rect().grow(0.5).encloses(control.get_global_rect())
				if control.get_child_count() > 0: _overlap_free(runner, control, label)
			runner.check(controls.size() > 3 and inside, "L8 every visible control lies inside the content area, %s" % label)
			_overlap_free(runner, launcher.get_node("Pages/" + page_name), label)
		launcher.free()
		port.free()
	AudioSettings.path = saved
	DirAccess.remove_absolute(scratch)
	return true

func _launcher_with(runner, name: String, picks: Dictionary, prerelease: bool = false):
	AudioSettings.path = scratch_for(name)
	LauncherSettings.save_picks(picks)
	var launcher = Launcher.instantiate()
	launcher.prerelease = prerelease
	runner.root.add_child(launcher)
	await runner.process_frame
	return launcher

func test_opens_on_bot_with_picks(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "opens", {"faction": "china", "bot_faction": "frc", "map": "ashfall"})
	AudioSettings.path = saved
	var play: Control = launcher.get_node("Pages/Play")
	runner.check(launcher._faction(play.get_node("Body/Own")) == "china" and launcher._faction(play.get_node("Body/Bot")) == "frc" and launcher._map_id() == "ashfall", "L9a Play shows the remembered picks")
	runner.check(launcher.opponent == "bot" and play.get_node("Footer/Start").visible and not play.get_node("Footer/Create").visible, "L9a opens on the bot with Start only")
	launcher.free()
	return true

func test_toggle_friend(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "toggle", {})
	AudioSettings.path = saved
	var play: Control = launcher.get_node("Pages/Play")
	var bot_toggle: Button = play.get_node("Body/Opponent/BotToggle")
	var friend_toggle: Button = play.get_node("Body/Opponent/FriendToggle")
	launcher.set_opponent("friend")
	runner.check(launcher.opponent == "friend" and not play.get_node("Body/Bot").visible and not play.get_node("Body/BotLabel").visible, "L9b friend hides the bot selector")
	runner.check(play.get_node("Body/OpenSlot").visible and play.get_node("Footer/Create").visible and not play.get_node("Footer/Start").visible, "L9b friend shows the open slot and Create")
	runner.check(play.get_node("Body/OpenSlot/Row/Hint").text == "Your friend picks their own faction.", "L9b open slot copy")
	runner.check(play.get_node("Footer/Status").text == "You get a link to send to your friend.", "L9b footer hint, got '%s'" % play.get_node("Footer/Status").text)
	runner.check(friend_toggle.button_pressed and not bot_toggle.button_pressed, "L9b the Friend toggle is pressed")
	runner.check(friend_toggle.get_theme_stylebox("pressed").bg_color == SELECTED and bot_toggle.get_theme_stylebox("normal").bg_color == FIELD, "L9b selected side green, other side field colour")
	bot_toggle.pressed.emit()
	runner.check(launcher.opponent == "bot" and play.get_node("Body/Bot").visible and not play.get_node("Body/OpenSlot").visible and play.get_node("Footer/Start").visible, "L9b the Bot toggle returns to the bot")
	launcher.free()
	return true

func test_map_info_and_summary(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "info", {"faction": "usa", "bot_faction": "frc", "map": "dry_wells"})
	AudioSettings.path = saved
	for id: String in MatchSettings.PLAY_MAPS:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MatchSettings.map_path(id)))
		runner.check(launcher._map_info(id) == "%d start positions · %d supply sources" % [data.starts.size(), data.sources.size()], "L9c map info for %s, got '%s'" % [id, launcher._map_info(id)])
	runner.check(launcher._summary() == "Dry Wells · United States vs Free Resistance Coalition bot", "L9c summary, got '%s'" % launcher._summary())
	runner.check(launcher.get_node("Pages/Play/Footer/Status").text == launcher._summary(), "L9c the footer shows the summary")
	runner.check(launcher.get_node("Pages/Play/Body/MapInfo").text == launcher._map_info("dry_wells"), "L9c the map info shows under the map")
	launcher.free()
	return true

func _index_where(selector: OptionButton, matches: Callable) -> int:
	for i in selector.item_count:
		if matches.call(selector.get_item_metadata(i)): return i
	return -1

func test_own_faction_shared(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "shared", {"faction": "usa"})
	AudioSettings.path = saved
	var play_own: OptionButton = launcher.get_node("Pages/Play/Body/Own")
	var join_own: OptionButton = launcher.get_node_or_null("Pages/Join/Body/Own")
	runner.check(join_own != null, "L9d Join has its own faction selector")
	if join_own == null:
		launcher.free()
		return true
	for id: String in ["china", "usa"]:
		var index: int = _index_where(join_own, func(item: String) -> bool: return item == id)
		join_own.select(index)
		join_own.item_selected.emit(index)
		runner.check(launcher._faction(play_own) == id, "L9d Join's pick %s reaches Play" % id)
		var back: int = _index_where(play_own, func(item: String) -> bool: return item != id)
		play_own.select(back)
		play_own.item_selected.emit(back)
		runner.check(launcher._faction(join_own) == launcher._faction(play_own) and launcher._faction(join_own) != id, "L9d Play's pick reaches Join")
	launcher.free()
	return true

func test_start_saves_picks(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "saves", {"faction": "usa", "bot_faction": "usa", "map": "dry_wells"})
	launcher._set_own("china")
	launcher._select_id(launcher.get_node("Pages/Play/Body/Bot"), "frc")
	launcher._select_id(launcher.get_node("Pages/Play/Body/Map"), "ashfall")
	launcher._offline_setup()
	var stored: Dictionary = LauncherSettings.load_picks()
	AudioSettings.path = saved
	runner.check(stored == {"faction": "china", "bot_faction": "frc", "map": "ashfall"}, "L9e a bot start saves all three, got %s" % [stored])
	launcher.free()
	return true

func test_advanced_only_prerelease(runner) -> bool:
	var saved: String = AudioSettings.path
	for prerelease in [false, true]:
		var launcher = await _launcher_with(runner, "advanced", {}, prerelease)
		launcher.set_opponent("friend")
		for page_name: String in ["Play", "Join"]:
			var fold: Control = launcher.get_node("Pages/%s/Body/Advanced" % page_name)
			runner.check(fold.visible == prerelease, "L9f %s fold visible == prerelease (%s)" % [page_name, prerelease])
			runner.check(fold.get_node("Toggle").text == "Advanced settings" and fold.get_node("Toggle/Tag").text == "TEST BUILDS ONLY", "L9f %s fold label and tag" % page_name)
		launcher.set_opponent("bot")
		runner.check(not launcher.get_node("Pages/Play/Body/Advanced").visible, "L9f Play bot hides the fold")
		launcher.free()
	AudioSettings.path = saved
	return true


func _texts(node: Node) -> Array[String]:
	var found: Array[String] = []
	for label: Node in node.find_children("*", "Label", true, false): found.append(label.text)
	return found

func _nav_disabled(launcher) -> Array[bool]:
	var states: Array[bool] = []
	for page_name: String in LauncherScript.NAV_PAGES: states.append(launcher.get_node("Sidebar/Nav/" + page_name).disabled)
	return states

func _host(launcher) -> Object:
	launcher._set_relay(LOOPBACK)
	launcher.set_opponent("friend")
	launcher.get_node("Pages/Play/Footer/Create").pressed.emit()
	launcher.set_process(false)
	var transport := OnlineTests.FakeTransport.new()
	launcher._transport = transport
	return transport

func test_link_opens_join(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("link")
	LauncherScript.code_applied = false
	var first = Launcher.instantiate()
	first.search = "?code=ABC234"
	runner.root.add_child(first)
	await runner.process_frame
	runner.check(first.current_page == "Join" and first.get_node("Pages/Join/Body/Code").text == "ABC234" and first._transport == null, "L10a a join link opens Join with the code and no connection, got %s" % first.current_page)
	var again = Launcher.instantiate()
	again.search = "?code=ABC234"
	runner.root.add_child(again)
	await runner.process_frame
	runner.check(again.current_page == "Play", "L10b a stale link does not reopen Join, got %s" % again.current_page)
	first.free()
	again.free()
	AudioSettings.path = saved
	return true

func test_lock_while_connecting(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "lock", {})
	AudioSettings.path = saved
	var reason := "Connection to relay lost"
	_host(launcher)
	runner.check(launcher._relay_url() == LOOPBACK, "L11 fixture: the relay is a loopback literal, so no DNS lookup starts")
	runner.check(_nav_disabled(launcher) == [true, true, true, true], "L11 Create locks every nav button, got %s" % [_nav_disabled(launcher)])
	launcher._fail(reason)
	var play_status: Label = launcher.get_node("Pages/Play/Footer/Status")
	runner.check(_nav_disabled(launcher) == [false, false, false, false] and launcher.current_page == "Play" and play_status.text == reason and launcher.opponent == "friend", "L11 a failure before welcome unlocks the nav and shows the reason in Play's footer")
	var join_own: OptionButton = launcher.get_node("Pages/Join/Body/Own")
	var index: int = _index_where(join_own, func(item: String) -> bool: return item != launcher._faction(join_own))
	join_own.select(index)
	join_own.item_selected.emit(index)
	runner.check(play_status.text == reason, "M3 changing Own from Join keeps the error in Play's footer, got '%s'" % play_status.text)
	launcher.set_opponent("bot")
	runner.check(play_status.text == launcher._summary(), "M3 the next action on Play replaces the error")
	launcher.free()
	return true

func test_waiting_view(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "waiting", {"faction": "china", "map": "ashfall"})
	AudioSettings.path = saved
	var transport = _host(launcher)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	var waiting: Control = launcher.get_node("Pages/Waiting")
	var own: String = Registry.faction("china").display_name
	runner.check(launcher.current_page == "Waiting" and _nav_disabled(launcher) == [true, true, true, true], "L12a welcome shows Waiting with the nav locked")
	runner.check(waiting.get_node("Body/Link").text == launcher._copy_text() and "Or tell them the code: ABC234" in _texts(waiting), "L12a link and code line")
	var one: Array[String] = _texts(waiting.get_node("Body/One"))
	runner.check("You" in one and own in one and "READY" in one, "L12a row 1 is You, %s, READY, got %s" % [own, one])
	var two: Array[String] = _texts(waiting.get_node("Body/Two"))
	runner.check("Open" in two and "waiting for your friend…" in two, "L12a row 2 is Open, got %s" % [two])
	var map_texts: Array[String] = _texts(waiting.get_node("Body/Map"))
	runner.check(MatchSettings.PLAY_MAPS["ashfall"] in map_texts and launcher._map_info("ashfall") in map_texts, "L12a map name and info, got %s" % [map_texts])
	runner.check(waiting.get_node("Footer/Status").text == "Match code ABC234", "L12a footer shows the match code")
	await runner.process_frame
	await runner.process_frame
	var controls: Array[Control] = []
	_visible_controls(waiting, controls)
	var inside: bool = true
	for control in controls: inside = inside and launcher.get_node("Pages").get_global_rect().grow(0.5).encloses(control.get_global_rect())
	runner.check(controls.size() > 10 and inside, "L12a every Waiting control lies inside the content area")
	_overlap_free(runner, waiting.get_node("Body"), "Waiting")
	waiting.get_node("Footer/Cancel").pressed.emit()
	runner.check(transport.close_calls == 1 and launcher.current_page == "Play" and _nav_disabled(launcher) == [false, false, false, false], "L12b Cancel closes and returns to Play unlocked")
	runner.check(launcher.get_node("Pages/Play/Footer/Status").text == "Match cancelled" and launcher.opponent == "friend", "L12b Play says Match cancelled and stays on Friend")
	_host(launcher)
	launcher._handle('{"type":"welcome","seat":1,"match":"ABC234"}')
	launcher._handle('{"type":"error","reason":"match is full"}')
	runner.check(launcher.current_page == "Play" and launcher.get_node("Pages/Play/Footer/Status").text == "match is full" and launcher.opponent == "friend", "L12c a relay error on Waiting returns to Play with the reason")
	launcher.free()
	return true

func test_back_to_menu(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("back")
	LauncherSettings.save_picks({"faction": "china", "bot_faction": "frc", "map": "ashfall"})
	LauncherScript.code_applied = false
	var first = Launcher.instantiate()
	first.search = "?code=ABC234"
	runner.root.add_child(first)
	await runner.process_frame
	first.free()
	var back = Launcher.instantiate()
	back.search = "?code=ABC234"
	runner.root.add_child(back)
	await runner.process_frame
	AudioSettings.path = saved
	runner.check(back.current_page == "Play" and back._faction(back.get_node("Pages/Play/Body/Own")) == "china" and back._map_id() == "ashfall", "L13 back to menu shows Play with the remembered picks")
	runner.check(runner.root.get_tree().root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "L13 back to menu sets expand again")
	back.free()
	return true

func test_join_error_footer(runner) -> bool:
	var saved: String = AudioSettings.path
	var launcher = await _launcher_with(runner, "join-error", {})
	AudioSettings.path = saved
	launcher.show_page("Join")
	launcher._set_relay(LOOPBACK)
	runner.check(launcher._relay_url() == LOOPBACK, "L14 fixture: the relay is a loopback literal, so no DNS lookup starts")
	launcher.get_node("Pages/Join/Footer/Join").pressed.emit()
	launcher.set_process(false)
	runner.check(_nav_disabled(launcher) == [true, true, true, true], "L14 Join locks the nav")
	launcher._transport = OnlineTests.FakeTransport.new()
	launcher._fail("Cannot connect to relay")
	runner.check(launcher.current_page == "Join" and launcher.get_node("Pages/Join/Footer/Status").text == "Cannot connect to relay" and _nav_disabled(launcher) == [false, false, false, false], "L14 the error shows in Join's footer, nav unlocked")
	launcher.free()
	return true

func test_relay_fields_follow(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("relay")
	LauncherScript.code_applied = false
	var launcher = Launcher.instantiate()
	launcher.prerelease = true
	launcher.search = "?relay=wss%3A%2F%2Fx.example%2Fws"
	runner.root.add_child(launcher)
	await runner.process_frame
	AudioSettings.path = saved
	var play: LineEdit = launcher.get_node("Pages/Play/Body/Advanced/RelayUrl")
	var join: LineEdit = launcher.get_node("Pages/Join/Body/Advanced/RelayUrl")
	runner.check(play.text == "wss://x.example/ws" and join.text == play.text and play.visible and join.visible, "M2 ?relay= fills and opens both folds")
	join.text = "wss://y.example/ws"
	join.text_changed.emit(join.text)
	runner.check(launcher._relay_url() == "wss://y.example/ws" and play.text == join.text, "M2 typing into Join's field reaches Play and _relay_url()")
	play.text = "wss://z.example/ws"
	play.text_changed.emit(play.text)
	runner.check(launcher._relay_url() == "wss://z.example/ws" and join.text == play.text, "M2 typing into Play's field reaches Join")
	launcher.free()
	return true

func test_fullscreen_switch(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("fullscreen-switch")
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var fullscreen: CheckButton = launcher.get_node_or_null("Pages/Settings/Body/Audio/Fullscreen")
	runner.check(fullscreen != null and not fullscreen.button_pressed, "L15a Fullscreen exists and is off by default")
	if fullscreen != null:
		fullscreen.button_pressed = true
		runner.check(LauncherSettings.fullscreen(), "L15a pressing Fullscreen saves true")
		fullscreen.button_pressed = false
		runner.check(not LauncherSettings.fullscreen(), "L15a releasing Fullscreen saves false")
	launcher.free()
	LauncherSettings.save_fullscreen(true)
	launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	runner.check(launcher.get_node("Pages/Settings/Body/Audio/Fullscreen").button_pressed, "L15a the stored value shows on the switch")
	launcher.free()
	AudioSettings.path = saved
	return true

func test_this_build_line(runner) -> bool:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch_for("this-build")
	var launcher = Launcher.instantiate()
	runner.root.add_child(launcher)
	await runner.process_frame
	var toggle: CheckButton = launcher.get_node("Pages/Settings/Body/Playtest/PlaytestSwitch")
	toggle.button_pressed = false
	var build: Button = launcher.get_node("Pages/Settings/Body/Playtest/ThisBuild")
	runner.check(not build.visible, "L15b ThisBuild is hidden while the switch is off")
	toggle.button_pressed = true
	var title: String = FocusCards.load_cards()[0].title
	runner.check(build.visible and build.text == "This build: " + title and title == "The new menu", "L15b ThisBuild names the first card when on, got %s" % build.text)
	toggle.button_pressed = false
	runner.check(not build.visible, "L15b ThisBuild hides again when switched off")
	launcher.free()
	AudioSettings.path = saved
	return true
