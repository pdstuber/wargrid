extends RefCounted

const Supply = preload("res://scripts/simulation/supply_collection.gd")
const Production = preload("res://scripts/simulation/production.gd")
const Construction = preload("res://scripts/simulation/construction.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Allocation = preload("res://scripts/simulation/destination_allocation.gd")
const Navigation = preload("res://scripts/simulation/grid_navigation.gd")
const PATH_REQUESTS_PER_TICK: int = 8
var _navigation: RefCounted

var _players: Dictionary = {}
var _buildings: Dictionary = {}
var _sources: Dictionary = {}
var _terrain_cells: Array[Vector2i] = []
var _command_results: Array[Dictionary] = []
var _next_production_id: int = 1
var _tick: int = 0
var _next_entity_id: int = 1
var _entities: Dictionary = {}
var _pending: Array[Dictionary] = []
var _path_queue: Array[int] = []
var _last_sequences: Dictionary = {}
var _combat_events: Array[Dictionary] = []
var _match: Variant = null
var _combat_work: int = 0
var _chases: Dictionary = {}
var _scan_chases: int = 0
var _retaliations: int = 0
var _allocation_calls: int = 0
var _navigation_builds: int = 0

func _init(blocked_cells: Array[Vector2i] = [], size: Vector2i = Navigation.SIZE) -> void:
	_navigation = Navigation.new(blocked_cells, size)
	for cell in _navigation.snapshot().blocked_cells:
		_terrain_cells.append(Vector2i(cell[0],cell[1]))

func add_player(player: int, credits: int, controller: String = "human") -> Dictionary:
	if controller != "human" and controller != "ai": return {"ok": false, "error": "Invalid controller"}
	if player <= 0 or credits < 0 or _players.has(player):
		return {"ok": false, "error": "Invalid or duplicate player"}
	_players[player] = {"id":player,"credits":credits,"controller":controller}
	return {"ok":true,"error":""}

func spawn(owner: int, position: Vector2, kind: String = "vehicle") -> int:
	if Definitions.unit(kind).is_empty() or owner <= 0 or not _in_bounds(position) or (kind != "collector" and not _navigation.is_walkable(position)):
		return -1
	var cell := Vector2i(position.floor())
	for unit in _entities.values():
		if kind == "collector" or unit.kind == "collector": continue
		if _cell(unit.position) == cell or (unit.destination != null and _cell(unit.destination) == cell):
			return -1
	var id: int = _next_entity_id
	_entities[id] = {"id": id, "owner": owner, "position": [position.x, position.y], "order": null, "status": "idle", "route": [], "destination": null, "kind":kind,"hp":CombatDefinitions.profile(kind).max_hp,"max_hp":CombatDefinitions.profile(kind).max_hp,"combat":CombatDefinitions.initial_combat(kind),"construction_id":null,"collection": {"enabled":false,"preferred_source_id":null,"target_id":null,"phase":"idle","remaining_ticks":0,"retry_tick":0,"cargo":0} if kind == "collector" else null}
	_next_entity_id += 1
	return id

func start_match(players: Array[int]) -> Dictionary:
	var ids: Array[int] = players.duplicate()
	ids.sort()
	if _match != null or ids.size() != 2 or ids[0] == ids[1] or ids[0] <= 0: return {"ok":false,"error":"Invalid match players"}
	for id in ids:
		if not _players.has(id) or not _survives(id): return {"ok":false,"error":"Player cannot start a match"}
	_match = {"players":ids,"status":"ongoing","winner":null,"ended_tick":null}
	return {"ok":true,"error":""}

func _survives(player: int) -> bool:
	for unit in _entities.values():
		if unit.owner == player and unit.kind == "builder": return true
	for building in _buildings.values():
		if building.owner == player and building.completed and building.kind in ["depot","barracks","factory"]: return true
	return false

func _evaluate_match() -> void:
	var alive: Array[int] = []
	for player in _match.players:
		if _survives(player): alive.append(player)
	if alive.size() == 2: return
	_match.status = "draw" if alive.is_empty() else "won"
	_match.winner = alive[0] if alive.size() == 1 else null
	_match.ended_tick = _tick

func match_over() -> bool:
	return _match != null and _match.status != "ongoing"

func issue_command(command: Dictionary) -> Dictionary:
	if match_over(): return {"ok":false,"error":"Match ended"}
	var error: String = _validate(command)
	if not error.is_empty():
		return {"ok":false,"error":error}
	var normalized := {"tick":command.tick,"player":command.player,"sequence":command.sequence,"type":command.type}
	for key in _payload_fields(command.type):
		normalized[key] = command[key].duplicate(true) if command[key] is Array else command[key]
	if normalized.has("target"):
		normalized.target = [float(command.target[0]),float(command.target[1])]
	_pending.append(normalized)
	_last_sequences[command.player] = command.sequence
	return {"ok":true,"error":""}

func _payload_fields(type: String) -> Array:
	match type:
		"move": return ["entity_ids","target"]
		"stop": return ["entity_ids"]
		"build": return ["builder_id","building_kind","origin"]
		"resume_build": return ["builder_id","building_id"]
		"cancel_build": return ["building_id"]
		"produce": return ["building_id","unit_kind"]
		"cancel_production": return ["building_id","production_id"]
		"set_rally": return ["building_id","target"]
		"gather": return ["entity_ids","source_id"]
		"attack": return ["entity_ids","target_id"]
		"attack_move": return ["entity_ids","target"]
	return []

func _validate(command: Dictionary, due: bool = false) -> String:
	for key in ["tick","player","sequence","type"]:
		if not command.has(key): return "Missing field: " + key
	for key in ["tick","player","sequence"]:
		if typeof(command[key]) != TYPE_INT: return key + " must be an integer"
	if (not due and command.tick < _tick) or command.player <= 0 or command.sequence < 0:
		return "Invalid tick, player or sequence"
	if not due and command.sequence <= _last_sequences.get(command.player,-1): return "Sequence must increase"
	if typeof(command.type) != TYPE_STRING or _payload_fields(command.type).is_empty(): return "Unsupported command type"
	var fields: Array = _payload_fields(command.type)
	for key in fields:
		if not command.has(key): return "Missing field: " + key
	for key in ["builder_id","building_id","production_id","source_id","target_id"]:
		if fields.has(key) and (typeof(command[key]) != TYPE_INT or command[key] <= 0): return "Invalid " + key
	for key in ["building_kind","unit_kind"]:
		if fields.has(key) and typeof(command[key]) != TYPE_STRING: return "Invalid " + key
	if fields.has("origin"):
		if not command.origin is Array or command.origin.size() != 2: return "Expected integer origin"
		for coordinate in command.origin:
			if typeof(coordinate) != TYPE_INT: return "Expected integer origin"
	var live: Array = []
	if fields.has("entity_ids"):
		if not command.entity_ids is Array or command.entity_ids.is_empty(): return "Expected nonempty entity array"
		var seen: Dictionary = {}
		for id in command.entity_ids:
			if typeof(id) != TYPE_INT or id <= 0 or seen.has(id): return "Invalid or duplicate entity ID"
			seen[id] = true
		var found: Variant = _live_ids(command.player,command.entity_ids)
		if found is String: return found
		live = found
		if live.is_empty(): return "No units left" if due else "Missing entity or wrong owner"
	if command.type == "move": return _validate_target(command,due)
	if command.type == "stop": return ""
	if command.type in ["attack","attack_move"]:
		if command.type == "attack_move": return _validate_target(command,due)
		if _armed(live).is_empty(): return "Attack requires armed units"
		return "" if Combat.valid_target(self,command.player,command.target_id) else "Invalid attack target"
	if not _players.has(command.player): return "Player has no economy"
	# Due builds are checked once by Construction.place, which reuses that preview grid.
	if command.type == "build": return "" if due else preview_build(command.player,command.builder_id,command.building_kind,Vector2i(command.origin[0],command.origin[1])).error
	if command.type == "resume_build":
		if not _entities.has(command.builder_id) or _entities[command.builder_id].owner != command.player or _entities[command.builder_id].kind != "builder": return "Invalid builder"
	if command.type in ["resume_build","cancel_build"]:
		if not _buildings.has(command.building_id) or _buildings[command.building_id].owner != command.player or _buildings[command.building_id].completed: return "Missing owned foundation"
		if command.type == "resume_build": return Construction.resume(self,command).error
		return ""
	if command.type == "set_rally":
		if not _buildings.has(command.building_id): return "Missing producer"
		var producer: Dictionary = _buildings[command.building_id]
		if producer.owner != command.player or not producer.kind in ["barracks","factory"]: return "Invalid owned producer"
		return _validate_target(command,due)
	if command.type in ["produce","cancel_production"]:
		if not _buildings.has(command.building_id): return "Missing producer"
		var building: Dictionary = _buildings[command.building_id]
		if building.owner != command.player or not building.completed: return "Invalid owned completed producer"
		if command.type == "cancel_production":
			for entry in building.queue:
				if entry.id == command.production_id: return ""
			return "Missing production entry"
		var definition: Dictionary = Definitions.unit(command.unit_kind)
		if definition.is_empty() or definition.producer != building.kind: return "Producer cannot build that unit"
		if not _has_prerequisite(command.player,Definitions.building(building.kind).prerequisite): return "Missing completed prerequisite"
		if building.queue.size() >= 9: return "Production queue full"
		if _players[command.player].credits < definition.cost: return "Insufficient credits"
		return ""
	if command.type == "gather":
		if not _sources.has(command.source_id): return "Missing supply source"
		for id in live:
			if _entities[id].kind != "collector": return "Gather requires collectors"
			if _sources[command.source_id].boxes == 0 and _entities[id].collection.cargo == 0: return "Source is empty"
		return ""
	return "Economic command unavailable"

func _validate_target(command: Dictionary, due: bool) -> String:
	if not command.target is Array or command.target.size() != 2: return "Expected two target coordinates"
	for coordinate in command.target:
		if typeof(coordinate) != TYPE_INT and typeof(coordinate) != TYPE_FLOAT: return "Target coordinates must be numbers"
		if not is_finite(float(coordinate)): return "Target coordinates must be finite"
	var target := Vector2(command.target[0],command.target[1])
	if not _in_bounds(target): return "Target outside map"
	if not due and command.has("entity_ids"):
		for id in command.entity_ids:
			if _entities.has(id) and _entities[id].kind != "collector" and not _navigation.is_walkable(target): return "Target must be walkable and within map"
	return ""

func _live_ids(player: int, ids: Array) -> Variant:
	var live: Array = []
	for id in ids:
		if not _entities.has(id): continue
		if _entities[id].owner != player: return "Missing entity or wrong owner"
		live.append(id)
	return live

func _armed(ids: Array) -> Array:
	return ids.filter(func(id): return _entities[id].combat != null)

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
		if unit.kind == "collector": continue
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
			continue
		var error: String = _validate(command,true)
		if error.is_empty():
			match command.type:
				"build":
					var placed: Dictionary = Construction.place(self,command)
					error = placed.error
					if placed.ok:
						command.building_id = placed.building_id
						_buildings[placed.building_id].rally = Production.default_rally(self,command.building_kind,Vector2i(command.origin[0],command.origin[1]))
						command.goal = placed.approach
				"resume_build": command.goal = Construction.resume(self,command).approach
				"cancel_build": Construction.cancel(self,command.building_id)
				"produce": Production.enqueue(self,command.building_id,command.unit_kind)
				"cancel_production": Production.cancel(self,command.building_id,command.production_id)
				"set_rally": _buildings[command.building_id].rally = command.target.duplicate()
		if command.type != "move":
			_command_results.append({"tick":_tick,"player":command.player,"sequence":command.sequence,"ok":error.is_empty(),"error":error})
		if not error.is_empty(): continue
		if command.has("entity_ids"):
			command.entity_ids = _live_ids(command.player,command.entity_ids)
			if command.type == "attack": command.entity_ids = _armed(command.entity_ids)
		if command.type in ["build","resume_build"]:
			command.entity_ids = [command.builder_id]
		if not command.has("entity_ids"): continue
		due.append(command)
		for id in command.entity_ids: final[id] = command
	_pending = future
	for id in final.keys():
		var intent: Dictionary = final[id]
		if intent.type in ["build","resume_build"] and not _buildings.has(intent.building_id): final.erase(id)
	for id in final:
		_detach_task(_entities[id])
		_entities[id].destination = null
		_path_queue.erase(id)
	for command in due:
		var members: Array[Dictionary] = []
		var ids: Array = command.entity_ids.duplicate()
		ids.sort()
		for id in ids:
			if final.get(id) == command:
				members.append(_entities[id])
		if members.is_empty(): continue
		if command.type in ["build","resume_build"]:
			if _buildings.has(command.building_id): _attach_builder(members[0],command.building_id,command.goal)
			continue
		if command.type == "gather":
			for unit in members:
				_stop_unit(unit)
				unit.collection.enabled = true
				unit.collection.preferred_source_id = command.source_id
				unit.collection.phase = "seeking"
				unit.collection.retry_tick = _tick
			continue
		if command.type == "stop":
			for unit in members:
				_stop_unit(unit)
				_set_intent(unit,"guard")
				if unit.combat != null: unit.combat.repath_tick = _tick + Combat.REPATH_TICKS - (_tick + unit.id) % Combat.REPATH_TICKS
			continue
		if command.type == "attack":
			if not Combat.valid_target(self,command.player,command.target_id): continue
			for unit in members:
				_stop_unit(unit)
				_set_intent(unit,"attack",command.target_id)
			continue
		_assign_move(members, command.target)
		var attack_move: bool = command.type == "attack_move"
		for unit in members: _set_intent(unit,"attack_move" if attack_move else "move",null,command.target if attack_move else null)

func _assign_move(members: Array[Dictionary], target: Array) -> void:
	var point := Vector2(target[0], target[1])
	var ground: Array[Dictionary] = []
	for unit in members:
		if unit.kind != "collector": ground.append(unit)
	_allocation_calls += 1
	var goals: Dictionary = Allocation.assign(_navigation, ground, point, _unavailable_cells(ground))
	for unit in members:
		unit.route = []
		if unit.kind == "collector":
			unit.order = {"type":"move","target":target.duplicate()}
			unit.destination = target.duplicate()
			unit.route = [target.duplicate()]
			unit.status = "moving"
			continue
		if goals[unit.id] == null:
			unit.order = null
			unit.status = "blocked"
		else:
			var goal: Vector2 = goals[unit.id]
			unit.order = {"type": "move", "target": target.duplicate()}
			unit.destination = [goal.x, goal.y]
			unit.status = "path_pending"
			_path_queue.append(unit.id)

func _set_intent(unit: Dictionary, mode: String, target_id: Variant = null, goal: Variant = null) -> void:
	if unit.combat == null: return
	_chases.erase(unit.id)
	unit.combat.mode = mode
	unit.combat.target_id = target_id
	unit.combat.goal = goal.duplicate() if goal != null else null
	unit.combat.repath_tick = _tick
	unit.combat.retarget = false

func _stop_unit(unit: Dictionary) -> void:
	unit.order = null
	unit.destination = null
	unit.route = []
	unit.status = "idle"
	_path_queue.erase(unit.id)

func _service_paths() -> void:
	for i in range(mini(PATH_REQUESTS_PER_TICK, _path_queue.size())):
		var id: int = _path_queue.pop_front()
		_assign_route(_entities[id])

func combat_work() -> int:
	return _combat_work

func scan_chases() -> int:
	return _scan_chases

func retaliations() -> int:
	return _retaliations

func navigation_builds() -> int:
	return _navigation_builds

func tick() -> int:
	return _tick

func allocation_calls() -> int:
	return _allocation_calls

func step() -> void:
	if match_over(): return
	_command_results.clear()
	_combat_events.clear()
	_combat_work = 0
	_scan_chases = 0
	_retaliations = 0
	_allocation_calls = 0
	_apply_orders()
	var ids: Array[int] = []
	ids.assign(_entities.keys())
	ids.sort()
	var armed: Array[int] = []
	for id in ids:
		if _entities[id].combat != null: armed.append(id)
	Combat.plan(self,armed)
	var rates: Dictionary = {}
	for player in _player_snapshots(): rates[player.id] = player.work_rate
	Construction.step(self,rates)
	Production.step(self,rates)
	Supply.step(self,ids)
	_service_paths()
	var before: Dictionary = {}
	for id in armed: before[id] = _entities[id].position
	for id in ids:
		if _entities[id].status == "moving":
			_advance(_entities[id])
	var moved: Array[int] = []
	for id in armed:
		if _entities[id].position != before[id]: moved.append(id)
	Combat.fire(self,armed,moved)
	if _match != null: _evaluate_match()
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
	var remaining: float = Definitions.unit(unit.kind).speed / 30.0
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
		"pending_commands": pending, "last_sequences": sequences, "map": _navigation.snapshot(), "path_queue": _path_queue.duplicate(), "players":_player_snapshots(),"buildings":_sorted_copies(_buildings),"sources":_sorted_copies(_sources),"terrain_cells":_terrain_snapshot(),"next_production_id":_next_production_id,"command_results":_command_results.duplicate(true),"combat_events":_combat_events.duplicate(true),"match":_match.duplicate(true) if _match != null else null}

