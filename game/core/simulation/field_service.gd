class_name GopalaFieldService
extends RefCounted
## Fields own a deterministic terrace and crop record; views never drive production.
const FIELD_CELLS := Vector2i(4, 4)
const MAX_TERRACE_SLOPE_DEGREES := 12.0
const MAX_RIVER_DISTANCE_METRES := 1000.0
const MIN_RIVER_DISTANCE_METRES := 30.0
const MAX_ELEVATION_METRES := 1550.0
const MAX_SINGLE_CELL_RIVER_DISTANCE_METRES := 1200.0
# Climate cycle length is shared with the existing deterministic moisture model.
const CLIMATE_YEAR_TICKS := 7200
const SEASON_TICKS := CLIMATE_YEAR_TICKS / 4
const SEASONS: Array[String] = ["Dry", "Pre-monsoon", "Monsoon", "Cool/dry"]
const CROP_PATHS := {
	&"cereal": "res://data/crops/cereal.tres",
	&"fodder_crop": "res://data/crops/fodder_crop.tres",
}

var simulation: GopalaSettlementSimulation
var terrain: GopalaKathmanduTerrain
func _init(sim: GopalaSettlementSimulation, landscape: GopalaKathmanduTerrain = null) -> void:
	simulation = sim
	terrain = landscape

func configure_terrain(landscape: GopalaKathmanduTerrain) -> void:
	terrain = landscape

func fields() -> Array[GopalaEntitySnapshot]:
	return simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.ZONE).filter(func(field): return field.attributes.get(&"definition_id") == &"field")

func food_stock() -> int:
	return simulation.resource_amount(&"wild_food") + simulation.resource_amount(&"milk") + simulation.resource_amount(&"grain")

func _zone_rows_valid(value: Variant) -> bool:
	if not value is Array or value.size() != FIELD_CELLS.x * FIELD_CELLS.y: return false
	var seen := {}
	for row in value:
		if not row is Array or row.size() != 2 or typeof(row[0]) != TYPE_INT or typeof(row[1]) != TYPE_INT: return false
		var cell := Vector2i(row[0],row[1])
		if seen.has(cell): return false
		seen[cell] = true
	return true

func _on_entity_removed(entity_id: int, kind: StringName, _sequence: int) -> void:
	if kind == GopalaEntityKind.ZONE:
		for task_id in _tasks.keys():
			if int(_tasks[task_id].get("field_id",0)) == entity_id: cancel_worker(int(task_id),simulation.logical_tick,false)
	elif kind == GopalaEntityKind.VILLAGER:
		_tasks.erase(entity_id)

func field_work_required(field: GopalaEntitySnapshot) -> int:
	return int(field.attributes.get("work_required",1))

func harvest_output(field: GopalaEntitySnapshot, crop: GopalaCropDefinition) -> int:
	var fertility := clampf(float(field.attributes.get("fertility",0.0)),0.0,1.0)
	var moisture := clampf(float(field.attributes.get("moisture",0.0)),0.0,1.0)
	var quality := clampf(fertility*0.7+moisture*0.3,0.25,1.0)
	return maxi(1,int(round(float(crop.yield_amount)*quality)))

## Read-only player-facing outlook. The yield is an estimate at current soil
## conditions; productive ticks can pause while moisture is below crop minimum.
func crop_outlook(field: GopalaEntitySnapshot, tick: int) -> Dictionary:
	var crop := crop_definition(field.attributes.get(&"crop_id",&""))
	if crop == null: return {}
	var fertility := clampf(float(field.attributes.get(&"fertility",0.0)),0.0,1.0)
	var moisture := clampf(float(field.attributes.get(&"moisture",0.0)),0.0,1.0)
	var progress := clampi(int(field.attributes.get(&"growth_progress_ticks",0)),0,crop.growth_ticks)
	var stage: StringName = field.attributes.get(&"field_stage",&"FALLOW")
	var growth_started := stage in [&"PLANTED",&"GROWING",&"TENDING",&"DROUGHT",&"MATURE"]
	var remaining := maxi(0,crop.growth_ticks-progress)
	return {
		"fertility": fertility,
		"fertility_suitable": fertility >= crop.minimum_fertility,
		"minimum_fertility": crop.minimum_fertility,
		"moisture": moisture,
		"moisture_suitable": moisture >= crop.minimum_moisture,
		"minimum_moisture": crop.minimum_moisture,
		"growth_percent": roundi(float(progress)/float(crop.growth_ticks)*100.0),
		"productive_ticks_remaining": remaining,
		"growth_started": growth_started,
		"growth_paused": growth_started and stage != &"MATURE" and moisture < crop.minimum_moisture,
		"earliest_ready_tick": tick+remaining,
		"estimated_yield": harvest_output(field,crop),
		"harvest_resource": crop.harvest_resource,
	}

