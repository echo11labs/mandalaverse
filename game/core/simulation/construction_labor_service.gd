class_name GopalaConstructionLaborService
extends Node

var _registry: GopalaEntityRegistry
var _queries: GopalaEntityQueryService
var _villagers: GopalaVillagerService
var _ledger: GopalaResourceLedger
var _coordinate_service: GopalaSettlementCoordinateService

var storage: GopalaStorageService
var _tasks: Dictionary = {}
var _next_task_id: int = 1

func configure(queries: GopalaEntityQueryService, registry: GopalaEntityRegistry, ledger: GopalaResourceLedger, villagers: GopalaVillagerService, coord: GopalaSettlementCoordinateService) -> void:
	_queries = queries
	_registry = registry
	_ledger = ledger
	_villagers = villagers
	_coordinate_service = coord

func _camp_position() -> Vector2:
	if _coordinate_service != null and _coordinate_service._config != null:
		return _coordinate_service._config.origin_xz
	return Vector2.ZERO

func _blueprint_position(blueprint: GopalaEntitySnapshot) -> Vector2:
	if blueprint.attributes.has("position_x") and blueprint.attributes.has("position_z"):
		return Vector2(blueprint.attributes["position_x"], blueprint.attributes["position_z"])
	if _coordinate_service != null:
		var cell = Vector2i(blueprint.attributes.get("anchor_cell_x", 0), blueprint.attributes.get("anchor_cell_y", 0))
		return _coordinate_service.settlement_cell_to_world_xz(cell)
	return Vector2(blueprint.attributes.get("anchor_cell_x", 0), blueprint.attributes.get("anchor_cell_y", 0))

func handle_request_assign_builder(command: GopalaSimulationCommand, current_tick: int) -> GopalaCommandResult:
	var builder_id: int = command.payload.get("villager_id", -1)
	var blueprint_id: int = command.payload.get("blueprint_id", command.payload.get("blueprint_entity_id", -1))
	
	var builder = _queries.snapshot(builder_id)
	var blueprint = _queries.snapshot(blueprint_id)
	
	if builder == null or builder.kind != &"villager":
		return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_PAYLOAD", command.submitted_tick)
		
	if blueprint == null or blueprint.kind != &"building" or blueprint.attributes.get("construction_state", "") == "COMPLETED" or blueprint.attributes.get("construction_state", "") == "CANCELLED":
		return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_PAYLOAD", command.submitted_tick)
		
	var active_task_id = builder.attributes.get("active_task_id", 0)
	var carried = builder.attributes.get("carried_amount", 0)
	if active_task_id != 0 or carried > 0 or builder.attributes.get(&"task_kind") == &"NEED":
		return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_PAYLOAD", command.submitted_tick)
		
	var current_assigned = blueprint.attributes.get("assigned_builder_id", 0)
	if current_assigned != 0:
		return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_PAYLOAD", command.submitted_tick)

	var required_materials = blueprint.attributes.get("required_materials", {})
	var reserved_materials = GopalaPlainData.copy_dictionary(blueprint.attributes.get("reserved_materials", {}))
	var delivered_materials = blueprint.attributes.get("delivered_materials", {})
	
	var transaction: Dictionary[StringName, int] = {}
	for mat in required_materials:
		if StringName(mat) != &"timber" and (storage == null or not storage.located):
			continue
		var req = int(required_materials[mat])
		var del = int(delivered_materials.get(mat, 0))
		var res = int(reserved_materials.get(mat, 0))
		
		var needed = req - del - res
		if needed > 0:
			var available = _ledger.amount(StringName(mat))
			var to_reserve = mini(needed, available)
			if to_reserve > 0:
				transaction[StringName(mat)] = -to_reserve
				reserved_materials[mat] = res + to_reserve
				
	var bp_patch: Dictionary = {"assigned_builder_id": builder_id}
	var old_stocks: Dictionary = storage.stocks.duplicate(true) if storage != null else {}
	if not transaction.is_empty():
		var applied := false
		if storage != null and storage.located:
			var reservation := storage.reserve_materials(transaction,Vector2(builder.attributes.position_x,builder.attributes.position_z),_blueprint_position(blueprint))
			applied = reservation.ok
			if applied:
				var origins: Dictionary = blueprint.attributes.get("material_origins",{}).duplicate(true)
				for resource in reservation.origins:
					if not origins.has(resource): origins[resource] = {}
					for id in reservation.origins[resource]: origins[resource][id] = int(origins[resource].get(id,0)) + reservation.origins[resource][id]
				bp_patch["material_origins"] = origins
		else: applied = _ledger.apply_authorized_transaction(transaction)
		if not applied:
			return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_PAYLOAD", command.submitted_tick)
		bp_patch["reserved_materials"] = reserved_materials
			
	var bp_res = _registry.update_entity(blueprint_id, bp_patch, {}, current_tick, blueprint.revision)
	if bp_res.status != GopalaEntityOperationResult.Status.APPLIED:
		# Rollback transaction if entity update failed
		if not transaction.is_empty():
			var rollback: Dictionary[StringName, int] = {}
			for k in transaction:
				rollback[k] = -transaction[k]
			_ledger.apply_authorized_transaction(rollback)
			if storage != null and storage.located: storage.stocks = old_stocks
		return _result(command, GopalaCommandResult.Status.REJECTED, &"INVALID_PAYLOAD", command.submitted_tick)
	
	var task_id = _next_task_id
	_next_task_id += 1
	
	_tasks[builder_id] = {
		"task_id": task_id,
		"blueprint_id": blueprint_id,
		"state": &"EVALUATING"
	}
	
	_registry.update_entity(builder_id, {
		&"active_task_id": task_id,
		&"task_kind": &"BUILD",
		&"task_state": &"EVALUATING"
	}, {}, current_tick, builder.revision)
	
	return _result(command, GopalaCommandResult.Status.APPLIED, &"SUCCESS", command.submitted_tick, {"changed": true})

