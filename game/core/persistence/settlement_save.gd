class_name GopalaSettlementSave
extends RefCounted

## Versioned plain state only. A detached simulation is validated before the view
## swaps it in. Engine nodes, AStar paths and presentation caches are never saved.
const VERSION := 2
const MAX_BYTES := 8 * 1024 * 1024
var error := ""

func capture(sim: GopalaSettlementSimulation, context: Dictionary, drain := true) -> Dictionary:
	if sim._processing_commands or sim._resetting or sim._advancing_ticks or sim._storage_service.flushing:
		error = "Settlement is busy"
		return {}
	if drain:
		sim.process_pending_commands()
		sim._storage_service.flush_removed()
	if drain and sim._queue.has_pending():
		error = "Commands remain pending"
		return {}
	var records := []
	for record in sim._entity_registry._records.values():
		records.append([record._entity_id, record._kind, int(record._lifecycle), record._revision,
			record._created_tick, record._updated_tick, record._attributes.duplicate(true), record._links.duplicate(true)])
	var claims := []
	for claim in sim._occupancy_service._claims.values():
		claims.append(sim._occupancy_service._make_snapshot(claim).to_plain_data())
	return {"located_storage":sim._storage_service.located,"store_stocks":sim._storage_service.stocks.duplicate(true),"context": context.duplicate(true), "grid": sim._coordinate_service.config_snapshot(),
		"clock": [sim.paused, sim.speed, sim.logical_tick, sim._clock.elapsed_logical_nanoseconds,
			sim._clock._fractional_logical_nanoseconds, sim._clock._tick_interval_nanoseconds],
		"balances": sim.resource_balances_snapshot(), "records": records,
		"removed": sim._entity_registry._removed_ids.duplicate(),
		"registry_sequence": sim._entity_registry._sequence, "next_entity": sim._entity_ids._next_id,
		"next_command": sim._queue._next_command_id, "claims": claims,
		"occupancy_sequence": sim._occupancy_service._sequence,
		"gather": sim._gather_delivery_service._tasks.duplicate(true),		"next_gather":sim._gather_delivery_service._next_task_id,
		"construction":sim._construction_labor_service._tasks.duplicate(true),
		"next_construction":sim._construction_labor_service._next_task_id,
		"field_tasks":sim._field_service._tasks.duplicate(true),
		"next_field":sim._field_service._next_task_id}


func write(path: String, state: Dictionary) -> bool:
	if state.is_empty(): return false
	error = ""
	var encoded: Variant = encode(state)
	var payload := JSON.stringify(encoded)
	var document := JSON.stringify({"version": VERSION, "checksum": payload.sha256_text(), "payload": encoded})
	if document.length() > MAX_BYTES: return _fail("Save exceeds size limit")
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK: return _fail("Cannot create save directory")
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _fail("Cannot write save")
	file.store_string(document)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or read(temporary).is_empty(): return _fail("Temporary save validation failed")
	# Copy the previous file first; replacing the primary is a same-directory rename.
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(absolute, absolute + ".bak") != OK: return _fail("Cannot retain previous save")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute) != OK: return _fail("Cannot replace save")
	return true

func read(path: String) -> Dictionary:
	error = ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: _fail("Save file unavailable"); return {}
	if file.get_length() > MAX_BYTES: _fail("Save exceeds size limit"); return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		_fail("Unsupported or malformed save"); return {}
	var document: Variant = parser.data
	if not document is Dictionary or document.get("version") != VERSION or not document.has("payload"):
		_fail("Unsupported or malformed save"); return {}
	if document.get("checksum") != JSON.stringify(document.payload).sha256_text():
		_fail("Save checksum mismatch"); return {}
	var decoded: Variant = decode(document.payload)
	if not error.is_empty() or not decoded is Dictionary: return {}
	return decoded