func replace_blocked_cells(cells: Array[Vector2i]) -> Dictionary:
	var size: Array = _navigation.snapshot().size
	var bounds := Rect2i(0,0,size[0],size[1])
	var objects: Dictionary = {}
	for cell in _union_cells():
		if not _terrain_cells.has(cell): objects[cell] = true
	for cell in cells:
		if not bounds.has_point(cell): return {"ok":false,"error":"Obstacle outside map"}
		if objects.has(cell): return {"ok":false,"error":"Obstacle overlaps building or source"}
		for unit in _entities.values():
			if unit.kind != "collector" and _cell(unit.position) == cell: return {"ok":false,"error":"Obstacle would cover a unit"}
	var unique: Dictionary = {}
	for cell in cells: unique[cell] = true
	_terrain_cells.assign(unique.keys())
	_terrain_cells.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return _replace_union(_union_cells())

func _replace_union(cells: Array[Vector2i], prebuilt: RefCounted = null) -> Dictionary:
	var map: Dictionary = _navigation.snapshot()
	if prebuilt != null:
		_navigation = prebuilt
	else:
		_navigation_builds += 1
		_navigation.replace_blocked_cells(cells)
	if _navigation.snapshot() == map:
		return {"ok": true, "error": ""}
	_path_queue.clear()
	var ids: Array = _entities.keys()
	ids.sort()
	for id in ids:
		var unit: Dictionary = _entities[id]
		if unit.kind == "collector": continue
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

