extends SceneTree
var checks := 0
var failures: Array[String] = []
var worker_id := 0

func _initialize() -> void: run.call_deferred()
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func fixture() -> GopalaSettlementSimulation:
	var sim := GopalaSettlementSimulation.new()
	root.add_child(sim)
	sim.set_physics_process(false)
	sim.coordinate_service().configure(GopalaSettlementGridConfig.new(Vector2.ZERO,Rect2i(-12,-12,24,24),2.0,100.0))
	sim.bootstrap_session()
	var camp := sim.entity_registry().create_entity(GopalaEntityKind.BUILDING,{&"definition_id":&"stockpile",&"construction_state":&"COMPLETED",&"position_x":0.0,&"position_z":0.0,&"storage_capacity":{&"timber":200,&"stone":200,&"thatch":200}}).entity_id
	sim.occupancy_service().reserve_cells(camp,[Vector2i.ZERO],0)
	sim.occupancy_service().commit_reservation(camp,0)
	sim._storage_service.enable_locations(camp)
	sim._route_service.enable(Rect2i(-12,-12,24,24))
	worker_id = sim.villager_service().spawn_villager(Vector2(-0.04,0.04))
	return sim

func resume(sim: GopalaSettlementSimulation) -> void:
	sim.set_paused(false)
	sim.process_pending_commands()

func complete(sim: GopalaSettlementSimulation, id: int) -> void:
	for tick in 1500:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(id).attributes.construction_state == "COMPLETED": return
	check(false,"Construction completes through real routing and labor")

func restore(sim: GopalaSettlementSimulation) -> GopalaSettlementSimulation:
	var codec := GopalaSettlementSave.new()
	check(codec.write("user://tests/path-work.json",codec.capture(sim,{})),"Write path state as JSON")
	var next := codec.restore(codec.read("user://tests/path-work.json"),sim,{})
	check(next != null,"Mid-path save/load validates: " + codec.error)
	if next != null:
		root.add_child(next)
		next.set_physics_process(false)
	return next