## Tag integers as decimal strings: JSON numbers cannot preserve all 64-bit ticks.
static func encode(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT: return ["i", str(value)]
		TYPE_STRING_NAME: return ["n", str(value)]
		TYPE_STRING: return ["s", value]
		TYPE_BOOL: return ["b", value]
		TYPE_FLOAT: return ["f", PackedFloat64Array([value]).to_byte_array().hex_encode()]
		TYPE_NIL: return ["z"]
		TYPE_ARRAY:
			var items := []
			for item in value: items.append(encode(item))
			return ["a", items]
		TYPE_DICTIONARY:
			var pairs := []
			for key in value: pairs.append([encode(key), encode(value[key])])
			return ["d", pairs]
	return null

func decode(value: Variant, depth := 0) -> Variant:
	if depth > 24 or not value is Array or value.is_empty() or not value[0] is String:
		_fail("Invalid typed save data"); return null
	if value[0] == "z" and value.size() == 1: return null
	if value.size() != 2: _fail("Invalid typed save length"); return null
	var item: Variant = value[1]
	match value[0]:
		"i":
			if item is String and item.is_valid_int() and str(item.to_int()) == item: return item.to_int()
		"s":
			if item is String: return item
		"n":
			if item is String: return StringName(item)
		"b":
			if item is bool: return item
		"f":
			if item is String and item.length() == 16:
				var bytes: PackedByteArray = item.hex_decode()
				if bytes.size() == 8 and bytes.hex_encode() == item:
					var number: float = bytes.to_float64_array()[0]
					if is_finite(number): return number
		"a":
			if item is Array:
				var items := []
				for entry in item: items.append(decode(entry, depth + 1))
				return items
		"d":
			if item is Array:
				var map := {}
				for pair in item:
					if not pair is Array or pair.size() != 2: _fail("Invalid save dictionary"); return null
					var key: Variant = decode(pair[0], depth + 1)
					if typeof(key) not in [TYPE_INT, TYPE_STRING, TYPE_STRING_NAME] or map.has(key): _fail("Invalid or duplicate save key"); return null
					map[key] = decode(pair[1], depth + 1)
				return map
	_fail("Invalid save value"); return null

func restore(state: Dictionary, current: GopalaSettlementSimulation, context: Dictionary) -> GopalaSettlementSimulation:
	error = ""
	var candidate := GopalaSettlementSimulation.new()
	candidate._resetting = true
	if not _populate(state, candidate, current, context):
		candidate.free()
		if error.is_empty(): error = "Save state is inconsistent"
		return null
	candidate._resetting = false
	candidate._session_epoch = current._session_epoch + 1
	candidate._snapshot_sequence = current._snapshot_sequence + 1
	return candidate

func _populate(s: Dictionary, sim: GopalaSettlementSimulation, current: GopalaSettlementSimulation, context: Dictionary) -> bool:
	var template := capture(current, context, false)
	if template.is_empty(): return _fail("Invalid settlement state at validation 144")
	# Schema 2 saves created before fields had no agriculture task counter/state.
	if not s.has("field_tasks") and not s.has("next_field"):
		s["field_tasks"] = {}
		s["next_field"] = 1
	if s.size() != template.size(): return _fail("Invalid settlement state at validation 145")
	for key in template:
		if not s.has(key) or typeof(s[key]) != typeof(template[key]): return _fail("Invalid settlement state at validation 147")
	if s.context != context or s.grid != template.grid or s.located_storage != current._storage_service.located: return _fail("Save belongs to a different world or scale standard")
	for key in ["registry_sequence", "occupancy_sequence", "next_entity", "next_command", "next_gather", "next_construction", "next_field"]:
		if not _integer(s[key], 1 if key.begins_with("next_") else 0): return _fail("Invalid settlement state at validation 150")
	if s.clock.size() != 6 or not s.clock[0] is bool: return _fail("Invalid settlement state at validation 151")
	for i in range(1,6):
		if typeof(s.clock[i]) != TYPE_INT or s.clock[i] < 0: return _fail("Invalid settlement state at validation 153")
	if s.clock[1] < 1 or s.clock[1] > 4 or s.clock[5] != current._clock._tick_interval_nanoseconds or s.clock[4] >= s.clock[5]: return _fail("Invalid settlement state at validation 154")
	if s.clock[3] > GopalaSimulationConfig.MAX_ELAPSED_NANOSECONDS or s.clock[3] / s.clock[5] != s.clock[2] or s.clock[3] % s.clock[5] != s.clock[4]: return _fail("Invalid settlement state at validation 155")
	sim._config.tick_interval_seconds = current._config.tick_interval_seconds
	sim._clock.paused = s.clock[0]
	sim._clock.speed = s.clock[1]
	sim._clock.logical_tick = s.clock[2]
	sim._clock.elapsed_logical_nanoseconds = s.clock[3]
	sim._clock._fractional_logical_nanoseconds = s.clock[4]
	sim._clock.configure(s.clock[5])
	sim._clock._fractional_logical_nanoseconds = s.clock[4]
	if not sim._ledger._is_integer_delta(s.balances,true): return _fail("Invalid settlement state at validation 163")
	if not sim._ledger.apply_authorized_transaction(s.balances): return _fail("Invalid settlement state at validation 164")
	sim._coordinate_service.configure(current._coordinate_service._config)
	var registry := sim._entity_registry
	for row in s.records:
		if not row is Array or row.size() != 8: return _fail("Invalid settlement state at validation 168")
		for i in [0,2,3,4,5]:
			if not _integer(row[i]): return _fail("Invalid settlement state at validation 170")
		if typeof(row[1]) != TYPE_STRING_NAME or not row[6] is Dictionary or not row[7] is Dictionary: return _fail("Invalid settlement state at validation 171")
		var record := GopalaEntityRecord.new(row[0],row[1],row[2],row[3],row[4],row[5],row[6],row[7])
		if row[2] != GopalaEntityLifecycle.State.ACTIVE or not record.snapshot(s.registry_sequence).valid or row[5] > sim.logical_tick or row[0] >= s.next_entity or registry._records.has(row[0]): return _fail("Invalid settlement state at validation 173")
		if not _attributes_valid(row[6]): return _fail("Invalid settlement state at validation 174")
		registry._records[row[0]] = record
		registry._add_kind_id(row[1],row[0])
	for record in registry._records.values():
		if registry._links_error(record._links) != GopalaEntityOperationResult.APPLIED: return _fail("Invalid settlement state at validation 178")
		registry._add_outgoing_references(record)
	for id in s.removed:
		if not _integer(id,1) or id >= s.next_entity or registry.has_entity(id) or s.removed[id] != true: return _fail("Invalid settlement state at validation 181")
		registry._removed_ids[id] = true
	registry._sequence = s.registry_sequence
	sim._entity_ids._next_id = s.next_entity
	sim._queue._next_command_id = s.next_command
	for claim in s.claims:
		if not claim is Dictionary or claim.size() != 6: return _fail("Invalid settlement state at validation 187")
		for key in ["owner_entity_id","revision","created_tick","updated_tick"]:
			if not _integer(claim.get(key)): return _fail("Invalid settlement state at validation 189")
		if claim.revision < 1 or claim.updated_tick < claim.created_tick or claim.updated_tick > sim.logical_tick: return _fail("Invalid settlement state at validation 190")
		if typeof(claim.get("state")) != TYPE_STRING_NAME or not claim.get("cells") is Array or not GopalaOccupancyState.is_valid(claim.get("state", &"")): return _fail("Invalid settlement state at validation 191")
		var cells: Array[Vector2i] = []
		for cell in claim.cells:
			if not cell is Array or cell.size() != 2 or not _integer(cell[0],-1000000) or not _integer(cell[1],-1000000): return _fail("Invalid settlement state at validation 194")
			cells.append(Vector2i(cell[0],cell[1]))
		var occupancy := sim._occupancy_service
		if occupancy._claims.has(claim.owner_entity_id) or occupancy.replace_claim(claim.owner_entity_id,claim.state,cells,claim.updated_tick).status != GopalaOccupancyOperationResult.Status.APPLIED: return _fail("Invalid settlement state at validation 197")
		var imported = occupancy._claims[claim.owner_entity_id]
		imported.revision = claim.revision
		imported.created_tick = claim.created_tick
	sim._occupancy_service._sequence = s.occupancy_sequence
	for record in s.records:
		var attributes: Dictionary = record[6]
		if attributes.has("workforce_policy") and (str(record[1]) != str(GopalaEntityKind.SETTLEMENT) or not GopalaWorkforceService.valid_policy(attributes.workforce_policy)): return _fail("Invalid workforce policy")
		for key in ["workforce_managed","workforce_excluded"]:
			if attributes.has(key) and typeof(attributes[key]) != TYPE_BOOL: return _fail("Invalid worker automation")
		for key in ["workforce_role","workforce_pending_role"]:
			if attributes.has(key) and str(attributes[key]) not in GopalaWorkforceService.ROLES + ["NONE",""]: return _fail("Invalid workforce role")
	if not _roads_valid(s,sim): return _fail("Invalid road construction state")
	if not _fields_valid(sim): return _fail("Invalid field state")
	if not _tasks_valid(s.gather, sim, true, s.next_gather) or not _tasks_valid(s.construction,sim,false,s.next_construction): return _fail("Invalid settlement state at validation 202")
	if not _field_tasks_valid(s.field_tasks, sim, s.next_field): return _fail("Invalid field work state")
	sim._storage_service.located = s.located_storage
	sim._storage_service.stocks = s.store_stocks.duplicate(true)
	if not _located_stocks_valid(s,sim): return _fail("Invalid per-store stock or construction origin")
	if not _cross_references_valid(s,sim): return _fail("Save has inconsistent tasks, reservations or building requirements")
	if sim._survival_service.enabled() != current._survival_service.enabled() or not _survival_valid(sim) or not _herd_valid(sim): return _fail("Invalid survival state")
	sim._gather_delivery_service._tasks = s.gather.duplicate(true)
	sim._gather_delivery_service._next_task_id = s.next_gather
	sim._construction_labor_service._tasks = s.construction.duplicate(true)
	sim._construction_labor_service._next_task_id = s.next_construction
	sim._field_service.restore_tasks(s.field_tasks,s.next_field)
	# Rebuild navigation from the current terrain predicate and restored claims.
	if current._route_service.enabled:
		sim._route_service.enable(current._route_service._grid.region,current._route_service._walkable)
		sim._villager_service._current_tick = sim.logical_tick
		for worker in sim._entity_queries.snapshots_by_kind(GopalaEntityKind.VILLAGER):
			if worker.attributes.get(&"movement_state") == &"MOVING":
				var attrs := worker.attributes
				if not attrs.has(&"requested_destination_x") or not attrs.has(&"requested_destination_z"): return _fail("Invalid settlement state at validation 214")
				if not sim._villager_service.set_destination(worker.entity_id,Vector2(attrs.requested_destination_x,attrs.requested_destination_z),attrs.get(&"movement_purpose",&""),attrs.get(&"active_task_id",0)):
					var refreshed := sim._entity_registry.snapshot(worker.entity_id)
					sim._entity_registry.update_entity(worker.entity_id,{&"movement_state":&"BLOCKED",&"movement_failure":sim._villager_service.last_failure},{},sim.logical_tick,refreshed.revision)
	# A blocked task must retry against the rebuilt navigation revision.
	for task in sim._gather_delivery_service._tasks.values(): task["blocked_revision"] = -1
	for task in sim._construction_labor_service._tasks.values(): task["blocked_revision"] = -1
	for task in sim._field_service._tasks.values(): task["blocked_revision"] = -1
	return true

func _attributes_valid(attrs: Dictionary) -> bool:
	if not GopalaPlainData.validate(attrs): return false
	for key in ["available_amount","reserved_amount","initial_amount","generated_amount","carried_amount","active_task_id","assigned_builder_id"]:
		if attrs.has(key) and not _amount(attrs[key]): return false
	for key in ["position_x","position_z","destination_x","destination_z","requested_destination_x","requested_destination_z","movement_speed","waypoint_x","waypoint_z","work_completed","work_required"]:
		if attrs.has(key) and (typeof(attrs[key]) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(attrs[key]))): return false
	for key in ["resource_id","carried_resource_id","movement_purpose","movement_state","task_kind","task_state","definition_id","construction_state"]:
		if attrs.has(key) and typeof(attrs[key]) not in [TYPE_STRING,TYPE_STRING_NAME]: return false
	for key in ["required_materials","reserved_materials","delivered_materials","storage_capacity","consumed_goods"]:
		if attrs.has(key):
			if not attrs[key] is Dictionary: return false
			for resource in attrs[key]:
				if typeof(resource) not in [TYPE_STRING,TYPE_STRING_NAME] or not StringName(resource) in GopalaSimulationConfig.RESOURCE_IDS or not _amount(attrs[key][resource]): return false
	if attrs.has(&"work_role") and (typeof(attrs.work_role) != TYPE_STRING_NAME or (attrs.work_role not in [&"NONE",&"herder"] and not attrs.work_role in GopalaSimulationCommand.COLLECTIBLE_RESOURCES)): return false
	for key in [&"fertility",&"moisture",&"base_moisture"]:
		if attrs.has(key) and (typeof(attrs[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(attrs[key])) or float(attrs[key]) < 0.0 or float(attrs[key]) > 1.0): return false
	for key in [&"slope_degrees",&"elevation_metres",&"river_distance_metres"]:
		if attrs.has(key) and (typeof(attrs[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(attrs[key]))): return false
	for key in [&"growth_started_tick",&"harvest_ready_tick",&"growth_progress_ticks",&"last_growth_tick",&"harvest_count","terrace_riser_count"]:
		if attrs.has(key) and not _integer(attrs[key]): return false
	if attrs.has(&"field_stage") and (typeof(attrs.field_stage) != TYPE_STRING_NAME or attrs.field_stage not in [&"FALLOW",&"PREPARING",&"PLANTED",&"GROWING",&"TENDING",&"DROUGHT",&"MATURE",&"HARVESTED"]): return false
	if attrs.has(&"crop_id") and (typeof(attrs.crop_id) != TYPE_STRING_NAME or attrs.crop_id not in [&"",&"cereal",&"fodder_crop"]): return false
	if attrs.has(&"zone_cells") and not _cell_rows_valid(attrs.zone_cells,16): return false
	if attrs.has(&"terrace_cells") and not _cell_rows_valid(attrs.terrace_cells,16): return false
	if attrs.has(&"terrace_levels"):
		if not attrs.terrace_levels is Array or attrs.terrace_levels.size() != GopalaFieldService.FIELD_CELLS.y: return false
		for level in attrs.terrace_levels:
			if typeof(level) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(level)): return false
	return true

func _survival_valid(sim: GopalaSettlementSimulation) -> bool:
	if not sim._survival_service.enabled(): return true
	var scenarios := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.SETTLEMENT).filter(func(s): return s.attributes.get(&"survival_enabled",false))
	if scenarios.size() != 1 or typeof(scenarios[0].attributes.get(&"survival_enabled")) != TYPE_BOOL or scenarios[0].attributes.get(&"scenario_id") != &"gopala_mvp_v1": return false
	for key in [&"started_tick",&"stable_ticks"]:
		if scenarios[0].attributes.has(key) and not _integer(scenarios[0].attributes[key]): return false
	for source in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE):
		for key in [&"water_producer_id",&"last_refill_tick"]:
			if source.attributes.has(key) and not _integer(source.attributes[key]): return false
	var states: Array[StringName] = [&"SATISFIED",&"FETCHING_SUPPLIES",&"FINISHING_DELIVERY",&"NO_FOOD",&"NO_WATER",&"NO_ACCESS",&"SEEKING_SUPPLIES"]
	var occupants := {}
	for worker in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER):
		var attrs := worker.attributes
		for key in [&"meal_due_tick",&"drink_due_tick",&"home_id",&"need_store_id",&"resume_blueprint_id"]:
			if attrs.has(key) and not _integer(attrs[key]): return false
		if attrs.has(&"health") and (not _integer(attrs.health) or attrs.health > 100): return false
		if attrs.has(&"need_state") and (typeof(attrs.need_state) != TYPE_STRING_NAME or not attrs.need_state in states): return false
		if attrs.has(&"need_resource") and (typeof(attrs.need_resource) != TYPE_STRING_NAME or not attrs.need_resource in [&"",&"water",&"wild_food",&"milk"]): return false
		if attrs.get(&"task_kind") == &"NEED" and (attrs.get(&"active_task_id",0) != 0 or attrs.get(&"carried_amount",0) != 0 or int(attrs.get(&"need_store_id",0)) < 1): return false
		var home_id: int = attrs.get(&"home_id",0)
		if home_id > 0:
			var home := sim.entity_queries().snapshot(home_id)
			if home == null or home.kind != GopalaEntityKind.BUILDING or home.attributes.get("definition_id") != &"dwelling" or str(home.attributes.get("construction_state","COMPLETED")) != "COMPLETED": return false
			occupants[home_id] = int(occupants.get(home_id,0)) + 1
			if occupants[home_id] > sim.placement_service().get_building(&"dwelling").home_capacity: return false
	return true

