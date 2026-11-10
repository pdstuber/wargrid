extends RefCounted

const OWNER_BASE: Array[Color] = [
	Color("376eac"), Color("b04a3a"), Color("3f8f4f"), Color("c9a227"),
	Color("d27a2c"), Color("7a4fa0"), Color("2f9c9c"), Color("c8628f"),
]
# Vertical faces and machinery stay neutral for every owner (ART_DIRECTION section 7, palette-proposal.json materials).
const SIDE := Color("3d515f")
const SIDE_DARK := Color("263842")
const MACHINE := Color("8098a5")
const OWNER_BRIGHT: Array[Color] = [
	Color("2f7bff"), Color("ff2f45"), Color("14d45a"), Color("ffe100"),
	Color("ff7a00"), Color("a040ff"), Color("00d8e8"), Color("ff4fb0"),
]
const SKIN := Color("d8c8ae")
const SMOKE := Color("2a2c2e")
const FALLBACK := Color("808080")
# Owner 0 is neutral supply: amber crates (palette-proposal.json, impact_heat_resources).
const NEUTRAL := Color("f7c871")
const WATER := Color("3b6f8f")
const SAND := Color("a88e5c")
const DEFAULT_BIOME := 1
const HEALTH_GREEN := Color("5cc85a")
const HEALTH_YELLOW := Color("e0d060")
const HEALTH_RED := Color("d8453a")

# Ten slots: the eight Shapes slots plus a flat owner colour and a light skin tone; bright swaps in the Neon hues.
static func owner_colors(owner: int, bright: bool = false) -> PackedColorArray:
	var base: Color = OWNER_BASE[owner - 1] if owner >= 1 and owner <= OWNER_BASE.size() else (NEUTRAL if owner == 0 else FALLBACK)
	if bright and owner >= 1 and owner <= OWNER_BRIGHT.size(): base = OWNER_BRIGHT[owner - 1]
	return PackedColorArray([
		base, base.darkened(0.25), SIDE, SIDE_DARK,
		MACHINE, base.lightened(0.5), SMOKE, Color(0, 0, 0, 0.3),
		base, SKIN,
	])

# Cliffs read against the ground: top lighter, sides much darker.
static func ground_set(tone: Color) -> Dictionary:
	return {"ground": tone, "cliff_top": tone.lightened(0.15), "cliff_side": tone.darkened(0.4), "water": WATER}

static func ground(biome: int) -> Dictionary:
	if biome == 0:
		return {"ground": Color("7b7566"), "cliff_top": Color("968f7c"), "cliff_side": Color("4a463c"), "water": WATER}
	return ground_set(SAND)
