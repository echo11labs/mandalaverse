class_name GopalaRoadPlacementService
extends Node

## Dirt paths are physical, traversable ground improvements. Their authored cells
## live on a ROAD entity rather than occupancy claims, so workers can walk them.
signal roads_changed

var _coordinates: GopalaSettlementCoordinateService
var _occupancy: GopalaSettlementOccupancyService
var _queries: GopalaEntityQueryService
var _registry: GopalaEntityRegistry
var _routes: GopalaSettlementRouteService
var storage: GopalaStorageService

const DIRT_WORK_PER_CELL := 4
const COBBLED_WORK_PER_CELL := 8
var labor: GopalaConstructionLaborService
var _surface_signature := ""
var _index_dirty := true
var _surface_dirty := true
var _index_cache: Dictionary = {}

const COBBLED_STONE_PER_CELL := 2
const COBBLED_TIMBER_PER_CELL := 1

func configure(coordinates: GopalaSettlementCoordinateService, occupancy: GopalaSettlementOccupancyService, queries: GopalaEntityQueryService, registry: GopalaEntityRegistry, routes: GopalaSettlementRouteService) -> void:
	_coordinates = coordinates
	_occupancy = occupancy
	_queries = queries
	_registry = registry
	_routes = routes
	_registry.entity_removed.connect(_on_entity_removed)
	_registry.transaction_committed.connect(_on_registry_transaction)
	_registry.entity_committed.connect(func(entity: GopalaEntitySnapshot):
		if entity.kind == GopalaEntityKind.ROAD:
			_index_dirty = true
			_surface_dirty = true
	)
	_registry.registry_reset.connect(func():
		_index_dirty = true
		_surface_dirty = true
	)

func _road_cell_index() -> Dictionary:
	if not _index_dirty: return _index_cache
	var cells := {}
	for road in _queries.snapshots_by_kind(GopalaEntityKind.ROAD):
		var cobbled := {}
		for pair in road.attributes.get(&"cobbled_cells", []):
			if pair is Array and pair.size() == 2:
				cobbled[Vector2i(int(pair[0]), int(pair[1]))] = true
		var built := built_cells(road)
		for pair in completed_upgrades(road): cobbled[Vector2i(pair[0], pair[1])] = true
		for pair in road.attributes.get(&"road_cells", []):
			if pair is Array and pair.size() == 2:
				var cell := Vector2i(int(pair[0]), int(pair[1]))
				cells[cell] = {"entity_id": road.entity_id, "quality": (&"cobbled" if cobbled.has(cell) else &"dirt") if built.has(cell) else &"planned"}
	_index_cache = cells
	_index_dirty = false
	return cells

func road_cells() -> Dictionary:
	var cells := {}
	for cell in _road_cell_index(): cells[cell] = true
	return cells

func road_quality_at(cell: Vector2i) -> StringName:
	var record: Dictionary = _road_cell_index().get(cell, {})
	return &"" if record.get("quality") == &"planned" else StringName(record.get("quality", &""))

func road_quality_cells() -> Dictionary:
	var qualities := {}
	var index := _road_cell_index()
	for cell in index:
		if index[cell].quality != &"planned": qualities[cell] = index[cell].quality
	return qualities

func road_cell_size(quality: StringName = &"dirt") -> Vector2:
	var profile := "cobbled_path" if quality == &"cobbled" else "dirt_path"
	return Vector2(GopalaScaleStandard.number(profile, "width"), GopalaScaleStandard.number(profile, "depth"))

func cobbled_cost(cell_count: int) -> Dictionary[StringName, int]:
	return {&"stone": cell_count * COBBLED_STONE_PER_CELL, &"timber": cell_count * COBBLED_TIMBER_PER_CELL}

