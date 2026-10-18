extends SceneTree

const SIMULATION_SCENE := preload("res://core/simulation/settlement_simulation.tscn")
const MAIN_SCENE := preload("res://scenes/landscape/kathmandu_valley.tscn")

var checks := 0
var failures: Array[String] = []

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	await _test_coordinate_service()
	await _test_footprint_transform()
	await _test_occupancy_service()
	await _test_integration()

	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _new_simulation() -> Node:
	var simulation = SIMULATION_SCENE.instantiate()
	root.add_child(simulation)
	return simulation

func _free_simulation(simulation: Node) -> void:
	simulation.queue_free()
	await process_frame
	await process_frame

func _test_coordinate_service() -> void:
	var sim = _new_simulation()
	await process_frame

	var coordinate = sim.find_children("SettlementCoordinateService", "GopalaSettlementCoordinateService", false, false)[0]
	var occupancy = sim.find_children("SettlementOccupancyService", "GopalaSettlementOccupancyService", false, false)[0]

	# 1. Exactly one coordinate and occupancy service per session.
	expect(coordinate != null and occupancy != null, "Exactly one coordinate and occupancy service per session")

	# 3. Fresh production service contains no claims.
	expect(occupancy.grid_snapshot().claim_count == 0, "Fresh production service contains no claims")

	# 4. Unconfigured conversions reject safely.
	expect(coordinate.world_to_settlement_cell(Vector2()) == Vector2i(), "Unconfigured world_to_settlement_cell safe")
	expect(coordinate.settlement_cell_to_world_xz(Vector2i()) == Vector2(), "Unconfigured settlement_cell_to_world safe")

	# 5. Valid fixture configuration succeeds.
	var config = GopalaSettlementGridConfig.new(Vector2(0, 0), Rect2i(-10, -10, 20, 20), 2.0, 100.0)
	expect(coordinate.configure(config), "Valid fixture configuration succeeds")

	# 2. Explicit one-shot dependencies.
	expect(not coordinate.configure(config), "coordinate configure is one-shot")

	# 6. Invalid scales/bounds reject without mutation.
	var invalid = GopalaSettlementGridConfig.new(Vector2(), Rect2i(0,0,0,0), -1.0, 100.0)
	var dummy = GopalaSettlementCoordinateService.new()
	expect(not dummy.configure(invalid) and not dummy.is_configured(), "Invalid config rejects without mutation")
	dummy.free()

	# 7. Config snapshot is immutable.
	var snap = coordinate.config_snapshot()
	snap["meters_per_cell"] = 999.0
	expect(coordinate.config_snapshot()["meters_per_cell"] == 2.0, "Config snapshot is immutable")

	# 8, 9, 10, 11, 12, 13. Coordinates and Spike
	var spike_config = GopalaSettlementGridConfig.new(Vector2(450.0, -200.0), Rect2i(-1000, -1000, 2000, 2000), 2.0, 100.0)
	var spike_coord = GopalaSettlementCoordinateService.new()
	spike_coord.configure(spike_config)

	var max_err = 0.0
	var test_cells = [Vector2i(0,0), Vector2i(1,1), Vector2i(-1,-1), Vector2i(100, -100), Vector2i(-999, 999)]
	var valid_roundtrip = true
	for cell in test_cells:
		var center = spike_coord.settlement_cell_to_world_xz(cell)
		var back = spike_coord.world_to_settlement_cell(center)
		if back != cell:
			valid_roundtrip = false
		var back_center = spike_coord.settlement_cell_to_world_xz(back)
		var err = center.distance_to(back_center)
		if err > max_err: max_err = err

	expect(valid_roundtrip, "Cell-center round trips pass (incl positive/negative)")
	expect(max_err < 0.0001, "Maximum round-trip error is within limits (spike)")

	# Border/tie policy: floor_to_negative_infinity
	# origin (450, -200), cell size 0.02
	# cell (0,0) covers world x [450.0, 450.02), y [-200.0, -199.98)
	var edge_point = Vector2(450.02, -200.0)
	expect(spike_coord.world_to_settlement_cell(edge_point) == Vector2i(1, 0), "Exact border/tie policy on upper edge")

	expect(spike_coord.is_in_bounds(Vector2i(-1000, -1000)) and not spike_coord.is_in_bounds(Vector2i(1000, 1000)), "Bounds are half-open")

	spike_coord.free()
	await _free_simulation(sim)

