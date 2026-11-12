extends RefCounted

const NO_CELL := Vector2i(-1, -1)

var legs: Array[Dictionary] = []

var _keep_trace: bool
var _open: Dictionary = {}
var _previous: Dictionary = {}

func _init(keep_trace: bool = false) -> void:
	_keep_trace = keep_trace

static func _is_collector(row: Dictionary) -> bool:
	return row.kind == "frc_builder" and row.collection != null

static func _position(row: Dictionary) -> Vector2:
	return Vector2(row.position[0], row.position[1])

static func _cell(position: Vector2) -> Vector2i:
	return Vector2i(position.floor())

static func _dock_cell(row: Dictionary) -> Variant:
	var dock: Variant = row.collection.get("dock")
	return null if dock == null else Vector2i(int(dock[0]), int(dock[1]))

static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func _segments(from: Vector2, route: Array) -> Array[Vector2]:
	var segments: Array[Vector2] = []
	var at: Vector2 = from
	for waypoint: Array in route:
		var next := Vector2(waypoint[0], waypoint[1])
		if next != at: segments.append(next - at)
		at = next
	return segments

static func route_length(from: Vector2, route: Array) -> float:
	var length: float = 0.0
	for segment: Vector2 in _segments(from, route): length += segment.length()
	return length

static func corners(from: Vector2, route: Array) -> int:
	var segments: Array[Vector2] = _segments(from, route)
	var count: int = 0
	for index: int in range(1, segments.size()):
		if segments[index - 1].normalized().dot(segments[index].normalized()) < 0.999: count += 1
	return count

static func tick_line(tick: int, id: int, entities: Array) -> String:
	var self_text: String = ""
	var others: Array[String] = []
	for row: Dictionary in entities:
		if not _is_collector(row): continue
		var position: Vector2 = _position(row)
		var cell: Vector2i = _cell(position)
		if row.id == id:
			var dock: Variant = _dock_cell(row)
			self_text = "T %d %d %s %s cell=%d,%d pos=%.2f,%.2f dock=%s" % [tick, id, row.collection.phase, row.status, cell.x, cell.y, position.x, position.y, "-" if dock == null else "%d,%d" % [dock.x, dock.y]]
		else:
			others.append("%d:%s:%d,%d" % [row.id, row.collection.phase, cell.x, cell.y])
	return "%s | %s" % [self_text, " ".join(others)]

func observe(tick: int, entities: Array) -> void:
	var collectors: Array = entities.filter(_is_collector)
	for row: Dictionary in collectors: _observe_unit(tick, row, entities)

func _observe_unit(tick: int, row: Dictionary, entities: Array) -> void:
	var id: int = row.id
	var phase: String = row.collection.phase
	var position: Vector2 = _position(row)
	if _previous.has(id):
		var before: Dictionary = _previous[id]
		if phase == "loading" and before.phase != "loading": _close(id, "empty")
		if phase == "unloading" and before.phase != "unloading": _close(id, "loaded")
		if before.phase == "unloading" and phase != "unloading": _open[id] = _new_leg("empty", id, tick, position)
		if before.phase == "loading" and phase != "loading": _open[id] = _new_leg("loaded", id, tick, position)
		if _open.has(id): _count(_open[id], tick, row, before, entities)
	_previous[id] = {"phase": phase, "status": row.status, "position": position}

func _new_leg(kind: String, id: int, tick: int, position: Vector2) -> Dictionary:
	return {"kind": kind, "id": id, "start_tick": tick, "end_tick": tick, "start_cell": _cell(position), "end_cell": NO_CELL, "target_id": -1, "route": -1.0, "corners": 0, "moved_len": 0.0, "flying": 0, "moved_ticks": 0, "routes": 0, "held": "", "trace": []}

func _close(id: int, kind: String) -> void:
	if _open.has(id) and _open[id].kind == kind: legs.append(_open[id])
	_open.erase(id)

func _count(leg: Dictionary, tick: int, row: Dictionary, before: Dictionary, entities: Array) -> void:
	var position: Vector2 = _position(row)
	leg.end_tick = tick
	if row.collection.phase.begins_with("flying_"): leg.flying += 1
	if position != before.position:
		leg.moved_ticks += 1
		leg.moved_len += position.distance_to(before.position)
	var dock: Variant = _dock_cell(row)
	if dock != null and leg.end_cell == NO_CELL: _claim(leg, row, dock, entities)
	if row.status == "moving" and leg.route < 0.0:
		leg.route = route_length(position, row.route)
		leg.corners = corners(position, row.route)
	if row.status == "moving" and before.status == "path_pending" and tick > leg.start_tick: leg.routes += 1
	if _keep_trace: leg.trace.append(tick_line(tick, row.id, entities))

func _claim(leg: Dictionary, row: Dictionary, dock: Vector2i, entities: Array) -> void:
	leg.end_cell = dock
	leg.target_id = int(row.collection.target_id)
	var held: Array[String] = []
	for other: Dictionary in entities:
		if not _is_collector(other) or other.id == row.id or other.collection.target_id != row.collection.target_id: continue
		var other_dock: Variant = _dock_cell(other)
		if other_dock != null: held.append("%d,%d:%s" % [other_dock.x, other_dock.y, other.collection.phase])
	held.sort()
	leg.held = ";".join(held)
