extends SceneTree
var checks := 0
var failures: Array[String] = []
const SAVE := "user://saves/mvp-scenario-test.json"
func _initialize(): run.call_deferred()
func check(value: bool,label: String):
	checks += 1
	if not value: failures.append(label); push_error(label)
func meta(sim): return sim.entity_queries().snapshots_by_kind(GopalaEntityKind.SETTLEMENT).filter(func(s): return s.attributes.get(&"survival_enabled",false))[0]
func run():
	var valley = load("res://scenes/mvp.tscn").instantiate()
	root.add_child(valley)
	var sim: GopalaSettlementSimulation = valley.simulation
	sim.set_physics_process(false)
	# Accelerated gameplay acceptance keeps rendering out of the logical-time test.
	sim.snapshot_committed.disconnect(valley._on_snapshot_committed)
	var workers := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)
	var definitions: Array[StringName] = [&"dwelling",&"dwelling",&"stockpile",&"water_point",&"cattle_shelter",&"timber_camp",&"gatherer_shelter"]
	var sites: Array[int] = []
	for i in definitions.size():
		var chosen := false
		for radius in range(3,14):
			for cell in [Vector2i(radius,0),Vector2i(-radius,0),Vector2i(0,radius),Vector2i(0,-radius),Vector2i(radius,radius),Vector2i(-radius,radius),Vector2i(radius,-radius),Vector2i(-radius,-radius)]:
				if not sim.placement_service().validate_placement(definitions[i],cell,0).valid: continue
				sim.request_construction(definitions[i],cell);sim.process_pending_commands()
				var id := sim._entity_ids._next_id-1
				sites.append(id)
				sim.submit_command(GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER,{"villager_id":workers[i].entity_id,"blueprint_id":id});sim.process_pending_commands()
				chosen = true;break
			if chosen: break
		check(chosen,"Place real blueprint "+str(definitions[i]))
	var pasture_placed := false
	for radius in range(4,17):
		for cell in [Vector2i(radius,radius),Vector2i(-radius,radius),Vector2i(radius,-radius),Vector2i(-radius,-radius)]:
			if sim._herd_service.validate_pasture(cell).valid:
				sim.submit_command(GopalaSimulationCommand.CREATE_PASTURE,{"cell_x":cell.x,"cell_y":cell.y});sim.process_pending_commands();pasture_placed = true;break
		if pasture_placed: break
	check(pasture_placed,"Place reachable pasture in the actual valley")
	sim.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":workers[7].entity_id,"role":&"wild_food"});sim.set_paused(false);sim.process_pending_commands()
	for i in 1000:
		sim.advance_ticks(1)
		if sites.all(func(id): return str(sim.entity_queries().snapshot(id).attributes.construction_state) == "COMPLETED"): break
	check(sites.size() == 7 and sites.all(func(id): return str(sim.entity_queries().snapshot(id).attributes.construction_state) == "COMPLETED"),"Seven structures finish using real material hauling and labour")
	var roles: Array[StringName] = [&"water",&"water",&"wild_food",&"wild_food",&"herder",&"milk",&"fodder",&"NONE"]
	for i in 8: sim.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":workers[i].entity_id,"role":roles[i]})
	sim.process_pending_commands()
	var saved := false
	for i in 2400:
		sim.advance_ticks(1)
		if not saved and int(meta(sim).attributes.stable_ticks) >= 450:
			check(valley.save_settlement(SAVE),"Save actual MVP halfway through its sustain objective")
			check(valley.load_settlement(SAVE),"Reload actual MVP without manually repairing jobs")
			sim = valley.simulation
			sim.set_physics_process(false)
			sim.snapshot_committed.disconnect(valley._on_snapshot_committed)
			saved = true
		if meta(sim).attributes.objective_state in [&"SUCCESS",&"FAILED"]: break
	check(saved,"Fifteen-minute acceptance includes a mid-objective reload")
	check(meta(sim).attributes.objective_state == &"SUCCESS","Eight settlers sustain fifteen logical minutes: "+str(meta(sim).attributes))
	check(sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER).all(func(w): return int(w.attributes.health) >= 50 and int(w.attributes.home_id) > 0),"All eight settlers remain housed and healthy after reload")
	var production_before: int = sim._herd_service.animals()[0].attributes.milk_produced
	sim.advance_ticks(240)
	check(sim._herd_service.animals().all(func(c): return int(c.attributes.get(&"consumed_goods",{}).get(&"fodder",0)) > 0),"Empty pasture transitions to physically hauled fodder")
	check(sim._herd_service.animals()[0].attributes.milk_produced > production_before,"Cattle continue producing after the objective and pasture depletion")
	print("GOPALA_MVP_ACCEPTANCE="+JSON.stringify({"tick":sim.logical_tick,"objective":str(meta(sim).attributes.objective_state),"stable_ticks":meta(sim).attributes.stable_ticks,"resources":sim.resource_balances_snapshot(),"cattle":sim._herd_service.animals().map(func(c):return c.attributes)}))
	valley.queue_free();await process_frame
	for suffix in ["",".tmp",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
	print("GOPALA_TEST_REPORT="+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
