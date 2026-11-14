extends RefCounted

const ViewRows = preload("res://scripts/simulation/view_rows.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const View = preload("res://scripts/presentation/world_view.gd")

var note: String = ""
var _last_result_tick: int = -1
var _last_result_sequence: int = -1
var _screen: Node
var _status: Label
var _economy: Control
var _build_menu: GridContainer
var _queue: Control
var _produce: Button
var _cancel_build: Button
var _result: Label
var _restart_button: Button

func _init(hud_layer: CanvasLayer, screen: Node) -> void:
	_screen = screen
	_status = hud_layer.get_node("Status")
	_economy = hud_layer.get_node("Economy")
	_build_menu = hud_layer.get_node("Economy/BuildMenu")
	_queue = hud_layer.get_node("Economy/Queue")
	_produce = hud_layer.get_node("Economy/Produce")
	_cancel_build = hud_layer.get_node("Economy/CancelBuild")
	_result = hud_layer.get_node("Result")
	_restart_button = hud_layer.get_node("Restart")

func reset() -> void:
	note = ""
	_last_result_tick = -1
	_last_result_sequence = -1

func place_economy() -> void:
	_economy.position.y = maxf(116.0,_status.position.y + _status.get_minimum_size().y + 8.0)

func _refresh_hud(state: Dictionary) -> void:
	_screen._ensure_sound()
	_economy_hud(state)
	_match_hud(state)
	var line: String = _screen.driver.notice()
	if not line.is_empty(): _status.text += "\n" + line
	if not _screen.driver.can_restart(): _restart_button.hide()
	_screen._sound.update(state)

func _economy_hud(state: Dictionary) -> void:
	for result: Dictionary in _screen.stepped_results + state.command_results:
		if result.player == _screen.local_player and (result.tick > _last_result_tick or (result.tick == _last_result_tick and result.sequence > _last_result_sequence)):
			note = result.error
			_last_result_tick = result.tick
			_last_result_sequence = result.sequence
	var player: Dictionary = _screen._local_state(state)
	var building: Dictionary = _screen._building(state,_screen.orders.selected_building_id)
	var detail: String = "Units: " + str(_screen.orders.selected_ids)
	if not building.is_empty(): detail = "%s #%d | Work %d/%d" % [Registry.kind(building.kind).display_name,building.id,building.work,Definitions.building(building.kind).ticks * 1000]
	var resume: String = "Right-click: resume\n" if _screen._view.resume_candidate() != -1 else ""
	var placing: String = Registry.kind(_screen.orders._placement_kind).get("display_name","")
	_status.text = "Credits: %d | Power: %d/%d | Tick: %d\n%s | Place: %s\n%s | Right: context/move | E: produce | Esc: cancel\n%s%s" % [player.credits,player.power_supply,player.power_demand,state.tick,detail,placing,_build_hint(),resume,note]
	_produce.visible = not building.is_empty() and building.completed and not _screen._production_kind(building, state).is_empty()
	_cancel_build.visible = not building.is_empty() and not building.completed
	_refresh_menu(_menu_kinds(state,building))
	_refresh_queue(building.get("queue",[]))

func _match_hud(state: Dictionary) -> void:
	var result: String = "" if state.match == null else _result_text(state.match)
	var building: Dictionary = _screen._building(state, _screen.orders.selected_building_id)
	_screen._view.set_inspected(_screen.orders.inspected_id)
	_produce.text = "Produce %s (E)" % Registry.kind(_screen._production_kind(building, state)).get("display_name", "") if not building.is_empty() else "Produce (E)"
	_status.text += "\n" + (_selected_summary(state) + _enemy_summary(state)) + ("A: attack-move click | S: stop | You are %s (P%d)" % [("blue" if _screen.local_player == 1 else "red"), _screen.local_player] if result.is_empty() else "")
	_result.text = result
	_result.visible = not result.is_empty()
	_restart_button.visible = not result.is_empty()

func _build_hint() -> String:
	return "1-9: menu  U: unload"

func _menu_kinds(state: Dictionary, building: Dictionary) -> Array:
	if not building.is_empty(): return Registry.kind(building.kind).produces if building.completed else []
	var kind: String = Registry.faction(_screen._local_state(state).get("faction",Registry.Factions.DEFAULT_FACTION)).get("start_unit","")
	if _screen.orders.selected_ids.size() == 1:
		var i: int = state.units.index_of(_screen.orders.selected_ids[0])
		var unit_kind: String = state.units.kinds[state.units.kind[i]] if i != -1 else ""
		if Registry.is_builder(unit_kind): kind = unit_kind
	return Registry.kind(kind).get("builds",[])

static func menu_label(index: int, kind: String) -> String:
	var quantity: int = Registry.kind(kind).get("quantity",1)
	return "%d: %s%s $%d" % [index + 1,Registry.kind(kind).display_name," x%d" % quantity if quantity > 1 else "",Registry.kind(kind).cost]

func _refresh_menu(kinds: Array) -> void:
	_screen.orders.menu = kinds
	var grid: GridContainer = _build_menu
	while grid.get_child_count() > kinds.size(): grid.get_child(grid.get_child_count() - 1).free()
	for i in kinds.size():
		var button: Button = grid.get_child(i) if i < grid.get_child_count() else null
		if button == null:
			button = Button.new()
			button.pressed.connect(_screen.orders._menu_choose.bind(i,false))
			grid.add_child(button)
		button.text = menu_label(i,kinds[i])

func _refresh_queue(queue: Array) -> void:
	var ids: Array = queue.map(func(entry: Dictionary) -> String: return str(entry.id))
	for child in _queue.get_children():
		if not ids.has(str(child.name)): child.free()
	for entry: Variant in queue:
		var button: Button = _queue.get_node_or_null(str(entry.id))
		if button == null:
			button = Button.new()
			button.name = str(entry.id)
			button.pressed.connect(_screen.orders._cancel_entry.bind(entry.id))
			_queue.add_child(button)
		button.text = queue_label(entry)

static func queue_label(entry: Dictionary) -> String:
	var label: String = Registry.kind(entry.kind).display_name
	if entry.work == 0: return "Cancel %s (queued)" % label
	return "Cancel %s (%d%%)" % [label,entry.work * 100 / (Definitions.unit(entry.kind).ticks * 1000)]

func _selected_summary(state: Dictionary) -> String:
	if _screen.orders.selected_ids.size() != 1: return ""
	var i: int = state.units.index_of(_screen.orders.selected_ids[0])
	if i == -1: return ""
	var unit: Dictionary = _unit_record(state.units, i)
	var line: String = "%s #%d HP %d/%d" % [Registry.kind(unit.kind).display_name, unit.id, unit.hp / 1000, unit.max_hp / 1000]
	if unit.combat != null: line += " | %s%s" % [unit.combat.mode, "" if unit.combat.target_id == null else " -> #" + str(unit.combat.target_id)]
	if unit.collection != null and unit.collection.enabled: line += _collection_suffix(state, unit)
	return line + "\n"

func _unit_record(units: RefCounted, i: int) -> Dictionary:
	var target: Variant = units.target[i] if units.target[i] != -1 else null
	var combat: Variant = {"mode": units.modes[units.mode[i]], "target_id": target} if units.mode[i] != ViewRows.NONE else null
	var collection: Variant = {"enabled": (units.flags[i] & ViewRows.COLLECTING) != 0, "phase": units.phases[units.phase[i]]} if units.phase[i] != ViewRows.NONE else null
	return {"id": units.id[i], "owner": units.owner[i], "kind": units.kinds[units.kind[i]], "hp": units.hp[i], "max_hp": units.max_hp[i], "combat": combat, "collection": collection}

func _collection_suffix(state: Dictionary, unit: Dictionary) -> String:
	var line: String = " | " + unit.collection.phase
	if unit.collection.phase.begins_with("waiting_"): line += " (%s in line)" % _ordinal(View.line_position(state.units, state.units.index_of(unit.id)))
	return line

func _ordinal(n: int) -> String:
	var suffix: String = "th" if n % 100 in [11, 12, 13] else {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return str(n) + suffix

func _inspected(state: Dictionary) -> Dictionary:
	var i: int = state.units.index_of(_screen.orders.inspected_id)
	if i != -1: return _unit_record(state.units, i)
	for building: Dictionary in state.buildings:
		if building.id == _screen.orders.inspected_id: return building
	return {}

func _enemy_summary(state: Dictionary) -> String:
	var object: Dictionary = _inspected(state)
	if object.is_empty(): return ""
	var line: String = "Enemy (P%d) %s #%d HP %d/%d" % [object.owner, Registry.kind(object.kind).display_name, object.id, object.hp / 1000, object.max_hp / 1000]
	var combat: Variant = object.get("combat")
	if combat != null: line += " | " + combat.mode + ("" if combat.target_id == null else " -> #%d" % combat.target_id)
	return line + "\n"

func _result_text(match_state: Dictionary) -> String:
	if match_state.status == "draw": return "Draw"
	if match_state.status != "won": return ""
	return "Victory" if match_state.winner == _screen.driver.sim.team_of(_screen.local_player) else "Defeat"
