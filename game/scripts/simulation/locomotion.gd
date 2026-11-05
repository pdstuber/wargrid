extends RefCounted

static func step(unit: Dictionary, kind_def: Dictionary, tick: int) -> float:
	var cap: float = kind_def.speed
	if not kind_def.has("accel"): return cap / 30.0
	if tick < unit.move_after: return 0.0
	var remaining: float = route_length(unit)
	var stoppable: float = sqrt(2.0 * kind_def.brake * remaining)
	unit.speed = minf(minf(unit.speed + kind_def.accel / 30.0, cap), stoppable)
	return minf(unit.speed / 30.0, remaining)

static func braking_distance(speed: float, brake: float) -> float:
	return speed * speed / (2.0 * brake)

static func route_length(unit: Dictionary) -> float:
	var x: float = unit.position[0]
	var y: float = unit.position[1]
	var total: float = 0.0
	for waypoint in unit.route:
		var dx: float = waypoint[0] - x
		var dy: float = waypoint[1] - y
		total += sqrt(dx * dx + dy * dy)
		x = waypoint[0]
		y = waypoint[1]
	return total