func _result(command: GopalaSimulationCommand, status: GopalaCommandResult.Status, reason: StringName, logical_tick: int, details: Dictionary = {}) -> GopalaCommandResult:
	return GopalaCommandResult.new(command.command_id, status, reason, logical_tick, details)

func tick(logical_tick: int) -> void:
	for villager_id in _tasks.keys():
		var task = _tasks.get(villager_id)
		if task == null:
			continue
		var villager = _queries.snapshot(villager_id)
		
		if villager == null:
			_fail_task(villager_id, &"VILLAGER_REMOVED", logical_tick)
			continue
			
		_tick_build_task(villager_id, task, villager, logical_tick)

func _update_villager_task_state(villager_id: int, state: StringName, logical_tick: int, revision: int = 0) -> void:
	_registry.update_entity(villager_id, {&"task_state": state}, {}, logical_tick, revision)

func _fail_task(villager_id: int, reason: StringName, logical_tick: int) -> void:
	var task = _tasks.get(villager_id)
	if task == null: return
	
	task.state = &"CANCELLED" if reason == &"CANCELLED" else &"FAILED"
	
	if task.has("blueprint_id"):
		var bp = _queries.snapshot(task.blueprint_id)
		if bp != null:
			_registry.update_entity(task.blueprint_id, {"assigned_builder_id": 0}, {}, logical_tick, bp.revision)
			
	var villager = _queries.snapshot(villager_id)
	if villager != null:
		var carried = villager.attributes.get(&"carried_amount", 0)
		if carried > 0:
			task.state = &"RETURNING_TO_CAMP"
			task.arrived_at_camp = false
			_update_villager_task_state(villager_id, &"RETURNING_TO_CAMP", logical_tick, villager.revision)
			if storage != null and storage.located:
				task.return_store_id = storage.return_store(villager,StringName(villager.attributes.get("carried_resource_id","")))
				if task.return_store_id == 0:
					_villagers.stop(villager_id,&"NO_STORAGE")
					_update_villager_task_state(villager_id,&"NO_STORAGE",logical_tick)
					return
			_villagers.set_destination(villager_id, _pickup_position(task), &"BUILD", task.task_id)
			return
		else:
			_villagers.stop(villager_id, reason)
			var v_refreshed = _queries.snapshot(villager_id)
			_registry.update_entity(villager_id, {
				&"active_task_id": 0,
				&"task_kind": &"NONE",
				&"task_state": &"NONE"
			}, {}, logical_tick, v_refreshed.revision if v_refreshed else villager.revision)
	
	_tasks.erase(villager_id)

func cancel_task(villager_id: int, logical_tick: int) -> void:
	if not _tasks.has(villager_id): return
	_fail_task(villager_id, &"CANCELLED", logical_tick)

func reset() -> void:
	_tasks.clear()
	_next_task_id = 1

