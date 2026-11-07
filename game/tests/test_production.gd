@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/economy_fixture.gd")
const Construction = preload("res://scripts/simulation/construction.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Production = preload("res://scripts/simulation/production.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")

func cases() -> Array[Callable]:
	return [test_producer_and_free_collector,test_fifo_payment_and_cancel,test_blocked_exit,test_production_power_and_removal,test_default_rally_mirrored,test_production_never_stalls,test_set_rally_applies_to_next_spawn,test_rally_blocked_cell_falls_back,test_set_rally_same_tick_cases,test_supply_center_spawns_ground_truck,test_quantity_trains_two,test_quantity_rally_on_free_exit]

func ready(runner) -> Dictionary:
	var sim = Fixture.make_world(50000)
	var reactor: int = Fixture.build(runner,sim,"usa_power_plant",Vector2i(5,5))
	var depot: int = Fixture.build(runner,sim,"usa_supply_center",Vector2i(10,4))
	var factory: int = Fixture.build(runner,sim,"usa_factory",Vector2i(16,4))
	return {"sim":sim,"reactor":reactor,"depot":depot,"factory":factory}

func produce(sim, id: int, kind: String = "usa_light_vehicle") -> Dictionary:
	return Fixture.send(sim,{"type":"produce","building_id":id,"unit_kind":kind})

func test_producer_and_free_collector(runner) -> bool:
	var world: Dictionary = ready(runner)
	var sim = world.sim
	var collectors: Array = sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "usa_collector")
	runner.check(collectors.size() == 1,"P1 exactly one free collector")
	if not collectors.is_empty(): runner.check(collectors[0].collection.cargo == 0 and collectors[0].collection.enabled,"P1 free collector enabled empty")
	Fixture.steps(sim,10)
	runner.check(sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "usa_collector").size() == 1,"P1 grant never repeats")
	for row in [[world.factory,"usa_collector"],[world.depot,"usa_light_vehicle"],[999,"usa_light_vehicle"]]:
		var before: Dictionary = sim.snapshot()
		runner.check(not produce(sim,row[0],row[1]).ok and sim.snapshot() == before,"P1 invalid producer atomic")
	runner.check(produce(sim,world.depot,"usa_collector").ok,"P1 paid collector accepted")
	sim.step()
	var queue: Array = Fixture.object(sim,world.depot).queue
	runner.check(queue.size() == 1 and sim.snapshot().players[0].credits == 44000,"P1 paid immediate")
	if not queue.is_empty():
		queue[0].paid_cost = 0
		runner.check(Fixture.object(sim,world.depot).queue[0].paid_cost == 1200,"P1 queue copied")
	var next: int = sim.snapshot().next_entity_id
	Fixture.steps(sim,299)
	runner.check(Fixture.object(sim,next).collection.phase == "seeking" and Fixture.object(sim,next).order == null,"P1 completion-spawned paid collector inactive until next tick")
	sim.step()
	runner.check(Fixture.object(sim,next).collection.phase == "idle","P1 new collector activates following tick")
	var grant = Fixture.make_world()
	grant.add_supply_source(Vector2i(24,4),8)
	Fixture.build(runner,grant,"usa_power_plant",Vector2i(5,5))
	Fixture.build(runner,grant,"usa_supply_center",Vector2i(10,4))
	var free: Dictionary = grant.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "usa_collector")[0]
	runner.check(free.collection.phase == "seeking" and free.order == null and free.position == [11.5,5.5],"P1 free completion collector also inactive until next tick")
	return true

