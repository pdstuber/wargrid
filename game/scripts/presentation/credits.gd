extends RefCounted

const WARGRID_LINE: String = "Wargrid © 2026 Philipp Stuber. Free software under the GNU GPL v3 or later, with no warranty. License and source: github.com/pdstuber/wargrid"
const MACLEOD_HEADING: String = "Attribution text requested by Kevin MacLeod"

static func text(credits_md: String, notice_md: String, license_text: String) -> String:
	var parts: PackedStringArray = [WARGRID_LINE, "Music\n" + _music(credits_md), _voice(credits_md), "Maps\n" + notice_md, "Godot Engine\n" + license_text]
	return "\n\n".join(parts)

static func _rows(credits_md: String, prefix: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	for line in credits_md.split("\n"):
		if not line.begins_with("| `" + prefix): continue
		var cells := line.split("|")
		for i in cells.size(): cells[i] = cells[i].strip_edges()
		rows.append(cells)
	return rows

static func _music(credits_md: String) -> String:
	var lines: PackedStringArray = []
	for c in _rows(credits_md, "music/"):
		var line: String = '"%s" by %s (%s), licensed %s (%s)' % [c[2], c[4], c[3], c[5], c[6]]
		if c[7] != "-": line += "; " + c[7]
		lines.append(line + "; changes: " + c[8].replace("`", ""))
	return "\n".join(lines) + "\n\n" + _macleod(credits_md)

static func _macleod(credits_md: String) -> String:
	var start: int = credits_md.find("```text\n")
	if start < 0: return ""
	start += 8
	return MACLEOD_HEADING + ":\n" + credits_md.substr(start, credits_md.find("```", start) - start).strip_edges()

static func _voice(credits_md: String) -> String:
	var rows := _rows(credits_md, "voice/")
	var url: String = rows[0][3] if not rows.is_empty() else ""
	return "Voice: Piper en_US-kristin-medium (public-domain LibriVox recordings), %s; announcer lines vocoded by Wargrid" % url
