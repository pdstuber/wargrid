extends RefCounted

const FONT_SIZE: int = 12

static func hud_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	return theme
