@warning_ignore_start("untyped_declaration")
extends RefCounted

const MapData = preload("res://scripts/simulation/map_data.gd")
const StartSpots = preload("res://scripts/simulation/start_spots.gd")

const SS6_PINNED := "8-4,2-6,3-7,5-1,6-2,2-6,7-3,4-8,1-5,3-7,2-6,6-2,6-2,8-4,6-2,5-1"

func cases() -> Array[Callable]:
	return [test_first_random, test_farthest, test_summed, test_teammates, test_chosen, test_pinned, test_ties]

func _ashfall() -> Dictionary:
	return MapData.load("res://data/maps/ashfall.json")

func _square() -> Dictionary:
	var starts: Array = []
	for cell: Array in [[0, 0], [10, 0], [10, 10], [0, 10]]:
		starts.append({"seat": float(starts.size() + 1), "cell": cell})
	return {"starts": starts}

func _ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	for value: Variant in values: out.append(int(value))
	return out

func test_first_random(runner) -> bool:
	var map := _ashfall()
	var seen := {}
	var repeat := true
	for s in 256:
		var a := StartSpots.assign(map, s, _ints([1, 2]), _ints([0, 0]))
		seen[a[0]] = true
		repeat = repeat and a == StartSpots.assign(map, s, _ints([1, 2]), _ints([0, 0]))
	runner.check(seen.size() == 8 and repeat, "SS1 the first random slot gets a random start from the seed")
	return true

func test_farthest(runner) -> bool:
	var tables := {"ashfall": {1: 5, 2: 6, 3: 7, 4: 8, 5: 1, 6: 2, 7: 3, 8: 4}, "broken_crown": {1: 3, 2: 4, 3: 1, 4: 2}, "dry_wells": {1: 2, 2: 1}}
	var ok := true
	for id: String in tables:
		var map := MapData.load("res://data/maps/%s.json" % id)
		for s in 256:
			var a := StartSpots.assign(map, s, _ints([1, 2]), _ints([0, 0]))
			ok = ok and a[1] == tables[id][a[0]]
	runner.check(ok, "SS2 each later one the free start with the largest summed straight-line distance to the taken ones")
	return true

func test_summed(runner) -> bool:
	var ok := true
	for s in 32: ok = ok and StartSpots.assign(_ashfall(), s, _ints([1, 2, 3]), _ints([1, 0, 0])) == _ints([1, 5, 7])
	runner.check(ok, "SS3 summed distance over all taken starts")
	return true

func test_teammates(runner) -> bool:
	var rows := {1: [1, 8, 5, 4], 2: [2, 3, 7, 6], 3: [3, 2, 7, 6], 4: [4, 5, 8, 1], 5: [5, 4, 8, 1], 6: [6, 7, 2, 3], 7: [7, 6, 2, 3], 8: [8, 1, 5, 4]}
	var map := _ashfall()
	var ok := true
	for s in 256:
		var a := StartSpots.assign(map, s, _ints([1, 1, 2, 2]), _ints([0, 0, 0, 0]))
		ok = ok and a == _ints(rows[a[0]])
	runner.check(ok, "SS4 teammates take the free start closest to their team")
	return true

func test_chosen(runner) -> bool:
	var ok := true
	for s in 32: ok = ok and StartSpots.assign(_ashfall(), s, _ints([1, 2]), _ints([0, 3])) == _ints([7, 3])
	runner.check(ok, "SS5 chosen spots are taken first")
	return true

func test_pinned(runner) -> bool:
	var parts: PackedStringArray = []
	for s in 16:
		var a := StartSpots.assign(_ashfall(), s, _ints([1, 2]), _ints([0, 0]))
		parts.append("%d-%d" % [a[0], a[1]])
	runner.check(",".join(parts) == SS6_PINNED, "SS6 seeded start spots are pinned across platforms: " + ",".join(parts))
	return true

func test_ties(runner) -> bool:
	var map := _square()
	var near := {1: 2, 2: 1, 3: 2, 4: 1}
	var ok := true
	for s in 64:
		var a := StartSpots.assign(map, s, _ints([1, 1]), _ints([0, 0]))
		ok = ok and a[1] == near[a[0]]
	runner.check(ok, "SS7 ties go to the lowest seat")
	runner.check(StartSpots.assign(map, 0, _ints([0, 0, 0]), _ints([1, 0, 0])) == _ints([1, 3, 2]), "SS7 summed tie goes to the lowest seat")
	runner.check(StartSpots.assign(map, 0, _ints([1, 1]), _ints([1, 0])) == _ints([1, 3]), "SS7 a chosen spot is not its team's position")
	return true
