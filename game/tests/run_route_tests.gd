extends SceneTree
var checks := 0
var failures: Array[String] = []
const SIM := preload("res://core/simulation/settlement_simulation.tscn")
func _initialize(): run.call_deferred()
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label); push_error(label)
func fixture():
	var sim = SIM.instantiate()
	root.add_child(sim)
	sim.set_physics_process(false)
	sim.coordinate_service().configure(GopalaSettlementGridConfig.new(Vector2.ZERO, Rect2i(-12,-12,24,24),2.0,100.0))
	sim.bootstrap_session()
	sim.set_paused(false)
	sim.process_pending_commands()
	sim._route_service.enable(Rect2i(-12,-12,24,24))
	return sim
func claim(sim, cells: Array[Vector2i]) -> int:
	var result = sim.entity_registry().create_entity(GopalaEntityKind.BUILDING, {&"position_x":0.0,&"position_z":0.0})
	check(sim.occupancy_service().reserve_cells(result.entity_id,cells,sim.logical_tick).status == GopalaOccupancyOperationResult.Status.APPLIED, "Obstacle claim accepted")
	sim.occupancy_service().commit_reservation(result.entity_id,sim.logical_tick)
	return result.entity_id
func advance(sim, tick: int):
	sim._physics_process(sim._config.tick_interval_seconds)
