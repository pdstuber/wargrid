extends RefCounted

const Navigation = preload("res://scripts/simulation/grid_navigation.gd")

func cases() -> Array[Callable]:
	return [test_boundaries, test_open_path, test_obstacle, test_disconnected, test_copy]

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
	var state: Dictionary = nav.snapshot()
	if not state.blocked_cells.is_empty():
		state.blocked_cells[0][0] = 9
	state.blocked_cells.clear()
	state.size[0] = 9
	runner.check(nav.snapshot() == expected and not nav.is_walkable(Vector2(2.5, 2.5)), "N5 snapshot isolation")
	var path: Array[Vector2] = nav.route(Vector2(1.5, 1.5), Vector2(4.5, 4.5))
	for i in range(10):
		runner.check(nav.route(Vector2(1.5, 1.5), Vector2(4.5, 4.5)) == path, "N5 repeat route")
	return true
