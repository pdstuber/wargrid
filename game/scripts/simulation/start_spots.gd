extends RefCounted

static func assign(map: Dictionary, match_seed: int, teams: Array[int], chosen: Array[int]) -> Array[int]:
	var starts: Array = map.starts
	var count := starts.size()
	var taken: Array[bool] = []
	taken.resize(count)
	taken.fill(false)
	var placed: Array[int] = []
	placed.resize(teams.size())
	placed.fill(-1)
	var picked := false
	for k in teams.size():
		var index := _index_of(starts, chosen[k])
		if chosen[k] > 0 and index >= 0:
			placed[k] = index
			taken[index] = true
			picked = true
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed
	var team_spot := {}
	for k in teams.size():
		if placed[k] >= 0: continue
		var team := teams[k]
		var index: int
		if not picked:
			index = rng.randi_range(0, count - 1)
			while taken[index]: index = rng.randi_range(0, count - 1)
			picked = true
			if team > 0: team_spot[team] = index
		elif team > 0 and team_spot.has(team):
			index = _closest(starts, taken, team_spot[team])
		else:
			index = _farthest(starts, taken)
			if team > 0: team_spot[team] = index
		placed[k] = index
		taken[index] = true
	var seats: Array[int] = []
	for index in placed: seats.append(int(starts[index].seat))
	return seats

static func _index_of(starts: Array, seat: int) -> int:
	for i in starts.size():
		if int(starts[i].seat) == seat: return i
	return -1

static func _distance(starts: Array, a: int, b: int) -> float:
	var ca: Array = starts[a].cell
	var cb: Array = starts[b].cell
	var d := Vector2i(int(ca[0]) - int(cb[0]), int(ca[1]) - int(cb[1]))
	return sqrt(float(d.x * d.x + d.y * d.y))

static func _farthest(starts: Array, taken: Array[bool]) -> int:
	var best := -1
	var best_sum := -1.0
	for i in starts.size():
		if taken[i]: continue
		var sum := 0.0
		for j in starts.size():
			if taken[j]: sum += _distance(starts, i, j)
		if sum > best_sum:
			best_sum = sum
			best = i
	return best

static func _closest(starts: Array, taken: Array[bool], anchor: int) -> int:
	var best := -1
	var best_distance := INF
	for i in starts.size():
		if taken[i]: continue
		var d := _distance(starts, i, anchor)
		if d < best_distance:
			best_distance = d
			best = i
	return best