## Seasonal names and midpoint moisture forecasts use the same climate curve as
## field growth, so player advice cannot drift from the authoritative simulation.
func seasonal_outlook(field: GopalaEntitySnapshot, tick: int) -> Dictionary:
	var year_tick := posmod(tick,CLIMATE_YEAR_TICKS)
	var season_index := mini(year_tick / SEASON_TICKS,SEASONS.size()-1)
	var next_index := (season_index+1)%SEASONS.size()
	var year_start := tick-year_tick
	var next_year_start := year_start + (CLIMATE_YEAR_TICKS if next_index == 0 else 0)
	var next_midpoint := next_year_start+next_index*SEASON_TICKS+SEASON_TICKS/2
	var current_target := _seasonal_moisture(field,tick)
	var next_target := _seasonal_moisture(field,next_midpoint)
	var trend := "wetter" if next_target-current_target > 0.05 else ("drier" if current_target-next_target > 0.05 else "similar")
	return {
		"current_season": SEASONS[season_index],
		"next_season": SEASONS[next_index],
		"next_season_tick": next_year_start+next_index*SEASON_TICKS,
		"next_season_moisture": next_target,
		"moisture_trend": trend,
	}

func _task_state_valid(task: Dictionary) -> bool:
	if task.size() != 8: return false
	if task.size() != 8 or typeof(task.get("task_id")) != TYPE_INT or task.task_id < 1: return false
	if typeof(task.get("worker_id")) != TYPE_INT or typeof(task.get("field_id")) != TYPE_INT: return false
	if task.get("action") not in [&"PLANT",&"TEND",&"HARVEST"] or typeof(task.get("start_stage")) != TYPE_STRING_NAME: return false
	if task.get("state") not in [&"MOVING_TO_FIELD",&"WORKING"]: return false
	if typeof(task.get("work")) != TYPE_INT or task.work < 0 or typeof(task.get("created_tick")) != TYPE_INT or task.created_tick < 0: return false
	return true

func validate_tasks(tasks: Variant, next_id: int, sim: GopalaSettlementSimulation) -> bool:
	if not tasks is Dictionary or next_id < 1: return false
	var staffed_fields := {}
	for worker_id in tasks:
		if typeof(worker_id) != TYPE_INT or worker_id < 1 or not tasks[worker_id] is Dictionary: return false
		var task: Dictionary = tasks[worker_id]
		if not _task_state_valid(task) or task.worker_id != worker_id or task.task_id >= next_id: return false
		var worker := sim.entity_queries().snapshot(worker_id)
		var field := sim.entity_queries().snapshot(task.field_id)
		if worker == null or worker.kind != GopalaEntityKind.VILLAGER or field == null or field.kind != GopalaEntityKind.ZONE or field.attributes.get(&"definition_id") != &"field": return false
		if worker.attributes.get(&"active_task_id",0) != task.task_id or worker.attributes.get(&"task_kind") != &"FIELD" or worker.attributes.get(&"target_building_id") != task.field_id: return false
		if worker.attributes.get(&"task_state") != (&"MOVING_TO_FIELD" if task.state == &"MOVING_TO_FIELD" else &"WORKING_FIELD"): return false
		if int(worker.attributes.get(&"carried_amount",0)) != 0 or task.created_tick > sim.logical_tick: return false
		if staffed_fields.has(task.field_id): return false
		staffed_fields[task.field_id] = true
		var crop := crop_definition(field.attributes.get(&"crop_id",&""))
		if crop == null or task.work >= int(field.attributes.get(&"work_required",0)): return false
		if task.action == &"PLANT" and field.attributes.get(&"field_stage") != &"PREPARING": return false
		if task.action == &"TEND" and (field.attributes.get(&"field_stage") not in [&"TENDING",&"GROWING",&"DROUGHT",&"MATURE"] or task.start_stage not in [&"GROWING",&"TENDING",&"DROUGHT"]): return false
		if task.action == &"HARVEST" and field.attributes.get(&"field_stage") != &"MATURE": return false
	for worker in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER):
		if worker.attributes.get(&"task_kind") == &"FIELD" and not tasks.has(worker.entity_id): return false
	return true

func _terrain_baseline_at(point: Vector2) -> float:
	return terrain.height_at(point.x,point.y) if _has_terrain() else 0.0

func _terrain_normal_at(point: Vector2) -> Vector3:
	return terrain.normal_at(point.x,point.y,true) if _has_terrain() else Vector3.UP

func _terrain_elevation_at(point: Vector2) -> float:
	return terrain.elevation_at(point.x,point.y) if _has_terrain() else 1300.0

func _terrain_river_distance_at(point: Vector2) -> float:
	return terrain.river_distance(point.x,point.y) if _has_terrain() else 500.0

func _terrain_height_metres(height: float) -> float:
	return height / GopalaKathmanduTerrain.RELIEF * GopalaKathmanduTerrain.METRES_PER_UNIT

func _existing_zone_overlaps(area: Array[Vector2i]) -> bool:
	for zone in simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.ZONE):
		for cell in area:
			if zone.attributes.get(&"zone_cells",[]).has([cell.x,cell.y]): return true
	return false

func _existing_road_overlaps(area: Array[Vector2i]) -> bool:
	var road_cells := simulation.road_service().road_cells()
	for cell in area:
		if road_cells.has(cell): return true
	return false

func _cell_slope_at(point: Vector2) -> float:
	return rad_to_deg(acos(clampf(_terrain_normal_at(point).y,-1.0,1.0)))

