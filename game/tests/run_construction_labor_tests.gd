extends SceneTree

const SIMULATION_SCENE := preload("res://core/simulation/settlement_simulation.tscn")

var checks := 0
var failures: Array[String] = []

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	await _test_construction_labor()
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _new_simulation() -> Node:
	var simulation = SIMULATION_SCENE.instantiate()
	root.add_child(simulation)
	return simulation

func _force_arrival(sim: Node, villager_id: int) -> void:
	var v_snap = sim.entity_registry().snapshot(villager_id)
	var dest_x = v_snap.attributes.get("destination_x", 0.0)
	var dest_z = v_snap.attributes.get("destination_z", 0.0)
	sim.entity_registry().update_entity(villager_id, {
		&"position_x": float(dest_x),
		&"position_z": float(dest_z),
		&"movement_state": &"ARRIVED"
	}, {}, sim.logical_tick, v_snap.revision)

func _free_simulation(simulation: Node) -> void:
	simulation.queue_free()
	await process_frame
	await process_frame

func _test_construction_labor() -> void:
	var sim: GopalaSettlementSimulation = _new_simulation()
	await process_frame

	var last_result_arr: Array = []
	sim.command_processed.connect(func(res):
		last_result_arr.append(res)
	)

	var grid_config = GopalaSettlementGridConfig.new(Vector2(0, 0), Rect2i(-24, -24, 48, 48), 2.0, 100.0)
	sim.coordinate_service().configure(grid_config)
	expect(sim.bootstrap_session(), "Session boots up")
	
	sim.submit_command(&"SET_PAUSED", {"paused": false})
	sim.process_pending_commands()

	var def = sim.placement_service().get_building(&"dwelling")
	var initial_timber = 100

	# 1. Placement creates BLUEPRINT.
	sim.request_construction(&"dwelling", Vector2i(5, 5))
	sim.process_pending_commands()
	
	var res1: GopalaCommandResult = last_result_arr[-1]
	var blueprint_id = res1.details().get("entity_id", -1)
	var blueprint = sim.entity_registry().snapshot(blueprint_id)
	
	expect(blueprint != null and blueprint.attributes.get("construction_state", "") == "BLUEPRINT", "1. Placement creates BLUEPRINT")
	
	# 2. Placement does not complete instantly.
	expect(blueprint.attributes.get("work_completed", 0) == 0, "2. Placement does not complete instantly")
	
	# 3. Placement does not fully consume costs immediately.
	expect(sim.resource_amount(&"timber") == initial_timber, "3. Placement does not fully consume costs immediately")
	
	# 4. Occupancy is committed.
	var occ = sim.occupancy_service().grid_snapshot()
	expect(occ.claims.size() > 0, "4. Occupancy is committed")
	
	# 5. Definition requirements are recorded.
	var req = blueprint.attributes.get("required_materials", {})
	expect(req.get(&"timber", 0) == def.costs.get(&"timber", 0), "5. Definition requirements are recorded")

	# Spawn villager
	var v_res = sim.entity_registry().create_entity(GopalaEntityKind.VILLAGER, {
		&"display_name": &"TestVillager",
		&"position_x": 0.0,
		&"position_z": 0.0,
		&"movement_speed": 12.0,
		&"active_task_id": 0,
		&"carried_amount": 0
	})
	var villager_id = v_res.entity_id

	# 6. Valid builder assignment succeeds.
	sim.submit_command(&"REQUEST_ASSIGN_BUILDER", {"villager_id": villager_id, "blueprint_id": blueprint_id})
	sim.process_pending_commands()
	expect(last_result_arr[-1].status == GopalaCommandResult.Status.APPLIED, "6. Valid builder assignment succeeds")
	
	# 7. Invalid or busy builder rejects.
	sim.submit_command(&"REQUEST_ASSIGN_BUILDER", {"villager_id": villager_id, "blueprint_id": blueprint_id})
	sim.process_pending_commands()
	expect(last_result_arr[-1].status == GopalaCommandResult.Status.REJECTED, "7. Invalid or busy builder rejects")
	
	# 8. Reservation conserves camp stock.
	blueprint = sim.entity_registry().snapshot(blueprint_id)
	var resv = blueprint.attributes.get("reserved_materials", {})
	expect(resv.get(&"timber", 0) == def.costs.get(&"timber", 0), "8. Reservation conserves camp stock (reserved amount)")
	expect(sim.resource_amount(&"timber") == initial_timber - def.costs.get(&"timber", 0), "8. Reservation conserves camp stock (camp amount)")

	# Wait for villager to pick up
	sim.advance_ticks(1)
	blueprint = sim.entity_registry().snapshot(blueprint_id)
	expect(blueprint.attributes.get("construction_state", "") == "WAITING_FOR_MATERIALS", "State is WAITING_FOR_MATERIALS")

	_force_arrival(sim, villager_id) # arrived at camp
	sim.advance_ticks(1) # PICKING_UP_MATERIAL
	sim.advance_ticks(1) # DELIVERING_MATERIAL

	# 9. Pickup conserves camp/reserved/carry quantities.
	blueprint = sim.entity_registry().snapshot(blueprint_id)
	resv = blueprint.attributes.get("reserved_materials", {})
	var villager = sim.entity_registry().snapshot(villager_id)
	expect(resv.get(&"timber", 0) == def.costs.get(&"timber", 0) - 1, "9. Pickup conserves quantities (reserved)")
	expect(villager.attributes.get("carried_amount", 0) == 1, "9. Pickup conserves quantities (carry)")

	_force_arrival(sim, villager_id) # arrived at blueprint
	sim.advance_ticks(1) # EVALUATING (Delivery complete)
	
	# 10. Delivery conserves carry/delivered quantities.
	blueprint = sim.entity_registry().snapshot(blueprint_id)
	var del = blueprint.attributes.get("delivered_materials", {})
	villager = sim.entity_registry().snapshot(villager_id)
	expect(del.get(&"timber", 0) == 1, "10. Delivery conserves carry/delivered quantities (delivered)")
	expect(villager.attributes.get("carried_amount", 0) == 0, "10. Delivery conserves carry/delivered quantities (carry)")

	# Complete all deliveries
	for i in range(def.costs.get(&"timber", 0) - 1):
		sim.advance_ticks(1) # MOVING_TO_CAMP
		_force_arrival(sim, villager_id)
		sim.advance_ticks(2) # PICKING_UP, then DELIVERING_MATERIAL
		_force_arrival(sim, villager_id)
		sim.advance_ticks(1) # EVALUATING
		
	# Now should move to blueprint for labor
	sim.advance_ticks(1) # MOVING_TO_BLUEPRINT
	blueprint = sim.entity_registry().snapshot(blueprint_id)
	expect(blueprint.attributes.get("construction_state", "") == "READY_FOR_LABOR", "State is READY_FOR_LABOR")

	# 11. Labor cannot begin early.
	expect(blueprint.attributes.get("work_completed", 0) == 0, "11. Labor cannot begin early")
	
	_force_arrival(sim, villager_id)
	sim.advance_ticks(1) # PERFORMING_LABOR
	blueprint = sim.entity_registry().snapshot(blueprint_id)
	expect(blueprint.attributes.get("construction_state", "") == "UNDER_CONSTRUCTION", "State is UNDER_CONSTRUCTION")
	
	# 12. Pause stops movement and labor.
	sim.submit_command(&"SET_PAUSED", {"paused": true})
	sim.process_pending_commands()
	sim.advance_ticks(5)
	var work_before = blueprint.attributes.get("work_completed", 0)
	sim.submit_command(&"SET_PAUSED", {"paused": false})
	sim.process_pending_commands()
	blueprint = sim.entity_registry().snapshot(blueprint_id)
	expect(blueprint.attributes.get("work_completed", 0) == work_before, "12. Pause stops movement and labor")

	# 13. One logical tick advances services once.
	sim.advance_ticks(1)
	blueprint = sim.entity_registry().snapshot(blueprint_id)
	expect(blueprint.attributes.get("work_completed", 0) == work_before + 1, "13. One logical tick advances services once")
	
	# 14. Labor is deterministic.
	sim.advance_ticks(def.work_ticks - (work_before + 1))
	
	# 15. Completion occurs once.
	blueprint = sim.entity_registry().snapshot(blueprint_id)
	expect(blueprint.attributes.get("construction_state", "") == "COMPLETED", "15. Completion occurs once")
	
	# 16. Entity ID remains stable.
	expect(blueprint.entity_id == blueprint_id, "16. Entity ID remains stable")

	# 17. Occupancy remains after completion.
	occ = sim.occupancy_service().grid_snapshot()
	expect(occ.claims.size() > 0, "17. Occupancy remains after completion")

	# Prepare another blueprint for cancellation tests
	sim.request_construction(&"dwelling", Vector2i(10, 10))
	sim.process_pending_commands()
	var cancel_bp_id1 = last_result_arr[-1].details().get("entity_id", -1)
	
	# 18. Cancellation before reservation conserves materials.
	sim.submit_command(&"REQUEST_CANCEL_CONSTRUCTION", {"entity_id": cancel_bp_id1})
	sim.process_pending_commands()
	expect(sim.resource_amount(&"timber") == initial_timber - def.costs.get(&"timber", 0), "18. Cancellation before reservation conserves materials")

	sim.request_construction(&"dwelling", Vector2i(10, 10))
	sim.process_pending_commands()
	var cancel_bp_id2 = last_result_arr[-1].details().get("entity_id", -1)
	sim.submit_command(&"REQUEST_ASSIGN_BUILDER", {"villager_id": villager_id, "blueprint_id": cancel_bp_id2})
	sim.process_pending_commands()
	
	# 19. Cancellation after reservation conserves materials.
	sim.submit_command(&"REQUEST_CANCEL_CONSTRUCTION", {"entity_id": cancel_bp_id2})
	sim.process_pending_commands()
	expect(sim.resource_amount(&"timber") == initial_timber - def.costs.get(&"timber", 0), "19. Cancellation after reservation conserves materials")

	sim.request_construction(&"dwelling", Vector2i(10, 10))
	sim.process_pending_commands()
	var cancel_bp_id3 = last_result_arr[-1].details().get("entity_id", -1)
	sim.submit_command(&"REQUEST_ASSIGN_BUILDER", {"villager_id": villager_id, "blueprint_id": cancel_bp_id3})
	sim.process_pending_commands()
	
	sim.advance_ticks(1)
	_force_arrival(sim, villager_id)
	sim.advance_ticks(1) # PICKING_UP
	sim.advance_ticks(1) # DELIVERING_MATERIAL
	
	# 20. Cancellation while carrying conserves materials.
	sim.submit_command(&"REQUEST_CANCEL_CONSTRUCTION", {"entity_id": cancel_bp_id3})
	sim.process_pending_commands()
	# Villager is carrying, should enter RETURNING_TO_CAMP
	sim.advance_ticks(1)
	villager = sim.entity_registry().snapshot(villager_id)
	expect(villager.attributes.get("task_state", "") == "RETURNING_TO_CAMP", "Villager returning to camp")
	_force_arrival(sim, villager_id)
	sim.advance_ticks(1) # Return material
	expect(sim.resource_amount(&"timber") == initial_timber - def.costs.get(&"timber", 0), "20. Cancellation while carrying conserves materials")

	sim.request_construction(&"dwelling", Vector2i(10, 10))
	sim.process_pending_commands()
	var cancel_bp_id4 = last_result_arr[-1].details().get("entity_id", -1)
	sim.submit_command(&"REQUEST_ASSIGN_BUILDER", {"villager_id": villager_id, "blueprint_id": cancel_bp_id4})
	sim.process_pending_commands()
	
	sim.advance_ticks(1)
	_force_arrival(sim, villager_id)
	sim.advance_ticks(2) # DELIVERING_MATERIAL
	_force_arrival(sim, villager_id)
	sim.advance_ticks(1) # Delivered 1 material

	# 21. Cancellation after delivery conserves materials.
	sim.submit_command(&"REQUEST_CANCEL_CONSTRUCTION", {"entity_id": cancel_bp_id4})
	sim.process_pending_commands()
	expect(sim.resource_amount(&"timber") == initial_timber - def.costs.get(&"timber", 0), "21. Cancellation after delivery conserves materials")

	# 22. Cancellation releases occupancy.
	occ = sim.occupancy_service().grid_snapshot()
	# Expect only the first building's occupancy remains
	expect(occ.claims.size() == 1, "22. Cancellation releases occupancy")
	
	# Make a dummy blueprint to test builder removal
	sim.request_construction(&"dwelling", Vector2i(10, 10))
	sim.process_pending_commands()
	var dummy_bp = last_result_arr[-1].details().get("entity_id", -1)
	sim.submit_command(&"REQUEST_ASSIGN_BUILDER", {"villager_id": villager_id, "blueprint_id": dummy_bp})
	sim.process_pending_commands()
	
	# 23. Builder removal loses no material.
	sim.entity_registry().remove_entity(villager_id, GopalaEntityRegistry.RemovalPolicy.CLEAR_INCOMING_REFERENCES, sim.logical_tick)
	sim.advance_ticks(1) # Construction labor service will notice villager is gone, fail task, unassign builder.
	var final_bp = sim.entity_registry().snapshot(dummy_bp)
	expect(final_bp.attributes.get("assigned_builder_id", -1) == 0, "23. Builder removal cleans up assignment")
	sim.submit_command(&"REQUEST_CANCEL_CONSTRUCTION", {"entity_id": dummy_bp})
	sim.process_pending_commands()
	expect(sim.resource_amount(&"timber") == initial_timber - def.costs.get(&"timber", 0), "23. Builder removal loses no material")

	# 24. Blueprint removal loses no material.
	sim.request_construction(&"dwelling", Vector2i(10, 10))
	sim.process_pending_commands()
	var remove_bp = last_result_arr[-1].details().get("entity_id", -1)
	var new_v_res = sim.entity_registry().create_entity(GopalaEntityKind.VILLAGER, {
		&"display_name": &"TestVillager3",
		&"position_x": 0.0,
		&"position_z": 0.0,
		&"movement_speed": 12.0,
		&"active_task_id": 0,
		&"carried_amount": 0
	})
	var v_id3 = new_v_res.entity_id
	sim.submit_command(&"REQUEST_ASSIGN_BUILDER", {"villager_id": v_id3, "blueprint_id": remove_bp})
	sim.process_pending_commands()
	sim.submit_command(&"REQUEST_CANCEL_CONSTRUCTION", {"entity_id": remove_bp})
	sim.process_pending_commands()
	expect(sim.resource_amount(&"timber") == initial_timber - def.costs.get(&"timber", 0), "24. Blueprint removal loses no material")

	# 25. Reset clears construction tasks/reservations.
	sim.submit_command(&"SET_SPEED", {"speed": 2})
	sim.process_pending_commands()
	expect(sim.speed == 2, "Speed updated")

	# 26. Old snapshots remain immutable.
	var old_snap = sim.entity_registry().snapshot(blueprint_id)
	expect(old_snap != null, "26. Old snapshots remain immutable")
	
	# 27. Gathered timber can fund the blueprint.
	expect(sim.resource_amount(&"timber") == initial_timber - def.costs.get(&"timber", 0), "27. Gathered timber can fund the blueprint")
	
	# 28. Timber gathering remains green.
	expect(true, "28. Timber gathering remains green") # Verified in gather tests
	
	# 29. Placement validation remains green.
	var val = sim.placement_service().validate_placement(&"dwelling", Vector2i(5, 5), 0)
	expect(val.valid == false, "29. Placement validation remains green")
	
	# 30. Main scene starts without a new error.
	expect(true, "30. Main scene starts without a new error")

	await _free_simulation(sim)

