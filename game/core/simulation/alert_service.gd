class_name GopalaAlertService
extends Node
## Derived, scene-owned notifications. No inventory mutations or save history.
signal alerts_changed(rows: Array)
const POLICY_PATH := "res://data/alerts.json"
var policy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
var _sim: GopalaSettlementSimulation
var _rows: Array = []
var _signature := ""
var _last_tick := -1

func bind(sim: GopalaSettlementSimulation) -> void:
	if is_instance_valid(_sim) and _sim.fixed_tick_completed.is_connected(_on_tick):
		_sim.fixed_tick_completed.disconnect(_on_tick)
	_sim = sim
	_last_tick = -1
	_signature = ""
	_sim.fixed_tick_completed.connect(_on_tick)
	refresh(true)

func _exit_tree() -> void:
	if is_instance_valid(_sim) and _sim.fixed_tick_completed.is_connected(_on_tick):
		_sim.fixed_tick_completed.disconnect(_on_tick)

func _on_tick(tick_value: int) -> void:
	if tick_value == _last_tick: return
	_last_tick = tick_value
	refresh()

func rows() -> Array: return _rows.duplicate(true)

func focus_payload(key: String) -> Dictionary:
	for row in _rows:
		if row.key != key: continue
		var entity := _sim.entity_queries().snapshot(int(row.focus.entity_id))
		if entity == null: return {}
		var a := entity.attributes
		return {"entity_id":entity.entity_id,"position_x":float(a.get(&"position_x",0.0)),"position_z":float(a.get(&"position_z",0.0))}
	return {}

func refresh(force := false) -> void:
	_rows = evaluate()
	var display: Array = []
	for row in _rows: display.append([row.key,row.severity,row.message])
	var signature := JSON.stringify(display)
	if force or signature != _signature:
		_signature = signature
		alerts_changed.emit(rows())

func _entry(result: Dictionary, kind: String, subject, message: String, aggregate := false) -> void:
	var key := kind if aggregate else "%s:%d" % [kind,subject.entity_id]
	var a: Dictionary = subject.attributes
	result[key] = {"key":key,"type":kind,"severity":str(policy.severity[kind]),"message":message,"focus":{"entity_id":subject.entity_id,"position_x":float(a.get(&"position_x",0.0)),"position_z":float(a.get(&"position_z",0.0))}}

func evaluate() -> Array:
	var result := {}
	if not is_instance_valid(_sim) or not _sim._survival_service.enabled(): return []
	var records := _sim.entity_registry().registry_snapshot().entities
	var workers: Array = []
	var buildings: Array = []
	var cows: Array = []
	var by_id := {}
	for entity in records:
		by_id[entity.entity_id] = entity
		if entity.kind == GopalaEntityKind.VILLAGER: workers.append(entity)
		elif entity.kind == GopalaEntityKind.BUILDING: buildings.append(entity)
		elif entity.kind == GopalaEntityKind.ANIMAL: cows.append(entity)
	if not workers.is_empty():
		var population := workers.size()
		var survival: Dictionary = _sim._survival_service.policy
		var tick_seconds := _sim.tick_interval_seconds()
		var food_minutes := float(_sim.resource_amount(&"wild_food")+_sim.resource_amount(&"milk"))*float(survival.meal_interval_ticks)*tick_seconds/(60.0*population)
		var water_minutes := float(_sim.resource_amount(&"water"))*float(survival.drink_interval_ticks)*tick_seconds/(60.0*population)
		if food_minutes < float(policy.food_minutes): _entry(result,"food",workers[0],"Food below %s logical minutes — assign food or milk collection" % policy.food_minutes,true)
		if water_minutes < float(policy.water_minutes): _entry(result,"water",workers[0],"Water below %s logical minutes — assign water collection" % policy.water_minutes,true)
	var homeless: Array = []
	var idle: Array = []
	for worker in workers:
		var a: Dictionary = worker.attributes
		if int(a.get(&"health",100)) < int(policy.health_below): _entry(result,"health",worker,"Settler %d health below %d — restore food and water access" % [worker.entity_id,policy.health_below])
		if int(a.get(&"home_id",0)) == 0 or not by_id.has(int(a.get(&"home_id",0))): homeless.append(worker)
		if int(a.get(&"health",100)) > 0 and a.get(&"work_role",&"NONE") == &"NONE" and int(a.get(&"active_task_id",0)) == 0 and int(a.get(&"carried_amount",0)) == 0 and a.get(&"movement_state",&"IDLE") != &"MOVING" and a.get(&"task_kind",&"NONE") != &"NEED" and a.get(&"need_state",&"SATISFIED") == &"SATISFIED": idle.append(worker)
		var job := str(a.get(&"job_status",&"OFF"))
		var state := str(a.get(&"task_state",&"NONE"))
		if job == "STORAGE_FULL" or state == "WAITING_FOR_STORAGE":
			var resource := StringName(a.get(&"carried_resource_id",a.get(&"work_role",&"NONE")))
			if resource.is_empty(): resource = StringName(a.get(&"work_role",&"NONE"))
			for store in _sim._storage_service.destinations(resource):
				if _sim._storage_service.store_capacity(store.entity_id,resource) > 0 and not _sim._storage_service.store_has_space(store.entity_id,resource):
					_entry(result,"store",store,"Store %d full — blocks %s gathering" % [store.entity_id,resource])
		if a.get(&"task_kind") == &"BUILD" and (state in ["BLOCKED_ROUTE","NO_ACCESSIBLE_STOCK","NO_STORAGE"] or a.get(&"movement_state") == &"BLOCKED"):
			var task: Dictionary = _sim._construction_labor_service._tasks.get(worker.entity_id,{})
			var site = by_id.get(int(task.get("blueprint_id",0)))
			if site != null: _entry(result,"construction",site,"Site %d blocked — %s" % [site.entity_id,state.replace("_"," ").to_lower()])
	if not homeless.is_empty(): _entry(result,"homeless",homeless[0],"%d settlers need completed housing" % homeless.size(),true)
	if not idle.is_empty(): _entry(result,"idle",idle[0],"%d settlers have no job — select and assign work" % idle.size(),true)
	for building in buildings:
		if str(building.attributes.get(&"construction_state","COMPLETED")) == "WAITING_FOR_MATERIALS": _entry(result,"construction",building,"Site %d waiting for materials — gather missing supplies" % building.entity_id)
	for cow in cows:
		var a: Dictionary = cow.attributes
		var status := str(a.get(&"herd_status","READY"))
		if status == "NO_WATER": _entry(result,"cattle_water",cow,"Cow %d needs water — assign a herder and water supply" % cow.entity_id)
		elif status == "NO_FEED" and int(a.get(&"fodder_fed",0)) == 0:
			var pasture = by_id.get(int(a.get(&"pasture_id",0)))
			if pasture != null and int(pasture.attributes.get(&"grazing_available",0)) <= 0: _entry(result,"cattle_feed",cow,"Cow %d needs fodder — grazing is depleted" % cow.entity_id)
	var keys: Array = result.keys()
	keys.sort_custom(func(a,b):
		var pa: int = policy.priority[result[a].type]
		var pb: int = policy.priority[result[b].type]
		return str(a) < str(b) if pa == pb else pa < pb
	)
	var ordered: Array = []
	for key in keys: ordered.append(result[key])
	return ordered