func test_fifo_payment_and_cancel(runner) -> bool:
	var world: Dictionary = ready(runner)
	var sim = world.sim
	for index in range(2): runner.check(produce(sim,world.factory).ok,"P2 paid enqueue")
	sim.step()
	var queue: Array = Fixture.object(sim,world.factory).queue
	runner.check(queue.size() == 2 and sim.snapshot().players[0].credits == 43800,"P2 charge1400")
	if queue.size() != 2: return true
	runner.check(queue[0].work == 1000 and queue[1].work == 0 and queue[0].id != queue[1].id,"P2 FIFO unique IDs")
	Fixture.steps(sim,299)
	queue = Fixture.object(sim,world.factory).queue
	runner.check(queue.size() == 1 and queue[0].work == 0,"P2 next head waits next tick")
	for index in range(8): runner.check(produce(sim,world.factory).ok,"P2 cap fill")
	sim.step()
	var before: Dictionary = sim.snapshot()
	runner.check(not produce(sim,world.factory).ok and sim.snapshot() == before,"P2 tenth atomic")
	queue = Fixture.object(sim,world.factory).queue
	var ids: Array = [queue[0].id,queue[4].id,queue[8].id]
	for id in ids:
		runner.check(Fixture.send(sim,{"type":"cancel_production","building_id":world.factory,"production_id":id}).ok,"P2 cancel exact ID")
	sim.step()
	var remaining: Array = Fixture.object(sim,world.factory).queue
	runner.check(remaining.size() == 6 and sim.snapshot().players[0].credits == before.players[0].credits + 2100,"P2 refunds stored costs")
	var expected: Array = queue.filter(func(entry: Dictionary) -> bool: return not ids.has(entry.id)).map(func(entry: Dictionary): return entry.id)
	runner.check(remaining.map(func(entry: Dictionary): return entry.id) == expected,"P2 preserved entry order")
	before = sim.snapshot()
	runner.check(not Fixture.send(sim,{"type":"cancel_production","building_id":world.factory,"production_id":ids[0]}).ok and sim.snapshot() == before,"P2 no double refund")
	return true

func test_blocked_exit(runner) -> bool:
	var world: Dictionary = ready(runner)
	var sim = world.sim
	var first: int = -1
	for cell in Construction.perimeter("usa_factory",Vector2i(16,4)):
		var id: int = sim.spawn(1,Vector2(cell) + Vector2(.5,.5))
		if first == -1 and id != -1: first = id
	runner.check(produce(sim,world.factory).ok and produce(sim,world.factory).ok,"P3 queued blocked")
	Fixture.steps(sim,300)
	var queue: Array = Fixture.object(sim,world.factory).queue
	runner.check(queue.size() == 2,"P3 ready remains")
	if queue.size() != 2: return true
	var next: int = sim.snapshot().next_entity_id
	runner.check(queue[0].work == 300000 and queue[1].work == 0,"P3 ready blocks FIFO")
	Fixture.steps(sim,10)
	runner.check(sim.snapshot().next_entity_id == next,"P3 blocked allocates no ID")
	Fixture.send(sim,{"type":"move","entity_ids":[first],"target":[24.5,24.5]})
	for tick in range(20):
		sim.step()
		if sim.snapshot().next_entity_id != next: break
	runner.check(sim.snapshot().next_entity_id == next + 1 and Fixture.object(sim,next).position == [16.5,3.5],"P3 first free exit spawns once")
	Fixture.send(sim,{"type":"cancel_production","building_id":world.factory,"production_id":queue[1].id})
	sim.step()
	runner.check(Fixture.object(sim,world.factory).queue.is_empty(),"P3 remaining cancellation")
	var reserved_world: Dictionary = ready(runner)
	var reserved = reserved_world.sim
	for cell in Construction.perimeter("usa_factory",Vector2i(16,4)):
		if cell != Vector2i(16,3): reserved.spawn(1,Vector2(cell) + Vector2(.5,.5))
	var blocker: int = reserved.spawn(1,Vector2(16.5,1.5))
	produce(reserved,reserved_world.factory)
	Fixture.steps(reserved,299)
	Fixture.send(reserved,{"type":"move","entity_ids":[blocker],"target":[16.5,3.5]})
	var next_id: int = reserved.snapshot().next_entity_id
	reserved.step()
	var ready_queue: Array = Fixture.object(reserved,reserved_world.factory).queue
	runner.check(ready_queue.size() == 1 and ready_queue[0].work == 300000 and reserved.snapshot().next_entity_id == next_id and Fixture.object(reserved,blocker).position != [16.5,3.5],"P3 reserved-only exit blocks ready spawn without ID allocation")
	if ready_queue.is_empty(): return true
	var credits: int = reserved.snapshot().players[0].credits
	var tick: int = reserved.snapshot().tick + 1
	for index in range(2): runner.check(Fixture.send(reserved,{"type":"cancel_production","building_id":reserved_world.factory,"production_id":ready_queue[0].id,"tick":tick}).ok,"P3 duplicate future ready cancel accepted")
	Fixture.steps(reserved,2)
	var state: Dictionary = reserved.snapshot()
	runner.check(Fixture.object(reserved,reserved_world.factory).queue.is_empty() and state.players[0].credits == credits + 700 and state.next_entity_id == next_id,"P3 ready head refunds once no spawn")
	runner.check(state.command_results.size() == 2 and state.command_results[0].ok and not state.command_results[1].ok,"P3 second ready cancel fails due")
	return true