func validate_cells(cells: Array[Vector2i]) -> GopalaConstructionValidationResult:
	if cells.is_empty():
		return GopalaConstructionValidationResult.new(false, &"EMPTY_PATH", Vector2i.ZERO, [], [])
	if _coordinates == null or not _coordinates.is_configured() or _routes == null or not _routes.enabled:
		return GopalaConstructionValidationResult.new(false, &"GRID_UNCONFIGURED", Vector2i.ZERO, [], [])

	var normalized: Array[Vector2i] = []
	var seen := {}
	for cell in cells:
		if not seen.has(cell):
			seen[cell] = true
			normalized.append(cell)
	if normalized.size() > _coordinates._config.bounds.get_area():
		return GopalaConstructionValidationResult.new(false, &"PATH_TOO_LONG", normalized[0], normalized, [])
	if normalized.size() != cells.size():
		return GopalaConstructionValidationResult.new(false, &"PATH_DUPLICATE_CELL", normalized[0], normalized, [])
	for cell in normalized:
		if not _coordinates.is_in_bounds(cell):
			return GopalaConstructionValidationResult.new(false, &"OUT_OF_BOUNDS", cell, normalized, [cell])
		if not _routes.is_open(cell):
			return GopalaConstructionValidationResult.new(false, &"UNBUILDABLE_GROUND", cell, normalized, [cell])
	for index in range(1, normalized.size()):
		if absi(normalized[index].x - normalized[index - 1].x) + absi(normalized[index].y - normalized[index - 1].y) != 1:
			return GopalaConstructionValidationResult.new(false, &"PATH_DISCONNECTED", normalized[0], normalized, [])

	var existing := road_cells()
	var conflicts: Array[Vector2i] = []
	var new_cells: Array[Vector2i] = []
	for cell in normalized:
		if _occupancy.is_blocked(cell):
			conflicts.append(cell)
			continue
		var pasture_overlap := false
		for zone in _queries.snapshots_by_kind(GopalaEntityKind.ZONE):
			if zone.attributes.get(&"zone_cells", []).has([cell.x, cell.y]):
				pasture_overlap = true
				break
		if pasture_overlap:
			conflicts.append(cell)
		elif not existing.has(cell):
			new_cells.append(cell)
	if not conflicts.is_empty():
		return GopalaConstructionValidationResult.new(false, &"UNBUILDABLE_GROUND", normalized[0], normalized, conflicts)
	if new_cells.is_empty():
		return GopalaConstructionValidationResult.new(false, &"PATH_ALREADY_EXISTS", normalized[0], normalized, [])
	return GopalaConstructionValidationResult.new(true, &"VALID", normalized[0], new_cells, [])

func validate_cobbled_cells(cells: Array[Vector2i]) -> GopalaConstructionValidationResult:
	if cells.is_empty():
		return GopalaConstructionValidationResult.new(false, &"EMPTY_PATH", Vector2i.ZERO, [], [])
	if _coordinates == null or not _coordinates.is_configured() or _routes == null or not _routes.enabled:
		return GopalaConstructionValidationResult.new(false, &"GRID_UNCONFIGURED", Vector2i.ZERO, [], [])
	var seen := {}
	for index in range(cells.size()):
		var cell := cells[index]
		if seen.has(cell):
			return GopalaConstructionValidationResult.new(false, &"PATH_DUPLICATE_CELL", cells[0], cells, [])
		seen[cell] = true
		if not _coordinates.is_in_bounds(cell):
			return GopalaConstructionValidationResult.new(false, &"OUT_OF_BOUNDS", cell, cells, [cell])
		if not _routes.is_open(cell):
			return GopalaConstructionValidationResult.new(false, &"UNBUILDABLE_GROUND", cell, cells, [cell])
		if index > 0 and absi(cell.x - cells[index - 1].x) + absi(cell.y - cells[index - 1].y) != 1:
			return GopalaConstructionValidationResult.new(false, &"PATH_DISCONNECTED", cells[0], cells, [])
	var index_by_cell := _road_cell_index()
	var segment_ids := {}
	for cell in cells:
		if not index_by_cell.has(cell):
			return GopalaConstructionValidationResult.new(false, &"PATH_NOT_FOUND", cell, cells, [cell])
		var road_data: Dictionary = index_by_cell[cell]
		if road_data.quality == &"cobbled":
			return GopalaConstructionValidationResult.new(false, &"PATH_ALREADY_COBBLED", cell, cells, [cell])
		segment_ids[road_data.entity_id] = true
	if segment_ids.size() > 1:
		return GopalaConstructionValidationResult.new(false, &"PATH_SPANS_SEGMENTS", cells[0], cells, [])
	var owner := _queries.snapshot(int(segment_ids.keys()[0]))
	if str(owner.attributes.get("construction_state", "COMPLETED")) != "COMPLETED":
		return GopalaConstructionValidationResult.new(false, &"PATH_WORK_PENDING", cells[0], cells, [])
	var costs := cobbled_cost(cells.size())
	if storage == null or not storage.simulation.can_afford(costs):
		return GopalaConstructionValidationResult.new(false, &"INSUFFICIENT_RESOURCES", cells[0], cells, [])
	return GopalaConstructionValidationResult.new(true, &"VALID", cells[0], cells, [])

