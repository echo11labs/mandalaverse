class_name GopalaStorageService
extends RefCounted

## Completed stores hold stock partitions; the ledger projects available totals.
## Isolated legacy fixtures can retain pooled capacity until locations are enabled.
var simulation: GopalaSettlementSimulation
func _init(sim: GopalaSettlementSimulation): simulation = sim

func enabled() -> bool:
	return simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING).any(func(b): return b.attributes.has(&"storage_capacity") or b.attributes.get("definition_id") == &"stockpile")

func capacity(resource: StringName) -> int:
	var total := 0
	for building in simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING):
		if str(building.attributes.get("construction_state","COMPLETED")) != "COMPLETED": continue
		if building.attributes.has(&"storage_capacity"):
			total = mini(GopalaSimulationConfig.MAX_BALANCE,total + int(building.attributes.storage_capacity.get(resource,0)))
		elif building.attributes.get("definition_id") == &"stockpile":
			var definition := simulation.placement_service().get_building(&"stockpile")
			total = mini(GopalaSimulationConfig.MAX_BALANCE,total + int(definition.inventory_limits.get(resource,0)))
	if resource == &"grain":
		for building in simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING):
			if str(building.attributes.get("construction_state","COMPLETED")) == "COMPLETED" and building.attributes.get(&"definition_id") == &"stockpile":
				total = mini(GopalaSimulationConfig.MAX_BALANCE,total+int(building.attributes.get(&"storage_capacity",{}).get(resource,0)))
	return total

func incoming(resource: StringName) -> int:
	var total := 0
	for task in simulation.gather_delivery_service()._tasks.values():
		if task.resource_id == resource: total += 1
	return total

func staged(resource: StringName) -> int:
	var total := 0
	for building in (simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING) + simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.ROAD)):
		total += int(building.attributes.get("reserved_materials",{}).get(resource,0))
	return total

func has_space(resource: StringName) -> bool:
	if located: return destinations(resource).any(func(store): return store_has_space(store.entity_id,resource))
	return not enabled() or simulation.resource_amount(resource) + incoming(resource) + staged(resource) < capacity(resource)

func destinations(resource: StringName) -> Array[GopalaEntitySnapshot]:
	var result: Array[GopalaEntitySnapshot] = []
	for building in simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING):
		if str(building.attributes.get("construction_state","COMPLETED")) != "COMPLETED": continue
		if building.attributes.get(StringName("accepts_" + str(resource)),false) or (enabled() and building.attributes.get("definition_id") == &"stockpile"):
			result.append(building)
	return result

func can_deliver(resource: StringName) -> bool:
	return not enabled() or simulation.resource_amount(resource) + staged(resource) < capacity(resource)

# Located inventories are authoritative stock partitions; the ledger is their
# aggregate projection. Legacy small fixtures retain the previous pooled model.
var located := false
var stocks: Dictionary = {}
var _positions: Dictionary = {}
var _removed: Dictionary = {}
var flushing := false

func enable_locations(camp_id: int) -> void:
	if located: return
	located = true
	stocks[camp_id] = simulation.resource_balances_snapshot().duplicate()
	_cache_position(camp_id)

func _cache_position(id: int) -> void:
	var store := simulation.entity_queries().snapshot(id)
	if store != null: _positions[id] = [store.attributes.get(&"position_x",0.0),store.attributes.get(&"position_z",0.0)]

func store_capacity(id: int, resource: StringName) -> int:
	var store := simulation.entity_queries().snapshot(id)
	if store == null or str(store.attributes.get("construction_state","COMPLETED")) != "COMPLETED": return 0
	if store.attributes.has(&"storage_capacity"): return int(store.attributes.storage_capacity.get(resource,0))
	var definition := simulation.placement_service().get_building(StringName(store.attributes.get("definition_id","")))
	return int(definition.inventory_limits.get(resource,0)) if definition != null else 0

func stored(id: int, resource: StringName) -> int:
	return int(stocks.get(id,{}).get(resource,0))

func consume_at(id: int, resource: StringName, amount: int) -> bool:
	if not located or amount < 1 or stored(id,resource) < amount or simulation.entity_queries().snapshot(id) == null: return false
	if not simulation._ledger.apply_authorized_transaction({resource:-amount}): return false
	stocks[id][resource] -= amount
	return true

func reserved_at(id: int, resource: StringName) -> int:
	var total := 0
	for building in (simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING) + simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.ROAD)):
		total += int(building.attributes.get("material_origins",{}).get(resource,{}).get(id,0))
	return total

func incoming_at(id: int, resource: StringName, except_worker := 0) -> int:
	var total := 0
	for worker in simulation.gather_delivery_service()._tasks:
		var task: Dictionary = simulation.gather_delivery_service()._tasks[worker]
		if worker != except_worker and task.destination_id == id and task.resource_id == resource: total += 1
	return total