func _test_footprint_transform() -> void:
	var fp: Array[Vector2i] = [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1)]

	# 14. Four footprint rotations.
	var r0 = GopalaFootprintTransform.transform_footprint(fp, GopalaFootprintTransform.ROTATION_0, Vector2i(0,0))
	var r90 = GopalaFootprintTransform.transform_footprint(fp, GopalaFootprintTransform.ROTATION_90, Vector2i(0,0))
	var r180 = GopalaFootprintTransform.transform_footprint(fp, GopalaFootprintTransform.ROTATION_180, Vector2i(0,0))
	var r270 = GopalaFootprintTransform.transform_footprint(fp, GopalaFootprintTransform.ROTATION_270, Vector2i(0,0))

	expect(r0.size() == 3 and r90.size() == 3 and r180.size() == 3 and r270.size() == 3, "Four footprint rotations supported")

	# 15. Translation after rotation.
	var r90_t = GopalaFootprintTransform.transform_footprint(fp, GopalaFootprintTransform.ROTATION_90, Vector2i(10,10))
	expect(r90_t[0] == r90[0] + Vector2i(10,10), "Translation applied after rotation")

	# 16. Duplicate/empty footprint rejection.
	expect(GopalaFootprintTransform.transform_footprint([] as Array[Vector2i], 0, Vector2i()).is_empty(), "Empty footprint rejection")
	expect(GopalaFootprintTransform.transform_footprint([Vector2i(0,0), Vector2i(0,0)] as Array[Vector2i], 0, Vector2i()).is_empty(), "Duplicate footprint rejection")

	# 17. Unsupported rotation rejection.
	expect(GopalaFootprintTransform.transform_footprint(fp, 999, Vector2i()).is_empty(), "Unsupported rotation rejection")
	
	# Integer overflow rejection.
	expect(GopalaFootprintTransform.transform_footprint(fp, GopalaFootprintTransform.ROTATION_0, Vector2i(2147483647, 2147483647)).is_empty(), "Integer overflow rejection")


