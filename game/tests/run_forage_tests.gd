extends SceneTree

var checks := 0
var failures: Array[String] = []
const SAVE := "user://saves/forage-test.json"
func _initialize(): run.call_deferred()
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label); push_error(label)
func role(sim, worker: int, resource: StringName):
	sim.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":worker,"role":resource})
	sim.process_pending_commands()
func conservation(sim, resource: StringName, expected: int) -> bool:
	var amount: int = sim.resource_amount(resource)
	for source in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE):
		if source.attributes.resource_id == resource:
			amount += source.attributes.available_amount + source.attributes.reserved_amount
	for worker in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER):
		if worker.attributes.get(&"carried_resource_id") == resource: amount += worker.attributes.get(&"carried_amount",0)
	return amount == expected
func run():
	for resource in [&"thatch",&"wild_food",&"fodder"]:
		var sim := GopalaSettlementSimulation.new()
		root.add_child(sim)
		sim.set_physics_process(false)
		sim.coordinate_service().configure(GopalaSettlementGridConfig.new(Vector2.ZERO,Rect2i(-12,-12,24,24),2.0,100.0))
		sim.bootstrap_session()
		var initial: int = sim.resource_amount(resource)
		var capacity := {&"timber":200,&"stone":200,&"thatch":200,&"wild_food":200,&"fodder":200}
		capacity[resource] = initial + 2
		var store: int = sim.entity_registry().create_entity(GopalaEntityKind.BUILDING,{&"definition_id":&"stockpile",&"position_x":0.0,&"position_z":0.0,&"storage_capacity":capacity}).entity_id
		sim.occupancy_service().reserve_cells(store,[Vector2i.ZERO],sim.logical_tick)
		sim.occupancy_service().commit_reservation(store,sim.logical_tick)
		sim._storage_service.enable_locations(store)
		sim._route_service.enable(Rect2i(-12,-12,24,24))
		var worker: int = sim.villager_service().spawn_villager(Vector2(0.04,0.04))
		var source: int = sim.entity_registry().create_entity(GopalaEntityKind.RESOURCE_SOURCE,{&"resource_id":resource,&"available_amount":3,&"initial_amount":3,&"reserved_amount":0,&"position_x":0.08,&"position_z":0.08,&"gatherable":true}).entity_id
		role(sim,worker,resource)
		check(not sim.advance_ticks(3) and sim.gather_delivery_service()._tasks.is_empty(),"Pause freezes forage dispatch")
		sim.set_paused(false)
		sim.process_pending_commands()
		for frame in 100:
			sim.advance_ticks(1)
			check(conservation(sim,resource,initial+3),"Forage source, stored and carried quantities conserved")
			if sim.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 1: break
		check(sim.entity_queries().snapshot(worker).attributes.get(&"carried_resource_id") == resource,"Worker carries the correct forage category")
		var codec := GopalaSettlementSave.new()
		check(codec.write(SAVE,codec.capture(sim,{})),"Write carried forage save")
		var loaded = codec.restore(codec.read(SAVE),sim,{})
		check(loaded != null,"Restore forage role and task: " + codec.error)
		if loaded == null: sim.free(); continue
		sim.free()
		sim = loaded
		root.add_child(sim)
		sim.set_physics_process(false)
		check(sim.entity_queries().snapshot(worker).attributes.work_role == resource,"Forage role survives loading")
		for frame in 200:
			sim.advance_ticks(1)
			check(conservation(sim,resource,initial+3),"Loaded forage hauling conserves goods")
			if sim.resource_amount(resource) == initial+2: break
		sim.advance_ticks(3)
		check(sim._storage_service.stored(store,resource) == initial+2 and sim.entity_queries().snapshot(source).attributes.available_amount == 1,"Correct store fills to its own forage capacity")
		check(sim.entity_queries().snapshot(worker).attributes.job_status == &"STORAGE_FULL","Full forage store pauses persistent role")
		check(sim.apply_authorized_transaction({resource:-1}),"Consumption opens a forage slot")
		for frame in 100:
			sim.advance_ticks(1)
			if sim.entity_queries().snapshot(source).attributes.get(&"exhausted",false) and sim.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 0: break
		check(sim.resource_amount(resource) == initial+2 and sim.entity_queries().snapshot(source).attributes.available_amount == 0,"Collection restarts after consumption and depletes source")
		role(sim,worker,&"NONE")
		# A repeated manual order uses the same category on every subsequent trip.
		var record = sim.entity_queries().snapshot(store)
		capacity[resource] = initial+10
		sim.entity_registry().update_entity(store,{&"storage_capacity":capacity},{},sim.logical_tick,record.revision)
		var manual: int = sim.entity_registry().create_entity(GopalaEntityKind.RESOURCE_SOURCE,{&"resource_id":resource,&"available_amount":2,&"reserved_amount":0,&"position_x":0.04,&"position_z":0.06,&"gatherable":true}).entity_id
		sim.submit_command(GopalaSimulationCommand.REQUEST_GATHER_RESOURCE,{"resource_id":resource,"villager_id":worker,"source_entity_id":manual,"repeat":true})
		sim.process_pending_commands()
		for frame in 200:
			sim.advance_ticks(1)
			if sim.gather_delivery_service()._tasks.is_empty(): break
		check(sim.resource_amount(resource) == initial+4,"Repeated forage order delivers both units without switching to timber")
		sim.advance_ticks(5)
		check(sim.resource_amount(resource) == initial+4,"Completed forage cannot credit twice")
		var command := GopalaSimulationCommand._from_queue(0,GopalaSimulationCommand.REQUEST_GATHER_RESOURCE,sim.logical_tick,{"resource_id":&"grain","villager_id":worker,"source_entity_id":manual},&"test")
		check(sim.gather_delivery_service().handle_request_gather_timber(command,sim.logical_tick).reason_code == &"INVALID_RESOURCE","Unsupported grain collection rejected")
		sim.free()
	# The actual landscape seeds distinct, gatherable patches and exposes role buttons.
	var valley = load("res://scenes/landscape/kathmandu_valley.tscn").instantiate()
	root.add_child(valley)
	valley.simulation.set_physics_process(false)
	await physics_frame
	await physics_frame
	var sources = valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/resource_distribution.json"))
	for resource in [&"thatch",&"wild_food",&"fodder"]:
		var matches = sources.filter(func(s): return s.attributes.resource_id == resource)
		check(matches.size() == int(config[str(resource)].count),"Live landscape seeds configured forage count: " + str(resource))
		for source in matches:
			check(valley._built_views[source.entity_id] is GopalaForagePatchView,"Forage uses plant view instead of tree or rock")
			var bounds := GopalaScaleStandard.bounds_in_parent(valley._built_views[source.entity_id].get_node("MeshChild"))
			check(GopalaScaleStandard.within_profile(bounds,"forage_patch"),"Live forage measured size stays within standard: %s %s" % [resource,bounds.size*100])
			for plant in valley._built_views[source.entity_id].plants:
				check(GopalaScaleStandard.bounds_in_parent(plant).size.y < GopalaScaleStandard.number("villager","height"),"Individual plant remains below human height")
			check(valley.simulation._route_service._walkable.call(Vector2(source.attributes.position_x,source.attributes.position_z)),"Forage is on traversable dry terrain")
		var worker: int = valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)[0].entity_id
		valley.simulation.selection_service().select_entity(worker)
		if matches.is_empty(): continue
		var target = matches[0]
		var x: float = target.attributes.position_x
		var z: float = target.attributes.position_z
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = true
		event.position = valley.camera.unproject_position(Vector3(x,valley.ground_height_at(x,z)+GopalaScaleStandard.number("forage_patch","pick_height")*0.5,z))
		valley._unhandled_input(event)
		valley.simulation.process_pending_commands()
		check(valley.simulation.gather_delivery_service()._tasks.has(worker) and valley.simulation.gather_delivery_service()._tasks[worker].resource_id == resource,"Right click picks the correct forage category: " + str(resource))
		valley.simulation.submit_command(GopalaSimulationCommand.REQUEST_STOP_GATHERING,{"villager_id":worker})
		valley.simulation.process_pending_commands()
		valley.simulation.selection_service().select_entity(worker)
		valley._inspect_selected_entity(worker)
		var index: int = 2 if resource == &"thatch" else (3 if resource == &"wild_food" else 4)
		valley.hud._worker_jobs.get_child(index).pressed.emit()
		valley.simulation.process_pending_commands()
		check(valley.simulation.entity_queries().snapshot(worker).attributes.work_role == resource,"Actual HUD assigns forage role")
	var before: int = sources.size()
	valley._seed_forest_resource_stands()
	check(valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE).size() == before,"Reseeding cannot duplicate forage")
	valley.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
	print("GOPALA_TEST_REPORT="+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
