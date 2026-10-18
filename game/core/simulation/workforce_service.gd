class_name GopalaWorkforceService
extends RefCounted
## Settlement-wide quotas. Internal assignments use the existing validated job
## services; only idle boundaries permit reassignment, never an in-flight load.
const ROLES := ["construction","water","wild_food","timber","stone","thatch","fodder","herder","milk"]
var simulation: GopalaSettlementSimulation
func _init(sim: GopalaSettlementSimulation): simulation = sim

static func default_policy() -> Dictionary:
	var jobs := {}
	for role in ROLES: jobs[role] = {"target":1 if role not in ["fodder","milk"] else 0,"priority":3 if role in ["water","wild_food"] else 2}
	jobs.construction.target = 2
	return {"enabled":false,"jobs":jobs}

static func valid_policy(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2 or typeof(value.get("enabled")) != TYPE_BOOL or not value.get("jobs") is Dictionary or value.jobs.size() != ROLES.size(): return false
	for role in ROLES:
		var row: Variant = value.jobs.get(role)
		if not row is Dictionary or row.size() != 2: return false
		for key in ["target","priority"]:
			if typeof(row.get(key)) != TYPE_INT: return false
		if row.target < 0 or row.target > 128 or row.priority < 0 or row.priority > 3: return false
	return true

func settlement() -> GopalaEntitySnapshot:
	var rows := simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.SETTLEMENT)
	return null if rows.is_empty() else rows[0]

func policy() -> Dictionary:
	var owner := settlement()
	return default_policy() if owner == null else owner.attributes.get("workforce_policy",default_policy()).duplicate(true)

func configure(command: GopalaSimulationCommand, tick: int) -> GopalaCommandResult:
	var value: Variant = command.payload.get("policy")
	var owner := settlement()
	if owner == null or not valid_policy(value): return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.REJECTED,&"INVALID_WORKFORCE_POLICY",tick)
	simulation.entity_registry().update_entity(owner.entity_id,{"workforce_policy":value},{},tick,owner.revision)
	return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.APPLIED,&"WORKFORCE_POLICY_UPDATED",tick,{"changed":true})

func set_automatic(command: GopalaSimulationCommand, tick: int) -> GopalaCommandResult:
	var p := command.payload
	if typeof(p.get("villager_id")) != TYPE_INT or typeof(p.get("enabled")) != TYPE_BOOL: return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.REJECTED,&"INVALID_WORKER",tick)
	var worker := simulation.entity_queries().snapshot(p.villager_id)
	if worker == null or worker.kind != GopalaEntityKind.VILLAGER: return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.REJECTED,&"INVALID_WORKER",tick)
	var owner := settlement()
	if owner != null and not owner.attributes.has("workforce_policy"): simulation.entity_registry().update_entity(owner.entity_id,{"workforce_policy":default_policy()},{},tick,owner.revision)
	simulation.entity_registry().update_entity(worker.entity_id,{"workforce_managed":p.enabled,"workforce_excluded":not p.enabled,"workforce_role":role_of(worker)},{},tick,worker.revision)
	return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.APPLIED,&"WORKER_AUTOMATION_UPDATED",tick,{"changed":true})

func manual_override(id: int, tick: int) -> void:
	var worker := simulation.entity_queries().snapshot(id)
	if worker != null: simulation.entity_registry().update_entity(id,{"workforce_managed":false,"workforce_excluded":true,"workforce_pending_role":"","workforce_blocked":"","resume_blueprint_id":0},{},tick,worker.revision)

func role_of(worker: GopalaEntitySnapshot) -> String:
	return "construction" if worker.attributes.get("task_kind") == "BUILD" else str(worker.attributes.get("work_role","NONE"))

func _eligible(worker: GopalaEntitySnapshot, role: String) -> bool:
	if simulation._survival_service.ready_for_work(worker): return true
	var need := str(worker.attributes.get("need_state","SATISFIED"))
	return (need == "NO_WATER" and role == "water") or (need == "NO_FOOD" and role in ["wild_food","milk"])

func _idle(worker: GopalaEntitySnapshot, role: String = "NONE") -> bool:
	return int(worker.attributes.get("active_task_id",0)) == 0 and int(worker.attributes.get("carried_amount",0)) == 0 and worker.attributes.get("movement_state","IDLE") != "MOVING" and worker.attributes.get("task_kind","NONE") not in ["BUILD","NEED"] and _eligible(worker,role)