func run():
	var sim = fixture()
	var barrier: Array[Vector2i] = [Vector2i(0,-1),Vector2i(0,0),Vector2i(0,1)]
	var owner := claim(sim,barrier)
	var worker: int = sim.villager_service().spawn_villager(Vector2(-0.1,0))
	check(sim.villager_service().assign_move_task(worker,Vector2(0.1,0)), "Route accepted around occupied plots")
	var travelled := 0.0
	var previous := Vector2(-0.1,0)
	for tick in range(1,400):
		advance(sim,tick)
		var attrs = sim.entity_queries().snapshot(worker).attributes
		var point := Vector2(attrs.position_x,attrs.position_z)
		travelled += point.distance_to(previous)
		check(not sim.occupancy_service().is_blocked(sim.coordinate_service().world_to_settlement_cell(point)), "Worker never walks inside occupied plot")
		check(point.distance_to(previous) <= 0.014 * sim._config.tick_interval_seconds + 0.000001, "Movement budget remains 1.4m/s at fixed tick")
		previous = point
		if str(attrs.movement_state) == "IDLE": break
	check(previous.distance_to(Vector2(0.1,0)) < 0.000001 and travelled > 0.2, "Detour completes at requested destination")
	check(not sim.villager_service().assign_move_task(worker,Vector2.ZERO), "Debug move into solid plot rejected")
	check(sim.villager_service().last_failure == &"NO_ROUTE", "Solid goal has explicit reason")
	check(not sim.villager_service().assign_move_task(worker,Vector2(2,2)), "Outside navigation bounds rejected")
	check(sim.villager_service().assign_move_task(worker,Vector2(-0.1,0)), "Reverse route accepted")
	var wall: Array[Vector2i] = []
	for y in range(-12,12): wall.append(Vector2i(2,y))
	var wall_owner := claim(sim,wall)
	advance(sim,401)
	check(sim.entity_queries().snapshot(worker).attributes.movement_state == &"BLOCKED", "New obstruction invalidates route")
	check(not sim.villager_service().has_arrived(worker), "Blocked route is never arrival")
	sim.occupancy_service().release_claim(wall_owner,&"TEST",401)
	check(sim.villager_service().assign_move_task(worker,Vector2(-0.1,0)), "Released obstruction permits a new route")
	sim.queue_free()
	await process_frame
	# Gather pickup is physical; blocked drop-off keeps the load until access returns.
	sim = fixture()
	var camp: int = claim(sim,[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)])
	sim.entity_registry().update_entity(camp,{&"accepts_stone":true},{},0)
	worker = sim.villager_service().spawn_villager(Vector2(-0.08,0.04))
	var source = sim.entity_registry().create_entity(GopalaEntityKind.RESOURCE_SOURCE,{&"resource_id":&"stone",&"gatherable":true,&"available_amount":1,&"reserved_amount":0,&"position_x":-0.1,&"position_z":0.04})
	var initial: int = sim.resource_amount(&"stone")
	sim.submit_command(GopalaSimulationCommand.REQUEST_GATHER_STONE,{"villager_id":worker,"source_entity_id":source.entity_id,"destination_entity_id":camp})
	sim.process_pending_commands()
	var picked := false
	var tick := 0
	while tick < 150:
		tick += 1
		advance(sim,tick)
		if sim.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 1: picked = true; break
	check(picked, "Worker reaches source and picks up reserved stone")
	var ring: Array[Vector2i] = [Vector2i(-1,0),Vector2i(-1,1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(0,2),Vector2i(1,2),Vector2i(2,0),Vector2i(2,1)]
	var ring_owner := claim(sim,ring)
	for frame in 20: tick += 1; advance(sim,tick)
	check(sim.entity_queries().snapshot(worker).attributes.carried_amount == 1 and sim.resource_amount(&"stone") == initial, "Blocked delivery preserves carried goods without remote credit")
	check(sim.entity_queries().snapshot(worker).attributes.task_state == &"BLOCKED_DELIVERY", "Blocked delivery reported clearly")
	sim.occupancy_service().release_claim(ring_owner,&"TEST",tick)
	for frame in 500:
		tick += 1
		advance(sim,tick)
		if sim.resource_amount(&"stone") == initial + 1: break
	check(sim.resource_amount(&"stone") == initial + 1 and sim.entity_queries().snapshot(worker).attributes.carried_amount == 0, "Delivery resumes once access opens; credited once")
	var final = sim.entity_queries().snapshot(worker)
	check(not sim.occupancy_service().is_blocked(sim.coordinate_service().world_to_settlement_cell(Vector2(final.attributes.position_x,final.attributes.position_z))), "Delivery ends beside camp, outside its occupied footprint")
	# Initial unreachable source returns its reservation and leaves worker available.
	var cage: Array[Vector2i] = [Vector2i(-6,2),Vector2i(-4,2),Vector2i(-5,1),Vector2i(-5,3)]
	claim(sim,cage)
	sim.entity_registry().update_entity(source.entity_id,{&"available_amount":1,&"exhausted":false},{},tick)
	sim.submit_command(GopalaSimulationCommand.REQUEST_GATHER_STONE,{"villager_id":worker,"source_entity_id":source.entity_id,"destination_entity_id":camp})
	sim.process_pending_commands()
	check(sim.entity_queries().snapshot(source.entity_id).attributes.reserved_amount == 0 and sim.entity_queries().snapshot(source.entity_id).attributes.available_amount == 1, "Unreachable source releases reservation")
	check(sim.entity_queries().snapshot(worker).attributes.active_task_id == 0, "Unreachable request leaves no stale task ownership")
	sim.reset()
	check(sim.villager_service()._routes.is_empty(), "Session reset clears route cache")
	sim.queue_free()
	await process_frame
	var valley = load("res://scenes/landscape/kathmandu_valley.tscn").instantiate()
	root.add_child(valley)
	sim = valley.simulation
	sim.set_physics_process(false)
	var villagers = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)
	worker = villagers[0].entity_id
	var start := Vector2(villagers[0].attributes.position_x,villagers[0].attributes.position_z)
	for deposit in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE):
		var target := Vector2(deposit.attributes.position_x,deposit.attributes.position_z)
		check(sim._route_service.plan(start,target,&"GATHER").ok,"Live seeded resource reachable on dry grid route")
	var camp_record = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING)[0]
	check(sim.occupancy_service().claim_for_owner(camp_record.entity_id) != null,"Scenario camp occupies its grid plot")
	check(not sim.placement_service().validate_placement(&"stockpile",sim.coordinate_service().world_to_settlement_cell(start),0).valid,"Placement cannot trap a worker inside a building")
	sim.set_paused(false)
	sim.process_pending_commands()
	var timber_before: int = sim.resource_amount(&"timber")
	sim.request_construction(&"stockpile",Vector2i(4,4),0)
	sim.process_pending_commands()
	var buildings = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING)
	check(buildings.size() == 2,"Live construction accepts free plot")
	if buildings.size() == 2:
		var blueprint_id: int = buildings[1].entity_id
		sim.submit_command(GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER,{"villager_id":worker,"blueprint_id":blueprint_id})
		sim.process_pending_commands()
		for frame in 1000:
			advance(sim,frame)
			var actor = sim.entity_queries().snapshot(worker)
			check(not sim.occupancy_service().is_blocked(sim.coordinate_service().world_to_settlement_cell(Vector2(actor.attributes.position_x,actor.attributes.position_z))),"Builder remains outside claimed footprints")
			if sim.entity_queries().snapshot(blueprint_id).attributes.construction_state == "COMPLETED": break
		check(sim.entity_queries().snapshot(blueprint_id).attributes.construction_state == "COMPLETED","Live builder routes to camp, delivers four loads, then completes labour")
		check(sim.resource_amount(&"timber") == timber_before - 4,"Construction routing conserves four consumed timber")
	valley.queue_free()
	await process_frame
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
