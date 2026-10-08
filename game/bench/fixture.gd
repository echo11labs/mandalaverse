extends RefCounted
## G1-12 only. Coordinator-approved one-time finite fixture initialization.
const SEED := 401208
const SUPPLIES := {&"wild_food": 10000, &"water": 10000, &"fodder": 10000}

static func setup(valley, smoke := false) -> Dictionary:
	seed(SEED)
	var sim: GopalaSettlementSimulation = valley.simulation
	sim.set_physics_process(false)
	var registry := sim.entity_registry()
	var stores := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING)
	var capacities := {}
	for good in GopalaSimulationConfig.RESOURCE_IDS: capacities[good] = 1000000
	registry.update_entity(stores[0].entity_id, {&"storage_capacity": capacities}, {}, sim.logical_tick)
	sim.apply_authorized_transaction(SUPPLIES)
	var cells: Array[Vector2i] = []
	for z in range(-20, 21):
		for x in range(-20, 21):
			var cell := Vector2i(x,z)
			if sim._route_service.is_open(cell): cells.append(cell)
	cells.sort_custom(func(a,b): return a.length_squared() < b.length_squared() if a.length_squared() != b.length_squared() else (a.x < b.x if a.x != b.x else a.y < b.y))
	# Pre-existing completed buildings, as approved; no sampled replenishment.
	for i in 11:
		var point := sim.coordinate_service().settlement_cell_to_world_xz(cells[50+i*4])
		registry.create_entity(GopalaEntityKind.BUILDING, {&"definition_id": &"dwelling" if i < 10 else &"cattle_shelter", &"construction_state": "COMPLETED", &"position_x":point.x, &"position_z":point.y, &"rotation":0}, {}, sim.logical_tick)
	for i in 40:
		var point := sim.coordinate_service().settlement_cell_to_world_xz(cells[20+i])
		registry.create_entity(GopalaEntityKind.RESOURCE_SOURCE, {&"resource_id":&"timber", &"available_amount":100000, &"initial_amount":100000, &"reserved_amount":0, &"position_x":point.x, &"position_z":point.y, &"gatherable":true, &"exhausted":false}, {}, sim.logical_tick)
	sim.set_paused(false)
	sim.set_speed(4)
	sim.process_pending_commands()
	for cell in cells:
		if sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER).size() >= 40: break
		var point := sim.coordinate_service().settlement_cell_to_world_xz(cell)
		sim.submit_command(GopalaSimulationCommand.REQUEST_SPAWN_VILLAGER, {"x":float(point.x), "z":float(point.y)}, &"benchmark")
		sim.process_pending_commands()
		if not smoke: sim.advance_ticks(1)
	var pasture_id := 0
	for cell in cells:
		if sim._herd_service.validate_pasture(cell).valid:
			sim.submit_command(GopalaSimulationCommand.CREATE_PASTURE, {"cell_x":cell.x,"cell_y":cell.y}, &"benchmark")
			sim.process_pending_commands()
			pasture_id = sim._herd_service.pastures()[-1].entity_id
			break
	for cow in sim._herd_service.animals():
		sim.submit_command(GopalaSimulationCommand.ASSIGN_CATTLE_PASTURE,{"cow_id":cow.entity_id,"pasture_id":pasture_id}, &"benchmark")
	var workers := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)
	for i in workers.size():
		sim.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":workers[i].entity_id,"role":&"herder" if i == 0 else &"timber"}, &"benchmark")
	sim.set_speed(4)
	sim.set_paused(false)
	sim.process_pending_commands()
	# Let normal need trips dephase through gameplay; no worker-state edits.
	if not smoke: sim.advance_ticks(180)
	sim.advance_ticks(1) # Initialize normal survival fields before changing only due ticks.
	var timer_offsets: Array = []
	workers = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)
	for i in workers.size():
		var meal_offset := 1 + int(i * int(sim._survival_service.policy.meal_interval_ticks) / workers.size())
		var drink_offset := 1 + int(i * int(sim._survival_service.policy.drink_interval_ticks) / workers.size())
		registry.update_entity(workers[i].entity_id,{&"meal_due_tick":sim.logical_tick+meal_offset,&"drink_due_tick":sim.logical_tick+drink_offset},{},sim.logical_tick)
		timer_offsets.append({"worker_id":workers[i].entity_id,"meal_offset":meal_offset,"drink_offset":drink_offset})
	valley.focus_camp()
	return {"seed":SEED, "preconditioning_ticks":sim.logical_tick, "initial_need_timer_offsets":timer_offsets, "supplies_added":SUPPLIES, "initial_ledger":sim.resource_balances_snapshot(), "storage_capacity":capacities, "extra_sources":40, "timber_per_extra_source":100000, "completed_fixture_homes":10, "completed_fixture_shelters":1, "workers":workers.size(), "cattle":sim._herd_service.animals().size(), "roles":{"timber":39,"herder":1}, "setup_exception":"Registry/stock APIs only before warmup; spawning/roles/pasture use commands. Completed fixture buildings are nonblocking pre-existing records."}

static func activity(sim) -> Dictionary:
	var active := 0
	var needs := 0
	var statuses := {}
	for worker in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER):
		var a: Dictionary = worker.attributes
		var state := str(a.get(&"job_status", "UNKNOWN"))
		statuses[state] = int(statuses.get(state,0))+1
		if a.get(&"task_kind") == &"NEED": needs += 1
		if int(a.get(&"active_task_id",0)) > 0 or int(a.get(&"carried_amount",0)) > 0 or (a.get(&"movement_state") == &"MOVING" and a.get(&"task_kind") != &"NEED"):
			active += 1
	return {"active":active,"needs":needs,"statuses":statuses}
