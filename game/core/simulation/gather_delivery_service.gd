class_name GopalaGatherDeliveryService
extends Node

var _queries: GopalaEntityQueryService
var _registry: GopalaEntityRegistry
var _ledger: GopalaResourceLedger
var _villagers: GopalaVillagerService
var _coordinates: GopalaSettlementCoordinateService

var storage: GopalaStorageService
var _tasks := {}
var _next_task_id := 1

func configure(queries: GopalaEntityQueryService, registry: GopalaEntityRegistry, ledger: GopalaResourceLedger, villagers: GopalaVillagerService, coordinates: GopalaSettlementCoordinateService) -> void:
	_queries = queries
	_registry = registry
	_ledger = ledger
	_villagers = villagers
	_coordinates = coordinates

func handle_request_gather_timber(command: GopalaSimulationCommand, current_tick: int) -> GopalaCommandResult:
	var resource_id: StringName = &"stone" if command.command_type == GopalaSimulationCommand.REQUEST_GATHER_STONE else &"timber"
	if command.command_type == GopalaSimulationCommand.REQUEST_GATHER_RESOURCE:
		if typeof(command.payload.get("resource_id")) != TYPE_STRING_NAME or not command.payload.resource_id in GopalaSimulationCommand.COLLECTIBLE_RESOURCES:
			return _result(command,GopalaCommandResult.Status.REJECTED,&"INVALID_RESOURCE",current_tick)
		resource_id = command.payload.resource_id
	var acceptance_key := StringName("accepts_" + str(resource_id))
	var payload: Dictionary = command.payload
	if typeof(payload.get("repeat", false)) != TYPE_BOOL:
		return _result(command, GopalaCommandResult.Status.REJECTED, GopalaCommandResult.REASON_INVALID_PAYLOAD, current_tick)
	if typeof(payload.get("villager_id")) != TYPE_INT or typeof(payload.get("source_entity_id")) != TYPE_INT or typeof(payload.get("destination_entity_id", 0)) != TYPE_INT:
		return _result(command, GopalaCommandResult.Status.REJECTED, GopalaCommandResult.REASON_INVALID_PAYLOAD, current_tick)
	var villager_id: int = payload["villager_id"]
	var source_id: int = payload["source_entity_id"]
	
	if _tasks.has(villager_id):
		return _result(command, GopalaCommandResult.Status.REJECTED, &"DUPLICATE_REQUEST", current_tick)

	if not _queries.has_entity(villager_id):
		return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_VILLAGER", current_tick)
	var villager = _queries.snapshot(villager_id)
	if villager.kind != GopalaEntityKind.VILLAGER:
		return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_VILLAGER", current_tick)
	
	if not _queries.has_entity(source_id):
		return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_SOURCE", current_tick)
	var source = _queries.snapshot(source_id)
	if source.kind != GopalaEntityKind.RESOURCE_SOURCE or source.attributes.get(&"resource_id", &"") != resource_id or not source.attributes.get(&"gatherable", false):
		return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_SOURCE", current_tick)
	
	# Verify revision if provided
	if payload.has("source_revision") and payload["source_revision"] != source.revision:
		return _result(command, GopalaCommandResult.Status.REJECTED, &"STALE_SOURCE", current_tick)

	if storage != null and not storage.has_space(resource_id):
		return _result(command,GopalaCommandResult.Status.REJECTED,&"STORAGE_FULL",current_tick)
	var dest_id: int = payload.get("destination_entity_id",0)
	var destinations: Array = storage.ordered_stores(resource_id,Vector2(source.attributes.get(&"position_x",0.0),source.attributes.get(&"position_z",0.0))) if storage != null else _queries.snapshots_by_kind(GopalaEntityKind.BUILDING).filter(func(b): return b.attributes.get(acceptance_key,false))
	if dest_id != 0:
		destinations = destinations.filter(func(b): return b.entity_id == dest_id)
	if destinations.is_empty(): return _result(command,GopalaCommandResult.Status.REJECTED,&"INVALID_DESTINATION",current_tick)
	var worker_position := Vector2(villager.attributes.get(&"position_x",0.0),villager.attributes.get(&"position_z",0.0))
	var target_position := Vector2(source.attributes.get(&"position_x",0.0),source.attributes.get(&"position_z",0.0))
	dest_id = 0
	for destination in destinations:
		var point := Vector2(destination.attributes.get(&"position_x",0.0),destination.attributes.get(&"position_z",0.0))
		if _villagers._navigation != null and _villagers._navigation.enabled:
			if not _villagers._navigation.plan(worker_position,target_position,&"GATHER").ok or not _villagers._navigation.plan(target_position,point,&"DELIVER").ok: continue
		if storage != null and not storage.store_has_space(destination.entity_id,resource_id): continue
		dest_id = destination.entity_id
		break
	if dest_id == 0: return _result(command,GopalaCommandResult.Status.REJECTED,&"NO_ROUTE",current_tick)

	var avail: int = source.attributes.get(&"available_amount", 0)
	if avail <= 0:
		return _result(command, GopalaCommandResult.Status.REJECTED, &"SOURCE_EXHAUSTED", current_tick)
	
	var active_task = villager.attributes.get(&"active_task_id", 0)
	var carried = villager.attributes.get(&"carried_amount", 0)
	if active_task != 0 or carried > 0 or villager.attributes.get(&"task_kind") == &"NEED":
		if carried > 0:
			return _result(command, GopalaCommandResult.Status.REJECTED, &"VILLAGER_ALREADY_CARRYING", current_tick)
		return _result(command, GopalaCommandResult.Status.REJECTED, &"VILLAGER_BUSY", current_tick)

	var pos_x = source.attributes.get(&"position_x")
	var pos_z = source.attributes.get(&"position_z")
	if not (typeof(pos_x) in [TYPE_FLOAT, TYPE_INT]) or not (typeof(pos_z) in [TYPE_FLOAT, TYPE_INT]):
		return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_POS", current_tick)

	var reserved: int = source.attributes.get(&"reserved_amount", 0)

	# Apply reservation
	var res1 = _registry.update_entity(source_id, {
		&"reserved_amount": reserved + 1,
		&"available_amount": avail - 1
	}, {}, current_tick, source.revision)
	if res1.status != GopalaEntityOperationResult.Status.APPLIED:
		return _result(command, GopalaCommandResult.Status.REJECTED, &"STALE_SOURCE", current_tick)

	var task_id = _next_task_id
	_next_task_id += 1
	
	var res2 = _registry.update_entity(villager_id, {
		&"active_task_id": task_id,
		&"task_kind": &"GATHER",
		&"task_state": &"MOVING_TO_SOURCE"
	}, {}, current_tick, villager.revision)
	if res2.status != GopalaEntityOperationResult.Status.APPLIED:
		# Rollback source reservation
		_release_reservation(source_id, current_tick)
		return _result(command, GopalaCommandResult.Status.REJECTED, &"STALE_VILLAGER", current_tick)
		
	var move_result = _villagers.set_destination(villager_id, Vector2(float(pos_x), float(pos_z)), &"GATHER", task_id)
	if not move_result:
		# Rollback using the revision after the route failure state was published.
		_villagers.stop(villager_id, _villagers.last_failure)
		var refreshed := _queries.snapshot(villager_id)
		_registry.update_entity(villager_id, {
			&"active_task_id": 0,
			&"task_kind": &"NONE",
			&"task_state": &"NONE"
		}, {}, current_tick, refreshed.revision)
		# Rollback source reservation
		_release_reservation(source_id, current_tick)
		return _result(command, GopalaCommandResult.Status.REJECTED, _villagers.last_failure if _villagers.last_failure != &"" else &"INVALID_MOVEMENT", current_tick)

	_tasks[villager_id] = {
		"task_id": task_id,
		"villager_id": villager_id,
		"source_id": source_id,
		"destination_id": dest_id,
		"resource_id": resource_id,
		"amount": 1,
		"repeat": payload.get("repeat", false),
		"state": &"MOVING_TO_SOURCE",
		"created_tick": current_tick,
		"updated_tick": current_tick,
		"failure_reason": &""
	}

	return _result(command, GopalaCommandResult.Status.APPLIED, GopalaCommandResult.REASON_APPLIED, current_tick, {"changed": true})