func _valid_terrain_patch(area: Array[Vector2i]) -> Dictionary:
	for cell in area:
		var point := simulation.coordinate_service().settlement_cell_to_world_xz(cell)
		var river_distance := _terrain_river_distance_at(point)
		if river_distance < MIN_RIVER_DISTANCE_METRES: return {"ok":false,"reason":&"FLOODPLAIN_UNSAFE","cell":cell}
		if river_distance > MAX_SINGLE_CELL_RIVER_DISTANCE_METRES: return {"ok":false,"reason":&"SOIL_UNSUITABLE","cell":cell}
		var half_cell: float = simulation.coordinate_service()._config.world_units_per_cell * 0.5
		for offset in [Vector2.ZERO,Vector2(-half_cell,-half_cell),Vector2(half_cell,-half_cell),Vector2(half_cell,half_cell),Vector2(-half_cell,half_cell)]:
			if _cell_slope_at(point+offset) > MAX_TERRACE_SLOPE_DEGREES: return {"ok":false,"reason":&"TERRACE_TOO_STEEP","cell":cell}
	return {"ok":true}

func validate_field_state(field: GopalaEntitySnapshot, sim: GopalaSettlementSimulation) -> bool:
	if field.kind != GopalaEntityKind.ZONE or field.attributes.get(&"definition_id") != &"field": return false
	for key in [&"fertility",&"moisture",&"base_moisture"]:
		if typeof(field.attributes.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(field.attributes[key])) or float(field.attributes[key]) < 0.0 or float(field.attributes[key]) > 1.0: return false
	for key in [&"slope_degrees",&"elevation_metres",&"river_distance_metres"]:
		if typeof(field.attributes.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(field.attributes[key])): return false
	for key in [&"growth_started_tick",&"harvest_ready_tick",&"growth_progress_ticks",&"last_growth_tick",&"harvest_count","terrace_riser_count"]:
		if typeof(field.attributes.get(key)) != TYPE_INT or int(field.attributes[key]) < 0: return false
	if not _zone_rows_valid(field.attributes.get(&"zone_cells",null)) or not _zone_rows_valid(field.attributes.get(&"terrace_cells",null)): return false
	if field.attributes.zone_cells != field.attributes.terrace_cells: return false
	var first: Array = field.attributes.zone_cells[0]
	var anchor := Vector2i(first[0],first[1])
	for row in field.attributes.zone_cells:
		anchor.x = mini(anchor.x,int(row[0]))
		anchor.y = mini(anchor.y,int(row[1]))
	var expected := cells(anchor)
	if expected.size() != field.attributes.zone_cells.size(): return false
	for index in expected.size():
		if field.attributes.zone_cells[index] != [expected[index].x,expected[index].y]: return false
		if not sim.coordinate_service().is_in_bounds(expected[index]): return false
	var claim := sim.occupancy_service().claim_for_owner(field.entity_id)
	if claim == null or claim.state != GopalaOccupancyState.OCCUPIED or claim.cells.size() != expected.size(): return false
	for other in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.ZONE):
		if other.entity_id != field.entity_id and other.attributes.get(&"zone_cells",[]).any(func(pair): return field.attributes.zone_cells.has(pair)): return false
	for road_cell in sim.road_service().road_cells():
		if expected.has(road_cell): return false
	for cell in expected:
		if not claim.cells.has(cell): return false
	if not field.attributes.get("terrace_levels") is Array or field.attributes.terrace_levels.size() != FIELD_CELLS.y: return false
	for value in field.attributes.terrace_levels:
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return false
	var crop_id: StringName = field.attributes.get(&"crop_id",&"")
	var stage: StringName = field.attributes.get(&"field_stage",&"FALLOW")
	var crop := crop_definition(crop_id)
	if crop_id == &"":
		if stage not in [&"FALLOW",&"HARVESTED"] or int(field.attributes.get(&"growth_progress_ticks",0)) != 0 or int(field.attributes.get("work_required",0)) != 0: return false
	elif crop == null or int(field.attributes.get("work_required",0)) != crop.work_ticks or stage not in [&"PREPARING",&"PLANTED",&"GROWING",&"TENDING",&"DROUGHT",&"MATURE"]:
		return false
	else:
		var progress := int(field.attributes.get("growth_progress_ticks",0))
		if progress > crop.growth_ticks or (stage == &"MATURE" and progress < crop.growth_ticks): return false
		if stage == &"PREPARING" and (progress != 0 or int(field.attributes.get("growth_started_tick",0)) != 0): return false
		if stage != &"PREPARING" and int(field.attributes.get("growth_started_tick",0)) > sim.logical_tick: return false
		if stage in [&"PLANTED",&"GROWING",&"TENDING",&"DROUGHT",&"MATURE"] and int(field.attributes.get("harvest_ready_tick",0)) < int(field.attributes.get("growth_started_tick",0)): return false
	return true

func configure_entity_removal() -> void:
	if not simulation.entity_registry().entity_removed.is_connected(_on_entity_removed):
		simulation.entity_registry().entity_removed.connect(_on_entity_removed)

func crop_definition(id: StringName) -> GopalaCropDefinition:
	var path: String = CROP_PATHS.get(id, "")
	if path.is_empty():
		return null
	return load(path) as GopalaCropDefinition