func _tasks_valid(tasks: Dictionary, sim: GopalaSettlementSimulation, gather: bool, next_id: int) -> bool:
	for id in tasks:
		if not _integer(id,1) or not tasks[id] is Dictionary: return false
		var task: Dictionary = tasks[id]
		var worker := sim._entity_queries.snapshot(id)
		if worker == null or worker.kind != GopalaEntityKind.VILLAGER or not _integer(task.get("task_id"),1) or task.task_id >= next_id: return false
		if worker.attributes.get(&"active_task_id") != task.task_id or worker.attributes.get(&"task_kind") != (&"GATHER" if gather else &"BUILD"): return false
		var states := ["MOVING_TO_SOURCE","PICKING_UP","MOVING_TO_DROPOFF","DELIVERING"] if gather else ["EVALUATING","MOVING_TO_CAMP","PICKING_UP_MATERIAL","DELIVERING_MATERIAL","MOVING_TO_BLUEPRINT","PERFORMING_LABOR","RETURNING_TO_CAMP"]
		if not str(task.get("state")) in states: return false
		for key in (["source_id","destination_id"] if gather else ["blueprint_id"]):
			if not _integer(task.get(key),1): return false
			var missing_allowed: bool = (not gather and str(task.state) == "RETURNING_TO_CAMP") or (gather and key == "destination_id" and worker.attributes.get(&"task_state") == &"NO_STORAGE")
			if not missing_allowed and not sim._entity_registry.has_entity(task[key]): return false
		for key in ["pickup_store_id","return_store_id"]:
			if task.has(key) and not _integer(task[key]): return false
		for key in ["created_tick","updated_tick","blocked_revision"]:
			if task.has(key) and not _integer(task[key],-1): return false
		if task.has("arrived_at_camp") and not task.arrived_at_camp is bool: return false
		if task.has("target_material") and typeof(task.target_material) not in [TYPE_STRING,TYPE_STRING_NAME]: return false
		if gather:
			if task.get("villager_id") != id or task.get("amount") != 1 or not task.get("repeat") is bool or not task.get("resource_id") in GopalaSimulationCommand.COLLECTIBLE_RESOURCES: return false
	return true