func test_production_power_and_removal(runner) -> bool:
	var world: Dictionary = ready(runner)
	var sim = world.sim
	runner.check(produce(sim,world.factory).ok,"P4 enqueue")
	Fixture.steps(sim,150)
	var queue: Array = Fixture.object(sim,world.factory).queue
	if queue.is_empty():
		runner.check(false,"P4 queue exists")
		return true
	runner.check(queue[0].work == 150000,"P4 earned150000")
	sim.remove_object(world.reactor)
	Fixture.steps(sim,299)
	runner.check(Fixture.object(sim,world.factory).queue[0].work == 299500,"P4 half-rate299")
	sim.step()
	runner.check(Fixture.object(sim,world.factory).queue.is_empty(),"P4 exactly450 work ticks")
	sim.remove_object(world.depot)
	runner.check(produce(sim,world.factory).ok == false,"P4 enqueue requires current prerequisite")
	var world2: Dictionary = ready(runner)
	sim = world2.sim
	produce(sim,world2.factory)
	produce(sim,world2.factory)
	sim.step()
	var credits: int = sim.snapshot().players[0].credits
	runner.check(sim.remove_object(world2.factory).ok and sim.snapshot().players[0].credits == credits + 1400,"P4 producer death refunds all once")
	var before: Dictionary = sim.snapshot()
	runner.check(not sim.remove_object(world2.factory).ok and sim.snapshot() == before,"P4 repeated removal no refund")
	var retained_world: Dictionary = ready(runner)
	var retained = retained_world.sim
	produce(retained,retained_world.factory)
	Fixture.steps(retained,150)
	var paid_credits: int = retained.snapshot().players[0].credits
	retained.remove_object(retained_world.depot)
	Fixture.steps(retained,149)
	runner.check(Fixture.object(retained,retained_world.factory).queue[0].work == 299000 and retained.snapshot().players[0].credits == paid_credits,"P4 accepted paid queue survives prerequisite loss")
	retained.step()
	runner.check(Fixture.object(retained,retained_world.factory).queue.is_empty() and retained.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "usa_light_vehicle").size() == 1 and retained.snapshot().players[0].credits == paid_credits,"P4 retained queue completes without refund or second charge")
	return true

func skirmish_barracks(runner) -> Dictionary:
	var sim = Skirmish.create()
	var barracks: int = Fixture.build(runner,sim,"usa_barracks",Vector2i(12,12))
	return {"sim":sim,"barracks":barracks}

func rally(sim, id: int, target: Array, extra: Dictionary = {}) -> Dictionary:
	var payload := {"type":"set_rally","building_id":id,"target":target}
	payload.merge(extra)
	return Fixture.send(sim,payload)

func test_default_rally_mirrored(runner) -> bool:
	var world: Dictionary = skirmish_barracks(runner)
	var sim = world.sim
	runner.check(Fixture.object(sim,world.barracks).rally == [16.5,13.5],"R1 barracks rally in snapshot")
	runner.check(Production.default_rally(sim,"usa_barracks",Vector2i(34,12)) == [31.5,13.5],"R1 barracks mirrored")
	runner.check(Production.default_rally(sim,"usa_factory",Vector2i(12,18)) == [17.5,19.5],"R1 factory left")
	runner.check(Production.default_rally(sim,"usa_factory",Vector2i(33,18)) == [30.5,19.5],"R1 factory right")
	runner.check(Production.default_rally(sim,"usa_barracks",Vector2i(44,0)) == [41.5,1.5],"R1 right edge origin")
	runner.check(Production.default_rally(sim,"usa_barracks",Vector2i(0,30)) == [4.5,31.5],"R1 bottom clamp")
	return true

