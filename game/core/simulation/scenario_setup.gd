class_name GopalaScenarioSetup

static func setup_kathmandu_scenario(simulation: GopalaSettlementSimulation, camp_pos: Vector2) -> void:
	var registry = simulation.entity_registry()
	
	var queries = simulation.entity_queries()
	var buildings = queries.snapshots_by_kind(GopalaEntityKind.BUILDING)
	var sources = queries.snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE)
	var villagers = queries.snapshots_by_kind(GopalaEntityKind.VILLAGER)
	
	if buildings.size() > 0 and sources.size() > 0 and villagers.size() > 0:
		return
		
	var to_remove = []
	for e in buildings + sources + villagers:
		to_remove.append(e.entity_id)
	for id in to_remove:
		registry.remove_entity(id, GopalaEntityRegistry.RemovalPolicy.CLEAR_INCOMING_REFERENCES)
		
	var created = []

	var res1 = registry.create_entity(GopalaEntityKind.BUILDING, {
		&"definition_id": &"stockpile",
		&"position_x": camp_pos.x,
		&"position_z": camp_pos.y,
		&"accepts_timber": true,
		&"accepts_stone": true,
		&"storage_capacity": {&"timber":500,&"stone":1000,&"thatch":100,&"water":200,&"wild_food":100,&"fodder":100,&"milk":100},
		&"footprint_cells": [[0,0], [1,0], [0,1], [1,1]],
		&"rotation": 0
	})
	if res1.status != GopalaEntityOperationResult.Status.APPLIED:
		return
	created.append(res1.entity_id)

	var res2 = registry.create_entity(GopalaEntityKind.RESOURCE_SOURCE, {
		&"resource_id": &"timber",
		&"available_amount": 5,
		&"initial_amount": 5,
		&"reserved_amount": 0,
		&"position_x": camp_pos.x + GopalaScaleStandard.number("scenario", "starter_tree_offset"),
		&"position_z": camp_pos.y - GopalaScaleStandard.number("scenario", "starter_tree_offset"),
		&"gatherable": true,
		&"exhausted": false
	})
	if res2.status != GopalaEntityOperationResult.Status.APPLIED:
		_rollback(registry, created)
		return
	created.append(res2.entity_id)
	
	var res3 = registry.create_entity(GopalaEntityKind.VILLAGER, {
		&"position_x": camp_pos.x - GopalaScaleStandard.number("scenario", "worker_offset"),
		&"position_z": camp_pos.y + GopalaScaleStandard.number("scenario", "worker_offset"),
		&"destination_x": camp_pos.x - GopalaScaleStandard.number("scenario", "worker_offset"),
		&"destination_z": camp_pos.y + GopalaScaleStandard.number("scenario", "worker_offset"),
		&"movement_state": &"IDLE",
		&"task_kind": &"NONE",
		&"movement_speed": GopalaScaleStandard.number("movement", "walk_speed"),
		&"updated_tick": 0
	})
	if res3.status != GopalaEntityOperationResult.Status.APPLIED:
		_rollback(registry, created)
		return

static func _rollback(registry, ids: Array) -> void:
	for id in ids:
		registry.remove_entity(id, GopalaEntityRegistry.RemovalPolicy.CLEAR_INCOMING_REFERENCES)
