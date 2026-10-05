class_name GopalaGatherDeliveryService
extends Node

var _queries: GopalaEntityQueryService
var _registry: GopalaEntityRegistry
var _ledger: GopalaResourceLedger
var _villagers: GopalaVillagerService
var _coordinates: GopalaSettlementCoordinateService

var _tasks := {}
var _next_task_id := 1

func configure(queries: GopalaEntityQueryService, registry: GopalaEntityRegistry, ledger: GopalaResourceLedger, villagers: GopalaVillagerService, coordinates: GopalaSettlementCoordinateService) -> void:
	_queries = queries
	_registry = registry
	_ledger = ledger
	_villagers = villagers
	_coordinates = coordinates

func handle_request_gather_timber(command: GopalaSimulationCommand, current_tick: int) -> GopalaCommandResult:
	var payload: Dictionary = command.payload
	if not payload.has("villager_id") or not payload.has("source_entity_id"):
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
	if source.kind != GopalaEntityKind.RESOURCE_SOURCE or source.attributes.get(&"resource_id", &"") != &"timber" or not source.attributes.get(&"gatherable", false):
		return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_SOURCE", current_tick)
	
	# Verify revision if provided
	if payload.has("source_revision") and payload["source_revision"] != source.revision:
		return _result(command, GopalaCommandResult.Status.REJECTED, &"STALE_SOURCE", current_tick)

	var dest_id: int = payload.get("destination_entity_id", 0)
	if dest_id == 0:
		# Resolve valid default drop-off
		var buildings = _queries.snapshots_by_kind(GopalaEntityKind.BUILDING).filter(func(b): return b.attributes.get(&"accepts_timber", false))
		if buildings.is_empty():
			return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_DESTINATION", current_tick)
		dest_id = buildings[0].entity_id
	else:
		if not _queries.has_entity(dest_id):
			return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_DESTINATION", current_tick)
		var dest = _queries.snapshot(dest_id)
		if dest.kind != GopalaEntityKind.BUILDING or not dest.attributes.get(&"accepts_timber", false):
			return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_DESTINATION", current_tick)

	var avail: int = source.attributes.get(&"available_amount", 0)
	if avail <= 0:
		return _result(command, GopalaCommandResult.Status.REJECTED, &"SOURCE_EXHAUSTED", current_tick)
	
	var active_task = villager.attributes.get(&"active_task_id", 0)
	var carried = villager.attributes.get(&"carried_amount", 0)
	if active_task != 0 or carried > 0:
		if carried > 0:
			return _result(command, GopalaCommandResult.Status.REJECTED, &"VILLAGER_ALREADY_CARRYING", current_tick)
		return _result(command, GopalaCommandResult.Status.REJECTED, &"VILLAGER_BUSY", current_tick)

	var pos_x = source.attributes.get(&"position_x")
	var pos_z = source.attributes.get(&"position_z")
	if typeof(pos_x) != TYPE_FLOAT and typeof(pos_x) != TYPE_INT:
		return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_POS", current_tick)

	var reserved: int = source.attributes.get(&"reserved_amount", 0)

	# Apply reservation
	var res1 = _registry.update_entity(source_id, {
		&"reserved_amount": reserved + 1,
		&"available_amount": avail - 1
	}, {}, source.revision)
	if res1.status != GopalaEntityOperationResult.Status.APPLIED:
		return _result(command, GopalaCommandResult.Status.REJECTED, &"STALE_SOURCE", current_tick)

	var task_id = _next_task_id
	_next_task_id += 1
	
	var res2 = _registry.update_entity(villager_id, {
		&"active_task_id": task_id,
		&"task_kind": &"GATHER",
		&"task_state": &"MOVING_TO_SOURCE"
	}, {}, villager.revision)
	if res2.status != GopalaEntityOperationResult.Status.APPLIED:
		# Rollback source reservation
		_release_reservation(source_id)
		return _result(command, GopalaCommandResult.Status.REJECTED, &"STALE_VILLAGER", current_tick)
		
	var move_result = _villagers.set_destination(villager_id, Vector2(float(pos_x), float(pos_z)), &"GATHER", task_id)
	if not move_result:
		# Rollback villager
		_registry.update_entity(villager_id, {
			&"active_task_id": 0,
			&"task_kind": &"NONE",
			&"task_state": &"NONE"
		}, {}, res2.revision)
		# Rollback source reservation
		_release_reservation(source_id)
		return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_MOVEMENT", current_tick)

	_tasks[villager_id] = {
		"task_id": task_id,
		"villager_id": villager_id,
		"source_id": source_id,
		"destination_id": dest_id,
		"resource_id": &"timber",
		"amount": 1,
		"state": &"MOVING_TO_SOURCE",
		"created_tick": current_tick,
		"updated_tick": current_tick,
		"failure_reason": &""
	}

	return _result(command, GopalaCommandResult.Status.APPLIED, GopalaCommandResult.REASON_APPLIED, current_tick, {"changed": true})

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
				_release_reservation(task.source_id)
			elif task.state == &"MOVING_TO_DROPOFF" or task.state == &"DELIVERING":
				var source = _queries.snapshot(task.source_id)
				if source != null:
					# Return carried resource back to source if available
					var avail: int = source.attributes.get(&"available_amount", 0)
					_registry.update_entity(task.source_id, {
						&"available_amount": avail + 1,
						&"exhausted": false
					}, {}, source.revision)
				else:
					# Source is gone, we drop the item. For this block, we instantiate a dropped resource.
					var dropped_pos_x = 0.0 # Should get from last known pos
					var dropped_pos_z = 0.0
					_registry.create_entity(GopalaEntityKind.RESOURCE_SOURCE, {
						&"resource_id": &"timber",
						&"available_amount": 1,
						&"reserved_amount": 0,
						&"gatherable": true,
						&"position_x": dropped_pos_x,
						&"position_z": dropped_pos_z
					})
			_tasks.erase(villager_id)
			continue
		
		match task.state:
			&"MOVING_TO_SOURCE":
				var source = _queries.snapshot(task.source_id)
				if source == null:
					_fail_task(villager_id, &"SOURCE_REMOVED", logical_tick)
					continue
				if _villagers.has_arrived(villager_id):
					task.state = &"PICKING_UP"
					_update_villager_task_state(villager_id, &"PICKING_UP", villager.revision)
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
				}, {}, source.revision)
				
				_registry.update_entity(villager_id, {
					&"carried_resource_id": &"timber",
					&"carried_amount": 1,
					&"task_state": &"MOVING_TO_DROPOFF"
				}, {}, villager.revision)
				
				task.state = &"MOVING_TO_DROPOFF"
				
				var dest = _queries.snapshot(task.destination_id)
				if dest != null:
					_villagers.set_destination(villager_id, Vector2(dest.attributes.get(&"position_x", 0.0), dest.attributes.get(&"position_z", 0.0)), &"DELIVER", task.task_id)
				else:
					_fail_task(villager_id, &"DESTINATION_REMOVED", logical_tick)

			&"MOVING_TO_DROPOFF":
				if _villagers.has_arrived(villager_id):
					task.state = &"DELIVERING"
					_update_villager_task_state(villager_id, &"DELIVERING", villager.revision) # re-fetch villager for latest revision if needed, but we don't strictly need it if we aren't mutating more
			&"DELIVERING":
				var dest = _queries.snapshot(task.destination_id)
				if dest == null:
					_fail_task(villager_id, &"DESTINATION_REMOVED", logical_tick)
					continue
				
				# Deliver
				villager = _queries.snapshot(villager_id) # fetch latest
				
				_ledger.apply_authorized_transaction({&"timber": 1})
				
				_registry.update_entity(villager_id, {
					&"carried_resource_id": &"",
					&"carried_amount": 0,
					&"active_task_id": 0,
					&"task_kind": &"NONE",
					&"task_state": &"NONE"
				}, {}, villager.revision)
				
				task.state = &"COMPLETED"
				_tasks.erase(villager_id)