func _cross_references_valid(s: Dictionary, sim: GopalaSettlementSimulation) -> bool:
	var reservations := {}
	for id in s.gather:
		if s.construction.has(id): return false
		var task: Dictionary = s.gather[id]
		var source := sim._entity_queries.snapshot(task.source_id)
		var destination := sim._entity_queries.snapshot(task.destination_id)
		var worker := sim._entity_queries.snapshot(id)
		if source.kind != GopalaEntityKind.RESOURCE_SOURCE or source.attributes.get(&"resource_id") != task.resource_id: return false
		if not sim._gather_delivery_service._valid_destination(task.destination_id,task.resource_id) and worker.attributes.get(&"task_state") != &"NO_STORAGE": return false
		var picking: bool = str(task.state) in ["MOVING_TO_SOURCE","PICKING_UP"]
		if picking: reservations[task.source_id] = reservations.get(task.source_id,0) + 1
		if worker.attributes.get(&"carried_amount",0) != (0 if picking else 1): return false
		if not picking and worker.attributes.get(&"carried_resource_id") != task.resource_id: return false
	for source in sim._entity_queries.snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE):
		if source.attributes.get(&"reserved_amount",0) != reservations.get(source.entity_id,0): return false
	for worker in sim._entity_queries.snapshots_by_kind(GopalaEntityKind.VILLAGER):
		var attrs := worker.attributes
		if not attrs.has(&"position_x") or not attrs.has(&"position_z"): return false
		if attrs.get(&"carried_amount",0) > 1: return false
		if attrs.get(&"carried_amount",0) > 0 and not attrs.get(&"carried_resource_id") in GopalaSimulationConfig.RESOURCE_IDS: return false
		if attrs.get(&"task_kind") == &"GATHER" and not s.gather.has(worker.entity_id) and attrs.get(&"task_state") != &"FAILED_DELIVERY": return false
		if attrs.get(&"task_kind") == &"BUILD" and not s.construction.has(worker.entity_id): return false
	for building in sim._entity_queries.snapshots_by_kind(GopalaEntityKind.BUILDING):
		var attrs := building.attributes
		if attrs.has("required_materials"):
			var definition := sim._placement_service.get_building(StringName(attrs.get("definition_id","")))
			if definition == null or attrs.required_materials != definition.costs or attrs.get("work_required") != definition.work_ticks: return false
			if attrs.get("work_completed",0) < 0 or attrs.get("work_completed",0) > definition.work_ticks: return false
			var claim := sim._occupancy_service.claim_for_owner(building.entity_id)
			if claim == null: return false
			for key in ["anchor_cell_x","anchor_cell_y","rotation"]:
				if not _integer(attrs.get(key),-1000000): return false
			if attrs.rotation < 0 or attrs.rotation > 3: return false
			var expected := GopalaFootprintTransform.transform_footprint(sim._placement_service.get_footprint_offsets(definition.footprint),attrs.rotation,Vector2i(attrs.anchor_cell_x,attrs.anchor_cell_y))
			if expected.size() != claim.cells.size(): return false
			for cell in expected:
				if not claim.cells.has(cell): return false
			var builder: int = attrs.get("assigned_builder_id",0)
			if builder > 0 and (not s.construction.has(builder) or s.construction[builder].blueprint_id != building.entity_id): return false
			for resource in attrs.required_materials:
				var total: int = attrs.get("reserved_materials",{}).get(resource,0) + attrs.get("delivered_materials",{}).get(resource,0)
				if builder > 0:
					var worker := sim._entity_queries.snapshot(builder)
					if worker.attributes.get(&"carried_resource_id") == resource: total += worker.attributes.get(&"carried_amount",0)
				if total > attrs.required_materials[resource]: return false
	for id in s.construction:
		var task: Dictionary = s.construction[id]
		if str(task.state) != "RETURNING_TO_CAMP":
			var blueprint := sim._entity_queries.snapshot(task.blueprint_id)
			if blueprint == null or blueprint.kind not in [GopalaEntityKind.BUILDING,GopalaEntityKind.ROAD] or blueprint.attributes.get("assigned_builder_id") != id: return false
	return true