func handle_request_cobbled_path(command: GopalaSimulationCommand, tick: int) -> GopalaCommandResult:
	var payload := command.payload
	if payload.size() != 1 or not payload.get("cells") is Array:
		return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, &"INVALID_PAYLOAD", tick, {"command_type": command.command_type})
	var cells: Array[Vector2i] = []
	for pair in payload.cells:
		if not pair is Array or pair.size() != 2 or typeof(pair[0]) != TYPE_INT or typeof(pair[1]) != TYPE_INT:
			return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, &"INVALID_PAYLOAD", tick, {"command_type": command.command_type})
		cells.append(Vector2i(pair[0], pair[1]))
	var validation := validate_cobbled_cells(cells)
	if not validation.valid:
		return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, validation.reason_code, tick, {"command_type": command.command_type})
	var owner_id: int = int(_road_cell_index()[cells[0]].entity_id)
	var road := _queries.snapshot(owner_id)
	var patch := construction_patch(cells, &"cobbled")
	var staging_point := _coordinates.settlement_cell_to_world_xz(cells[0])
	patch[&"position_x"] = staging_point.x
	patch[&"position_z"] = staging_point.y
	patch[&"cobbled_cells"] = road.attributes.get(&"cobbled_cells", [])
	var updated := _registry.update_entity(owner_id, patch, {}, tick, road.revision)
	if updated.status != GopalaEntityOperationResult.Status.APPLIED:
		return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, &"ROAD_UPGRADE_FAILED", tick, {"command_type":command.command_type})
	roads_changed.emit()
	return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.APPLIED, &"PATH_UPGRADE_PLANNED", tick, {"changed":true,"entity_id":owner_id,"cell_count":cells.size(),"stone_cost":cells.size()*2,"timber_cost":cells.size(),"command_type":command.command_type})

func handle_request_road(command: GopalaSimulationCommand, tick: int) -> GopalaCommandResult:
	var payload := command.payload
	if payload.size() != 1 or not payload.get("cells") is Array:
		return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, &"INVALID_PAYLOAD", tick, {"command_type": command.command_type})
	var cells: Array[Vector2i] = []
	for pair in payload.cells:
		if not pair is Array or pair.size() != 2 or typeof(pair[0]) != TYPE_INT or typeof(pair[1]) != TYPE_INT:
			return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, &"INVALID_PAYLOAD", tick, {"command_type": command.command_type})
		cells.append(Vector2i(pair[0], pair[1]))
	var validation := validate_cells(cells)
	if not validation.valid:
		return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, validation.reason_code, tick, {"command_type": command.command_type})
	var rows: Array = []
	for cell in validation.transformed_cells:
		rows.append([cell.x, cell.y])
	var anchor := validation.transformed_cells[0]
	var world := _coordinates.settlement_cell_to_world_xz(anchor)
	var attributes := construction_patch(validation.transformed_cells, &"dirt")
	attributes.merge({&"definition_id":&"dirt_path",&"road_cells":rows,&"position_x":world.x,&"position_z":world.y,&"placed_tick":tick,&"built_cell_count":0})
	var created := _registry.create_entity(GopalaEntityKind.ROAD, attributes, {}, tick)
	if created.status != GopalaEntityOperationResult.Status.APPLIED:
		return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.REJECTED, &"ENTITY_CREATION_FAILED", tick, {"command_type": command.command_type})
	roads_changed.emit()
	return GopalaCommandResult.new(command.command_id, GopalaCommandResult.Status.APPLIED, &"PATH_PLANNED", tick, {"changed": true, "entity_id": created.entity_id, "cell_count": rows.size(), "command_type": command.command_type})

func _on_entity_removed(_entity_id: int, kind: StringName, _sequence: int) -> void:
	if kind == GopalaEntityKind.ROAD:
		_index_dirty = true
		_surface_dirty = true
		roads_changed.emit()

static func construction_patch(cells: Array[Vector2i], quality: StringName) -> Dictionary:
	var rows: Array = []
	for cell in cells: rows.append([cell.x, cell.y])
	return {&"road_work_cells":rows,&"road_job":quality,&"construction_state":&"BLUEPRINT",
		&"work_required":cells.size() * (COBBLED_WORK_PER_CELL if quality == &"cobbled" else DIRT_WORK_PER_CELL),
		&"work_completed":0,&"required_materials":({&"stone":cells.size()*2,&"timber":cells.size()} if quality == &"cobbled" else {}),
		&"reserved_materials":{},&"delivered_materials":{},&"material_origins":{},&"assigned_builder_id":0,&"auto_build":true}

static func work_per_cell(road: GopalaEntitySnapshot) -> int:
	return COBBLED_WORK_PER_CELL if road.attributes.get("road_job") == "cobbled" else DIRT_WORK_PER_CELL

