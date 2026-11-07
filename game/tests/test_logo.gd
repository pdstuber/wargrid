@warning_ignore_start("untyped_declaration")
extends RefCounted

func cases() -> Array[Callable]:
	return [test_icon_is_master_times_16, test_branding_settings]

func test_branding_settings(runner) -> bool:
	runner.check(ProjectSettings.get_setting("application/config/icon") == "res://icon.png", "LG2 project icon")
	runner.check(ProjectSettings.get_setting("application/boot_splash/image") == "res://icon.png", "LG2 splash image")
	runner.check(ProjectSettings.get_setting("application/boot_splash/use_filter") == false, "LG2 splash keeps pixels sharp")
	runner.check(ProjectSettings.get_setting("application/boot_splash/stretch_mode") == 0, "LG2 splash shown at its own 512 px, not stretched")
	runner.check(ProjectSettings.get_setting("application/boot_splash/bg_color") == Color("4d4d4d"), "LG2 splash on the card colour")
	if not FileAccess.file_exists("res://export_presets.cfg"): return true # exported packs omit the presets; the project run checks them
	var config := ConfigFile.new()
	runner.check(config.load("res://export_presets.cfg") == OK, "LG2 export presets load")
	var options: Dictionary = {}
	for section in config.get_sections():
		if not section.ends_with(".options"): options[config.get_value(section, "name")] = section + ".options"
	for preset in ["macOS", "Windows Desktop"]:
		runner.check(config.get_value(options[preset], "application/icon_interpolation", -1) == 0, "LG2 %s scales the icon nearest-neighbour" % preset)
	runner.check(config.get_value(options["Windows Desktop"], "application/modify_resources", false) == true, "LG2 Windows exe carries the icon")
	var head: String = config.get_value(options["Web"], "html/head_include", "")
	runner.check("og:image" in head and "https://wargrid.pdstuber.dev/og.png" in head, "LG2 web page has the preview image tag")
	return true

func test_icon_is_master_times_16(runner) -> bool:
	var master: Image = load("res://art/logo-32.png").get_image()
	var icon: Image = load("res://icon.png").get_image()
	runner.check(master.get_size() == Vector2i(32, 32) and icon.get_size() == Vector2i(512, 512), "LG1 sizes 32 and 512")
	var same: bool = true
	for y in 512:
		for x in 512:
			var got: Color = icon.get_pixel(x, y)
			var want: Color = master.get_pixel(floori(x / 16.0), floori(y / 16.0))
			# Import's fix_alpha_border recolours invisible pixels differently per size.
			same = same and (got == want or (got.a == 0.0 and want.a == 0.0))
	runner.check(same, "LG1 icon is the master scaled x16 nearest-neighbour")
	return true
