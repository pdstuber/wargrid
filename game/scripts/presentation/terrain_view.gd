extends Node2D

const Iso = preload("res://scripts/presentation/isometric.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const GROUND := Color("c4a568")
const BLOCKED := Color("665744")
const GRID := Color("a88b55")

var draws: int = 0
var _map: Dictionary = {}

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
	draw_colored_polygon(_corners(Vector2.ZERO, size), GROUND)
	_draw_blocked(_map.blocked_cells)
	_draw_grid(size)
	Profiler.end(&"draw.terrain", zone)

func _draw_blocked(cells: Array) -> void:
	if cells.is_empty(): return
	var points := PackedVector2Array()
	var indices := PackedInt32Array()
	for cell: Variant in cells:
		var base: int = points.size()
		points.append_array(_corners(Vector2(cell[0], cell[1]), Vector2.ONE))
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var colors := PackedColorArray()
	colors.resize(points.size())
	colors.fill(BLOCKED)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors)

func _draw_grid(size: Vector2) -> void:
	var lines := PackedVector2Array()
	for x in range(int(size.x) + 1):
		lines.append(Iso.world_to_plane(Vector2(x, 0)))
		lines.append(Iso.world_to_plane(Vector2(x, size.y)))
	for y in range(int(size.y) + 1):
		lines.append(Iso.world_to_plane(Vector2(0, y)))
		lines.append(Iso.world_to_plane(Vector2(size.x, y)))
	draw_multiline(lines, GRID, 1.0)

func _corners(origin: Vector2, size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([Iso.world_to_plane(origin), Iso.world_to_plane(origin + Vector2(size.x, 0)),
		Iso.world_to_plane(origin + size), Iso.world_to_plane(origin + Vector2(0, size.y))])