func cells(anchor: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in simulation.placement_service().get_footprint_offsets(FIELD_CELLS): result.append(anchor+offset)
	return result

func _has_terrain() -> bool:
	return terrain != null and not terrain.source.is_empty() and not terrain.distance_field.is_empty() and not terrain.ground.is_empty()

func soil_at(point: Vector2) -> Dictionary:
	if not _has_terrain(): return {"fertility":0.55,"moisture":0.5,"slope_degrees":0.0,"elevation_metres":1300.0,"river_distance_metres":500.0}
	var elevation := terrain.elevation_at(point.x,point.y)
	var slope := rad_to_deg(acos(clampf(terrain.normal_at(point.x,point.y,true).y,-1.0,1.0)))
	var river_distance := terrain.river_distance(point.x,point.y)
	var lowland := clampf(1.0-maxf(0.0,elevation-GopalaKathmanduTerrain.BASE_ELEVATION)/350.0,0.0,1.0)
	var river_factor := 1.0-clampf(absf(river_distance-350.0)/650.0,0.0,1.0)
	return {"fertility":clampf(0.18+lowland*0.42+river_factor*0.28-maxf(0.0,slope-6.0)*0.008,0.0,1.0),"moisture":clampf(0.2+river_factor*0.5+lowland*0.2,0.0,1.0),"slope_degrees":slope,"elevation_metres":elevation,"river_distance_metres":river_distance}

func soil_summary(anchor: Vector2i) -> Dictionary:
	var fertility := 0.0
	var moisture := 0.0
	var slope := 0.0
	var elevation := 0.0
	var river_distance := 0.0
	var area := cells(anchor)
	for cell in area:
		var sample := soil_at(simulation.coordinate_service().settlement_cell_to_world_xz(cell))
		fertility += sample.fertility
		moisture += sample.moisture
		slope = maxf(slope,sample.slope_degrees)
		elevation += sample.elevation_metres
		river_distance += sample.river_distance_metres
	var count := float(maxi(area.size(),1))
	return {"fertility":fertility/count,"moisture":moisture/count,"slope_degrees":slope,"elevation_metres":elevation/count,"river_distance_metres":river_distance/count}

func validate_field(anchor: Vector2i) -> GopalaConstructionValidationResult:
	var area := cells(anchor)
	if not simulation.coordinate_service().cells_in_bounds(area): return GopalaConstructionValidationResult.new(false,&"OUT_OF_BOUNDS",anchor,area,[])
	for cell in area:
		if simulation.occupancy_service().is_blocked(cell): return GopalaConstructionValidationResult.new(false,&"OCCUPIED",anchor,area,[cell])
		if simulation.road_service().road_cells().has(cell): return GopalaConstructionValidationResult.new(false,&"ROAD_OCCUPIED",anchor,area,[cell])
		if not simulation._route_service.is_open(cell): return GopalaConstructionValidationResult.new(false,&"UNBUILDABLE_GROUND",anchor,area,[cell])
	var soil := soil_summary(anchor)
	if soil.river_distance_metres < MIN_RIVER_DISTANCE_METRES: return GopalaConstructionValidationResult.new(false,&"FLOODPLAIN_UNSAFE",anchor,area,[])
	if soil.river_distance_metres > MAX_RIVER_DISTANCE_METRES or soil.elevation_metres > MAX_ELEVATION_METRES: return GopalaConstructionValidationResult.new(false,&"SOIL_UNSUITABLE",anchor,area,[])
	if soil.slope_degrees > MAX_TERRACE_SLOPE_DEGREES: return GopalaConstructionValidationResult.new(false,&"TERRACE_TOO_STEEP",anchor,area,[])
	if _has_terrain():
		var terrain_check := _valid_terrain_patch(area)
		if not terrain_check.ok: return GopalaConstructionValidationResult.new(false,terrain_check.reason,anchor,area,[terrain_check.cell])
	var probe := simulation.occupancy_service().probe_cells(area)
	if not probe.valid: return GopalaConstructionValidationResult.new(false,&"OCCUPIED",anchor,area,probe.conflicting_cells)
	if _existing_zone_overlaps(area): return GopalaConstructionValidationResult.new(false,&"ZONE_OVERLAP",anchor,area,[])
	if _existing_road_overlaps(area): return GopalaConstructionValidationResult.new(false,&"ROAD_OCCUPIED",anchor,area,[])
	for worker in simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER):
		if area.has(simulation.coordinate_service().world_to_settlement_cell(Vector2(worker.attributes.get(&"position_x",0.0),worker.attributes.get(&"position_z",0.0)))): return GopalaConstructionValidationResult.new(false,&"VILLAGER_IN_FOOTPRINT",anchor,area,[])
	for animal in simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.ANIMAL):
		if area.has(simulation.coordinate_service().world_to_settlement_cell(Vector2(animal.attributes.get(&"position_x",0.0),animal.attributes.get(&"position_z",0.0)))): return GopalaConstructionValidationResult.new(false,&"CATTLE_IN_FOOTPRINT",anchor,area,[])
	return GopalaConstructionValidationResult.new(true,&"VALID",anchor,area,[])

func _terrace_levels(anchor: Vector2i) -> Array[float]:
	var result: Array[float] = []
	var coordinate := simulation.coordinate_service()
	for row in FIELD_CELLS.y:
		var total := 0.0
		for column in FIELD_CELLS.x:
			var point := coordinate.settlement_cell_to_world_xz(anchor+Vector2i(column,row))
			total += terrain.height_at(point.x,point.y) if _has_terrain() else 0.0
		result.append(total/float(FIELD_CELLS.x))
	return result

