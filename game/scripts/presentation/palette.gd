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
const NEUTRAL_SIDE := Color("4a4d50")
const NEUTRAL_SIDE_DARK := Color("333538")
const NEUTRAL_MACHINE := Color("8f9296")
const SKIN := Color("d8c8ae")
const SMOKE := Color("2a2c2e")
const FALLBACK := Color("808080")
# Owner 0 is neutral supply: amber crates (palette-proposal.json, impact_heat_resources).
const NEUTRAL := Color("f7c871")
const HEALTH_GREEN := Color("5cc85a")
const HEALTH_YELLOW := Color("e0d060")
const HEALTH_RED := Color("d8453a")

static func owner_colors(owner: int) -> PackedColorArray:
	var base: Color = OWNER_BASE[owner - 1] if owner >= 1 and owner <= OWNER_BASE.size() else (NEUTRAL if owner == 0 else FALLBACK)
	return PackedColorArray([
		base, base.darkened(0.25), SIDE, SIDE_DARK,
		MACHINE, base.lightened(0.5), SMOKE, Color(0, 0, 0, 0.3),
	])

# Lab: the eight normal slots plus a flat owner colour for every face and a light skin tone; neutral_sides swaps the blue-grey sides for true greys, bright swaps the owner hues.
static func extended_colors(owner: int, neutral_sides: bool, bright: bool = false) -> PackedColorArray:
	var colors: PackedColorArray = owner_colors(owner)
	if bright and owner >= 1 and owner <= OWNER_BRIGHT.size():
		colors[0] = OWNER_BRIGHT[owner - 1]
		colors[1] = colors[0].darkened(0.25)
		colors[5] = colors[0].lightened(0.5)
	if neutral_sides:
		colors[2] = NEUTRAL_SIDE
		colors[3] = NEUTRAL_SIDE_DARK
		colors[4] = NEUTRAL_MACHINE
	colors.append(colors[0])
	colors.append(SKIN)
	return colors

static func ground(biome: int) -> Dictionary:
	if biome == 2:
		return {"ground": Color("7b7566"), "cliff_top": Color("968f7c"), "cliff_side": Color("4a463c"), "water": Color("3b6f8f")}
	if biome == 1:
		return {"ground": Color("c4a568"), "cliff_top": Color("a88b55"), "cliff_side": Color("665744"), "water": Color("3b6f8f")}
	return {"ground": Color("575c55"), "cliff_top": Color("6d7268"), "cliff_side": Color("3e423c"), "water": Color("34576b")}
