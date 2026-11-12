extends RefCounted

const DockSplit = preload("res://scripts/experiments/dock_split.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")

# Dock models c1 and c2: split's lead/lock mechanics with the pile lock sized to a share of the credits a visit earns; the stand keeps its length.
const RATIOS := {"c1": Vector2i(184, 300), "c2": Vector2i(44, 75)}

static var tables: Dictionary = _build_tables()

static func source_entry(collects: Dictionary, ratio: Vector2i) -> Dictionary:
	var loads: int = collects.boxes + 1
	var stand: int = loads * collects.load_ticks
	@warning_ignore("integer_division")
	var earned: int = (collects.boxes * collects.box_value * ratio.x + ratio.y - 1) / ratio.y
	if earned >= stand: return {"lead": 0, "box": collects.load_ticks}
	@warning_ignore("integer_division")
	var box: int = (2 * earned + loads) / (2 * loads)
	return {"lead": stand - loads * box, "box": box}

static func _build_tables() -> Dictionary:
	var built: Dictionary = {"split": DockSplit.SPLIT}
	for model: String in RATIOS:
		var table: Dictionary = {}
		for kind: String in DockSplit.SPLIT:
			table[kind] = {"source": source_entry(Registry.collects(kind), RATIOS[model]), "depot": DockSplit.SPLIT[kind].depot}
		built[model] = table
	return built
