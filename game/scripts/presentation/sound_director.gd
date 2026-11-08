extends RefCounted

const Cues = preload("res://scripts/presentation/sound_cues.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Shared = preload("res://scripts/simulation/definitions/shared.gd")
const MAX_PENDING := 120
const MAX_CONSUMED := 64
const FUNDS_ERROR := "Insufficient credits"

var _local_player: int
var _rng: RandomNumberGenerator
var _pending: Array[Dictionary] = []
var _consumed: Array[int] = []
var _queued: Array[Dictionary] = []
var _last_collected: int = -1
var _previous: Dictionary = {}
var _previous_status: String = ""
var _has_previous: bool = false
var _last_shot: Dictionary = {}

func _init(local_player: int, rng: RandomNumberGenerator = null) -> void:
	_local_player = local_player
	_rng = rng
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()

func collect_step(tick: int, events: Array[Dictionary], results: Array[Dictionary]) -> void:
	if tick <= _last_collected: return
	_last_collected = tick
	_pending.append({"tick": tick, "events": events.duplicate(true), "results": results.duplicate(true)})
	if _pending.size() > MAX_PENDING: _pending.pop_front()

func collected_ticks() -> Array[int]:
	var ticks: Array[int] = []
	for step: Dictionary in _pending: ticks.append(step.tick)
	return ticks

func consumed_ticks() -> Array[int]:
	return _consumed

func pending_step(index: int) -> Dictionary:
	return _pending[index]

func rejected(error: String) -> void:
	if error != FUNDS_ERROR: _queued.append(ui_request("error"))

func update(state: Dictionary) -> Array[Dictionary]:
	var requests: Array[Dictionary] = _queued.duplicate()
	_queued.clear()
	var current: Dictionary = _records(state)
	var match_state: Variant = state.get("match")
	var status: String = match_state.status if match_state is Dictionary else ""
	if _has_previous:
		for step: Dictionary in _pending:
			_consume(step, current, requests)
			_consumed.append(step.tick)
		if _consumed.size() > MAX_CONSUMED: _consumed = _consumed.slice(-MAX_CONSUMED)
		_placements(current, status, requests)
	_pending.clear()
	for id: Variant in _last_shot.keys():
		if not current.has(id): _last_shot.erase(id)
	_previous = current
	_previous_status = status
	_has_previous = true
	return requests

func reset() -> void:
	_pending.clear()
	_queued.clear()
	_consumed.clear()
	_last_shot.clear()
	_previous = {}
	_previous_status = ""
	_has_previous = false
	_last_collected = -1

func _records(state: Dictionary) -> Dictionary:
	var records: Dictionary = {}
	for unit: Dictionary in state.get("entities", []):
		var combat: Variant = unit.get("combat")
		records[unit.id] = {"kind": unit.kind, "owner": unit.owner, "position": Vector2(unit.position[0], unit.position[1]), "tier": combat.get("tier", 0) if combat is Dictionary else 0, "building": false, "completed": true, "hole": false, "site": false}
	for building: Dictionary in state.get("buildings", []):
		var footprint: Vector2i = Registry.kind(building.kind).get("footprint", Vector2i.ONE)
		records[building.id] = {"kind": building.kind, "owner": building.owner, "position": Vector2(building.origin[0], building.origin[1]) + Vector2(footprint) / 2.0, "tier": 0, "building": true, "completed": building.get("completed", true), "hole": building.has("rebuild"), "site": building.has("hole_id")}
	return records

func _lookup(id: int, current: Dictionary) -> Dictionary:
	return current.get(id, _previous.get(id, {}))

func _consume(step: Dictionary, current: Dictionary, requests: Array[Dictionary]) -> void:
	for event: Dictionary in step.events:
		if event.type == "shot": _shot(event, current, requests)
		elif event.type == "death": _death(event, current, requests)
	for result: Dictionary in step.results:
		if result.player == _local_player and not result.ok and result.error != FUNDS_ERROR: requests.append(ui_request("error"))

func _shot(event: Dictionary, current: Dictionary, requests: Array[Dictionary]) -> void:
	var attacker: Dictionary = _lookup(event.attacker_id, current)
	if attacker.is_empty() or event.splash: return
	var weapon: String = Cues.weapon_id(attacker.kind, attacker.tier)
	var cue: String = Cues.shot_cue(weapon)
	var definition: Dictionary = Shared.WEAPONS.get(weapon, {})
	var last: int = _last_shot.get(event.attacker_id, -1000000)
	_last_shot[event.attacker_id] = event.tick
	if cue.is_empty(): return
	if cue != "rifle_burst" or event.tick - last > definition.delay_ticks + 1: requests.append(_world(cue, attacker.position))
	var target: Dictionary = _lookup(event.target_id, current)
	if not definition.affects.is_empty() and not target.is_empty(): requests.append(_world("impact", target.position))

func _death(event: Dictionary, current: Dictionary, requests: Array[Dictionary]) -> void:
	var dead: Dictionary = _lookup(event.object_id, current)
	if dead.is_empty(): return
	var cue: String = Cues.death_cue(dead.kind, dead.building)
	var request: Dictionary = _world(cue, dead.position)
	if dead.building: request.sound = Cues.building_sound(dead.kind)
	var jitter: float = Cues.CUES[cue].jitter
	if jitter > 0.0: request.pitch = 1.0 + _rng.randf_range(-jitter, jitter)
	requests.append(request)

func _placements(current: Dictionary, status: String, requests: Array[Dictionary]) -> void:
	if status != "ongoing" or _previous_status != "ongoing": return
	for id: Variant in current:
		var record: Dictionary = current[id]
		if record.building and record.owner == _local_player and not record.hole and not record.site and not _previous.has(id):
			requests.append(ui_request("placement"))

func _world(cue: String, position: Vector2) -> Dictionary:
	return {"cue": cue, "sound": Cues.CUES[cue].sound, "pitch": Cues.CUES[cue].pitch, "position": position}

func ui_request(cue: String) -> Dictionary:
	return {"cue": cue, "sound": Cues.CUES[cue].sound, "pitch": Cues.CUES[cue].pitch, "position": null}
