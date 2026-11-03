extends RefCounted

const Fixture = preload("res://tests/economy_fixture.gd")
const Construction = preload("res://scripts/simulation/construction.gd")

func cases() -> Array[Callable]:
	return [test_producer_and_free_collector,test_fifo_payment_and_cancel,test_blocked_exit,test_production_power_and_removal]

func ready(runner) -> Dictionary:
	var sim = Fixture.make_world(50000)
	var reactor: int = Fixture.build(runner,sim,"reactor",Vector2i(5,5))
	var depot: int = Fixture.build(runner,sim,"depot",Vector2i(10,4))
	var factory: int = Fixture.build(runner,sim,"factory",Vector2i(16,4))
	return {"sim":sim,"reactor":reactor,"depot":depot,"factory":factory}

func produce(sim, id: int, kind: String = "vehicle") -> Dictionary:
	return Fixture.send(sim,{"type":"produce","building_id":id,"unit_kind":kind})

func test_producer_and_free_collector(runner) -> bool:
	var world: Dictionary = ready(runner)
	var sim = world.sim
	var collectors: Array = sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "collector")
	runner.check(collectors.size() == 1,"P1 exactly one free collector")
	if not collectors.is_empty(): runner.check(collectors[0].collection.cargo == 0 and collectors[0].collection.enabled,"P1 free collector enabled empty")
	Fixture.steps(sim,10)
	runner.check(sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "collector").size() == 1,"P1 grant never repeats")
	for row in [[world.factory,"collector"],[world.depot,"vehicle"],[999,"vehicle"]]:
		var before: Dictionary = sim.snapshot()
		runner.check(not produce(sim,row[0],row[1]).ok and sim.snapshot() == before,"P1 invalid producer atomic")
	runner.check(produce(sim,world.depot,"collector").ok,"P1 paid collector accepted")
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
	Fixture.build(runner,grant,"reactor",Vector2i(5,5))
	Fixture.build(runner,grant,"depot",Vector2i(10,4))
	var free: Dictionary = grant.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "collector")[0]
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
	for cell in Construction.perimeter("factory",Vector2i(16,4)):
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
	Fixture.steps(sim,20)
	runner.check(sim.snapshot().next_entity_id == next + 1 and Fixture.object(sim,next).position == [16.5,3.5],"P3 first free exit spawns once")
	Fixture.send(sim,{"type":"cancel_production","building_id":world.factory,"production_id":queue[1].id})
	sim.step()
	runner.check(Fixture.object(sim,world.factory).queue.is_empty(),"P3 remaining cancellation")
	var reserved_world: Dictionary = ready(runner)
	var reserved = reserved_world.sim
	for cell in Construction.perimeter("factory",Vector2i(16,4)):
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
	runner.check(Fixture.object(retained,retained_world.factory).queue.is_empty() and retained.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "vehicle").size() == 1 and retained.snapshot().players[0].credits == paid_credits,"P4 retained queue completes without refund or second charge")
	return true
