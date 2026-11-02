extends RefCounted

const Allocation = preload("res://scripts/simulation/destination_allocation.gd")
const Navigation = preload("res://scripts/simulation/grid_navigation.gd")
const PATH_REQUESTS_PER_TICK: int = 8
const DISTANCE_PER_TICK: float = 3.0 / 30.0
var _navigation: RefCounted

var _tick: int = 0
var _next_entity_id: int = 1
var _entities: Dictionary = {}
var _pending: Array[Dictionary] = []
var _path_queue: Array[int] = []
var _last_sequences: Dictionary = {}

func _init(blocked_cells: Array[Vector2i] = [], size: Vector2i = Navigation.SIZE) -> void:
	_navigation = Navigation.new(blocked_cells, size)

func spawn(owner: int, position: Vector2) -> int:
	if owner <= 0 or not _navigation.is_walkable(position):
		return -1
	var cell := Vector2i(position.floor())
	for unit in _entities.values():
		if _cell(unit.position) == cell or (unit.destination != null and _cell(unit.destination) == cell):
			return -1
	var id: int = _next_entity_id
	_entities[id] = {"id": id, "owner": owner, "position": [position.x, position.y], "order": null, "status": "idle", "route": [], "destination": null}
	_next_entity_id += 1
	return id

func issue_command(command: Dictionary) -> Dictionary:
	var error: String = _validate(command)
	if not error.is_empty():
		return {"ok": false, "error": error}
	_pending.append({
		"tick": command.tick, "player": command.player, "sequence": command.sequence,
		"type": "move", "entity_ids": command.entity_ids.duplicate(),
		"target": [float(command.target[0]), float(command.target[1])],
	})
	_last_sequences[command.player] = command.sequence
	return {"ok": true, "error": ""}

func _validate(command: Dictionary) -> String:
	for key in ["tick", "player", "sequence", "type", "entity_ids", "target"]:
		if not command.has(key):
			return "Missing field: " + key
	for key in ["tick", "player", "sequence"]:
		if typeof(command[key]) != TYPE_INT:
			return key + " must be an integer"
	if command.tick < _tick or command.player <= 0 or command.sequence < 0:
		return "Invalid tick, player or sequence"
	if command.sequence <= _last_sequences.get(command.player, -1):
		return "Sequence must increase"
	if typeof(command.type) != TYPE_STRING or command.type != "move":
		return "Unsupported command type"
	if not command.entity_ids is Array or command.entity_ids.is_empty():
		return "Expected nonempty entity array"
	var seen: Dictionary = {}
	for id in command.entity_ids:
		if typeof(id) != TYPE_INT or id <= 0 or seen.has(id):
			return "Invalid or duplicate entity ID"
		seen[id] = true
	if not _owns_all(command.player, command.entity_ids):
		return "Missing entity or wrong owner"
	if not command.target is Array or command.target.size() != 2:
		return "Expected two target coordinates"
	for coordinate in command.target:
		if typeof(coordinate) != TYPE_INT and typeof(coordinate) != TYPE_FLOAT:
			return "Target coordinates must be numbers"
		if not is_finite(float(coordinate)):
			return "Target coordinates must be finite"
	if not _navigation.is_walkable(Vector2(command.target[0], command.target[1])):
		return "Target must be walkable and within map"
	return ""

func _owns_all(player: int, ids: Array) -> bool:
	for id in ids:
		if not _entities.has(id) or _entities[id].owner != player:
			return false
	return true

func _command_before(a: Dictionary, b: Dictionary) -> bool:
	for key in ["tick", "player", "sequence"]:
		if a[key] != b[key]:
			return a[key] < b[key]
	return false

func _cell(point: Array) -> Vector2i:
	return Vector2i(Vector2(point[0], point[1]).floor())

func _unavailable_cells(members: Array[Dictionary]) -> Array[Vector2i]:
	var ids: Dictionary = {}
	for unit in members:
		ids[unit.id] = true
	var unavailable: Dictionary = {}
	for unit in _entities.values():
		if not ids.has(unit.id):
			unavailable[_cell(unit.position)] = true
		if unit.destination != null:
			unavailable[_cell(unit.destination)] = true
	var cells: Array[Vector2i] = []
	cells.assign(unavailable.keys())
	return cells

