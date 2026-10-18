class_name GopalaSurvivalService
extends RefCounted

const POLICY_PATH := "res://data/mvp_policy.json"
var simulation: GopalaSettlementSimulation
var policy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
func _init(sim: GopalaSettlementSimulation): simulation = sim

func enabled() -> bool:
	return simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.SETTLEMENT).any(func(s): return s.attributes.get(&"survival_enabled",false))

func update(id: int, changes: Dictionary, tick_value: int) -> void:
	var entity := simulation.entity_queries().snapshot(id)
	if entity == null: return
	if changes.keys().all(func(key): return entity.attributes.has(key) and entity.attributes[key] == changes[key]): return
	simulation.entity_registry().update_entity(id,changes,{},tick_value,entity.revision)

func ready_for_work(worker: GopalaEntitySnapshot) -> bool:
	if not enabled(): return true
	return worker.attributes.get(&"need_state",&"SATISFIED") == &"SATISFIED"

func tick(tick_value: int) -> void:
	if not enabled(): return
	_sync_water_points(tick_value)
	_assign_homes(tick_value)
	for worker in simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER):
		_tick_worker(worker,tick_value)

func _assign_homes(tick_value: int) -> void:
	var homes := simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING).filter(func(b): return b.attributes.get("definition_id") == &"dwelling" and str(b.attributes.get("construction_state","COMPLETED")) == "COMPLETED")
	var occupants := {}
	for worker in simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER):
		var home_id := 0
		for home in homes:
			var definition := simulation.placement_service().get_building(&"dwelling")
			if int(occupants.get(home.entity_id,0)) < definition.home_capacity:
				home_id = home.entity_id
				occupants[home_id] = int(occupants.get(home_id,0)) + 1
				break
		if worker.attributes.get(&"home_id",-1) != home_id: update(worker.entity_id,{&"home_id":home_id},tick_value)

func _tick_worker(original: GopalaEntitySnapshot, tick_value: int) -> void:
	var id := original.entity_id
	if not original.attributes.has(&"meal_due_tick"):
		update(id,{&"meal_due_tick":tick_value+int(policy.meal_interval_ticks),&"drink_due_tick":tick_value+int(policy.drink_interval_ticks),&"health":100,&"need_state":&"SATISFIED",&"need_store_id":0,&"need_resource":&"",&"consumed_goods":{}},tick_value)
	var worker := simulation.entity_queries().snapshot(id)
	var thirsty: bool = tick_value >= int(worker.attributes.drink_due_tick)
	var hungry: bool = tick_value >= int(worker.attributes.meal_due_tick)
	if tick_value % int(policy.health_interval_ticks) == 0:
		var overdue := tick_value - mini(int(worker.attributes.drink_due_tick),int(worker.attributes.meal_due_tick))
		var health := clampi(int(worker.attributes.health) + (-int(policy.health_change) if overdue > int(policy.shortage_grace_ticks) else int(policy.health_change)),0,100)
		update(id,{&"health":health,&"movement_speed":GopalaScaleStandard.number("movement","walk_speed")*(0.5 if health < 25 else 1.0)},tick_value)
	if not thirsty and not hungry:
		if worker.attributes.get(&"task_kind") == &"NEED":
			simulation.villager_service().stop(id,&"NEED_MET")
			update(id,{&"task_kind":&"NONE",&"task_state":&"NONE",&"need_store_id":0,&"need_resource":&""},tick_value)
		update(id,{&"need_state":&"SATISFIED"},tick_value)
		var resume: int = worker.attributes.get(&"resume_blueprint_id",0)
		if resume > 0 and worker.attributes.get(&"active_task_id",0) == 0:
			update(id,{&"resume_blueprint_id":0},tick_value)
			if simulation.entity_queries().snapshot(resume) != null:
				simulation._construction_labor_service.handle_request_assign_builder(GopalaSimulationCommand._from_queue(0,GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER,tick_value,{"villager_id":id,"blueprint_id":resume},&"needs_resume"),tick_value)
		return
	# Release unpicked collection, but finish any carried delivery before changing ownership.
	if simulation.gather_delivery_service()._tasks.has(id):
		var task: Dictionary = simulation.gather_delivery_service()._tasks[id]
		# A hungry final carrier may continue collecting the missing good as a fallback.
		var fallback: bool = (task.resource_id == &"water" and thirsty and simulation.resource_amount(&"water") == 0) or (task.resource_id in [&"wild_food",&"milk"] and hungry and simulation.resource_amount(&"wild_food")+simulation.resource_amount(&"milk") == 0)
		if not fallback:
			var command := GopalaSimulationCommand._from_queue(0,GopalaSimulationCommand.REQUEST_STOP_GATHERING,tick_value,{"villager_id":id},&"needs")
			simulation.gather_delivery_service().handle_stop_gathering(command,tick_value)
	if simulation._construction_labor_service._tasks.has(id):
		var task: Dictionary = simulation._construction_labor_service._tasks[id]
		if task.state != &"RETURNING_TO_CAMP":
			update(id,{&"resume_blueprint_id":task.blueprint_id},tick_value)
			simulation._construction_labor_service.cancel_task(id,tick_value,&"NEEDS_BREAK")
	worker = simulation.entity_queries().snapshot(id)
	if worker.attributes.get(&"active_task_id",0) > 0 or worker.attributes.get(&"carried_amount",0) > 0:
		update(id,{&"need_state":&"FINISHING_DELIVERY"},tick_value)
		return
	var resource: StringName = &"water" if thirsty else (&"wild_food" if simulation.resource_amount(&"wild_food") > 0 else &"milk")
	var target: int = worker.attributes.get(&"need_store_id",0)
	if worker.attributes.get(&"need_resource") != resource or target == 0 or simulation.entity_queries().snapshot(target) == null or simulation._storage_service.stored(target,resource) < 1:
		target = _find_store(worker,resource)
		update(id,{&"need_resource":resource,&"need_store_id":target},tick_value)
		if target > 0:
			update(id,{&"task_kind":&"NEED",&"task_state":&"FETCHING_SUPPLIES",&"need_state":&"FETCHING_SUPPLIES"},tick_value)
			simulation.villager_service().set_destination(id,simulation._storage_service.position(target),&"NEED",0)
			return
	if target == 0:
		simulation.villager_service().stop(id,&"SHORTAGE")
		update(id,{&"task_kind":&"NONE",&"task_state":&"NONE",&"need_state":&"NO_ACCESS" if simulation.resource_amount(resource) > 0 else (&"NO_WATER" if thirsty else &"NO_FOOD")},tick_value)
		return
	if worker.attributes.get(&"movement_state") == &"BLOCKED":
		update(id,{&"need_store_id":0,&"need_state":&"NO_ACCESS"},tick_value)
		return
	if not simulation.villager_service().has_arrived(id): return
	# Quantity is checked again at arrival; competing diners never spend negative stock.
	if simulation._storage_service.consume_at(target,resource,1):
		var other_due: bool = hungry if resource == &"water" else thirsty
		var consumed: Dictionary = worker.attributes.get(&"consumed_goods",{}).duplicate()
		consumed[resource] = int(consumed.get(resource,0))+1
		update(id,{&"drink_due_tick" if resource == &"water" else &"meal_due_tick":tick_value+int(policy.drink_interval_ticks if resource == &"water" else policy.meal_interval_ticks),&"consumed_goods":consumed,&"need_store_id":0,&"need_resource":&"",&"task_kind":&"NONE",&"task_state":&"NONE",&"need_state":&"SEEKING_SUPPLIES" if other_due else &"SATISFIED"},tick_value)

