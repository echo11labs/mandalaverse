extends SceneTree
var checks := 0
var failures: Array[String] = []
func _initialize(): run.call_deferred()
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label); push_error(label)
func run():
	var sim := GopalaSettlementSimulation.new()
	root.add_child(sim)
	sim.set_physics_process(false)
	sim.coordinate_service().configure(GopalaSettlementGridConfig.new(Vector2.ZERO,Rect2i(-24,-24,48,48),2.0,100.0))
	sim.bootstrap_session()
	var store: int = sim.entity_registry().create_entity(GopalaEntityKind.BUILDING,{&"definition_id":&"stockpile",&"position_x":0.0,&"position_z":0.0}).entity_id
	sim._storage_service.enable_locations(store)
	sim._route_service.enable(Rect2i(-24,-24,48,48))
	GopalaMvpScenario.setup(sim,Vector2.ZERO)
	for worker in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER): sim._survival_service.update(worker.entity_id,{&"meal_due_tick":10000,&"drink_due_tick":10000},0)
	var herder := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)[0].entity_id
	check(sim._herd_service.animals().size() == 2,"MVP begins with two cattle")
	check(sim.placement_service().validate_placement(&"dwelling",Vector2i(0,3),0).reason_code == &"CATTLE_IN_FOOTPRINT","Construction cannot trap cattle in a footprint")
	sim.set_paused(false); sim.process_pending_commands(); sim.advance_ticks(10)
	check(sim.resource_amount(&"milk") == 0 and sim._herd_service.animals()[0].attributes.herd_status == &"NO_PASTURE","No pasture produces no milk")
	sim.submit_command(GopalaSimulationCommand.CREATE_PASTURE,{"cell_x":4,"cell_y":4})
	sim.process_pending_commands(); sim.advance_ticks(1)
	check(sim._herd_service.pastures().size() == 1,"Player places an eight-metre pasture on the grid")
	check(not sim._herd_service.validate_pasture(Vector2i(5,5)).valid,"Pastures cannot overlap")
	check(not sim.placement_service().validate_placement(&"dwelling",Vector2i(4,4),0).valid,"Buildings cannot consume a pasture plot")
	check(sim._herd_service.animals()[0].attributes.herd_status == &"NO_SHELTER","Pasture alone cannot produce milk")
	sim.entity_registry().create_entity(GopalaEntityKind.BUILDING,{&"definition_id":&"cattle_shelter",&"construction_state":&"COMPLETED",&"position_x":-0.1,&"position_z":0.0},{},sim.logical_tick)
	sim.advance_ticks(1)
	check(sim._herd_service.animals()[0].attributes.herd_status == &"NO_WATER","Shelter without physically fed water cannot produce milk")
	sim.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":herder,"role":&"herder"});sim.process_pending_commands()
	for i in 100:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(herder).attributes.get(&"carried_amount",0) == 1: break
	var worker := sim.entity_queries().snapshot(herder)
	check(worker.attributes.get(&"carried_resource_id") == &"water" and sim.resource_amount(&"water") == 63,"Herder physically picks one water unit from stock")
	var codec := GopalaSettlementSave.new()
	var loaded := codec.restore(codec.capture(sim,{}),sim,{})
	check(loaded != null,"Save restores a feed load in transit: "+codec.error)
	if loaded == null: sim.free(); finish(); return
	sim.free(); sim = loaded; root.add_child(sim);sim.set_physics_process(false)
	for i in 250:
		sim.advance_ticks(1)
		if sim._herd_service.animals().all(func(c): return c.attributes.milk_produced >= 2): break
	check(sim._herd_service.animals().all(func(c): return c.attributes.milk_produced >= 2),"Both cattle require water, grazing and a physical tending visit")
	check(sim._herd_service.pastures()[0].attributes.grazing_consumed == 2,"Each cow consumes one grazing ration per production")
	check(sim.resource_amount(&"milk") == 0,"Produced milk remains at cattle until collected")
	var carrier := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)[1].entity_id
	sim.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":carrier,"role":&"milk"});sim.process_pending_commands()
	for i in 150:
		sim.advance_ticks(1)
		if sim.resource_amount(&"milk") > 0: break
	check(sim.resource_amount(&"milk") > 0 and sim._storage_service.stored(store,&"milk") == sim.resource_amount(&"milk"),"Milk carrier deposits into a located store")
	# Hungry interruption drops its physical load once, without remote refunds.
	for i in 250:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(herder).attributes.get(&"carried_amount",0) == 1: break
	check(sim.entity_queries().snapshot(herder).attributes.get(&"carried_amount",0) == 1,"Second herd supply cycle owns a real load")
	var water_before := sim.resource_amount(&"water")
	sim._survival_service.update(herder,{&"meal_due_tick":0},sim.logical_tick)
	sim.advance_ticks(1)
	var dropped := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE).filter(func(s): return s.attributes.get(&"recovered_goods",false) and s.attributes.resource_id == &"water")
	check(dropped.size() == 1 and dropped[0].attributes.available_amount == 1 and sim.resource_amount(&"water") == water_before,"Interrupted herder leaves recoverable water at its physical position")
	var invalid := codec.capture(sim,{})
	for row in invalid.records:
		if row[1] == GopalaEntityKind.ANIMAL: row[6][&"water_fed"] = 50
	check(codec.restore(invalid,sim,{}) == null,"Impossible cattle input save rejected")
	sim.free(); management_tests(); finish()