func handle_stop_gathering(command: GopalaSimulationCommand, logical_tick: int) -> GopalaCommandResult:
	if typeof(command.payload.get("villager_id")) != TYPE_INT:
		return _result(command, GopalaCommandResult.Status.REJECTED, GopalaCommandResult.REASON_INVALID_PAYLOAD, logical_tick)
	var villager_id: int = command.payload.villager_id
	if not _tasks.has(villager_id):
		return _result(command, GopalaCommandResult.Status.REJECTED, &"NO_GATHER_TASK", logical_tick)
	var task: Dictionary = _tasks[villager_id]
	if task.state in [&"MOVING_TO_SOURCE", &"PICKING_UP"]:
		cancel_task(villager_id, logical_tick)
	else:
		# Finish delivery of the existing load, then stop; never discard carried goods.
		task.repeat = false
	return _result(command, GopalaCommandResult.Status.APPLIED, GopalaCommandResult.REASON_APPLIED, logical_tick, {"changed": true})

func _result(command: GopalaSimulationCommand, status: GopalaCommandResult.Status, reason: StringName, current_tick: int, details: Dictionary = {}) -> GopalaCommandResult:
	return GopalaCommandResult.new(command.command_id, status, reason, current_tick, details)

func tick(logical_tick: int) -> void:
	var keys = _tasks.keys()
	for villager_id in keys:
		var task = _tasks[villager_id]
		if task.state == &"COMPLETED" or task.state == &"FAILED" or task.state == &"CANCELLED":
			continue

		var villager = _queries.snapshot(villager_id)
		if villager == null:
			# Villager missing
			if task.state == &"MOVING_TO_SOURCE" or task.state == &"PICKING_UP":
				_release_reservation(task.source_id, logical_tick)
			elif task.state == &"MOVING_TO_DROPOFF" or task.state == &"DELIVERING":
				var source = _queries.snapshot(task.source_id)
				if source != null:
					# Return carried resource back to source if available
					var avail: int = source.attributes.get(&"available_amount", 0)
					_registry.update_entity(task.source_id, {
						&"available_amount": avail + 1,
						&"exhausted": false
					}, {}, logical_tick, source.revision)
				else:
					# Source is gone, we drop the item. For this block, we instantiate a dropped resource.
					var dropped_pos_x = 0.0 # Should get from last known pos
					var dropped_pos_z = 0.0
					_registry.create_entity(GopalaEntityKind.RESOURCE_SOURCE, {
						&"resource_id": task.resource_id,
						&"available_amount": 1,
						&"reserved_amount": 0,
						&"gatherable": true,
						&"position_x": dropped_pos_x,
						&"position_z": dropped_pos_z
					})
			_tasks.erase(villager_id)
			continue
		
		if task.state in [&"MOVING_TO_DROPOFF",&"DELIVERING"] and (not _valid_destination(task.destination_id,task.resource_id) or villager.attributes.get(&"task_state") == &"NO_STORAGE"):
			_retarget(task,villager,logical_tick)
			continue
		if str(villager.attributes.get(&"movement_state", "")) == "BLOCKED":
			if task.state in [&"MOVING_TO_SOURCE", &"PICKING_UP"]:
				_fail_task(villager_id, StringName(villager.attributes.get(&"movement_failure", "NO_ROUTE")), logical_tick)
				continue
			# Carried goods stay with the worker while an obstructed drop-off is retried
			# only after occupancy changes. No remote or animation-driven delivery.
			var route_revision: int = _villagers._navigation.revision
			if int(task.get("blocked_revision", -1)) != route_revision:
				task.blocked_revision = route_revision
				var dropoff = _queries.snapshot(task.destination_id)
				if dropoff == null:
					_fail_task(villager_id, &"DESTINATION_REMOVED", logical_tick)
				else:
					_villagers.set_destination(villager_id, Vector2(dropoff.attributes.get(&"position_x",0.0),dropoff.attributes.get(&"position_z",0.0)), &"DELIVER", task.task_id)
					_update_villager_task_state(villager_id, &"BLOCKED_DELIVERY" if not _villagers.last_failure.is_empty() else &"MOVING_TO_DROPOFF", logical_tick)
			continue

		match task.state:
			&"MOVING_TO_SOURCE":
				var source = _queries.snapshot(task.source_id)
				if source == null:
					_fail_task(villager_id, &"SOURCE_REMOVED", logical_tick)
					continue
				if _villagers.has_arrived(villager_id):
					task.state = &"PICKING_UP"
					_update_villager_task_state(villager_id, &"PICKING_UP", logical_tick)
			&"PICKING_UP":
				var source = _queries.snapshot(task.source_id)
				if source == null:
					_fail_task(villager_id, &"SOURCE_REMOVED", logical_tick)
					continue
				
				var reserved: int = source.attributes.get(&"reserved_amount", 0)
				if reserved <= 0:
					_fail_task(villager_id, &"SOURCE_EXHAUSTED", logical_tick)
					continue
					
				# Atomically transfer from reserved to carried
				var avail: int = source.attributes.get(&"available_amount", 0)
				_registry.update_entity(task.source_id, {
					&"reserved_amount": reserved - 1,
					&"exhausted": avail == 0 and (reserved - 1) == 0
				}, {}, logical_tick, source.revision)
				
				_registry.update_entity(villager_id, {
					&"carried_resource_id": task.resource_id,
					&"carried_amount": 1,
					&"task_state": &"MOVING_TO_DROPOFF"
				}, {}, logical_tick, villager.revision)
				
				task.state = &"MOVING_TO_DROPOFF"
				
				var dest = _queries.snapshot(task.destination_id)
				if dest != null:
					_villagers.set_destination(villager_id, Vector2(dest.attributes.get(&"position_x", 0.0), dest.attributes.get(&"position_z", 0.0)), &"DELIVER", task.task_id)
				else:
					_fail_task(villager_id, &"DESTINATION_REMOVED", logical_tick)

			&"MOVING_TO_DROPOFF":
				if _villagers.has_arrived(villager_id):
					task.state = &"DELIVERING"
					_update_villager_task_state(villager_id, &"DELIVERING", logical_tick)
			&"DELIVERING":
				var dest = _queries.snapshot(task.destination_id)
				if dest == null or (storage != null and not storage.destinations(task.resource_id).any(func(b): return b.entity_id == task.destination_id)):
					_fail_task(villager_id, &"DESTINATION_REMOVED", logical_tick)
					continue
				
				if storage != null and not storage.store_has_space(task.destination_id,task.resource_id,villager_id):
					_update_villager_task_state(villager_id,&"WAITING_FOR_STORAGE",logical_tick)
					continue
				# Deliver
				villager = _queries.snapshot(villager_id) # fetch latest
				
				if not (storage.credit(task.destination_id,task.resource_id,1,false,villager_id) if storage != null else _ledger.apply_authorized_transaction({task.resource_id:1})):
					_fail_task(villager_id, &"STORAGE_REJECTED", logical_tick)
					continue
				
				_registry.update_entity(villager_id, {
					&"carried_resource_id": &"",
					&"carried_amount": 0,
					&"active_task_id": 0,
					&"task_kind": &"NONE",
					&"task_state": &"NONE"
				}, {}, logical_tick, villager.revision)
				
				task.state = &"COMPLETED"
				_tasks.erase(villager_id)
				if task.get("repeat", false):
					var source = _queries.snapshot(task.source_id)
					if source != null and source.attributes.get(&"available_amount", 0) > 0:
						var type := GopalaSimulationCommand.REQUEST_GATHER_RESOURCE
						var next := GopalaSimulationCommand._from_queue(0, type, logical_tick, {"villager_id": villager_id, "source_entity_id": task.source_id, "resource_id": task.resource_id, "destination_entity_id": task.destination_id, "repeat": true}, &"gather_continuation")
						handle_request_gather_timber(next, logical_tick)

