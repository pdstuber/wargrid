extends RefCounted

const Iso = preload("res://scripts/presentation/isometric.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Palette = preload("res://scripts/presentation/palette.gd")
const Fight = preload("res://scripts/lab/lab_fight.gd")

const QUESTIONS: Array[StringName] = [
	&"biome", &"fog", &"signature", &"shake", &"hit_flash", &"wrecks", &"owner_palette", &"sand_tone",
]
const LABELS := {
	&"biome": ["sand ground (the game default)", "dark ground #7B7566"],
	&"fog": ["fog darkened to half brightness", "fog as a grey veil, colour drained"],
	&"signature": ["no signature effect (no special weapon in the fight)", "big core and rings on building and vehicle deaths"],
	&"shake": ["no camera shake (today)", "small shake on building and vehicle deaths"],
	&"hit_flash": ["no hit flash (today)", "a light flash on the unit that is hit"],
	&"wrecks": ["wreck stays: tanks 20 s, light vehicles 8 s", "short wreck, 3 s"],
	&"owner_palette": ["today's owner colours (the game default)", "brighter, more saturated owner colours (Neon mode)"],
	&"sand_tone": ["#7B7566", "#8A7D62", "#998559", "#A88E5C", "#B29763", "#C4A568"],
}
const SAND_STEPS: Array[Color] = [Color("7b7566"), Color("8a7d62"), Color("998559"), Color("a88e5c"), Color("b29763"), Color("c4a568")]
const FOG_CLEAR := 12.0
const FOG_FULL := 17.0
const FLASH_TICKS: int = 2
const SIGNATURE_TICKS: int = 24
const SHAKE_TICKS: int = 12
const SHAKE_PIXELS: float = 6.0
const WRECK_TICKS_A: int = 600
const WRECK_TICKS_A_LIGHT: int = 240
const WRECK_TICKS_B: int = 90
const WRECK_SINK_TICKS: int = 45
const WRECK_COLOR := Color("2b2d2f")

var opponent_owner: int = 2
var focus: StringName = &""
var _variants := {}
var _applied := []
var _tick: int = 0
var _items := {}
var _map_size := Vector2i.ZERO
var _hits: Array[Dictionary] = []
var _deaths: Array[Dictionary] = []
var _fog := {}

func variant(question: StringName) -> int:
	return _variants.get(question, 0)

func is_b(question: StringName) -> bool:
	return variant(question) == 1

func variant_count(question: StringName) -> int:
	return LABELS[question].size()

func sand_colors() -> Dictionary:
	return Palette.ground_set(SAND_STEPS[variant(&"sand_tone")])

func set_variant(question: StringName, value: int) -> void:
	assert(QUESTIONS.has(question))
	_variants[question] = clampi(value, 0, variant_count(question) - 1)

func reset() -> void:
	_items = {}
	_hits = []
	_deaths = []
	_tick = 0

# The production hooks the variants plug into; each setter defaults to the game's look.
func apply(view: Node2D, camera: Camera2D) -> void:
	var state := [_variants, focus]
	if _applied != state:
		_applied = [_variants.duplicate(), focus]
		if focus == &"sand_tone": view.set_ground_colors(sand_colors())
		else: view.set_biome(0 if is_b(&"biome") else Palette.DEFAULT_BIOME)
		view.set_bright_owners(is_b(&"owner_palette"))
	camera.offset = shake_offset()

# One call per simulation tick with that tick's events; events carry no positions, so anchors come from the objects.
func observe(state: Dictionary, items: Array[Dictionary], events: Array[Dictionary]) -> void:
	var previous: Dictionary = _items
	_tick = state.tick
	_items = {}
	for item in items: _items[item.id] = item
	_map_size = Vector2i(state.map.size[0], state.map.size[1])
	for event in events:
		if event.type == "shot": _record_hit(event, previous)
		elif event.type == "death": _record_death(event.object_id, previous)
	_prune()

func _anchor_of(id: int, previous: Dictionary) -> Variant:
	var item: Variant = _items.get(id, previous.get(id))
	return null if item == null else item.anchor

func _record_hit(event: Dictionary, previous: Dictionary) -> void:
	var to: Variant = _anchor_of(event.target_id, previous)
	if to != null: _hits.append({"anchor": to, "tick": _tick})

func _record_death(id: int, previous: Dictionary) -> void:
	var item: Variant = _items.get(id, previous.get(id))
	if item == null: return
	var row: Dictionary = Registry.kind(item.kind)
	var building: bool = row.has("footprint")
	var vehicle: bool = row.get("class", "") == "vehicle"
	if not building and not vehicle: return
	_deaths.append({"anchor": item.anchor, "tick": _tick, "building": building, "light": item.kind.ends_with("light_vehicle")})

func _prune() -> void:
	_hits = _hits.filter(func(hit: Dictionary) -> bool: return _tick - hit.tick < FLASH_TICKS)
	var keep: int = maxi(WRECK_TICKS_A, SIGNATURE_TICKS)
	_deaths = _deaths.filter(func(death: Dictionary) -> bool: return _tick - death.tick < keep)

func active_flashes() -> Array[Dictionary]:
	return _hits if is_b(&"hit_flash") else []

func active_signatures() -> Array[Dictionary]:
	if not is_b(&"signature"): return []
	return _deaths.filter(func(death: Dictionary) -> bool: return _tick - death.tick < SIGNATURE_TICKS)

func active_wrecks() -> Array[Dictionary]:
	return _deaths.filter(func(death: Dictionary) -> bool: return not death.building and _tick - death.tick < _wreck_life(death))

func _wreck_life(death: Dictionary) -> int:
	if is_b(&"wrecks"): return WRECK_TICKS_B
	return WRECK_TICKS_A_LIGHT if death.light else WRECK_TICKS_A

func shake_offset() -> Vector2:
	if not is_b(&"shake"): return Vector2.ZERO
	var amplitude: float = 0.0
	for death: Dictionary in _deaths:
		var age: int = _tick - death.tick
		if age < SHAKE_TICKS: amplitude = maxf(amplitude, SHAKE_PIXELS * (1.0 - float(age) / SHAKE_TICKS))
	return Vector2(sin(_tick * 2.9), cos(_tick * 3.7)) * amplitude

# The same fight with player 2 shown in another owner's colour, to compare the eight colours against blue.
static func recolored(state: Dictionary, opponent: int) -> Dictionary:
	if opponent == 2: return state
	var result: Dictionary = state.duplicate()
	for key: String in ["entities", "buildings"]:
		var rows: Array = []
		for row: Dictionary in state.get(key, []):
			if row.owner == 2:
				row = row.duplicate()
				row.owner = opponent
			rows.append(row)
		result[key] = rows
	return result

# Under the bodies: wrecks.
func draw_ground(canvas: CanvasItem) -> void:
	for wreck in active_wrecks(): _draw_wreck(canvas, wreck)

# Over the bodies: flashes, signature rings and the fog mask.
func draw_top(canvas: CanvasItem) -> void:
	for flash in active_flashes(): canvas.draw_colored_polygon(_diamond(Iso.world_to_plane(flash.anchor) + Vector2(0, -8), 11.0), Color(1, 1, 1, 0.55))
	for death in active_signatures(): _draw_signature(canvas, death)
	var fog: Dictionary = _fog_mesh()
	if not fog.indices.is_empty(): RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), fog.indices, fog.points, fog.colors)

