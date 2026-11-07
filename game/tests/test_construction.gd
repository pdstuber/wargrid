@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/economy_fixture.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

func cases() -> Array[Callable]:
	return [test_preview_and_placement,test_travel_and_work,test_pause_resume_builder_loss,test_cancel_refund,test_competing_build_commands,test_prerequisites_and_power,test_construction_power_transition,test_build_navigation_cost]

func place(sim, origin: Array = [8,4]) -> Dictionary:
	return Fixture.send(sim,{"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":origin})

func test_preview_and_placement(runner) -> bool:
	var sim = Fixture.make_world(799)
	var before: Dictionary = sim.snapshot()
	runner.check(not sim.preview_build(1,1,"usa_power_plant",Vector2i(8,4)).ok and sim.snapshot() == before,"Cn1 insufficient pure")
	sim = Fixture.make_world(800)
	before = sim.snapshot()
	var preview: Dictionary = sim.preview_build(1,1,"usa_power_plant",Vector2i(8,4))
	runner.check(preview.ok and preview.cells == [[8,4],[9,4],[8,5],[9,5]] and preview.approach == [7.5,4.5],"Cn1 exact cells nearest approach")
	preview.cells.clear()
	runner.check(sim.snapshot() == before,"Cn1 preview copied pure")
	for origin in [Vector2i(-1,0),Vector2i(31,31),Vector2i(4,4)]:
		runner.check(not sim.preview_build(1,1,"usa_power_plant",origin).ok and sim.snapshot() == before,"Cn1 invalid geometry unchanged")
	runner.check(not sim.preview_build(1,99,"usa_power_plant",Vector2i(8,4)).ok,"Cn1 wrong builder")
	var wall: Array[Vector2i] = []
	for y in range(32): wall.append(Vector2i(6,y))
	runner.check(sim.replace_blocked_cells(wall).ok,"Cn1 wall")
	runner.check(not sim.preview_build(1,1,"usa_power_plant",Vector2i(8,4)).ok,"Cn1 unreachable approach")
	var occupied = Fixture.make_world()
	var terrain: Array[Vector2i] = [Vector2i(8,4)]
	occupied.replace_blocked_cells(terrain)
	before = occupied.snapshot()
	runner.check(not occupied.preview_build(1,1,"usa_power_plant",Vector2i(8,4)).ok and occupied.snapshot() == before,"Cn1 terrain overlap pure")
	occupied.add_supply_source(Vector2i(24,4),8)
	before = occupied.snapshot()
	runner.check(not occupied.preview_build(1,1,"usa_power_plant",Vector2i(24,4)).ok and occupied.snapshot() == before,"Cn1 source overlap pure")
	var built: int = Fixture.build(runner,occupied,"usa_power_plant",Vector2i(10,10))
	before = occupied.snapshot()
	runner.check(built != -1 and not occupied.preview_build(1,1,"usa_power_plant",Vector2i(10,10)).ok and occupied.snapshot() == before,"Cn1 building overlap pure")
	var blocker: int = occupied.spawn(1,Vector2(1.5,1.5))
	Fixture.send(occupied,{"type":"move","entity_ids":[blocker],"target":[16.5,4.5]})
	occupied.step()
	before = occupied.snapshot()
	runner.check(not occupied.preview_build(1,1,"usa_power_plant",Vector2i(16,4)).ok and occupied.snapshot() == before,"Cn1 reserved destination overlap pure")
	return true

func test_travel_and_work(runner) -> bool:
	var sim = Fixture.make_world()
	runner.check(place(sim).ok,"Cn2 accepted")
	sim.step()
	var state: Dictionary = sim.snapshot()
	runner.check(state.players[0].credits == 9200 and state.buildings.size() == 1,"Cn2 charge on execution")
	if state.buildings.is_empty(): return true
	runner.check(state.map.blocked_cells.has([8,4]) and state.buildings[0].work == 0,"Cn2 foundation blocks no travel work")
	for index in range(100):
		if sim.snapshot().entities[0].status == "arrived": break
		runner.check(sim.snapshot().buildings[0].work == 0,"Cn2 no work in travel")
		sim.step()
	runner.check(sim.snapshot().buildings[0].work == 0,"Cn2 arrival tick no work")
	Fixture.steps(sim,299)
	runner.check(sim.snapshot().buildings[0].work == 299000 and not sim.snapshot().buildings[0].completed,"Cn2 work299")
	sim.step()
	runner.check(sim.snapshot().buildings[0].completed and sim.snapshot().buildings[0].work == 300000 and sim.snapshot().entities[0].construction_id == null,"Cn2 exact completion")
	return true

