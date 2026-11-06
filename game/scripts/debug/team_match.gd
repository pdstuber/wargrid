extends RefCounted

const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")

const MAP_PATH := "res://data/maps/ashfall.json"
const TEAM_TICK_CAP: int = 27000
const SEATS: Array[Dictionary] = [
	{"seat": 1, "team": 1}, {"seat": 2, "team": 1}, {"seat": 8, "team": 1},
	{"seat": 4, "team": 2}, {"seat": 5, "team": 2}, {"seat": 6, "team": 2}]

static func create() -> RefCounted:
	var seats: Array[Dictionary] = []
	var ids: Array[int] = []
	for entry in SEATS:
		seats.append({"seat": entry.seat, "team": entry.team, "controller": "ai", "credits": Skirmish.START_CREDITS})
		ids.append(entry.seat)
	var sim: RefCounted = MapData.create(MapData.load(MAP_PATH), seats)
	sim.start_match(ids)
	return sim

static func step(sim: RefCounted) -> void:
	var seats: Array[int] = []
	for entry in SEATS: seats.append(entry.seat)
	Skirmish.issue_opponents(sim, seats)
	sim.step()