func store_has_space(id: int, resource: StringName, except_worker := 0) -> bool:
	if not located: return has_space(resource) if except_worker == 0 else can_deliver(resource)
	return stored(id,resource) + reserved_at(id,resource) + incoming_at(id,resource,except_worker) < store_capacity(id,resource)

func ordered_stores(resource: StringName, point: Vector2) -> Array[GopalaEntitySnapshot]:
	var stores := destinations(resource)
	stores.sort_custom(func(a,b):
		var da := point.distance_squared_to(Vector2(a.attributes.get(&"position_x",0.0),a.attributes.get(&"position_z",0.0)))
		var db := point.distance_squared_to(Vector2(b.attributes.get(&"position_x",0.0),b.attributes.get(&"position_z",0.0)))
		return a.entity_id < b.entity_id if is_equal_approx(da,db) else da < db
	)
	return stores

func credit(id: int, resource: StringName, amount: int, force := false, worker := 0) -> bool:
	if not located: return simulation._ledger.apply_authorized_transaction({resource:amount})
	if simulation.entity_queries().snapshot(id) == null: return false
	if not force and not store_has_space(id,resource,worker): return false
	if not simulation._ledger.apply_authorized_transaction({resource:amount}): return false
	if not stocks.has(id): stocks[id] = {}
	stocks[id][resource] = stored(id,resource) + amount
	_cache_position(id)
	return true

## Explicit authorized stock changes (consumption/debug supply) preserve the
## per-store decomposition. Haul deposits use credit with their actual target.
func apply_transaction(delta: Dictionary) -> bool:
	if not located: return simulation._ledger.apply_authorized_transaction(delta)
	if not simulation._ledger.validate_transaction(delta): return false
	var next := stocks.duplicate(true)
	for resource in delta:
		var remaining: int = absi(delta[resource])
		if delta[resource] < 0:
			for id in next:
				var take := mini(remaining,int(next[id].get(resource,0)))
				next[id][resource] = int(next[id].get(resource,0)) - take
				remaining -= take
			if remaining > 0: return false
		elif remaining > 0:
			var stores := destinations(resource)
			if stores.is_empty(): return false
			var id := stores[0].entity_id
			if not next.has(id): next[id] = {}
			next[id][resource] = int(next[id].get(resource,0)) + remaining
			_cache_position(id)
	if not simulation._ledger.apply_authorized_transaction(delta): return false
	stocks = next
	return true

func reserve_materials(delta: Dictionary, worker_position: Vector2, site: Vector2) -> Dictionary:
	var next := stocks.duplicate(true)
	var origins := {}
	for resource in delta:
		var remaining: int = -int(delta[resource])
		var allocation := {}
		for store in ordered_stores(resource,worker_position):
			var id := store.entity_id
			var point := Vector2(store.attributes.get(&"position_x",0.0),store.attributes.get(&"position_z",0.0))
			if simulation._route_service.enabled and (not simulation._route_service.plan(worker_position,point,&"BUILD").ok or not simulation._route_service.plan(point,site,&"BUILD").ok):
				# An occupied store anchor is not a path start; use its accessible edge.
				var access := simulation._route_service.plan(worker_position,point,&"BUILD")
				if not access.ok or not simulation._route_service.plan(access.destination,site,&"BUILD").ok: continue
			var take := mini(remaining,stored(id,resource))
			if take > 0:
				next[id][resource] -= take
				allocation[id] = take
				remaining -= take
				_cache_position(id)
			if remaining == 0: break
		if remaining > 0: return {"ok":false}
		origins[resource] = allocation
	if not simulation._ledger.apply_authorized_transaction(delta): return {"ok":false}
	stocks = next
	return {"ok":true,"origins":origins}

func pickup_store(blueprint: GopalaEntitySnapshot, resource: StringName, point: Vector2) -> int:
	var origins: Dictionary = blueprint.attributes.get("material_origins",{}).get(resource,{})
	for store in ordered_stores(resource,point):
		if int(origins.get(store.entity_id,0)) <= 0: continue
		var target := Vector2(store.attributes.get(&"position_x",0.0),store.attributes.get(&"position_z",0.0))
		if not simulation._route_service.enabled or simulation._route_service.plan(point,target,&"BUILD").ok: return store.entity_id
	return 0

func consume_origin(blueprint: GopalaEntitySnapshot, resource: StringName, id: int) -> Dictionary:
	var origins: Dictionary = blueprint.attributes.get("material_origins",{}).duplicate(true)
	origins[resource][id] -= 1
	if origins[resource][id] == 0: origins[resource].erase(id)
	return origins

