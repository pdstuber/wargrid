extends RefCounted

const Iso = preload("res://scripts/presentation/isometric.gd")

func cases() -> Array[Callable]:
	return [test_projection]

func test_projection(runner) -> bool:
	var points: Array[Vector2] = [Vector2(1, 0), Vector2(0, 1), Vector2(2.5, 1.5)]
	var planes: Array[Vector2] = [Vector2(32, 16), Vector2(-32, 16), Vector2(32, 64)]
	for i in range(points.size()):
		runner.check(Iso.world_to_plane(points[i]) == planes[i], "P1 axes %d" % i)
	points.append_array([Vector2.ZERO, Vector2(-0.25, 2), Vector2(15.999, 0.125)])
	for point in points:
		runner.check(Iso.plane_to_world(Iso.world_to_plane(point)).distance_to(point) <= 1e-5, "P1 roundtrip " + str(point))
	return true
