class_name PlaytestSession
extends RefCounted

const FORMAT: int = 1
const CURRENT := "current.json"
const LAST := "last-session.json"
static var dir: String = "user://playtests"
static var current: PlaytestSession = null
var data: Dictionary = {}
var _pending: Array[Dictionary] = []

static func resume_or_open(focus_id: String, build: String) -> PlaytestSession:
	if current != null: return current
	var session := new()
	session.data = _stored()
	if session.data.is_empty():
		session.data = {"format": FORMAT, "build": build, "focus": focus_id, "started": Time.get_datetime_string_from_system(true), "checklist": {}, "answers": {}, "matches": []}
	current = session
	return session

static func open_count() -> int:
	var shown: Dictionary = current.data if current != null else _stored()
	return shown.matches.size() if not shown.is_empty() else -1

static func open_focus() -> String:
	var shown: Dictionary = current.data if current != null else _stored()
	return str(shown.get("focus", ""))

static func file_name(started: String) -> String:
	return "session-%s.json" % started.replace(":", "-")

static func _stored() -> Dictionary:
	var path: String = dir.path_join(CURRENT)
	var json := JSON.new()
	var parsed: Variant = json.data if FileAccess.file_exists(path) and json.parse(FileAccess.get_file_as_string(path)) == OK else null
	var valid: bool = parsed is Dictionary and parsed.get("format") == FORMAT and parsed.get("matches") is Array and parsed.get("answers") is Dictionary and parsed.get("checklist") is Dictionary
	return parsed if valid else {}

func add_marker(marker: Dictionary) -> void:
	_pending.append(marker)

func pending_markers() -> Array[Dictionary]:
	return _pending

func clear_pending() -> void:
	_pending.clear()

func finish_match(record: Dictionary) -> int:
	var finished: Dictionary = record.duplicate(true)
	finished.markers = _pending.duplicate(true)
	_pending.clear()
	data.matches.append(finished)
	_mirror()
	return data.matches.size() - 1

func set_comment(match_index: int, marker_index: int, text: String) -> void:
	data.matches[match_index].markers[marker_index].comment = text
	_mirror()

func set_answer(question_id: String, score: int, text: String) -> void:
	data.answers[question_id] = {"score": score, "text": text}
	_mirror()

func set_checked(item_id: String, on: bool) -> void:
	data.checklist[item_id] = on
	_mirror()

func write(web: bool, download: Callable) -> String:
	var file: String = file_name(data.started)
	var json: String = JSON.stringify(data, "\t")
	var result: String = file
	if web:
		_store(LAST, json) # the browser may block the download; this copy survives until the next save
		download.call(json.to_utf8_buffer(), file, "application/json")
	else:
		DirAccess.make_dir_recursive_absolute(dir)
		var out := FileAccess.open(dir.path_join(file), FileAccess.WRITE)
		if out == null: return ""
		out.store_string(json)
		out.close()
		result = ProjectSettings.globalize_path(dir.path_join(file))
	discard()
	return result

func discard() -> void:
	DirAccess.remove_absolute(dir.path_join(CURRENT))
	if current == self: current = null

func _mirror() -> void:
	_store(CURRENT, JSON.stringify(data))

func _store(file: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var out := FileAccess.open(dir.path_join(file), FileAccess.WRITE)
	if out == null: return
	out.store_string(text)
	out.close()