func finish():
	print("GOPALA_TEST_REPORT="+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func management_tests():
	var sim := GopalaSettlementSimulation.new()
	root.add_child(sim);sim.set_physics_process(false)
	sim.coordinate_service().configure(GopalaSettlementGridConfig.new(Vector2.ZERO,Rect2i(-24,-24,48,48),2.0,100.0))
	sim.bootstrap_session()
	var store: int = sim.entity_registry().create_entity(GopalaEntityKind.BUILDING,{&"definition_id":&"stockpile",&"position_x":0.0,&"position_z":0.0}).entity_id
	sim._storage_service.enable_locations(store);sim._route_service.enable(Rect2i(-24,-24,48,48))
	GopalaMvpScenario.setup(sim,Vector2.ZERO)
	for worker in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER): sim._survival_service.update(worker.entity_id,{&"meal_due_tick":10000,&"drink_due_tick":10000},0)
	for anchor in [Vector2i(4,4),Vector2i(-8,-8)]:
		sim.submit_command(GopalaSimulationCommand.CREATE_PASTURE,{"cell_x":anchor.x,"cell_y":anchor.y})
	sim.set_paused(false);sim.process_pending_commands();sim.advance_ticks(30)
	var cow := sim._herd_service.animals()[0]
	var other := sim._herd_service.animals()[1]
	var plots := sim._herd_service.pastures()
	check(cow.attributes.pasture_id != other.attributes.pasture_id,"Initial assignment balances cattle across plots")
	var destination: GopalaEntitySnapshot = plots.filter(func(p):return p.entity_id != cow.attributes.pasture_id)[0]
	var start := sim._herd_service.point(cow)
	sim.submit_command(GopalaSimulationCommand.ASSIGN_CATTLE_PASTURE,{"cow_id":cow.entity_id,"pasture_id":destination.entity_id});sim.process_pending_commands()
	check(sim._herd_service.point(sim.entity_queries().snapshot(cow.entity_id)) == start,"Assignment cannot teleport cattle")
	sim.advance_ticks(1)
	cow = sim.entity_queries().snapshot(cow.entity_id)
	check(sim._herd_service.point(cow).distance_to(start) <= GopalaScaleStandard.number("movement","walk_speed")+0.000001 and cow.attributes.cattle_move_state == &"MOVING","Cattle walk at the standard speed")
	var codec := GopalaSettlementSave.new()
	var restored := codec.restore(codec.capture(sim,{}),sim,{})
	check(restored != null,"Mid-relocation save restores: "+codec.error)
	if restored == null: sim.free();return
	sim.free();sim = restored;root.add_child(sim);sim.set_physics_process(false)
	sim.advance_ticks(100)
	cow = sim.entity_queries().snapshot(cow.entity_id)
	check(cow.attributes.pasture_id == destination.entity_id and cow.attributes.cattle_move_state == &"IDLE","Relocation completes after load without losing assignment")
	check(sim._herd_service.point(cow).distance_to(sim._herd_service.cow_destination(cow,sim.entity_queries().snapshot(destination.entity_id))) < 0.000001,"Cattle reach an in-plot destination")
	var invalid := codec.capture(sim,{})
	for row in invalid.records:
		if row[1] == GopalaEntityKind.ANIMAL: row[6][&"pasture_id"] = store
	check(codec.restore(invalid,sim,{}) == null,"Save rejects non-pasture cattle assignment")
	var target_id: int = destination.entity_id
	var applied := sim._apply_command_for_tests(GopalaSimulationCommand._from_queue(999,GopalaSimulationCommand.ASSIGN_CATTLE_PASTURE,sim.logical_tick,{"cow_id":cow.entity_id,"pasture_id":store},&"test"))
	check(applied.status == GopalaCommandResult.Status.REJECTED and sim.entity_queries().snapshot(cow.entity_id).attributes.pasture_id == target_id,"Invalid command leaves assignment unchanged")
	sim._route_service.enable(Rect2i(-24,-24,48,48),func(_point):return false)
	applied = sim._apply_command_for_tests(GopalaSimulationCommand._from_queue(1000,GopalaSimulationCommand.ASSIGN_CATTLE_PASTURE,sim.logical_tick,{"cow_id":cow.entity_id,"pasture_id":plots[0].entity_id},&"test"))
	check(applied.status == GopalaCommandResult.Status.REJECTED,"Unreachable pasture assignment is rejected")
	sim._route_service.enable(Rect2i(-24,-24,48,48))
	# Three cattle on one plot expose overcrowding; inputs still conserve per cycle.
	var attrs := cow.attributes.duplicate(true)
	attrs[&"assigned_herder_id"] = 0;attrs[&"display_name"] = "Cow 3"
	var third := sim.entity_registry().create_entity(GopalaEntityKind.ANIMAL,attrs,{},sim.logical_tick)
	for i in 2: sim.entity_registry().create_entity(GopalaEntityKind.BUILDING,{&"definition_id":&"cattle_shelter",&"construction_state":&"COMPLETED",&"position_x":-0.1,&"position_z":0.0},{},sim.logical_tick)
	sim.advance_ticks(30)
	check(sim._herd_service.pasture_summary(sim.entity_queries().snapshot(target_id)).overcrowded,"Three cattle exceed the two-cow grazing capacity")
	var summary := sim._herd_service.pasture_summary(sim.entity_queries().snapshot(target_id))
	check(summary.cycle_multiplier == 2 and summary.grazing_minutes > 0.0,"Pasture exposes support and remaining grazing minutes")
	for animal in sim._herd_service.animals(): prime(sim,animal.entity_id,store,false)
	var fallback_worker := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)[0]
	var fallback_cow := sim.entity_queries().snapshot(cow.entity_id)
	sim._survival_service.update(fallback_cow.entity_id,{&"tended_tick":-1},sim.logical_tick)
	sim._survival_service.update(fallback_worker.entity_id,{&"work_role":&"herder"},sim.logical_tick)
	sim.advance_ticks(1)
	check(sim.entity_queries().snapshot(fallback_worker.entity_id).attributes.get(&"task_state") == &"HERD_TEND","Crowded grass can be tended when no fodder is stocked")
	sim._survival_service.update(fallback_worker.entity_id,{&"work_role":&"NONE"},sim.logical_tick)
	sim.advance_ticks(1)
	sim._survival_service.update(fallback_cow.entity_id,{&"tended_tick":sim.logical_tick},sim.logical_tick)
	check(sim._herd_service.animals().all(func(c):return c.attributes.milk_produced == 0),"Overcrowding delays grazing-only milk cycles")
	sim.advance_ticks(120)
	check(sim._herd_service.animals().all(func(c):return c.attributes.milk_produced == 2),"Overcrowded cattle produce after the slower cycle")
	check(sim.entity_queries().snapshot(target_id).attributes.grazing_consumed == 3,"Slower cycles still consume exactly one ration each")
	sim._storage_service.credit(store,&"fodder",3,true)
	for animal in sim._herd_service.animals(): prime(sim,animal.entity_id,store,true)
	sim.advance_ticks(1)
	check(sim._herd_service.animals().all(func(c):return c.attributes.milk_produced == 4),"Prepared fodder restores supported milk cycles despite crowding")
	check(sim.entity_queries().snapshot(target_id).attributes.grazing_consumed == 3 and sim.resource_amount(&"fodder") == 0,"Fodder support consumes delivered feed rather than grazing")
	var valid := codec.restore(codec.capture(sim,{}),sim,{})
	check(valid != null,"Overcrowded production journals remain valid: "+codec.error)
	if valid != null: valid.free()
	# Moving one cow restores normal grass support for both plots.
	var free_plot: int = plots.filter(func(p):return p.entity_id != target_id)[0].entity_id
	sim.submit_command(GopalaSimulationCommand.ASSIGN_CATTLE_PASTURE,{"cow_id":third.entity_id,"pasture_id":free_plot});sim.process_pending_commands();sim.advance_ticks(100)
	check(not sim._herd_service.pasture_summary(sim.entity_queries().snapshot(target_id)).overcrowded,"Moving cattle restores normal pasture support")
	sim.free()
func prime(sim: GopalaSettlementSimulation,cow_id: int,store: int,fodder: bool):
	var cow := sim.entity_queries().snapshot(cow_id)
	var consumed: Dictionary = cow.attributes.get(&"consumed_goods",{}).duplicate()
	check(sim._storage_service.consume_at(store,&"water",1),"Test prepares real store water")
	consumed[&"water"] = int(consumed.get(&"water",0))+1
	if fodder:
		check(sim._storage_service.consume_at(store,&"fodder",1),"Test prepares real store fodder")
		consumed[&"fodder"] = int(consumed.get(&"fodder",0))+1
	sim._survival_service.update(cow_id,{&"water_fed":1,&"fodder_fed":1 if fodder else 0,&"consumed_goods":consumed,&"tended_tick":sim.logical_tick,&"next_milk_tick":sim.logical_tick},sim.logical_tick)
