class_name GopalaDebugInspection
extends RefCounted
## Plain defensive inspection data. No commands, ticks, reservations or route planning.
static func selected(sim: GopalaSettlementSimulation) -> Dictionary:
	var id := sim.selection_service().selected_entity_id
	var entity := sim.entity_queries().snapshot(id)
	if entity == null: return {}
	var result := {"id":id,"kind":str(entity.kind),"attributes":entity.attributes.duplicate(true)}
	if entity.kind == GopalaEntityKind.VILLAGER:
		result.route = sim.villager_service().route_snapshot(id)
		result.gather = sim.gather_delivery_service()._tasks.get(id,{}).duplicate(true)
		result.construction = sim._construction_labor_service._tasks.get(id,{}).duplicate(true)
		var a: Dictionary = result.attributes
		result.reason = str(a.get(&"movement_failure",&"")) if a.get(&"movement_state") == &"BLOCKED" else str(a.get(&"job_status",a.get(&"need_state",a.get(&"task_state",&"IDLE"))))
		result.path = remaining_path(a,result.route)
	elif entity.kind == GopalaEntityKind.BUILDING:
		var a: Dictionary = result.attributes
		result.inventory = sim._storage_service.stocks.get(id,{}).duplicate(true)
		result.reservations = {}
		result.promises = {}
		result.shortages = {}
		for resource in sim.resource_balances_snapshot():
			result.reservations[resource] = sim._storage_service.reserved_at(id,resource)
			result.promises[resource] = sim._storage_service.incoming_at(id,resource)
		for resource in a.get("required_materials",{}):
			var reserved := int(a.get("reserved_materials",{}).get(resource,0))
			var delivered := int(a.get("delivered_materials",{}).get(resource,0))
			result.shortages[resource] = maxi(0,int(a.required_materials[resource])-delivered-reserved)
		result.site_reserved = a.get("reserved_materials",{}).duplicate(true)
		result.site_delivered = a.get("delivered_materials",{}).duplicate(true)
		result.site_promises = a.get("material_origins",{}).duplicate(true)
	return result

static func remaining_path(attributes: Dictionary, route: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if route.is_empty(): return result
	result.append(Vector2(float(attributes.get(&"position_x",0.0)),float(attributes.get(&"position_z",0.0))))
	for index in range(int(route.get("index",0)),route.get("points",[]).size()): result.append(route.points[index])
	return result

static func format(data: Dictionary) -> String:
	if data.is_empty(): return "Select a villager, store or construction site to inspect it."
	var a: Dictionary = data.attributes
	var lines: Array[String] = ["Selected #%d · %s" % [data.id,data.kind]]
	if data.has("route"):
		lines.append("Job: %s · status: %s" % [a.get(&"work_role",&"NONE"),a.get(&"job_status",&"IDLE")])
		lines.append("Movement: %s · task: %s / %s" % [a.get(&"movement_state",&"IDLE"),a.get(&"task_kind",&"NONE"),a.get(&"task_state",&"IDLE")])
		lines.append("Waiting/status reason: %s" % data.reason)
		lines.append("Carried: %s × %d" % [a.get(&"carried_resource_id",a.get(&"carried_resource",&"NONE")),int(a.get(&"carried_amount",0))])
		lines.append("Gather reservation/task: "+str(data.gather))
		lines.append("Build reservation/task: "+str(data.construction))
		lines.append("Remaining route: %d points · revision %s" % [data.path.size(),data.route.get("revision","none")])
	elif data.has("inventory"):
		lines.append("Inventory: "+str(data.inventory))
		lines.append("Store outgoing reservations: "+str(data.reservations))
		lines.append("Store incoming promises: "+str(data.promises))
		lines.append("Site delivered: "+str(data.site_delivered))
		lines.append("Site reserved: "+str(data.site_reserved))
		lines.append("Site promises by source store: "+str(data.site_promises))
		lines.append("Unreserved shortages: "+str(data.shortages))
	else: lines.append(str(a))
	return "\n".join(lines)