func _apply_orders() -> void:
	_pending.sort_custom(_command_before)
	var future: Array[Dictionary] = []
	var due: Array[Dictionary] = []
	var final: Dictionary = {}
	for command in _pending:
		if command.tick != _tick:
			future.append(command)
		elif _owns_all(command.player, command.entity_ids):
			due.append(command)
			for id in command.entity_ids:
				final[id] = command
	_pending = future
	for id in final:
		_entities[id].destination = null
		_path_queue.erase(id)
	for command in due:
		var members: Array[Dictionary] = []
		var ids: Array = command.entity_ids.duplicate()
		ids.sort()
		for id in ids:
			if final.get(id) == command:
				members.append(_entities[id])
		if members.is_empty():
			continue
		var target := Vector2(command.target[0], command.target[1])
		var goals: Dictionary = Allocation.assign(_navigation, members, target, _unavailable_cells(members))
		for unit in members:
			unit.route = []
			if goals[unit.id] == null:
				unit.order = null
				unit.status = "blocked"
			else:
				var goal: Vector2 = goals[unit.id]
				unit.order = {"type": "move", "target": command.target.duplicate()}
				unit.destination = [goal.x, goal.y]
				unit.status = "path_pending"
				_path_queue.append(unit.id)

func _service_paths() -> void:
	for i in range(mini(PATH_REQUESTS_PER_TICK, _path_queue.size())):
		var id: int = _path_queue.pop_front()
		_assign_route(_entities[id])

func step() -> void:
	_apply_orders()
	_service_paths()
	var ids: Array = _entities.keys()
	ids.sort()
	for id in ids:
		if _entities[id].status == "moving":
			_advance(_entities[id])
	_tick += 1

func _assign_route(unit: Dictionary) -> void:
	var from := Vector2(unit.position[0], unit.position[1])
	var to := Vector2(unit.destination[0], unit.destination[1])
	unit.route = []
	for point in _navigation.route(from, to):
		unit.route.append([point.x, point.y])
	unit.status = "blocked" if unit.route.is_empty() else "moving"
	if unit.status == "blocked":
		unit.order = null
		unit.destination = null

func _advance(unit: Dictionary) -> void:
	var remaining: float = DISTANCE_PER_TICK
	var x: float = unit.position[0]
	var y: float = unit.position[1]
	while not unit.route.is_empty():
		var waypoint: Array = unit.route[0]
		var dx: float = waypoint[0] - x
		var dy: float = waypoint[1] - y
		var distance: float = sqrt(dx * dx + dy * dy)
		if distance <= remaining + 1e-5:
			x = waypoint[0]
			y = waypoint[1]
			remaining = maxf(0.0, remaining - distance)
			unit.route.pop_front()
		else:
			x += dx / distance * remaining
			y += dy / distance * remaining
			break
	unit.position = [x, y]
	if unit.route.is_empty():
		unit.order = null
		unit.status = "arrived"

func snapshot() -> Dictionary:
	var entities: Array = []
	var ids: Array = _entities.keys()
	ids.sort()
	for id in ids:
		entities.append(_entities[id].duplicate(true))
	var pending: Array = _pending.duplicate(true)
	pending.sort_custom(_command_before)
	var sequences: Array = []
	var players: Array = _last_sequences.keys()
	players.sort()
	for player in players:
		sequences.append({"player": player, "sequence": _last_sequences[player]})
	return {"tick": _tick, "next_entity_id": _next_entity_id, "entities": entities,
		"pending_commands": pending, "last_sequences": sequences, "map": _navigation.snapshot(), "path_queue": _path_queue.duplicate()}

func replace_blocked_cells(cells: Array[Vector2i]) -> Dictionary:
	var map: Dictionary = _navigation.snapshot()
	var bounds := Rect2i(0, 0, map.size[0], map.size[1])
	var occupied: Dictionary = {}
	for unit in _entities.values():
		occupied[_cell(unit.position)] = true
	for cell in cells:
		if not bounds.has_point(cell):
			return {"ok": false, "error": "Obstacle outside map"}
		if occupied.has(cell):
			return {"ok": false, "error": "Obstacle would cover a unit"}
	_navigation.replace_blocked_cells(cells)
	if _navigation.snapshot() == map:
		return {"ok": true, "error": ""}
	_path_queue.clear()
	var ids: Array = _entities.keys()
	ids.sort()
	for id in ids:
		var unit: Dictionary = _entities[id]
		if unit.status != "moving" and unit.status != "path_pending":
			continue
		unit.route = []
		var destination := Vector2(unit.destination[0], unit.destination[1])
		var position := Vector2(unit.position[0], unit.position[1])
		if not _navigation.is_walkable(destination) or _navigation.component_at(position) != _navigation.component_at(destination):
			unit.order = null
			unit.destination = null
			unit.status = "blocked"
		else:
			unit.status = "path_pending"
			_path_queue.append(id)
	return {"ok": true, "error": ""}