func cancel_blueprint(blueprint: GopalaEntitySnapshot, tick: int) -> void:
	var refund: Dictionary[StringName,int] = {}
	for resource in blueprint.attributes.get("material_origins",{}):
		for id in blueprint.attributes.material_origins[resource]:
			var amount: int = blueprint.attributes.material_origins[resource][id]
			if not stocks.has(id): stocks[id] = {}
			stocks[id][resource] = stored(id,resource) + amount
			refund[StringName(resource)] = int(refund.get(StringName(resource),0)) + amount
	if not refund.is_empty(): simulation._ledger.apply_authorized_transaction(refund)
	var point := Vector2(blueprint.attributes.get("position_x",0.0),blueprint.attributes.get("position_z",0.0))
	for resource in blueprint.attributes.get("delivered_materials",{}):
		drop(resource,blueprint.attributes.delivered_materials[resource],point,tick)

func drop(resource: StringName, amount: int, point: Vector2, tick: int) -> int:
	if amount <= 0: return 0
	var source := simulation.entity_registry().create_entity(GopalaEntityKind.RESOURCE_SOURCE,{&"resource_id":resource,&"available_amount":amount,&"initial_amount":amount,&"reserved_amount":0,&"gatherable":true,&"position_x":point.x,&"position_z":point.y,&"recovered_goods":true}, {}, tick)
	return source.entity_id

func on_removed(id: int, _kind: StringName, _sequence: int) -> void:
	if located and stocks.has(id):
		_removed[id] = {"stock":stocks[id].duplicate(),"point":_positions.get(id,[0.0,0.0])}
		stocks.erase(id)

func flush_removed() -> void:
	if flushing or _removed.is_empty(): return
	flushing = true
	for id in _removed:
		var goods: Dictionary = _removed[id].stock
		var delta: Dictionary[StringName,int] = {}
		for resource in goods: delta[StringName(resource)] = -int(goods[resource])
		simulation._ledger.apply_authorized_transaction(delta)
		for building in (simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING) + simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.ROAD)):
			var origins: Dictionary = building.attributes.get("material_origins",{}).duplicate(true)
			var reserved: Dictionary = building.attributes.get("reserved_materials",{}).duplicate(true)
			var changed := false
			for resource in origins:
				if origins[resource].has(id):
					var amount: int = origins[resource][id]
					goods[resource] = int(goods.get(resource,0)) + amount
					reserved[resource] -= amount
					origins[resource].erase(id)
					changed = true
			if changed: simulation.entity_registry().update_entity(building.entity_id,{"material_origins":origins,"reserved_materials":reserved},{},simulation.logical_tick,building.revision)
		var point := Vector2(_removed[id].point[0],_removed[id].point[1])
		for resource in goods: drop(StringName(resource),goods[resource],point,simulation.logical_tick)
	_removed.clear()
	flushing = false

func return_store(worker: GopalaEntitySnapshot, resource: StringName) -> int:
	var point := Vector2(worker.attributes.position_x,worker.attributes.position_z)
	for store in ordered_stores(resource,point):
		if not store_has_space(store.entity_id,resource): continue
		var target := Vector2(store.attributes.get(&"position_x",0.0),store.attributes.get(&"position_z",0.0))
		if not simulation._route_service.enabled or simulation._route_service.plan(point,target,&"BUILD").ok: return store.entity_id
	return 0

func position(id: int) -> Vector2:
	_cache_position(id)
	var point: Array = _positions.get(id,[0.0,0.0])
	return Vector2(point[0],point[1])

func refill_blueprint(blueprint: GopalaEntitySnapshot, worker: GopalaEntitySnapshot, tick: int) -> bool:
	var delta: Dictionary[StringName,int] = {}
	var reserved: Dictionary = blueprint.attributes.get("reserved_materials",{}).duplicate(true)
	var delivered: Dictionary = blueprint.attributes.get("delivered_materials",{})
	for resource in blueprint.attributes.get("required_materials",{}):
		var missing: int = int(blueprint.attributes.required_materials[resource]) - int(reserved.get(resource,0)) - int(delivered.get(resource,0))
		var available := mini(missing,simulation.resource_amount(StringName(resource)))
		if available > 0: delta[StringName(resource)] = -available
	if delta.is_empty(): return false
	var old_stocks := stocks.duplicate(true)
	var reservation := reserve_materials(delta,Vector2(worker.attributes.position_x,worker.attributes.position_z),Vector2(blueprint.attributes.position_x,blueprint.attributes.position_z))
	if not reservation.ok: return false
	var origins: Dictionary = blueprint.attributes.get("material_origins",{}).duplicate(true)
	for resource in reservation.origins:
		if not origins.has(resource): origins[resource] = {}
		for id in reservation.origins[resource]: origins[resource][id] = int(origins[resource].get(id,0)) + reservation.origins[resource][id]
		reserved[resource] = int(reserved.get(resource,0)) - int(delta[resource])
	var result := simulation.entity_registry().update_entity(blueprint.entity_id,{"material_origins":origins,"reserved_materials":reserved},{},tick,blueprint.revision)
	if result.status != GopalaEntityOperationResult.Status.APPLIED:
		stocks = old_stocks
		var refund: Dictionary[StringName,int] = {}
		for resource in delta: refund[resource] = -int(delta[resource])
		simulation._ledger.apply_authorized_transaction(refund)
		return false
	return true
