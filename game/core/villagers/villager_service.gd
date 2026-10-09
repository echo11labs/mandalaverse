class_name GopalaVillagerService
extends Node

var _queries: GopalaEntityQueryService
var _registry: GopalaEntityRegistry
var _coordinates: GopalaSettlementCoordinateService
var _config: GopalaSimulationConfig

var _navigation: GopalaSettlementRouteService
var _routes := {}
var last_failure: StringName = &""

var _current_tick: int = 0

## Defensive presentation copy. Never plans/replans a route or advances movement.
func route_snapshot(villager_id: int) -> Dictionary:
	return _routes.get(villager_id,{}).duplicate(true)

func configure(queries: GopalaEntityQueryService, registry: GopalaEntityRegistry, coordinates: GopalaSettlementCoordinateService, config: GopalaSimulationConfig, navigation: GopalaSettlementRouteService = null) -> void:
	_queries = queries
	_registry = registry
	_coordinates = coordinates
	_config = config
	_navigation = navigation
	registry.entity_removed.connect(func(entity_id: int, _kind, _sequence): _routes.erase(entity_id))

func spawn_villager(pos: Vector2) -> int:
	if _registry == null:
		return 0
	
	if not is_finite(pos.x) or not is_finite(pos.y):
		return 0
	
	if _navigation != null and _navigation.enabled and not _navigation.is_open(_coordinates.world_to_settlement_cell(pos)):
		return 0
	var result := _registry.create_entity(GopalaEntityKind.VILLAGER, {
		&"position_x": float(pos.x),
		&"position_z": float(pos.y),
		&"destination_x": float(pos.x),
		&"destination_z": float(pos.y),
		&"movement_state": &"IDLE",
		&"task_kind": &"NONE",
		&"movement_speed": GopalaScaleStandard.number("movement", "walk_speed"), # world units per logical second
		&"updated_tick": 0
	})
	
	if result.status == GopalaEntityOperationResult.Status.APPLIED:
		return result.entity_id
	return 0

func assign_move_task(villager_id: int, target_pos: Vector2) -> bool:
	last_failure = &""
	var entity = _queries.snapshot(villager_id) if _queries != null else null
	if entity == null or entity.attributes.get(&"active_task_id", 0) != 0 or entity.attributes.get(&"carried_amount", 0) > 0 or entity.attributes.get(&"task_kind") == &"NEED":
		return false
	return set_destination(villager_id, target_pos, &"MOVE_DEBUG", 0)

func set_destination(villager_id: int, destination: Vector2, purpose: StringName, task_id: int) -> bool:
	if _registry == null or not _queries.has_entity(villager_id) or not is_finite(destination.x) or not is_finite(destination.y):
		return false
	var entity := _queries.snapshot(villager_id)
	if entity == null or entity.kind != GopalaEntityKind.VILLAGER:
		return false
	
	last_failure = &""
	var route := {}
	if _navigation != null and _navigation.enabled:
		route = _navigation.plan(Vector2(entity.attributes.get(&"position_x",0.0),entity.attributes.get(&"position_z",0.0)),destination,purpose)
		if not route.ok:
			last_failure = route.reason
			if task_id > 0:
				_routes.erase(villager_id)
				_registry.update_entity(villager_id, {&"movement_state": &"BLOCKED", &"movement_failure": last_failure}, {}, maxi(_current_tick, entity.updated_tick), entity.revision)
			return false
	var result := _registry.update_entity(villager_id, {
		&"requested_destination_x": destination.x,
		&"requested_destination_z": destination.y,
		&"destination_x": float(route.destination.x if not route.is_empty() else destination.x),
		&"destination_z": float(route.destination.y if not route.is_empty() else destination.y),
		&"movement_failure": &"",
		&"waypoint_x": float(route.points[0].x if not route.is_empty() else destination.x),
		&"waypoint_z": float(route.points[0].y if not route.is_empty() else destination.y),
		&"movement_state": &"MOVING",
		&"movement_purpose": purpose,
		&"active_task_id": task_id
	}, {}, maxi(_current_tick, entity.updated_tick), entity.revision)
	if result.status == GopalaEntityOperationResult.Status.APPLIED:
		if not route.is_empty():
			route.requested = destination
			route.purpose = purpose
			route.index = 0
			_routes[villager_id] = route
		return true
	return false

func has_arrived(villager_id: int) -> bool:
	if _queries == null or not _queries.has_entity(villager_id):
		return false
	var entity = _queries.snapshot(villager_id)
	if entity == null:
		return false
	var state = entity.attributes.get(&"movement_state", &"IDLE")
	return state == &"ARRIVED" or state == &"IDLE"