func _amount(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= GopalaSimulationConfig.MAX_BALANCE

func _integer(value: Variant, minimum := 0) -> bool:
	return typeof(value) == TYPE_INT and value >= minimum and value <= GopalaSimulationConfig.MAX_SEQUENCE

func _fail(message: String) -> bool:
	error = message
	return false

func _located_stocks_valid(s: Dictionary, sim: GopalaSettlementSimulation) -> bool:
	if not s.located_storage: return s.store_stocks.is_empty()
	var totals := {}
	for id in s.store_stocks:
		if not _integer(id,1) or not s.store_stocks[id] is Dictionary: return false
		var store := sim._entity_queries.snapshot(id)
		if store == null or store.kind != GopalaEntityKind.BUILDING or str(store.attributes.get("construction_state","COMPLETED")) != "COMPLETED": return false
		for resource in s.store_stocks[id]:
			if typeof(resource) != TYPE_STRING_NAME or not resource in GopalaSimulationConfig.RESOURCE_IDS or not _amount(s.store_stocks[id][resource]): return false
			totals[resource] = int(totals.get(resource,0)) + s.store_stocks[id][resource]
			if totals[resource] > GopalaSimulationConfig.MAX_BALANCE: return false
		sim._storage_service._cache_position(id)
	for resource in GopalaSimulationConfig.RESOURCE_IDS:
		if int(totals.get(resource,0)) != int(s.balances.get(resource,0)): return false
	for blueprint in (sim._entity_queries.snapshots_by_kind(GopalaEntityKind.BUILDING) + sim._entity_queries.snapshots_by_kind(GopalaEntityKind.ROAD)):
		var origins: Variant = blueprint.attributes.get("material_origins",{})
		if not origins is Dictionary: return false
		for resource in origins:
			if typeof(resource) != TYPE_STRING_NAME or not resource in GopalaSimulationConfig.RESOURCE_IDS or not origins[resource] is Dictionary: return false
			var reserved := 0
			for id in origins[resource]:
				if not _integer(id,1) or not _amount(origins[resource][id]): return false
				var origin := sim._entity_queries.snapshot(id)
				if origin == null or origin.kind != GopalaEntityKind.BUILDING or str(origin.attributes.get("construction_state","COMPLETED")) != "COMPLETED": return false
				reserved += origins[resource][id]
			if reserved != int(blueprint.attributes.get("reserved_materials",{}).get(resource,0)): return false
		for resource in blueprint.attributes.get("reserved_materials",{}):
			if int(blueprint.attributes.reserved_materials[resource]) > 0 and not origins.has(resource): return false
	return true

func _herd_valid(sim: GopalaSettlementSimulation) -> bool:
	var used_cells := {}
	var grazing_total := 0
	for zone in sim._herd_service.pastures():
		var attrs := zone.attributes
		if attrs.get(&"definition_id") != &"pasture" or not attrs.get(&"zone_cells") is Array or attrs.zone_cells.size() != 16: return false
		for key in [&"grazing_available",&"grazing_consumed",&"cattle_capacity"]:
			if not _amount(attrs.get(key)): return false
		grazing_total += int(attrs.grazing_consumed)
		if attrs.cattle_capacity != 2 or attrs.grazing_available+attrs.grazing_consumed != 16: return false
		var min_cell := Vector2i(1000000,1000000)
		for row in attrs.zone_cells:
			if not row is Array or row.size() != 2 or not _integer(row[0],-1000000) or not _integer(row[1],-1000000): return false
			var cell := Vector2i(row[0],row[1])
			if used_cells.has(cell): return false
			used_cells[cell] = true
			min_cell = Vector2i(mini(min_cell.x,cell.x),mini(min_cell.y,cell.y))
		for cell in sim._herd_service.cells(min_cell):
			if not attrs.zone_cells.has([cell.x,cell.y]): return false
	var eaten_grazing := 0
	for cow in sim._herd_service.animals():
		var attrs := cow.attributes
		if attrs.get(&"species") != &"cattle": return false
		if attrs.get(&"cattle_move_state",&"IDLE") not in [&"IDLE",&"MOVING",&"BLOCKED"]: return false
		if typeof(attrs.get(&"pasture_manual",false)) != TYPE_BOOL: return false
		var pasture_id = attrs.get(&"pasture_id",0)
		if not _amount(pasture_id): return false
		if pasture_id > 0:
			var pasture := sim.entity_queries().snapshot(pasture_id)
			if pasture == null or pasture.kind != GopalaEntityKind.ZONE or sim._herd_service.occupants(pasture_id).size() > 16: return false

		for key in [&"water_fed",&"fodder_fed",&"milk_produced",&"next_milk_tick",&"assigned_herder_id"]:
			if not _amount(attrs.get(key)): return false
		if attrs.water_fed > 1 or attrs.fodder_fed > 1 or not _integer(attrs.get(&"tended_tick"),-1): return false
		var cycle_output := int(sim._survival_service.policy.milk_per_cycle)
		if attrs.milk_produced % cycle_output != 0: return false
		var cycles := int(attrs.milk_produced)/cycle_output
		if not _amount(attrs.get(&"grazing_consumed",0)): return false
		eaten_grazing += int(attrs.get(&"grazing_consumed",0))
		var consumed: Dictionary = attrs.get(&"consumed_goods",{})
		if int(consumed.get(&"water",0)) != cycles+int(attrs.water_fed): return false
		if int(consumed.get(&"fodder",0))+int(attrs.get(&"grazing_consumed",0)) != cycles+int(attrs.fodder_fed): return false
		var source_id: int = attrs.get(&"milk_source_id",0)
		if source_id > 0:
			var source := sim.entity_queries().snapshot(source_id)
			if source == null or source.kind != GopalaEntityKind.RESOURCE_SOURCE or source.attributes.get(&"cow_id") != cow.entity_id or source.attributes.get(&"resource_id") != &"milk" or source.attributes.get(&"generated_amount") != attrs.milk_produced: return false
		var owner := int(attrs.assigned_herder_id)
		if owner > 0:
			var worker := sim.entity_queries().snapshot(owner)
			if worker == null or worker.kind != GopalaEntityKind.VILLAGER or worker.attributes.get(&"herd_target_id") != cow.entity_id or worker.attributes.get(&"task_kind") != &"HERD": return false
	for worker in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER):
		var attrs := worker.attributes
		if attrs.get(&"task_kind") != &"HERD": continue
		var cow := sim.entity_queries().snapshot(int(attrs.get(&"herd_target_id",0)))
		if cow == null or cow.kind != GopalaEntityKind.ANIMAL or cow.attributes.assigned_herder_id != worker.entity_id or attrs.get(&"active_task_id") != cow.entity_id: return false
		if attrs.get(&"task_state") not in [&"HERD_PICKUP",&"HERD_FEED",&"HERD_TEND"] or attrs.get(&"herd_resource") not in [&"",&"water",&"fodder"]: return false
		var feeding: bool = attrs.task_state == &"HERD_FEED"
		if int(attrs.get(&"carried_amount",0)) != (1 if feeding else 0): return false
		if feeding and attrs.get(&"carried_resource_id") != attrs.herd_resource: return false
	return true

