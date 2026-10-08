class_name GopalaHerdService
extends RefCounted

## Herd inputs leave a store only on physical pickup. Worker records own loads;
## milk is an uncollected source until a carrier reaches a real store.
var simulation: GopalaSettlementSimulation
func _init(sim: GopalaSettlementSimulation): simulation = sim
func update(id: int, attrs: Dictionary, tick_value: int): simulation._survival_service.update(id,attrs,tick_value)
func point(entity: GopalaEntitySnapshot) -> Vector2: return Vector2(entity.attributes.position_x,entity.attributes.position_z)
func pastures() -> Array[GopalaEntitySnapshot]: return simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.ZONE)
func animals() -> Array[GopalaEntitySnapshot]: return simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.ANIMAL)
func cells(anchor: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in simulation.placement_service().get_footprint_offsets(Vector2i(4,4)): result.append(cell+anchor)
	return result
func validate_pasture(anchor: Vector2i) -> GopalaConstructionValidationResult:
	var area := cells(anchor)
	var reason: StringName = &"VALID"
	if not simulation.coordinate_service().cells_in_bounds(area): reason = &"OUT_OF_BOUNDS"
	for cell in area:
		if not simulation._route_service.is_open(cell): reason = &"UNBUILDABLE_GROUND"
		for zone in pastures():
			if zone.attributes.zone_cells.has([cell.x,cell.y]): reason = &"PASTURE_OVERLAP"
	return GopalaConstructionValidationResult.new(reason == &"VALID",reason,anchor,area,[])
func create_pasture(command: GopalaSimulationCommand, tick_value: int) -> GopalaCommandResult:
	var p := command.payload
	if not simulation._survival_service.enabled() or typeof(p.get("cell_x")) != TYPE_INT or typeof(p.get("cell_y")) != TYPE_INT:
		return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.REJECTED,&"INVALID_PAYLOAD",tick_value)
	var anchor := Vector2i(p.cell_x,p.cell_y)
	var validation := validate_pasture(anchor)
	if not validation.valid: return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.REJECTED,validation.reason_code,tick_value)
	var center := simulation.coordinate_service().settlement_cell_to_world_xz(anchor)+Vector2.ONE*simulation.coordinate_service()._config.world_units_per_cell*1.5
	var rows := []
	for cell in validation.transformed_cells: rows.append([cell.x,cell.y])
	var result := simulation.entity_registry().create_entity(GopalaEntityKind.ZONE,{&"definition_id":&"pasture",&"zone_cells":rows,&"position_x":center.x,&"position_z":center.y,&"grazing_available":16,&"grazing_consumed":0,&"cattle_capacity":2},{},tick_value)
	return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.APPLIED,&"PASTURE_CREATED",tick_value,{"changed":true,"entity_id":result.entity_id})
# Assignment is persistent; route caches are derived and rebuilt after loading.
var _cow_routes := {}
func occupants(pasture_id: int) -> Array[GopalaEntitySnapshot]:
	return animals().filter(func(c): return int(c.attributes.get(&"pasture_id",0)) == pasture_id)
func pasture_summary(pasture: GopalaEntitySnapshot) -> Dictionary:
	var count := occupants(pasture.entity_id).size()
	var capacity := int(pasture.attributes.cattle_capacity)
	var cycle := int(simulation._survival_service.policy.cattle_cycle_ticks)
	var multiplier := maxi(1,ceili(float(count)/capacity))
	return {"count":count,"capacity":capacity,"overcrowded":count>capacity,"cycle_multiplier":multiplier,"grazing_minutes":float(pasture.attributes.grazing_available)*cycle*multiplier/maxi(count,1)/60.0}
func cow_destination(cow: GopalaEntitySnapshot, pasture: GopalaEntitySnapshot) -> Vector2:
	var herd := occupants(pasture.entity_id)
	var slot := herd.find(cow)
	# Snapshots are separate values; stable IDs determine the slot.
	for i in herd.size():
		if herd[i].entity_id == cow.entity_id: slot = i; break
	var offset := Vector2(float(slot%4)-1.5,float(slot/4)-1.5)*GopalaScaleStandard.metres_to_world(1.5)
	return point(pasture)+offset