func test_pause_resume_builder_loss(runner) -> bool:
	var sim = Fixture.make_world()
	if not place(sim).ok:
		runner.check(false,"Cn3 build accepted")
		return true
	Fixture.steps(sim,50)
	var id: int = sim.snapshot().buildings[0].id
	Fixture.send(sim,{"type":"stop","entity_ids":[1]})
	sim.step()
	var work: int = Fixture.object(sim,id).work
	Fixture.steps(sim,20)
	runner.check(Fixture.object(sim,id).work == work and Fixture.object(sim,id).builder_id == null,"Cn3 pause retains work")
	var second: int = sim.spawn(1,Vector2(6.5,3.5),"usa_builder")
	runner.check(Fixture.send(sim,{"type":"resume_build","builder_id":second,"building_id":id}).ok,"Cn3 resume new builder")
	sim.step()
	runner.check(Fixture.object(sim,id).builder_id == second and Fixture.object(sim,1).construction_id == null,"Cn3 binding replaced")
	runner.check(sim.remove_object(second).ok,"Cn3 builder removed")
	Fixture.steps(sim,20)
	runner.check(Fixture.object(sim,id).work == work and Fixture.object(sim,id).builder_id == null,"Cn3 loss pauses")
	return true

func test_cancel_refund(runner) -> bool:
	for ticks in [0,299]:
		var sim = Fixture.make_world()
		if not place(sim,[5,5]).ok:
			runner.check(false,"Cn4 accepted")
			continue
		sim.step()
		var id: int = sim.snapshot().buildings[0].id
		for index in range(50):
			if sim.snapshot().entities[0].status == "arrived": break
			sim.step()
		Fixture.steps(sim,ticks)
		var delay: int = 1 if ticks == 0 else 0
		var due: int = sim.snapshot().tick + delay
		runner.check(Fixture.send(sim,{"type":"cancel_build","building_id":id,"tick":due}).ok,"Cn4 cancel accepted")
		runner.check(Fixture.send(sim,{"type":"cancel_build","building_id":id,"tick":due}).ok,"Cn4 duplicate future accepted")
		Fixture.steps(sim,delay + 1)
		var state: Dictionary = sim.snapshot()
		runner.check(state.players[0].credits == 10000 and state.buildings.is_empty() and state.map.blocked_cells.is_empty(),"Cn4 refund once footprint clear")
		runner.check(state.command_results.size() == 2 and state.command_results[0].ok and not state.command_results[1].ok,"Cn4 second due failure")
		runner.check(state.entities[0].construction_id == null and state.entities[0].status == "idle" and state.path_queue.is_empty(),"Cn4 builder cleared")
	var sim = Fixture.make_world()
	if place(sim).ok:
		sim.step()
		runner.check(sim.remove_object(2).ok and sim.snapshot().players[0].credits == 9200,"Cn4 destruction no refund")
	var preserved = Fixture.make_world()
	var terrain: Array[Vector2i] = [Vector2i(2,2)]
	preserved.replace_blocked_cells(terrain)
	var source: int = preserved.add_supply_source(Vector2i(24,4),8)
	place(preserved)
	preserved.step()
	var foundation: int = preserved.snapshot().buildings[0].id
	Fixture.send(preserved,{"type":"cancel_build","building_id":foundation})
	preserved.step()
	runner.check(preserved.snapshot().map.blocked_cells.size() == 21 and preserved.snapshot().map.blocked_cells.has([2,2]) and Fixture.object(preserved,source).boxes == 8,"Cn4 cancellation preserves terrain/source union")
	var complete: int = Fixture.build(runner,preserved,"usa_power_plant",Vector2i(8,4))
	var before: Dictionary = preserved.snapshot()
	runner.check(not Fixture.send(preserved,{"type":"cancel_build","building_id":complete}).ok and preserved.snapshot() == before,"Cn4 completed cancellation rejects")
	return true