func _update_villager_task_state(villager_id: int, state: StringName, current_tick: int) -> void:
	# Fetch latest revision to prevent stale update rejection
	var villager = _queries.snapshot(villager_id)
	if villager != null:
		_registry.update_entity(villager_id, {&"task_state": state}, {}, current_tick, villager.revision)

func _release_reservation(source_id: int, current_tick: int) -> void:
	var source = _queries.snapshot(source_id)
	if source != null:
		var reserved: int = source.attributes.get(&"reserved_amount", 0)
		var avail: int = source.attributes.get(&"available_amount", 0)
		if reserved <= 0:
			return
		_registry.update_entity(source_id, {
			&"reserved_amount": max(0, reserved - 1),
			&"available_amount": avail + 1,
			&"exhausted": false
		}, {}, current_tick, source.revision)

func _fail_task(villager_id: int, reason: StringName, logical_tick: int) -> void:
	var task = _tasks[villager_id]
	var previous_state: StringName = task.state
	
	task.state = &"CANCELLED" if reason == &"CANCELLED" else &"FAILED"
	task.failure_reason = reason
	task.updated_tick = logical_tick
	
	if previous_state == &"MOVING_TO_SOURCE" or previous_state == &"PICKING_UP":
		_release_reservation(task.source_id, logical_tick)
		
	var villager = _queries.snapshot(villager_id)
	if villager != null:
		_villagers.stop(villager_id, reason)
		villager = _queries.snapshot(villager_id)
		var carried = villager.attributes.get(&"carried_amount", 0)
		if carried > 0:
			_update_villager_task_state(villager_id, &"FAILED_DELIVERY", logical_tick)
		else:
			_registry.update_entity(villager_id, {
				&"active_task_id": 0,
				&"task_kind": &"NONE",
				&"task_state": &"NONE"
			}, {}, logical_tick, villager.revision)
	
	_tasks.erase(villager_id)