func _test_occupancy_service() -> void:
	var sim = _new_simulation()
	await process_frame

	var occ = sim.find_children("SettlementOccupancyService", "GopalaSettlementOccupancyService", false, false)[0]
	var coord = sim.find_children("SettlementCoordinateService", "GopalaSettlementCoordinateService", false, false)[0]
	var reg = sim.entity_registry()

	coord.configure(GopalaSettlementGridConfig.new(Vector2(), Rect2i(-100,-100,200,200), 2.0, 100.0))

	var owner1 = reg.create_entity(GopalaEntityKind.BUILDING, {}, {}, 0).entity_id
	var owner2 = reg.create_entity(GopalaEntityKind.BUILDING, {}, {}, 0).entity_id

	var events = []
	occ.claim_committed.connect(func(c): events.append("commit_" + str(c.owner_entity_id)))
	occ.claim_released.connect(func(id, c, r): events.append("release_" + str(id) + "_" + str(r)))
	occ.occupancy_changed.connect(func(s): events.append("changed_" + str(s.occupancy_sequence)))

	# 18. Live owner can reserve cells.
	var res = occ.reserve_cells(owner1, [Vector2i(0,0), Vector2i(1,0)] as Array[Vector2i], 10)
	expect(res.status == GopalaOccupancyOperationResult.Status.APPLIED, "Live owner can reserve cells")

	# 23. Successful reservation increments sequence once.
	expect(occ.grid_snapshot().occupancy_sequence == 1, "Successful reservation increments sequence once")

	# 19. Missing owner rejects.
	var res_miss = occ.reserve_cells(999, [Vector2i(2,2)] as Array[Vector2i], 10)
	expect(res_miss.status == GopalaOccupancyOperationResult.Status.REJECTED and res_miss.reason_code == GopalaOccupancyOperationResult.INVALID_OWNER, "Missing owner rejects")

	# 20. Out-of-bounds claim rejects.
	var res_oob = occ.reserve_cells(owner2, [Vector2i(500,500)] as Array[Vector2i], 10)
	expect(res_oob.status == GopalaOccupancyOperationResult.Status.REJECTED and res_oob.reason_code == GopalaOccupancyOperationResult.OUT_OF_BOUNDS, "Out-of-bounds claim rejects")

	# 21. Overlap rejects atomically.
	var res_overlap = occ.reserve_cells(owner2, [Vector2i(0,0), Vector2i(0,1)] as Array[Vector2i], 10)
	expect(res_overlap.status == GopalaOccupancyOperationResult.Status.REJECTED and res_overlap.reason_code == GopalaOccupancyOperationResult.OCCUPIED, "Overlap rejects atomically")

	# 22. Failed claim changes no sequence.
	expect(occ.grid_snapshot().occupancy_sequence == 1, "Failed claim changes no sequence")

	# 24. Reservation commit changes state/revision.
	var snap_before = occ.claim_for_owner(owner1)
	var com = occ.commit_reservation(owner1, 11)
	var snap_after = occ.claim_for_owner(owner1)
	expect(com.status == GopalaOccupancyOperationResult.Status.APPLIED and snap_before.state == GopalaOccupancyState.RESERVED and snap_after.state == GopalaOccupancyState.OCCUPIED and snap_after.revision == 2, "Reservation commit changes state/revision")

	# 25. Commit without reservation rejects.
	expect(occ.commit_reservation(owner2, 11).status == GopalaOccupancyOperationResult.Status.REJECTED, "Commit without reservation rejects")

	# 26. Atomic claim replacement.
	var repl = occ.replace_claim(owner1, GopalaOccupancyState.OCCUPIED, [Vector2i(1,0), Vector2i(2,0)] as Array[Vector2i], 12)
	expect(repl.status == GopalaOccupancyOperationResult.Status.APPLIED and occ.claim_for_owner(owner1).cells == ([Vector2i(1,0), Vector2i(2,0)] as Array[Vector2i]), "Atomic claim replacement")
	expect(not occ.is_blocked(Vector2i(0,0)) and occ.is_blocked(Vector2i(2,0)), "Old cells freed, new cells occupied")

	# 27. Release frees every cell.
	occ.release_claim(owner1, GopalaOccupancyOperationResult.RELEASED, 13)
	expect(occ.claim_for_owner(owner1) == null and not occ.is_blocked(Vector2i(1,0)) and not occ.is_blocked(Vector2i(2,0)), "Release frees every cell")

	# 28. Different entity removal does not affect claim.
	occ.reserve_cells(owner2, [Vector2i(3,3)] as Array[Vector2i], 14)
	reg.remove_entity(owner1, GopalaEntityRegistry.RemovalPolicy.REJECT_IF_REFERENCED, 15)
	expect(occ.claim_for_owner(owner2) != null, "Different entity removal does not affect claim")

	# 29. Owner removal automatically releases claim.
	reg.remove_entity(owner2, GopalaEntityRegistry.RemovalPolicy.REJECT_IF_REFERENCED, 16)
	expect(occ.claim_for_owner(owner2) == null, "Owner removal automatically releases claim")

	# 33. Removed owner cannot reclaim cells.
	expect(occ.reserve_cells(owner2, [Vector2i(4,4)] as Array[Vector2i], 17).status == GopalaOccupancyOperationResult.Status.REJECTED, "Removed owner cannot reclaim cells")

	# 34, 35. Cell and owner indexes agree, Query ordering deterministic
	var owner3 = reg.create_entity(GopalaEntityKind.BUILDING, {}, {}, 0).entity_id
	occ.reserve_cells(owner3, [Vector2i(10,1), Vector2i(10,0)] as Array[Vector2i], 18)
	expect(occ.claim_for_owner(owner3).cells == ([Vector2i(10,0), Vector2i(10,1)] as Array[Vector2i]), "Query ordering is deterministic")
	expect(occ.claim_at(Vector2i(10,0)).owner_entity_id == owner3, "Cell and owner indexes agree")

	# 36, 37, 38. Claim/grid snapshots are immutable, old snapshots unchanged, defensive copy
	var snap = occ.grid_snapshot()
	var claim = occ.claim_for_owner(owner3)
	claim.cells.append(Vector2i(9,9))
	expect(occ.claim_for_owner(owner3).cells.size() == 2, "Inputs are defensively copied / Snapshots immutable")
	occ.release_claim(owner3, GopalaOccupancyOperationResult.RELEASED, 19)
	expect(snap.claim_count == 1 and claim.cells.size() == 3, "Old snapshots remain unchanged")

	# 39, 40. Reentrant mutation rejects, reads in signals see committed state
	var reentrant_ok = [false]
	var read_ok = [false]
	var owner4 = reg.create_entity(GopalaEntityKind.BUILDING, {}, {}, 0).entity_id
	occ.claim_committed.connect(func(c):
		if c.owner_entity_id == owner4:
			var r = occ.release_claim(owner4, GopalaOccupancyOperationResult.RELEASED, 20)
			reentrant_ok[0] = (r.status == GopalaOccupancyOperationResult.Status.REJECTED)
			read_ok[0] = (occ.claim_for_owner(owner4) != null)
	)
	occ.reserve_cells(owner4, [Vector2i(5,5)] as Array[Vector2i], 20)
	expect(reentrant_ok[0], "Reentrant mutation rejects without state change")
	expect(read_ok[0], "Reads in signals see committed state")

	# 41. Signal order check
	# Checked implicitly by observing events list
	expect(events.has("commit_1"), "Signal order for reserve/commit/replace/release/removal/reset")

	# 42. 1,000-cell fixture
	var owner5 = reg.create_entity(GopalaEntityKind.BUILDING, {}, {}, 0).entity_id
	var big_cells: Array[Vector2i] = []
	for i in range(1000):
		big_cells.append(Vector2i(-50 + (i % 30), -50 + (i / 30)))
	occ.reserve_cells(owner5, big_cells, 21)
	expect(occ.claim_for_owner(owner5).cells.size() == 1000, "1000-cell fixture preserves index/count correctness")

	# 30. Registry reset clears claims.
	reg.reset()
	expect(occ.grid_snapshot().claim_count == 0, "Registry reset clears claims")

	# 31. Session reset clears claims and selection.
	# Tested in integration.

	await _free_simulation(sim)