func _draw_wreck(canvas: CanvasItem, wreck: Dictionary) -> void:
	var left: int = _wreck_life(wreck) - (_tick - wreck.tick)
	var sink: float = clampf(float(left) / WRECK_SINK_TICKS, 0.0, 1.0)
	var at: Vector2 = Iso.world_to_plane(wreck.anchor)
	canvas.draw_colored_polygon(_diamond(at, 13.0 * sink), Color(WRECK_COLOR, 0.9 * sink))
	canvas.draw_colored_polygon(_diamond(at + Vector2(0, -4.0 * sink), 7.0 * sink), Color(WRECK_COLOR.lightened(0.15), 0.9 * sink))

func _draw_signature(canvas: CanvasItem, death: Dictionary) -> void:
	var age: float = float(_tick - death.tick)
	var fade: float = 1.0 - age / SIGNATURE_TICKS
	var at: Vector2 = Iso.world_to_plane(death.anchor) + Vector2(0, -8)
	canvas.draw_colored_polygon(_diamond(at, (22.0 if death.building else 15.0) * fade + 3.0), Color("ffb347", 0.9 * fade))
	for ring in 2:
		var radius: float = 8.0 + age * (2.6 + ring)
		canvas.draw_arc(at, radius, 0.0, TAU, 20, Color("ffe0a0", 0.8 * fade), 2.0)

static func _diamond(centre: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([centre + Vector2(0, -radius * 0.5), centre + Vector2(radius, 0), centre + Vector2(0, radius * 0.5), centre + Vector2(-radius, 0)])

# Static mask, built once per variant and map size: full strength beyond FOG_FULL cells from the fight, none inside FOG_CLEAR.
func _fog_mesh() -> Dictionary:
	if _map_size == Vector2i.ZERO: return {"indices": PackedInt32Array()}
	var key := [variant(&"fog"), _map_size]
	if not _fog.has(key): _fog[key] = _build_fog(variant(&"fog"))
	return _fog[key]

func _build_fog(fog_variant: int) -> Dictionary:
	var mesh := {"points": PackedVector2Array(), "colors": PackedColorArray(), "indices": PackedInt32Array()}
	var base: Color = Color(0, 0, 0, 0.5) if fog_variant == 0 else Color(0.55, 0.58, 0.62, 0.6)
	for y in _map_size.y:
		for x in _map_size.x:
			var strength: float = smoothstep(FOG_CLEAR, FOG_FULL, (Vector2(x + 0.5, y + 0.5) - Fight.FOCUS).length())
			if strength <= 0.01: continue
			var start: int = mesh.points.size()
			for corner: Vector2 in [Vector2(x, y), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]:
				mesh.points.append(Iso.world_to_plane(corner))
				mesh.colors.append(Color(base, base.a * strength))
			mesh.indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])
	return mesh