func _tick_build_task(villager_id: int, task: Dictionary, villager: GopalaEntitySnapshot, logical_tick: int) -> void:
	if storage != null and storage.located and task.state in [&"MOVING_TO_CAMP",&"PICKING_UP_MATERIAL"] and _queries.snapshot(task.get("pickup_store_id",0)) == null:
		task.state = &"EVALUATING"
		_villagers.stop(villager_id,&"STOCK_REMOVED")
		return
	if storage != null and storage.located and task.state == &"RETURNING_TO_CAMP":
		var store_id: int = task.get("return_store_id",0)
		var mat: StringName = villager.attributes.get(&"carried_resource_id",&"")
		if _queries.snapshot(store_id) == null or not storage.store_has_space(store_id,mat):
			store_id = storage.return_store(villager,mat)
			task.return_store_id = store_id
			task.arrived_at_camp = false
			if store_id == 0:
				_villagers.stop(villager_id,&"NO_STORAGE")
				_update_villager_task_state(villager_id,&"NO_STORAGE",logical_tick)
				return
			_villagers.set_destination(villager_id,storage.position(store_id),&"BUILD",task.task_id)
			return
	if str(villager.attributes.get(&"movement_state", "")) == "BLOCKED":
		var route_revision: int = _villagers._navigation.revision
		if int(task.get("blocked_revision", -1)) != route_revision:
			task.blocked_revision = route_revision
			var target := _pickup_position(task)
			if task.state in [&"MOVING_TO_BLUEPRINT", &"DELIVERING_MATERIAL"]:
				var blocked_blueprint = _queries.snapshot(task.blueprint_id)
				if blocked_blueprint == null:
					_fail_task(villager_id, &"BLUEPRINT_REMOVED", logical_tick)
					return
				target = _blueprint_position(blocked_blueprint)
			_villagers.set_destination(villager_id,target,&"BUILD",task.task_id)
			_update_villager_task_state(villager_id, &"BLOCKED_ROUTE" if not _villagers.last_failure.is_empty() else task.state, logical_tick)
		return
	# 1. First priority: if villager is returning to camp with refunded materials
	if task.state == &"RETURNING_TO_CAMP":
		if not task.get("arrived_at_camp", false):
			if _villagers.has_arrived(villager_id):
				task.arrived_at_camp = true
			return
			
		var mat = villager.attributes.get("carried_resource_id", "")
		var amount = villager.attributes.get("carried_amount", 0)
		if str(mat) != "" and amount > 0:
			if storage != null and storage.located:
				if not storage.credit(task.return_store_id,StringName(mat),amount): return
			else: _ledger.apply_authorized_transaction({StringName(mat): amount})
		_registry.update_entity(villager_id, {
			&"carried_resource_id": &"",
			&"carried_amount": 0,
			&"task_state": &"NONE",
			&"active_task_id": 0,
			&"task_kind": &"NONE"
		}, {}, logical_tick, villager.revision)
		_tasks.erase(villager_id)
		return

	# 2. Check blueprint validity
	var blueprint = _queries.snapshot(task.blueprint_id)
	if blueprint == null or blueprint.attributes.get("construction_state", "") == "CANCELLED":
		_fail_task(villager_id, &"BLUEPRINT_REMOVED", logical_tick)
		return
		
	var reserved = blueprint.attributes.get("reserved_materials", {})
	var delivered = blueprint.attributes.get("delivered_materials", {})
	var required = blueprint.attributes.get("required_materials", {})
	
	var needs_material = false
	var needed_mat: StringName = &""
	for mat in reserved:
		if reserved[mat] > 0:
			needs_material = true
			needed_mat = StringName(mat)
			break
			
	var current_construction_state = blueprint.attributes.get("construction_state", "BLUEPRINT")
	
	match task.state:
		&"EVALUATING":
			if storage != null and storage.located and not needs_material:
				var missing := false
				for resource in required:
					if int(delivered.get(resource,0)) < int(required[resource]): missing = true
				if missing:
					storage.refill_blueprint(blueprint,villager,logical_tick)
					_update_villager_task_state(villager_id,&"WAITING_FOR_MATERIALS",logical_tick)
					return
			if needs_material:
				if current_construction_state == "BLUEPRINT":
					_registry.update_entity(blueprint.entity_id, {"construction_state": "WAITING_FOR_MATERIALS"}, {}, logical_tick, blueprint.revision)
				task.state = &"MOVING_TO_CAMP"
				if storage != null and storage.located:
					task.pickup_store_id = storage.pickup_store(blueprint,needed_mat,Vector2(villager.attributes.position_x,villager.attributes.position_z))
					if task.pickup_store_id == 0:
						task.state = &"EVALUATING"
						_update_villager_task_state(villager_id,&"NO_ACCESSIBLE_STOCK",logical_tick)
						return
				task.target_material = needed_mat
				_update_villager_task_state(villager_id, &"MOVING_TO_CAMP", logical_tick, villager.revision)
				_villagers.set_destination(villager_id, _pickup_position(task), &"BUILD", task.task_id)
			else:
				var work_completed = blueprint.attributes.get("work_completed", 0)
				var work_required = blueprint.attributes.get("work_required", 100)
				if work_completed < work_required:
					_registry.update_entity(blueprint.entity_id, {"construction_state": "READY_FOR_LABOR"}, {}, logical_tick, blueprint.revision)
					task.state = &"MOVING_TO_BLUEPRINT"
					_update_villager_task_state(villager_id, &"MOVING_TO_BLUEPRINT", logical_tick, villager.revision)
					_villagers.set_destination(villager_id, _blueprint_position(blueprint), &"BUILD", task.task_id)
				
		&"MOVING_TO_CAMP":
			if _villagers.has_arrived(villager_id):
				task.state = &"PICKING_UP_MATERIAL"
				_update_villager_task_state(villager_id, &"PICKING_UP_MATERIAL", logical_tick, villager.revision)
				
		&"PICKING_UP_MATERIAL":
			var mat = task.target_material
			if reserved.get(mat, 0) > 0:
				var new_reserved = GopalaPlainData.copy_dictionary(reserved)
				new_reserved[mat] -= 1
				_registry.update_entity(blueprint.entity_id, {
					"reserved_materials": new_reserved,
					"construction_state": "DELIVERING_MATERIALS",
					"material_origins": storage.consume_origin(blueprint,StringName(mat),task.pickup_store_id) if storage != null and storage.located else blueprint.attributes.get("material_origins",{})
				}, {}, logical_tick, blueprint.revision)
				
				var v_res = _registry.update_entity(villager_id, {
					&"carried_resource_id": mat,
					&"carried_amount": 1,
					&"task_state": &"DELIVERING_MATERIAL"
				}, {}, logical_tick, villager.revision)
				if v_res.status != GopalaEntityOperationResult.Status.APPLIED:
					print("V_RES PICKUP FAILED: ", v_res.status, " reason: ", v_res.failure_reason, " rev: ", villager.revision)
				
				task.state = &"DELIVERING_MATERIAL"
				_villagers.set_destination(villager_id, _blueprint_position(blueprint), &"BUILD", task.task_id)
			else:
				task.state = &"EVALUATING"
				
		&"DELIVERING_MATERIAL":
			if _villagers.has_arrived(villager_id):
				var mat = villager.attributes.get("carried_resource_id", "")
				if str(mat) != "":
					var new_delivered = GopalaPlainData.copy_dictionary(delivered)
					new_delivered[mat] = new_delivered.get(mat, 0) + 1
					_registry.update_entity(blueprint.entity_id, {"delivered_materials": new_delivered}, {}, logical_tick, blueprint.revision)
					
					_registry.update_entity(villager_id, {
						&"carried_resource_id": &"",
						&"carried_amount": 0,
						&"task_state": &"EVALUATING"
					}, {}, logical_tick, villager.revision)
				task.state = &"EVALUATING"
				
		&"MOVING_TO_BLUEPRINT":
			if _villagers.has_arrived(villager_id):
				task.state = &"PERFORMING_LABOR"
				_update_villager_task_state(villager_id, &"PERFORMING_LABOR", logical_tick, villager.revision)
				_registry.update_entity(blueprint.entity_id, {"construction_state": "UNDER_CONSTRUCTION"}, {}, logical_tick, blueprint.revision)
				
		&"PERFORMING_LABOR":
			var work_completed = blueprint.attributes.get("work_completed", 0) + 1
			var work_required = blueprint.attributes.get("work_required", 100)
			
			if work_completed < work_required:
				_registry.update_entity(blueprint.entity_id, {"work_completed": work_completed}, {}, logical_tick, blueprint.revision)
			else:
				_registry.update_entity(blueprint.entity_id, {
					"construction_state": "COMPLETED",
					"work_completed": work_required,
					"completed_tick": logical_tick,
					"assigned_builder_id": 0
				}, {}, logical_tick, blueprint.revision)
				
				_registry.update_entity(villager_id, {
					&"active_task_id": 0,
					&"task_kind": &"NONE",
					&"task_state": &"NONE"
				}, {}, logical_tick, villager.revision)
				
				task.state = &"COMPLETED"
				_tasks.erase(villager_id)

func _pickup_position(task: Dictionary) -> Vector2:
	if storage != null and storage.located:
		return storage.position(task.get("return_store_id",0) if task.state == &"RETURNING_TO_CAMP" else task.get("pickup_store_id",0))
	return _camp_position()