func cancel_task(villager_id: int, logical_tick: int) -> void:
	if not _tasks.has(villager_id): return
	_fail_task(villager_id, &"CANCELLED", logical_tick)

func reset() -> void:
	_tasks.clear()
	_next_task_id = 1

func _valid_destination(id: int, resource: StringName) -> bool:
	if storage != null: return storage.destinations(resource).any(func(b): return b.entity_id == id)
	var destination := _queries.snapshot(id)
	return destination != null and destination.attributes.get(StringName("accepts_" + str(resource)),false)

func _retarget(task: Dictionary, worker: GopalaEntitySnapshot, tick_value: int) -> void:
	if storage != null:
		for destination in storage.ordered_stores(task.resource_id,Vector2(worker.attributes.position_x,worker.attributes.position_z)):
			if not storage.store_has_space(destination.entity_id,task.resource_id,worker.entity_id): continue
			var point := Vector2(destination.attributes.get(&"position_x",0.0),destination.attributes.get(&"position_z",0.0))
			if _villagers.set_destination(worker.entity_id,point,&"DELIVER",task.task_id):
				task.destination_id = destination.entity_id
				task.state = &"MOVING_TO_DROPOFF"
				_update_villager_task_state(worker.entity_id,&"MOVING_TO_DROPOFF",tick_value)
				return
	_villagers.stop(worker.entity_id,&"NO_STORAGE")
	_update_villager_task_state(worker.entity_id,&"NO_STORAGE",tick_value)
