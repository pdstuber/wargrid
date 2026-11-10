@warning_ignore_start("untyped_declaration")
extends RefCounted

const View = preload("res://scripts/presentation/world_view.gd")
const Terrain = preload("res://scripts/presentation/terrain_view.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const Shapes = preload("res://scripts/presentation/shapes.gd")
const WorldBatch = preload("res://scripts/presentation/world_batch.gd")
const Director = preload("res://scripts/presentation/visual_director.gd")
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Skirmish = preload("res://scenes/skirmish.tscn")
const Base = preload("res://scenes/base.tscn")
const TICK_USEC: int = 33333
var scratch: String = "user://test-winners-%d.cfg" % OS.get_process_id()

func cases() -> Array[Callable]:
	return [test_sand_and_dark_palettes, test_scenes_apply_the_default_biome, test_ground_is_built_once, test_blend_between_ticks, test_overlays_and_picks_follow_the_drawn_pose, test_stall_holds_and_does_not_rebuild, test_catch_up_and_restart_snap, test_same_tick_refresh_keeps_the_pose, test_heading_wraps, test_low_never_blends, test_blend_leaves_effects_alone, test_infantry_colour_default, test_horde_ring_in_the_batch, test_wide_infantry_pick_default, test_pivot_roles_pick_extent_covers_every_pose, test_shot_dash, test_neon_setting, test_neon_menu_and_wiring, test_neon_reaches_structures_and_rings]

func _begin() -> String:
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	return saved

func _end(saved: String) -> void:
	DirAccess.remove_absolute(scratch)
	AudioSettings.path = saved

func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

func test_sand_and_dark_palettes(runner) -> bool:
	var sand: Dictionary = Palette.ground(Palette.DEFAULT_BIOME)
	runner.check(Palette.DEFAULT_BIOME != 0, "W1 the default biome is not the dark one")
	runner.check(sand.ground == Color("a88e5c"), "W1 default ground is sand D, got %s" % sand.ground.to_html(false))
	runner.check(sand.cliff_top == sand.ground.lightened(0.15) and sand.cliff_side == sand.ground.darkened(0.4), "W1 cliffs derived like the lab's sand ladder")
	runner.check(_distance(sand.ground, sand.cliff_top) > 0.1 and _distance(sand.ground, sand.cliff_side) > 0.25, "W1 sand cliffs stay readable")
	runner.check(Palette.ground(0).ground == Color("7b7566"), "W1 the dark biome is 17B #7B7566")
	return true

func test_scenes_apply_the_default_biome(runner) -> bool:
	for packed in [Skirmish, Base]:
		var main = packed.instantiate()
		runner.root.add_child(main)
		await runner.process_frame
		runner.check(main._view._terrain._colors.ground == Color("a88e5c"), "W1 a match scene starts on sand, got %s" % main._view._terrain._colors.ground.to_html(false))
		main.free()
	return true

func test_ground_is_built_once(runner) -> bool:
	var terrain = Terrain.new()
	terrain.set_map({"size": [40, 40], "blocked_cells": []})
	terrain._draw()
	runner.check(terrain.ground_builds == 1, "W2 first draw builds the ground, got %d" % terrain.ground_builds)
	terrain.set_map({"size": [40, 40], "blocked_cells": [[3, 3]]})
	terrain._draw()
	terrain.set_map({"size": [40, 40], "blocked_cells": [[3, 3], [4, 3]]})
	terrain._draw()
	runner.check(terrain.draws == 3 and terrain.ground_builds == 1, "W2 a placement redraws the terrain but reuses the ground, got %d builds" % terrain.ground_builds)
	terrain.set_palette(Palette.ground(Palette.DEFAULT_BIOME))
	terrain._draw()
	runner.check(terrain.ground_builds == 2, "W2 a palette change rebuilds the ground once")
	terrain.set_map({"size": [41, 40], "blocked_cells": []})
	terrain._draw()
	runner.check(terrain.ground_builds == 3, "W2 a new map size rebuilds the ground")
	terrain.free()
	return true

func _pair(from: Vector2 = Vector2(10.5, 10.5), to: Vector2 = Vector2(13.5, 10.5), turn: Array = [0.0, 0.0]) -> Dictionary:
	var sim = Fixture.make_world()
	var id: int = sim.spawn(1, from, "usa_rifle_infantry")
	var first: Dictionary = sim.snapshot().duplicate(true)
	var second: Dictionary = first.duplicate(true)
	second.tick = first.tick + 1
	for state: Dictionary in [first, second]:
		for unit: Dictionary in state.entities:
			if unit.id == id:
				unit.position = [from.x, from.y] if state == first else [to.x, to.y]
				if turn[0] != 0.0 or turn[1] != 0.0: unit.heading = [cos(turn[0 if state == first else 1]), sin(turn[0 if state == first else 1])]
	var third: Dictionary = second.duplicate(true)
	third.tick = first.tick + 2
	return {"id": id, "a": first, "b": second, "c": third}

func _anchor(view, id: int) -> Vector2:
	for item: Dictionary in view._items:
		if item.id == id: return item.anchor
	return Vector2(-999, -999)

func _item(view, id: int) -> Dictionary:
	for item: Dictionary in view._items:
		if item.id == id: return item
	return {}

func test_blend_between_ticks(runner) -> bool:
	var f := _pair()
	var view = View.new()
	view.set_state(f.a, [])
	view.set_state(f.b, [])
	runner.check(_anchor(view, f.id).is_equal_approx(Vector2(10.5, 10.5)), "W3 right after a tick the unit is drawn where it was, got %s" % _anchor(view, f.id))
	view.blend(0.5)
	runner.check(_anchor(view, f.id).is_equal_approx(Vector2(12.0, 10.5)), "W3 halfway at alpha 0.5, got %s" % _anchor(view, f.id))
	var hash_half: int = hash(view._batch.points)
	view.blend(1.0)
	runner.check(_anchor(view, f.id).is_equal_approx(Vector2(13.5, 10.5)) and hash(view._batch.points) != hash_half, "W3 alpha 1 reaches the new tick and the batch follows")
	view.blend(7.0)
	runner.check(_anchor(view, f.id).is_equal_approx(Vector2(13.5, 10.5)), "W3 alpha is clamped to 1")
	view.free()
	return true

func test_overlays_and_picks_follow_the_drawn_pose(runner) -> bool:
	var f := _pair()
	var view = View.new()
	view.set_state(f.a, [f.id])
	view.set_state(f.b, [f.id])
	var extent: Rect2 = WorldBatch.pick_extent("usa_rifle_infantry")
	var old_point: Vector2 = Iso.world_to_plane(Vector2(10.5, 10.5)) + extent.get_center()
	var new_point: Vector2 = Iso.world_to_plane(Vector2(13.5, 10.5)) + extent.get_center()
	runner.check(view.pick_entity(old_point) == f.id and view.pick_entity(new_point) == -1, "W3 a click hits where the unit is drawn at alpha 0")
	var lines: PackedVector2Array = view.selected_unit_lines()
	runner.check(((lines[0] + lines[3]) / 2.0).is_equal_approx(Iso.world_to_plane(Vector2(10.5, 10.5))), "W3 the selection diamond sits on the drawn unit at alpha 0")
	view.blend(1.0)
	runner.check(view.pick_entity(new_point) == f.id and view.pick_entity(old_point) == -1, "W3 a click hits the new pose at alpha 1")
	lines = view.selected_unit_lines()
	runner.check(((lines[0] + lines[3]) / 2.0).is_equal_approx(Iso.world_to_plane(Vector2(13.5, 10.5))), "W3 the selection diamond follows")
	view.free()
	return true

func test_stall_holds_and_does_not_rebuild(runner) -> bool:
	var f := _pair()
	var view = View.new()
	view.set_state(f.a, [])
	view.set_state(f.b, [])
	var start: int = view._tick_usec
	view.advance_frame(start + 5)
	runner.check(_anchor(view, f.id).is_equal_approx(Vector2(10.5, 10.5)), "W3 the frame of a tick keeps the tick pose, got %s" % _anchor(view, f.id))
	view.advance_frame(start + 16666)
	runner.check(_anchor(view, f.id).x > 11.0 and _anchor(view, f.id).x < 13.0, "W3 a later frame is between, got %s" % _anchor(view, f.id))
	view.advance_frame(start + TICK_USEC * 10)
	var settled: int = hash(view._batch.points)
	runner.check(_anchor(view, f.id).is_equal_approx(Vector2(13.5, 10.5)), "W3 a stalled lockstep parks the unit at the new tick, got %s" % _anchor(view, f.id))
	for i in 5: view.advance_frame(start + TICK_USEC * (11 + i))
	runner.check(hash(view._batch.points) == settled and _anchor(view, f.id).is_equal_approx(Vector2(13.5, 10.5)), "W3 no rubber band while the stall lasts")
	var builds: int = view.batch_builds
	view.advance_frame(start + TICK_USEC * 30)
	runner.check(view.batch_builds == builds, "W3 a stalled frame does not rebuild the batch")
	view.free()
	return true

func test_catch_up_and_restart_snap(runner) -> bool:
	var f := _pair()
	var view = View.new()
	view.set_state(f.a, [])
	view.set_state(f.c, [])
	runner.check(_anchor(view, f.id).is_equal_approx(Vector2(13.5, 10.5)), "W3 two ticks at once snap to the new pose, got %s" % _anchor(view, f.id))
	view.blend(0.5)
	runner.check(_anchor(view, f.id).is_equal_approx(Vector2(13.5, 10.5)), "W3 nothing blends after a catch-up")
	view.set_state(f.a, [])
	runner.check(_anchor(view, f.id).is_equal_approx(Vector2(10.5, 10.5)), "W3 a restart to an older tick snaps")
	view.blend(0.5)
	runner.check(_anchor(view, f.id).is_equal_approx(Vector2(10.5, 10.5)), "W3 nothing blends backwards")
	view.free()
	return true

func test_same_tick_refresh_keeps_the_pose(runner) -> bool:
	var f := _pair()
	var view = View.new()
	view.set_state(f.a, [])
	view.set_state(f.b, [])
	view.blend(0.5)
	view.set_state(f.b, [f.id])
	runner.check(_anchor(view, f.id).is_equal_approx(Vector2(12.0, 10.5)), "W3 a selection refresh in the same tick keeps the drawn pose, got %s" % _anchor(view, f.id))
	view.blend(0.75)
	runner.check(_anchor(view, f.id).is_equal_approx(Vector2(12.75, 10.5)), "W3 the blend still runs from the previous tick")
	view.free()
	return true

func test_heading_wraps(runner) -> bool:
	var f := _pair(Vector2(10.5, 10.5), Vector2(11.5, 10.5), [deg_to_rad(170.0), deg_to_rad(-170.0)])
	var view = View.new()
	view.set_state(f.a, [])
	view.set_state(f.b, [])
	view.blend(0.5)
	var angle: float = _item(view, f.id).heading
	runner.check(cos(angle) < -0.99, "W3 a heading crossing 180 degrees turns the short way, got %f" % rad_to_deg(angle))
	view.blend(1.0)
	runner.check(is_equal_approx(wrapf(_item(view, f.id).heading - deg_to_rad(-170.0), -PI, PI), 0.0), "W3 alpha 1 ends on the new heading")
	view.free()
	return true

func test_low_never_blends(runner) -> bool:
	var f := _pair()
	var view = View.new()
	view.set_quality(GraphicsSettings.LOW)
	view.set_state(f.a, [])
	view.set_state(f.b, [])
	view.blend(0.5)
	runner.check(_anchor(view, f.id).is_equal_approx(Vector2(13.5, 10.5)), "W3 Low keeps the tick position, got %s" % _anchor(view, f.id))
	view.set_quality(GraphicsSettings.HIGH)
	view.set_state(f.a, [])
	view.set_state(f.b, [])
	view.blend(0.5)
	view.set_quality(GraphicsSettings.LOW)
	runner.check(_anchor(view, f.id).is_equal_approx(Vector2(13.5, 10.5)), "W3 switching to Low mid-blend returns to the tick pose")
	view.free()
	return true

func test_blend_leaves_effects_alone(runner) -> bool:
	var sim = Fixture.make_world()
	var attacker: int = sim.spawn(1, Vector2(5.5, 5.5), "usa_tank")
	var target: int = sim.spawn(2, Vector2(9.5, 5.5), "usa_tank")
	var director := Director.new()
	var events: Array[Dictionary] = [{"type": "shot", "tick": 1, "attacker_id": attacker, "target_id": target, "damage": 1, "splash": false}]
	var none: Array[Dictionary] = []
	director.collect_step(1, events, none)
	var view = View.new()
	view.set_visuals(director)
	var first: Dictionary = sim.snapshot()
	view.set_state(first, [])
	var second: Dictionary = first.duplicate(true)
	second.tick = first.tick + 1
	second.entities[1].position = [6.5, 5.5]
	view.set_state(second, [])
	var ages: Array = director.effects().map(func(effect: Dictionary) -> int: return effect.age)
	for i in 4:
		view.blend(0.2 * i)
		view.advance_frame(view._tick_usec + TICK_USEC * i)
	runner.check(not ages.is_empty() and director.effects().map(func(effect: Dictionary) -> int: return effect.age) == ages, "W3 frames between ticks do not age effects")
	view.free()
	return true

func test_infantry_colour_default(runner) -> bool:
	for role in [&"infantry", &"rocket_infantry", &"laborer"]:
		var prims: Array = Shapes.parts(role, 1)[0].prims
		runner.check(prims[0].slot == Shapes.SLOT_SIDE_DARK and prims[1].slot == Shapes.SLOT_OWNER_FLAT and prims[2].slot == Shapes.SLOT_SKIN, "W4 %s: dark legs, full owner colour torso, light head" % role)
	var colors: PackedColorArray = Palette.owner_colors(1)
	runner.check(colors.size() == 10 and colors[Shapes.SLOT_OWNER_FLAT] == colors[0] and colors[Shapes.SLOT_SKIN] == Palette.SKIN, "W4 every owner palette carries the flat owner and skin slots")
	return true

func _horde_states() -> Array:
	var sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 1000)
	var id: int = sim.spawn(1, Vector2(8.5, 8.5), "china_rifle_infantry")
	var plain: Dictionary = sim.snapshot()
	sim._entities[id].combat.horde = 2
	return [plain, sim.snapshot(), id]

