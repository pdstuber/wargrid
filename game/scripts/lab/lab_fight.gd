extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")

const MAP_SIZE := Vector2i(40, 40)
const FOCUS := Vector2(14.5, 14.5)
const BLOCK_CENTRE := Vector2(11.0, 18.0)
const OWNERS: Array[int] = [1, 2]
const SPACING: float = 1.6
const COLUMNS: int = 6
const ENGAGE_TICK: int = 240
const ASSAULT_TICK: int = 600
const SOURCES := {1: Vector2i(24, 3), 2: Vector2i(3, 24)}
const LISTED_KINDS: Array[String] = [
	"usa_tank", "china_tank", "frc_tank", "usa_light_vehicle", "china_light_vehicle", "frc_light_vehicle",
	"usa_builder", "china_builder", "frc_builder", "usa_rifle_infantry", "china_rifle_infantry", "frc_rifle_infantry",
	"usa_rocket_infantry", "china_rocket_infantry", "frc_rocket_infantry", "usa_collector", "china_collector",
]
const FIGHTERS: Array[String] = ["usa_tank", "china_tank", "frc_tank", "usa_light_vehicle", "china_light_vehicle", "frc_light_vehicle", "usa_rifle_infantry", "china_rifle_infantry", "frc_rifle_infantry", "usa_rocket_infantry", "china_rocket_infantry", "frc_rocket_infantry"]
const WAVE: Array[String] = ["usa_tank", "frc_tank", "china_light_vehicle", "china_tank", "frc_tank"]
const BUILDS := [["usa_builder", "usa_power_plant", [5, 14]], ["china_builder", "china_barracks", [5, 19]]]

var simulation: Simulation = Simulation.new([], MAP_SIZE)
var _sequence := {1: 0, 2: 0}
var _units := {1: {}, 2: {}}
var _gathering := {}

func _init() -> void:
	simulation.add_player(1, 30000)
	simulation.add_player(2, 30000)
	for owner: int in OWNERS:
		_spawn_block(owner)
		_spawn_horde(owner)
		simulation.add_supply_source(SOURCES[owner], 400)
		_order_builds(owner)

# Player 2 is the point reflection of player 1 through FOCUS, so both sides show the same kinds in mirrored places.
static func mirrored(owner: int, point: Vector2) -> Vector2:
	return point if owner == 1 else FOCUS * 2.0 - point

static func mirrored_cell(owner: int, origin: Array, size: int) -> Array:
	return origin if owner == 1 else [int(FOCUS.x * 2.0) - origin[0] - size, int(FOCUS.y * 2.0) - origin[1] - size]

func step() -> void:
	var tick: int = simulation.tick()
	if tick == ENGAGE_TICK:
		for owner: int in OWNERS: _command(owner, {"type": "attack_move", "entity_ids": _fighters(owner), "target": _point_array(mirrored(3 - owner, BLOCK_CENTRE))})
	if tick == ASSAULT_TICK: for owner: int in OWNERS: _launch_assault(owner)
	for owner: int in OWNERS: _order_gather(owner)
	simulation.step()

func unit_ids(owner: int, kind: String) -> Array:
	return _units[owner].get(kind, [])

func _spawn_block(owner: int) -> void:
	var along := Vector2(1, -1).normalized()
	var across := Vector2(1, 1).normalized()
	for i in LISTED_KINDS.size():
		var row: int = floori(i / float(COLUMNS))
		var spot: Vector2 = BLOCK_CENTRE + along * (row * SPACING) + across * ((i % COLUMNS) - 2.5) * SPACING
		_add(owner, LISTED_KINDS[i], mirrored(owner, spot))

func _spawn_horde(owner: int) -> void:
	for i in 9:
		_add(owner, "china_rifle_infantry", mirrored(owner, Vector2(11.5, 11.5) + Vector2(i % 3, floori(i / 3.0))))

func _add(owner: int, kind: String, at: Vector2) -> void:
	var id: int = simulation.spawn(owner, at, kind)
	if id != -1: _units[owner].get_or_add(kind, []).append(id)

func _fighters(owner: int) -> Array:
	var ids: Array = []
	for kind in FIGHTERS: ids.append_array(unit_ids(owner, kind))
	return ids

func _order_builds(owner: int) -> void:
	for entry: Array in BUILDS:
		var builder: Array = unit_ids(owner, entry[0])
		_command(owner, {"type": "build", "builder_id": builder[0], "building_kind": entry[1], "origin": mirrored_cell(owner, entry[2], 2)})

func _launch_assault(owner: int) -> void:
	var wave: Array[int] = []
	for i in WAVE.size():
		var id: int = simulation.spawn(owner, mirrored(owner, Vector2(8.5 + i * 1.5, 24.5)), WAVE[i])
		if id != -1: wave.append(id)
	for building: Dictionary in simulation.snapshot().buildings:
		if building.owner != owner and building.kind == "usa_power_plant": _command(owner, {"type": "attack", "entity_ids": wave, "target_id": building.id})

func _order_gather(owner: int) -> void:
	if _gathering.has(owner): return
	var state: Dictionary = simulation.snapshot()
	var collector: Array = unit_ids(owner, "usa_collector")
	for source: Dictionary in state.sources:
		if Vector2i(source.origin[0], source.origin[1]) == SOURCES[owner] and not collector.is_empty():
			_gathering[owner] = _command(owner, {"type": "gather", "entity_ids": collector, "source_id": source.id})

func _point_array(point: Vector2) -> Array:
	return [point.x, point.y]

func _command(player: int, payload: Dictionary) -> bool:
	var command: Dictionary = payload.duplicate(true)
	command.tick = simulation.tick()
	command.player = player
	command.sequence = _sequence[player]
	var result: Dictionary = simulation.issue_command(command)
	if result.ok: _sequence[player] += 1
	return result.ok
