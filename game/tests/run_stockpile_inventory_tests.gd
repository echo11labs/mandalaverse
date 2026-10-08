extends SceneTree
var checks := 0
var failures: Array[String] = []
const PATH := "user://saves/located-stock-test.json"
func _initialize(): run.call_deferred()
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label); push_error(label)
func stockpile(sim, point: Vector2, cells: Array[Vector2i], capacity: Dictionary) -> int:
	var id: int = sim.entity_registry().create_entity(GopalaEntityKind.BUILDING,{&"definition_id":&"stockpile",&"position_x":point.x,&"position_z":point.y,&"storage_capacity":capacity}).entity_id
	sim.occupancy_service().reserve_cells(id,cells,sim.logical_tick)
	sim.occupancy_service().commit_reservation(id,sim.logical_tick)
	return id
func role(sim, worker: int, resource: StringName):
	sim.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":worker,"role":resource})
	sim.process_pending_commands()
func restore(sim):
	var codec := GopalaSettlementSave.new()
	check(codec.write(PATH,codec.capture(sim,{})),"Write located stock snapshot")
	var loaded = codec.restore(codec.read(PATH),sim,{})
	check(loaded != null,"Restore located stock snapshot: " + codec.error)
	if loaded != null:
		root.add_child(loaded)
		loaded.set_physics_process(false)
	return loaded