func _cell_rows_valid(rows: Variant, expected_count: int) -> bool:
	if not rows is Array or expected_count < 1 or rows.size() != expected_count: return false
	var seen := {}
	for pair in rows:
		if not pair is Array or pair.size() != 2 or not _integer(pair[0],-1000000) or not _integer(pair[1],-1000000): return false
		var cell := Vector2i(pair[0],pair[1])
		if seen.has(cell): return false
		seen[cell] = true
	return true

func _field_tasks_valid(tasks: Dictionary, sim: GopalaSettlementSimulation, next_id: int) -> bool:
	var staffed_fields := {}
	for worker_id in tasks:
		if not _integer(worker_id,1) or not tasks[worker_id] is Dictionary: return false
		var task: Dictionary = tasks[worker_id]
		if task.size() < 8 or task.size() > 9: return false
		var worker := sim.entity_queries().snapshot(worker_id)
		var field_id: Variant = task.get("field_id",0)
		if not _integer(field_id,1): return false
		var field := sim.entity_queries().snapshot(field_id)
		if worker == null or worker.kind != GopalaEntityKind.VILLAGER or field == null or field.kind != GopalaEntityKind.ZONE or field.attributes.get(&"definition_id") != &"field": return false
		if task.get("worker_id") != worker_id or not _integer(task.get("task_id"),1) or task.task_id >= next_id: return false
		if worker.attributes.get(&"active_task_id") != task.task_id or worker.attributes.get(&"task_kind") != &"FIELD" or worker.attributes.get(&"target_building_id") != field_id: return false
		if worker.attributes.get(&"task_state") not in [&"MOVING_TO_FIELD",&"WORKING_FIELD"] or int(worker.attributes.get(&"carried_amount",0)) != 0: return false
		if task.get("state") not in [&"MOVING_TO_FIELD",&"WORKING"]: return false
		if (task.state == &"MOVING_TO_FIELD") != (worker.attributes.get(&"task_state") == &"MOVING_TO_FIELD"): return false
		if task.get("action") not in [&"PLANT",&"TEND",&"HARVEST"] or typeof(task.get("start_stage")) != TYPE_STRING_NAME: return false
		if not _integer(task.get("work")) or not _integer(task.get("created_tick")) or task.created_tick > sim.logical_tick: return false
		if task.has("blocked_revision") and not _integer(task.blocked_revision,-1): return false
		var crop := sim._field_service.crop_definition(field.attributes.get(&"crop_id",&""))
		if crop == null or task.work >= maxi(1,int(field.attributes.get(&"work_required",0))): return false
		if task.action == &"PLANT" and (field.attributes.get(&"field_stage") != &"PREPARING" or task.start_stage != &"PREPARING"): return false
		if task.action == &"TEND" and (field.attributes.get(&"field_stage") not in [&"TENDING",&"GROWING",&"DROUGHT",&"MATURE"] or task.start_stage not in [&"GROWING",&"TENDING",&"DROUGHT"]): return false
		if task.action == &"HARVEST" and (field.attributes.get(&"field_stage") != &"MATURE" or task.start_stage != &"MATURE"): return false
		if staffed_fields.has(field_id): return false
		staffed_fields[field_id] = worker_id
	for worker in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER):
		if worker.attributes.get(&"task_kind") == &"FIELD" and not tasks.has(worker.entity_id): return false
	return true

