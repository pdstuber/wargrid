@warning_ignore_start("untyped_declaration")
extends RefCounted

const LauncherSettings = preload("res://scripts/launcher_settings.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const Launcher = preload("res://scenes/launcher.tscn")
const LauncherScript = preload("res://scripts/launcher.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const SELECTED := Color(0.18, 0.43, 0.33)
const FIELD := Color(0.165, 0.165, 0.165)
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2576, 1145)]
# canvas_items + expand lays a window out at 720 logical px high; 2576x1145 becomes roundi(720 * 2576 / 1145) wide
const STRETCHED: Array[Array] = [[Vector2i(1280, 720), Vector2i(1280, 720)], [Vector2i(1920, 1080), Vector2i(1280, 720)], [Vector2i(2576, 1145), Vector2i(1620, 720)]]

func cases() -> Array[Callable]:
	return [test_picks_defaults, test_picks_fallback_per_field, test_picks_keep_other_sections, test_fullscreen_round_trip, test_sidebar_switches_pages, test_version_in_sidebar, test_aspect_expand_and_restore, test_layout_every_page, test_opens_on_bot_with_picks, test_toggle_friend, test_map_info_and_summary, test_own_faction_shared, test_start_saves_picks, test_advanced_only_prerelease]

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
		nav.pressed.emit()
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
