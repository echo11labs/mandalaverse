extends SceneTree
var checks := 0
var failures: Array[String] = []
const SAVE := "user://saves/survival-test.json"
func _initialize(): run.call_deferred()
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label); push_error(label)
func patch(sim, id: int, changes: Dictionary): sim._survival_service.update(id,changes,sim.logical_tick)
func run():
	var sim := GopalaSettlementSimulation.new()
	root.add_child(sim)
	sim.set_physics_process(false)
	sim.coordinate_service().configure(GopalaSettlementGridConfig.new(Vector2.ZERO,Rect2i(-16,-16,32,32),2.0,100.0))
	sim.bootstrap_session()
	var store: int = sim.entity_registry().create_entity(GopalaEntityKind.BUILDING,{&"definition_id":&"stockpile",&"position_x":0.0,&"position_z":0.0}).entity_id
	sim.occupancy_service().reserve_cells(store,[Vector2i.ZERO],0)
	sim.occupancy_service().commit_reservation(store,0)
	sim._storage_service.enable_locations(store)
	sim._route_service.enable(Rect2i(-16,-16,32,32))
	var worker: int = sim.villager_service().spawn_villager(Vector2(0.12,0.12))
	sim.entity_registry().create_entity(GopalaEntityKind.SETTLEMENT,{&"scenario_id":&"gopala_mvp_v1",&"survival_enabled":true})
	sim.apply_authorized_transaction({&"wild_food":3,&"water":3})
	sim._survival_service.tick(0)
	patch(sim,worker,{&"meal_due_tick":0,&"drink_due_tick":1000})
	check(not sim.advance_ticks(5) and sim.resource_amount(&"wild_food") == 3,"Pause freezes food consumption")
	sim.set_paused(false)
	sim.process_pending_commands()
	sim.advance_ticks(1)
	check(sim.entity_queries().snapshot(worker).attributes.task_kind == &"NEED" and sim.resource_amount(&"wild_food") == 3,"Hungry settler walks to storage before eating")
	check(not sim.villager_service().assign_move_task(worker,Vector2(0.2,0.2)),"Manual move cannot redirect a diner then consume remotely")
	for frame in 100:
		sim.advance_ticks(1)
		if sim.resource_amount(&"wild_food") == 2: break
	check(sim.resource_amount(&"wild_food") == 2 and sim._storage_service.stored(store,&"wild_food") == 2,"Meal consumes one unit from its actual store")
	check(sim.entity_queries().snapshot(worker).attributes.consumed_goods.get(&"wild_food",0) == 1,"Consumption journal records the food sink")
	patch(sim,worker,{&"drink_due_tick":0,&"meal_due_tick":1000})
	sim.advance_ticks(1)
	var codec := GopalaSettlementSave.new()
	check(codec.write(SAVE,codec.capture(sim,{})),"Write needs journey save")
	var loaded = codec.restore(codec.read(SAVE),sim,{})
	check(loaded != null,"Restore needs journey: "+codec.error)
	if loaded == null: finish(); return
	sim.free()
	sim = loaded
	root.add_child(sim)
	sim.set_physics_process(false)
	for frame in 100:
		sim.advance_ticks(1)
		if sim.resource_amount(&"water") == 2: break
	check(sim.resource_amount(&"water") == 2 and sim.entity_queries().snapshot(worker).attributes.drink_due_tick > sim.logical_tick,"Loaded physical journey consumes water once")
	# Housing only uses completed dwellings and never overfills them.
	var home: int = sim.entity_registry().create_entity(GopalaEntityKind.BUILDING,{&"definition_id":&"dwelling",&"construction_state":&"BLUEPRINT",&"position_x":0.2,&"position_z":0.0}).entity_id
	sim.advance_ticks(1)
	check(sim.entity_queries().snapshot(worker).attributes.home_id == 0,"Blueprint provides no housing")
	patch(sim,home,{&"construction_state":&"COMPLETED"})
	for i in 4: sim.villager_service().spawn_villager(Vector2(0.04+float(i)*0.02,-0.1))
	sim.advance_ticks(1)
	var housed := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER).filter(func(w): return w.attributes.get(&"home_id",0) == home)
	check(housed.size() == 4,"Completed dwelling admits four settlers exactly")
	sim.entity_registry().remove_entity(home,GopalaEntityRegistry.RemovalPolicy.CLEAR_INCOMING_REFERENCES,sim.logical_tick)
	sim.advance_ticks(1)
	check(sim.entity_queries().snapshot(worker).attributes.home_id == 0,"Removed dwelling releases its households")
	# A real built water point produces a bounded source beside its plot.
	sim.request_construction(&"water_point",Vector2i(4,0))
	sim.process_pending_commands()
	var well: int = sim._entity_ids._next_id-1
	patch(sim,well,{&"construction_state":&"COMPLETED",&"work_completed":100,&"delivered_materials":{&"timber":3,&"stone":3}})
	sim.advance_ticks(1)
	var source: int = sim.entity_queries().snapshot(well).attributes.get(&"water_source_id",0)
	check(source > 0 and sim.entity_queries().snapshot(source).attributes.available_amount == 12,"Completed water point creates twelve collectible water units")
	check(sim._route_service.is_open(sim.coordinate_service().world_to_settlement_cell(Vector2(sim.entity_queries().snapshot(source).attributes.position_x,sim.entity_queries().snapshot(source).attributes.position_z))),"Water collection is outside the solid building footprint")
	patch(sim,source,{&"available_amount":0,&"exhausted":true})
	sim.advance_ticks(60)
	check(sim.entity_queries().snapshot(source).attributes.available_amount == 12 and sim.entity_queries().snapshot(source).attributes.generated_amount == 24,"Water refills by logical time and journals its external supply")
	# Shortage reduces health; the last water carrier can gather to recover.
	var water: int = sim.resource_amount(&"water")
	sim.apply_authorized_transaction({&"water":-water})
	patch(sim,worker,{&"meal_due_tick":10000,&"drink_due_tick":0,&"health":10})
	sim.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":worker,"role":&"water"})
	sim.process_pending_commands()
	for frame in 120:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(worker).attributes.consumed_goods.get(&"water",0) == 2: break
	check(sim.entity_queries().snapshot(worker).attributes.consumed_goods.get(&"water",0) == 2,"Thirsty final carrier gathers, physically delivers and drinks its own water")
	check(sim.entity_queries().snapshot(worker).attributes.health > 0,"Fallback collection avoids a final-carrier supply softlock")
	sim.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":worker,"role":&"NONE"})
	sim.process_pending_commands()
	var food: int = sim.resource_amount(&"wild_food")
	if food > 0: sim.apply_authorized_transaction({&"wild_food":-food})
	patch(sim,worker,{&"meal_due_tick":0,&"drink_due_tick":10000,&"health":100})
	sim.advance_ticks(240)
	check(sim.entity_queries().snapshot(worker).attributes.health < 100 and sim.entity_queries().snapshot(worker).attributes.need_state == &"NO_FOOD","Prolonged food shortage visibly reduces health and interrupts work")
	# Interrupt a builder after pickup; reservations and the load survive its break.
	patch(sim,worker,{&"meal_due_tick":10000,&"drink_due_tick":10000,&"health":100,&"need_state":&"SATISFIED"})
	sim.request_construction(&"stockpile",Vector2i(8,8))
	sim.process_pending_commands()
	var blueprint: int = sim._entity_ids._next_id-1
	sim.submit_command(GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER,{"villager_id":worker,"blueprint_id":blueprint})
	sim.process_pending_commands()
	for frame in 100:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 1: break
	check(sim.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 1,"Builder interruption starts with a real carried load")
	patch(sim,worker,{&"meal_due_tick":0})
	for frame in 100:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(worker).attributes.need_state == &"NO_FOOD": break
	check(sim.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 0 and sim.resource_amount(&"timber")+sim.entity_queries().snapshot(blueprint).attributes.reserved_materials.get(&"timber",0) == 100,"Builder returns carried goods and retains site reservations before seeking food")
	check(sim.apply_authorized_transaction({&"wild_food":10}),"Restock food for builder recovery")
	for frame in 1000:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(blueprint).attributes.construction_state == "COMPLETED": break
	check(sim.entity_queries().snapshot(blueprint).attributes.construction_state == "COMPLETED","Builder resumes and completes after needs are satisfied")
	var invalid := codec.capture(sim,{})
	for row in invalid.records:
		if row[0] == worker: row[6][&"health"] = 101
	check(codec.restore(invalid,sim,{}) == null,"Invalid need/health state rejected before replacing authorities")
	sim.free()
	var valley = load("res://scenes/mvp.tscn").instantiate()
	root.add_child(valley)
	valley.simulation.set_physics_process(false)
	check(valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER).size() == 8,"Actual MVP starts with eight settlers")
	check(valley.simulation.resource_amount(&"wild_food") == 48 and valley.simulation.resource_amount(&"water") == 64,"MVP starts with a protected food and water reserve")
	check(valley.simulation._survival_service.enabled(),"MVP enables survival while landscape fixtures retain their scope")
	valley.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
	finish()
func finish():
	print("GOPALA_TEST_REPORT="+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