func stop(villager_id: int, reason: StringName) -> void:
	_routes.erase(villager_id)
	if _registry == null or not _queries.has_entity(villager_id):
		return
	var entity = _queries.snapshot(villager_id)
	if entity == null: return
	_registry.update_entity(villager_id, {
		&"movement_state": &"IDLE",
		&"movement_purpose": &"NONE",
		&"destination_x": entity.attributes.get(&"position_x", 0.0),
		&"destination_z": entity.attributes.get(&"position_z", 0.0)
	}, {}, maxi(_current_tick, entity.updated_tick), entity.revision)

func tick(logical_tick: int) -> void:
	_current_tick = logical_tick
	if _registry == null or _queries == null:
		return
	
	var all_villagers = _queries.snapshots_by_kind(GopalaEntityKind.VILLAGER)
	for entity in all_villagers:
		if entity == null: continue
		var attrs = entity.attributes
		
		var state = attrs.get(&"movement_state", &"IDLE")
		if state != &"MOVING":
			continue
			
		var pos_x: float = attrs.get(&"position_x", 0.0)
		var pos_z: float = attrs.get(&"position_z", 0.0)
		var dest_x: float = attrs.get(&"destination_x", 0.0)
		var dest_z: float = attrs.get(&"destination_z", 0.0)
		var speed: float = attrs.get(&"movement_speed", GopalaScaleStandard.number("movement", "walk_speed"))
		var purpose = attrs.get(&"movement_purpose", &"NONE")
		
		var pos := Vector2(pos_x, pos_z)
		var dest := Vector2(dest_x, dest_z)
		
		var sim_delta := _config.tick_interval_seconds if _config != null else 1.0
		var move_dist := speed * sim_delta
		if _routes.has(entity.entity_id):
			var route: Dictionary = _routes[entity.entity_id]
			if route.revision != _navigation.revision:
				var replanned := _navigation.plan(pos,route.requested,route.purpose)
				if not replanned.ok:
					_routes.erase(entity.entity_id)
					_registry.update_entity(entity.entity_id, {&"movement_state": &"BLOCKED", &"movement_failure": replanned.reason}, {}, logical_tick, entity.revision)
					continue
				replanned.requested = route.requested
				replanned.purpose = route.purpose
				replanned.index = 0
				route = replanned
				_routes[entity.entity_id] = route
			var budget := move_dist
			while route.index < route.points.size() and budget > 0.0:
				var waypoint: Vector2 = route.points[route.index]
				var distance := pos.distance_to(waypoint)
				if distance <= budget:
					pos = waypoint
					budget -= distance
					route.index += 1
				else:
					pos = pos.move_toward(waypoint,budget)
					budget = 0.0
			var finished: bool = route.index >= route.points.size()
			var waypoint: Vector2 = route.destination if finished else route.points[route.index]
			_registry.update_entity(entity.entity_id, {&"position_x":pos.x,&"position_z":pos.y,&"destination_x":route.destination.x,&"destination_z":route.destination.y,&"waypoint_x":waypoint.x,&"waypoint_z":waypoint.y,&"movement_state": &"IDLE" if finished and purpose == &"MOVE_DEBUG" else (&"ARRIVED" if finished else &"MOVING"),&"updated_tick":logical_tick}, {}, logical_tick,entity.revision)
			if finished: _routes.erase(entity.entity_id)
			continue
		var dist := pos.distance_to(dest)

		if dist <= move_dist:
			# Arrived exactly at destination
			var updates = {
				&"position_x": dest.x,
				&"position_z": dest.y,
				&"movement_state": &"ARRIVED",
				&"updated_tick": logical_tick
			}
			# Debug movement automatically clears task state upon arrival. 
			# Purpose-driven movement preserves task ownership.
			if purpose == &"MOVE_DEBUG":
				updates[&"task_kind"] = &"NONE"
				updates[&"movement_state"] = &"IDLE"
			_registry.update_entity(entity.entity_id, updates, {}, logical_tick, entity.revision)
		else:
			# Move towards destination
			var dir = (dest - pos).normalized()
			var new_pos = pos + dir * move_dist
			var result = _registry.update_entity(entity.entity_id, {
				&"position_x": float(new_pos.x),
				&"position_z": float(new_pos.y),
				&"updated_tick": logical_tick
			}, {}, logical_tick, entity.revision)
			if result.status != GopalaEntityOperationResult.Status.APPLIED:
				push_warning("Villager movement update failed! Status: ", result.status, " Reason: ", result.reason_code, " Expected Rev: ", entity.revision)

func reset() -> void:
	_routes.clear()
	_current_tick = 0
	last_failure = &""
