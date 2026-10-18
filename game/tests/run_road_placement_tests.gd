extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func run() -> void:
	var sim := GopalaSettlementSimulation.new()
	root.add_child(sim)
	sim.set_physics_process(false)
	sim.coordinate_service().configure(GopalaSettlementGridConfig.new(Vector2.ZERO, Rect2i(-8, -8, 16, 16), 2.0, 100.0))
	sim._route_service.enable(Rect2i(-8, -8, 16, 16))
	var before := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.ROAD).size()
	check(not sim.road_service().validate_cells([]).valid, "Empty route is rejected")
	check(sim.road_service().validate_cells([Vector2i.ZERO, Vector2i(2, 0)]).reason_code == &"PATH_DISCONNECTED", "Route cells must form a continuous orthogonal line")
	check(sim.road_service().validate_cells([Vector2i(-2,0),Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)]).valid, "Intermediate logical cells produce a continuous straight path")
	check(sim.road_service().validate_cells([Vector2i(-9, 0), Vector2i(-8, 0)]).reason_code == &"OUT_OF_BOUNDS", "Out-of-bounds terrain is rejected")
	check(sim.road_service().validate_cells([Vector2i(-2, 0), Vector2i(-2, 0)]).reason_code == &"PATH_DUPLICATE_CELL", "Repeated cells are rejected instead of silently changing the route")

	var blocker := sim.entity_registry().create_entity(GopalaEntityKind.BUILDING, {}).entity_id
	check(sim.occupancy_service().reserve_cells(blocker, [Vector2i(1, 0)], 0).status == GopalaOccupancyOperationResult.Status.APPLIED, "Building footprint reserves its cell")
	check(not sim.road_service().validate_cells([Vector2i(0, 0), Vector2i(1, 0)]).valid, "Path cannot occupy a building footprint")
	sim.occupancy_service().release_claim(blocker, &"TEST", 0)

	var zone_cells: Array = []
	for y in range(2):
		for x in range(2): zone_cells.append([x, y])
	sim.entity_registry().create_entity(GopalaEntityKind.ZONE, {&"zone_cells": zone_cells})
	check(not sim.road_service().validate_cells([Vector2i.ZERO, Vector2i(1, 0)]).valid, "Path cannot cut through a pasture")
	var zone := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.ZONE)[0]
	sim.entity_registry().remove_entity(zone.entity_id, GopalaEntityRegistry.RemovalPolicy.CLEAR_INCOMING_REFERENCES, 0)

	var straight_cells: Array[Vector2i] = []
	for x in range(-2, 3): straight_cells.append(Vector2i(x, 0))
	var placed := _place_road(sim, straight_cells)
	check(placed.status == GopalaCommandResult.Status.APPLIED, "A valid drag enters the simulation command queue and places a road")
	var road := sim.entity_queries().snapshot(int(placed.details().get("entity_id", 0)))
	check(road != null and road.kind == GopalaEntityKind.ROAD and road.attributes.road_cells.size() == 5, "Road geometry is persisted as plain cell coordinates")
	check(sim.road_service().road_cells().size() == 5, "Road query exposes all authored cells")
	check(not sim.road_service().validate_cells([Vector2i(-2, 0), Vector2i(-1, 0)]).valid, "Existing path cells cannot be duplicated")
	check(sim.placement_service().validate_placement(&"dwelling", Vector2i(-2, 0), 0).reason_code == &"ROAD_OCCUPIED", "Building placement cannot erase an existing road")
	check(sim.road_service().validate_cells([Vector2i(-2, 0), Vector2i(-1, 1)]).reason_code == &"PATH_DISCONNECTED", "Diagonal jumps are rejected")
	check(sim._route_service.is_open(Vector2i(0, 0)), "Road surface remains traversable")

	var winding: Array[Vector2i] = [Vector2i(-4,2),Vector2i(-3,2),Vector2i(-2,2),Vector2i(-2,3),Vector2i(-1,3),Vector2i(0,3),Vector2i(0,2),Vector2i(1,2),Vector2i(2,2),Vector2i(3,2)]
	var curved := _place_road(sim, winding)
	check(curved.status == GopalaCommandResult.Status.APPLIED, "An orthogonal winding path persists as a second stretch")
	check(sim.road_service().road_cells().size() == 15, "Both path segments expose their combined unique cells")

	var start_cell := Vector2i(-4, 0)
	var target_cell := Vector2i(3, 0)
	var start := sim.coordinate_service().settlement_cell_to_world_xz(start_cell)
	var target := sim.coordinate_service().settlement_cell_to_world_xz(target_cell)
	var route := sim._route_service.plan(start, target, &"MOVE")
	check(route.ok and route.points.size() >= 2, "Route planner finds a walkable path")
	if route.ok:
		var uses_road := false
		for point: Vector2 in route.points:
			if sim.road_service().road_cells().has(sim.coordinate_service().world_to_settlement_cell(point)):
				uses_road = true
		check(uses_road, "Path cells participate in route planning")
		check(_route_duration(route.points, sim) < 12.0, "Dirt path lowers traversal time across the local grid")
	check(is_equal_approx(sim._route_service.movement_multiplier(Vector2i(0,0)),1.25), "Dirt paths increase worker traversal speed by the authored multiplier")
	var timber_before_upgrade := sim.resource_amount(&"timber")
	var stone_before_upgrade := sim.resource_amount(&"stone")
	check(sim.road_service().validate_cobbled_cells([Vector2i(-2,0),Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0)]).reason_code == &"PATH_NOT_FOUND", "Cobbled upgrade rejects cells without an existing route")
	var upgrading: Array[Vector2i] = [Vector2i(-2,0),Vector2i(-1,0),Vector2i(0,0)]
	check(sim._seed_resources_for_tests({&"timber":3,&"stone":6}), "Fixture stocks materials for the path upgrade")
	var upgrade_result := _upgrade_path(sim, upgrading)
	check(upgrade_result.status == GopalaCommandResult.Status.APPLIED and upgrade_result.reason_code == &"PATH_UPGRADE_PLANNED", "A valid continuous dirt section queues paving and completes through a builder")
	check(sim.resource_amount(&"timber") == timber_before_upgrade and sim.resource_amount(&"stone") == stone_before_upgrade, "Upgrade consumes exactly one timber and two stone per upgraded cell")
	check(sim.road_service().road_quality_at(Vector2i(-1,0)) == &"cobbled" and sim.road_service().road_quality_at(Vector2i(1,0)) == &"dirt", "Upgrade changes only the selected cells and preserves remaining dirt")
	check(is_equal_approx(sim._route_service.movement_multiplier(Vector2i(-1,0)),1.6), "Cobbled paths grant a stronger worker speed multiplier")
	check(sim.road_service().validate_cobbled_cells(upgrading).reason_code == &"PATH_ALREADY_COBBLED", "Already upgraded cells cannot be charged twice")
	check(sim.road_service().validate_cobbled_cells([Vector2i(-2,0),Vector2i(3,0)]).reason_code == &"PATH_DISCONNECTED", "Cobbled requests reject disconnected spans")
	var separate_segment: Array[Vector2i] = [Vector2i(-6,-2),Vector2i(-5,-2)]
	check(_place_road(sim,separate_segment).status == GopalaCommandResult.Status.APPLIED, "Separate dirt road segment can be placed")
	var adjacent_segment: Array[Vector2i] = [Vector2i(-4,-2),Vector2i(-3,-2)]
	check(_place_road(sim,adjacent_segment).status == GopalaCommandResult.Status.APPLIED, "Another adjacent dirt segment can be placed independently")
	var cross_segment: Array[Vector2i] = [Vector2i(-5,-2),Vector2i(-4,-2)]
	check(sim.road_service().validate_cobbled_cells(cross_segment).reason_code == &"PATH_SPANS_SEGMENTS", "Cobbled requests cannot span separately placed road entities")
	var timber_after_first := sim.resource_amount(&"timber")
	var stone_after_first := sim.resource_amount(&"stone")
	check(sim.road_service().validate_cobbled_cells([Vector2i(1,0),Vector2i(2,0)]).reason_code == &"INSUFFICIENT_RESOURCES", "Insufficient stored materials reject the requested upgrade")
	var poor_upgrade := _upgrade_path(sim, [Vector2i(1,0),Vector2i(2,0)])
	check(poor_upgrade.status == GopalaCommandResult.Status.REJECTED and sim.resource_amount(&"timber") == timber_after_first and sim.resource_amount(&"stone") == stone_after_first, "Rejected upgrade preserves every resource balance")

	var codec := GopalaSettlementSave.new()
	var state := codec.capture(sim, {})
	var restored := codec.restore(state, sim, {})
	check(restored != null, "Road save state restores successfully: " + codec.error)
	if restored != null:
		check(restored.road_service().road_cells().size() == 19, "All four road segments survive save and load")
		check(restored._route_service.is_open(Vector2i(0, 0)), "Restored road routes rebuild as walkable")
		var restored_road := restored.entity_queries().snapshot(road.entity_id)
		check(restored_road != null and restored_road.attributes.get(&"cobbled_cells", []).size() == 3 and restored.road_service().road_quality_at(Vector2i(-1,0)) == &"cobbled" and restored.road_service().road_quality_at(Vector2i(1,0)) == &"dirt", "Mixed cobbled/dirt quality survives save/load")
		check(is_equal_approx(restored._route_service.movement_multiplier(Vector2i(-1,0)),1.6), "Cobbled travel speed survives save/load")
		check(restored.resource_amount(&"timber") == sim.resource_amount(&"timber") and restored.resource_amount(&"stone") == sim.resource_amount(&"stone"), "Upgraded path and stockpile balances restore together")
		var restored_route := restored._route_service.plan(start, target, &"MOVE")
		check(restored_route.ok and restored._route_service.movement_multiplier(Vector2i(0, 0)) > 1.0, "Road movement benefit survives save/load route rebuild")
		restored.free()

	var rejected := _place_road(sim, [Vector2i(-2,0),Vector2i(-1,1)])
	check(rejected.status == GopalaCommandResult.Status.REJECTED, "Invalid route is rejected by the queued simulation command")
	check(sim.entity_queries().snapshots_by_kind(GopalaEntityKind.ROAD).size() == before + 4, "Rejected routes do not create road records")

	sim.free()
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _place_road(sim: GopalaSettlementSimulation, cells: Array[Vector2i]) -> GopalaCommandResult:
	var results: Array[GopalaCommandResult] = []
	var on_result := func(result: GopalaCommandResult) -> void: results.append(result)
	sim.command_processed.connect(on_result)
	sim.request_road(cells)
	sim.process_pending_commands()
	sim.command_processed.disconnect(on_result)
	var result: GopalaCommandResult = results[0] if not results.is_empty() else null
	if result != null and result.status == GopalaCommandResult.Status.APPLIED: _complete_road(sim,int(result.details().entity_id))
	return result