func test_competing_build_commands(runner) -> bool:
	for same in [false,true]:
		var sim = Fixture.make_world(10000 if same else 800)
		runner.check(Fixture.send(sim,{"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,4],"tick":2}).ok,"Cn5 first queued")
		runner.check(Fixture.send(sim,{"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,4] if same else [12,4],"tick":2}).ok,"Cn5 second queued")
		Fixture.steps(sim,2)
		runner.check(sim.snapshot().players[0].credits == (10000 if same else 800),"Cn5 no escrow")
		sim.step()
		var state: Dictionary = sim.snapshot()
		runner.check(state.players[0].credits == (9200 if same else 0) and state.buildings.size() == 1 and state.next_entity_id == 3,"Cn5 only canonical first pays no ID gap")
		runner.check(state.command_results.size() == 2 and state.command_results[0].ok and not state.command_results[1].ok,"Cn5 results")
	var sim = Fixture.make_world()
	runner.check(place(sim).ok,"Cn5 build before move")
	Fixture.send(sim,{"type":"move","entity_ids":[1],"target":[4.5,8.5]})
	sim.step()
	runner.check(sim.snapshot().buildings.size() == 1 and sim.snapshot().buildings[0].builder_id == null and sim.snapshot().entities[0].construction_id == null,"Cn5 paid paused foundation")
	return true

func test_prerequisites_and_power(runner) -> bool:
	var sim = Fixture.make_world()
	runner.check(not sim.preview_build(1,1,"usa_supply_center",Vector2i(10,4)).ok,"Cn6 depot requires reactor")
	if not place(sim,[5,5]).ok:
		runner.check(false,"Cn6 reactor accepted")
		return true
	sim.step()
	runner.check(not sim.preview_build(1,1,"usa_supply_center",Vector2i(10,4)).ok and sim.snapshot().players[0].power_supply == 0,"Cn6 foundation no prerequisite or supply")
	for index in range(500):
		if sim.snapshot().buildings[0].completed: break
		sim.step()
	runner.check(sim.snapshot().players[0].power_supply == 5 and sim.preview_build(1,1,"usa_supply_center",Vector2i(10,4)).ok,"Cn6 completed reactor unlocks")
	runner.check(not sim.preview_build(1,1,"usa_factory",Vector2i(16,4)).ok,"Cn6 factory requires depot")
	var depot: int = Fixture.build(runner,sim,"usa_supply_center",Vector2i(10,4))
	if depot == -1: return true
	runner.check(sim.snapshot().players[0].power_demand == 1 and sim.preview_build(1,1,"usa_factory",Vector2i(16,4)).ok,"Cn6 completed depot demand and unlock")
	runner.check(sim.remove_object(2).ok and sim.snapshot().players[0].power_supply == 0 and sim.snapshot().players[0].work_rate == 500,"Cn6 removal derived once")
	var before: Dictionary = sim.snapshot()
	runner.check(not sim.remove_object(2).ok and sim.snapshot() == before,"Cn6 repeated removal unchanged")
	return true

func test_construction_power_transition(runner) -> bool:
	var sim = Fixture.make_world()
	var reactor: int = Fixture.build(runner,sim,"usa_power_plant",Vector2i(5,5))
	var depot: int = Fixture.build(runner,sim,"usa_supply_center",Vector2i(10,4))
	if reactor == -1 or depot == -1: return true
	runner.check(Fixture.send(sim,{"type":"build","builder_id":1,"building_kind":"usa_factory","origin":[16,4]}).ok,"Cn7 factory accepted")
	sim.step()
	var id: int = sim.snapshot().buildings.back().id
	for index in range(300):
		if Fixture.object(sim,1).status == "arrived": break
		sim.step()
	Fixture.steps(sim,150)
	runner.check(Fixture.object(sim,id).work == 150000,"Cn7 earned full work")
	sim.remove_object(reactor)
	Fixture.steps(sim,299)
	runner.check(Fixture.object(sim,id).work == 299500 and not Fixture.object(sim,id).completed,"Cn7 exact accumulated low work")
	sim.step()
	runner.check(Fixture.object(sim,id).work == 300000 and not Fixture.object(sim,id).completed,"Cn7 no duration recompute jump")
	Fixture.steps(sim,300)
	runner.check(Fixture.object(sim,id).completed and Fixture.object(sim,id).work == 450000,"Cn7 completion after remaining work")
	var captured = Fixture.make_world(50000)
	var old_power: int = Fixture.build(runner,captured,"usa_power_plant",Vector2i(5,5))
	Fixture.build(runner,captured,"usa_supply_center",Vector2i(10,4))
	Fixture.send(captured,{"type":"build","builder_id":1,"building_kind":"usa_power_plant","origin":[8,12]})
	captured.step()
	var replacement: int = captured.snapshot().buildings.back().id
	for index in range(300):
		if Fixture.object(captured,1).status == "arrived": break
		captured.step()
	Fixture.steps(captured,299)
	runner.check(Fixture.object(captured,replacement).work == 299000,"Cn7 replacement earned299000")
	captured.remove_object(old_power)
	var builder: int = captured.spawn(1,Vector2(15.5,4.5),"usa_builder")
	Fixture.send(captured,{"type":"build","builder_id":builder,"building_kind":"usa_factory","origin":[16,4]})
	captured.step()
	var factory: int = captured.snapshot().buildings.back().id
	runner.check(Fixture.object(captured,replacement).work == 299500 and Fixture.object(captured,factory).work == 0,"Cn7 captured deficit before completion")
	captured.step()
	runner.check(Fixture.object(captured,replacement).completed and Fixture.object(captured,factory).work == 500,"Cn7 earlier completion cannot change later rate same tick")
	captured.step()
	runner.check(Fixture.object(captured,factory).work == 1500,"Cn7 completion rate starts next tick")
	return true

func test_build_navigation_cost(runner) -> bool:
	var sim = Fixture.make_world()
	var before: int = sim.navigation_builds()
	var local: int = sim.navigation_local_updates()
	runner.check(place(sim).ok,"Cn8 build accepted")
	runner.check(sim.navigation_builds() == before,"Cn8 issue-time check builds no grid on open ground")
	sim.step()
	runner.check(sim.snapshot().buildings.size() == 1 and sim.navigation_builds() == before and sim.navigation_local_updates() == local + 1,"Cn8 placement updates in place, got " + str(sim.navigation_builds() - before))
	var expected = Simulation.new(sim._union_cells(),Vector2i(32,32))
	runner.check(sim.snapshot().map == expected.snapshot().map,"Cn8 reused grid equals a rebuilt one")
	return true