func _sorted_copies(records: Dictionary) -> Array:
	var result: Array = []
	var ids: Array = records.keys()
	ids.sort()
	for id in ids:
		result.append(records[id].duplicate(true))
	return result

func _player_snapshots() -> Array:
	var result: Array = _sorted_copies(_players)
	for player in result:
		player.power_supply = 0
		player.power_demand = 0
		for building in _buildings.values():
			if building.owner != player.id or not building.completed: continue
			var power: int = Definitions.building(building.kind).power
			if power > 0: player.power_supply += power
			else: player.power_demand -= power
		player.work_rate = Definitions.work_rate(player.power_supply,player.power_demand)
	return result

func _terrain_snapshot() -> Array:
	var result: Array = []
	for cell in _terrain_cells:
		result.append([cell.x,cell.y])
	return result

func _in_bounds(point: Vector2) -> bool:
	var size: Array = _navigation.snapshot().size
	return point.is_finite() and point.x >= 0 and point.y >= 0 and point.x < size[0] and point.y < size[1]

func preview_build(player: int, builder_id: int, kind: String, origin: Vector2i) -> Dictionary:
	var result: Dictionary = Construction.preview(self,player,builder_id,kind,origin)
	result.erase("navigation")
	return result

func remove_object(id: int) -> Dictionary:
	if _entities.has(id):
		_detach_task(_entities[id])
		_path_queue.erase(id)
		_entities.erase(id)
		_chases.erase(id)
		Combat.object_removed(self,id)
	elif _buildings.has(id):
		_remove_building(id)
	elif _sources.has(id):
		Supply.object_removed(self,id)
		_sources.erase(id)
		Construction.rebuild_navigation(self)
	else:
		return {"ok":false,"error":"Unknown object"}
	return {"ok":true,"error":""}

