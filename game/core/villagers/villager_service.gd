class_name GopalaVillagerService
extends Node

var _queries: GopalaEntityQueryService
var _registry: GopalaEntityRegistry
var _coordinates: GopalaSettlementCoordinateService
var _config: GopalaSimulationConfig

func configure(queries: GopalaEntityQueryService, registry: GopalaEntityRegistry, coordinates: GopalaSettlementCoordinateService, config: GopalaSimulationConfig) -> void:
	_queries = queries
	_registry = registry
	_coordinates = coordinates
	_config = config

func spawn_villager(pos: Vector2) -> int:
	if _registry == null:
		return 0
	
	if not is_finite(pos.x) or not is_finite(pos.y):
		return 0
	
	var result := _registry.create_entity(GopalaEntityKind.VILLAGER, {
		&"position_x": float(pos.x),
		&"position_z": float(pos.y),
		&"destination_x": float(pos.x),
		&"destination_z": float(pos.y),
		&"movement_state": &"IDLE",
		&"task_kind": &"NONE",
		&"movement_speed": 12.0, # distance per logical second
		&"updated_tick": 0
	})
	
	if result.status == GopalaEntityOperationResult.Status.APPLIED:
		return result.entity_id
	return 0

func assign_move_task(villager_id: int, target_pos: Vector2) -> bool:
	if _registry == null or not _queries.has_entity(villager_id):
		return false
	var entity := _queries.snapshot(villager_id)
	if entity == null or entity.kind != GopalaEntityKind.VILLAGER:
		return false
	
	var result := _registry.update_entity(villager_id, {
		&"destination_x": float(target_pos.x),
		&"destination_z": float(target_pos.y),
		&"movement_state": &"MOVING",
		&"task_kind": &"MOVE_DEBUG"
	}, {}, entity.revision)
	return result.status == GopalaEntityOperationResult.Status.APPLIED

func tick(logical_tick: int) -> void:
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
		var speed: float = attrs.get(&"movement_speed", 12.0)
		
		var pos := Vector2(pos_x, pos_z)
		var dest := Vector2(dest_x, dest_z)
		
		var dist := pos.distance_to(dest)
		var sim_delta := _config.tick_interval_seconds if _config != null else 1.0
		var move_dist := speed * sim_delta
		
		if dist <= move_dist:
			# Arrived exactly at destination
			_registry.update_entity(entity.entity_id, {
				&"position_x": dest.x,
				&"position_z": dest.y,
				&"movement_state": &"IDLE",
				&"task_kind": &"NONE",
				&"updated_tick": logical_tick
			}, {}, entity.revision)
		else:
			# Move towards destination
			var dir = (dest - pos).normalized()
			var new_pos = pos + dir * move_dist
			_registry.update_entity(entity.entity_id, {
				&"position_x": float(new_pos.x),
				&"position_z": float(new_pos.y),
				&"updated_tick": logical_tick
			}, {}, entity.revision)
