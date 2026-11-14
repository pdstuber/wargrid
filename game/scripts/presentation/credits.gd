extends RefCounted

const WARGRID_LINE: String = "Wargrid © 2026 Philipp Stuber. Free software under the GNU GPL v3 or later, with no warranty. License and source: github.com/pdstuber/wargrid"
const PUBLIC_SANS_LINE: String = "Public Sans 2.001, github.com/uswds/public-sans, SIL Open Font License 1.1."
const MACLEOD_HEADING: String = "Attribution text requested by Kevin MacLeod"

static func text(credits_md: String, notice_md: String, license_text: String, components: Array, licenses: Dictionary, font_license: String = "") -> String:
	var md: String = credits_md.replace("\r\n", "\n")
	var parts: PackedStringArray = [WARGRID_LINE, "Music\n" + _music(md), _voice(md), "Maps\n" + notice_md, "Fonts\n" + PUBLIC_SANS_LINE + "\n\n" + font_license, "Godot Engine\n" + license_text, _third_party(components, licenses)]
	return "\n\n".join(parts)

static func _third_party(components: Array, licenses: Dictionary) -> String:
	var blocks: PackedStringArray = ["Third-party components in Godot"]
	for component: Dictionary in components:
		var copyrights: PackedStringArray = []
		var names: PackedStringArray = []
		for part: Dictionary in component.parts:
			for line: String in part.copyright:
				if line not in copyrights: copyrights.append(line)
			if part.license not in names: names.append(part.license)
		blocks.append("%s\n%s\nLicense: %s" % [component.name, "\n".join(copyrights), ", ".join(names)])
	for license_name: String in licenses:
		blocks.append("%s\n%s" % [license_name, licenses[license_name]])
	return "\n\n".join(blocks)

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
	var heading: int = credits_md.find(MACLEOD_HEADING)
	var start: int = credits_md.find("```text\n", heading)
	if heading < 0 or start < 0: return ""
	start += 8
	return MACLEOD_HEADING + ":\n" + credits_md.substr(start, credits_md.find("```", start) - start).strip_edges()

static func _voice(credits_md: String) -> String:
	var rows := _rows(credits_md, "voice/")
	var url: String = rows[0][3] if not rows.is_empty() else ""
	var unit_rows := _rows(credits_md, "voice/units/")
	var unit_url: String = unit_rows[0][3] if not unit_rows.is_empty() else ""
	return "Voice: Piper en_US-kristin-medium (public-domain LibriVox recordings), %s; announcer lines vocoded by Wargrid; unit order lines: Piper en_US-bryce-medium (public domain), %s" % [url, unit_url]