func _has_prerequisite(player: int, kind: String) -> bool:
	if kind.is_empty(): return true
	for building in _buildings.values():
		if building.owner == player and building.kind == kind and building.completed: return true
	return false

func _union_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = _terrain_cells.duplicate()
	for building in _buildings.values():
		cells.append_array(Construction.cells(building.kind,Vector2i(building.origin[0],building.origin[1])))
	for source in _sources.values():
		cells.append_array(Construction.cells("depot",Vector2i(source.origin[0],source.origin[1])))
	return cells

func _detach_task(unit: Dictionary) -> void:
	if unit.collection != null:
		Supply.release(self,unit.id)
		unit.collection.enabled = false
		unit.collection.phase = "idle"
	if unit.construction_id != null and _buildings.has(unit.construction_id):
		var building: Dictionary = _buildings[unit.construction_id]
		if building.builder_id == unit.id:
			building.builder_id = null
			building.approach = null
	unit.construction_id = null

func _attach_builder(unit: Dictionary, id: int, goal: Array) -> void:
	var building: Dictionary = _buildings[id]
	Production.refund_all(self,id)
	if building.builder_id != null and _entities.has(building.builder_id):
		var previous: Dictionary = _entities[building.builder_id]
		if previous.construction_id == id:
			_detach_task(previous)
			_stop_unit(previous)
	building.builder_id = unit.id
	building.approach = goal.duplicate()
	unit.construction_id = id
	unit.destination = goal.duplicate()
	unit.order = {"type":"move","target":goal.duplicate()}
	unit.route = []
	unit.status = "path_pending"
	_path_queue.append(unit.id)

func _remove_building(id: int) -> void:
	Supply.object_removed(self,id)
	var building: Dictionary = _buildings[id]
	Production.refund_all(self,id)
	if building.builder_id != null and _entities.has(building.builder_id):
		var builder: Dictionary = _entities[building.builder_id]
		if builder.construction_id == id:
			_detach_task(builder)
			_stop_unit(builder)
	_buildings.erase(id)
	Combat.object_removed(self,id)
	Construction.rebuild_navigation(self)

func _grant_collector(building: Dictionary) -> void:
	Production.spawn_collector(self,building)

func add_supply_source(origin: Vector2i, boxes: int) -> int:
	if boxes < 0: return -1
	if not Construction.footprint_error(self,Construction.cells("depot",origin)).is_empty(): return -1
	var id: int = _next_entity_id
	_next_entity_id += 1
	_sources[id] = {"id":id,"origin":[origin.x,origin.y],"boxes":boxes,"active_collector_id":null}
	Construction.rebuild_navigation(self)
	return id