func _riser_count(levels: Array[float]) -> int:
	var threshold := float(GopalaScaleStandard.settings().terrace_field.riser_threshold)
	var count := 0
	for row in range(1,levels.size()):
		if _terrain_height_metres(levels[row]-levels[row-1]) >= threshold: count += 1
	return count

func create_field(command: GopalaSimulationCommand, tick: int) -> GopalaCommandResult:
	var payload := command.payload
	if typeof(payload.get("cell_x")) != TYPE_INT or typeof(payload.get("cell_y")) != TYPE_INT: return _result(command,GopalaCommandResult.Status.REJECTED,&"INVALID_PAYLOAD",tick)
	var anchor := Vector2i(payload.cell_x,payload.cell_y)
	var validation := validate_field(anchor)
	if not validation.valid: return _result(command,GopalaCommandResult.Status.REJECTED,validation.reason_code,tick)
	var origin := simulation.coordinate_service().settlement_cell_to_world_xz(anchor)
	var centre: Vector2 = origin+Vector2(FIELD_CELLS-Vector2i.ONE)*simulation.coordinate_service()._config.world_units_per_cell*0.5
	var rows := []
	for cell in validation.transformed_cells: rows.append([cell.x,cell.y])
	var soil := soil_summary(anchor)
	var result := simulation.entity_registry().create_entity(GopalaEntityKind.ZONE,{&"definition_id":&"field",&"zone_cells":rows,&"position_x":centre.x,&"position_z":centre.y,&"crop_id":&"",&"field_stage":&"FALLOW",&"work_completed":0,&"work_required":0,&"growth_started_tick":0,&"harvest_ready_tick":0,&"growth_progress_ticks":0,&"last_growth_tick":tick,&"harvest_count":0,&"growth_state":&"IDLE",&"fertility":soil.fertility,&"moisture":soil.moisture,&"base_moisture":soil.moisture,&"slope_degrees":soil.slope_degrees,&"elevation_metres":soil.elevation_metres,&"river_distance_metres":soil.river_distance_metres,&"terrace_cells":rows.duplicate(true),&"terrace_levels":_terrace_levels(anchor),&"terrace_riser_count":_riser_count(_terrace_levels(anchor))},{},tick)
	var claim := simulation.occupancy_service().replace_claim(result.entity_id,GopalaOccupancyState.OCCUPIED,validation.transformed_cells,tick)
	if claim.status != GopalaOccupancyOperationResult.Status.APPLIED:
		simulation.entity_registry().remove_entity(result.entity_id,GopalaEntityRegistry.RemovalPolicy.REJECT_IF_REFERENCED,tick)
		return _result(command,GopalaCommandResult.Status.REJECTED,&"FIELD_CLAIM_FAILED",tick)
	return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.APPLIED,&"FIELD_CREATED",tick,{"changed":true,"entity_id":result.entity_id,"command_type":command.command_type})

func set_crop(command: GopalaSimulationCommand, tick: int) -> GopalaCommandResult:
	var payload := command.payload
	if typeof(payload.get("field_id")) != TYPE_INT or typeof(payload.get("crop_id")) != TYPE_STRING_NAME: return _result(command,GopalaCommandResult.Status.REJECTED,&"INVALID_PAYLOAD",tick)
	var field := simulation.entity_queries().snapshot(payload.field_id)
	var crop := crop_definition(payload.crop_id)
	if field == null or field.kind != GopalaEntityKind.ZONE or field.attributes.get(&"definition_id") != &"field" or crop == null: return _result(command,GopalaCommandResult.Status.REJECTED,&"INVALID_FIELD_OR_CROP",tick)
	if field.attributes.get(&"field_stage") not in [&"FALLOW",&"HARVESTED"]: return _result(command,GopalaCommandResult.Status.REJECTED,&"FIELD_NOT_FALLOW",tick)
	if float(field.attributes.get(&"fertility",0.0)) < crop.minimum_fertility or float(field.attributes.get(&"moisture",0.0)) < crop.minimum_moisture: return _result(command,GopalaCommandResult.Status.REJECTED,&"SOIL_BELOW_CROP_MINIMUM",tick)
	var update := simulation.entity_registry().update_entity(field.entity_id,{&"crop_id":crop.id,&"field_stage":&"PREPARING",&"growth_state":&"PREPARING","work_completed":0,&"work_required":crop.work_ticks,&"growth_started_tick":0,&"harvest_ready_tick":0,&"growth_progress_ticks":0,&"last_growth_tick":tick},{},tick,field.revision)
	if update.status != GopalaEntityOperationResult.Status.APPLIED: return _result(command,GopalaCommandResult.Status.REJECTED,&"STALE_FIELD",tick)
	return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.APPLIED,&"CROP_SELECTED",tick,{"changed":true,"command_type":command.command_type})

