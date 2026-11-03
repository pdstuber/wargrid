extends RefCounted

static func unit(kind: String) -> Dictionary:
	match kind:
		"builder": return {"cost":1000,"ticks":150,"speed":1.2,"air":false,"producer":""}
		"vehicle": return {"cost":700,"ticks":300,"speed":3.0,"air":false,"producer":"factory"}
		"collector": return {"cost":1200,"ticks":300,"speed":6.0,"air":true,"producer":"depot"}
	return {}

static func building(kind: String) -> Dictionary:
	match kind:
		"reactor": return {"cost":800,"ticks":300,"power":5,"footprint":Vector2i(2,2),"prerequisite":"","produces":""}
		"depot": return {"cost":2000,"ticks":300,"power":-1,"footprint":Vector2i(3,3),"prerequisite":"reactor","produces":"collector"}
		"factory": return {"cost":2000,"ticks":450,"power":-1,"footprint":Vector2i(3,3),"prerequisite":"depot","produces":"vehicle"}
	return {}

static func work_rate(supply: int, demand: int) -> int:
	if demand == 0 or supply >= demand:
		return 1000
	return clampi(int(supply * 1000 / demand),500,800)