func run():
	var sim := GopalaSettlementSimulation.new()
	root.add_child(sim)
	sim.set_physics_process(false)
	sim.coordinate_service().configure(GopalaSettlementGridConfig.new(Vector2.ZERO,Rect2i(-12,-12,24,24),2.0,100.0))
	sim.bootstrap_session()
	var a := stockpile(sim,Vector2.ZERO,[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)],{&"timber":0,&"stone":50,&"thatch":100})
	var b := stockpile(sim,Vector2(0.1,0),[Vector2i(5,0),Vector2i(6,0),Vector2i(5,1),Vector2i(6,1)],{&"timber":200,&"stone":2})
	sim._storage_service.enable_locations(a)
	# Authored fixture puts its initial timber in store B before play starts.
	sim._storage_service.stocks[a][&"timber"] = 0
	sim._storage_service.stocks[b] = {&"timber":100}
	sim._storage_service._cache_position(b)
	sim._route_service.enable(Rect2i(-12,-12,24,24))
	var worker: int = sim.villager_service().spawn_villager(Vector2(0.16,0.08))
	var second: int = sim.villager_service().spawn_villager(Vector2(0.18,0.08))
	var source: int = sim.entity_registry().create_entity(GopalaEntityKind.RESOURCE_SOURCE,{&"resource_id":&"stone",&"position_x":0.18,&"position_z":0.08,&"available_amount":5,&"reserved_amount":0,&"gatherable":true}).entity_id
	role(sim,worker,&"stone")
	role(sim,second,&"stone")
	sim.set_paused(false)
	sim.process_pending_commands()
	sim.advance_ticks(1)
	check(sim._storage_service.incoming_at(b,&"stone") == 2 and sim._storage_service.incoming_at(a,&"stone") == 0,"Two workers reserve distinct slots in nearest available store")
	var loaded = restore(sim)
	if loaded == null: finish(); return
	sim.free()
	sim = loaded
	for frame in 500:
		sim.advance_ticks(1)
		var total: int = sim.resource_amount(&"stone") + sim.entity_queries().snapshot(source).attributes.available_amount + sim.entity_queries().snapshot(source).attributes.reserved_amount
		for actor in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER): total += actor.attributes.get(&"carried_amount",0)
		check(total == 55,"Stored/source/carried stock conserved every tick")
		check(sim._storage_service.stored(b,&"stone") + sim._storage_service.incoming_at(b,&"stone") <= 2,"Per-store capacity cannot be overpromised")
		if sim.resource_amount(&"stone") == 52: break
	check(sim._storage_service.stored(a,&"stone") == 50 and sim._storage_service.stored(b,&"stone") == 2,"Delivery credits its destination rather than every stockpile")
	sim.advance_ticks(5)
	check(sim.entity_queries().snapshot(source).attributes.available_amount == 3,"Full stores stop new collection")
	role(sim,worker,&"NONE")
	role(sim,second,&"NONE")
	sim.request_construction(&"stockpile",Vector2i(8,4))
	sim.process_pending_commands()
	var blueprint: int = sim._entity_ids._next_id - 1
	sim.submit_command(GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER,{"villager_id":worker,"blueprint_id":blueprint})
	sim.process_pending_commands()
	check(sim.entity_queries().snapshot(blueprint).attributes.material_origins[&"timber"][b] == 4,"Builder reservation records the store holding timber")
	for frame in 500:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 1: break
	check(sim._construction_labor_service._tasks[worker].pickup_store_id == b,"Builder travels to timber store instead of camp origin")
	check(sim._storage_service.stored(b,&"timber") == 96 and sim._storage_service.reserved_at(b,&"timber") == 3,"Pickup moves reserved stock into carrier at its source store")
	loaded = restore(sim)
	if loaded == null: finish(); return
	sim.free()
	sim = loaded
	check(sim._storage_service.reserved_at(b,&"timber") == 3,"Construction origins survive carrying save/load")
	sim.submit_command(GopalaSimulationCommand.REQUEST_CANCEL_CONSTRUCTION,{"entity_id":blueprint})
	sim.process_pending_commands()
	for frame in 500:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 0: break
	check(sim.resource_amount(&"timber") == 100 and sim._storage_service.stored(b,&"timber") == 100,"Cancellation returns unpicked and carried goods to a real store exactly once")
	# Delivered construction materials remain at the site as recoverable goods.
	sim.request_construction(&"stockpile",Vector2i(8,4))
	sim.process_pending_commands()
	blueprint = sim._entity_ids._next_id - 1
	sim.submit_command(GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER,{"villager_id":worker,"blueprint_id":blueprint})
	sim.process_pending_commands()
	for frame in 500:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(blueprint).attributes.delivered_materials.get(&"timber",0) == 1: break
	sim.submit_command(GopalaSimulationCommand.REQUEST_CANCEL_CONSTRUCTION,{"entity_id":blueprint})
	sim.process_pending_commands()
	var recovered = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE).filter(func(s): return s.attributes.get(&"recovered_goods",false))
	check(sim.resource_amount(&"timber") == 99 and recovered.size() == 1 and recovered[0].attributes.available_amount == 1,"Delivered cancellation goods stay at the site rather than teleporting into storage")
	role(sim,worker,&"timber")
	for frame in 500:
		sim.advance_ticks(1)
		if sim.resource_amount(&"timber") == 100: break
	check(sim._storage_service.stored(b,&"timber") == 100,"Collector physically recovers cancelled site goods")
	role(sim,worker,&"NONE")
	# Store destruction spills its actual stock at its own location.
	sim.request_construction(&"stockpile",Vector2i(8,4))
	sim.process_pending_commands()
	blueprint = sim._entity_ids._next_id - 1
	sim.submit_command(GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER,{"villager_id":worker,"blueprint_id":blueprint})
	sim.process_pending_commands()
	check(sim._storage_service.reserved_at(b,&"timber") == 4,"Store removal fixture includes unpicked construction reservations")
	sim.entity_registry().remove_entity(b,GopalaEntityRegistry.RemovalPolicy.CLEAR_INCOMING_REFERENCES,sim.logical_tick)
	sim.advance_ticks(1)
	check(sim.resource_amount(&"timber") == 0 and sim.resource_amount(&"stone") == 50,"Removed-store stock leaves the aggregate available ledger")
	recovered = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE).filter(func(s): return s.attributes.get(&"recovered_goods",false) and s.attributes.get(&"available_amount",0) > 0)
	check(recovered.any(func(s): return s.attributes.resource_id == &"timber" and s.attributes.available_amount == 100 and is_equal_approx(s.attributes.position_x,0.1)),"Removed timber remains recoverable at the old store position")
	check(sim.entity_queries().snapshot(blueprint).attributes.reserved_materials[&"timber"] == 0,"Removed origin releases blueprint promises and spills reserved goods once")
	loaded = restore(sim)
	if loaded != null: loaded.free()
	var store_a = sim.entity_queries().snapshot(a)
	var limits: Dictionary = store_a.attributes.storage_capacity.duplicate()
	limits[&"timber"] = 200
	sim.entity_registry().update_entity(a,{&"storage_capacity":limits},{},sim.logical_tick,store_a.revision)
	check(sim.apply_authorized_transaction({&"timber":4}),"Restock surviving store")
	for frame in 1000:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(blueprint).attributes.construction_state == "COMPLETED": break
	check(sim.entity_queries().snapshot(blueprint).attributes.construction_state == "COMPLETED","Waiting builder reserves replacement stock and physically finishes construction")
	check(sim.entity_queries().snapshot(blueprint).attributes.delivered_materials[&"timber"] == 4 and sim.resource_amount(&"timber") == 0,"Replacement materials delivered exactly once")
	# A dwelling must haul every material category before labour can activate it.
	check(sim.apply_authorized_transaction({&"timber":8}),"Supply dwelling timber to a real store")
	sim.request_construction(&"dwelling",Vector2i(8,-4))
	sim.process_pending_commands()
	var dwelling: int = sim._entity_ids._next_id - 1
	sim.submit_command(GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER,{"villager_id":worker,"blueprint_id":dwelling})
	sim.process_pending_commands()
	var materials: Dictionary = sim.entity_queries().snapshot(dwelling).attributes.reserved_materials
	check(materials.get(&"timber",0) == 8 and materials.get(&"stone",0) == 2 and materials.get(&"thatch",0) == 6,"Dwelling reserves timber, stone and thatch from inventories")
	for frame in 2000:
		sim.advance_ticks(1)
		var home = sim.entity_queries().snapshot(dwelling)
		if int(home.attributes.get("work_completed",0)) > 0:
			check(home.attributes.delivered_materials.get(&"timber",0) == 8 and home.attributes.delivered_materials.get(&"stone",0) == 2 and home.attributes.delivered_materials.get(&"thatch",0) == 6,"Labour requires all physical material deliveries")
			break
	for frame in 200:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(dwelling).attributes.construction_state == "COMPLETED": break
	check(sim.entity_queries().snapshot(dwelling).attributes.construction_state == "COMPLETED","Multi-material dwelling completes through routed hauling and labour")
	check(sim._storage_service.stored(a,&"stone") == 48 and sim._storage_service.stored(a,&"thatch") == 44,"Dwelling consumes stock from recorded store exactly once")
	var codec := GopalaSettlementSave.new()
	var invalid := codec.capture(sim,{})
	invalid.store_stocks[a][&"stone"] += 1
	check(codec.restore(invalid,sim,{}) == null,"Save rejects aggregate and per-store inventory mismatch")
	sim.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	finish()
func finish():
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