func request_work(command: GopalaSimulationCommand, tick: int) -> GopalaCommandResult:
	var payload := command.payload
	if typeof(payload.get("field_id")) != TYPE_INT or typeof(payload.get("villager_id")) != TYPE_INT: return _result(command,GopalaCommandResult.Status.REJECTED,&"INVALID_PAYLOAD",tick)
	var field := simulation.entity_queries().snapshot(payload.field_id)
	var worker := simulation.entity_queries().snapshot(payload.villager_id)
	if field == null or field.kind != GopalaEntityKind.ZONE or field.attributes.get(&"definition_id") != &"field" or worker == null or worker.kind != GopalaEntityKind.VILLAGER: return _result(command,GopalaCommandResult.Status.REJECTED,&"INVALID_FIELD_OR_WORKER",tick)
	if not simulation._survival_service.ready_for_work(worker) or worker.attributes.get(&"task_kind",&"NONE") != &"NONE" or int(worker.attributes.get(&"active_task_id",0)) != 0 or int(worker.attributes.get(&"carried_amount",0)) != 0: return _result(command,GopalaCommandResult.Status.REJECTED,&"WORKER_BUSY",tick)
	var stage: StringName = field.attributes.get(&"field_stage",&"FALLOW")
	if stage not in [&"PREPARING",&"GROWING",&"TENDING",&"DROUGHT",&"MATURE"]: return _result(command,GopalaCommandResult.Status.REJECTED,&"FIELD_NOT_WORKABLE",tick)
	var existing_crop := crop_definition(field.attributes.get(&"crop_id",&""))
	if stage == &"MATURE" and existing_crop == null: return _result(command,GopalaCommandResult.Status.REJECTED,&"INVALID_CROP",tick)
	if stage in [&"GROWING",&"TENDING"] and existing_crop != null and int(field.attributes.get(&"growth_progress_ticks",0)) >= existing_crop.growth_ticks: return _result(command,GopalaCommandResult.Status.REJECTED,&"CROP_READY_TO_HARVEST",tick)
	if _tasks.values().any(func(task: Dictionary) -> bool: return int(task.field_id) == field.entity_id): return _result(command,GopalaCommandResult.Status.REJECTED,&"FIELD_ALREADY_STAFFED",tick)
	var action: StringName = &"PLANT" if stage == &"PREPARING" else (&"HARVEST" if stage == &"MATURE" else &"TEND")
	var route := simulation._route_service.plan(Vector2(worker.attributes.get(&"position_x",0.0),worker.attributes.get(&"position_z",0.0)),Vector2(field.attributes.position_x,field.attributes.position_z),&"BUILD")
	if not route.ok: return _result(command,GopalaCommandResult.Status.REJECTED,&"NO_FIELD_ACCESS",tick)
	var field_stage_before: StringName = field.attributes.get(&"field_stage",&"FALLOW")
	if action == &"TEND":
		var field_update := simulation.entity_registry().update_entity(field.entity_id,{&"field_stage":&"TENDING",&"growth_state":&"TENDING"},{},tick,field.revision)
		if field_update.status != GopalaEntityOperationResult.Status.APPLIED: return _result(command,GopalaCommandResult.Status.REJECTED,&"STALE_FIELD",tick)
		field = simulation.entity_queries().snapshot(field.entity_id)
	var task_id := _next_task_id
	var worker_update := simulation.entity_registry().update_entity(worker.entity_id,{&"active_task_id":task_id,&"task_kind":&"FIELD",&"task_state":&"MOVING_TO_FIELD",&"target_building_id":field.entity_id},{},tick,worker.revision)
	if worker_update.status != GopalaEntityOperationResult.Status.APPLIED:
		if action == &"TEND":
			var current_field := simulation.entity_queries().snapshot(field.entity_id)
			simulation.entity_registry().update_entity(current_field.entity_id,{&"field_stage":field_stage_before,&"growth_state":field_stage_before},{},tick,current_field.revision)
		return _result(command,GopalaCommandResult.Status.REJECTED,&"WORKER_UPDATE_FAILED",tick)
	if not simulation.villager_service().set_destination(worker.entity_id,Vector2(field.attributes.position_x,field.attributes.position_z),&"BUILD",task_id):
		var failed_worker := simulation.entity_queries().snapshot(worker.entity_id)
		simulation.entity_registry().update_entity(worker.entity_id,{&"active_task_id":0,&"task_kind":&"NONE",&"task_state":&"NONE",&"target_building_id":0},{},tick,failed_worker.revision)
		if action == &"TEND":
			var current_field := simulation.entity_queries().snapshot(field.entity_id)
			simulation.entity_registry().update_entity(current_field.entity_id,{&"field_stage":field_stage_before,&"growth_state":field_stage_before},{},tick,current_field.revision)
		return _result(command,GopalaCommandResult.Status.REJECTED,&"NO_FIELD_ACCESS",tick)
	_next_task_id += 1
	_tasks[worker.entity_id] = {"task_id":task_id,"worker_id":worker.entity_id,"field_id":field.entity_id,"action":action,"start_stage":field_stage_before,"state":&"MOVING_TO_FIELD","work":0,"created_tick":tick}
	return GopalaCommandResult.new(command.command_id,GopalaCommandResult.Status.APPLIED,&"FIELD_WORK_ASSIGNED",tick,{"changed":true,"task_id":task_id,"command_type":command.command_type})

func harvest_field(command: GopalaSimulationCommand, tick: int) -> GopalaCommandResult:
	return request_work(command,tick)