func assign_pasture(command: GopalaSimulationCommand, tick_value: int) -> GopalaCommandResult:
	var p := command.payload
	if not simulation._survival_service.enabled() or typeof(p.get("cow_id")) != TYPE_INT or typeof(p.get("pasture_id")) != TYPE_INT:
		return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.REJECTED,&"INVALID_PAYLOAD",tick_value)
	var cow := simulation.entity_queries().snapshot(p.cow_id)
	var pasture := simulation.entity_queries().snapshot(p.pasture_id)
	if cow == null or cow.kind != GopalaEntityKind.ANIMAL or pasture == null or pasture.kind != GopalaEntityKind.ZONE:
		return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.REJECTED,&"INVALID_TARGET",tick_value)
	if occupants(pasture.entity_id).size() >= 16 and int(cow.attributes.get(&"pasture_id",0)) != pasture.entity_id:
		return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.REJECTED,&"PASTURE_FULL",tick_value)
	if not simulation._route_service.plan(point(cow),point(pasture),&"HERD").ok:
		return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.REJECTED,&"NO_ROUTE",tick_value)
	var owner := simulation.entity_queries().snapshot(int(cow.attributes.get(&"assigned_herder_id",0)))
	if owner != null:
		var amount := int(owner.attributes.get(&"carried_amount",0))
		if amount > 0: simulation._storage_service.drop(owner.attributes.carried_resource_id,amount,point(owner),tick_value)
		_finish(owner,tick_value)
	update(cow.entity_id,{&"pasture_id":pasture.entity_id,&"pasture_manual":true,&"cattle_move_state":&"MOVING"},tick_value)
	_cow_routes.erase(cow.entity_id)
	return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.APPLIED,&"PASTURE_ASSIGNED",tick_value,{"changed":true})
func _walk(cow: GopalaEntitySnapshot, pasture: GopalaEntitySnapshot, tick_value: int) -> void:
	var destination := cow_destination(cow,pasture)
	var location := point(cow)
	if location.distance_to(destination) < 0.000001:
		update(cow.entity_id,{&"cattle_move_state":&"IDLE"},tick_value); return
	var cached: Dictionary = _cow_routes.get(cow.entity_id,{})
	var blocked := false
	if not cached.is_empty() and cached.revision != simulation._route_service.revision:
		for waypoint in cached.points:
			if not simulation._route_service.is_open(simulation.coordinate_service().world_to_settlement_cell(waypoint)): blocked = true; break
		cached.revision = simulation._route_service.revision
	if cached.is_empty() or cached.destination != destination or blocked:
		var route := simulation._route_service.plan(location,destination,&"HERD")
		if not route.ok:
			update(cow.entity_id,{&"cattle_move_state":&"BLOCKED"},tick_value); return
		cached = {"destination":destination,"revision":route.revision,"points":route.points}
		_cow_routes[cow.entity_id] = cached
	var remaining := GopalaScaleStandard.number("movement","walk_speed")
	while not cached.points.is_empty() and remaining > 0.0:
		var target: Vector2 = cached.points[0]
		var distance := location.distance_to(target)
		if distance <= remaining:
			location = target; remaining -= distance; cached.points.pop_front()
		else:
			location = location.move_toward(target,remaining); remaining = 0.0
	update(cow.entity_id,{&"position_x":location.x,&"position_z":location.y,&"cattle_move_state":&"IDLE" if cached.points.is_empty() else &"MOVING"},tick_value)
