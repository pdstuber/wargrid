extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")

static func load(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Map file unreadable: " + path)
		return {}
	var map := parse(file.get_as_text())
	if map.is_empty(): push_error("Map file invalid: " + path)
	return map

static func parse(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if parsed is not Dictionary or not _valid(parsed): return {}
	return parsed

static func slot(map: Dictionary, seat: int, kind: String) -> Vector2i:
	for start: Dictionary in map.starts:
		if int(start.seat) == seat: return _cell(start.slots[Registry.kind(kind).slot])
	return Vector2i(-1, -1)

static func start_cell(map: Dictionary, seat: int) -> Vector2i:
	for start: Dictionary in map.starts:
		if int(start.seat) == seat: return _cell(start.cell)
	return Vector2i(-1, -1)

static func blocked_cells(map: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in map.cells.size():
		var row: String = map.cells[y]
		for x in row.length():
			if row[x] != ".": cells.append(Vector2i(x, y))
	return cells

static func create(map: Dictionary, seats: Array[Dictionary]) -> Simulation:
	var sim: Simulation = Simulation.new(blocked_cells(map), Vector2i(int(map.size[0]), int(map.size[1])))
	sim._map = map
	for seat in seats: sim.add_player(seat.seat, seat.credits, seat.controller, seat.get("team", 0))
	for seat in seats:
		if seat.has("faction"):
			sim.setup_seat(seat.seat, seat.faction)
			continue
		if seat.get("defer", false): continue
		var cell := start_cell(map, seat.seat)
		sim.spawn(seat.seat, Vector2(cell) + Vector2(0.5, 0.5), Registry.faction(Registry.Factions.DEFAULT_FACTION).start_unit)
	for source: Dictionary in map.sources: sim.add_supply_source(_cell(source.origin), int(source.boxes), Registry.source_footprint(source), source.get("delete_when_empty", false))
	return sim

static func _cell(pair: Array) -> Vector2i:
	return Vector2i(int(pair[0]), int(pair[1]))

static func _valid(map: Dictionary) -> bool:
	for key: String in ["name", "notice", "size", "cells", "starts", "sources"]:
		if not map.has(key): return false
	if map.size is not Array or map.size.size() != 2: return false
	var size := Vector2i(int(map.size[0]), int(map.size[1]))
	if size.x <= 0 or size.y <= 0 or map.cells is not Array or map.cells.size() != size.y: return false
	for row: Variant in map.cells:
		if row is not String or row.length() != size.x: return false
	for start: Variant in map.starts:
		if not _start_valid(map, start, size): return false
	for source: Variant in map.sources:
		if not _source_valid(map, size, source): return false
	return true

static func _source_valid(map: Dictionary, size: Vector2i, source: Variant) -> bool:
	if source is not Dictionary or source.get("origin") is not Array or source.origin.size() != 2: return false
	if source.has("delete_when_empty") and source.delete_when_empty is not bool: return false
	if source.has("footprint") and not _footprint_valid(source.footprint): return false
	return _open(map, size, _cell(source.origin), Registry.source_footprint(source))

static func _footprint_valid(footprint: Variant) -> bool:
	if footprint is not Array or footprint.size() != 2: return false
	for side: Variant in footprint:
		if (side is not float and side is not int) or side < 1 or side != floorf(side): return false
	return true

static func _start_valid(map: Dictionary, start: Dictionary, size: Vector2i) -> bool:
	if not _open(map, size, _cell(start.cell), Vector2i.ONE): return false
	for kind: String in Registry.buildings():
		var slot_key: String = Registry.kind(kind).get("slot", "")
		if slot_key.is_empty(): continue
		if not start.slots.has(slot_key) or not _open(map, size, _cell(start.slots[slot_key]), Definitions.building(kind).footprint): return false
	return true

static func _open(map: Dictionary, size: Vector2i, origin: Vector2i, footprint: Vector2i) -> bool:
	if origin.x < 0 or origin.y < 0 or origin.x + footprint.x > size.x or origin.y + footprint.y > size.y: return false
	for y in range(origin.y, origin.y + footprint.y):
		for x in range(origin.x, origin.x + footprint.x):
			if map.cells[y][x] != ".": return false
	return true
