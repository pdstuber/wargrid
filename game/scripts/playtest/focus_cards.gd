extends RefCounted

const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const PATH := "res://data/playtest/focus.json"
const COMMAND_TYPES: Array[String] = ["move", "attack_move", "stop", "gather", "attack", "enter", "unload", "build", "resume_build", "cancel_build", "produce", "cancel_production", "set_rally", "defence_attack"]
const MIN_QUESTIONS: int = 3
const MAX_QUESTIONS: int = 5
static var chosen: String = ""

static func load_cards(path: String = PATH) -> Array[Dictionary]:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var problems: PackedStringArray = errors(parsed)
	var cards: Array[Dictionary] = []
	if problems.is_empty(): cards.assign(parsed)
	else: push_error("Focus cards rejected: " + "; ".join(problems))
	return cards

static func errors(cards: Variant) -> PackedStringArray:
	if not cards is Array or cards.is_empty(): return ["the focus file must be a non-empty list"]
	var found := PackedStringArray()
	var ids: Dictionary = {}
	for entry: Variant in cards:
		if not entry is Dictionary:
			found.append("a card is not an object")
			continue
		var label: String = str(entry.get("id", "?"))
		found.append_array(_unique_text_errors([entry], "card", "title", ids))
		found.append_array(_card_errors(entry, label))
	return found

static func _card_errors(entry: Dictionary, label: String) -> PackedStringArray:
	var found := PackedStringArray()
	var lines: Variant = entry.get("new")
	if not lines is Array or lines.any(func(line: Variant) -> bool: return not line is String):
		found.append("%s: new must be a list of lines" % label)
	var steps: Variant = entry.get("try")
	var questions: Variant = entry.get("questions")
	if not steps is Array: found.append("%s: try must be a list" % label)
	else:
		found.append_array(_unique_text_errors(steps, label + " try", "text", {}))
		for step: Variant in steps:
			if step is Dictionary and step.has("trigger"):
				var problem: String = trigger_error(str(step.trigger))
				if not problem.is_empty(): found.append("%s: %s" % [label, problem])
	if not questions is Array or questions.size() < MIN_QUESTIONS or questions.size() > MAX_QUESTIONS:
		found.append("%s: questions must be a list of %d to %d" % [label, MIN_QUESTIONS, MAX_QUESTIONS])
	else: found.append_array(_unique_text_errors(questions, label + " question", "text", {}))
	return found

static func _unique_text_errors(items: Array, what: String, text_key: String, ids: Dictionary) -> PackedStringArray:
	var found := PackedStringArray()
	for item: Variant in items:
		if not item is Dictionary:
			found.append("%s is not an object" % what)
			continue
		var id: Variant = item.get("id")
		if not id is String or id.is_empty(): found.append("%s needs an id" % what)
		elif ids.has(id): found.append("%s id %s is used twice" % [what, id])
		else: ids[id] = true
		var text: Variant = item.get(text_key)
		if not text is String or text.is_empty(): found.append("%s %s needs %s" % [what, str(id), text_key])
	return found

static func trigger_error(trigger: String) -> String:
	if trigger in COMMAND_TYPES or trigger == "esc_menu": return ""
	var parts: PackedStringArray = trigger.split(":", true, 1)
	if parts.size() == 2 and parts[0] in ["build", "produce"]:
		return "" if not Registry.kind(parts[1]).is_empty() else "unknown kind " + parts[1]
	if parts.size() == 2 and parts[0] == "key":
		return "" if OS.find_keycode_from_string(parts[1]) != KEY_NONE else "unknown key " + parts[1]
	return "unknown trigger " + trigger

static func matches_command(trigger: String, payload: Dictionary) -> bool:
	var type: Variant = payload.get("type")
	if trigger.begins_with("build:"): return type == "build" and payload.get("building_kind") == trigger.substr(6)
	if trigger.begins_with("produce:"): return type == "produce" and payload.get("unit_kind") == trigger.substr(8)
	return trigger in COMMAND_TYPES and type == trigger

static func shown() -> String:
	var open: String = PlaytestSession.open_focus()
	return open if not open.is_empty() else chosen

static func card(id: String, cards: Array[Dictionary]) -> Dictionary:
	for entry in cards:
		if entry.id == id: return entry
	return cards[0] if not cards.is_empty() else {}
