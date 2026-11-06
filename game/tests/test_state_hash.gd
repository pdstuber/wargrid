@warning_ignore_start("untyped_declaration")
extends RefCounted

const Replay = preload("res://tests/test_replay.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const PINNED: String = "6374674a4bdd4dfb"

func cases() -> Array[Callable]:
	return [test_pinned_digest, test_digest_sensitivity, test_core_check_scope, test_nonfinite_stable]

func _state(runner) -> Dictionary:
	var sim = Replay.new()._world(runner)
	sim.add_player(1, 1000)
	sim.step()
	return sim.snapshot()

func test_pinned_digest(runner) -> bool:
	var digest: String = StateHash.digest(_state(runner))
	runner.check(digest.length() == 16, "H1 digest is 16 hex chars")
	runner.check(digest == PINNED, "H1 pinned digest %s" % digest)
	return true

func test_digest_sensitivity(runner) -> bool:
	var state: Dictionary = _state(runner)
	var base: String = StateHash.digest(state)
	var edits := {
		"id": func(s): s.entities[0].id += 1,
		"owner": func(s): s.entities[0].owner += 1,
		"hp": func(s): s.entities[0].hp -= 1,
		"position": func(s): s.entities[0].position[0] += 1.0 / 1024.0,
		"credits": func(s): s.players[0].credits += 1,
		"route": func(s): s.entities[0].route[0][0] += 0.5,
		"nested event": func(s): s.combat_events.append({"type": "shot", "tick": 1}),
		"1e-12": func(s): s.entities[0].position[0] += 1e-12,
	}
	for name in edits:
		var changed: Dictionary = state.duplicate(true)
		edits[name].call(changed)
		runner.check(StateHash.digest(changed) != base, "H2 digest changes with " + name)
	return true

func test_core_check_scope(runner) -> bool:
	var state: Dictionary = _state(runner)
	var base: int = StateHash.core_check(state)
	for name in ["id", "owner", "hp", "position", "credits"]:
		var changed: Dictionary = state.duplicate(true)
		match name:
			"id": changed.entities[0].id += 1
			"owner": changed.entities[0].owner += 1
			"hp": changed.entities[0].hp -= 1
			"position":
				changed.entities[0].position[1] += 1.0 / 1024.0
				var other: Dictionary = state.duplicate(true)
				other.entities[0].position[0] += 1.0 / 1024.0
				runner.check(StateHash.core_check(other) != base, "H3 core_check covers position x")
			"credits": changed.players[0].credits += 1
		runner.check(StateHash.core_check(changed) != base, "H3 core_check covers " + name)
	var changed: Dictionary = state.duplicate(true)
	changed.entities[0].route[0][0] += 0.5
	runner.check(StateHash.core_check(changed) == base, "H3 core_check ignores route")
	return true

func test_nonfinite_stable(runner) -> bool:
	var a: Dictionary = _state(runner)
	var b: Dictionary = a.duplicate(true)
	a.entities[0].position[0] = NAN
	b.entities[0].position[0] = INF
	runner.check(StateHash.core_check(a) == StateHash.core_check(b), "H4 NaN and inf hash alike")
	return true