func _fields_valid(sim: GopalaSettlementSimulation) -> bool:
	var claimed_fields := {}
	for field in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.ZONE):
		if field.attributes.get(&"definition_id") != &"field": continue
		var attrs := field.attributes
		for key in [&"fertility",&"moisture",&"base_moisture"]:
			if typeof(attrs.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(attrs[key])) or float(attrs[key]) < 0.0 or float(attrs[key]) > 1.0: return false
		for key in [&"slope_degrees",&"elevation_metres",&"river_distance_metres"]:
			if typeof(attrs.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(attrs[key])): return false
		for key in [&"growth_started_tick",&"harvest_ready_tick",&"growth_progress_ticks",&"last_growth_tick",&"harvest_count","terrace_riser_count"]:
			if not _integer(attrs.get(key,-1)): return false
		var rows: Variant = attrs.get(&"zone_cells",null)
		if not _cell_rows_valid(rows,16) or not _cell_rows_valid(attrs.get(&"terrace_cells",null),16): return false
		if attrs.zone_cells != attrs.terrace_cells: return false
		var anchor := Vector2i(1000000,1000000)
		for pair in rows:
			var cell := Vector2i(pair[0],pair[1])
			if not sim.coordinate_service().is_in_bounds(cell): return false
			anchor.x = mini(anchor.x,cell.x)
			anchor.y = mini(anchor.y,cell.y)
		var expected := sim._field_service.cells(anchor)
		if expected.size() != rows.size(): return false
		for index in expected.size():
			if rows[index] != [expected[index].x,expected[index].y]: return false
		var claim := sim.occupancy_service().claim_for_owner(field.entity_id)
		if claim == null or claim.state != GopalaOccupancyState.OCCUPIED or claim.cells.size() != expected.size(): return false
		for cell in expected:
			if not claim.cells.has(cell): return false
		claimed_fields[field.entity_id] = true
		for other in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.ZONE):
			if other.entity_id != field.entity_id and other.attributes.get(&"zone_cells",[]).any(func(pair): return rows.has(pair)): return false
		for road in sim.road_service().road_cells():
			if expected.has(road): return false
		if not attrs.get("terrace_levels") is Array or attrs.terrace_levels.size() != GopalaFieldService.FIELD_CELLS.y: return false
		for level in attrs.terrace_levels:
			if typeof(level) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(level)): return false
		var crop_id: StringName = attrs.get(&"crop_id",&"")
		var stage: StringName = attrs.get(&"field_stage",&"FALLOW")
		if crop_id == &"":
			if stage not in [&"FALLOW",&"HARVESTED"] or int(attrs.get(&"growth_progress_ticks",0)) != 0 or int(attrs.get(&"work_required",0)) != 0: return false
		else:
			var crop := sim._field_service.crop_definition(crop_id)
			if crop == null or int(attrs.get(&"work_required",0)) != crop.work_ticks: return false
			if stage not in [&"PREPARING",&"PLANTED",&"GROWING",&"TENDING",&"DROUGHT",&"MATURE"]: return false
			var progress := int(attrs.get(&"growth_progress_ticks",0))
			if progress > crop.growth_ticks or (stage == &"MATURE" and progress < crop.growth_ticks): return false
			if stage != &"PREPARING" and int(attrs.get(&"growth_started_tick",0)) > sim.logical_tick: return false
			if stage == &"PREPARING" and (progress != 0 or int(attrs.get(&"growth_started_tick",0)) != 0): return false
			if stage in [&"PLANTED",&"GROWING",&"TENDING",&"DROUGHT",&"MATURE"] and int(attrs.get(&"harvest_ready_tick",0)) < int(attrs.get(&"growth_started_tick",0)): return false
	return true