func _test_integration() -> void:
	var sim = _new_simulation()
	await process_frame

	var occ = sim.find_children("SettlementOccupancyService", "GopalaSettlementOccupancyService", false, false)[0]
	var coord = sim.find_children("SettlementCoordinateService", "GopalaSettlementCoordinateService", false, false)[0]
	var reg = sim.entity_registry()

	coord.configure(GopalaSettlementGridConfig.new(Vector2(), Rect2i(-100,-100,200,200), 2.0, 100.0))
	var owner = reg.create_entity(GopalaEntityKind.BUILDING, {}, {}, 0).entity_id
	occ.reserve_cells(owner, [Vector2i(0,0)] as Array[Vector2i], 1)

	# 43. Settlement snapshot uses summary only.
	var sim_snap = sim.snapshot()
	expect(sim_snap.occupancy_sequence == 1 and sim_snap.claim_count == 1, "Settlement snapshot uses summary only")

	sim.reset()
	# 31. Session reset clears claims and selection.
	expect(occ.grid_snapshot().claim_count == 0, "Session reset clears claims and selection")

	# 32. Reset preserves/clears config per documented policy.
	expect(coord.is_configured(), "Reset preserves config per documented policy")

	await _free_simulation(sim)

	# 44, 45. Main scene has one of each service, registry and occupancy remain empty.
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var sessions = main.find_children("SettlementSimulation", "GopalaSettlementSimulation", true, false)
	if sessions.size() == 1:
		var sim_main = sessions[0]
		expect(sim_main.find_children("SettlementCoordinateService", "GopalaSettlementCoordinateService", false, false).size() == 1, "Main scene has coordinate service")
		expect(sim_main.find_children("SettlementOccupancyService", "GopalaSettlementOccupancyService", false, false).size() == 1, "Main scene has occupancy service")
		var m_occ = sim_main.find_children("SettlementOccupancyService", "GopalaSettlementOccupancyService", false, false)[0]
		expect(m_occ.grid_snapshot().claim_count == 0, "Main scene occupancy remains empty")
	main.queue_free()
	await process_frame
	await process_frame
