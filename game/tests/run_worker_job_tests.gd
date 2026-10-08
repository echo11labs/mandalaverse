extends SceneTree
var checks := 0
var failures: Array[String] = []
const SAVE := "user://saves/worker-job-test.json"
func _initialize(): run.call_deferred()
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label); push_error(label)
func role(sim, worker: int, resource: StringName):
	sim.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":worker,"role":resource})
	sim.process_pending_commands()
func set_capacity(sim, camp: int, amount: int):
	var record = sim.entity_queries().snapshot(camp)
	sim.entity_registry().update_entity(camp,{&"storage_capacity":{&"stone":amount,&"timber":500,&"thatch":100}},{},sim.logical_tick,record.revision)
func conservation(sim, sources: Array, initial := 4):
	var total: int = sim.resource_amount(&"stone") - 50
	for source in sources:
		var attrs = sim.entity_queries().snapshot(source).attributes
		total += attrs.available_amount + attrs.reserved_amount
	for worker in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER):
		if worker.attributes.get(&"carried_resource_id") == &"stone": total += worker.attributes.get(&"carried_amount",0)
	check(total == initial,"Stone conserved on every physical tick")
	check(sim.resource_amount(&"stone") + sim._storage_service.incoming(&"stone") <= sim._storage_service.capacity(&"stone"),"Destination promises never overcommit capacity")