func test_horde_ring_in_the_batch(runner) -> bool:
	var states := _horde_states()
	var plain = View.new()
	var horde = View.new()
	for view in [plain, horde]: view.set_quality(GraphicsSettings.LOW)
	plain.set_state(states[0], [])
	horde.set_state(states[1], [])
	var extra: int = horde._batch.triangle_count - plain._batch.triangle_count
	runner.check(extra > 0 and extra <= 64, "W5 a horde unit adds a cheap ring to the one array, got %d triangles" % extra)
	runner.check(horde.horde_count() == 1 and plain.horde_count() == 0, "W5 the view counts horde units")
	var owner: Color = Palette.owner_colors(1)[0]
	runner.check(is_equal_approx(horde._batch.colors[0].a, 0.25) and Color(horde._batch.colors[0], 1.0).is_equal_approx(owner), "W5 the ring is drawn first, in the owner colour, got %s" % horde._batch.colors[0])
	var anchor: Vector2 = Iso.world_to_plane(Vector2(8.5, 8.5))
	runner.check(absf(horde._batch.points[0].x - anchor.x) <= 11.5 and absf(horde._batch.points[0].y - anchor.y) <= 6.0, "W5 the ring lies on the ground under the unit")
	runner.check(not horde._batch.points.has(Vector2.ZERO) and horde._batch.points.size() == horde._batch.colors.size(), "W5 no white diamond")
	plain.free()
	horde.free()
	return true