func _roads_valid(state: Dictionary, sim: GopalaSettlementSimulation) -> bool:
	var used := {}
	for road in sim._entity_queries.snapshots_by_kind(GopalaEntityKind.ROAD):
		var attrs := road.attributes
		var cells: Variant = attrs.get("road_cells",null)
		if not cells is Array or cells.is_empty(): return false
		for pair in cells:
			if not pair is Array or pair.size() != 2 or not _integer(pair[0],-1000000) or not _integer(pair[1],-1000000): return false
			var cell := Vector2i(pair[0],pair[1])
			if used.has(cell) or not sim.coordinate_service().is_in_bounds(cell): return false
			used[cell] = true
		for pair in attrs.get("cobbled_cells",[]):
			if not cells.has(pair): return false
		var built: Variant = attrs.get("built_cell_count",cells.size())
		if not _amount(built) or built > cells.size(): return false
		if attrs.has("auto_build") and typeof(attrs.auto_build) != TYPE_BOOL: return false
		if not attrs.has("road_job") or attrs.road_job == "": continue # Legacy completed roads.
		if not str(attrs.get("construction_state")) in ["BLUEPRINT","WAITING_FOR_MATERIALS","READY_FOR_LABOR","DELIVERING_MATERIALS","UNDER_CONSTRUCTION","COMPLETED"]: return false
		if attrs.road_job == "cobbled" and built != cells.size(): return false
		if not str(attrs.road_job) in ["dirt","cobbled"]: return false
		var work: Variant = attrs.get("road_work_cells",null)
		if not work is Array or work.is_empty(): return false
		for index in work.size():
			if not cells.has(work[index]) or work.slice(0,index).has(work[index]): return false
			if attrs.road_job == "cobbled" and index > 0 and absi(work[index][0]-work[index-1][0])+absi(work[index][1]-work[index-1][1]) != 1: return false
		var costs := {&"stone":work.size()*2,&"timber":work.size()} if attrs.road_job == "cobbled" else {}
		if attrs.get("required_materials") != costs or attrs.get("work_required") != work.size()*GopalaRoadPlacementService.work_per_cell(road): return false
		if not _amount(attrs.get("work_completed")) or attrs.work_completed > attrs.work_required: return false
		var builder: int = attrs.get("assigned_builder_id",0)
		if builder > 0 and (not state.construction.has(builder) or state.construction[builder].blueprint_id != road.entity_id): return false
		for resource in costs:
			var total: int = int(attrs.get("reserved_materials",{}).get(resource,0)) + int(attrs.get("delivered_materials",{}).get(resource,0))
			if builder > 0:
				var worker := sim._entity_queries.snapshot(builder)
				if worker != null and worker.attributes.get("carried_resource_id") == resource: total += int(worker.attributes.get("carried_amount",0))
			if total > costs[resource]: return false
		if attrs.work_completed > 0:
			for resource in costs:
				if int(attrs.get("delivered_materials",{}).get(resource,0)) != costs[resource]: return false
		if str(attrs.get("construction_state")) == "COMPLETED" and attrs.work_completed != attrs.work_required: return false
	return true