func test_production_never_stalls(runner) -> bool:
	var world: Dictionary = skirmish_barracks(runner)
	var sim = world.sim
	var produced: int = 0
	for tick in range(2400):
		if Fixture.object(sim,world.barracks).queue.size() < 2 and sim.snapshot().players[0].credits >= 225 and produced < 12:
			produced += 1 if produce(sim,world.barracks,"usa_rifle_infantry").ok else 0
		sim.step()
	var units: Array = sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "usa_rifle_infantry")
	runner.check(produced == 12 and units.size() == 12,"R2 twelve infantry produced")
	for unit in units:
		runner.check(unit.status == "arrived" and unit.combat.mode == "guard","R2 unit parked in guard")
	return true

func test_set_rally_applies_to_next_spawn(runner) -> bool:
	var world: Dictionary = skirmish_barracks(runner)
	var sim = world.sim
	runner.check(rally(sim,world.barracks,[20.5,20.5]).ok and rally(sim,world.barracks,[20.5,22.5]).ok,"R3 set accepted twice")
	sim.spawn(2,Vector2(12.5,14.5),"usa_builder")
	runner.check(produce(sim,world.barracks,"usa_rifle_infantry").ok,"R3 queued")
	var next: int = sim.snapshot().next_entity_id
	Fixture.steps(sim,152)
	var unit: Dictionary = Fixture.object(sim,next)
	runner.check(not unit.is_empty() and unit.combat.mode == "move" and unit.combat.target_id == null,"R3 spawned moving")
	runner.check(not unit.is_empty() and unit.destination != null and Vector2(unit.destination[0],unit.destination[1]).distance_to(Vector2(20.5,22.5)) < 1.5,"R3 destination follows last rally")
	runner.check(unit.position != [20.5,22.5] and unit.status != "arrived","R3 not yet arrived")
	Fixture.steps(sim,900)
	unit = Fixture.object(sim,next)
	runner.check(unit.combat.mode == "guard" and unit.status == "arrived","R3 guard on arrival")
	return true

func spawn_one(sim, world: Dictionary) -> Dictionary:
	var next: int = sim.snapshot().next_entity_id
	produce(sim,world.barracks,"usa_rifle_infantry")
	Fixture.steps(sim,152)
	return Fixture.object(sim,next)

func test_rally_blocked_cell_falls_back(runner) -> bool:
	var world: Dictionary = skirmish_barracks(runner)
	var sim = world.sim
	var reactor: int = Fixture.build(runner,sim,"usa_power_plant",Vector2i(20,12))
	runner.check(rally(sim,world.barracks,[20.5,12.5]).ok,"R4 rally on reactor footprint accepted")
	var unit: Dictionary = spawn_one(sim,world)
	var goal := Vector2i(Vector2(unit.destination[0],unit.destination[1]).floor()) if unit.get("destination") != null else Vector2i(-1,-1)
	runner.check(not unit.is_empty() and unit.destination != null and sim._navigation.is_walkable(Vector2(goal) + Vector2(.5,.5)),"R4 footprint rally falls back to walkable cell")
	runner.check(not unit.is_empty() and unit.destination != null and Vector2(unit.destination[0],unit.destination[1]).distance_to(Vector2(20.5,12.5)) < 3.0,"R4 fallback is near the rally")
	var walled: Array[Vector2i] = []
	for y in range(32): walled.append(Vector2i(30,y))
	var split = Simulation.new(walled,Vector2i(48,32))
	split.add_player(1,5000)
	split.spawn(1,Vector2(4.5,4.5),"usa_builder")
	var barracks: int = Fixture.build(runner,split,"usa_barracks",Vector2i(12,12))
	runner.check(rally(split,barracks,[40.5,12.5]).ok,"R4 far-side rally accepted")
	var other: Dictionary = spawn_one(split,{"barracks":barracks})
	runner.check(not other.is_empty() and other.destination != null and other.destination[0] < 30.0,"R4 other component falls back to reachable side")
	return true