func _upgrade_path(sim: GopalaSettlementSimulation, cells: Array[Vector2i]) -> GopalaCommandResult:
	var results: Array[GopalaCommandResult] = []
	var on_result := func(result: GopalaCommandResult) -> void: results.append(result)
	sim.command_processed.connect(on_result)
	sim.request_cobbled_path(cells)
	sim.process_pending_commands()
	sim.command_processed.disconnect(on_result)
	var result: GopalaCommandResult = results[0] if not results.is_empty() else null
	if result != null and result.status == GopalaCommandResult.Status.APPLIED: _complete_road(sim,int(result.details().entity_id))
	return result

func _route_duration(points: Array[Vector2], sim: GopalaSettlementSimulation) -> float:
	var duration := 0.0
	for index in range(1, points.size()):
		var midpoint: Vector2 = points[index - 1].lerp(points[index], 0.5)
		var cell := sim.coordinate_service().world_to_settlement_cell(midpoint)
		duration += points[index - 1].distance_to(points[index]) / GopalaScaleStandard.number("movement", "walk_speed") / sim._route_service.movement_multiplier(cell)
	return duration

func _complete_road(sim: GopalaSettlementSimulation, id: int) -> void:
	if sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER).is_empty():
		var worker := sim.villager_service().spawn_villager(Vector2.ZERO)
		var snap := sim.entity_queries().snapshot(worker)
		sim.entity_registry().update_entity(worker,{&"movement_speed":10.0},{},0,snap.revision)
	sim.set_paused(false)
	sim.process_pending_commands()
	for tick in 1000:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(id).attributes.get("construction_state") == "COMPLETED": return
	check(false,"Builder completes road through actual movement and labor")
