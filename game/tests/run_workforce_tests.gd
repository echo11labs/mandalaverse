extends SceneTree
var checks := 0
var failures: Array[String] = []
var worker_id := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func fixture() -> GopalaSettlementSimulation:
	var sim := GopalaSettlementSimulation.new()
	root.add_child(sim)
	sim.set_physics_process(false)
	sim.coordinate_service().configure(GopalaSettlementGridConfig.new(Vector2.ZERO,Rect2i(-12,-12,24,24),2.0,100.0))
	sim.bootstrap_session()
	sim.entity_registry().create_entity(GopalaEntityKind.SETTLEMENT,{"display_name":"Workforce fixture"})
	var camp := sim.entity_registry().create_entity(GopalaEntityKind.BUILDING,{&"definition_id":&"stockpile",&"construction_state":&"COMPLETED",&"position_x":0.0,&"position_z":0.0,&"storage_capacity":{&"timber":300,&"stone":300,&"thatch":300}}).entity_id
	sim.occupancy_service().reserve_cells(camp,[Vector2i.ZERO],0)
	sim.occupancy_service().commit_reservation(camp,0)
	sim._storage_service.enable_locations(camp)
	sim._route_service.enable(Rect2i(-12,-12,24,24))
	worker_id = sim.villager_service().spawn_villager(Vector2(-0.08,0.08))
	for resource in [&"stone",&"timber"]:
		sim.entity_registry().create_entity(GopalaEntityKind.RESOURCE_SOURCE,{"resource_id":resource,"position_x":-0.12,"position_z":0.08,"gatherable":true,"available_amount":20,"reserved_amount":0})
	return sim
func configure(sim: GopalaSettlementSimulation, jobs: Dictionary, enabled := true) -> void:
	var config := GopalaWorkforceService.default_policy()
	config.enabled = enabled
	for role in config.jobs: config.jobs[role] = {"target":0,"priority":0}
	for role in jobs: config.jobs[role] = jobs[role]
	sim.submit_command(GopalaSimulationCommand.SET_WORKFORCE_POLICY,{"policy":config})
	sim.process_pending_commands()
func total(sim: GopalaSettlementSimulation, resource: StringName) -> int:
	var amount := sim.resource_amount(resource)
	for source in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE):
		if source.attributes.get("resource_id") == resource: amount += int(source.attributes.available_amount)+int(source.attributes.reserved_amount)
	for worker in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER):
		if worker.attributes.get("carried_resource_id") == resource: amount += int(worker.attributes.get("carried_amount",0))
	return amount
