@warning_ignore_start("untyped_declaration")
extends RefCounted

const Credits = preload("res://scripts/presentation/credits.gd")
const CREDITS_PATH: String = "res://audio/CREDITS.md"
const NOTICE_PATH: String = "res://data/maps/NOTICE.md"
const LICENSE: String = "GODOT-LICENSE-MARKER " + "line two"
const COMPONENTS: Array = [
	{"name": "Foo Lib", "parts": [{"files": ["a.c"], "copyright": ["2020, Foo", "2021, Bar"], "license": "Expat"}, {"files": ["b.c"], "copyright": ["2020, Foo"], "license": "Zlib"}]},
	{"name": "Baz Lib", "parts": [{"files": ["c.c"], "copyright": ["2019, Baz"], "license": "Expat"}]},
]
const LICENSES: Dictionary = {"Expat": "EXPAT-LICENCE-TEXT", "Zlib": "ZLIB-LICENCE-TEXT"}

func cases() -> Array[Callable]:
	return [test_every_music_row, test_new_row_appears, test_macleod_block, test_voice_line, test_unit_voice_rows, test_maps_notice, test_godot_license, test_wargrid_line, test_third_party_components, test_third_party_engine_data, test_macleod_ignores_earlier_fence, test_crlf_credits, test_public_sans_notice, test_exports_ship_the_font_licence]

func _credits() -> String:
	return FileAccess.get_file_as_string(CREDITS_PATH).replace("\r\n", "\n")

func _notice() -> String:
	return FileAccess.get_file_as_string(NOTICE_PATH)

func _panel(credits_md: String) -> String:
	return Credits.text(credits_md, _notice(), LICENSE, COMPONENTS, LICENSES)