func _update_villager_task_state(villager_id: int, state: StringName, revision: int) -> void:
	# Fetch latest revision to prevent stale update rejection
	var villager = _queries.snapshot(villager_id)
	if villager != null:
		_registry.update_entity(villager_id, {&"task_state": state}, {}, villager.revision)

func _release_reservation(source_id: int) -> void:
	var source = _queries.snapshot(source_id)
	if source != null:
		var reserved: int = source.attributes.get(&"reserved_amount", 0)
		var avail: int = source.attributes.get(&"available_amount", 0)
		_registry.update_entity(source_id, {
			&"reserved_amount": max(0, reserved - 1),
			&"available_amount": avail + 1,
			&"exhausted": false
		}, {}, source.revision)

func _fail_task(villager_id: int, reason: StringName, logical_tick: int) -> void:
	var task = _tasks[villager_id]
	var previous_state: StringName = task.state
	
	task.state = &"CANCELLED" if reason == &"CANCELLED" else &"FAILED"
	task.failure_reason = reason
	task.updated_tick = logical_tick
	
	if previous_state == &"MOVING_TO_SOURCE" or previous_state == &"PICKING_UP":
		_release_reservation(task.source_id)
		
	var villager = _queries.snapshot(villager_id)
	if villager != null:
		_villagers.stop(villager_id, reason)
		var carried = villager.attributes.get(&"carried_amount", 0)
		if carried > 0:
			_update_villager_task_state(villager_id, &"FAILED_DELIVERY", villager.revision)
		else:
			_registry.update_entity(villager_id, {
				&"active_task_id": 0,
				&"task_kind": &"NONE",
				&"task_state": &"NONE"
			}, {}, villager.revision)
	
	_tasks.erase(villager_id)

func cancel_task(villager_id: int, logical_tick: int) -> void:
	if not _tasks.has(villager_id): return
	_fail_task(villager_id, &"CANCELLED", logical_tick)

func reset() -> void:
	_tasks.clear()
	_next_task_id = 1