func run():
	var sim := GopalaSettlementSimulation.new()
	root.add_child(sim)
	sim.set_physics_process(false)
	sim.coordinate_service().configure(GopalaSettlementGridConfig.new(Vector2.ZERO,Rect2i(-12,-12,24,24),2.0,100.0))
	sim.bootstrap_session()
	var camp: int = sim.entity_registry().create_entity(GopalaEntityKind.BUILDING,{&"definition_id":&"stockpile",&"position_x":0.0,&"position_z":0.0,&"accepts_stone":true,&"accepts_timber":true,&"storage_capacity":{&"stone":51,&"timber":500,&"thatch":100}}).entity_id
	var cells: Array[Vector2i] = [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]
	sim.occupancy_service().reserve_cells(camp,cells,0)
	sim.occupancy_service().commit_reservation(camp,0)
	sim._route_service.enable(Rect2i(-12,-12,24,24))
	var worker: int = sim.villager_service().spawn_villager(Vector2(-0.08,0.08))
	var second: int = sim.villager_service().spawn_villager(Vector2(-0.1,0.08))
	var sources := []
	for point in [Vector2(-0.1,0.08),Vector2(-0.18,0.08)]:
		sources.append(sim.entity_registry().create_entity(GopalaEntityKind.RESOURCE_SOURCE,{&"resource_id":&"stone",&"position_x":point.x,&"position_z":point.y,&"gatherable":true,&"available_amount":2,&"reserved_amount":0}).entity_id)
	role(sim,worker,&"stone")
	role(sim,second,&"stone")
	check(sim.paused,"Role assignment cannot unpause simulation")
	check(not sim.advance_ticks(1) and sim._storage_service.incoming(&"stone") == 0,"Paused roles do no work")
	sim.set_paused(false)
	sim.process_pending_commands()
	sim.advance_ticks(1)
	check(sim._storage_service.incoming(&"stone") == 1,"Two workers compete safely for one free slot")
	check(sim.entity_queries().snapshot(second).attributes.job_status == &"STORAGE_FULL","Full storage reason visible")
	var codec := GopalaSettlementSave.new()
	check(codec.write(SAVE,codec.capture(sim,{})),"Save role and space reservation")
	var restored = codec.restore(codec.read(SAVE),sim,{})
	check(restored != null,"Restore persistent jobs and incoming capacity")
	if restored == null: finish(); return
	sim.free()
	sim = restored
	root.add_child(sim)
	sim.set_physics_process(false)
	check(sim.entity_queries().snapshot(worker).attributes.work_role == &"stone" and sim._storage_service.incoming(&"stone") == 1,"Job and destination promise survive load")
	for frame in 300:
		sim.advance_ticks(1)
		conservation(sim,sources)
		if sim.resource_amount(&"stone") == 51: break
	check(sim.resource_amount(&"stone") == 51,"Worker delivers only into its promised slot")
	sim.advance_ticks(5)
	check(sim._storage_service.incoming(&"stone") == 0,"Full stores stop new pickups")
	set_capacity(sim,camp,53)
	for frame in 500:
		sim.advance_ticks(1)
		conservation(sim,sources)
		if sim.resource_amount(&"stone") == 53: break
	check(sim.resource_amount(&"stone") == 53,"Roles resume without new orders when space opens")
	check(sim.entity_queries().snapshot(sources[0]).attributes.available_amount == 0,"First source exhausted")
	check(sim.entity_queries().snapshot(sources[1]).attributes.available_amount == 1,"Role automatically switches to next source")
	check(sim.apply_authorized_transaction({&"stone":-1}),"Consumption opens a storage slot")
	for frame in 500:
		sim.advance_ticks(1)
		if sim.resource_amount(&"stone") == 53: break
	check(sim.resource_amount(&"stone") == 53 and sim.entity_queries().snapshot(sources[1]).attributes.available_amount == 0,"Last unit delivered once after consumption")
	set_capacity(sim,camp,55)
	sim.advance_ticks(2)
	check(sim.entity_queries().snapshot(worker).attributes.job_status == &"NO_SOURCE","Depleted resource gives clear idle reason")
	# A new stockpile contributes only after physical construction completes.
	role(sim,worker,&"NONE")
	sim.request_construction(&"stockpile",Vector2i(4,4))
	sim.process_pending_commands()
	var blueprint: int = sim._entity_ids._next_id - 1
	check(sim._storage_service.capacity(&"stone") == 55,"Blueprint creates no storage capacity")
	sim.submit_command(GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER,{"villager_id":worker,"blueprint_id":blueprint})
	sim.process_pending_commands()
	for frame in 2000:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(blueprint).attributes.construction_state == "COMPLETED": break
	check(sim.entity_queries().snapshot(blueprint).attributes.construction_state == "COMPLETED" and sim._storage_service.capacity(&"stone") == 255,"Completed stockpile adds capacity")
	check(sim._storage_service.destinations(&"stone").any(func(b): return b.entity_id == blueprint),"Completed stockpile becomes a legal delivery destination")
	# Remove the old store during a haul; carriers find the new store safely.
	var source: int = sim.entity_registry().create_entity(GopalaEntityKind.RESOURCE_SOURCE,{&"resource_id":&"stone",&"position_x":-0.2,&"position_z":0.08,&"gatherable":true,&"available_amount":1,&"reserved_amount":0}).entity_id
	role(sim,second,&"NONE")
	role(sim,worker,&"stone")
	for frame in 500:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 1: break
	check(sim.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 1,"Worker picks up for removed-store recovery")
	role(sim,worker,&"NONE")
	sim.entity_registry().remove_entity(camp,GopalaEntityRegistry.RemovalPolicy.CLEAR_INCOMING_REFERENCES,sim.logical_tick)
	for frame in 1000:
		sim.advance_ticks(1)
		if sim.resource_amount(&"stone") == 54: break
	check(sim.resource_amount(&"stone") == 54 and sim.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 0,"Carrier reroutes and credits new completed store once")
	check(sim.entity_queries().snapshot(worker).attributes.work_role == &"NONE","Stop role finishes load without restarting work")
	check(codec.write(SAVE,codec.capture(sim,{})),"Save completed store with roles")
	restored = codec.restore(codec.read(SAVE),sim,{})
	check(restored != null,"Completed store acceptance survives load")
	if restored != null: restored.free()
	# Existing carried goods wait safely if a capacity changes or every store disappears.
	sim.entity_registry().update_entity(source,{&"available_amount":2,&"exhausted":false},{},sim.logical_tick)
	set_capacity(sim,blueprint,56)
	role(sim,worker,&"stone")
	for frame in 500:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 1: break
	set_capacity(sim,blueprint,54)
	for frame in 500:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(worker).attributes.get(&"task_state") == &"WAITING_FOR_STORAGE": break
	check(sim.entity_queries().snapshot(worker).attributes.get(&"task_state") == &"WAITING_FOR_STORAGE" and sim.resource_amount(&"stone") == 54,"Full destination keeps goods carried without remote credit")
	check(codec.write(SAVE,codec.capture(sim,{})),"Save full-store carrier")
	restored = codec.restore(codec.read(SAVE),sim,{})
	check(restored != null,"Full-store carrier restores")
	if restored == null: finish(); return
	sim.free()
	sim = restored
	root.add_child(sim)
	sim.set_physics_process(false)
	role(sim,worker,&"NONE")
	sim.entity_registry().remove_entity(blueprint,GopalaEntityRegistry.RemovalPolicy.CLEAR_INCOMING_REFERENCES,sim.logical_tick)
	sim.advance_ticks(1)
	check(sim.entity_queries().snapshot(worker).attributes.task_state == &"NO_STORAGE" and sim.entity_queries().snapshot(worker).attributes.carried_amount == 1,"Destroyed last store cannot discard carried goods")
	check(codec.write(SAVE,codec.capture(sim,{})),"Save carrier with no remaining store")
	restored = codec.restore(codec.read(SAVE),sim,{})
	check(restored != null,"Missing-store recovery state restores")
	if restored == null: finish(); return
	sim.free()
	sim = restored
	root.add_child(sim)
	sim.set_physics_process(false)
	sim.entity_registry().create_entity(GopalaEntityKind.BUILDING,{&"definition_id":&"stockpile",&"storage_capacity":{&"stone":200},&"position_x":0.08,&"position_z":-0.08})
	for frame in 500:
		sim.advance_ticks(1)
		if sim.resource_amount(&"stone") == 55: break
	check(sim.resource_amount(&"stone") == 55 and sim.entity_queries().snapshot(worker).attributes.carried_amount == 0,"New store resumes retained delivery exactly once")
	sim.queue_free()
	await process_frame
	var valley = load("res://scenes/landscape/kathmandu_valley.tscn").instantiate()
	root.add_child(valley)
	valley.simulation.set_physics_process(false)
	var selected_worker: int = valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)[0].entity_id
	valley.simulation.selection_service().select_entity(selected_worker)
	valley._inspect_selected_entity(selected_worker)
	check(valley.hud._worker_jobs.visible and valley.hud._worker_jobs.get_child_count() == 9,"Worker inspection offers seven collection roles, tending and stop")
	valley.hud._worker_jobs.get_child(1).pressed.emit()
	valley.simulation.process_pending_commands()
	check(valley.simulation.entity_queries().snapshot(selected_worker).attributes.work_role == &"stone","Visible Stone control assigns persistent role")
	valley.hud._worker_jobs.get_child(8).pressed.emit()
	valley.simulation.process_pending_commands()
	check(valley.simulation.entity_queries().snapshot(selected_worker).attributes.work_role == &"NONE","Visible Stop job control stops role")
	valley.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	finish()
func finish():
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
