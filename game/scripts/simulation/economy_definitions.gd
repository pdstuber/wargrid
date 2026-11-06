extends RefCounted

const UNITS := {
	"usa_builder": {"cost":1000,"ticks":150,"speed":1.2,"accel":1.2,"brake":2.0,"locomotor":"wheels","min_turn_speed":1.0,"turn_cos":0.9986295347545738,"turn_sin":0.052335956242943835,"air":false,"producer":""},
	"usa_light_vehicle": {"cost":700,"ticks":300,"speed":3.0,"accel":40.0,"brake":40.0,"locomotor":"wheels","min_turn_speed":0.8,"turn_cos":0.9945218953682733,"turn_sin":0.10452846326765347,"air":false,"producer":"usa_factory"},
	"usa_collector": {"cost":1200,"ticks":300,"speed":6.0,"locomotor":"air","air":true,"producer":"usa_supply_center"},
	"usa_rifle_infantry": {"cost":225,"ticks":150,"speed":0.8,"accel":4.0,"brake":4.0,"locomotor":"legs","turn_cos":0.9579895123154889,"turn_sin":0.28680323271109026,"air":false,"producer":"usa_barracks"},
	"usa_tank": {"cost":900,"ticks":300,"speed":1.2,"accel":40.0,"brake":40.0,"locomotor":"treads","turn_cos":0.9945218953682733,"turn_sin":0.10452846326765347,"air":false,"producer":"usa_factory"},
}

static func unit(kind: String) -> Dictionary:
	return UNITS.get(kind, {})

const BUILDINGS := {
	"usa_power_plant": {"cost":800,"ticks":300,"power":5,"footprint":Vector2i(2,2),"prerequisite":"","produces":""},
	"usa_supply_center": {"cost":2000,"ticks":300,"power":-1,"footprint":Vector2i(3,3),"prerequisite":"usa_power_plant","produces":"usa_collector"},
	"usa_factory": {"cost":2000,"ticks":450,"power":-1,"footprint":Vector2i(3,3),"prerequisite":"usa_supply_center","produces":"usa_light_vehicle"},
	"usa_barracks": {"cost":600,"ticks":300,"power":0,"footprint":Vector2i(2,2),"prerequisite":"","produces":"usa_rifle_infantry"},
}

static func building(kind: String) -> Dictionary:
	return BUILDINGS.get(kind, {})

static func work_rate(supply: int, demand: int) -> int:
	if demand == 0 or supply >= demand:
		return 1000
	@warning_ignore("integer_division")
	return clampi(int(supply * 1000 / demand),500,800)
