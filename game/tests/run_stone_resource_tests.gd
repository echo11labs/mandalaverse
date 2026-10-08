extends SceneTree

var failures: Array[String] = []
var checks := 0
const SIM := preload("res://core/simulation/settlement_simulation.tscn")

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func run() -> void:
	var land := GopalaKathmanduTerrain.new()
	land.load_data()
	var valid := func(pos: Vector2) -> bool:
		return land.river_distance(pos.x, pos.y) >= 38.0 and land.normal_at(pos.x, pos.y, true).y >= cos(deg_to_rad(35.0))
	var scatter := GopalaStoneScatter.generate(land.camp, 43129, valid)
	check(scatter.size() == 24, "Kathmandu has 24 valid stone deposits")
	check(scatter == GopalaStoneScatter.generate(land.camp, 43129, valid), "Same seed reproduces positions and counts")
	check(scatter != GopalaStoneScatter.generate(land.camp, 123, valid), "Different seed changes deposits")
	check(GopalaStoneScatter.generate(land.camp, 43129, func(_p): return false).is_empty(), "Unsuitable terrain yields no deposits")
	for deposit in scatter:
		check(valid.call(deposit.position), "Stone avoids water and cliffs")
		check(deposit.position.distance_to(land.camp) >= 10.0, "Camp remains clear")
		for other in scatter:
			if other != deposit:
				check(deposit.position.distance_to(other.position) >= 5.0, "Deposits do not overlap")

	var distribution: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/resource_distribution.json"))
	for resource in GopalaSimulationCommand.COLLECTIBLE_RESOURCES:
		if not distribution.has(str(resource)): continue
		var profile: Dictionary = distribution[resource]
		var layout := GopalaStoneScatter.generate(land.camp, 43129, valid, int(profile.count), profile)
		check(layout.size() == int(profile.count), "Local seeded %s sources reach configured count" % resource)
		check(layout == GopalaStoneScatter.generate(land.camp, 43129, valid, int(profile.count), profile), "%s seed reproduces stock and positions" % resource)
		check(layout != GopalaStoneScatter.generate(land.camp, 113, valid, int(profile.count), profile), "%s changes with another seed" % resource)
		for source in layout:
			var distance: float = source.position.distance_to(land.camp) * GopalaScaleStandard.number("units", "regional_meters_per_world_unit")
			check(distance >= float(profile.radius_min_metres) - 0.001 and distance <= float(profile.radius_max_metres) + 0.001, "%s spacing uses physical metres" % resource)

	var sim = SIM.instantiate()
	root.add_child(sim)
	sim.set_process(false)
	sim.set_physics_process(false)
	sim.coordinate_service().configure(GopalaSettlementGridConfig.new(Vector2.ZERO, Rect2i(-24, -24, 48, 48), 2.0, 100.0))
	sim.bootstrap_session()
	GopalaScenarioSetup.setup_kathmandu_scenario(sim, Vector2.ZERO)
	sim.process_pending_commands()
	var villager_id: int = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)[0].entity_id
	var stone = sim.entity_registry().create_entity(GopalaEntityKind.RESOURCE_SOURCE, {
		&"resource_id": &"stone", &"available_amount": 1, &"reserved_amount": 0,
		&"position_x": 0.04, &"position_z": 0.04, &"gatherable": true, &"exhausted": false
	})
	var payload := {"villager_id": villager_id, "source_entity_id": stone.entity_id}
	var initial_stone: int = sim.resource_amount(&"stone")
	var initial_timber: int = sim.resource_amount(&"timber")
	var results: Array = []
	sim.command_processed.connect(func(result): results.append(result))
	sim.submit_command(GopalaSimulationCommand.REQUEST_GATHER_TIMBER, payload)
	sim.process_pending_commands()
	check(results[-1].status == GopalaCommandResult.Status.REJECTED, "Timber order cannot collect stone")
	sim.submit_command(GopalaSimulationCommand.REQUEST_GATHER_STONE, {"villager_id": "bad", "source_entity_id": stone.entity_id})
	sim.process_pending_commands()
	check(results[-1].status == GopalaCommandResult.Status.REJECTED, "Malformed order rejected")
	sim.submit_command(GopalaSimulationCommand.REQUEST_GATHER_STONE, payload)
	sim.process_pending_commands()
	check(results[-1].status == GopalaCommandResult.Status.APPLIED, "Camp accepts a stone order")
	check(sim.resource_amount(&"stone") == initial_stone, "Reservation does not add stored stone")
	check(sim.entity_queries().snapshot(stone.entity_id).attributes.get(&"reserved_amount") == 1, "Stone reserved once")
	sim.submit_command(GopalaSimulationCommand.REQUEST_GATHER_STONE, payload)
	sim.process_pending_commands()
	check(results[-1].status == GopalaCommandResult.Status.REJECTED, "Duplicate stone order rejected")
	sim.gather_delivery_service().cancel_task(villager_id, sim.logical_tick)
	check(sim.entity_queries().snapshot(stone.entity_id).attributes.get(&"available_amount") == 1, "Cancel restores source stone")
	check(sim.entity_queries().snapshot(stone.entity_id).attributes.get(&"reserved_amount") == 0, "Cancel clears reservation")
	sim.submit_command(GopalaSimulationCommand.REQUEST_GATHER_STONE, payload)
	sim.process_pending_commands()
	check(not sim.advance_ticks(5), "Pause freezes stone collection")
	sim.set_paused(false)
	sim.process_pending_commands()
	for i in 100:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(villager_id).attributes.get(&"carried_amount", 0) == 1:
			break
	var worker = sim.entity_queries().snapshot(villager_id)
	check(worker.attributes.get(&"carried_resource_id") == &"stone", "Worker carries stone, not timber")
	check(sim.resource_amount(&"stone") == initial_stone, "Pickup does not credit stored stone")
	check(sim.entity_queries().snapshot(stone.entity_id).attributes.get(&"exhausted"), "Last pickup depletes deposit")
	for i in 100:
		sim.advance_ticks(1)
		if sim.gather_delivery_service()._tasks.is_empty():
			break
	check(sim.resource_amount(&"stone") == initial_stone + 1, "Delivery credits one stone")
	check(sim.resource_amount(&"timber") == initial_timber, "Stone delivery preserves timber balance")
	check(sim.entity_queries().snapshot(villager_id).attributes.get(&"carried_amount") == 0, "Delivery clears carried stone")
	sim.advance_ticks(10)
	check(sim.resource_amount(&"stone") == initial_stone + 1, "Later ticks cannot duplicate delivery")
	sim.submit_command(GopalaSimulationCommand.REQUEST_GATHER_STONE, payload)
	sim.process_pending_commands()
	check(results[-1].reason_code == &"SOURCE_EXHAUSTED", "Depleted deposit rejects further collection")
	for resource in [&"timber", &"stone"]:
		var source = sim.entity_registry().create_entity(GopalaEntityKind.RESOURCE_SOURCE, {&"resource_id": resource, &"available_amount": 3, &"reserved_amount": 0, &"position_x": 0.02, &"position_z": 0.02, &"gatherable": true})
		var initial: int = sim.resource_amount(resource)
		var type := GopalaSimulationCommand.REQUEST_GATHER_STONE if resource == &"stone" else GopalaSimulationCommand.REQUEST_GATHER_TIMBER
		sim.submit_command(type, {"villager_id": villager_id, "source_entity_id": source.entity_id, "repeat": true})
		sim.process_pending_commands()
		var owned_task: int = sim.entity_queries().snapshot(villager_id).attributes.get(&"active_task_id")
		sim.submit_command(GopalaSimulationCommand.REQUEST_MOVE_VILLAGER, {"villager_id": villager_id, "x": 0.05, "z": 0.05})
		sim.process_pending_commands()
		check(results[-1].status == GopalaCommandResult.Status.REJECTED, "Move cannot overwrite an owned collection task")
		check(sim.entity_queries().snapshot(villager_id).attributes.get(&"active_task_id") == owned_task, "Rejected move preserves gather ownership")
		for tick in 100:
			sim.advance_ticks(1)
			var record = sim.entity_queries().snapshot(source.entity_id)
			var carried: int = sim.entity_queries().snapshot(villager_id).attributes.get(&"carried_amount", 0)
			check(int(record.attributes.get(&"available_amount", 0)) + int(record.attributes.get(&"reserved_amount", 0)) + carried + sim.resource_amount(resource) - initial == 3, "Repeated trips conserve every unit")
			if sim.gather_delivery_service()._tasks.is_empty():
				break
		check(sim.resource_amount(resource) == initial + 3, "One repeated order delivers the full %s source" % resource)
		check(sim.entity_queries().snapshot(source.entity_id).attributes.get(&"exhausted", false), "Repeated gather finishes at depletion")
		sim.advance_ticks(10)
		check(sim.resource_amount(resource) == initial + 3, "Completed repetition cannot duplicate goods")
		var cancellation = sim.entity_registry().create_entity(GopalaEntityKind.RESOURCE_SOURCE, {&"resource_id": resource, &"available_amount": 3, &"reserved_amount": 0, &"position_x": 0.02, &"position_z": 0.02, &"gatherable": true})
		sim.submit_command(type, {"villager_id": villager_id, "source_entity_id": cancellation.entity_id, "repeat": true})
		sim.process_pending_commands()
		sim.submit_command(GopalaSimulationCommand.REQUEST_STOP_GATHERING, {"villager_id": villager_id})
		sim.process_pending_commands()
		sim.advance_ticks(20)
		check(sim.entity_queries().snapshot(cancellation.entity_id).attributes.get(&"available_amount") == 3 and sim.gather_delivery_service()._tasks.is_empty(), "Cancelling repeat restores reservation and prevents later trips")

		var stopping = sim.entity_registry().create_entity(GopalaEntityKind.RESOURCE_SOURCE, {&"resource_id": resource, &"available_amount": 2, &"reserved_amount": 0, &"position_x": 0.02, &"position_z": 0.02, &"gatherable": true})
		var stop_start: int = sim.resource_amount(resource)
		sim.submit_command(type, {"villager_id": villager_id, "source_entity_id": stopping.entity_id, "repeat": true})
		sim.process_pending_commands()
		for tick in 30:
			sim.advance_ticks(1)
			if sim.entity_queries().snapshot(villager_id).attributes.get(&"carried_amount", 0) > 0:
				break
		check(sim.entity_queries().snapshot(villager_id).attributes.get(&"carried_amount", 0) == 1, "Stop fixture carries a real load")
		sim.submit_command(GopalaSimulationCommand.REQUEST_STOP_GATHERING, {"villager_id": villager_id})
		sim.process_pending_commands()
		check(sim.entity_queries().snapshot(villager_id).attributes.get(&"carried_amount", 0) == 1, "Stop preserves goods already carried")
		sim.advance_ticks(100)
		check(sim.resource_amount(resource) == stop_start + 1 and sim.gather_delivery_service()._tasks.is_empty(), "Stopping mid-haul finishes one delivery and stops repetition")
		check(sim.entity_queries().snapshot(stopping.entity_id).attributes.get(&"available_amount") == 1, "Stopped source retains its uncollected goods")
		sim.submit_command(GopalaSimulationCommand.REQUEST_STOP_GATHERING, {"villager_id": villager_id})
		sim.process_pending_commands()
		check(results[-1].status == GopalaCommandResult.Status.REJECTED, "Repeated stop has no task to mutate")

	sim.queue_free()
	await process_frame
	await process_frame
	# Exercise the valley's actual selection, physics picking and right-click path.
	var valley = load("res://scenes/landscape/kathmandu_valley.tscn").instantiate()
	root.add_child(valley)
	await physics_frame
	await physics_frame
	var live = valley.simulation
	var live_sources = live.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE).filter(func(source): return source.attributes.get(&"resource_id") == &"stone")
	check(live_sources.size() == 24, "Paused valley initializes all stone entities")
	check(valley._built_views.has(live_sources[0].entity_id), "Paused valley initializes stone visuals")
	for source in live_sources:
		var patch = valley._built_views[source.entity_id] as GopalaStonePatchView
		check(patch != null, "Stone source uses loose stone patch view")
		var patch_bounds := GopalaScaleStandard.bounds_in_parent(patch.get_node("MeshChild"))
		check(GopalaScaleStandard.within_profile(patch_bounds, "stone_patch"), "Live patch dimensions follow scale standard")
		for piece in patch.pieces:
			check(GopalaScaleStandard.within_profile(GopalaScaleStandard.bounds_in_parent(piece), "stone_piece"), "Live stone dimensions follow scale standard")
	var live_worker = live.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)[0]
	live.selection_service().select_entity(live_worker.entity_id)
	var live_source = live_sources[0]
	live.entity_registry().update_entity(live_source.entity_id, {&"available_amount": 1, &"initial_amount": 1}, {}, live.logical_tick)
	var px: float = live_source.attributes.get(&"position_x")
	var pz: float = live_source.attributes.get(&"position_z")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = valley.camera.unproject_position(Vector3(px, valley.ground_height_at(px, pz) + GopalaScaleStandard.number("stone_patch", "pick_height") * 0.5, pz))
	valley._unhandled_input(event)
	live.process_pending_commands()
	check(live.gather_delivery_service()._tasks.size() == 1, "Right-clicking selected villager's stone target creates a gather task")
	check(live.gather_delivery_service()._tasks[live_worker.entity_id].resource_id == &"stone", "Stone picking is not intercepted by a timber canopy")
	var live_start: int = live.resource_amount(&"stone")
	live.set_paused(false)
	live.process_pending_commands()
	for i in 500:
		live.advance_ticks(1)
		if live.gather_delivery_service()._tasks.is_empty():
			break
	check(live.resource_amount(&"stone") == live_start + 1, "Live input order delivers stone to storage")
	var displayed_rivers := GopalaStoneScatter.river_segments(valley.terrain)
	var all_sources = live.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE)
	var seeded_timber = all_sources.filter(func(source): return source.attributes.get(&"resource_id") == &"timber" and source.attributes.has(&"scatter_seed"))
	check(seeded_timber.size() == 12, "Valley initializes 12 randomized collectible timber stands")
	check(valley.resolved_world_seed == valley.vegetation_seed, "Scenery and resources share a resolved seed")
	for source in all_sources:
		if source.attributes.has(&"scatter_seed"):
			check(source.attributes.get(&"scatter_seed") == valley.resolved_world_seed, "Resource records retain world seed")
			check(GopalaStoneScatter.outside_displayed_water(Vector2(source.attributes.get(&"position_x"), source.attributes.get(&"position_z")), displayed_rivers), "Resources stay outside displayed river banks")
	valley._seed_forest_resource_stands()
	check(live.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE).size() == all_sources.size(), "Repeated seeding cannot duplicate resources")
	var timber_source = seeded_timber[0]
	var timber_view = valley._built_views[timber_source.entity_id] as GopalaTimberStandView
	check(timber_view != null and timber_view.trees.size() == 3, "Collectible timber has three visible trees")
	var canopy_bounds := GopalaScaleStandard.bounds_in_parent(timber_view.get_node("MeshChild"))
	check(timber_view.pick_shape.shape.size.y >= canopy_bounds.size.y, "Tree canopy participates in resource picking")
	for timber in seeded_timber:
		for stone_source in live_sources:
			var timber_position := Vector2(timber.attributes.get(&"position_x"), timber.attributes.get(&"position_z"))
			var stone_position := Vector2(stone_source.attributes.get(&"position_x"), stone_source.attributes.get(&"position_z"))
			check(timber_position.distance_to(stone_position) >= GopalaScaleStandard.metres_to_world(float(distribution.cross_resource_spacing_metres)) - 0.0001, "Collectible trees do not cover stone picking volumes")
	var tree_bounds := GopalaScaleStandard.bounds_in_parent(timber_view.trees[0])
	var tree_scale: Vector3 = timber_view.trees[0].scale
	check(tree_bounds.size.y <= GopalaScaleStandard.number("timber_stand", "tree_height") + 0.0001, "Timber tree height obeys physical standard")
	timber_view.update_amount(1, 3)
	check(timber_view.trees.filter(func(tree): return tree.visible).size() == 1, "Partial harvest removes trees")
	check(timber_view.trees[0].scale == tree_scale, "Harvest preserves remaining tree size")
	live.entity_registry().update_entity(timber_source.entity_id, {&"available_amount": 1, &"initial_amount": 1}, {}, live.logical_tick)
	px = timber_source.attributes.get(&"position_x")
	pz = timber_source.attributes.get(&"position_z")
	event.position = valley.camera.unproject_position(Vector3(px, valley.ground_height_at(px, pz) + GopalaScaleStandard.number("timber_stand", "pick_height") * 0.5, pz))
	var timber_start: int = live.resource_amount(&"timber")
	valley._unhandled_input(event)
	live.process_pending_commands()
	check(live.gather_delivery_service()._tasks.size() == 1, "Right-clicking seeded vegetation starts timber collection")
	for i in 500:
		live.advance_ticks(1)
		if live.gather_delivery_service()._tasks.is_empty():
			break
	check(live.resource_amount(&"timber") == timber_start + 1, "Seeded vegetation delivers timber to storage")
	check(live.entity_queries().snapshot(timber_source.entity_id).attributes.get(&"exhausted"), "Final timber pickup depletes stand")
	check(not timber_view.visible, "Exhausted vegetation disappears")
	await physics_frame
	check(timber_view.pick_shape.disabled, "Exhausted vegetation cannot be picked")
	valley._seed_forest_resource_stands()
	check(live.entity_queries().snapshot(timber_source.entity_id).attributes.get(&"available_amount") == 0, "Reseeding cannot refill a harvested source")

	var building = live.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING)[0]
	var start_position := Vector2(building.attributes.get(&"position_x"), building.attributes.get(&"position_z"))
	check(GopalaStoneScatter.outside_displayed_water(start_position, displayed_rivers), "Starting camp is on dry ground")
	var building_view: MeshInstance3D = valley._built_views[building.entity_id]
	var footprint = live.placement_service().get_building(&"stockpile").footprint
	check(is_equal_approx(building_view.mesh.size.x, footprint.x * live.coordinate_service()._config.world_units_per_cell), "Building view matches logical footprint width")
	for corner in [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
		var point: Vector2 = Vector2(building_view.position.x, building_view.position.z) + corner * Vector2(building_view.mesh.size.x, building_view.mesh.size.z) * 0.5
		check(GopalaStoneScatter.outside_displayed_water(point, displayed_rivers), "Starting stockpile footprint avoids water")
	var worker_start = live.entity_queries().snapshot(live_worker.entity_id)
	check(is_equal_approx(worker_start.attributes.get(&"movement_speed"), 0.014), "Walking speed is 1.4 metres per logical second")
	for source in all_sources:
		if source.attributes.has(&"scatter_seed"):
			var position := Vector2(source.attributes.get(&"position_x"), source.attributes.get(&"position_z"))
			for sample in 10:
				check(GopalaStoneScatter.outside_displayed_water(start_position.lerp(position, float(sample) / 10.0), displayed_rivers), "Starter resource trips stay on the same dry bank")

	valley.queue_free()
	await process_frame
	await process_frame
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