func tick(tick_value: int):
	if not simulation._survival_service.enabled(): return
	var shelters := simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING).filter(func(b): return b.attributes.get("definition_id") == &"cattle_shelter" and str(b.attributes.get("construction_state","COMPLETED")) == "COMPLETED")
	var herd := animals()
	for i in herd.size():
		var cow := herd[i]
		var pasture := simulation.entity_queries().snapshot(int(cow.attributes.get(&"pasture_id",0)))
		if pasture == null and not cow.attributes.get(&"pasture_manual",false) and not pastures().is_empty():
			var candidates := pastures()
			candidates.sort_custom(func(a,b): return occupants(a.entity_id).size()<occupants(b.entity_id).size())
			pasture = candidates[0]
		var shelter: GopalaEntitySnapshot = shelters[i/2] if shelters.size() > i/2 else null
		update(cow.entity_id,{&"pasture_id":pasture.entity_id if pasture != null else 0,&"shelter_id":shelter.entity_id if shelter != null else 0},tick_value)
		cow = simulation.entity_queries().snapshot(cow.entity_id)
		if pasture != null and cow.attributes.get(&"assigned_herder_id",0) == 0: _walk(cow,pasture,tick_value)
		cow = simulation.entity_queries().snapshot(cow.entity_id)
		var multiplier: int = pasture_summary(pasture).cycle_multiplier if pasture != null and int(cow.attributes.get(&"fodder_fed",0)) == 0 else 1
		var due := int(cow.attributes.get(&"next_milk_tick",0))+(multiplier-1)*int(simulation._survival_service.policy.cattle_cycle_ticks)
		var reason: StringName = &"READY"
		if pasture == null: reason = &"NO_PASTURE"
		elif shelter == null: reason = &"NO_SHELTER"
		elif int(cow.attributes.get(&"water_fed",0)) < 1: reason = &"NO_WATER"
		elif int(pasture.attributes.grazing_available) < 1 and int(cow.attributes.get(&"fodder_fed",0)) < 1: reason = &"NO_FEED"
		elif cow.attributes.get(&"cattle_move_state",&"IDLE") != &"IDLE": reason = &"MOVING_TO_PASTURE" if cow.attributes.cattle_move_state == &"MOVING" else &"PASTURE_ROUTE_BLOCKED"
		elif tick_value >= due and int(cow.attributes.get(&"tended_tick",-1)) < int(cow.attributes.get(&"next_milk_tick",0)): reason = &"NEEDS_TENDING"
		update(cow.entity_id,{&"herd_status":reason},tick_value)
		cow = simulation.entity_queries().snapshot(cow.entity_id)
		if reason == &"READY" and tick_value >= due:
			var source := simulation.entity_queries().snapshot(int(cow.attributes.get(&"milk_source_id",0)))
			if source != null and int(source.attributes.available_amount)+int(source.attributes.reserved_amount) >= 8:
				update(cow.entity_id,{&"herd_status":&"MILK_WAITING_FOR_COLLECTION"},tick_value)
				continue
			var feed: StringName = &"fodder" if int(cow.attributes.get(&"fodder_fed",0)) > 0 and (pasture_summary(pasture).overcrowded or int(pasture.attributes.grazing_available) == 0) else &"grazing"
			if feed == &"grazing": update(pasture.entity_id,{&"grazing_available":int(pasture.attributes.grazing_available)-1,&"grazing_consumed":int(pasture.attributes.grazing_consumed)+1},tick_value)
			var produced := int(simulation._survival_service.policy.milk_per_cycle)
			if source == null:
				var location := point(cow)
				var result := simulation.entity_registry().create_entity(GopalaEntityKind.RESOURCE_SOURCE,{&"resource_id":&"milk",&"cow_id":cow.entity_id,&"available_amount":0,&"initial_amount":8,&"reserved_amount":0,&"generated_amount":0,&"gatherable":true,&"position_x":location.x,&"position_z":location.y},{},tick_value)
				source = simulation.entity_queries().snapshot(result.entity_id)
			update(source.entity_id,{&"available_amount":int(source.attributes.available_amount)+produced,&"generated_amount":int(source.attributes.generated_amount)+produced,&"exhausted":false},tick_value)
			update(cow.entity_id,{&"water_fed":int(cow.attributes.get(&"water_fed",0))-1,&"fodder_fed":int(cow.attributes.get(&"fodder_fed",0))-(1 if feed == &"fodder" else 0),&"grazing_consumed":int(cow.attributes.get(&"grazing_consumed",0))+(1 if feed == &"grazing" else 0),&"milk_source_id":source.entity_id,&"milk_produced":int(cow.attributes.get(&"milk_produced",0))+produced,&"next_milk_tick":tick_value+int(simulation._survival_service.policy.cattle_cycle_ticks)},tick_value)
	for worker in simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER):
		if worker.attributes.get(&"task_kind") == &"HERD": _tick_worker(worker,tick_value)
		elif worker.attributes.get(&"work_role") == &"herder" and simulation._survival_service.ready_for_work(worker) and int(worker.attributes.get(&"active_task_id",0)) == 0 and int(worker.attributes.get(&"carried_amount",0)) == 0 and worker.attributes.get(&"movement_state") != &"MOVING": _assign(worker,tick_value)