func sites() -> Array[GopalaEntitySnapshot]:
	var rows: Array[GopalaEntitySnapshot] = []
	for kind in [GopalaEntityKind.BUILDING,GopalaEntityKind.ROAD]:
		for site in simulation.entity_queries().snapshots_by_kind(kind):
			if str(site.attributes.get("construction_state","COMPLETED")) in ["COMPLETED","CANCELLED"] or int(site.attributes.get("assigned_builder_id",0)) != 0: continue
			if kind == GopalaEntityKind.ROAD and not site.attributes.get("auto_build",false): continue
			rows.append(site)
	rows.sort_custom(func(a,b): return a.entity_id < b.entity_id)
	return rows

func reason(role: String) -> String:
	if role == "construction":
		for kind in [GopalaEntityKind.BUILDING,GopalaEntityKind.ROAD]:
			if simulation.entity_queries().snapshots_by_kind(kind).any(func(s):return str(s.attributes.get("construction_state","COMPLETED")) not in ["COMPLETED","CANCELLED"] and (kind != GopalaEntityKind.ROAD or s.attributes.get("auto_build",false))): return "READY"
		return "NO_SITE"
	if role == "herder":
		return "READY" if simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.ANIMAL).any(func(c):return int(c.attributes.get("pasture_id",0)) > 0 and int(c.attributes.get("shelter_id",0)) > 0) else "NO_SUPPORTED_HERD"
	if not simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE).any(func(s):return s.attributes.get("resource_id") == role and s.attributes.get("gatherable",false) and int(s.attributes.get("available_amount",0)) > 0): return "NO_SOURCE"
	return "READY" if simulation._storage_service.has_space(StringName(role)) else "STORAGE_FULL"

func tick(tick_value: int) -> void:
	var config := policy()
	var workers := simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)
	workers.sort_custom(func(a,b):return a.entity_id < b.entity_id)
	var pool: Array[GopalaEntitySnapshot] = []
	var manual := {}
	for worker in workers:
		if worker.attributes.get("workforce_managed",false) or (config.enabled and not worker.attributes.get("workforce_excluded",false) and role_of(worker) == "NONE" and (_idle(worker) or _idle(worker,"water") or _idle(worker,"wild_food"))):
			pool.append(worker)
		else:
			var role := role_of(worker)
			manual[role] = int(manual.get(role,0))+1
	var order := ROLES.duplicate()
	order.sort_custom(func(a,b):return ROLES.find(a) < ROLES.find(b) if config.jobs[a].priority == config.jobs[b].priority else config.jobs[a].priority > config.jobs[b].priority)
	var desired := {}
	var budget := pool.size()
	for role in order:
		var count := maxi(0,int(config.jobs[role].target)-int(manual.get(role,0))) if config.enabled and config.jobs[role].priority > 0 and reason(role) == "READY" else 0
		if role == "construction": count = mini(count,sites().size()+pool.filter(func(w):return role_of(w) == "construction").size())
		var eligible_count := pool.filter(func(w):return _eligible(w,role)).size()
		desired[role] = mini(count,mini(budget,eligible_count))
		budget -= int(desired[role])
	var assignments := {}
	# Keep matching workers before allocating spare workers, preventing churn.
	for worker in pool:
		var current := role_of(worker)
		if int(desired.get(current,0)) > 0:
			assignments[worker.entity_id] = current
			desired[current] -= 1
	for worker in pool:
		if assignments.has(worker.entity_id): continue
		assignments[worker.entity_id] = "NONE"
		for role in order:
			if int(desired.get(role,0)) > 0 and _eligible(worker,role):
				assignments[worker.entity_id] = role
				desired[role] -= 1
				break
	for original in pool:
		var worker := simulation.entity_queries().snapshot(original.entity_id)
		var next: String = assignments[worker.entity_id]
		var current := role_of(worker)
		if not worker.attributes.get("workforce_managed",false) or worker.attributes.get("workforce_pending_role","") != next:
			simulation.entity_registry().update_entity(worker.entity_id,{"workforce_managed":true,"workforce_pending_role":next},{},tick_value,worker.revision)
		# A material-starved builder with no cargo can safely release the site.
		# Keep its staged goods/progress and road auto-build intent intact.
		if current == "construction" and next != "construction" and int(worker.attributes.get("carried_amount",0)) == 0 and worker.attributes.get("task_state") == "WAITING_FOR_MATERIALS":
			simulation._construction_labor_service.cancel_task(worker.entity_id,tick_value,&"WORKFORCE_REASSIGNED")
			worker = simulation.entity_queries().snapshot(worker.entity_id)
			current = role_of(worker)
		if not _idle(worker,next): continue
		if next == "construction":
			# Construction owns the worker until it finishes or the player stops it.
			if current != "NONE": _assign_role(worker.entity_id,"NONE",tick_value)
			var outcome := "NO_SITE"
			for site in sites():
				var command := GopalaSimulationCommand._from_queue(0,GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER,tick_value,{"villager_id":worker.entity_id,"blueprint_id":site.entity_id},&"workforce")
				var result := simulation._construction_labor_service.handle_request_assign_builder(command,tick_value)
				outcome = "WORKING" if result.status == GopalaCommandResult.Status.APPLIED else str(result.reason_code)
				if outcome == "WORKING": break
			_status(worker.entity_id,outcome,tick_value)
		elif current != next:
			_assign_role(worker.entity_id,next,tick_value)

