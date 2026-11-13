@warning_ignore_start("untyped_declaration")
extends RefCounted

const Director = preload("res://scripts/presentation/sound_director.gd")
const UnitVoice = preload("res://scripts/presentation/unit_voice.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const ViewRows = preload("res://scripts/simulation/view_rows.gd")
const FocusCards = preload("res://scripts/playtest/focus_cards.gd")

const EXPECTED_ROLES := {"usa_builder": "worker", "usa_collector": "worker", "china_builder": "worker", "china_collector": "worker", "frc_builder": "worker", "usa_rifle_infantry": "infantry", "usa_rocket_infantry": "infantry", "china_rifle_infantry": "infantry", "china_rocket_infantry": "infantry", "frc_rifle_infantry": "infantry", "frc_rocket_infantry": "infantry", "usa_light_vehicle": "vehicle", "usa_tank": "vehicle", "china_light_vehicle": "vehicle", "china_tank": "vehicle", "frc_light_vehicle": "vehicle", "frc_tank": "vehicle"}
const SILENT := ["stop", "set_rally", "produce", "cancel_build", "cancel_production", "defence_attack"]
const PREFIX := "res://audio/voice/units/"

func cases() -> Array[Callable]:
	return [test_order_roles_cover_every_unit, test_order_line_per_command, test_first_unit_with_a_line_speaks, test_order_voice_skips_while_busy, test_order_variant_is_presentation_random]

func _unit(id: int, kind: String, owner: int) -> Dictionary:
	return {"id": id, "owner": owner, "kind": kind, "position": [float(id), 1.0], "combat": {"tier": 0}}

func _director(seed_value: int = 1) -> Director:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var director := Director.new(1, rng)
	var units: Array = [_unit(1, "usa_builder", 1), _unit(2, "usa_rifle_infantry", 1), _unit(3, "usa_tank", 1), _unit(4, "china_tank", 2), _unit(5, "frc_light_vehicle", 1)]
	director.update({"units": ViewRows.from_units(units), "buildings": [], "match": {"status": "ongoing"}})
	return director

func _order(type: String, ids: Array) -> Dictionary:
	return {"type": type, "entity_ids": ids}

func test_order_roles_cover_every_unit(runner) -> bool:
	var found: Array = Registry.units()
	var expected: Array = EXPECTED_ROLES.keys()
	found.sort()
	expected.sort()
	runner.check(found == expected, "OV1 every unit kind has a role row, got %s" % [found])
	for kind: String in EXPECTED_ROLES:
		runner.check(UnitVoice.role(kind) == EXPECTED_ROLES[kind], "OV1 %s speaks as %s, got %s" % [kind, EXPECTED_ROLES[kind], UnitVoice.role(kind)])
	return true

func test_order_line_per_command(runner) -> bool:
	var expected := {"move": "move", "enter": "move", "unload": "move", "attack": "attack", "attack_move": "attack", "gather": "work", "build": "work", "resume_build": "work"}
	runner.check(UnitVoice.ORDER_LINE == expected, "OV2 order lines are %s" % [UnitVoice.ORDER_LINE])
	var covered: Array = UnitVoice.ORDER_LINE.keys() + SILENT
	var types: Array = FocusCards.COMMAND_TYPES.duplicate()
	covered.sort()
	types.sort()
	runner.check(covered == types, "OV2 every command type is voiced or silent, got %s" % [covered])
	var director = _director()
	for type: String in SILENT:
		runner.check(director.order_voice(_order(type, [2]), false) == "", "OV2 %s stays silent" % type)
	return true

func test_first_unit_with_a_line_speaks(runner) -> bool:
	var director = _director()
	var spoken := [
		[_order("attack", [1, 2, 3]), "infantry_attack_"], [_order("gather", [2, 1]), "worker_work_"],
		[_order("move", [3, 1]), "vehicle_move_"], [_order("enter", [2]), "infantry_move_"],
		[{"type": "build", "builder_id": 1}, "worker_work_"], [{"type": "resume_build", "builder_id": 1}, "worker_work_"],
		[{"type": "unload", "target_id": 5}, "vehicle_move_"],
	]
	for row: Array in spoken:
		var voice: String = director.order_voice(row[0], false)
		runner.check(voice.begins_with(PREFIX + row[1]), "OV3 %s gives %s, got '%s'" % [row[0].type, row[1], voice])
	var silent := [_order("attack", [1]), _order("move", [4]), _order("move", [99]), {"type": "unload", "target_id": 99}]
	for payload: Dictionary in silent:
		runner.check(director.order_voice(payload, false) == "", "OV3 %s %s stays silent" % [payload.type, payload])
	return true

func test_order_voice_skips_while_busy(runner) -> bool:
	var busy = _director()
	runner.check(busy.order_voice(_order("move", [2]), true) == "", "OV4 busy order is skipped")
	var fresh = _director()
	runner.check(busy.order_voice(_order("move", [2]), false) != "", "OV4 order after a skip speaks")
	var skipped_then: String = busy.order_voice(_order("move", [2]), false)
	fresh.order_voice(_order("move", [2]), false)
	runner.check(skipped_then == fresh.order_voice(_order("move", [2]), false), "OV4 a skipped order spent a random number")
	return true

func _twenty(director) -> Array:
	var paths: Array = []
	for i in 20: paths.append(director.order_voice(_order("move", [2]), false))
	return paths

func test_order_variant_is_presentation_random(runner) -> bool:
	var first: Array = _twenty(_director())
	var allowed := [PREFIX + "infantry_move_1.wav", PREFIX + "infantry_move_2.wav"]
	for path: String in first: runner.check(path in allowed, "OV5 variant path %s is one of the two" % path)
	runner.check(allowed[0] in first and allowed[1] in first, "OV5 both variants occur in 20 calls")
	runner.check(first == _twenty(_director()), "OV5 same seed gives the same variants")
	return true