func cancel_worker(worker_id: int, tick: int, resume := true) -> void:
	if not _tasks.has(worker_id): return
	var task: Dictionary = _tasks[worker_id]
	var worker := simulation.entity_queries().snapshot(worker_id)
	var field := simulation.entity_queries().snapshot(int(task.field_id))
	if worker != null:
		simulation.villager_service().stop(worker_id,&"FIELD_WORK_STOPPED")
		worker = simulation.entity_queries().snapshot(worker_id)
		simulation.entity_registry().update_entity(worker_id,{&"active_task_id":0,&"task_kind":&"NONE",&"task_state":&"NONE",&"target_building_id":0},{},tick,worker.revision)
	if field != null and resume:
		var stage: StringName = task.get("start_stage",&"FALLOW")
		var crop := crop_definition(field.attributes.get(&"crop_id",&""))
		if crop != null and int(field.attributes.get(&"growth_progress_ticks",0)) >= crop.growth_ticks: stage = &"MATURE"
		var current_stage: StringName = stage
		if current_stage == &"TENDING": current_stage = &"MATURE" if crop != null and int(field.attributes.get(&"growth_progress_ticks",0)) >= crop.growth_ticks else (&"GROWING" if float(field.attributes.get(&"moisture",0.0)) >= (crop.minimum_moisture if crop != null else 0.0) else &"DROUGHT")
		simulation.entity_registry().update_entity(field.entity_id,{&"field_stage":current_stage,&"growth_state":current_stage,&"work_completed":int(field.attributes.get(&"work_completed",0))+int(task.get("work",0))},{},tick,field.revision)
	_tasks.erase(worker_id)

func tick(tick: int) -> void:
	for original in fields():
		var field := simulation.entity_queries().snapshot(original.entity_id)
		if field == null: continue
		var stage: StringName = field.attributes.get(&"field_stage",&"FALLOW")
		if stage not in [&"PLANTED",&"GROWING",&"TENDING",&"DROUGHT"]: continue
		var crop := crop_definition(field.attributes.get(&"crop_id",&""))
		if crop == null:
			_update_field(field,{&"field_stage":&"FALLOW",&"growth_state":&"INVALID_CROP",&"crop_id":&""},tick)
			continue
		var elapsed := maxi(0,tick-int(field.attributes.get(&"last_growth_tick",tick)))
		var moisture := clampf(lerpf(float(field.attributes.get(&"moisture",0.0)),_seasonal_moisture(field,tick),0.0025),0.0,1.0)
		var progress := int(field.attributes.get(&"growth_progress_ticks",0))
		if moisture >= crop.minimum_moisture: progress = mini(crop.growth_ticks,progress+elapsed)
		var next_stage: StringName = &"MATURE" if progress >= crop.growth_ticks else (&"GROWING" if stage in [&"PLANTED",&"DROUGHT"] else stage)
		var expected_tick := tick+maxi(0,crop.growth_ticks-progress)
		if moisture < crop.minimum_moisture: next_stage = &"DROUGHT" if not _field_has_tending_worker(field.entity_id) else &"TENDING"
		elif stage == &"TENDING" and not _field_has_tending_worker(field.entity_id): next_stage = &"GROWING"
		_update_field(field,{&"field_stage":next_stage,&"growth_state":next_stage,&"moisture":moisture,&"growth_progress_ticks":progress,&"last_growth_tick":tick,&"harvest_ready_tick":expected_tick},tick)
	for worker_id in _tasks.keys():
		var task: Dictionary = _tasks[worker_id]
		var worker := simulation.entity_queries().snapshot(worker_id)
		var field := simulation.entity_queries().snapshot(int(task.field_id))
		if worker == null or field == null or worker.attributes.get(&"task_kind") != &"FIELD" or not simulation._survival_service.ready_for_work(worker): cancel_worker(worker_id,tick); continue
		if worker.attributes.get(&"movement_state") == &"BLOCKED": cancel_worker(worker_id,tick); continue
		if not simulation.villager_service().has_arrived(worker_id): continue
		if task.state == &"MOVING_TO_FIELD":
			task.state = &"WORKING"
			task.work = 0
			simulation.entity_registry().update_entity(worker_id,{&"task_state":&"WORKING_FIELD"},{},tick,worker.revision)
			continue
		task.work = int(task.get("work",0))+1
		var required := int(field.attributes.get(&"work_required",1))
		if task.work < required: continue
		field = simulation.entity_queries().snapshot(field.entity_id)
		var crop := crop_definition(field.attributes.get(&"crop_id",&""))
		if crop == null: cancel_worker(worker_id,tick); continue
		var patch := {&"work_completed":required}
		if task.get("action") == &"PLANT":
			patch[&"field_stage"] = &"PLANTED"
			patch[&"growth_state"] = &"PLANTED"
			patch[&"growth_started_tick"] = tick
			patch[&"last_growth_tick"] = tick
			patch[&"growth_progress_ticks"] = 0
			patch[&"harvest_ready_tick"] = tick+crop.growth_ticks
		elif task.get("action") == &"TEND":
			patch[&"moisture"] = clampf(float(field.attributes.get(&"moisture",0.0))+0.25,0.0,1.0)
			patch[&"field_stage"] = &"MATURE" if int(field.attributes.get(&"growth_progress_ticks",0)) >= crop.growth_ticks else &"GROWING"
			patch[&"growth_state"] = patch[&"field_stage"]
			patch[&"last_growth_tick"] = tick
		elif task.get("action") == &"HARVEST":
			if not _harvest(field,crop,tick): continue
			patch[&"field_stage"] = &"HARVESTED"
			patch[&"growth_state"] = &"HARVESTED"
			patch[&"moisture"] = field.attributes.get(&"base_moisture",field.attributes.get(&"moisture",0.5))
			patch[&"harvest_count"] = int(field.attributes.get(&"harvest_count",0))+1
			patch[&"crop_id"] = &""
			patch[&"work_completed"] = 0
			patch[&"work_required"] = 0
			patch[&"growth_progress_ticks"] = 0
			patch[&"harvest_ready_tick"] = 0
		_update_field(field,patch,tick)
		_finish_worker(worker_id,tick)

