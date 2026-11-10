extends Node2D

const Iso = preload("res://scripts/presentation/isometric.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const CLIFF_HEIGHT: float = 8.0

var draws: int = 0
var ground_builds: int = 0
var _map: Dictionary = {}
var _colors: Dictionary = Palette.ground(0)
var _ground: Dictionary = {}

func set_palette(colors: Dictionary) -> void:
	_colors = colors
	queue_redraw()

func set_map(map: Dictionary) -> void:
	# The navigation snapshot is rebuilt only when blocked cells change, so identity is the change test.
	if is_same(map, _map): return
	_map = map
	queue_redraw()

func _draw() -> void:
	if _map.is_empty(): return
	var zone: int = Profiler.begin()
	draws += 1
	var size := Vector2(_map.size[0], _map.size[1])
	_draw_ground(size)
	_draw_blocked(_map.blocked_cells)
	Profiler.end(&"draw.terrain", zone)

# Built once per map size and ground colour: a placement redraws the cliffs but not these 70k triangles.
func _draw_ground(size: Vector2) -> void:
	if _ground.get("key") != [size, _colors.ground]: _ground = _build_ground(size)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _ground.indices, _ground.points, _ground.colors)

# Every cell a few percent lighter or darker by a hash of its position.
func _build_ground(size: Vector2) -> Dictionary:
	ground_builds += 1
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for y in int(size.y):
		for x in int(size.x):
			var shade: float = float(((x * 73856093) ^ (y * 19349663)) & 15) / 15.0 - 0.5
			var color: Color = _colors.ground.lightened(shade * 0.08) if shade > 0.0 else _colors.ground.darkened(-shade * 0.08)
			_add_quad(points, colors, indices, _corners(Vector2(x, y), Vector2.ONE), color)
	return {"key": [size, _colors.ground], "points": points, "colors": colors, "indices": indices}

# Back to front, so a cell in front covers the side faces of the one behind it.
func _draw_blocked(cells: Array) -> void:
	if cells.is_empty(): return
	var sorted: Array = cells.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] + a[1] < b[0] + b[1])
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var lift := Vector2(0, -CLIFF_HEIGHT)
	for cell: Array in sorted:
		var c: PackedVector2Array = _corners(Vector2(cell[0], cell[1]), Vector2.ONE)
		_add_quad(points, colors, indices, PackedVector2Array([c[3], c[2], c[2] + lift, c[3] + lift]), _colors.cliff_side.lightened(0.08))
		_add_quad(points, colors, indices, PackedVector2Array([c[2], c[1], c[1] + lift, c[2] + lift]), _colors.cliff_side)
		_add_quad(points, colors, indices, PackedVector2Array([c[0] + lift, c[1] + lift, c[2] + lift, c[3] + lift]), _colors.cliff_top)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors)

func _add_quad(points: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array, quad: PackedVector2Array, color: Color) -> void:
	var base: int = points.size()
	points.append_array(quad)
	for i in 4: colors.append(color)
	indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

func _corners(origin: Vector2, size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([Iso.world_to_plane(origin), Iso.world_to_plane(origin + Vector2(size.x, 0)),
		Iso.world_to_plane(origin + size), Iso.world_to_plane(origin + Vector2(0, size.y))])
