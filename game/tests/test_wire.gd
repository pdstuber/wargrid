@warning_ignore_start("untyped_declaration")
extends RefCounted

const Wire = preload("res://scripts/net/wire.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const COMMAND_TYPES: Array[String] = ["move", "stop", "build", "resume_build", "cancel_build", "produce", "cancel_production", "set_rally", "gather", "attack", "attack_move", "choose_faction"]

func cases() -> Array[Callable]:
	return [test_round_trip_every_command, test_decode_rejects, test_vectors, test_command_list_matches_simulation]

func _command(type: String, sim: RefCounted) -> Dictionary:
	var command := {"tick": 12, "player": 2, "sequence": 7, "type": type}
	for key in sim._payload_fields(type):
		match key:
			"entity_ids": command[key] = [1, 2, 300]
			"target": command[key] = [14.1, 0.30000000000000004]
			"origin": command[key] = [5, 6]
			"building_kind", "unit_kind": command[key] = "usa_factory"
			"faction": command[key] = "usa"
			_: command[key] = 9
	return command

func test_command_list_matches_simulation(runner) -> bool:
	var sim = Simulation.new()
	for type in COMMAND_TYPES:
		runner.check(not sim._payload_fields(type).is_empty(), "W0 known command " + type)
	runner.check(sim._payload_fields("bogus").is_empty(), "W0 no extra types")
	return true

func test_round_trip_every_command(runner) -> bool:
	var sim = Simulation.new()
	for type in COMMAND_TYPES:
		var message: Dictionary = Wire.tick_message(2, 12, [_command(type, sim)], {"tick": 30, "value": "0123456789abcdef"})
		var decoded: Dictionary = Wire.decode(Wire.encode(message))
		runner.check(decoded.ok and decoded.message == message, "W1 round trip " + type)
		if not decoded.ok: continue
		var command: Dictionary = decoded.message.commands[0]
		for key in ["tick", "player", "sequence"]:
			runner.check(typeof(command[key]) == TYPE_INT, "W1 %s.%s is int" % [type, key])
		runner.check(typeof(decoded.message.seat) == TYPE_INT and typeof(decoded.message.hash.tick) == TYPE_INT, "W1 header ints " + type)
		for key in sim._payload_fields(type):
			if key == "target":
				runner.check(typeof(command.target[0]) == TYPE_FLOAT and command.target[1] == 0.30000000000000004, "W1 target stays float exact")
			elif key.ends_with("_id"):
				runner.check(typeof(command[key]) == TYPE_INT, "W1 %s.%s is int" % [type, key])
			elif key == "entity_ids" or key == "origin":
				for value in command[key]: runner.check(typeof(value) == TYPE_INT, "W1 %s.%s[] is int" % [type, key])
	var no_hash: Dictionary = Wire.tick_message(1, 4, [], null)
	runner.check(not no_hash.has("hash") and Wire.decode(Wire.encode(no_hash)).ok, "W1 hash key omitted when null")
	return true

func test_decode_rejects(runner) -> bool:
	var long_text: String = '{"type":"ping","t":1,"pad":"' + "x".repeat(65536) + '"}'
	var bad := {
		"fractional tick": '{"type":"tick","seat":1,"tick":3.5,"commands":[]}',
		"missing type": '{"seat":1}',
		"not object": '[1]',
		"not json": 'nope',
		"string entity id": '{"type":"tick","seat":1,"tick":1,"commands":[{"type":"stop","entity_ids":["1"]}]}',
		"fractional command int": '{"type":"tick","seat":1,"tick":1,"commands":[{"type":"stop","sequence":1.5}]}',
		"bad hash value": '{"type":"tick","seat":1,"tick":1,"commands":[],"hash":{"tick":30,"value":"XYZ"}}',
		"missing field": '{"type":"welcome","seat":1}',
		"oversize": long_text,
		"huge integer": '{"type":"ping","t":1e300}',
		"non-string reason": '{"type":"error","reason":5}',
	}
	for name in bad:
		var decoded: Dictionary = Wire.decode(bad[name])
		runner.check(not decoded.ok and not decoded.error.is_empty(), "W2 rejects " + name)
	return true

func test_vectors(runner) -> bool:
	# Exports have no ../protocol next to res://, so CI points the exported suite at the checkout.
	var dir: String = OS.get_environment("WARGRID_VECTORS") if OS.has_environment("WARGRID_VECTORS") else ProjectSettings.globalize_path("res://").path_join("../protocol/vectors")
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	runner.check(files.size() >= 12, "W3 vector files found")
	for file in files:
		var vector: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(file)))
		runner.check(vector is Dictionary and vector.has("text"), "W3 vector parses " + file)
		if vector is not Dictionary: continue
		var decoded: Dictionary = Wire.decode(vector.text)
		if vector.get("valid", true):
			runner.check(decoded.ok and _same(decoded.message, vector.message), "W3 vector decodes " + file)
			if decoded.ok:
				for key in Wire._INT_FIELDS.get(decoded.message.type, []):
					runner.check(typeof(decoded.message[key]) == TYPE_INT, "W3 %s.%s is int" % [file, key])
				if decoded.message.type == "start":
					for seat in decoded.message.seats: runner.check(typeof(seat) == TYPE_INT, "W3 start seats are int")
		else:
			runner.check(not decoded.ok, "W3 vector invalid " + file)
	return true

func _same(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _same(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not _same(a[i], b[i]): return false
		return true
	return a == b
