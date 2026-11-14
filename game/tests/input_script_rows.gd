extends RefCounted

const IC1_ROWS: PackedStringArray = [
	"1|sel=[7, 8]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|",
	"2|sel=[7, 8]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|{\"entity_ids\":[7,8],\"player\":1,\"sequence\":0,\"target\":[20.5,10.5],\"tick\":0,\"type\":\"move\"}",
	"3|sel=[7, 8]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|{\"entity_ids\":[7,8],\"player\":1,\"sequence\":1,\"target\":[24.5,8.5],\"tick\":0,\"type\":\"attack_move\"}|Credits: 10000 | Power: 0/0 | Tick: 0\nUnits: [7, 8] | Place: \n1-9: menu  U: unload | Right: context/move | E: produce | Esc: cancel\n\nA: attack-move click | S: stop | You are blue (P1)",
	"4|sel=[7, 8]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|{\"entity_ids\":[7,8],\"player\":1,\"sequence\":2,\"tick\":0,\"type\":\"stop\"}",
	"5|sel=[7, 8]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|{\"entity_ids\":[7,8],\"player\":1,\"sequence\":3,\"target_id\":9,\"tick\":0,\"type\":\"attack\"}",
	"6|sel=[7, 8]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|",
	"7|sel=[]|bld=-1|insp=-1|place=|pend=|am=false|esc=false|menu=false|perf=false|",
	"8|sel=[]|bld=-1|insp=-1|place=|pend=|am=false|esc=false|menu=false|perf=false|",
	"9|sel=[10]|bld=-1|insp=-1|place=frc_supply_center|pend=|am=false|esc=true|menu=false|perf=false||Credits: 10000 | Power: 0/0 | Tick: 0\nUnits: [10] | Place: Supply Cache\n1-9: menu  U: unload | Right: context/move | E: produce | Esc: cancel\n\nLaborer #10 HP 100/100\nA: attack-move click | S: stop | You are blue (P1)",
	"10|sel=[10]|bld=-1|insp=-1|place=frc_supply_center|pend=|am=false|esc=true|menu=false|perf=false|",
	"11|sel=[10]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|{\"builder_id\":10,\"building_kind\":\"frc_supply_center\",\"origin\":[36,26],\"player\":1,\"sequence\":4,\"tick\":0,\"type\":\"build\"}",
	"12|sel=[]|bld=12|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|{\"building_id\":12,\"player\":1,\"sequence\":5,\"tick\":0,\"type\":\"produce\",\"unit_kind\":\"usa_rifle_infantry\"}|Credits: 10000 | Power: 0/0 | Tick: 0\nBarracks #12 | Work 0/300000 | Place: \n1-9: menu  U: unload | Right: context/move | E: produce | Esc: cancel\n\nA: attack-move click | S: stop | You are blue (P1)",
	"13|sel=[]|bld=12|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|{\"building_id\":12,\"player\":1,\"sequence\":6,\"target\":[26.5,16.5],\"tick\":0,\"type\":\"set_rally\"}",
	"14|sel=[10]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|{\"builder_id\":10,\"building_id\":13,\"player\":1,\"sequence\":7,\"tick\":0,\"type\":\"resume_build\"}",
	"15|sel=[]|bld=14|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|{\"player\":1,\"sequence\":8,\"target_id\":14,\"tick\":0,\"type\":\"unload\"}",
	"16|sel=[11]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|{\"entity_ids\":[11],\"player\":1,\"sequence\":9,\"target_id\":14,\"tick\":0,\"type\":\"enter\"}",
	"17|sel=[10]|bld=-1|insp=-1|place=usa_power_plant|pend=|am=false|esc=true|menu=false|perf=false|",
	"18|sel=[]|bld=-1|insp=-1|place=|pend=|am=false|esc=false|menu=false|perf=false|",
	"19|sel=[]|bld=-1|insp=9|place=|pend=|am=false|esc=true|menu=false|perf=false||Credits: 10000 | Power: 0/0 | Tick: 0\nUnits: [] | Place: \n1-9: menu  U: unload | Right: context/move | E: produce | Esc: cancel\n\nEnemy (P2) Battle Tank #9 HP 480/480 | guard\nA: attack-move click | S: stop | You are blue (P1)",
	"20|sel=[10]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|{\"entity_ids\":[10],\"player\":1,\"sequence\":10,\"source_id\":16,\"tick\":0,\"type\":\"gather\"}",
	"21|sel=[10]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false||tick=1",
]

const IC2_ROWS: PackedStringArray = [
	"1|sel=[3]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|",
	"2|sel=[3]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|{\"entity_ids\":[3],\"player\":1,\"sequence\":1,\"target\":[12.5,18.5],\"tick\":16,\"type\":\"move\"}",
	"4|sel=[3]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|{\"entity_ids\":[3],\"player\":1,\"sequence\":2,\"tick\":19,\"type\":\"stop\"}",
	"6|sel=[3]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|",
	"7|sel=[]|bld=-1|insp=-1|place=|pend=|am=false|esc=false|menu=false|perf=false|",
	"8|sel=[]|bld=-1|insp=-1|place=|pend=|am=false|esc=false|menu=false|perf=false|",
	"9|sel=[3]|bld=-1|insp=-1|place=usa_power_plant|pend=|am=false|esc=true|menu=false|perf=false||Credits: 10000 | Power: 0/0 | Tick: 29\nUnits: [3] | Place: Power Plant\n1-9: menu  U: unload | Right: context/move | E: produce | Esc: cancel\n\nBulldozer #3 HP 250/250\nA: attack-move click | S: stop | You are blue (P1)",
	"10|sel=[3]|bld=-1|insp=-1|place=usa_power_plant|pend=|am=false|esc=true|menu=false|perf=false|",
	"11|sel=[3]|bld=-1|insp=-1|place=|pend=|am=false|esc=true|menu=false|perf=false|{\"builder_id\":3,\"building_kind\":\"usa_power_plant\",\"origin\":[10,10],\"player\":1,\"sequence\":3,\"tick\":37,\"type\":\"build\"}",
	"17|sel=[3]|bld=-1|insp=-1|place=usa_power_plant|pend=|am=false|esc=true|menu=false|perf=false|",
	"18|sel=[]|bld=-1|insp=-1|place=|pend=|am=false|esc=false|menu=false|perf=false|",
]
