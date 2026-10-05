class_name GopalaConstructionPlacementService
extends Node

var _ledger: GopalaResourceLedger
var _occupancy: GopalaSettlementOccupancyService
var _registry: GopalaEntityRegistry
var _coordinates: GopalaSettlementCoordinateService
var _buildings: Dictionary = {}

func configure(ledger: GopalaResourceLedger, occupancy: GopalaSettlementOccupancyService, registry: GopalaEntityRegistry, coordinates: GopalaSettlementCoordinateService) -> void:
	_ledger = ledger
	_occupancy = occupancy
	_registry = registry
	_coordinates = coordinates
	
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	if catalog and catalog.has("buildings"):
		for path in catalog.get("buildings"):
			var def = load(path)
			if def != null and def is GopalaBuildingDefinition:
				_buildings[def.id] = def

func get_building(id: StringName) -> GopalaBuildingDefinition:
	return _buildings.get(id)

func get_footprint_offsets(size: Vector2i) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for y in range(size.y):
		for x in range(size.x):
			offsets.append(Vector2i(x, y))
	return offsets

func validate_placement(building_id: StringName, anchor_cell: Vector2i, rotation_steps: int) -> GopalaConstructionValidationResult:
	var def := get_building(building_id)
	if def == null:
		return GopalaConstructionValidationResult.new(false, &"UNKNOWN_BUILDING", anchor_cell, [], [])
		
	var offsets := get_footprint_offsets(def.footprint)
	var cells := GopalaFootprintTransform.transform_footprint(offsets, rotation_steps, anchor_cell)
	
	if cells.is_empty() and not offsets.is_empty():
		return GopalaConstructionValidationResult.new(false, &"INVALID_FOOTPRINT", anchor_cell, cells, [])
	
	if not _coordinates.cells_in_bounds(cells):
		return GopalaConstructionValidationResult.new(false, &"OUT_OF_BOUNDS", anchor_cell, cells, [])
		
	var probe = _occupancy.probe_cells(cells)
	if not probe.valid:
		return GopalaConstructionValidationResult.new(false, &"OCCUPIED", anchor_cell, cells, probe.conflicting_cells)
		
	if not _ledger.can_afford(def.costs):
		return GopalaConstructionValidationResult.new(false, &"INSUFFICIENT_RESOURCES", anchor_cell, cells, [])
		
	return GopalaConstructionValidationResult.new(true, &"VALID", anchor_cell, cells, [])

func handle_request_construction(command: GopalaSimulationCommand, current_tick: int) -> GopalaCommandResult:
	var payload = command.payload
	var building_id: StringName = StringName(payload.get("building_id", ""))
	var cell_x: int = payload.get("cell_x", 0)
	var cell_y: int = payload.get("cell_y", 0)
	var anchor_cell = Vector2i(cell_x, cell_y)
	var rotation_steps: int = payload.get("rotation", 0)
	
	var validation := validate_placement(building_id, anchor_cell, rotation_steps)
	if not validation.valid:
		return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, validation.reason_code, current_tick, {"command_type": command.command_type})
		
	var def := get_building(building_id)
	var costs := def.costs
	
	var neg_costs = {}
	for k in costs:
		neg_costs[k] = -costs[k]
		
	if not _ledger.apply_authorized_transaction(neg_costs):
		return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, &"INSUFFICIENT_RESOURCES", current_tick, {"command_type": command.command_type})
		
	var footprint_cells_array = []
	for c in validation.transformed_cells:
		footprint_cells_array.append([c.x, c.y])
		
	var attributes = {
		"definition_id": building_id,
		"anchor_cell_x": anchor_cell.x,
		"anchor_cell_y": anchor_cell.y,
		"rotation": rotation_steps,
		"display_name": def.display_name,
		"construction_state": "completed",
		"placed_tick": current_tick,
		"footprint_cells": footprint_cells_array
	}
	
	var res = _registry.create_entity(&"building", attributes, {}, current_tick)
	if res.status != GopalaEntityOperationResult.Status.APPLIED:
		_ledger.apply_authorized_transaction(costs)
		return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, &"ENTITY_CREATION_FAILED", current_tick, {"command_type": command.command_type})
		
	var entity_id: int = res.entity_id
	var claim_res = _occupancy.reserve_cells(entity_id, validation.transformed_cells, current_tick)
	if claim_res.status != GopalaOccupancyOperationResult.Status.APPLIED:
		_registry.remove_entity(entity_id, GopalaEntityRegistry.RemovalPolicy.CLEAR_INCOMING_REFERENCES, current_tick)
		_ledger.apply_authorized_transaction(costs)
		return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, &"OCCUPIED", current_tick, {"command_type": command.command_type})
		
	_occupancy.commit_reservation(entity_id, current_tick)
		
	return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.APPLIED, &"REASON_APPLIED", current_tick, {"entity_id": entity_id, "changed": true, "command_type": command.command_type})
