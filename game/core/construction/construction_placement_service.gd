class_name GopalaConstructionPlacementService
extends Node
var storage: GopalaStorageService

var _ledger: GopalaResourceLedger
var _occupancy: GopalaSettlementOccupancyService
var _registry: GopalaEntityRegistry
var _coordinates: GopalaSettlementCoordinateService
var routes: GopalaSettlementRouteService
var _labor_service: GopalaConstructionLaborService
var _buildings: Dictionary = {}

func configure(ledger: GopalaResourceLedger, occupancy: GopalaSettlementOccupancyService, registry: GopalaEntityRegistry, coordinates: GopalaSettlementCoordinateService, labor: GopalaConstructionLaborService = null) -> void:
	_ledger = ledger
	_occupancy = occupancy
	_registry = registry
	_coordinates = coordinates
	_labor_service = labor
	
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
		
	for zone in _registry.snapshots_by_kind(GopalaEntityKind.ZONE):
		for cell in cells:
			if zone.attributes.get(&"zone_cells",[]).has([cell.x,cell.y]):
				return GopalaConstructionValidationResult.new(false,&"PASTURE_OCCUPIED",anchor_cell,cells,[cell])
	var probe = _occupancy.probe_cells(cells)
	if not probe.valid:
		return GopalaConstructionValidationResult.new(false, &"OCCUPIED", anchor_cell, cells, probe.conflicting_cells)
		
	if routes != null and routes.enabled:
		for cell in cells:
			if not routes.is_open(cell):
				return GopalaConstructionValidationResult.new(false, &"UNBUILDABLE_GROUND",anchor_cell,cells,[cell])
		for worker in _registry.snapshots_by_kind(GopalaEntityKind.VILLAGER):
			var position := Vector2(worker.attributes.get(&"position_x",0.0),worker.attributes.get(&"position_z",0.0))
			if cells.has(_coordinates.world_to_settlement_cell(position)):
				return GopalaConstructionValidationResult.new(false,&"VILLAGER_IN_FOOTPRINT",anchor_cell,cells,[])

		for animal in _registry.snapshots_by_kind(GopalaEntityKind.ANIMAL):
			var position := Vector2(animal.attributes.get(&"position_x",0.0),animal.attributes.get(&"position_z",0.0))
			if cells.has(_coordinates.world_to_settlement_cell(position)):
				return GopalaConstructionValidationResult.new(false,&"CATTLE_IN_FOOTPRINT",anchor_cell,cells,[])

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
	var footprint_cells_array = []
	for c in validation.transformed_cells:
		footprint_cells_array.append([c.x, c.y])
	
	var anchor_world := _coordinates.settlement_cell_to_world_xz(anchor_cell) if _coordinates != null else Vector2(0, 0)
		
	var attributes = {
		"definition_id": building_id,
		"anchor_cell_x": anchor_cell.x,
		"anchor_cell_y": anchor_cell.y,
		"position_x": anchor_world.x,
		"position_z": anchor_world.y,
		"rotation": rotation_steps,
		"display_name": def.display_name,
		"construction_state": "BLUEPRINT",
		"work_required": def.work_ticks,
		"work_completed": 0,
		"required_materials": def.costs.duplicate(),
		"reserved_materials": {},
		"delivered_materials": {},
		"assigned_builder_id": 0,
		"placed_tick": current_tick,
		"footprint_cells": footprint_cells_array
	}
	
	var res = _registry.create_entity(&"building", attributes, {}, current_tick)
	if res.status != GopalaEntityOperationResult.Status.APPLIED:
		return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, &"ENTITY_CREATION_FAILED", current_tick, {"command_type": command.command_type})
		
	var entity_id: int = res.entity_id
	var claim_res = _occupancy.reserve_cells(entity_id, validation.transformed_cells, current_tick)
	if claim_res.status != GopalaOccupancyOperationResult.Status.APPLIED:
		_registry.remove_entity(entity_id, GopalaEntityRegistry.RemovalPolicy.CLEAR_INCOMING_REFERENCES, current_tick)
		return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, &"OCCUPIED", current_tick, {"command_type": command.command_type})
		
	_occupancy.commit_reservation(entity_id, current_tick)
		
	return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.APPLIED, &"REASON_APPLIED", current_tick, {"entity_id": entity_id, "changed": true, "command_type": command.command_type})

func handle_request_cancel_construction(command: GopalaSimulationCommand, current_tick: int) -> GopalaCommandResult:
	var payload = command.payload
	var entity_id: int = payload.get("entity_id", -1)
	if entity_id <= 0 or not _registry.has_entity(entity_id):
		return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, &"INVALID_ENTITY", current_tick, {"command_type": command.command_type})
		
	var blueprint = _registry.snapshot(entity_id)
	if blueprint == null or blueprint.kind != &"building":
		return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, &"INVALID_ENTITY", current_tick, {"command_type": command.command_type})
		
	var state = blueprint.attributes.get("construction_state", "")
	if state == "COMPLETED" or state == "CANCELLED":
		return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, &"INVALID_STATE", current_tick, {"command_type": command.command_type})
		
	# Refund reserved materials back to ledger
	var refund: Dictionary[StringName, int] = {}
	var reserved = blueprint.attributes.get("reserved_materials", {})
	for mat in reserved:
		var amt = int(reserved[mat])
		if amt > 0:
			refund[StringName(mat)] = refund.get(StringName(mat), 0) + amt
		
	# Refund delivered materials back to ledger
	var delivered = blueprint.attributes.get("delivered_materials", {})
	for mat in delivered:
		var amt = int(delivered[mat])
		if amt > 0:
			refund[StringName(mat)] = refund.get(StringName(mat), 0) + amt
			
	if storage != null and storage.located:
		storage.cancel_blueprint(blueprint,current_tick)
	elif not refund.is_empty():
		_ledger.apply_authorized_transaction(refund)
		
	# Release occupancy claims
	if _occupancy != null and _occupancy._claims.has(entity_id):
		_occupancy.release_claim(entity_id, GopalaOccupancyOperationResult.RELEASED, current_tick)
	
	# Cancel assigned builder task if present
	var assigned_builder_id = blueprint.attributes.get("assigned_builder_id", 0)
	if assigned_builder_id > 0 and _labor_service != null:
		_labor_service.cancel_task(assigned_builder_id, current_tick)

	# Mark as cancelled and remove entity
	_registry.update_entity(entity_id, {"construction_state": "CANCELLED"}, {}, current_tick, blueprint.revision)
	_registry.remove_entity(entity_id, GopalaEntityRegistry.RemovalPolicy.CLEAR_INCOMING_REFERENCES, current_tick)
	
	return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.APPLIED, &"REASON_APPLIED", current_tick, {"entity_id": entity_id, "changed": true, "command_type": command.command_type})