func run() -> void:
	var sim := fixture()
	var cells: Array[Vector2i] = [Vector2i(2,2),Vector2i(3,2),Vector2i(4,2)]
	sim.request_road(cells)
	sim.process_pending_commands()
	var road_id: int = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.ROAD)[0].entity_id
	var road := sim.entity_queries().snapshot(road_id)
	check(road.attributes.work_completed == 0 and road.attributes.construction_state == "BLUEPRINT","Drag creates a path blueprint with zero labor")
	check(sim.road_service().road_quality_at(cells[0]) == &"" and is_equal_approx(sim._route_service.movement_multiplier(cells[0]),1.0),"Planned cells grant no travel benefit")
	check(sim.road_service().validate_cells(cells).reason_code == &"PATH_ALREADY_EXISTS","Pending cells are protected against duplicate plans")
	sim.advance_ticks(1)
	check(sim.entity_queries().snapshot(road_id).attributes.work_completed == 0,"Paused simulation cannot advance path work")
	resume(sim)
	var positions := {}
	for tick in 300:
		sim.advance_ticks(1)
		road = sim.entity_queries().snapshot(road_id)
		var worker := sim.entity_queries().snapshot(worker_id)
		if worker.attributes.task_state == &"PERFORMING_LABOR": positions[sim.coordinate_service().world_to_settlement_cell(Vector2(worker.attributes.position_x,worker.attributes.position_z))] = true
		if GopalaRoadPlacementService.built_cells(road).size() == 1: break
	check(GopalaRoadPlacementService.built_cells(road).size() == 1,"Builder prepares cells progressively")
	check(sim.road_service().road_quality_at(cells[0]) == &"dirt" and sim.road_service().road_quality_at(cells[2]) == &"","Only finished cells gain a dirt surface")
	var loaded := restore(sim)
	if loaded == null: finish(sim); return
	sim.free(); sim = loaded
	for tick in 300:
		sim.advance_ticks(1)
		var worker := sim.entity_queries().snapshot(worker_id)
		if worker.attributes.task_state == &"PERFORMING_LABOR": positions[sim.coordinate_service().world_to_settlement_cell(Vector2(worker.attributes.position_x,worker.attributes.position_z))] = true
		if sim.entity_queries().snapshot(road_id).attributes.construction_state == "COMPLETED": break
	check(positions.size() == 3,"Builder works at each of the three physical cells")
	check(sim.entity_queries().snapshot(road_id).attributes.construction_state == "COMPLETED","Restored dirt construction completes")
	var initial_stone := sim.resource_amount(&"stone")
	var initial_timber := sim.resource_amount(&"timber")
	sim.request_cobbled_path(cells)
	sim.process_pending_commands()
	check(sim.resource_amount(&"stone") == initial_stone and sim.resource_amount(&"timber") == initial_timber,"Paving plan does not debit stock immediately")
	check(sim.road_service().road_quality_at(cells[0]) == &"dirt","Planning paving preserves the existing dirt surface")
	var saved_during_haul := false
	for tick in 600:
		sim.advance_ticks(1)
		road = sim.entity_queries().snapshot(road_id)
		var worker := sim.entity_queries().snapshot(worker_id)
		for resource in [&"timber",&"stone"]:
			var total: int = sim.resource_amount(resource) + int(road.attributes.reserved_materials.get(resource,0)) + int(road.attributes.delivered_materials.get(resource,0))
			if worker.attributes.get("carried_resource_id",&"") == resource: total += int(worker.attributes.get("carried_amount",0))
			check(total == (initial_stone if resource == &"stone" else initial_timber),"Paving conserves stored/reserved/carried/delivered goods")
		if not saved_during_haul and worker.attributes.get("carried_amount",0) > 0:
			loaded = restore(sim)
			if loaded == null: finish(sim); return
			sim.free(); sim = loaded; saved_during_haul = true
		if GopalaRoadPlacementService.completed_work_cells(road) >= 1: break
	check(saved_during_haul,"Paving actually carries material from a located store")
	check(sim.road_service().road_quality_at(cells[0]) == &"cobbled" and sim.road_service().road_quality_at(cells[2]) == &"dirt","Paving changes only completed cells")
	var state_codec := GopalaSettlementSave.new()
	var bad_state := state_codec.capture(sim,{})
	# Corrupt work progress must be rejected, rather than creating instant roads.
	for entity in bad_state.records:
		if entity[0] == road_id: entity[6].work_completed = 100000
	check(state_codec.restore(bad_state,sim,{}) == null,"Tampered path work exceeds its authored budget and is rejected")
	sim.submit_command(GopalaSimulationCommand.REQUEST_CANCEL_CONSTRUCTION,{"entity_id":road_id})
	sim.process_pending_commands()
	check(sim.road_service().road_quality_at(cells[0]) == &"cobbled" and sim.road_service().road_quality_at(cells[2]) == &"dirt","Cancellation preserves completed paving and the original dirt path")
	for resource in [&"timber",&"stone"]:
		var recoverable: int = sim.resource_amount(resource)
		for source in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE):
			if source.attributes.get("resource_id") == resource: recoverable += int(source.attributes.get("available_amount",0))
		var worker := sim.entity_queries().snapshot(worker_id)
		if worker.attributes.get("carried_resource_id",&"") == resource: recoverable += int(worker.attributes.get("carried_amount",0))
		check(recoverable == (initial_stone-2 if resource == &"stone" else initial_timber-1),"Cancellation recovers unused material without refunding completed paving")
	loaded = restore(sim)
	if loaded != null: loaded.free()
	sim.free()
	sim = fixture()
	sim.request_road(cells)
	sim.process_pending_commands()
	road_id = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.ROAD)[0].entity_id
	resume(sim)
	for tick in 200:
		sim.advance_ticks(1)
		if GopalaRoadPlacementService.built_cells(sim.entity_queries().snapshot(road_id)).size() == 1: break
	sim.submit_command(GopalaSimulationCommand.REQUEST_CANCEL_CONSTRUCTION,{"entity_id":road_id})
	sim.process_pending_commands()
	check(sim.road_service().road_cells().size() == 1,"Cancelling dirt preparation keeps completed cells only")
	check(sim.road_service().validate_cells([cells[1],cells[2]]).valid,"Cancelling releases unbuilt cells for another plan")
	# Complete a new stretch and cancel paving while the builder is carrying goods.
	sim.request_road([cells[1],cells[2]])
	sim.process_pending_commands()
	var roads := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.ROAD)
	road_id = roads[roads.size()-1].entity_id
	complete(sim,road_id)
	initial_stone = sim.resource_amount(&"stone")
	initial_timber = sim.resource_amount(&"timber")
	sim.request_cobbled_path([cells[1],cells[2]])
	sim.process_pending_commands()
	for tick in 300:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(worker_id).attributes.get("carried_amount",0) > 0: break
	check(sim.entity_queries().snapshot(worker_id).attributes.get("carried_amount",0) > 0,"Cancellation fixture reaches a real carrying state")
	sim.submit_command(GopalaSimulationCommand.REQUEST_CANCEL_CONSTRUCTION,{"entity_id":road_id})
	sim.process_pending_commands()
	loaded = restore(sim)
	if loaded != null:
		sim.free(); sim = loaded
	for tick in 300:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(worker_id).attributes.get("carried_amount",0) == 0: break
	check(sim.resource_amount(&"stone") == initial_stone and sim.resource_amount(&"timber") == initial_timber,"Mid-haul cancellation returns carried and reserved stock exactly once")
	check(sim.road_service().road_quality_at(cells[1]) == &"dirt","Cancelled paving grants no cobbled speed bonus")
	var crossing: Array[Vector2i] = [Vector2i(2,1),Vector2i(2,2),Vector2i(2,3)]
	sim.request_road(crossing)
	sim.process_pending_commands()
	loaded = restore(sim)
	if loaded != null: loaded.free()
	check(sim.road_service().road_cells().has(Vector2i(2,1)) and sim.road_service().road_cells().has(Vector2i(2,3)),"A crossing reuses the existing middle cell and plans only new cells")
	finish(sim)

func finish(sim: GopalaSettlementSimulation) -> void:
	sim.free()
	print("GOPALA_TEST_REPORT=",JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
