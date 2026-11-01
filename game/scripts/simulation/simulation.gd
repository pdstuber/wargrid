extends RefCounted

var _tick: int = 0
var _next_entity_id: int = 1
var _entities: Dictionary = {}
var _pending: Array[Dictionary] = []
var _last_sequences: Dictionary = {}

func spawn(owner: int, position: Vector2) -> int:
	if owner <= 0 or not position.is_finite():
		return -1
	var id: int = _next_entity_id
	_entities[id] = {"id": id, "owner": owner, "position": [position.x, position.y], "order": null}
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

func step() -> void:
	_pending.sort_custom(_command_before)
	var future: Array[Dictionary] = []
	for command in _pending:
		if command.tick != _tick:
			future.append(command)
		elif _owns_all(command.player, command.entity_ids):
			for id in command.entity_ids:
				_entities[id].order = {"type": "move", "target": command.target.duplicate()}
	_pending = future
	_tick += 1

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
		"pending_commands": pending, "last_sequences": sequences}