func test_set_rally_same_tick_cases(runner) -> bool:
	var world: Dictionary = skirmish_barracks(runner)
	var sim = world.sim
	var id: int = world.barracks
	var tick: int = sim.snapshot().tick + 1
	var results: Array = [
		rally(sim,id,[18.5,14.5],{"tick":tick}),
		produce(sim,id,"usa_rifle_infantry"),
		rally(sim,id,[19.5,15.5],{"tick":tick}),
	]
	for index in range(results.size()): runner.check(results[index].ok,"R5 accepted " + str(index))
	Fixture.steps(sim,2)
	runner.check(Fixture.object(sim,id).rally == [19.5,15.5],"R5 last same-tick set wins")
	runner.check(Fixture.send(sim,{"type":"set_rally","building_id":id,"target":[21.5,15.5],"tick":sim.snapshot().tick + 150}).ok,"R5 queued for spawn tick")
	Fixture.steps(sim,160)
	runner.check(Fixture.object(sim,id).rally == [21.5,15.5],"R5 rally applied by spawn")
	produce(sim,id,"usa_rifle_infantry")
	sim.step()
	var queued: int = Fixture.object(sim,id).queue[0].id
	var same: int = sim.snapshot().tick + 1
	runner.check(Fixture.send(sim,{"type":"cancel_production","building_id":id,"production_id":queued,"tick":same}).ok and rally(sim,id,[22.5,15.5],{"tick":same}).ok,"R5 cancel_production and set_rally accepted")
	Fixture.steps(sim,2)
	runner.check(Fixture.object(sim,id).queue.is_empty() and Fixture.object(sim,id).rally == [22.5,15.5],"R5 both applied same tick")
	var cancel: Dictionary = Fixture.send(sim,{"type":"set_rally","building_id":id,"target":[1.5,1.5],"tick":sim.snapshot().tick + 1})
	var removed: Dictionary = Fixture.send(sim,{"type":"set_rally","building_id":id,"target":[2.5,2.5],"tick":sim.snapshot().tick + 1})
	runner.check(cancel.ok and removed.ok,"R5 accepted before removal")
	sim.remove_object(id)
	Fixture.steps(sim,2)
	var outcomes: Array = sim.snapshot().command_results.filter(func(row: Dictionary) -> bool: return row.error == "Missing producer")
	runner.check(outcomes.size() == 2 and sim.snapshot().buildings.all(func(building: Dictionary) -> bool: return building.kind == "usa_command_center"),"R5 removed producer rejected, nothing orphaned")
	var fresh: Dictionary = skirmish_barracks(runner)
	var other = fresh.sim
	var depot_world = economy_depot(runner)
	runner.check(not rally(depot_world.sim,depot_world.depot,[5.5,5.5]).ok,"R5 depot rejected")
	for row in [[[999.5,1.5],"out of map"],[[INF,1.5],"non-finite"],[[1.5],"short"]]:
		var before_state: Dictionary = other.snapshot()
		runner.check(not rally(other,fresh.barracks,row[0]).ok and other.snapshot() == before_state,"R5 invalid target " + row[1])
	runner.check(not Fixture.send(other,{"type":"set_rally","building_id":fresh.barracks,"target":[5.5,5.5],"player":2,"sequence":0}).ok,"R5 enemy rejected")
	runner.check(not rally(other,999,[5.5,5.5]).ok,"R5 missing producer rejected")
	return true

func economy_depot(runner) -> Dictionary:
	var sim = Fixture.make_world(50000)
	Fixture.build(runner,sim,"usa_power_plant",Vector2i(5,5))
	return {"sim":sim,"depot":Fixture.build(runner,sim,"usa_supply_center",Vector2i(10,4))}