func _assign(worker: GopalaEntitySnapshot, tick_value: int):
	for cow in animals():
		if cow.attributes.get(&"cattle_move_state",&"IDLE") != &"IDLE" or int(cow.attributes.get(&"assigned_herder_id",0)) > 0 or int(cow.attributes.get(&"pasture_id",0)) == 0 or int(cow.attributes.get(&"shelter_id",0)) == 0: continue
		var pasture := simulation.entity_queries().snapshot(cow.attributes.pasture_id)
		var resource: StringName = &"water" if int(cow.attributes.get(&"water_fed",0)) == 0 else (&"fodder" if (int(pasture.attributes.grazing_available) == 0 or pasture_summary(pasture).overcrowded) and int(cow.attributes.get(&"fodder_fed",0)) == 0 else &"")
		if resource == &"" and (tick_value < int(cow.attributes.get(&"next_milk_tick",0)) or int(cow.attributes.get(&"tended_tick",-1)) >= int(cow.attributes.get(&"next_milk_tick",0))): continue
		var store_id := 0
		if resource != &"":
			for store in simulation._storage_service.ordered_stores(resource,point(worker)):
				if simulation._storage_service.stored(store.entity_id,resource) > 0 and simulation._route_service.plan(point(worker),point(store),&"NEED").ok:
					store_id = store.entity_id; break
			if store_id == 0:
				# Crowded grass still supports slower production when fodder is unavailable.
				if resource == &"fodder" and int(pasture.attributes.grazing_available) > 0:
					resource = &""
					if tick_value < int(cow.attributes.get(&"next_milk_tick",0)) or int(cow.attributes.get(&"tended_tick",-1)) >= int(cow.attributes.get(&"next_milk_tick",0)): continue
				else: continue
		if not simulation._route_service.plan(point(worker),point(cow),&"HERD").ok: continue
		update(cow.entity_id,{&"assigned_herder_id":worker.entity_id},tick_value)
		update(worker.entity_id,{&"task_kind":&"HERD",&"active_task_id":cow.entity_id,&"herd_target_id":cow.entity_id,&"herd_store_id":store_id,&"herd_resource":resource,&"task_state":&"HERD_PICKUP" if resource != &"" else &"HERD_TEND",&"job_status":&"WORKING"},tick_value)
		simulation.villager_service().set_destination(worker.entity_id,simulation._storage_service.position(store_id) if store_id > 0 else point(cow),&"NEED" if store_id > 0 else &"HERD",cow.entity_id)
		return
	update(worker.entity_id,{&"job_status":&"WAITING_FOR_HERD_INPUTS"},tick_value)
func _finish(worker: GopalaEntitySnapshot, tick_value: int):
	var cow := simulation.entity_queries().snapshot(int(worker.attributes.get(&"herd_target_id",0)))
	if cow != null: update(cow.entity_id,{&"assigned_herder_id":0},tick_value)
	simulation.villager_service().stop(worker.entity_id,&"HERD_FINISHED")
	update(worker.entity_id,{&"task_kind":&"NONE",&"active_task_id":0,&"task_state":&"NONE",&"herd_target_id":0,&"herd_store_id":0,&"herd_resource":&"",&"carried_amount":0,&"carried_resource_id":&""},tick_value)
func _tick_worker(worker: GopalaEntitySnapshot, tick_value: int):
	var id := worker.entity_id
	var cow := simulation.entity_queries().snapshot(int(worker.attributes.get(&"herd_target_id",0)))
	var amount := int(worker.attributes.get(&"carried_amount",0))
	var resource: StringName = worker.attributes.get(&"herd_resource",&"")
	var canceled: bool = cow == null or not simulation._survival_service.ready_for_work(worker) or worker.attributes.get(&"work_role") != &"herder" or (cow != null and (int(cow.attributes.get(&"pasture_id",0)) == 0 or int(cow.attributes.get(&"shelter_id",0)) == 0))
	if canceled or worker.attributes.get(&"movement_state") == &"BLOCKED":
		# An interrupted load remains recoverable environmental stock at its physical location.
		if amount > 0: simulation._storage_service.drop(resource,amount,point(worker),tick_value)
		_finish(worker,tick_value)
		return
	if not simulation.villager_service().has_arrived(id): return
	if worker.attributes.task_state == &"HERD_PICKUP":
		var store_id: int = worker.attributes.herd_store_id
		if not simulation._storage_service.consume_at(store_id,resource,1): _finish(worker,tick_value); return
		update(id,{&"carried_amount":1,&"carried_resource_id":resource,&"task_state":&"HERD_FEED"},tick_value)
		simulation.villager_service().set_destination(id,point(cow),&"HERD",cow.entity_id)
		return
	if worker.attributes.task_state == &"HERD_FEED":
		var key: StringName = &"water_fed" if resource == &"water" else &"fodder_fed"
		var consumed: Dictionary = cow.attributes.get(&"consumed_goods",{}).duplicate()
		consumed[resource] = int(consumed.get(resource,0))+1
		update(cow.entity_id,{key:int(cow.attributes.get(key,0))+1,&"consumed_goods":consumed},tick_value)
	else:
		update(cow.entity_id,{&"tended_tick":tick_value},tick_value)
	_finish(worker,tick_value)
