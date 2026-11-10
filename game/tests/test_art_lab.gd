@warning_ignore_start("untyped_declaration")
extends RefCounted

const View = preload("res://scripts/presentation/world_view.gd")
const Fight = preload("res://scripts/lab/lab_fight.gd")
const AbVariants = preload("res://scripts/lab/ab_variants.gd")
const AbOverlay = preload("res://scripts/lab/ab_overlay.gd")
const WorldBatch = preload("res://scripts/presentation/world_batch.gd")
const Shapes = preload("res://scripts/presentation/shapes.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const SCENE = preload("res://scenes/art_lab.tscn")

static func _ids() -> Array[int]:
	return []

static func _events() -> Array[Dictionary]:
	return []

func cases() -> Array[Callable]:
	return [test_lab_fight_shows_every_state, test_every_variant_draws, test_b_variants_change_the_picture, test_events_drive_the_effects, test_lab_keys_and_no_match_keys, test_palette_and_shape_choices, test_rejected_variants_leave_no_shape_hooks]

class BodySpyView extends View:
	var body_draws: int = 0

	func draw_bodies() -> void:
		body_draws += 1
		super()

func test_lab_fight_shows_every_state(runner) -> bool:
	var fight = Fight.new()
	var state: Dictionary = fight.simulation.snapshot()
	for owner in [1, 2]:
		for kind in Fight.LISTED_KINDS:
			var on_screen: bool = state.entities.any(func(unit: Dictionary) -> bool: return unit.owner == owner and unit.kind == kind and Vector2(unit.position[0], unit.position[1]).distance_to(Fight.FOCUS) < 12.0)
			runner.check(on_screen, "AB1 owner %d has a %s on screen at the start" % [owner, kind])
	var seen := {"shot": false, "death": false, "stage1": false, "stage2": false, "construction": false, "pickup": false}
	for tick in 1800:
		fight.step()
		for event in fight.simulation.combat_events():
			if event.type == "shot": seen.shot = true
			if event.type == "death": seen.death = true
		state = fight.simulation.snapshot()
		for building: Dictionary in state.buildings:
			if not building.completed: seen.construction = true
			var stage: int = WorldBatch.damage_stage(building.hp, building.max_hp)
			if stage == 1: seen.stage1 = true
			if stage == 2: seen.stage2 = true
		for unit: Dictionary in state.entities:
			if unit.collection != null and unit.collection.cargo > 0: seen.pickup = true
	for key: String in seen: runner.check(seen[key], "AB1 the 60 s fight shows %s" % key)
	return true

func _drawn_tree(runner) -> Array:
	var view = BodySpyView.new()
	var camera := Camera2D.new()
	var ground := AbOverlay.new()
	var top := AbOverlay.new()
	var variants := AbVariants.new()
	ground.variants = variants
	top.variants = variants
	top.on_top = true
	runner.root.add_child(view)
	view.add_child(ground)
	view.add_child(top)
	runner.root.add_child(camera)
	return [view, camera, variants]

func _free_tree(parts: Array) -> void:
	for node in parts.slice(0, 2): node.free()

func test_every_variant_draws(runner) -> bool:
	var fight = Fight.new()
	for tick in 60: fight.step()
	var parts := _drawn_tree(runner)
	var view = parts[0]
	var variants = parts[2]
	for question in AbVariants.QUESTIONS:
		variants.focus = question
		for choice in variants.variant_count(question):
			for quality in [GraphicsSettings.LOW, GraphicsSettings.HIGH]:
				var label := "%s %s %s" % [question, "ABCDEF"[choice], "High" if quality == GraphicsSettings.HIGH else "Low"]
				variants.set_variant(question, choice)
				fight.step()
				var state: Dictionary = fight.simulation.snapshot()
				variants.observe(state, WorldBatch.objects(state), fight.simulation.combat_events())
				variants.apply(view, parts[1])
				view.set_quality(quality)
				view.set_state(state, _ids())
				var before: int = view.body_draws
				await runner.process_frame
				runner.check(view.body_draws == before + 1, "AB2 %s: one body submission per frame, got %d" % [label, view.body_draws - before])
				runner.check(view._batch.triangle_count > 0 and view._batch.points.size() == view._batch.colors.size(), "AB2 %s: triangles drawn" % label)
		variants.set_variant(question, 0)
	_free_tree(parts)
	return true

func _picture(fight, question: StringName, choice: int) -> Array:
	var parts := _drawn_tree_headless()
	var variants = parts[1]
	variants.set_variant(question, choice)
	variants.focus = question
	var state: Dictionary = fight.simulation.snapshot()
	variants.observe(state, WorldBatch.objects(state), _events())
	variants.apply(parts[0], parts[2])
	parts[0].set_state(state, _ids())
	var batch = parts[0]._batch
	var ground: Color = parts[0]._terrain._colors.ground
	parts[0].free()
	parts[2].free()
	return [hash(batch.points), hash(batch.colors), batch.triangle_count, ground]

func _drawn_tree_headless() -> Array:
	return [View.new(), AbVariants.new(), Camera2D.new()]

func test_b_variants_change_the_picture(runner) -> bool:
	var fight = Fight.new()
	for tick in 40: fight.step()
	for question in AbVariants.QUESTIONS:
		var a: Array = _picture(fight, question, 0)
		var b: Array = _picture(fight, question, 1)
		if question == &"sand_tone":
			var last: Array = _picture(fight, question, 5)
			runner.check(a[3] == Color("7b7566") and b[3] == Color("8a7d62") and last[3] == Color("c4a568"), "AB3 sand_tone steps 1, 2 and 6 set their ground")
			continue
		match question:
			&"owner_palette": runner.check(a[1] != b[1], "AB3 owner_palette B changes the colours")
			&"biome": runner.check(a[3] == Palette.ground(Palette.DEFAULT_BIOME).ground and b[3] == Palette.ground(0).ground, "AB3 biome A is the game's sand and B the dark ground")
			_: runner.check(a.slice(0, 3) == b.slice(0, 3), "AB3 %s changes nothing in the batch itself" % question)
	return true

func _duel_tick(variants, sim, events: Array[Dictionary]) -> void:
	var state: Dictionary = sim.snapshot()
	state.tick = variants._tick + 1
	variants.observe(state, WorldBatch.objects(state), events)

func test_events_drive_the_effects(runner) -> bool:
	var sim = Fixture.make_world()
	var attacker: int = sim.spawn(1, Vector2(8.5, 8.5), "usa_tank")
	var target: int = sim.spawn(1, Vector2(12.5, 8.5), "usa_tank")
	var shot: Array[Dictionary] = [{"type": "shot", "tick": 1, "attacker_id": attacker, "target_id": target, "damage": 1, "splash": false}]
	var death: Array[Dictionary] = [{"type": "death", "tick": 1, "object_id": target}]
	var none: Array[Dictionary] = []
	for choice in 2:
		var variants = AbVariants.new()
		for question in [&"hit_flash", &"signature", &"shake", &"wrecks"]: variants.set_variant(question, choice)
		_duel_tick(variants, sim, shot)
		_duel_tick(variants, sim, death)
		runner.check(variants.active_flashes().size() == choice, "AB6 flashes only in B (%d)" % choice)
		runner.check(variants.active_signatures().size() == choice, "AB6 the signature effect only in B")
		runner.check((variants.shake_offset() != Vector2.ZERO) == (choice == 1), "AB6 shake only in B")
		runner.check(variants.active_wrecks().size() == 1, "AB6 a dead tank leaves a wreck in both")
		for i in 12: _duel_tick(variants, sim, none)
		runner.check(variants.shake_offset() == Vector2.ZERO, "AB6 shake ends within 12 ticks")
		for i in 100: _duel_tick(variants, sim, none)
		runner.check(variants.active_wrecks().size() == 1 - choice, "AB6 the B wreck is gone after 3 s, the A wreck stays (%d)" % choice)
	return true

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event

func test_lab_keys_and_no_match_keys(runner) -> bool:
	var lab = SCENE.instantiate()
	runner.root.add_child(lab)
	await runner.process_frame
	for i in 5: lab.advance()
	var before := [lab.question_index, lab.variants.variant(&"biome"), lab.quality, lab.zoom_index, lab.variants.opponent_owner, lab.paused]
	for code in [KEY_A, KEY_S, KEY_B, KEY_1, KEY_2]: lab._unhandled_input(_key(code))
	runner.check([lab.question_index, lab.variants.variant(&"biome"), lab.quality, lab.zoom_index, lab.variants.opponent_owner, lab.paused] == before, "AB7 the match keys A, S, B, 1 do nothing in the lab")
	lab._unhandled_input(_key(KEY_TAB))
	runner.check(lab.variants.is_b(&"biome"), "AB7 Tab switches to B")
	lab._unhandled_input(_key(KEY_PAGEDOWN))
	runner.check(lab.current_question() == &"fog", "AB7 PageDown steps to the next question")
	lab._unhandled_input(_key(KEY_PAGEUP))
	lab._unhandled_input(_key(KEY_PAGEUP))
	runner.check(lab.current_question() == AbVariants.QUESTIONS[-1], "AB7 PageUp wraps to the last question")
	lab._unhandled_input(_key(KEY_Q))
	lab._unhandled_input(_key(KEY_Z))
	runner.check(lab.quality == GraphicsSettings.LOW and lab.zoom_index == 2, "AB7 Q and Z change quality and zoom")
	var text: String = lab.status_text()
	runner.check(text.contains("sand_tone") and text.contains("step 1/6 #7B7566") and text.contains("Low") and text.contains("zoom 2") and text.contains("variant A"), "AB7 the HUD names question, variant, quality and zoom: %s" % text.get_slice("\n", 0))
	for i in 6: lab._unhandled_input(_key(KEY_TAB))
	runner.check(lab.variants.variant(&"sand_tone") == 0, "AB7 Tab cycles six sand steps and wraps")
	for i in 7: lab._unhandled_input(_key(KEY_O))
	runner.check(lab.variants.opponent_owner == 2, "AB7 O cycles the opponent colour 2..8 and back")
	lab._unhandled_input(_key(KEY_O))
	runner.check(lab.variants.opponent_owner == 3, "AB7 O steps to the next colour")
	lab._unhandled_input(_key(KEY_SPACE))
	runner.check(lab.paused, "AB7 Space pauses")
	lab.free()
	return true

func test_palette_and_shape_choices(runner) -> bool:
	var warm: Dictionary = Palette.ground(0)
	runner.check(_distance(warm.ground, warm.cliff_top) > 0.1 and _distance(warm.ground, warm.cliff_side) > 0.25, "AB8 the dark ground keeps its cliffs readable")
	for i in Palette.OWNER_BRIGHT.size():
		for j in range(i + 1, Palette.OWNER_BRIGHT.size()):
			runner.check(_distance(Palette.OWNER_BRIGHT[i], Palette.OWNER_BRIGHT[j]) > 0.25, "AB8 bright owners %d and %d are distinguishable" % [i + 1, j + 1])
		for other: Color in [Palette.HEALTH_GREEN, Palette.HEALTH_YELLOW, Palette.HEALTH_RED, Palette.NEUTRAL]:
			runner.check(_distance(Palette.OWNER_BRIGHT[i], other) > 0.12, "AB8 bright owner %d stays apart from %s" % [i + 1, other.to_html(false)])
	return true

func test_rejected_variants_leave_no_shape_hooks(runner) -> bool:
	for role in [&"tank_usa", &"light_vehicle"]:
		for bit in [1, 8]:
			runner.check(Shapes.parts(role, 1, bit)[0].prims == Shapes.parts(role, 1)[0].prims and Shapes.parts(role, 1, bit).size() == Shapes.parts(role, 1).size() and Shapes.parts(role, 1, bit)[-1].prims == Shapes.parts(role, 1)[-1].prims, "AB10 variant bit %d does nothing to %s" % [bit, role])
	return true

func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
