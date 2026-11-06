@warning_ignore_start("untyped_declaration")
extends RefCounted

const Navigation = preload("res://scripts/simulation/grid_navigation.gd")

func cases() -> Array[Callable]:
	return [test_boundaries, test_open_path, test_obstacle, test_disconnected, test_copy, test_sized_map, test_components, test_replacement]

func test_boundaries(runner) -> bool:
	var nav = Navigation.new([Vector2i(2, 2)])
	for point in [Vector2.ZERO, Vector2(15.999, 15.999)]:
		runner.check(nav.is_walkable(point), "N1 valid " + str(point))
	for point in [Vector2(-0.01, 0), Vector2(16, 0), Vector2(0, 16), Vector2(NAN, 0), Vector2(0, INF), Vector2(2.5, 2.5)]:
		runner.check(not nav.is_walkable(point), "N1 invalid " + str(point))
		runner.check(nav.route(point, Vector2(1.5, 1.5)).is_empty(), "N1 invalid start")
		runner.check(nav.route(Vector2(1.5, 1.5), point).is_empty(), "N1 invalid end")
	return true

func test_open_path(runner) -> bool:
	var nav = Navigation.new()
	runner.check(nav.route(Vector2(1.5, 1.5), Vector2(3.5, 1.5)) == [Vector2(2.5, 1.5), Vector2(3.5, 1.5)], "N2 open path")
	runner.check(nav.route(Vector2(1.5, 1.5), Vector2(1.75, 1.5)) == [Vector2(1.75, 1.5)], "N2 same cell exact target")
	runner.check(nav.route(Vector2(1.2, 1.3), Vector2(3.2, 1.1)) == [Vector2(1.5, 1.5), Vector2(2.5, 1.5), Vector2(3.5, 1.5), Vector2(3.2, 1.1)], "N2 start center and exact endpoint")
	return true

func test_obstacle(runner) -> bool:
	var nav = Navigation.new([Vector2i(2, 1)])
	var target := Vector2(3.5, 1.5)
	var path: Array[Vector2] = nav.route(Vector2(1.5, 1.5), target)
	runner.check(not path.is_empty(), "N3 obstacle reachable")
	var previous := Vector2(1.5, 1.5)
	var distance := 0.0
	for point in path:
		runner.check(nav.is_walkable(point), "N3 walkable waypoint")
		var diff: Vector2 = point - previous
		runner.check(absf(diff.x) + absf(diff.y) == 1.0, "N3 orthogonal neighbors")
		distance += diff.length()
		previous = point
	runner.check(previous == target, "N3 exact target")
	runner.check(distance == 4.0, "N3 distance four")
	return true

func test_disconnected(runner) -> bool:
	var wall: Array[Vector2i] = []
	for y in range(16):
		wall.append(Vector2i(3, y))
	var nav = Navigation.new(wall)
	runner.check(nav.route(Vector2(1.5, 1.5), Vector2(5.5, 1.5)).is_empty(), "N4 disconnected")
	nav = Navigation.new([Vector2i(1, 0), Vector2i(0, 1)])
	runner.check(nav.route(Vector2(0.5, 0.5), Vector2(1.5, 1.5)).is_empty(), "N4 no diagonal escape")
	return true

func test_copy(runner) -> bool:
	var solids: Array[Vector2i] = [Vector2i(2, 2), Vector2i(4, 0), Vector2i(0, 2), Vector2i(2, 2)]
	var nav = Navigation.new(solids)
	solids.clear()
	var expected := {"size": [16, 16], "blocked_cells": [[4, 0], [0, 2], [2, 2]]}
	runner.check(nav.snapshot() == expected, "N5 copy deduplicate sort")
	var state: Dictionary = nav.snapshot().duplicate(true)
	if not state.blocked_cells.is_empty():
		state.blocked_cells[0][0] = 9
	state.blocked_cells.clear()
	state.size[0] = 9
	runner.check(nav.snapshot() == expected and not nav.is_walkable(Vector2(2.5, 2.5)), "N5 snapshot isolation")
	var path: Array[Vector2] = nav.route(Vector2(1.5, 1.5), Vector2(4.5, 4.5))
	for i in range(10):
		runner.check(nav.route(Vector2(1.5, 1.5), Vector2(4.5, 4.5)) == path, "N5 repeat route")
	return true