func test_wide_infantry_pick_default(runner) -> bool:
	var sim = Fixture.make_world()
	var id: int = sim.spawn(1, Vector2(10.5, 10.5), "usa_rifle_infantry")
	var view = View.new()
	view.set_state(sim.snapshot(), [])
	var extent: Rect2 = WorldBatch.pick_extent("usa_rifle_infantry")
	var point: Vector2 = Iso.world_to_plane(Vector2(10.5, 10.5)) + extent.get_center() + Vector2(16.0, 0)
	runner.check(view.pick_entity(point) == id, "W6 the wide box catches a click 16 px beside the body by default")
	runner.check(view.pick_entity(point + Vector2(5.0, 0)) != id, "W6 the box is 36 px, not unlimited")
	var tank: int = sim.spawn(1, Vector2(16.5, 10.5), "usa_tank")
	view.set_state(sim.snapshot(), [])
	var tank_box: Rect2 = WorldBatch.pick_extent("usa_tank")
	var beside: Vector2 = Iso.world_to_plane(Vector2(16.5, 10.5)) + Vector2(tank_box.end.x + 4.0, tank_box.get_center().y)
	runner.check(view.pick_entity(beside) != tank, "W6 vehicles keep the drawn-body box")
	view.free()
	return true

func test_pivot_roles_pick_extent_covers_every_pose(runner) -> bool:
	var extent: Rect2 = WorldBatch.pick_extent("frc_tank")
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for hull in range(0, Shapes.HEADING_BUCKETS, 4):
		for turret in range(0, Shapes.HEADING_BUCKETS, 4):
			for point: Vector2 in WorldBatch._body(&"tank_frc", 1, 0, hull, turret).points:
				lo = lo.min(point)
				hi = hi.max(point)
	runner.check(extent.encloses(Rect2(lo, hi - lo)), "W6 the FRC tank click box covers every hull and turret pose, box %s drawn %s" % [extent, Rect2(lo, hi - lo)])
	return true

