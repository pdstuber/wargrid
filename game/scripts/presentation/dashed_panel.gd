extends PanelContainer

const DASH := 4.0
const COLOR := Color(0.5, 0.5, 0.5, 1)

static func edges(rect: Rect2) -> PackedVector2Array:
	var end: Vector2 = rect.end
	return PackedVector2Array([rect.position, Vector2(end.x, rect.position.y), Vector2(end.x, rect.position.y), end, end, Vector2(rect.position.x, end.y), Vector2(rect.position.x, end.y), rect.position])

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var style: StyleBox = get_theme_stylebox("panel")
	if style is StyleBoxFlat: rect = rect.grow_individual(style.expand_margin_left, style.expand_margin_top, style.expand_margin_right, style.expand_margin_bottom)
	var points: PackedVector2Array = edges(rect.grow(-0.5))
	for i in range(0, points.size(), 2): draw_dashed_line(points[i], points[i + 1], COLOR, 1.0, DASH)
