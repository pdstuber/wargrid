extends RefCounted

const Supply = preload("res://scripts/simulation/supply_collection.gd")
const Production = preload("res://scripts/simulation/production.gd")
const Construction = preload("res://scripts/simulation/construction.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Containers = preload("res://scripts/simulation/containers.gd")
const Horde = preload("res://scripts/simulation/horde.gd")
const Locomotion = preload("res://scripts/simulation/locomotion.gd")
const Allocation = preload("res://scripts/simulation/destination_allocation.gd")
const Navigation = preload("res://scripts/simulation/grid_navigation.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const PATH_REQUESTS_PER_TICK: int = 8
const START_DELAY_TICKS: int = 2
var _navigation: RefCounted

var _players: Dictionary = {}
var _buildings: Dictionary = {}
var _sources: Dictionary = {}
var _terrain_cells: Array[Vector2i] = []
var _terrain_cache: Array = []
var _terrain_cached: bool = false
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
var _horde_checks: int = 0
var _chases: Dictionary = {}
var _scan_chases: int = 0
var _retaliations: int = 0
var _allocation_calls: int = 0
var _navigation_builds: int = 0
var _navigation_local: int = 0
var _map: Dictionary = {}
const RNG_SEED: int = 0x2545F491
var _rng: int = RNG_SEED

func _init(blocked_cells: Array[Vector2i] = [], size: Vector2i = Navigation.SIZE) -> void:
	_navigation = Navigation.new(blocked_cells, size)
	for cell: Variant in _navigation.snapshot().blocked_cells:
		_terrain_cells.append(Vector2i(cell[0],cell[1]))

func next_random() -> int:
	var x: int = _rng
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	_rng = x
	return x

func map_data() -> Dictionary:
	return _map

func add_player(player: int, credits: int, controller: String = "human", team: int = 0) -> Dictionary:
	if controller != "human" and controller != "ai": return {"ok": false, "error": "Invalid controller"}
	if player <= 0 or credits < 0 or _players.has(player) or team < 0:
		return {"ok": false, "error": "Invalid or duplicate player"}
	_players[player] = {"id":player,"credits":credits,"controller":controller,"team":team if team > 0 else player}
	return {"ok":true,"error":""}

func team_of(player: int) -> int:
	return _players[player].team if _players.has(player) else 0

func spawn(owner: int, position: Vector2, kind: String = "", occupied: Variant = null) -> int:
	if kind.is_empty(): kind = Registry.DEFAULT_SPAWN
	if Definitions.unit(kind).is_empty() or owner <= 0 or not _in_bounds(position) or (not Registry.air_kinds.has(kind) and not _navigation.is_walkable(position)):
		return -1
	var cell := Vector2i(position.floor())
	if not Registry.air_kinds.has(kind) and (occupied if occupied != null else occupied_cells()).has(cell): return -1
	var id: int = _next_entity_id
	_entities[id] = {"id": id, "owner": owner, "position": [position.x, position.y], "order": null, "status": "idle", "route": [], "destination": null, "kind":kind,"hp":CombatDefinitions.profile(kind).max_hp,"max_hp":CombatDefinitions.profile(kind).max_hp,"combat":CombatDefinitions.initial_combat(kind),"speed":0.0,"move_after":0,"heading":[1.0,0.0],"construction_id":null,"collection": {"enabled":false,"preferred_source_id":null,"target_id":null,"phase":"idle","remaining_ticks":0,"retry_tick":0,"cargo":0} if not Registry.collects(kind).is_empty() else null}
	_next_entity_id += 1
	if Registry.kind(kind).has("horde") and _entities[id].combat != null:
		_entities[id].combat.horde = 0
		_entities[id].combat.horde_tick = Horde.first_check(self,kind)
	return id

func occupied_cells() -> Dictionary:
	var cells: Dictionary = {}
	for unit: Dictionary in _entities.values():
		if Registry.air_kinds.has(unit.kind) or unit.has("container_id"): continue
		cells[_cell(unit.position)] = true
		if unit.destination != null: cells[_cell(unit.destination)] = true
	return cells

func start_match(players: Array[int]) -> Dictionary:
	return _begin_match(players, "ongoing")

func begin_setup(players: Array[int]) -> Dictionary:
	return _begin_match(players, "setup")

func _begin_match(players: Array[int], status: String) -> Dictionary:
	var ids: Array[int] = players.duplicate()
	ids.sort()
	if _match != null or ids.size() < 2 or ids.size() > 8 or ids[0] <= 0: return {"ok":false,"error":"Invalid match players"}
	var teams: Dictionary = {}
	for i in ids.size():
		if i > 0 and ids[i] == ids[i - 1]: return {"ok":false,"error":"Invalid match players"}
		if not _players.has(ids[i]) or (status == "ongoing" and not _survives(ids[i])): return {"ok":false,"error":"Player cannot start a match"}
		teams[team_of(ids[i])] = true
	if teams.size() < 2: return {"ok":false,"error":"Invalid match players"}
	_match = {"players":ids,"status":status,"winner":null,"ended_tick":null}
	return {"ok":true,"error":""}

func setup_seat(player: int, faction: String) -> void:
	var definition: Dictionary = Registry.faction(faction)
	var start: Dictionary = _map_start(player)
	_players[player].faction = faction
	spawn(player, Vector2(start.cell[0], start.cell[1]) + Vector2(0.5, 0.5), definition.start_unit)
	var origin: Array = start.slots[Registry.kind(definition.start_building).slot]
	var id: int = _next_entity_id
	_next_entity_id += 1
	var hp: int = CombatDefinitions.profile(definition.start_building).max_hp
	_buildings[id] = {"id":id,"owner":player,"kind":definition.start_building,"hp":hp,"max_hp":hp,"origin":[int(origin[0]),int(origin[1])],"completed":true,"work":0,"paid_cost":0,"builder_id":null,"approach":null,"queue":[],"active_collector_id":null}
	if Registry.can_rally(definition.start_building): _buildings[id].rally = Production.default_rally(self,definition.start_building,Vector2i(int(origin[0]),int(origin[1])))
	_replace_union(_union_cells())

func _map_start(player: int) -> Dictionary:
	for start: Dictionary in _map.starts:
		if int(start.seat) == player: return start
	return {}

func _survives(player: int) -> bool:
	for building: Dictionary in _buildings.values():
		if building.owner == player and Registry.kind(building.kind).counts_for_victory: return true
	return false

func _evaluate_match() -> void:
	var alive: Dictionary = {}
	for player: int in _match.players:
		if _survives(player): alive[team_of(player)] = true
	if alive.size() > 1: return
	_match.status = "draw" if alive.is_empty() else "won"
	_match.winner = alive.keys()[0] if alive.size() == 1 else null
	_match.ended_tick = _tick

func match_over() -> bool:
	return _match != null and _match.status in ["won","draw"]

func issue_command(command: Dictionary) -> Dictionary:
	if match_over(): return {"ok":false,"error":"Match ended"}
	var error: String = _validate(command)
	if not error.is_empty():
		return {"ok":false,"error":error}
	var normalized := {"tick":command.tick,"player":command.player,"sequence":command.sequence,"type":command.type}
	for key: Variant in _payload_fields(command.type):
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
		"choose_faction": return ["faction"]
		"gather": return ["entity_ids","source_id"]
		"attack": return ["entity_ids","target_id"]
		"attack_move": return ["entity_ids","target"]
		"enter": return ["entity_ids","target_id"]
		"unload": return ["target_id"]
		"defence_attack": return ["building_id","target_id"]
	return []

func _validate(command: Dictionary, due: bool = false) -> String:
	for key: String in ["tick","player","sequence","type"]:
		if not command.has(key): return "Missing field: " + key
	for key: String in ["tick","player","sequence"]:
		if typeof(command[key]) != TYPE_INT: return key + " must be an integer"
	if (not due and command.tick < _tick) or command.player <= 0 or command.sequence < 0:
		return "Invalid tick, player or sequence"
	if not due and command.sequence <= _last_sequences.get(command.player,-1): return "Sequence must increase"
	if typeof(command.type) != TYPE_STRING or _payload_fields(command.type).is_empty(): return "Unsupported command type"
	var setup_error: String = _setup_error(command)
	if not setup_error.is_empty(): return setup_error
	var fields: Array = _payload_fields(command.type)
	for key: Variant in fields:
		if not command.has(key): return "Missing field: " + key
	for key: String in ["builder_id","building_id","production_id","source_id","target_id"]:
		if fields.has(key) and (typeof(command[key]) != TYPE_INT or command[key] <= 0): return "Invalid " + key
	for key: String in ["building_kind","unit_kind"]:
		if fields.has(key) and typeof(command[key]) != TYPE_STRING: return "Invalid " + key
	if fields.has("origin"):
		if not command.origin is Array or command.origin.size() != 2: return "Expected integer origin"
		for coordinate: Variant in command.origin:
			if typeof(coordinate) != TYPE_INT: return "Expected integer origin"
	var live: Array = []
	if fields.has("entity_ids"):
		if not command.entity_ids is Array or command.entity_ids.is_empty(): return "Expected nonempty entity array"
		var seen: Dictionary = {}
		for id: Variant in command.entity_ids:
			if typeof(id) != TYPE_INT or id <= 0 or seen.has(id): return "Invalid or duplicate entity ID"
			seen[id] = true
		var found: Variant = _live_ids(command.player,command.entity_ids)
		if found is String: return found
		live = found
		if live.is_empty(): return "No units left" if due else "Missing entity or wrong owner"
		if live.any(func(id: int) -> bool: return _entities[id].has("container_id")): return "Unit is inside a transport"
	if command.type == "move": return _validate_target(command,due)
	if command.type in ["stop","choose_faction"]: return ""
	if command.type == "enter": return Containers.enter_error(self,command,live)
	if command.type == "unload": return Containers.unload_error(self,command)
	if command.type == "defence_attack": return Combat.defence_attack_error(self,command)
	if command.type in ["attack","attack_move"]:
		if command.type == "attack_move": return _validate_target(command,due)
		if _armed(live).is_empty(): return "Attack requires armed units"
		return "" if Combat.valid_target(self,command.player,command.target_id) else "Invalid attack target"
	if not _players.has(command.player): return "Player has no economy"
	# Due builds are checked once by Construction.place, which reuses that preview grid.
	if command.type == "build": return "" if due else preview_build(command.player,command.builder_id,command.building_kind,Vector2i(command.origin[0],command.origin[1])).error
	if command.type == "resume_build":
		if not _entities.has(command.builder_id) or _entities[command.builder_id].owner != command.player or not Registry.is_builder(_entities[command.builder_id].kind): return "Invalid builder"
	if command.type in ["resume_build","cancel_build"]:
		if not _buildings.has(command.building_id) or _buildings[command.building_id].owner != command.player or _buildings[command.building_id].completed: return "Missing owned foundation"
		if command.type == "resume_build": return Construction.resume(self,command).error
		return ""
	if command.type == "set_rally":
		if not _buildings.has(command.building_id): return "Missing producer"
		var producer: Dictionary = _buildings[command.building_id]
		if producer.owner != command.player or not Registry.can_rally(producer.kind): return "Invalid owned producer"
		return _validate_target(command,due)
	if command.type in ["produce","cancel_production"]:
		if not _buildings.has(command.building_id): return "Missing producer"
		var building: Dictionary = _buildings[command.building_id]
		if building.owner != command.player or not building.completed: return "Invalid owned completed producer"
		if command.type == "cancel_production":
			for entry: Variant in building.queue:
				if entry.id == command.production_id: return ""
			return "Missing production entry"
		var definition: Dictionary = Definitions.unit(command.unit_kind)
		if definition.is_empty() or not Registry.kind(building.kind).get("produces", []).has(command.unit_kind): return "Producer cannot build that unit"
		if not _has_prerequisite(command.player,Definitions.building(building.kind).prerequisite): return "Missing completed prerequisite"
		if building.queue.size() >= 9: return "Production queue full"
		if _players[command.player].credits < definition.cost: return "Insufficient credits"
		return ""
	if command.type == "gather":
		if not _sources.has(command.source_id): return "Missing supply source"
		for id: Variant in live:
			if Registry.collects(_entities[id].kind).is_empty(): return "Gather requires collectors"
			if _sources[command.source_id].boxes == 0 and _entities[id].collection.cargo == 0: return "Source is empty"
		return ""
	return "Economic command unavailable"

func _start_when_chosen() -> void:
	if _match != null and _match.status == "setup" and _match.players.all(func(player: int) -> bool: return _players[player].has("faction")):
		_match.status = "ongoing"

func _setup_error(command: Dictionary) -> String:
	var chosen: bool = _players.get(command.player, {}).has("faction")
	if command.type != "choose_faction":
		if _match == null or _match.status != "setup" or not _players.has(command.player): return ""
		return "Match has not started" if chosen else "Choose a faction first"
	if not command.has("faction") or typeof(command.faction) != TYPE_STRING or Registry.faction(command.faction).is_empty(): return "Unknown faction"
	return "Faction already chosen" if chosen or _match == null or _match.status != "setup" else ""

func _validate_target(command: Dictionary, due: bool) -> String:
	if not command.target is Array or command.target.size() != 2: return "Expected two target coordinates"
	for coordinate: Variant in command.target:
		if typeof(coordinate) != TYPE_INT and typeof(coordinate) != TYPE_FLOAT: return "Target coordinates must be numbers"
		if not is_finite(float(coordinate)): return "Target coordinates must be finite"
	var target := Vector2(command.target[0],command.target[1])
	if not _in_bounds(target): return "Target outside map"
	if not due and command.has("entity_ids"):
		for id: Variant in command.entity_ids:
			if _entities.has(id) and not Registry.air_kinds.has(_entities[id].kind) and not _navigation.is_walkable(target): return "Target must be walkable and within map"
	return ""

func _live_ids(player: int, ids: Array) -> Variant:
	var live: Array = []
	for id: Variant in ids:
		if not _entities.has(id): continue
		if _entities[id].owner != player: return "Missing entity or wrong owner"
		live.append(id)
	return live

func _armed(ids: Array) -> Array:
	return ids.filter(func(id: int) -> bool: return _entities[id].combat != null)

func _command_before(a: Dictionary, b: Dictionary) -> bool:
	for key: String in ["tick", "player", "sequence"]:
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
	for unit: Dictionary in _entities.values():
		if Registry.air_kinds.has(unit.kind) or unit.has("container_id"): continue
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
				"choose_faction": setup_seat(command.player,command.faction)
				"unload": Containers.unload(self,command.target_id)
				"defence_attack": _buildings[command.building_id].combat.target_id = command.target_id
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
		for id: Variant in command.entity_ids: final[id] = command
	_pending = future
	_start_when_chosen()
	for id: Variant in final.keys():
		var intent: Dictionary = final[id]
		if intent.type in ["build","resume_build"] and not _buildings.has(intent.building_id): final.erase(id)
	for id: Variant in final:
		_detach_task(_entities[id])
		_entities[id].destination = null
		_path_queue.erase(id)
	for command in due:
		var members: Array[Dictionary] = []
		var ids: Array = command.entity_ids.duplicate()
		ids.sort()
		for id: Variant in ids:
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
		if command.type == "enter":
			for unit in members: Containers.head_for(self,unit,_entities[command.target_id])
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
		if not Registry.air_kinds.has(unit.kind): ground.append(unit)
	_allocation_calls += 1
	var zone: int = Profiler.begin()
	var unavailable: Array[Vector2i] = _unavailable_cells(ground)
	Profiler.end(&"assign_move.unavailable", zone)
	zone = Profiler.begin()
	var goals: Dictionary = Allocation.assign(_navigation, ground, point, unavailable)
	Profiler.end(&"allocation.assign", zone)
	for unit in members:
		unit.route = []
		if Registry.air_kinds.has(unit.kind):
			unit.order = {"type":"move","target":target.duplicate()}
			unit.destination = target.duplicate()
			unit.route = [_frozen(target.duplicate())]
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
		var zone: int = Profiler.begin()
		_assign_route(_entities[id])
		Profiler.end(&"route", zone)

func combat_work() -> int:
	return _combat_work

func horde_checks() -> int:
	return _horde_checks

func scan_chases() -> int:
	return _scan_chases

func retaliations() -> int:
	return _retaliations

func navigation_builds() -> int:
	return _navigation_builds

func navigation_local_updates() -> int:
	return _navigation_local

func tick() -> int:
	return _tick

func allocation_calls() -> int:
	return _allocation_calls

func step() -> void:
	if match_over(): return
	var total: int = Profiler.begin()
	_command_results.clear()
	_combat_events.clear()
	_combat_work = 0
	_horde_checks = 0
	_scan_chases = 0
	_retaliations = 0
	_allocation_calls = 0
	var zone: int = Profiler.begin()
	_apply_orders()
	Profiler.end(&"step.apply_orders", zone)
	zone = Profiler.begin()
	var ids: Array[int] = []
	ids.assign(_entities.keys())
	ids.sort()
	var armed: Array[int] = []
	for id in ids:
		if _entities[id].combat != null: armed.append(id)
	Profiler.end(&"step.ids", zone)
	zone = Profiler.begin()
	Combat.plan(self,armed)
	Profiler.end(&"step.combat_plan", zone)
	zone = Profiler.begin()
	var rates: Dictionary = {}
	for player: Dictionary in _player_snapshots(): rates[player.id] = player.work_rate
	Profiler.end(&"step.rates", zone)
	zone = Profiler.begin()
	Construction.step(self,rates)
	Profiler.end(&"step.construction", zone)
	zone = Profiler.begin()
	Production.step(self,rates)
	Profiler.end(&"step.production", zone)
	zone = Profiler.begin()
	Supply.step(self,ids)
	Profiler.end(&"step.supply", zone)
	zone = Profiler.begin()
	_service_paths()
	Profiler.end(&"step.service_paths", zone)
	zone = Profiler.begin()
	var before: Dictionary = {}
	for id in armed: before[id] = _entities[id].position
	for id in ids:
		var unit: Dictionary = _entities[id]
		if unit.status == "moving": _advance(unit)
		elif unit.status != "path_pending": unit.speed = 0.0
	Containers.step(self)
	Horde.step(self,armed)
	var moved: Array[int] = []
	for id in armed:
		if _entities[id].position != before[id] and not _entities[id].has("container_id"): moved.append(id)
	Profiler.end(&"step.advance", zone)
	zone = Profiler.begin()
	Combat.fire(self,armed,moved)
	Combat.fire_defences(self)
	Profiler.end(&"step.combat_fire", zone)
	zone = Profiler.begin()
	if _match != null and _match.status == "ongoing": _evaluate_match()
	Profiler.end(&"step.evaluate_match", zone)
	_tick += 1
	Profiler.end(&"step", total)

func _assign_route(unit: Dictionary) -> void:
	var from := Vector2(unit.position[0], unit.position[1])
	var to := Vector2(unit.destination[0], unit.destination[1])
	unit.route = []
	for point: Variant in _navigation.route(from, to):
		unit.route.append(_frozen([point.x, point.y]))
	if unit.route.size() > 1 and _behind(from, unit.route[0], unit.route[1]): unit.route.pop_front()
	unit.status = "blocked" if unit.route.is_empty() else "moving"
	if unit.status == "moving" and unit.speed == 0.0: unit.move_after = _tick + START_DELAY_TICKS
	if unit.status == "blocked":
		unit.order = null
		unit.destination = null

func _behind(from: Vector2, first: Array, second: Array) -> bool:
	return (first[0] - from.x) * (second[0] - first[0]) + (first[1] - from.y) * (second[1] - first[1]) < 0.0

# Snapshots share route arrays, so waypoints are read-only and the route is replaced, never edited, once it is shared.
static func _frozen(waypoint: Array) -> Array:
	waypoint.make_read_only()
	return waypoint

func _entity_copy(unit: Dictionary) -> Dictionary:
	var copy: Dictionary = unit.duplicate()
	for key: Variant in copy:
		if key != "route" and (copy[key] is Array or copy[key] is Dictionary): copy[key] = copy[key].duplicate(true)
	if not unit.route.is_read_only(): unit.route.make_read_only()
	return copy

func _advance(unit: Dictionary) -> void:
	var remaining: float = Locomotion.step(unit, Definitions.unit(unit.kind), _tick)
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
			unit.route = unit.route.slice(1)
		else:
			x += dx / distance * remaining
			y += dy / distance * remaining
			break
	unit.position = [x, y]
	if unit.route.is_empty():
		if not Containers.entering(unit): unit.order = null
		unit.speed = 0.0
		unit.status = "arrived"

func snapshot() -> Dictionary:
	var zone: int = Profiler.begin()
	var result: Dictionary = _snapshot()
	Profiler.end(&"snapshot", zone)
	return result

func _snapshot() -> Dictionary:
	var entities: Array = []
	var ids: Array = _entities.keys()
	ids.sort()
	for id: Variant in ids:
		entities.append(_entity_copy(_entities[id]))
	var pending: Array = _pending.duplicate(true)
	pending.sort_custom(_command_before)
	var sequences: Array = []
	var players: Array = _last_sequences.keys()
	players.sort()
	for player: Variant in players:
		sequences.append({"player": player, "sequence": _last_sequences[player]})
	return {"tick": _tick, "next_entity_id": _next_entity_id, "entities": entities,
		"pending_commands": pending, "last_sequences": sequences, "map": _navigation.snapshot(), "path_queue": _path_queue.duplicate(), "players":_player_snapshots(true),"buildings":_sorted_copies(_buildings),"sources":_sorted_copies(_sources),"terrain_cells":_terrain_snapshot(),"next_production_id":_next_production_id,"command_results":_command_results.duplicate(true),"combat_events":_combat_events.duplicate(true),"match":_match.duplicate(true) if _match != null else null,"rng":_rng}

func replace_blocked_cells(cells: Array[Vector2i]) -> Dictionary:
	var size: Array = _navigation.snapshot().size
	var bounds := Rect2i(0,0,size[0],size[1])
	var objects: Dictionary = {}
	for cell in _union_cells():
		if not _terrain_cells.has(cell): objects[cell] = true
	for cell in cells:
		if not bounds.has_point(cell): return {"ok":false,"error":"Obstacle outside map"}
		if objects.has(cell): return {"ok":false,"error":"Obstacle overlaps building or source"}
		for unit: Dictionary in _entities.values():
			if not Registry.air_kinds.has(unit.kind) and not unit.has("container_id") and _cell(unit.position) == cell: return {"ok":false,"error":"Obstacle would cover a unit"}
	var unique: Dictionary = {}
	for cell in cells: unique[cell] = true
	_terrain_cells.assign(unique.keys())
	_terrain_cells.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	_terrain_cached = false
	return _replace_union(_union_cells())

func _replace_union(cells: Array[Vector2i], prebuilt: RefCounted = null) -> Dictionary:
	var map: Dictionary = _navigation.snapshot()
	if prebuilt != null:
		_navigation = prebuilt
	else:
		var how: String = _navigation.replace_blocked_cells(cells)
		if how == "full": _navigation_builds += 1
		elif how == "local": _navigation_local += 1
	if _navigation.snapshot() == map:
		return {"ok": true, "error": ""}
	_path_queue.clear()
	var ids: Array = _entities.keys()
	ids.sort()
	for id: Variant in ids:
		var unit: Dictionary = _entities[id]
		if Registry.air_kinds.has(unit.kind): continue
		if unit.status != "moving" and unit.status != "path_pending":
			continue
		unit.route = []
		var destination := Vector2(unit.destination[0], unit.destination[1])
		var position := Vector2(unit.position[0], unit.position[1])
		if not _navigation.is_walkable(destination) or _navigation.component_at(position) != _navigation.component_at(destination):
			unit.order = null
			unit.destination = null
			unit.speed = 0.0
			unit.status = "blocked"
		else:
			unit.status = "path_pending"
			_path_queue.append(id)
	return {"ok": true, "error": ""}

func _sorted_copies(records: Dictionary) -> Array:
	var result: Array = []
	var ids: Array = records.keys()
	ids.sort()
	for id: Variant in ids:
		result.append(records[id].duplicate(true))
	return result

func _player_snapshots(with_alive: bool = false) -> Array:
	var result: Array = _sorted_copies(_players)
	for player: Variant in result:
		player.power_supply = 0
		player.power_demand = 0
		for building: Dictionary in _buildings.values():
			if building.owner != player.id or not building.completed: continue
			var power: int = Definitions.building(building.kind).power
			if power > 0: player.power_supply += power
			else: player.power_demand -= power
		player.work_rate = Definitions.work_rate(player.power_supply,player.power_demand)
		if with_alive: player.alive = _survives(player.id)
	return result

func _terrain_snapshot() -> Array:
	if not _terrain_cached:
		var result: Array = []
		for cell in _terrain_cells:
			var pair: Array = [cell.x,cell.y]
			pair.make_read_only()
			result.append(pair)
		result.make_read_only()
		_terrain_cache = result
		_terrain_cached = true
	return _terrain_cache

func _in_bounds(point: Vector2) -> bool:
	var size: Array = _navigation.snapshot().size
	return point.is_finite() and point.x >= 0 and point.y >= 0 and point.x < size[0] and point.y < size[1]

func preview_build(player: int, builder_id: int, kind: String, origin: Vector2i) -> Dictionary:
	var result: Dictionary = Construction.preview(self,player,builder_id,kind,origin)
	result.erase("navigation")
	return result

func remove_object(id: int) -> Dictionary:
	if _entities.has(id):
		Containers.object_removed(self,id)
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
	for building: Dictionary in _buildings.values():
		if building.owner == player and building.kind == kind and building.completed: return true
	return false

func _union_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = _terrain_cells.duplicate()
	for building: Dictionary in _buildings.values():
		cells.append_array(Construction.cells(building.kind,Vector2i(building.origin[0],building.origin[1])))
	for source: Dictionary in _sources.values():
		cells.append_array(Construction.block(Registry.SOURCE_FOOTPRINT,Vector2i(source.origin[0],source.origin[1])))
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

# shortcut: the free unit is lost when every exit cell is occupied; upgrade if a playtest shows it.
func _spawn_on_complete(building: Dictionary) -> void:
	for kind: String in Registry.kind(building.kind).spawns_on_complete: Production.spawn_unit(self,building,kind,null)

func add_supply_source(origin: Vector2i, boxes: int) -> int:
	if boxes < 0: return -1
	if not Construction.footprint_error(self,Construction.block(Registry.SOURCE_FOOTPRINT,origin)).is_empty(): return -1
	var id: int = _next_entity_id
	_next_entity_id += 1
	_sources[id] = {"id":id,"origin":[origin.x,origin.y],"boxes":boxes,"active_collector_id":null}
	Construction.rebuild_navigation(self)
	return id