func _find_store(worker: GopalaEntitySnapshot, resource: StringName) -> int:
	var position := Vector2(worker.attributes.position_x,worker.attributes.position_z)
	for store in simulation._storage_service.ordered_stores(resource,position):
		if simulation._storage_service.stored(store.entity_id,resource) < 1: continue
		if not simulation._route_service.enabled or simulation._route_service.plan(position,simulation._storage_service.position(store.entity_id),&"NEED").ok: return store.entity_id
	return 0

func _sync_water_points(tick_value: int) -> void:
	for source in simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE):
		if not source.attributes.has(&"water_producer_id"): continue
		var producer := simulation.entity_queries().snapshot(source.attributes.water_producer_id)
		if producer == null:
			if source.attributes.get(&"gatherable",true): update(source.entity_id,{&"gatherable":false,&"available_amount":0},tick_value)
			continue
		if tick_value - int(source.attributes.get(&"last_refill_tick",0)) >= int(policy.water_refill_ticks):
			var amount := maxi(0,int(policy.water_source_capacity)-int(source.attributes.available_amount)-int(source.attributes.reserved_amount))
			update(source.entity_id,{&"available_amount":int(source.attributes.available_amount)+amount,&"generated_amount":int(source.attributes.get(&"generated_amount",0))+amount,&"last_refill_tick":tick_value,&"exhausted":false},tick_value)
	for building in simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING):
		if building.attributes.get("definition_id") != &"water_point" or str(building.attributes.get("construction_state","COMPLETED")) != "COMPLETED" or building.attributes.get(&"water_source_id",0) > 0: continue
		var claim := simulation.occupancy_service().claim_for_owner(building.entity_id)
		if claim == null: continue
		var entry := Vector2i.ZERO
		var found := false
		for cell in claim.cells:
			for offset in [Vector2i(0,1),Vector2i(1,0),Vector2i(-1,0),Vector2i(0,-1)]:
				var candidate: Vector2i = cell + offset
				if not claim.cells.has(candidate) and simulation._route_service.is_open(candidate): entry = candidate; found = true; break
			if found: break
		if not found: continue
		var point := simulation.coordinate_service().settlement_cell_to_world_xz(entry)
		var source := simulation.entity_registry().create_entity(GopalaEntityKind.RESOURCE_SOURCE,{&"resource_id":&"water",&"water_producer_id":building.entity_id,&"available_amount":int(policy.water_source_capacity),&"initial_amount":int(policy.water_source_capacity),&"reserved_amount":0,&"generated_amount":int(policy.water_source_capacity),&"last_refill_tick":tick_value,&"position_x":point.x,&"position_z":point.y,&"gatherable":true}, {},tick_value)
		update(building.entity_id,{&"water_source_id":source.entity_id},tick_value)
