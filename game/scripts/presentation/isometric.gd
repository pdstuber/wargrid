extends RefCounted

static func world_to_plane(point: Vector2) -> Vector2:
	return Vector2(32 * (point.x - point.y), 16 * (point.x + point.y))

static func plane_to_world(point: Vector2) -> Vector2:
	return Vector2(point.x / 64 + point.y / 32, point.y / 32 - point.x / 64)