func test_supply_center_spawns_ground_truck(runner) -> bool:
	var row: Dictionary = Registry.kind("usa_builder").duplicate(true)
	row.builds = row.builds + ["china_power_plant","china_supply_center"]
	Registry.add_test_kind("usa_builder",row)
	var sim = Fixture.make_world(50000)
	Fixture.build(runner,sim,"china_power_plant",Vector2i(5,5))
	var center: int = Fixture.build(runner,sim,"china_supply_center",Vector2i(10,4))
	var trucks: Array = sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "china_collector")
	runner.check(trucks.size() == 1,"Pg1 completion spawns one truck")
	if trucks.size() == 1: ground_truck_ok(runner,trucks[0],"completion")
	runner.check(produce(sim,center,"china_collector").ok,"Pg1 truck order accepted")
	Fixture.steps(sim,300)
	trucks = sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "china_collector")
	runner.check(trucks.size() == 2,"Pg1 queued truck spawns")
	if trucks.size() == 2: ground_truck_ok(runner,trucks[1],"queued")
	Registry.clear_test_kinds()
	return true

func ground_truck_ok(runner, unit: Dictionary, label: String) -> void:
	var cell := Vector2i(floori(unit.position[0]),floori(unit.position[1]))
	var near: bool = cell.x >= 9 and cell.x <= 13 and cell.y >= 3 and cell.y <= 7 and not (cell.x >= 10 and cell.x <= 12 and cell.y >= 4 and cell.y <= 6)
	runner.check(near and unit.collection.enabled and unit.order == null,"Pg1 " + label + " truck on a perimeter cell, collecting, no rally move")

func quantity_world(runner, blocked: int) -> Dictionary:
	var sim = Simulation.new([],Vector2i(32,32))
	sim.add_player(1,20000)
	sim.spawn(1,Vector2(4.5,4.5),"china_builder")
	var barracks: int = Fixture.build(runner,sim,"china_barracks",Vector2i(12,12))
	var cells: Array = Construction.perimeter("china_barracks",Vector2i(12,12))
	for index in range(blocked): sim.spawn(1,Vector2(cells[index]) + Vector2(.5,.5))
	return {"sim":sim,"barracks":barracks}

func militia(sim) -> Array:
	return sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "china_rifle_infantry")

func test_quantity_trains_two(runner) -> bool:
	var world: Dictionary = quantity_world(runner,0)
	var sim = world.sim
	var credits: int = sim.snapshot().players[0].credits
	runner.check(produce(sim,world.barracks,"china_rifle_infantry").ok,"Q1 militia order accepted")
	sim.step()
	runner.check(sim.snapshot().players[0].credits == credits - 300,"Q1 one order costs 300 once")
	var seen: int = 0
	for tick in range(400):
		sim.step()
		seen = militia(sim).size()
		if seen > 0: break
	runner.check(seen == 2 and Fixture.object(sim,world.barracks).queue.is_empty(),"Q1 both militia spawn the same tick and the entry leaves, got " + str(seen))
	var cells: Array = Construction.perimeter("china_barracks",Vector2i(12,12))
	var tight: Dictionary = quantity_world(runner,cells.size() - 1)
	var squeezed = tight.sim
	var first: int = Fixture.object(squeezed,tight.barracks).queue.size()
	produce(squeezed,tight.barracks,"china_rifle_infantry")
	Fixture.steps(squeezed,400)
	runner.check(militia(squeezed).is_empty() and Fixture.object(squeezed,tight.barracks).queue.size() == first + 1,"Q1 with one free cell none spawn and the entry stays")
	return true

func test_quantity_rally_on_free_exit(runner) -> bool:
	var cells: Array = Construction.perimeter("china_barracks",Vector2i(12,12))
	var world: Dictionary = quantity_world(runner,0)
	var sim = world.sim
	for index in range(cells.size() - 2): sim.spawn(1,Vector2(cells[index]) + Vector2(.5,.5))
	var free: Vector2i = cells[cells.size() - 1]
	Fixture.send(sim,{"type":"set_rally","building_id":world.barracks,"target":[free.x + 0.5,free.y + 0.5]})
	sim.step()
	var credits: int = sim.snapshot().players[0].credits
	produce(sim,world.barracks,"china_rifle_infantry")
	Fixture.steps(sim,700)
	var spent: int = credits - sim.snapshot().players[0].credits
	var queued: int = Fixture.object(sim,world.barracks).queue.size()
	runner.check((militia(sim).size() == 2 and queued == 0) or (militia(sim).is_empty() and queued == 1),"Q1 rally on a free exit: both militia or none with the entry kept, got " + str(militia(sim).size()) + " paid " + str(spent))
	return true