func _field_has_tending_worker(field_id: int) -> bool:
	for task in _tasks.values():
		if int(task.get("field_id",0)) == field_id and task.get("action") == &"TEND": return true
	return false

func _seasonal_moisture(field: GopalaEntitySnapshot,tick: int) -> float:
	var phase := fposmod(float(tick),float(CLIMATE_YEAR_TICKS))/float(CLIMATE_YEAR_TICKS)
	var wet_season := 0.5+0.5*sin(phase*TAU-PI*0.5)
	var river_support := clampf(1.0-float(field.attributes.get(&"river_distance_metres",500.0))/1700.0,0.0,0.65)
	return clampf(float(field.attributes.get(&"base_moisture",0.5))*0.45+wet_season*0.35+river_support*0.2,0.0,1.0)

func _harvest_drop_point(field: GopalaEntitySnapshot) -> Vector2:
	var occupied := {}
	var candidates: Array[Vector2i] = []
	for row in field.attributes.get(&"zone_cells",[]):
		occupied[Vector2i(int(row[0]),int(row[1]))] = true
	for cell in occupied:
		for direction in [Vector2i(0,1),Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,0)]:
			var neighbour: Vector2i = cell + direction
			if occupied.has(neighbour) or candidates.has(neighbour) or not simulation.coordinate_service().is_in_bounds(neighbour): continue
			if simulation._route_service.is_open(neighbour): candidates.append(neighbour)
	if candidates.is_empty(): return Vector2.INF
	var centre := Vector2(float(field.attributes.position_x),float(field.attributes.position_z))
	candidates.sort_custom(func(a,b):
		var point_a := simulation.coordinate_service().settlement_cell_to_world_xz(a)
		var point_b := simulation.coordinate_service().settlement_cell_to_world_xz(b)
		var distance_a := point_a.distance_squared_to(centre)
		var distance_b := point_b.distance_squared_to(centre)
		return distance_a < distance_b if not is_equal_approx(distance_a,distance_b) else (a.x < b.x if a.x != b.x else a.y < b.y)
	)
	return simulation.coordinate_service().settlement_cell_to_world_xz(candidates[0])

func _harvest(field: GopalaEntitySnapshot,crop: GopalaCropDefinition,tick: int) -> bool:
	var quality := clampf(float(field.attributes.get(&"fertility",0.0))*0.7+float(field.attributes.get(&"moisture",0.0))*0.3,0.25,1.0)
	var amount := maxi(1,int(round(float(crop.yield_amount)*quality)))
	var point := _harvest_drop_point(field)
	if not is_finite(point.x) or not is_finite(point.y): return false
	return simulation._storage_service.drop(crop.harvest_resource,amount,point,tick) > 0

func _finish_worker(worker_id: int, tick: int) -> void:
	var worker := simulation.entity_queries().snapshot(worker_id)
	if worker != null:
		simulation.villager_service().stop(worker_id,&"FIELD_WORK_FINISHED")
		worker = simulation.entity_queries().snapshot(worker_id)
		simulation.entity_registry().update_entity(worker_id,{&"active_task_id":0,&"task_kind":&"NONE",&"task_state":&"NONE",&"target_building_id":0},{},tick,worker.revision)
	_tasks.erase(worker_id)

func cancel_worker_for_other_job(worker_id: int,tick: int) -> void:
	cancel_worker(worker_id,tick,false)

func _update_field(field: GopalaEntitySnapshot,attrs: Dictionary,tick: int) -> void:
	simulation.entity_registry().update_entity(field.entity_id,attrs,{},tick,field.revision)

func create_field_from_anchor(anchor: Vector2i,tick: int) -> int:
	var result := create_field(GopalaSimulationCommand._from_queue(0,GopalaSimulationCommand.CREATE_FIELD,tick,{"cell_x":anchor.x,"cell_y":anchor.y},&"test"),tick)
	return int(result.details().get("entity_id",0))

func restore_tasks(tasks: Dictionary,next_id: int) -> void:
	_tasks = tasks.duplicate(true)
	_next_task_id = next_id

func _result(command: GopalaSimulationCommand,status: GopalaCommandResult.Status,reason: StringName,tick: int) -> GopalaCommandResult:
	return GopalaCommandResult.new(command.command_id,status,reason,tick,{"command_type":command.command_type})

func reset() -> void:
	_tasks.clear()
	_next_task_id = 1

var _tasks: Dictionary = {}
var _next_task_id := 1