func _shot(attacker: int, target: int) -> Array[Dictionary]:
	return [{"type": "shot", "tick": 1, "attacker_id": attacker, "target_id": target, "damage": 1, "splash": false}]

func _objects() -> Array[Dictionary]:
	return [{"id": 1, "role": &"tank_usa", "anchor": Vector2(2, 2), "heading": 0.0, "target_id": -1}, {"id": 2, "role": &"tank_usa", "anchor": Vector2(6, 2), "heading": 0.0, "target_id": -1}]

func test_shot_dash(runner) -> bool:
	var director = Director.new()
	var none: Array[Dictionary] = []
	director.collect_step(1, _shot(1, 2), none)
	director.collect_step(1, _shot(1, 2), none)
	director.update(_objects())
	var dashes: Array = director.effects().filter(func(effect: Dictionary) -> bool: return effect.type == &"dash")
	runner.check(dashes.size() == 1 and dashes[0].anchor == Vector2(2, 2) and dashes[0].to == Vector2(6, 2), "W7 a shot makes one dash from attacker to target, got %s" % [dashes])
	for i in Director.DASH_TICKS - 1: director.update(_objects())
	runner.check(director.effects().any(func(effect: Dictionary) -> bool: return effect.type == &"dash"), "W7 the dash lasts several ticks")
	director.update(_objects())
	runner.check(not director.effects().any(func(effect: Dictionary) -> bool: return effect.type == &"dash"), "W7 the dash is gone after %d ticks" % Director.DASH_TICKS)
	var first := WorldBatch.new()
	var later := WorldBatch.new()
	first.build([], {}, 0, 0, [{"type": &"dash", "anchor": Vector2(2, 2), "to": Vector2(6, 2), "age": 0, "id": 1}])
	later.build([], {}, 0, 0, [{"type": &"dash", "anchor": Vector2(2, 2), "to": Vector2(6, 2), "age": 4, "id": 1}])
	runner.check(first.triangle_count == 2 and later.triangle_count == 2, "W7 a dash is one quad (2 triangles), got %d" % first.triangle_count)
	var reach: float = 0.0
	for a: Vector2 in first.points:
		for b: Vector2 in first.points: reach = maxf(reach, a.distance_to(b))
	runner.check(reach > 11.0 and reach < 14.0, "W7 the dash is about 12 px long, got %f" % reach)
	runner.check(first.points != later.points and (later.points[0].x - first.points[0].x) > 0.0, "W7 the dash flies toward the target")
	return true

