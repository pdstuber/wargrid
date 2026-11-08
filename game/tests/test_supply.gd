@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/economy_fixture.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const Construction = preload("res://scripts/simulation/construction.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Supply = preload("res://scripts/simulation/supply_collection.gd")

func cases() -> Array[Callable]:
	return [test_source_and_gather_validation,test_dock_timing,test_partial_load_and_conservation,test_dock_competition_and_lookup,test_collection_interruptions,test_dock_loss_recovery,test_ground_dock_cell,test_ground_dock_queue,test_ground_admit_first_waiter_first,test_ground_dock_no_starvation,test_ground_dock_full_perimeter,test_truck_timing,test_dock_loss_recovery_ground,test_ground_truck_recovers_after_blocked_path,test_ground_dock_skips_unwalkable_and_unreachable,test_laborer_timing,test_laborer_docks_share_fairly,test_mixed_waiters_do_not_deadlock,test_air_waiter_ahead_of_earlier_ground_waiter,test_helicopter_on_emptied_pile_waits_its_delay,test_depot_clearance_from_piles,test_build_edge_margin,test_start_slots_obey_placement_rules,test_source_footprint_records,test_ground_dock_on_small_pile,test_neighbouring_small_piles_load_at_once,test_depot_clearance_from_small_pile]

func ready(runner, boxes: int = 8) -> Dictionary:
	var sim = Fixture.make_world(50000)
	var source: int = sim.add_supply_source(Vector2i(24,4),boxes)
	var reactor: int = Fixture.build(runner,sim,"usa_power_plant",Vector2i(5,5))
	var depot: int = Fixture.build(runner,sim,"usa_supply_center",Vector2i(10,4))
	var collector: int = -1
	for unit in sim.snapshot().entities:
		if unit.kind == "usa_collector": collector = unit.id
	return {"sim":sim,"source":source,"reactor":reactor,"depot":depot,"collector":collector}

func until_phase(sim, id: int, phase: String, maximum: int = 1000) -> bool:
	for index in range(maximum):
		if Fixture.object(sim,id).collection.phase == phase: return true
		sim.step()
	return false

func test_source_and_gather_validation(runner) -> bool:
	var sim = Fixture.make_world()
	var before: Dictionary = sim.snapshot()
	for row in [[Vector2i(-1,0),8],[Vector2i(31,31),8],[Vector2i(4,4),8],[Vector2i(24,4),-1]]:
		runner.check(sim.add_supply_source(row[0],row[1]) == -1 and sim.snapshot() == before,"Su1 invalid source unchanged")
	var source: int = sim.add_supply_source(Vector2i(24,4),200)
	runner.check(source == 2 and sim.snapshot().map.blocked_cells.size() == 20,"Su1 source footprint")
	var empty: int = sim.add_supply_source(Vector2i(24,12),0)
	var air: int = sim.spawn(1,Vector2(2.5,2.5),"usa_collector")
	before = sim.snapshot()
	runner.check(not Fixture.send(sim,{"type":"gather","entity_ids":[air],"source_id":empty}).ok and sim.snapshot() == before,"Su1 empty source invalid empty cargo")
	runner.check(not Fixture.send(sim,{"type":"gather","entity_ids":[1,air],"source_id":source}).ok and sim.snapshot() == before,"Su1 mixed gather atomic")
	runner.check(Fixture.send(sim,{"type":"gather","entity_ids":[air],"source_id":source}).ok,"Su1 collector gathers")
	return true

func test_dock_timing(runner) -> bool:
	var sim = Fixture.make_world()
	var source: int = sim.add_supply_source(Vector2i(24,4),8)
	if source == -1:
		runner.check(false,"Su2 source created")
		return true
	var air: int = sim.spawn(1,Vector2(26.0,6.5),"usa_collector")
	runner.check(Fixture.send(sim,{"type":"gather","entity_ids":[air],"source_id":source}).ok,"Su2 gather stationary")
	sim.step()
	var unit: Dictionary = Fixture.object(sim,air)
	runner.check(unit.collection.phase == "loading" and unit.collection.remaining_ticks == 43 and unit.collection.cargo == 0,"Su2 admit43 no decrement")
	Fixture.steps(sim,42)
	unit = Fixture.object(sim,air)
	runner.check(unit.collection.remaining_ticks == 1 and unit.collection.cargo == 0,"Su2 wait42")
	sim.step()
	unit = Fixture.object(sim,air)
	runner.check(unit.collection.cargo == 1 and unit.collection.remaining_ticks == 43 and Fixture.object(sim,source).boxes == 7,"Su2 first box43")
	Fixture.steps(sim,343)
	unit = Fixture.object(sim,air)
	runner.check(unit.collection.cargo == 8 and unit.collection.phase == "loading" and Fixture.object(sim,source).boxes == 0,"Su2 capacity holds the dock for one more delay")
	sim.step()
	unit = Fixture.object(sim,air)
	runner.check(unit.collection.cargo == 8 and unit.collection.phase == "seeking","Su2 capacity departs after the extra delay")
	runner.check(sim.snapshot().players[0].credits == 10000,"Su2 no dock no credits")
	var world: Dictionary = ready(runner)
	if world.collector == -1:
		runner.check(false,"Su2 free collector")
		return true
	sim = world.sim
	runner.check(until_phase(sim,world.collector,"unloading"),"Su2 reaches unloading")
	unit = Fixture.object(sim,world.collector)
	var credits: int = sim.snapshot().players[0].credits
	runner.check(unit.collection.remaining_ticks == 213 and unit.collection.cargo == 8,"Su2 admit213")
	Fixture.steps(sim,212)
	runner.check(sim.snapshot().players[0].credits == credits and Fixture.object(sim,world.collector).collection.remaining_ticks == 1,"Su2 wait212")
	sim.step()
	runner.check(sim.snapshot().players[0].credits == credits + 600 and Fixture.object(sim,world.collector).collection.cargo == 0,"Su2 deposit213 exact")
	return true

func test_partial_load_and_conservation(runner) -> bool:
	for boxes in [9,3]:
		var world: Dictionary = ready(runner,boxes)
		var sim = world.sim
		if world.source == -1:
			runner.check(false,"Su3 source created")
			continue
		var credits: int = sim.snapshot().players[0].credits
		for index in range(2000):
			sim.step()
			var cargo: int = Fixture.object(sim,world.collector).collection.cargo
			var stock: int = Fixture.object(sim,world.source).boxes
			var earned: int = sim.snapshot().players[0].credits - credits
			@warning_ignore("integer_division")
			runner.check(stock >= 0 and cargo >= 0 and stock + cargo + int(earned / 75) == boxes,"Su3 conservation every tick")
			if earned == boxes * 75: break
		runner.check(sim.snapshot().players[0].credits == credits + boxes * 75 and Fixture.object(sim,world.source).boxes == 0 and Fixture.object(sim,world.collector).collection.cargo == 0,"Su3 partial load fully deposited")
		Fixture.steps(sim,100)
		runner.check(sim.snapshot().players[0].credits == credits + boxes * 75,"Su3 idle no earnings")
	return true

func test_dock_competition_and_lookup(runner) -> bool:
	var world: Dictionary = ready(runner,1)
	var sim = world.sim
	if world.source == -1:
		runner.check(false,"Su4 source created")
		return true
	var second: int = sim.spawn(1,Vector2(26.0,6.5),"usa_collector")
	Fixture.send(sim,{"type":"gather","entity_ids":[world.collector,second],"source_id":world.source})
	var credits: int = sim.snapshot().players[0].credits
	for index in range(1500):
		sim.step()
		var source: Dictionary = Fixture.object(sim,world.source)
		var cargo: int = Fixture.object(sim,world.collector).collection.cargo + Fixture.object(sim,second).collection.cargo
		runner.check(source.boxes + cargo + int((sim.snapshot().players[0].credits - credits) / 75) == 1,"Su4 last box atomic")
		if sim.snapshot().players[0].credits == credits + 75: break
	runner.check(sim.snapshot().players[0].credits == credits + 75 and Fixture.object(sim,world.source).active_collector_id == null,"Su4 exactly75 dock released")
	var lone = Fixture.make_world()
	var air: int = lone.spawn(1,Vector2(2.5,2.5),"usa_collector")
	var source: int = lone.add_supply_source(Vector2i(8,8),0)
	runner.check(not Fixture.send(lone,{"type":"gather","entity_ids":[air],"source_id":source}).ok,"Su4 empty rejection")
	runner.check(lone.snapshot().path_queue.is_empty(),"Su4 no ground route for air")
	var waiting = Fixture.make_world()
	var dock: int = waiting.add_supply_source(Vector2i(8,8),10)
	var low: int = waiting.spawn(1,Vector2(10.0,10.5),"usa_collector")
	var active: int = waiting.spawn(1,Vector2(10.0,10.5),"usa_collector")
	var high: int = waiting.spawn(1,Vector2(10.0,10.5),"usa_collector")
	Fixture.send(waiting,{"type":"gather","entity_ids":[active],"source_id":dock})
	waiting.step()
	Fixture.send(waiting,{"type":"gather","entity_ids":[low,high],"source_id":dock})
	waiting.step()
	Fixture.steps(waiting,342)
	runner.check(Fixture.object(waiting,active).collection.cargo == 7 and Fixture.object(waiting,active).collection.remaining_ticks == 1,"Su4 middle-ID active at release boundary")
	Fixture.steps(waiting,44)
	runner.check(Fixture.object(waiting,active).collection.cargo == 8 and Fixture.object(waiting,dock).active_collector_id != high,"Su4 higher waiter cannot bypass earlier lower waiter on release")
	waiting.step()
	runner.check(Fixture.object(waiting,dock).active_collector_id == low and Fixture.object(waiting,low).collection.remaining_ticks == 43,"Su4 lower waiting ID admits once next phase")
	var preferred = Fixture.make_world()
	var near: int = preferred.add_supply_source(Vector2i(8,8),8)
	var far: int = preferred.add_supply_source(Vector2i(24,4),8)
	var probe: int = preferred.spawn(1,Vector2(1.5,1.5),"usa_collector")
	Fixture.send(preferred,{"type":"gather","entity_ids":[probe],"source_id":far})
	preferred.step()
	runner.check(Fixture.object(preferred,probe).collection.target_id == far,"Su4 preferred source beats nearer source")
	preferred.remove_object(far)
	Fixture.steps(preferred,2)
	runner.check(Fixture.object(preferred,probe).collection.target_id == near,"Su4 removed preference falls back to nearest source")
	var retry_world: Dictionary = ready(runner,0)
	var retry = retry_world.sim
	retry.step()
	var idle: Dictionary = Fixture.object(retry,retry_world.collector).collection
	runner.check(idle.phase == "idle" and idle.retry_tick == retry.snapshot().tick + 29,"Su4 exact30-tick retry scheduled")
	var fresh: int = retry.add_supply_source(Vector2i(20,12),8)
	Fixture.steps(retry,29)
	runner.check(Fixture.object(retry,retry_world.collector).collection.phase == "idle","Su4 no early target retry")
	retry.step()
	runner.check(Fixture.object(retry,retry_world.collector).collection.target_id == fresh,"Su4 target lookup at retry boundary")
	var choices = Fixture.make_world(50000)
	var stock: int = choices.add_supply_source(Vector2i(24,4),1)
	Fixture.build(runner,choices,"usa_power_plant",Vector2i(5,5))
	var first_depot: int = Fixture.build(runner,choices,"usa_supply_center",Vector2i(18,3))
	stop_collectors(choices)
	var second_depot: int = Fixture.build(runner,choices,"usa_supply_center",Vector2i(18,7))
	stop_collectors(choices)
	choices.add_player(2,50000)
	var enemy_builder: int = choices.spawn(2,Vector2(14.5,12.5),"usa_builder")
	owned_build(runner,choices,2,enemy_builder,"usa_power_plant",Vector2i(10,16))
	var enemy_depot: int = owned_build(runner,choices,2,enemy_builder,"usa_supply_center",Vector2i(20,10))
	stop_collectors(choices)
	Fixture.send(choices,{"type":"build","builder_id":1,"building_kind":"usa_supply_center","origin":[24,10]})
	choices.step()
	var unfinished: int = choices.snapshot().buildings.back().id
	var loaded: int = choices.spawn(1,Vector2(26.0,6.5),"usa_collector")
	Fixture.send(choices,{"type":"gather","entity_ids":[loaded],"source_id":stock})
	Fixture.steps(choices,87)
	choices.step()
	runner.check(Fixture.object(choices,loaded).collection.cargo == 1 and Fixture.object(choices,loaded).collection.target_id == first_depot and first_depot < second_depot,"Su4 equal nearest depot chooses lower ID")
	runner.check(not Fixture.object(choices,unfinished).completed and Fixture.object(choices,loaded).collection.target_id != unfinished and Fixture.object(choices,loaded).collection.target_id != enemy_depot,"Su4 closer unfinished and enemy depots excluded")
	var tied = Simulation.new([],Vector2i(32,32))
	tied.add_player(1,10000)
	var preferred_source: int = tied.add_supply_source(Vector2i(4,4),8)
	var first_source: int = tied.add_supply_source(Vector2i(9,4),8)
	var second_source: int = tied.add_supply_source(Vector2i(4,9),8)
	var tied_air: int = tied.spawn(1,Vector2(6.0,6.5),"usa_collector")
	Fixture.send(tied,{"type":"gather","entity_ids":[tied_air],"source_id":preferred_source})
	tied.step()
	tied.remove_object(preferred_source)
	Fixture.steps(tied,2)
	runner.check(first_source < second_source and Fixture.object(tied,tied_air).collection.target_id == first_source,"Su4 equal nearest source chooses lower ID")
	return true

func test_collection_interruptions(runner) -> bool:
	for phase in ["flying_source","loading","unloading"]:
		var world: Dictionary = ready(runner,8)
		var sim = world.sim
		runner.check(until_phase(sim,world.collector,phase),"Su5 reaches " + phase)
		if phase == "loading": Fixture.steps(sim,43)
		var unit: Dictionary = Fixture.object(sim,world.collector)
		var cargo: int = unit.collection.cargo
		var before: Dictionary = sim.snapshot()
		runner.check(not Fixture.send(sim,{"type":"gather","entity_ids":[1,world.collector],"source_id":world.source}).ok and sim.snapshot() == before,"Su5 invalid replacement unchanged")
		var payload: Dictionary = {"type":"stop","entity_ids":[world.collector]}
		if phase == "loading": payload = {"type":"move","entity_ids":[world.collector],"target":[20.5,20.5]}
		runner.check(Fixture.send(sim,payload).ok,"Su5 interruption accepted")
		sim.step()
		unit = Fixture.object(sim,world.collector)
		runner.check(not unit.collection.enabled and unit.collection.cargo == cargo and Fixture.object(sim,world.source).active_collector_id == null and Fixture.object(sim,world.depot).active_collector_id == null,"Su5 dock released cargo retained")
		runner.check(Fixture.send(sim,{"type":"gather","entity_ids":[world.collector],"source_id":world.source}).ok,"Su5 resume including exhausted loaded source")
		sim.step()
		if cargo > 0: runner.check(Fixture.object(sim,world.collector).collection.target_id == world.depot,"Su5 cargo delivers first")
	return true

func test_dock_loss_recovery(runner) -> bool:
	for phase in ["flying_source","waiting_source","loading","loading_final","flying_depot","waiting_depot","unloading"]:
		var world: Dictionary = ready(runner,9 if phase == "waiting_depot" else 16)
		var sim = world.sim
		if phase == "waiting_source":
			var holder: int = sim.spawn(1,Vector2(26.0,6.5),"usa_collector")
			Fixture.send(sim,{"type":"gather","entity_ids":[holder],"source_id":world.source})
			sim.step()
		if phase == "waiting_depot":
			runner.check(until_phase(sim,world.collector,"flying_depot"),"Su6 first full collector returning")
			world.collector = sim.spawn(1,Vector2(26.0,6.5),"usa_collector")
			Fixture.send(sim,{"type":"gather","entity_ids":[world.collector],"source_id":world.source})
		var observed: String = "loading" if phase == "loading_final" else phase
		runner.check(until_phase(sim,world.collector,observed),"Su6 reaches " + phase)
		if phase == "loading": Fixture.steps(sim,43)
		if phase == "loading_final": Fixture.steps(sim,42)
		if phase == "unloading": Fixture.steps(sim,212)
		var cargo: int = Fixture.object(sim,world.collector).collection.cargo
		var target: int = world.depot if phase in ["flying_depot","waiting_depot","unloading"] else world.source
		var credits_before: int = sim.snapshot().players[0].credits
		runner.check(sim.remove_object(target).ok,"Su6 target removed " + phase)
		runner.check(Fixture.object(sim,world.collector).collection.cargo == cargo and Fixture.object(sim,world.collector).collection.target_id == null,"Su6 lost target retains cargo " + phase)
		var before: Dictionary = sim.snapshot()
		runner.check(not sim.remove_object(target).ok and sim.snapshot() == before,"Su6 removal once")
		if cargo > 0 and target == world.depot:
			Fixture.steps(sim,40)
			runner.check(Fixture.object(sim,world.collector).collection.cargo == cargo and sim.snapshot().players[0].credits == credits_before,"Su6 no depot preserves load")
			var depot: int = Fixture.build(runner,sim,"usa_supply_center",Vector2i(10,10))
			runner.check(depot != -1 and until_phase(sim,world.collector,"unloading"),"Su6 replacement depot recovered")
			for other in sim.snapshot().entities:
				if other.kind == "usa_collector" and other.id != world.collector: Fixture.send(sim,{"type":"stop","entity_ids":[other.id]})
			sim.step()
			var before_deposit: int = sim.snapshot().players[0].credits
			Fixture.steps(sim,212)
			runner.check(Fixture.object(sim,world.collector).collection.cargo == 0 and sim.snapshot().players[0].credits == before_deposit + cargo * 75,"Su6 surviving cargo credited exactly")
		else:
			Fixture.steps(sim,500)
			runner.check(Fixture.object(sim,world.collector).collection.cargo == 0,"Su6 partial delivered or empty retry")
		runner.check(sim.remove_object(world.collector).ok,"Su6 collector removal")
		for source in sim.snapshot().sources: runner.check(source.active_collector_id != world.collector,"Su6 no source dangling ID")
		for building in sim.snapshot().buildings: runner.check(building.active_collector_id != world.collector,"Su6 no depot dangling ID")
	var active_world: Dictionary = ready(runner,16)
	var active_sim = active_world.sim
	runner.check(until_phase(active_sim,active_world.collector,"loading"),"Su6 active destruction setup")
	Fixture.steps(active_sim,43)
	var lost: int = Fixture.object(active_sim,active_world.collector).collection.cargo
	var stock: int = Fixture.object(active_sim,active_world.source).boxes
	var credits: int = active_sim.snapshot().players[0].credits
	runner.check(lost == 1 and Fixture.object(active_sim,active_world.source).active_collector_id == active_world.collector,"Su6 known active cargo")
	active_sim.remove_object(active_world.collector)
	runner.check(Fixture.object(active_sim,active_world.source).active_collector_id == null and Fixture.object(active_sim,active_world.source).boxes == stock and active_sim.snapshot().players[0].credits == credits,"Su6 active collector death loses only carried box and releases dock")
	return true

func stop_collectors(sim) -> void:
	for unit in sim.snapshot().entities:
		if unit.kind == "usa_collector": Fixture.send(sim,{"type":"stop","entity_ids":[unit.id],"player":unit.owner})
	sim.step()

func owned_build(runner, sim, owner: int, builder: int, kind: String, origin: Vector2i) -> int:
	var id: int = sim.snapshot().next_entity_id
	var result: Dictionary = Fixture.send(sim,{"type":"build","player":owner,"builder_id":builder,"building_kind":kind,"origin":[origin.x,origin.y]})
	runner.check(result.ok,"Su4 owned fixture accepted " + kind)
	if not result.ok: return -1
	for index in range(3000):
		sim.step()
		if Fixture.object(sim,id).get("completed",false): return id
	runner.check(false,"Su4 owned fixture completes " + kind)
	return -1

func truck(sim, position: Vector2) -> int:
	var id: int = sim.spawn(1,position,"china_collector")
	assert(id > 0)
	return id

func gather(sim, ids: Array, source: int) -> void:
	Fixture.send(sim,{"type":"gather","entity_ids":ids,"source_id":source})

func test_ground_dock_cell(runner) -> bool:
	var sim = Fixture.make_world()
	var source: int = sim.add_supply_source(Vector2i(24,4),8)
	var unit: int = truck(sim,Vector2(30.5,5.5))
	gather(sim,[unit],source)
	until_phase(sim,unit,"loading",400)
	var loaded: Dictionary = Fixture.object(sim,unit)
	runner.check(loaded.collection.get("dock") == [28,5],"Gd1 claims the nearest perimeter cell on its side")
	runner.check(loaded.collection.phase == "loading" and loaded.position == [28.25,5.5],"Gd1 loads only on the dock arrival point, a quarter cell toward the pile")
	return true

func test_ground_dock_queue(runner) -> bool:
	var sim = Fixture.make_world()
	var source: int = sim.add_supply_source(Vector2i(24,4),8)
	var first: int = truck(sim,Vector2(30.5,5.5))
	var second: int = truck(sim,Vector2(31.5,5.5))
	gather(sim,[first,second],source)
	until_phase(sim,second,"waiting_source")
	var a: Dictionary = Fixture.object(sim,first)
	var b: Dictionary = Fixture.object(sim,second)
	runner.check(a.collection.dock == [28,5] and b.collection.dock == [28,4],"Gd2 both trucks want cell 28,5; the second takes the next nearest")
	runner.check(a.collection.phase == "loading" and b.collection.phase == "waiting_source" and a.collection.dock != b.collection.dock,"Gd2 second truck waits on its own cell")
	runner.check(a.position != b.position,"Gd2 no overlap")
	for index in range(600):
		sim.step()
		if Fixture.object(sim,first).collection.phase != "loading": break
	runner.check(Fixture.object(sim,first).collection.get("dock") == null and Fixture.object(sim,second).collection.phase == "loading","Gd2 waiter loads the tick the active truck releases")
	return true

func test_ground_admit_first_waiter_first(runner) -> bool:
	var sim = Fixture.make_world()
	var source: int = sim.add_supply_source(Vector2i(24,4),30)
	var far: int = truck(sim,Vector2(31.5,5.5))
	var near: int = truck(sim,Vector2(29.5,5.5))
	var mid: int = truck(sim,Vector2(30.5,6.5))
	gather(sim,[far,near,mid],source)
	var began: Dictionary = {}
	for index in range(2000):
		sim.step()
		for id in [far,mid]:
			if not began.has(id) and Fixture.object(sim,id).collection.phase == "waiting_source": began[id] = index
		if began.size() == 2: break
	runner.check(Fixture.object(sim,near).collection.phase == "loading","Gd4 the nearest truck loads first")
	runner.check(began[far] != began[mid],"Gd4 the two others begin waiting on different ticks")
	var first: int = far if began[far] < began[mid] else mid
	var second: int = mid if first == far else far
	for index in range(600):
		sim.step()
		if Fixture.object(sim,near).collection.phase != "loading": break
	sim.step()
	runner.check(Fixture.object(sim,first).collection.phase == "loading" and Fixture.object(sim,second).collection.phase == "waiting_source","Gd4 the truck that began waiting first loads next, not the lower id")
	return true

func test_ground_dock_no_starvation(runner) -> bool:
	var sim = Fixture.make_world(50000)
	Fixture.build(runner,sim,"usa_power_plant",Vector2i(5,5))
	Fixture.build(runner,sim,"usa_supply_center",Vector2i(10,10))
	var source: int = sim.add_supply_source(Vector2i(14,10),400)
	stop_collectors(sim)
	var ids: Array = []
	for index in range(3): ids.append(truck(sim,Vector2(13.5 + index,16.5)))
	gather(sim,ids,source)
	var loads: Dictionary = {}
	for id in ids: loads[id] = 0
	var cargo: Dictionary = {}
	for id in ids: cargo[id] = 0
	for index in range(1500):
		sim.step()
		for id in ids:
			var now: int = Fixture.object(sim,id).collection.cargo
			if now > cargo[id]: loads[id] = loads[id] + 1
			cargo[id] = now
	var counts: Array = loads.values()
	runner.check(counts.min() > 0,"Gd5 every truck loads at the shared dock, got " + str(counts))
	runner.check(counts.max() - counts.min() <= 8,"Gd5 loads stay level across trucks, got " + str(counts))
	return true

func test_ground_dock_full_perimeter(runner) -> bool:
	var sim = Fixture.make_world()
	var source: int = sim.add_supply_source(Vector2i(24,4),200)
	var holders: Array = []
	for y in range(3,10):
		for x in range(23,29):
			if x in [24,25,26,27] and y in [4,5,6,7,8]: continue
			holders.append(truck(sim,Vector2(x + 0.5,y + 0.5)))
	runner.check(holders.size() == 22,"Gd3 twenty-two perimeter cells")
	var extra: int = truck(sim,Vector2(30.5,10.5))
	gather(sim,holders + [extra],source)
	sim.step()
	var idle: Dictionary = Fixture.object(sim,extra).collection
	runner.check(idle.phase == "idle" and idle.retry_tick == sim.snapshot().tick + 29 and not idle.has("dock"),"Gd3 extra truck idles with a retry 30 ticks out")
	var freed: Array = Fixture.object(sim,holders[5]).collection.dock
	sim.remove_object(holders[5])
	Fixture.steps(sim,30)
	runner.check(Fixture.object(sim,extra).collection.get("dock") == freed,"Gd3 extra truck takes the freed cell")
	runner.check(until_phase(sim,extra,"loading",4000),"Gd3 extra truck loads in the end")
	return true

func test_truck_timing(runner) -> bool:
	var sim = Fixture.make_world()
	var source: int = sim.add_supply_source(Vector2i(24,4),40)
	var depot: int = Fixture.add_completed(sim,1,"china_supply_center",Vector2i(10,4))
	var unit: int = truck(sim,Vector2(28.5,5.5))
	gather(sim,[unit],source)
	runner.check(until_phase(sim,unit,"loading"),"Gt1 loads")
	var collection: Dictionary = Fixture.object(sim,unit).collection
	runner.check(collection.remaining_ticks == 38,"Gt1 admit38")
	var ticks: int = 0
	while Fixture.object(sim,unit).collection.phase == "loading":
		sim.step()
		ticks += 1
	runner.check(ticks == 190 and Fixture.object(sim,unit).collection.cargo == 4,"Gt1 four boxes at 30 ticks each, one more delay to leave")
	runner.check(until_phase(sim,unit,"unloading"),"Gt1 reaches the depot")
	var credits: int = sim.snapshot().players[0].credits
	runner.check(Fixture.object(sim,unit).collection.remaining_ticks == 37 and Fixture.object(sim,unit).collection.target_id == depot,"Gt1 admit37")
	Fixture.steps(sim,36)
	runner.check(sim.snapshot().players[0].credits == credits,"Gt1 wait36")
	sim.step()
	runner.check(sim.snapshot().players[0].credits == credits + 300,"Gt1 trip pays 300")
	var small = Fixture.make_world()
	var pile: int = small.add_supply_source(Vector2i(24,4),3)
	var partial: int = truck(small,Vector2(28.5,5.5))
	gather(small,[partial],pile)
	until_phase(small,partial,"loading")
	Fixture.steps(small,114)
	runner.check(Fixture.object(small,partial).collection.cargo == 3 and Fixture.object(small,partial).collection.phase == "loading","Gt2 empty pile still holds the dock for one more delay")
	Fixture.steps(small,38)
	runner.check(Fixture.object(small,partial).collection.phase != "loading" and Fixture.object(small,partial).collection.cargo == 3,"Gt2 leaves after the extra delay")
	return true

func test_dock_loss_recovery_ground(runner) -> bool:
	for phase in ["flying_source","waiting_source","loading","flying_depot","unloading"]:
		var sim = Fixture.make_world()
		var source: int = sim.add_supply_source(Vector2i(24,4),40)
		var other_source: int = sim.add_supply_source(Vector2i(24,12),40)
		var depot: int = Fixture.add_completed(sim,1,"china_supply_center",Vector2i(10,4))
		var other_depot: int = Fixture.add_completed(sim,1,"china_supply_center",Vector2i(10,12))
		var unit: int = truck(sim,Vector2(29.5,6.5) if phase == "waiting_source" else Vector2(14.5,8.5))
		var at_depot: bool = phase in ["flying_depot","unloading"]
		if at_depot: sim._entities[unit].collection.cargo = 4
		if phase == "waiting_source":
			var holder: int = truck(sim,Vector2(29.5,5.5))
			gather(sim,[holder],source)
			sim.step()
		gather(sim,[unit],source)
		runner.check(until_phase(sim,unit,phase,2000),"Gl1 reaches " + phase)
		var target: int = (depot if Fixture.object(sim,unit).collection.target_id == depot else other_depot) if at_depot else source
		runner.check(sim.remove_object(target).ok,"Gl1 target removed " + phase)
		var lost: Dictionary = Fixture.object(sim,unit).collection
		runner.check(lost.target_id == null and not lost.has("dock"),"Gl1 dock erased " + phase)
		Fixture.steps(sim,2)
		var again: Dictionary = Fixture.object(sim,unit).collection
		var wanted: Array = [depot,other_depot] if at_depot else [source,other_source]
		runner.check(again.target_id != null and again.target_id != target and again.target_id in wanted and again.has("dock"),"Gl1 re-seeks with a new dock " + phase)
	return true

func wall(gap: bool) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(32):
		if gap and y == 20: continue
		cells.append(Vector2i(16,y))
	return cells

func test_ground_truck_recovers_after_blocked_path(runner) -> bool:
	var sim = Simulation.new(wall(true),Vector2i(32,32))
	sim.add_player(1,0)
	var source: int = sim.add_supply_source(Vector2i(4,4),40)
	Fixture.add_completed(sim,1,"china_supply_center",Vector2i(24,4))
	var unit: int = truck(sim,Vector2(28.5,20.5))
	gather(sim,[unit],source)
	Fixture.steps(sim,5)
	sim.replace_blocked_cells(wall(false))
	Fixture.steps(sim,100)
	runner.check(Fixture.object(sim,unit).collection.get("dock") == null,"Gb1 cut path releases the held dock cell")
	sim.replace_blocked_cells(wall(true))
	Fixture.steps(sim,2000)
	runner.check(sim.snapshot().players[0].credits > 0,"Gb1 truck delivers after the path reopens")
	return true

func test_ground_dock_skips_unwalkable_and_unreachable(runner) -> bool:
	var solids: Array[Vector2i] = []
	for cell in [Vector2i(28,4),Vector2i(28,5),Vector2i(28,6),Vector2i(29,6),Vector2i(29,7),Vector2i(29,8),Vector2i(28,8)]: solids.append(cell)
	var sim = Simulation.new(solids,Vector2i(32,32))
	sim.add_player(1,0)
	var source: int = sim.add_supply_source(Vector2i(24,4),8)
	var unit: int = truck(sim,Vector2(30.5,5.5))
	gather(sim,[unit],source)
	sim.step()
	runner.check(Fixture.object(sim,unit).collection.get("dock") == [28,3],"Gd4 skips blocked cells 28,4-6 and the sealed pocket 28,7 for the reachable 28,3")
	var closed: Array[Vector2i] = []
	for y in range(3,10):
		for x in range(23,29):
			if not (x in [24,25,26,27] and y in [4,5,6,7,8]): closed.append(Vector2i(x,y))
	var shut = Simulation.new(closed,Vector2i(32,32))
	shut.add_player(1,0)
	var pile: int = shut.add_supply_source(Vector2i(24,4),8)
	var outside: int = truck(shut,Vector2(30.5,5.5))
	gather(shut,[outside],pile)
	shut.step()
	var idle: Dictionary = Fixture.object(shut,outside).collection
	runner.check(idle.phase == "idle" and idle.retry_tick == shut.snapshot().tick + 29 and not idle.has("dock"),"Gd4 no walkable reachable ring cell: idle with a retry 30 ticks out")
	return true

func laborer(sim, position: Vector2) -> int:
	var id: int = sim.spawn(1,position,"frc_builder")
	assert(id > 0)
	return id

func test_laborer_timing(runner) -> bool:
	var sim = Fixture.make_world()
	var source: int = sim.add_supply_source(Vector2i(24,4),40)
	var depot: int = Fixture.add_completed(sim,1,"frc_supply_center",Vector2i(10,4))
	var unit: int = laborer(sim,Vector2(28.5,5.5))
	gather(sim,[unit],source)
	runner.check(until_phase(sim,unit,"loading"),"Lb1 loads")
	runner.check(Fixture.object(sim,unit).collection.remaining_ticks == 42,"Lb1 loads its box 42 ticks after admission")
	var ticks: int = 0
	while Fixture.object(sim,unit).collection.phase == "loading":
		sim.step()
		ticks += 1
	runner.check(ticks == 84 and Fixture.object(sim,unit).collection.cargo == 1,"Lb1 leaves 84 ticks after admission with one box, got %d" % ticks)
	runner.check(until_phase(sim,unit,"unloading"),"Lb1 reaches the supply center")
	var credits: int = sim.snapshot().players[0].credits
	runner.check(Fixture.object(sim,unit).collection.remaining_ticks == 45 and Fixture.object(sim,unit).collection.target_id == depot,"Lb1 unloads in 45 ticks")
	Fixture.steps(sim,44)
	runner.check(sim.snapshot().players[0].credits == credits,"Lb1 wait44")
	sim.step()
	runner.check(sim.snapshot().players[0].credits == credits + 75,"Lb1 a trip pays 75")
	return true

func test_laborer_docks_share_fairly(runner) -> bool:
	var sim = Fixture.make_world(50000)
	Fixture.add_completed(sim,1,"frc_supply_center",Vector2i(10,10))
	var source: int = sim.add_supply_source(Vector2i(14,10),400)
	stop_collectors(sim)
	var ids: Array = []
	for index in range(3): ids.append(laborer(sim,Vector2(13.5 + index,16.5)))
	gather(sim,ids,source)
	var loads: Dictionary = {}
	var cargo: Dictionary = {}
	for id in ids:
		loads[id] = 0
		cargo[id] = 0
	var stacked: int = 0
	for index in range(1500):
		sim.step()
		var docked: Array = []
		for id in ids:
			var unit: Dictionary = Fixture.object(sim,id)
			var collection: Dictionary = unit.collection
			if collection.phase in ["loading","unloading"]:
				if docked.has(unit.position): stacked += 1
				docked.append(unit.position)
			if collection.cargo > cargo[id]: loads[id] = loads[id] + 1
			cargo[id] = collection.cargo
	var counts: Array = loads.values()
	runner.check(counts.min() > 0 and counts.max() - counts.min() <= 8,"Lb2 every laborer loads and loads stay level, got " + str(counts))
	runner.check(stacked == 0,"Lb2 on no tick do two laborers dock on the same cell")
	return true

func test_mixed_waiters_do_not_deadlock(runner) -> bool:
	var sim = Fixture.make_world()
	var source: int = sim.add_supply_source(Vector2i(24,4),30)
	var ground: int = truck(sim,Vector2(28.5,5.5))
	var air: int = sim.spawn(1,Vector2(26.0,6.5),"usa_collector")
	gather(sim,[ground,air],source)
	sim.step()
	var waiting: Dictionary = {ground: {"remaining_ticks": 40, "dock": [28,5]}, air: {"remaining_ticks": 0}}
	for id: int in waiting:
		var collection: Dictionary = sim._entities[id].collection
		collection.phase = "waiting_source"
		collection.target_id = source
		for key: String in waiting[id]: collection[key] = waiting[id][key]
	sim._entities[ground].position = [28.5,5.5]
	sim._entities[air].position = [26.0,6.5]
	for id: int in waiting: sim._stop_unit(sim._entities[id])
	sim._sources[source].active_collector_id = null
	for index in range(5): sim.step()
	var loading: Array = [ground, air].filter(func(id: int) -> bool: return Fixture.object(sim,id).collection.phase == "loading")
	runner.check(loading.size() == 1 and sim._sources[source].active_collector_id == loading[0],"Gd9 a ground and an air waiter on one pile: exactly one loads (%s)" % [loading])
	return true

func test_air_waiter_ahead_of_earlier_ground_waiter(runner) -> bool:
	var sim = Fixture.make_world()
	var source: int = sim.add_supply_source(Vector2i(24,4),30)
	var ground: int = truck(sim,Vector2(28.5,5.5))
	var air: int = sim.spawn(1,Vector2(26.0,6.5),"usa_collector")
	gather(sim,[ground,air],source)
	sim.step()
	var waiting: Dictionary = {ground: {"remaining_ticks": 40, "dock": [28,5]}, air: {"remaining_ticks": 1000}}
	for id: int in waiting:
		var collection: Dictionary = sim._entities[id].collection
		collection.phase = "waiting_source"
		collection.target_id = source
		for key: String in waiting[id]: collection[key] = waiting[id][key]
	sim._entities[ground].position = [28.25,5.5]
	sim._entities[air].position = [26.0,6.5]
	for id: int in waiting: sim._stop_unit(sim._entities[id])
	sim._sources[source].active_collector_id = null
	for index in range(5): sim.step()
	runner.check(sim._sources[source].active_collector_id == air and Fixture.object(sim,air).collection.phase == "loading","Gd10 an air arrival is admitted ahead of an earlier ground waiter")
	return true

func test_helicopter_on_emptied_pile_waits_its_delay(runner) -> bool:
	var world: Dictionary = ready(runner,3)
	var sim = world.sim
	var delay: int = Registry.collects("usa_collector").load_ticks
	runner.check(until_phase(sim,world.collector,"loading",600),"Gd11 helicopter starts loading")
	var ticks: int = 0
	while Fixture.object(sim,world.collector).collection.phase == "loading" and ticks < 1000:
		sim.step()
		ticks += 1
	runner.check(ticks == 4 * delay and Fixture.object(sim,world.collector).collection.cargo == 3,"Gd11 three boxes then one more delay before it leaves, got %d ticks" % ticks)
	return true

func placement(kind: String, origin: Vector2i, pile: Variant = null, size: Vector2i = Registry.SOURCE_FOOTPRINT) -> bool:
	var faction: String = kind.split("_")[0]
	var sim = Fixture.make_world(50000)
	var builder: int = sim.spawn(1,Vector2(4.5,20.5),faction + "_builder")
	if faction != "frc": Fixture.add_completed(sim,1,faction + "_power_plant",Vector2i(2,26))
	if pile != null: sim.add_supply_source(pile,50,size)
	return sim.preview_build(1,builder,kind,origin).ok

func test_depot_clearance_from_piles(runner) -> bool:
	for kind in ["usa_supply_center","china_supply_center","frc_supply_center"]:
		var pile := Vector2i(10,10)
		runner.check(not placement(kind,Vector2i(14,10),pile),"Pl1 %s touching a pile is refused" % kind)
		runner.check(not placement(kind,Vector2i(10,15),pile),"Pl1 %s touching a pile below is refused" % kind)
		runner.check(not placement(kind,Vector2i(7,8),pile),"Pl1 %s touching a pile diagonally is refused" % kind)
		runner.check(not placement(kind,Vector2i(7,7),pile) and placement(kind,Vector2i(7,7)),"Pl1 %s touching a pile only at a corner is refused" % kind)
		runner.check(placement(kind,Vector2i(15,10),pile),"Pl1 %s one free cell from a pile is accepted" % kind)
		runner.check(placement(kind,Vector2i(14,10)),"Pl1 %s needs no clearance without a pile" % kind)
	runner.check(placement("usa_power_plant",Vector2i(14,10),Vector2i(10,10)),"Pl1 other buildings may touch a pile")
	return true

func test_build_edge_margin(runner) -> bool:
	for kind in ["usa_supply_center","china_supply_center","frc_supply_center"]:
		runner.check(not placement(kind,Vector2i(0,10)) and not placement(kind,Vector2i(10,0)),"Pl2 %s on the first cell of the map is refused" % kind)
		runner.check(placement(kind,Vector2i(1,10)) and placement(kind,Vector2i(10,1)),"Pl2 %s one cell in is accepted" % kind)
		runner.check(not placement(kind,Vector2i(29,10)) and not placement(kind,Vector2i(10,29)),"Pl2 %s against the far edge is refused" % kind)
		runner.check(placement(kind,Vector2i(28,10)) and placement(kind,Vector2i(10,28)),"Pl2 %s one cell from the far edge is accepted" % kind)
	return true

func test_start_slots_obey_placement_rules(runner) -> bool:
	var dir := DirAccess.open("res://data/maps")
	var paths: Array[String] = []
	for file: String in dir.get_files():
		if file.ends_with(".json"): paths.append("res://data/maps/" + file)
	runner.check(paths.size() >= 2,"Pl3 found the map files")
	for path in paths:
		var map: Dictionary = MapData.load(path)
		var seats: Array[Dictionary] = []
		var sim = MapData.create(map,seats)
		for start: Dictionary in map.starts:
			for kind: String in Registry.buildings():
				var definition: Dictionary = Registry.building_view(kind)
				if not Registry.kind(kind).has("slot") or definition.is_empty(): continue
				var origin: Vector2i = MapData.slot(map,int(start.seat),kind)
				var error: String = Construction.footprint_error(sim,Construction.cells(kind,origin),kind)
				runner.check(error.is_empty(),"Pl3 %s seat %d %s slot %s: %s" % [path.get_file(),int(start.seat),kind,str(origin),error])
	return true

func test_source_footprint_records(runner) -> bool:
	var sim = Fixture.make_world()
	var plain: Array = ["active_collector_id","boxes","id","origin"]
	var dock: int = sim.add_supply_source(Vector2i(24,4),200)
	var same: int = sim.add_supply_source(Vector2i(24,12),200,Registry.SOURCE_FOOTPRINT,false)
	var dock_keys: Array = Fixture.object(sim,dock).keys()
	dock_keys.sort()
	var same_keys: Array = Fixture.object(sim,same).keys()
	same_keys.sort()
	runner.check(dock_keys == plain and same_keys == plain,"Fp1 default sources keep today's record keys")
	var pile: int = sim.add_supply_source(Vector2i(20,4),50,Vector2i.ONE,true)
	var record: Dictionary = Fixture.object(sim,pile)
	runner.check(record.footprint == [1,1] and record.delete_when_empty == true and record.boxes == 50,"Fp1 small pile record")
	var blocked: Array = sim.snapshot().map.blocked_cells
	runner.check(blocked.size() == 41 and blocked.has([20,4]) and not blocked.has([21,4]) and not blocked.has([20,5]),"Fp1 a 1x1 pile blocks one cell")
	runner.check(Registry.source_footprint(record) == Vector2i.ONE and Registry.source_footprint(Fixture.object(sim,dock)) == Vector2i(4,5) and Registry.source_footprint({"footprint":[1.0,1.0]}) == Vector2i.ONE,"Fp1 one lookup for records and parsed JSON")
	var before: Dictionary = sim.snapshot()
	for row in [[Vector2i(10,20),Vector2i(0,1)],[Vector2i(10,20),Vector2i(1,-1)],[Vector2i(25,5),Vector2i.ONE]]:
		runner.check(sim.add_supply_source(row[0],50,row[1],true) == -1 and sim.snapshot() == before,"Fp1 invalid or overlapping footprint refused " + str(row))
	runner.check(sim.add_supply_source(Vector2i(21,5),50,Vector2i.ONE,true) > 0,"Fp1 diagonal neighbour piles are allowed, as on Dry Wells")
	return true

func test_ground_dock_on_small_pile(runner) -> bool:
	var sim = Fixture.make_world()
	var pile: int = sim.add_supply_source(Vector2i(24,4),8,Vector2i.ONE,true)
	runner.check(Supply._ring(Fixture.object(sim,pile)).size() == 8 and Supply.center(Fixture.object(sim,pile)) == [24.5,4.5],"Fp2 1x1 ring and centre")
	var unit: int = truck(sim,Vector2(30.5,4.5))
	gather(sim,[unit],pile)
	runner.check(until_phase(sim,unit,"loading",400),"Fp2 truck loads at a small pile")
	var loaded: Dictionary = Fixture.object(sim,unit)
	runner.check(loaded.collection.dock == [25,4] and loaded.position == [25.25,4.5],"Fp2 dock on the ring, a quarter cell toward the pile")
	return true

func test_neighbouring_small_piles_load_at_once(runner) -> bool:
	var sim = Fixture.make_world()
	var upper: int = sim.add_supply_source(Vector2i(24,4),8,Vector2i.ONE,true)
	var lower: int = sim.add_supply_source(Vector2i(24,6),8,Vector2i.ONE,true)
	var a: int = truck(sim,Vector2(30.5,4.5))
	var b: int = truck(sim,Vector2(30.5,6.5))
	gather(sim,[a],upper)
	gather(sim,[b],lower)
	var both: bool = false
	for index in range(400):
		sim.step()
		if Fixture.object(sim,a).collection.phase == "loading" and Fixture.object(sim,b).collection.phase == "loading":
			both = true
			break
	runner.check(both and Fixture.object(sim,upper).active_collector_id == a and Fixture.object(sim,lower).active_collector_id == b,"Fp3 two piles two cells apart serve one collector each at the same time")
	return true

func test_depot_clearance_from_small_pile(runner) -> bool:
	var pile := Vector2i(10,10)
	for kind in ["usa_supply_center","china_supply_center","frc_supply_center"]:
		for origin in [Vector2i(11,10),Vector2i(7,10),Vector2i(10,11),Vector2i(10,7),Vector2i(7,7)]:
			runner.check(not placement(kind,origin,pile,Vector2i.ONE),"Fp4 %s at %s within one cell of a 1x1 pile is refused" % [kind,origin])
		for origin in [Vector2i(12,10),Vector2i(6,10),Vector2i(10,12),Vector2i(10,6),Vector2i(6,6)]:
			runner.check(placement(kind,origin,pile,Vector2i.ONE),"Fp4 %s at %s one free cell from a 1x1 pile is accepted" % [kind,origin])
	runner.check(placement("usa_power_plant",Vector2i(11,10),pile,Vector2i.ONE),"Fp4 other buildings may touch a small pile")
	return true
