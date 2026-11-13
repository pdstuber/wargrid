extends RefCounted

const Cues = preload("res://scripts/presentation/sound_cues.gd")
const Announcer = preload("res://scripts/presentation/announcer.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Shared = preload("res://scripts/simulation/definitions/shared.gd")
const ViewRows = preload("res://scripts/simulation/view_rows.gd")
const UnitVoice = preload("res://scripts/presentation/unit_voice.gd")
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
var _rows: RefCounted = ViewRows.new()
var _previous_rows: RefCounted = ViewRows.new()
var _previous_status: String = ""
var _has_previous: bool = false
var _last_shot: Dictionary = {}
var _funds_rejected: bool = false
var _was_low_power: bool = false
var announcer := Announcer.new()

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
	if error == FUNDS_ERROR: _funds_rejected = true
	else: _queued.append(ui_request("error"))

func update(state: Dictionary) -> Array[Dictionary]:
	var requests: Array[Dictionary] = _queued.duplicate()
	_queued.clear()
	var current: Dictionary = _records(state)
	_rows = state.units
	var match_state: Variant = state.get("match")
	var status: String = match_state.status if match_state is Dictionary else ""
	if _has_previous:
		for step: Dictionary in _pending:
			_consume(step, current, requests)
			_consumed.append(step.tick)
		if _consumed.size() > MAX_CONSUMED: _consumed = _consumed.slice(-MAX_CONSUMED)
		_placements(current, status, requests)
		_triggers(state, current, status)
	var tick: int = state.get("tick", 0)
	if _funds_rejected: announcer.request("insufficient_funds", tick)
	_funds_rejected = false
	_was_low_power = _low_power(state)
	_pending.clear()
	for id: Variant in _last_shot.keys():
		if not current.has(id) and _rows.index_of(id) == -1: _last_shot.erase(id)
	_previous = current
	_previous_rows = _rows
	_previous_status = status
	_has_previous = true
	return requests

func order_voice(payload: Dictionary, busy: bool) -> String:
	var line: String = UnitVoice.ORDER_LINE.get(payload.get("type"), "")
	if busy or line.is_empty(): return ""
	for id: int in UnitVoice.speakers(payload):
		var i: int = _rows.index_of(id)
		if i == -1 or _rows.owner[i] != _local_player: continue
		var role: String = UnitVoice.role(_rows.kinds[_rows.kind[i]])
		if line in UnitVoice.LINES[role]: return UnitVoice.path(role, line, _rng.randi_range(1, UnitVoice.VARIANTS))
	return ""

func reset() -> void:
	_pending.clear()
	_queued.clear()
	_consumed.clear()
	_last_shot.clear()
	announcer.clear()
	_funds_rejected = false
	_was_low_power = false
	_previous = {}
	_previous_rows = ViewRows.new()
	_rows = ViewRows.new()
	_previous_status = ""
	_has_previous = false
	_last_collected = -1

func _records(state: Dictionary) -> Dictionary:
	var records: Dictionary = {}
	for building: Dictionary in state.get("buildings", []):
		var footprint: Vector2i = Registry.kind(building.kind).get("footprint", Vector2i.ONE)
		records[building.id] = {"kind": building.kind, "owner": building.owner, "position": Vector2(building.origin[0], building.origin[1]) + Vector2(footprint) / 2.0, "tier": 0, "building": true, "completed": building.get("completed", true), "hole": building.has("rebuild"), "site": building.has("hole_id"), "queue": building.get("queue", [])}
	return records

func _lookup(id: int, current: Dictionary) -> Dictionary:
	if current.has(id): return current[id]
	var unit: Dictionary = _unit_record(_rows, id)
	if not unit.is_empty(): return unit
	if _previous.has(id): return _previous[id]
	return _unit_record(_previous_rows, id)

# The kind is read through the rows' own table: its indices differ between ticks.
func _unit_record(rows: RefCounted, id: int) -> Dictionary:
	var i: int = rows.index_of(id)
	if i == -1: return {}
	return {"kind": rows.kinds[rows.kind[i]], "owner": rows.owner[i], "position": Vector2(rows.x[i], rows.y[i]), "tier": rows.tier[i], "building": false, "completed": true, "hole": false, "site": false, "queue": []}

func _consume(step: Dictionary, current: Dictionary, requests: Array[Dictionary]) -> void:
	for event: Dictionary in step.events:
		if event.type == "shot": _shot(event, current, requests)
		elif event.type == "death": _death(event, current, requests)
	for result: Dictionary in step.results:
		if result.player != _local_player or result.ok: continue
		if result.error == FUNDS_ERROR: announcer.request("insufficient_funds", result.tick)
		else: requests.append(ui_request("error"))

func _own_base(id: int, current: Dictionary) -> bool:
	var record: Dictionary = _lookup(id, current)
	return not record.is_empty() and record.building and record.owner == _local_player and not record.hole

func _shot(event: Dictionary, current: Dictionary, requests: Array[Dictionary]) -> void:
	if _own_base(event.target_id, current): announcer.request("base_under_attack", event.tick)
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
	if _own_base(event.object_id, current): announcer.request("building_lost", event.tick)
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

func _team_of(state: Dictionary, player: int) -> Variant:
	for row: Dictionary in state.get("players", []):
		if row.id == player: return row.team
	return null

func _low_power(state: Dictionary) -> bool:
	for row: Dictionary in state.get("players", []):
		if row.id == _local_player: return row.power_demand > row.power_supply
	return false

func _triggers(state: Dictionary, current: Dictionary, status: String) -> void:
	if status != "ongoing" and not (status == "won" and _previous_status == "ongoing"): return
	var tick: int = state.get("tick", 0)
	if status == "won":
		announcer.clear()
		announcer.request("victory" if state.match.winner == _team_of(state, _local_player) else "defeat", tick)
		return
	if _previous_status != "ongoing": return
	if _low_power(state) and not _was_low_power: announcer.request("low_power", tick)
	for id: Variant in current:
		var record: Dictionary = current[id]
		if not record.building or record.owner != _local_player or not _previous.has(id): continue
		var before: Dictionary = _previous[id]
		if record.completed and not before.completed: announcer.request("construction_complete", tick)
		if _unit_ready(before, record): announcer.request("unit_ready", tick)

func _unit_ready(before: Dictionary, record: Dictionary) -> bool:
	if before.queue.is_empty(): return false
	var head: Dictionary = before.queue[0]
	for entry: Dictionary in record.queue:
		if entry.id == head.id: return false
	for i: int in _rows.size():
		if _rows.owner[i] == _local_player and _rows.kinds[_rows.kind[i]] == head.kind and _previous_rows.index_of(_rows.id[i]) == -1: return true
	return false