func _music_rows(credits_md: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	for line in credits_md.split("\n"):
		if line.begins_with("| `music/"): rows.append(line.split("|"))
	return rows

func test_every_music_row(runner) -> bool:
	var panel := _panel(_credits())
	var rows := _music_rows(_credits())
	runner.check(rows.size() >= 5, "CR1 CREDITS.md has music rows, got %d" % rows.size())
	for row in rows:
		var c: Array = Array(row).map(func(cell: String) -> String: return cell.strip_edges())
		var expected: String = '"%s" by %s (%s), licensed %s (%s)' % [c[2], c[4], c[3], c[5], c[6]]
		if c[7] != "-": expected += "; " + c[7]
		expected += "; changes: " + c[8].replace("`", "")
		runner.check(expected in panel, "CR1 the panel has this music line: %s" % expected)
	return true

func test_new_row_appears(runner) -> bool:
	var row := "| `music/x.ogg` | Xtitle | https://x.test | Xauthor | CC-BY-4.0 | https://l.test | - | none |\n"
	var panel := _panel(_credits() + row)
	for part in ["Xtitle", "https://x.test", "Xauthor", "https://l.test"]:
		runner.check(part in panel, "CR2 a new music row appears: %s" % part)
	return true

func test_macleod_block(runner) -> bool:
	var text := _credits()
	var block := _block(text)
	runner.check(block.length() > 50 and block in _panel(text), "CR3 the MacLeod attribution block is verbatim")
	return true

func _block(text: String) -> String:
	var start := text.find("```text\n", text.find(Credits.MACLEOD_HEADING)) + 8
	return text.substr(start, text.find("```", start) - start).strip_edges()

func test_voice_line(runner) -> bool:
	var panel := _panel(_credits())
	runner.check("Piper en_US-kristin-medium (public-domain LibriVox recordings)" in panel and "huggingface.co/rhasspy/piper-voices" in panel, "CR4 voice line")
	runner.check("unit order lines: Piper en_US-bryce-medium (public domain), https://huggingface.co/rhasspy/piper-voices/blob/e7229f7d33a10e145e109b886d661984201ac3c4/en/en_US/bryce/medium/MODEL_CARD" in panel, "CR4 unit voice line")
	return true

func test_unit_voice_rows(runner) -> bool:
	var text := _credits()
	var lines := {"infantry": ["move", "attack"], "vehicle": ["move", "attack"], "worker": ["move", "work"]}
	for role: String in lines:
		for line: String in lines[role]:
			for n in [1, 2]:
				var file := "voice/units/%s_%s_%d.wav" % [role, line, n]
				var row := ""
				for l in text.split("\n"):
					if l.begins_with("| `%s` |" % file): row = l
				runner.check(row != "", "CR-U a credits row for %s" % file)
				runner.check("huggingface.co/rhasspy/piper-voices/blob/e7229f7d33a10e145e109b886d661984201ac3c4/en/en_US/bryce/medium/MODEL_CARD" in row, "CR-U %s names the pinned bryce model card" % file)
	return true

func test_maps_notice(runner) -> bool:
	var panel := _panel(_credits())
	runner.check("Copyright 2025 Electronic Arts Inc." in panel and "ADDITIONAL TERMS per GNU GPL Section 7" in panel, "CR5 EA's notice")
	return true

func test_godot_license(runner) -> bool:
	runner.check(LICENSE in _panel(_credits()), "CR6 Godot's licence text")
	runner.check(Engine.get_license_text().length() > 100, "CR6 the engine ships a licence text")
	return true

func test_wargrid_line(runner) -> bool:
	var panel := _panel(_credits())
	runner.check("Wargrid © 2026 Philipp Stuber. Free software under the GNU GPL v3 or later, with no warranty." in panel and "github.com/pdstuber/wargrid" in panel, "CR7 Wargrid GPL line")
	return true

func test_third_party_components(runner) -> bool:
	var panel := _panel(_credits())
	var godot := panel.find("\n\nGodot Engine\n")
	var third := panel.find("\n\nThird-party components in Godot\n")
	runner.check(godot >= 0 and third > godot + LICENSE.length(), "CR8 the third-party section follows the Godot licence")
	var section := panel.substr(third)
	for part in ["Foo Lib", "2020, Foo", "2021, Bar", "Baz Lib", "2019, Baz", "Expat", "Zlib"]:
		runner.check(part in section, "CR8 the third-party section names %s" % part)
	runner.check("Foo Lib\n2020, Foo\n2021, Bar\nLicense: Expat, Zlib\n\nBaz Lib\n2019, Baz\nLicense: Expat" in section, "CR8 each component block is name, copyright lines, then its licence names")
	runner.check(section.count("2020, Foo") == 1, "CR8 a copyright line shared by two parts is listed once")
	runner.check(section.count("EXPAT-LICENCE-TEXT") == 1 and section.count("ZLIB-LICENCE-TEXT") == 1, "CR8 each licence text appears once")
	runner.check(section.find("Foo Lib") < section.find("EXPAT-LICENCE-TEXT") and section.find("Baz Lib") < section.find("EXPAT-LICENCE-TEXT"), "CR8 components come before the licence texts")
	return true

func test_third_party_engine_data(runner) -> bool:
	var components: Array = Engine.get_copyright_info()
	var licenses: Dictionary = Engine.get_license_info()
	var panel := Credits.text(_credits(), _notice(), LICENSE, components, licenses)
	runner.check(components.size() > 50 and licenses.size() > 5, "CR9 the engine ships third-party notices, got %d and %d" % [components.size(), licenses.size()])
	for component: Dictionary in components:
		runner.check(component.name in panel, "CR9 component named: %s" % component.name)
	for license_name: String in licenses:
		runner.check(licenses[license_name] in panel, "CR9 licence text present: %s" % license_name)
	return true

func test_macleod_ignores_earlier_fence(runner) -> bool:
	var text := _credits().replace(Credits.MACLEOD_HEADING, "```text\nEARLIER-FENCE\n```\n\n" + Credits.MACLEOD_HEADING)
	var panel := _panel(text)
	runner.check(_block(text) in panel and "EARLIER-FENCE" not in panel, "CR10 the block comes from under the MacLeod heading")
	return true

func test_crlf_credits(runner) -> bool:
	var text := _credits()
	var panel := _panel(text.replace("\n", "\r\n"))
	runner.check(_block(text) in panel, "CR11 the MacLeod block survives CRLF input")
	runner.check(panel == _panel(text), "CR11 CRLF input gives the same panel")
	return true

func test_public_sans_notice(runner) -> bool:
	var licence: String = FileAccess.get_file_as_string("res://fonts/PublicSans-OFL.txt")
	runner.check("SIL OPEN FONT LICENSE Version 1.1" in licence and "The Public Sans Project Authors" in licence, "CR12 fixture: the shipped file is Public Sans' OFL text")
	var panel := Credits.text(_credits(), _notice(), LICENSE, COMPONENTS, LICENSES, licence)
	runner.check("Public Sans 2.001" in panel and "SIL Open Font License 1.1" in panel and "github.com/uswds/public-sans" in panel, "CR12 the panel names Public Sans 2.001 and its licence")
	runner.check(licence in panel, "CR12 the panel carries the OFL text in full")
	runner.check(panel.find("Public Sans 2.001") > panel.find("\n\nMaps\n") and panel.find("Public Sans 2.001") < panel.find("\n\nGodot Engine\n"), "CR12 the font notice sits between Maps and Godot")
	return true

func test_exports_ship_the_font_licence(runner) -> bool:
	runner.check(FileAccess.file_exists("res://fonts/PublicSans-OFL.txt"), "CR13 the licence is in the project or pack")
	if not FileAccess.file_exists("res://export_presets.cfg"): return true # exported packs omit the presets; the project run checks them
	var config := ConfigFile.new()
	runner.check(config.load("res://export_presets.cfg") == OK, "CR13 export presets load")
	for section: String in config.get_sections():
		if section.ends_with(".options"): continue
		runner.check("fonts/PublicSans-OFL.txt" in str(config.get_value(section, "include_filter", "")), "CR13 %s ships the Public Sans licence" % config.get_value(section, "name", section))
	return true