func test_neon_setting(runner) -> bool:
	var saved := _begin()
	runner.check(not GraphicsSettings.load_neon(), "W8 Neon is off without a file")
	AudioSettings.save_volumes({"music": 0.25, "effects": 0.5, "voice": 0.75})
	GraphicsSettings.save_quality(GraphicsSettings.LOW)
	GraphicsSettings.save_neon(true)
	runner.check(GraphicsSettings.load_neon() and GraphicsSettings.load_quality() == GraphicsSettings.LOW, "W8 Neon round trip keeps quality")
	runner.check(AudioSettings.load_volumes() == {"music": 0.25, "effects": 0.5, "voice": 0.75}, "W8 Neon keeps the audio volumes")
	GraphicsSettings.save_quality(GraphicsSettings.HIGH)
	runner.check(GraphicsSettings.load_neon(), "W8 saving quality keeps Neon")
	var config := ConfigFile.new()
	config.set_value("graphics", "neon", "yes")
	config.save(scratch)
	runner.check(not GraphicsSettings.load_neon(), "W8 a wrong type reads as off")
	_end(saved)
	return true

func test_neon_menu_and_wiring(runner) -> bool:
	var saved := _begin()
	var menu = PauseMenu.new(false)
	runner.root.add_child(menu)
	var seen: Array[bool] = []
	menu.neon_changed.connect(func(neon: bool) -> void: seen.append(neon))
	var button: Button = menu.find_child("Neon", true, false)
	runner.check(button != null and button.text == "Neon colours: Off", "W8 the menu starts with Neon off")
	button.pressed.emit()
	runner.check(seen == [true] and GraphicsSettings.load_neon() and button.text == "Neon colours: On", "W8 the toggle saves and emits")
	GraphicsSettings.save_neon(false)
	menu.open()
	runner.check(button.text == "Neon colours: Off", "W8 opening the menu re-reads the stored setting")
	menu.free()
	GraphicsSettings.save_neon(true)
	var main = Skirmish.instantiate()
	runner.root.add_child(main)
	await runner.process_frame
	runner.check(main._view._batch.bright_owners, "W8 a stored Neon setting applies at start")
	main._pause.neon_changed.emit(false)
	runner.check(not main._view._batch.bright_owners, "W8 the menu signal reaches the view")
	main.free()
	_end(saved)
	return true

func test_neon_reaches_structures_and_rings(runner) -> bool:
	runner.check(View.owner_color(1, true) == Palette.OWNER_BRIGHT[0] and View.owner_color(1) == Palette.OWNER_BASE[0], "W8 the structure tint takes the Neon hues")
	var states := _horde_states()
	var view = View.new()
	view.set_quality(GraphicsSettings.LOW)
	view.set_state(states[1], [])
	view._structure_key = [1, 2]
	view.set_bright_owners(true)
	runner.check(view._tint(1) == Palette.OWNER_BRIGHT[0], "W8 the view tints footprints with Neon hues")
	runner.check(view._structure_key.is_empty(), "W8 the structure layer is told to redraw")
	runner.check(Color(view._batch.colors[0], 1.0).is_equal_approx(Palette.OWNER_BRIGHT[0]), "W8 the horde ring follows Neon")
	view.free()
	return true
