extends RefCounted

const OWNER_BASE: Array[Color] = [
	Color("376eac"), Color("b04a3a"), Color("3f8f4f"), Color("c9a227"),
	Color("d27a2c"), Color("7a4fa0"), Color("2f9c9c"), Color("c8628f"),
]
const FALLBACK := Color("808080")

static func owner_colors(owner: int) -> PackedColorArray:
	var base: Color = OWNER_BASE[owner - 1] if owner >= 1 and owner <= OWNER_BASE.size() else FALLBACK
	return PackedColorArray([
		base, base.darkened(0.25), base.darkened(0.35), base.darkened(0.5),
		Color("4a4d52"), base.lightened(0.5), Color("15181a"), Color(0, 0, 0, 0.3),
	])

static func ground(biome: int) -> Dictionary:
	if biome == 1:
		return {"ground": Color("c4a568"), "cliff_top": Color("a88b55"), "cliff_side": Color("665744"), "water": Color("3b6f8f")}
	return {"ground": Color("575c55"), "cliff_top": Color("6d7268"), "cliff_side": Color("3e423c"), "water": Color("34576b")}