func _assign_role(id: int, role: String, tick_value: int) -> void:
	var command := GopalaSimulationCommand._from_queue(0,GopalaSimulationCommand.SET_WORK_ROLE,tick_value,{"villager_id":id,"role":StringName(role)},&"workforce")
	var result := simulation._worker_job_service.assign(command,tick_value)
	_status(id,"" if result.status == GopalaCommandResult.Status.APPLIED else str(result.reason_code),tick_value)

func _status(id: int, value: String, tick_value: int) -> void:
	var worker := simulation.entity_queries().snapshot(id)
	if worker.attributes.get("workforce_blocked","") != value: simulation.entity_registry().update_entity(id,{"workforce_blocked":value},{},tick_value,worker.revision)

func summary() -> Dictionary:
	var rows := []
	var workers := simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)
	var config := policy()
	for role in ROLES:
		var assigned := workers.filter(func(w):return role_of(w) == role)
		var status := reason(role)
		var blocked := assigned.filter(func(w):return str(w.attributes.get("job_status","")) not in ["", "WORKING","READY","OFF"])
		if not blocked.is_empty(): status = str(blocked[0].attributes.get("job_status"))
		if role == "construction":
			var stalled := assigned.filter(func(w):return w.attributes.get("task_state") == "WAITING_FOR_MATERIALS")
			if not stalled.is_empty(): status = "WAITING_FOR_MATERIALS"
		var waiting := workers.filter(func(w):return w.attributes.get("workforce_pending_role") == role and str(w.attributes.get("workforce_blocked","")) not in ["","WORKING"])
		if not waiting.is_empty(): status = str(waiting[0].attributes.workforce_blocked)
		if role == "construction" and status == "READY" and sites().is_empty() and not assigned.is_empty(): status = "SITES_STAFFED"
		if not config.enabled: status = "AUTOMATION_OFF"
		elif config.jobs[role].priority == 0: status = "DISABLED"
		elif config.jobs[role].target == 0: status = "NO_TARGET"
		elif status == "READY" and assigned.size() < int(config.jobs[role].target): status = "NO_FREE_WORKER"
		elif status == "READY" and not assigned.is_empty(): status = "WORKING"
		rows.append({"role":role,"assigned":assigned.size(),"target":config.jobs[role].target,"priority":config.jobs[role].priority,"status":status})
	var roster := []
	for worker in workers:
		roster.append({"id":worker.entity_id,"role":role_of(worker),"automatic":worker.attributes.get("workforce_managed",false),"status":_worker_status(worker),"pending":worker.attributes.get("workforce_pending_role",""),"carried":int(worker.attributes.get("carried_amount",0))})
	return {"policy":config,"jobs":rows,"workers":roster}

func _worker_status(worker: GopalaEntitySnapshot) -> String:
	if not simulation._survival_service.ready_for_work(worker): return str(worker.attributes.get("need_state","NEEDS_SUPPLIES"))
	var blocked := str(worker.attributes.get("workforce_blocked",""))
	if blocked not in ["","WORKING"]: return blocked
	if int(worker.attributes.get("active_task_id",0)) > 0: return str(worker.attributes.get("task_state","WORKING"))
	var job := str(worker.attributes.get("job_status","IDLE"))
	return "IDLE" if job in ["","NONE","OFF","WORKING"] else job