func run() -> void:
	var sim := fixture()
	configure(sim,{"stone":{"target":1,"priority":3},"timber":{"target":1,"priority":1}})
	sim.advance_ticks(2)
	check(sim.entity_queries().snapshot(worker_id).attributes.get("work_role",&"NONE") == &"NONE","Paused policy changes cannot start work")
	sim.set_paused(false); sim.process_pending_commands(); sim.advance_ticks(1)
	check(sim.entity_queries().snapshot(worker_id).attributes.get("work_role") == &"stone","Highest-priority job receives scarce worker")
	check(sim.entity_queries().snapshot(worker_id).attributes.get("workforce_managed",false),"Automatic ownership recorded")
	var stone_total := total(sim,&"stone")
	for tick in 600:
		sim.advance_ticks(1)
		check(total(sim,&"stone") == stone_total,"Every physical tick conserves gathered stone")
		if int(sim.entity_queries().snapshot(worker_id).attributes.get("carried_amount",0)) > 0: break
	var carrier := sim.entity_queries().snapshot(worker_id)
	check(int(carrier.attributes.get("carried_amount",0)) > 0,"Worker physically picks up cargo")
	configure(sim,{"timber":{"target":1,"priority":3}})
	sim.advance_ticks(1)
	check(sim.entity_queries().snapshot(worker_id).attributes.get("work_role") == &"stone","Quota change cannot steal in-flight cargo")
	check(sim.entity_queries().snapshot(worker_id).attributes.get("workforce_pending_role") == "timber","Next assignment is visible while delivery finishes")
	var codec := GopalaSettlementSave.new()
	check(codec.write("user://tests/workforce.json",codec.capture(sim,{})),"Workforce JSON save writes during cargo")
	var restored := codec.restore(codec.read("user://tests/workforce.json"),sim,{})
	check(restored != null,"Workforce JSON restores during cargo: " + codec.error)
	if restored != null:
		root.add_child(restored);restored.set_physics_process(false)
		check(restored._workforce_service.policy() == sim._workforce_service.policy(),"Policy survives save/load exactly")
		check(restored.entity_queries().snapshot(worker_id).attributes.get("workforce_pending_role") == "timber","Pending assignment survives save/load")
		sim.free(); sim = restored
	for tick in 1000:
		sim.advance_ticks(1)
		check(total(sim,&"stone") == stone_total,"Reassignment never loses or duplicates the delivered load")
		if sim.entity_queries().snapshot(worker_id).attributes.get("work_role") == &"timber": break
	check(sim.entity_queries().snapshot(worker_id).attributes.get("work_role") == &"timber","Worker changes job at safe delivery boundary")
	sim.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":worker_id,"role":&"stone"});sim.process_pending_commands()
	check(not sim.entity_queries().snapshot(worker_id).attributes.get("workforce_managed",false),"Manual command removes automatic ownership")
	sim.advance_ticks(5)
	check(sim.entity_queries().snapshot(worker_id).attributes.get("work_role") == &"stone","Automation respects explicit manual job")
	sim.submit_command(GopalaSimulationCommand.SET_WORKER_AUTOMATION,{"villager_id":worker_id,"enabled":true});sim.process_pending_commands()
	check(sim.entity_queries().snapshot(worker_id).attributes.workforce_managed,"Worker can return to automatic management")
	var bad := codec.capture(sim,{})
	for row in bad.records:
		if row[1] == GopalaEntityKind.SETTLEMENT: row[6].workforce_policy.jobs.timber.priority = 99
	check(codec.restore(bad,sim,{}) == null,"Malformed saved priorities rejected without replacing current settlement")
	check(sim._workforce_service.reason("milk") == "NO_SOURCE","Missing resource source is explained")
	check(sim._workforce_service.reason("herder") == "NO_SUPPORTED_HERD","Unsupported herd is explained")
	sim.free()
	sim = fixture()
	configure(sim,{"construction":{"target":1,"priority":3}})
	var cells: Array[Vector2i] = [Vector2i(3,2),Vector2i(4,2)]
	sim.request_road(cells);sim.process_pending_commands()
	sim.set_paused(false);sim.process_pending_commands()
	var path: int = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.ROAD)[0].entity_id
	sim.advance_ticks(1)
	sim._construction_labor_service.cancel_task(worker_id,sim.logical_tick,&"NEEDS_BREAK")
	check(sim.entity_queries().snapshot(path).attributes.auto_build,"Needs break preserves road automatic construction intent")

	for tick in 1200:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(path).attributes.construction_state == "COMPLETED": break
	check(sim.entity_queries().snapshot(path).attributes.construction_state == "COMPLETED","Construction quota dispatches real path builder")
	check(sim._workforce_service.reason("construction") == "NO_SITE","Finished construction leaves an explained empty queue")
	var timber_before := sim.resource_amount(&"timber")
	var stone_before := sim.resource_amount(&"stone")
	var thatch_before := sim.resource_amount(&"thatch")
	sim.request_construction(&"dwelling",Vector2i(5,-5));sim.process_pending_commands()
	var home: int = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING).filter(func(b):return b.attributes.get("definition_id") == &"dwelling")[0].entity_id
	for tick in 2400:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(home).attributes.construction_state == "COMPLETED": break
	check(sim.entity_queries().snapshot(home).attributes.construction_state == "COMPLETED","Same construction quota builds a house through material hauling and labor")
	check(sim.resource_amount(&"timber") == timber_before-8 and sim.resource_amount(&"stone") == stone_before-2 and sim.resource_amount(&"thatch") == thatch_before-6,"Automatically built house consumes exactly its authored costs")
	configure(sim,{},false)
	var more: Array[Vector2i] = [Vector2i(5,2)]
	sim.request_road(more);sim.process_pending_commands();sim.advance_ticks(50)
	var pending: Array = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.ROAD).filter(func(r):return r.entity_id != path)
	check(pending[0].attributes.work_completed == 0,"Disabling configured workforce also prevents legacy road dispatcher from bypassing policy")
	var original_policy := sim._workforce_service.policy()
	var invalid := original_policy.duplicate(true)
	invalid.jobs.stone.target = -1
	sim.submit_command(GopalaSimulationCommand.SET_WORKFORCE_POLICY,{"policy":invalid});sim.process_pending_commands()
	check(sim._workforce_service.policy() == original_policy,"Invalid quota rejected atomically")
	sim.submit_command(GopalaSimulationCommand.SET_WORKER_AUTOMATION,{"villager_id":{},"enabled":true});sim.process_pending_commands()
	check(sim._workforce_service.policy() == original_policy,"Invalid worker payload rejected without mutation or conversion errors")

	sim.free()
	sim = fixture()
	var owner := sim._workforce_service.settlement()
	sim.entity_registry().update_entity(owner.entity_id,{"survival_enabled":true},{},0)
	var camp := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING)[0]
	sim.entity_registry().update_entity(camp.entity_id,{"storage_capacity":{&"timber":300,&"stone":300,&"thatch":300,&"wild_food":100}},{},0)
	sim.entity_registry().create_entity(GopalaEntityKind.RESOURCE_SOURCE,{"resource_id":&"wild_food","position_x":-0.12,"position_z":0.08,"gatherable":true,"available_amount":20,"reserved_amount":0})
	sim.entity_registry().update_entity(worker_id,{"meal_due_tick":0,"drink_due_tick":10000,"health":100,"need_state":&"SATISFIED"},{},0)
	sim.request_road(cells);sim.process_pending_commands()
	configure(sim,{"construction":{"target":1,"priority":3},"wild_food":{"target":1,"priority":1}})
	sim.set_paused(false);sim.process_pending_commands();sim.advance_ticks(1)
	check(sim.entity_queries().snapshot(worker_id).attributes.get("work_role") == &"wild_food","Hungry settlers can dispatch food recovery before high-priority construction")
	for tick in 400:
		sim.advance_ticks(1)
		if int(sim.entity_queries().snapshot(worker_id).attributes.get("consumed_goods",{}).get(&"wild_food",0)) > 0: break
	check(int(sim.entity_queries().snapshot(worker_id).attributes.get("consumed_goods",{}).get(&"wild_food",0)) > 0,"Automatic food recovery physically feeds a hungry worker")
	sim.free()
	sim = fixture()
	sim.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":worker_id,"role":&"stone"});sim.process_pending_commands()
	var second := sim.villager_service().spawn_villager(Vector2(-0.08,0.1))
	configure(sim,{"stone":{"target":1,"priority":3},"timber":{"target":1,"priority":2}})
	sim.set_paused(false);sim.process_pending_commands();sim.advance_ticks(1)
	check(sim.entity_queries().snapshot(worker_id).attributes.get("work_role") == &"stone","Manual staff counts toward target without taking ownership")
	check(sim.entity_queries().snapshot(second).attributes.get("work_role") == &"timber","Quota allocation avoids double-staffing an already filled manual role")
	var camp_record := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING)[0]
	sim.entity_registry().update_entity(camp_record.entity_id,{"storage_capacity":{&"stone":50,&"timber":300,&"thatch":300}},{},sim.logical_tick)
	check(sim._workforce_service.reason("stone") == "STORAGE_FULL","Existing source with a full store has a distinct blocker")
	check(sim.capabilities().get("workforce_management",false),"Simulation advertises the new supported workforce contract")
	sim.free()
	sim = fixture()
	sim.request_construction(&"dwelling",Vector2i(5,-5));sim.process_pending_commands()
	var starved_home: int = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING).filter(func(b):return b.attributes.get("definition_id") == &"dwelling")[0].entity_id
	sim._storage_service.apply_transaction({&"timber":-100})
	configure(sim,{"construction":{"target":1,"priority":3}})
	sim.set_paused(false);sim.process_pending_commands()
	for tick in 4000:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(worker_id).attributes.get("task_state") == &"WAITING_FOR_MATERIALS": break
	check(sim.entity_queries().snapshot(worker_id).attributes.get("task_state") == &"WAITING_FOR_MATERIALS","Material-starved construction is a real waiting task")
	configure(sim,{"timber":{"target":1,"priority":3}});sim.advance_ticks(1)
	check(sim.entity_queries().snapshot(worker_id).attributes.get("work_role") == &"timber","Waiting builder can safely switch to supply recovery instead of deadlocking")
	check(sim.entity_queries().snapshot(starved_home).attributes.assigned_builder_id == 0,"Unfinished site is released without deleting progress or staged materials")
	var suspended := codec.restore(codec.capture(sim,{}),sim,{})
	check(suspended != null,"Suspended construction plus new supply task remains save-valid")
	if suspended != null: suspended.free()
	sim.free()
	print("GOPALA_TEST_REPORT=",JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
