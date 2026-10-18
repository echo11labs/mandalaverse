class_name GopalaWorkerJobService
extends RefCounted

var simulation: GopalaSettlementSimulation
func _init(sim: GopalaSettlementSimulation): simulation = sim

func assign(command: GopalaSimulationCommand, tick: int) -> GopalaCommandResult:
	var payload := command.payload
	if typeof(payload.get("villager_id")) != TYPE_INT or typeof(payload.get("role")) != TYPE_STRING_NAME or (payload.role not in [&"NONE",&"herder"] and not payload.role in GopalaSimulationCommand.COLLECTIBLE_RESOURCES):
		return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.REJECTED,&"INVALID_ROLE",tick)
	var worker := simulation.entity_queries().snapshot(payload.villager_id)
	if worker == null or worker.kind != GopalaEntityKind.VILLAGER:
		return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.REJECTED,&"INVALID_VILLAGER",tick)
	if worker.attributes.get(&"task_kind") in [&"BUILD", &"FIELD"]:
		return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.REJECTED,&"VILLAGER_BUSY",tick)
	if simulation._field_service._tasks.has(worker.entity_id):
		simulation._field_service.cancel_worker_for_other_job(worker.entity_id,tick)
		worker = simulation.entity_queries().snapshot(worker.entity_id)
	if simulation.gather_delivery_service()._tasks.has(worker.entity_id):
		var stop := GopalaSimulationCommand._from_queue(command.command_id,GopalaSimulationCommand.REQUEST_STOP_GATHERING,tick,{"villager_id":worker.entity_id},&"role_change")
		simulation.gather_delivery_service().handle_stop_gathering(stop,tick)
	worker = simulation.entity_queries().snapshot(worker.entity_id)
	var result := simulation.entity_registry().update_entity(worker.entity_id,{&"work_role":payload.role,&"job_status":&"OFF" if payload.role == &"NONE" else &"READY"},{},tick,worker.revision)
	return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.APPLIED if result.status == GopalaEntityOperationResult.Status.APPLIED else GopalaCommandResult.Status.REJECTED,&"ROLE_ASSIGNED",tick,{"changed":true})

func tick(tick_value: int) -> void:
	for worker in simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER):
		var role: StringName = worker.attributes.get(&"work_role",&"NONE")
		if role in [&"NONE",&"herder"]: continue
		if not simulation._survival_service.ready_for_work(worker):
			var fallback: bool = (role == &"water" and worker.attributes.get(&"need_state") == &"NO_WATER") or (role in [&"wild_food",&"milk"] and worker.attributes.get(&"need_state") == &"NO_FOOD")
			if not fallback:
				_status(worker.entity_id,worker.attributes.get(&"need_state",&"NEEDS_SUPPLIES"),tick_value)
				continue
		if worker.attributes.get(&"active_task_id",0) > 0 or worker.attributes.get(&"carried_amount",0) > 0:
			_status(worker.entity_id,worker.attributes.get(&"task_state") if worker.attributes.get(&"task_state") in [&"NO_STORAGE",&"WAITING_FOR_STORAGE",&"BLOCKED_DELIVERY"] else &"WORKING",tick_value)
			continue
		if worker.attributes.get(&"movement_state") == &"MOVING": continue
		if not simulation._storage_service.has_space(role):
			_status(worker.entity_id,&"STORAGE_FULL",tick_value)
			continue
		var position := Vector2(worker.attributes.position_x,worker.attributes.position_z)
		var sources := simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE).filter(func(s): return s.attributes.get(&"resource_id") == role and s.attributes.get(&"gatherable",false) and s.attributes.get(&"available_amount",0) > 0)
		sources.sort_custom(func(a,b):
			var da: float = position.distance_squared_to(Vector2(a.attributes.position_x,a.attributes.position_z))
			var db: float = position.distance_squared_to(Vector2(b.attributes.position_x,b.attributes.position_z))
			return a.entity_id < b.entity_id if is_equal_approx(da,db) else da < db
		)
		var reason: StringName = &"NO_SOURCE"
		for source in sources:
			var type := GopalaSimulationCommand.REQUEST_GATHER_RESOURCE
			var command := GopalaSimulationCommand._from_queue(0,type,tick_value,{"villager_id":worker.entity_id,"source_entity_id":source.entity_id,"resource_id":role},&"worker_job")
			var result := simulation.gather_delivery_service().handle_request_gather_timber(command,tick_value)
			if result.status == GopalaCommandResult.Status.APPLIED: reason = &"WORKING"; break
			reason = result.reason_code
			if reason == &"STORAGE_FULL": break
		_status(worker.entity_id,reason,tick_value)

func _status(id: int, status: StringName, tick_value: int) -> void:
	var worker := simulation.entity_queries().snapshot(id)
	if worker != null and worker.attributes.get(&"job_status") != status:
		simulation.entity_registry().update_entity(id,{&"job_status":status},{},tick_value,worker.revision)