static func completed_work_cells(road: GopalaEntitySnapshot) -> int:
	return floori(float(road.attributes.get("work_completed",0)) / work_per_cell(road))

static func built_cells(road: GopalaEntitySnapshot) -> Dictionary:
	var rows: Array = road.attributes.get("road_cells", [])
	var count: int = int(road.attributes.get("built_cell_count",rows.size()))
	if road.attributes.get("road_job") == "dirt": count = completed_work_cells(road)
	var cells := {}
	for pair in rows.slice(0,count): cells[Vector2i(pair[0],pair[1])] = true
	return cells

static func completed_upgrades(road: GopalaEntitySnapshot) -> Array:
	return road.attributes.get("road_work_cells",[]).slice(0,completed_work_cells(road)) if road.attributes.get("road_job") == "cobbled" else []

static func completion_patch(road: GopalaEntitySnapshot) -> Dictionary:
	var cobbled: Array = road.attributes.get("cobbled_cells",[]).duplicate(true)
	for pair in road.attributes.get("road_work_cells",[]) if road.attributes.get("road_job") == "cobbled" else []:
		if not cobbled.has(pair): cobbled.append(pair)
	return {&"built_cell_count":road.attributes.get("road_cells",[]).size(),&"cobbled_cells":cobbled}

func work_position(road: GopalaEntitySnapshot) -> Vector2:
	var rows: Array = road.attributes.get("road_work_cells",road.attributes.get("road_cells",[]))
	var index := mini(completed_work_cells(road),rows.size()-1)
	if index < 0: return Vector2(road.attributes.position_x,road.attributes.position_z)
	return _coordinates.settlement_cell_to_world_xz(Vector2i(rows[index][0],rows[index][1]))

func _on_registry_transaction(_snapshot: GopalaEntityRegistrySnapshot) -> void:
	if not _surface_dirty: return
	_surface_dirty = false
	var signature := JSON.stringify(_road_cell_index())
	if signature == _surface_signature: return
	_surface_signature = signature
	roads_changed.emit()

func cancel_work(command: GopalaSimulationCommand, tick: int) -> GopalaCommandResult:
	var id: int = command.payload.get("entity_id",0)
	var road := _queries.snapshot(id)
	if road == null or road.kind != GopalaEntityKind.ROAD or str(road.attributes.get("construction_state","COMPLETED")) in ["COMPLETED","CANCELLED"]:
		return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.REJECTED,&"INVALID_STATE",tick,{"command_type":command.command_type})
	# Completed paving is consumed; only unused staged material is recoverable.
	var delivered: Dictionary = road.attributes.get("delivered_materials",{}).duplicate(true)
	var completed := completed_work_cells(road) if road.attributes.get("road_job") == "cobbled" else 0
	for resource in delivered:
		delivered[resource] = maxi(0, int(delivered[resource]) - completed * (2 if str(resource) == "stone" else 1))
	_registry.update_entity(id,{"delivered_materials":delivered},{},tick,road.revision)
	road = _queries.snapshot(id)
	if storage.located: storage.cancel_blueprint(road,tick)
	else:
		var refund: Dictionary[StringName,int] = {}
		for resource in road.attributes.get("reserved_materials",{}): refund[StringName(resource)] = road.attributes.reserved_materials[resource]
		for resource in delivered: refund[StringName(resource)] = int(refund.get(StringName(resource),0)) + delivered[resource]
		if not refund.is_empty(): storage.apply_transaction(refund)
	var builder: int = road.attributes.get("assigned_builder_id",0)
	if builder != 0: labor.cancel_task(builder,tick)
	var built := built_cells(road)
	var retained: Array = []
	for pair in road.attributes.road_cells:
		if built.has(Vector2i(pair[0],pair[1])): retained.append(pair)
	var cobbled: Array = road.attributes.get("cobbled_cells",[]).duplicate(true)
	for pair in completed_upgrades(road):
		if not cobbled.has(pair): cobbled.append(pair)
	if retained.is_empty(): _registry.remove_entity(id,GopalaEntityRegistry.RemovalPolicy.CLEAR_INCOMING_REFERENCES,tick)
	else:
		_registry.update_entity(id,{"road_cells":retained,"built_cell_count":retained.size(),"cobbled_cells":cobbled,"road_job":&"","road_work_cells":[],"construction_state":&"COMPLETED","required_materials":{},"reserved_materials":{},"delivered_materials":{},"material_origins":{},"work_completed":0,"work_required":0,"assigned_builder_id":0},{},tick)
	roads_changed.emit()
	return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.APPLIED,&"PATH_WORK_CANCELLED",tick,{"changed":true,"entity_id":id,"command_type":command.command_type})
