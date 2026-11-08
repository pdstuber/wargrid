extends RefCounted

const PROTOCOL: int = 2
const MAX_FRAME_BYTES: int = 65536
const MAX_SAFE_INT: float = 9007199254740992.0
const _INT_FIELDS := {
	"hello": ["protocol"], "welcome": ["seat"], "start": ["delay", "seed"], "tick": ["seat", "tick"],
	"ping": ["t"], "pong": ["t"], "left": ["seat", "after_tick"], "error": [],
}
const _REQUIRED := {
	"hello": ["protocol", "build", "match"], "welcome": ["seat", "match"], "start": ["seats", "delay", "seed", "settings"],
	"tick": ["seat", "tick", "commands"], "ping": ["t"], "pong": ["t"], "left": ["seat", "after_tick"], "error": ["reason"],
}
const _COMMAND_INTS := ["tick", "player", "sequence", "builder_id", "building_id", "production_id", "source_id", "target_id"]

static var _hash_pattern: RegEx = RegEx.create_from_string("^[0-9a-f]{16}$")

static func encode(message: Dictionary) -> String:
	return JSON.stringify(message, "", true, true)

static func tick_message(seat: int, tick: int, commands: Array, hash_entry: Variant) -> Dictionary:
	var message := {"type": "tick", "seat": seat, "tick": tick, "commands": commands}
	if hash_entry != null: message["hash"] = hash_entry
	return message

static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_FRAME_BYTES: return _fail("frame too large")
	var json := JSON.new()
	if json.parse(text) != OK: return _fail("not json")
	var parsed: Variant = json.data
	if parsed is not Dictionary: return _fail("not an object")
	var message: Dictionary = parsed
	var type: Variant = message.get("type")
	if type is not String or not _REQUIRED.has(type): return _fail("unknown type")
	for key: Variant in _REQUIRED[type]:
		if not message.has(key): return _fail("missing " + key)
	for key: Variant in _INT_FIELDS[type]:
		if not _to_int(message, key): return _fail("non-integer " + key)
	if type == "error" and message.reason is not String: return _fail("non-string reason")
	if type == "start" and not _ints_in(message, "seats"): return _fail("non-integer seats")
	if (type == "start" or type == "hello") and message.has("settings") and message.settings is not Dictionary: return _fail("invalid settings")
	if type == "tick" and not _tick_extras(message): return _fail("invalid tick message")
	return {"ok": true, "error": "", "message": message}

static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason, "message": {}}

static func _to_int(container: Variant, key: Variant) -> bool:
	var value: Variant = container[key]
	if value is int: return true
	if value is not float or absf(value) > MAX_SAFE_INT or value != floorf(value): return false
	container[key] = int(value)
	return true

static func _ints_in(container: Dictionary, key: String) -> bool:
	var list: Variant = container[key]
	if list is not Array: return false
	for i: int in list.size():
		if not _to_int(list, i): return false
	return true

static func _tick_extras(message: Dictionary) -> bool:
	if message.commands is not Array: return false
	for command: Variant in message.commands:
		if command is not Dictionary or command.get("type") is not String: return false
		for key: Variant in _COMMAND_INTS:
			if command.has(key) and not _to_int(command, key): return false
		for key: String in ["entity_ids", "origin"]:
			if command.has(key) and not _ints_in(command, key): return false
	if message.has("hash"):
		var hash_entry: Variant = message.hash
		if hash_entry is not Dictionary or not hash_entry.has("tick") or not _to_int(hash_entry, "tick"): return false
		if hash_entry.get("value") is not String or not _hash_pattern.search(hash_entry.value): return false
	return true