func test_sized_map(runner) -> bool:
	var nav = Navigation.new([], Vector2i(64, 64))
	runner.check(nav.snapshot().size == [64, 64], "N6 sized snapshot")
	runner.check(nav.is_walkable(Vector2(63.999, 63.999)), "N6 last cell")
	for point in [Vector2(64, 0), Vector2(0, 64), Vector2(-0.01, 0)]:
		runner.check(not nav.is_walkable(point), "N6 boundary")
	runner.check(not nav.route(Vector2(62.5, 63.5), Vector2(63.5, 63.5)).is_empty(), "N6 route beyond default map")
	return true

func test_components(runner) -> bool:
	var wall: Array[Vector2i] = []
	for y in range(16):
		wall.append(Vector2i(3, y))
	var nav = Navigation.new(wall)
	var left: int = nav.component_at(Vector2(1.5, 1.5))
	var right: int = nav.component_at(Vector2(5.5, 1.5))
	runner.check(left >= 0 and right >= 0 and left != right, "N7 separate components")
	runner.check(nav.component_at(Vector2(3.5, 1.5)) == -1 and nav.component_at(Vector2(-0.1, 0)) == -1, "N7 invalid component")
	var cells: Array[Vector2i] = nav.cells_in_component(left)
	runner.check(cells.size() == 48, "N7 full left component")
	var previous := Vector2i(-1, -1)
	for cell in cells:
		runner.check(cell.y > previous.y or (cell.y == previous.y and cell.x > previous.x), "N7 row-major cells")
		runner.check(cell.x < 3 and nav.component_at(Vector2(cell) + Vector2(0.5, 0.5)) == left, "N7 member label")
		previous = cell
	if not cells.is_empty():
		cells[0] = Vector2i(99, 99)
	runner.check(nav.cells_in_component(left).size() == 48 and not nav.cells_in_component(left).has(Vector2i(99, 99)), "N7 cell array isolated")
	runner.check(nav.cells_in_component(-1).is_empty(), "N7 invalid component list")
	wall.erase(Vector2i(3, 7))
	nav.replace_blocked_cells(wall)
	runner.check(nav.component_at(Vector2(1.5, 1.5)) == nav.component_at(Vector2(5.5, 1.5)), "N7 gap joins components")
	runner.check(nav.cells_in_component(nav.component_at(Vector2.ZERO)).size() == 241, "N7 joined cell count")
	return true

func test_replacement(runner) -> bool:
	var nav = Navigation.new([Vector2i(2, 1)])
	var from := Vector2(1.5, 1.5)
	var to := Vector2(3.5, 1.5)
	nav.replace_blocked_cells([])
	runner.check(nav.route(from, to) == [Vector2(2.5, 1.5), to], "N8 obstacle removal updates route")
	var solids: Array[Vector2i] = [Vector2i(4, 0), Vector2i(2, 1), Vector2i(4, 0)]
	nav.replace_blocked_cells(solids)
	solids.clear()
	runner.check(nav.snapshot().blocked_cells == [[4, 0], [2, 1]], "N8 install copied canonical cells")
	runner.check(not nav.is_walkable(Vector2(2.5, 1.5)), "N8 new solid applied")
	var before: Dictionary = nav.snapshot()
	var path: Array[Vector2] = nav.route(from, to)
	var component: int = nav.component_at(from)
	nav.replace_blocked_cells([Vector2i(2, 1), Vector2i(4, 0), Vector2i(2, 1)])
	runner.check(nav.snapshot() == before and nav.route(from, to) == path and nav.component_at(from) == component, "N8 normalized no-op")
	return true
