@warning_ignore_start("untyped_declaration")
extends RefCounted

const Credits = preload("res://scripts/presentation/credits.gd")
const CREDITS_PATH: String = "res://audio/CREDITS.md"
const NOTICE_PATH: String = "res://data/maps/NOTICE.md"
const LICENSE: String = "GODOT-LICENSE-MARKER " + "line two"

func cases() -> Array[Callable]:
	return [test_every_music_row, test_new_row_appears, test_macleod_block, test_voice_line, test_maps_notice, test_godot_license, test_wargrid_line]

func _credits() -> String:
	return FileAccess.get_file_as_string(CREDITS_PATH)

func _notice() -> String:
	return FileAccess.get_file_as_string(NOTICE_PATH)

func _panel(credits_md: String) -> String:
	return Credits.text(credits_md, _notice(), LICENSE)

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
		for column in [2, 3, 4, 5, 6]:
			runner.check(row[column].strip_edges() in panel, "CR1 every CREDITS.md music row is in the panel: %s" % row[column].strip_edges())
	return true

func test_new_row_appears(runner) -> bool:
	var row := "| `music/x.ogg` | Xtitle | https://x.test | Xauthor | CC-BY-4.0 | https://l.test | - | none |\n"
	var panel := _panel(_credits() + row)
	for part in ["Xtitle", "https://x.test", "Xauthor", "https://l.test"]:
		runner.check(part in panel, "CR2 a new music row appears: %s" % part)
	return true

func test_macleod_block(runner) -> bool:
	var text := _credits()
	var start := text.find("```text\n") + 8
	var block := text.substr(start, text.find("```", start) - start)
	runner.check(block.length() > 50 and block in _panel(text), "CR3 the MacLeod attribution block is verbatim")
	return true

func test_voice_line(runner) -> bool:
	var panel := _panel(_credits())
	runner.check("Piper en_US-kristin-medium (public-domain LibriVox recordings)" in panel and "huggingface.co/rhasspy/piper-voices" in panel, "CR4 voice line")
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
