extends RefCounted

static func step(unit: Dictionary, kind_def: Dictionary, tick: int) -> float:
	var cap: float = kind_def.speed
	if kind_def.locomotor == "air":
		_snap_heading(unit)
		return cap / 30.0
	var desired := _desired(unit)
	var factor: float = 1.0
	if desired != Vector2.ZERO and (desired.x != unit.heading[0] or desired.y != unit.heading[1]):
		var heading := Vector2(unit.heading[0], unit.heading[1])
		factor = heading_factor(kind_def.locomotor, angle_between(heading, desired), kind_def)
		var turned := turn(heading, desired, kind_def.turn_cos, kind_def.turn_sin)
		unit.heading = [turned.x, turned.y]
	if tick < unit.move_after: return 0.0
	var remaining: float = _route_length_until(unit, 2.0 * kind_def.brake, cap * cap, cap / 30.0)
	var stoppable: float = sqrt(2.0 * kind_def.brake * remaining)
	unit.speed = minf(minf(unit.speed + kind_def.accel / 30.0, cap * factor), stoppable)
	return minf(unit.speed / 30.0, remaining)

static func angle_between(a: Vector2, b: Vector2) -> float:
	var dot: float = a.x * b.x + a.y * b.y
	var x: float = absf(dot)
	var y: float = absf(a.x * b.y - a.y * b.x)
	var high: float = maxf(x, y)
	if high == 0.0: return 0.0
	var z: float = minf(x, y) / high
	var z2: float = z * z
	var t: float = z * (0.99997726 + z2 * (-0.33262347 + z2 * (0.19354346 + z2 * (-0.11643287 + z2 * (0.05265332 - 0.01172120 * z2)))))
	if y > x: t = 1.5707963267948966 - t
	if dot < 0.0: t = 3.141592653589793 - t
	return t * 57.295779513082323

static func turn(heading: Vector2, desired: Vector2, cos_step: float, sin_step: float) -> Vector2:
	if heading.x * desired.x + heading.y * desired.y >= cos_step: return desired
	var sign: float = -1.0 if heading.x * desired.y - heading.y * desired.x < 0.0 else 1.0
	var turned := Vector2(heading.x * cos_step - sign * heading.y * sin_step, sign * heading.x * sin_step + heading.y * cos_step)
	return turned / sqrt(turned.x * turned.x + turned.y * turned.y)

static func heading_factor(locomotor: String, angle: float, kind_def: Dictionary) -> float:
	if locomotor == "wheels":
		if angle <= 9.0: return 1.0
		var speed: float = kind_def.speed
		return maxf(kind_def.min_turn_speed, speed / 4.0) / speed
	return maxf(0.0, 1.0 - angle / 45.0)

static func _desired(unit: Dictionary) -> Vector2:
	if unit.route.is_empty(): return Vector2.ZERO
	var dx: float = unit.route[0][0] - unit.position[0]
	var dy: float = unit.route[0][1] - unit.position[1]
	var length: float = sqrt(dx * dx + dy * dy)
	if length < 1e-9: return Vector2.ZERO
	return Vector2(dx / length, dy / length)

static func _snap_heading(unit: Dictionary) -> void:
	var desired := _desired(unit)
	if desired != Vector2.ZERO: unit.heading = [desired.x, desired.y]

static func braking_distance(speed: float, brake: float) -> float:
	return speed * speed / (2.0 * brake)

# Stops once the braking cap can no longer bind, so the caller's min() is unchanged.
static func _route_length_until(unit: Dictionary, two_brake: float, cap_squared: float, step_cap: float) -> float:
	var x: float = unit.position[0]
	var y: float = unit.position[1]
	var total: float = 0.0
	for waypoint in unit.route:
		var dx: float = waypoint[0] - x
		var dy: float = waypoint[1] - y
		total += sqrt(dx * dx + dy * dy)
		if two_brake * total >= cap_squared and total >= step_cap: return total
		x = waypoint[0]
		y = waypoint[1]
	return total

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
