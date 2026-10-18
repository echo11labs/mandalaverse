class_name GopalaSettlementSimulation
extends Node

signal snapshot_committed(snapshot: GopalaSettlementSnapshot)
signal command_processed(result: GopalaCommandResult)
signal logical_tick_advanced(tick: int)
signal fixed_tick_completed(tick: int) # Read-only observers run after all fixed-tick services.
signal pause_changed(paused: bool)
signal speed_changed(speed: int)
signal session_reset

const SET_PAUSED: StringName = GopalaSimulationCommand.SET_PAUSED
const SET_SPEED: StringName = GopalaSimulationCommand.SET_SPEED
const REQUEST_CONSTRUCTION: StringName = GopalaSimulationCommand.REQUEST_CONSTRUCTION

var _config := GopalaSimulationConfig.new()
var _clock := GopalaSimulationClock.new()
var _queue := GopalaCommandQueue.new()
var _ledger := GopalaResourceLedger.new()
var _entity_ids := GopalaEntityIdAllocator.new()
var _entity_registry: GopalaEntityRegistry
var _entity_queries: GopalaEntityQueryService
var _selection_service: GopalaSelectionService
var _coordinate_service: GopalaSettlementCoordinateService
var _occupancy_service: GopalaSettlementOccupancyService
var _placement_service: GopalaConstructionPlacementService
var _road_service: GopalaRoadPlacementService
var _route_service: GopalaSettlementRouteService
var _villager_service: GopalaVillagerService
var _gather_delivery_service: GopalaGatherDeliveryService
var _construction_labor_service: GopalaConstructionLaborService
var _storage_service: GopalaStorageService
var _workforce_service: GopalaWorkforceService
var _worker_job_service: GopalaWorkerJobService
var _herd_service: GopalaHerdService
var _survival_service: GopalaSurvivalService
var _field_service: GopalaFieldService
var _capabilities: Dictionary = {}
var _snapshot_sequence: int = 0
var _session_epoch: int = 0
var _processing_commands: bool = false
var _resetting: bool = false
var _advancing_ticks := false

var paused: bool:
	get: return _clock.paused
var speed: int:
	get: return _clock.speed
var logical_tick: int:
	get: return _clock.logical_tick
var elapsed_logical_time: float:
	get: return float(_clock.elapsed_logical_nanoseconds) / 1_000_000_000.0

func _init() -> void:
	_clock.configure(_config.tick_interval_nanoseconds())
	_capabilities = _make_capabilities()
	_entity_registry = GopalaEntityRegistry.new()
	_entity_registry.name = "EntityRegistry"
	_entity_registry.configure(_entity_ids)
	_entity_registry.transaction_committed.connect(_on_registry_transaction_committed)
	add_child(_entity_registry)
	_entity_queries = GopalaEntityQueryService.new()
	_entity_queries.name = "EntityQueryService"
	_entity_queries.configure(_entity_registry)
	add_child(_entity_queries)
	_selection_service = GopalaSelectionService.new()
	_selection_service.name = "SelectionService"
	_selection_service.configure(_entity_queries, _entity_registry)
	add_child(_selection_service)
	_coordinate_service = GopalaSettlementCoordinateService.new()
	_coordinate_service.name = "SettlementCoordinateService"
	add_child(_coordinate_service)
	_occupancy_service = GopalaSettlementOccupancyService.new()
	_occupancy_service.name = "SettlementOccupancyService"
	_occupancy_service.configure(_entity_queries, _entity_registry, _coordinate_service)
	_occupancy_service.occupancy_changed.connect(_on_occupancy_changed)
	add_child(_occupancy_service)
	_placement_service = GopalaConstructionPlacementService.new()
	_placement_service.name = "ConstructionPlacementService"
	_placement_service.configure(_ledger, _occupancy_service, _entity_registry, _coordinate_service)
	add_child(_placement_service)

	_route_service = GopalaSettlementRouteService.new()
	_route_service.name = "SettlementRoutes"
	_route_service.configure(_coordinate_service, _occupancy_service, _entity_queries)
	add_child(_route_service)
	_placement_service.routes = _route_service
	_road_service = GopalaRoadPlacementService.new()
	_road_service.name = "RoadPlacementService"
	_road_service.configure(_coordinate_service, _occupancy_service, _entity_queries, _entity_registry, _route_service)
	add_child(_road_service)
	_route_service.configure_roads(_road_service)
	_placement_service.road_service = _road_service
	_villager_service = GopalaVillagerService.new()
	_villager_service.name = "VillagerService"
	_villager_service.configure(_entity_queries, _entity_registry, _coordinate_service, _config, _route_service)
	add_child(_villager_service)
	
	_gather_delivery_service = GopalaGatherDeliveryService.new()
	_gather_delivery_service.name = "GatherDeliveryService"
	_gather_delivery_service.configure(_entity_queries, _entity_registry, _ledger, _villager_service, _coordinate_service)
	add_child(_gather_delivery_service)

	_construction_labor_service = GopalaConstructionLaborService.new()
	_construction_labor_service.name = "ConstructionLaborService"
	_construction_labor_service.configure(_entity_queries, _entity_registry, _ledger, _villager_service, _coordinate_service)
	add_child(_construction_labor_service)
	_placement_service._labor_service = _construction_labor_service
	_storage_service = GopalaStorageService.new(self)
	_worker_job_service = GopalaWorkerJobService.new(self)
	_survival_service = GopalaSurvivalService.new(self)
	_herd_service = GopalaHerdService.new(self)
	_field_service = GopalaFieldService.new(self)
	_field_service.configure_entity_removal()
	_workforce_service = GopalaWorkforceService.new(self)
	_gather_delivery_service.storage = _storage_service
	_construction_labor_service.storage = _storage_service
	_placement_service.storage = _storage_service
	_road_service.storage = _storage_service
	_road_service.labor = _construction_labor_service
	_construction_labor_service.roads = _road_service
	_entity_registry.entity_removed.connect(_storage_service.on_removed)

func bootstrap_session() -> bool:
	if _session_epoch > 0 or _ledger.amount(&"timber") > 0:
		return false
	_ledger._seed_for_tests({
		&"timber": 100,
		&"stone": 50,
		&"thatch": 50
	})
	_commit_snapshot()
	return true

func _ready() -> void:
	_commit_snapshot()

func _physics_process(delta: float) -> void:
	_advancing_ticks = true
	_storage_service.flush_removed()
	var advanced := _clock.advance_frame(delta)
	for i in range(advanced):
		logical_tick_advanced.emit(logical_tick - advanced + i + 1)
		_schedule_road_builders()
		_field_service.tick(logical_tick - advanced + i + 1)
		_survival_service.tick(logical_tick - advanced + i + 1)
		_villager_service.tick(logical_tick - advanced + i + 1)
		_gather_delivery_service.tick(logical_tick - advanced + i + 1)
		_construction_labor_service.tick(logical_tick - advanced + i + 1)
		_herd_service.tick(logical_tick - advanced + i + 1)
		_workforce_service.tick(logical_tick - advanced + i + 1)
		_worker_job_service.tick(logical_tick - advanced + i + 1)
		GopalaMvpScenario.tick(self,logical_tick - advanced + i + 1)
		_commit_snapshot()
		fixed_tick_completed.emit(logical_tick - advanced + i + 1)

	_advancing_ticks = false
	process_pending_commands()

func submit_command(command_type: StringName, payload: Dictionary = {}, source_id: StringName = &"") -> int:
	return _queue.submit(command_type, logical_tick, payload, source_id)

func process_pending_commands() -> int:
	if _processing_commands:
		return 0
	_processing_commands = true
	var processed := 0
	var drain_count: int = mini(_queue.pending_count(), GopalaSimulationConfig.MAX_COMMANDS_PER_DRAIN)
	var drained := 0
	var drain_epoch := _session_epoch
	var logical_tick_before_drain := logical_tick
	while drained < drain_count and _session_epoch == drain_epoch and _queue.has_pending():
		_storage_service.flush_removed()
		var command: GopalaSimulationCommand = _queue.pop_front()
		if command == null:
			break
		var result := _apply_command(command)
		var changed := result.status == GopalaCommandResult.Status.APPLIED \
			and bool(result.details().get("changed", false))
		if changed and command.command_type == SET_PAUSED:
			pause_changed.emit(paused)
		elif changed and command.command_type == SET_SPEED:
			speed_changed.emit(speed)
		if changed:
			_commit_snapshot()
		processed += 1
		drained += 1
		if not result.valid:
			result = _result(command, GopalaCommandResult.Status.REJECTED,
				GopalaCommandResult.REASON_INVALID_PAYLOAD)
		command_processed.emit(result)
	_processing_commands = false
	if logical_tick != logical_tick_before_drain:
		logical_tick_advanced.emit(logical_tick)
		_commit_snapshot()
	return processed

func set_paused(value: bool) -> int:
	return submit_command(SET_PAUSED, {"paused": value})

func set_speed(value: int) -> int:
	return submit_command(SET_SPEED, {"speed": value})

func request_construction(building_id: StringName, cell: Vector2i, rotation: int = 0) -> int:
	return submit_command(REQUEST_CONSTRUCTION, {"building_id": building_id,
		"cell_x": cell.x, "cell_y": cell.y, "rotation": rotation})

func advance_ticks(count: int) -> bool:
	if paused and count > 0:
		return false
	if count < 0:
		return false
	if count == 0:
		return true
	_advancing_ticks = true
	for i in range(count):
		if not _clock.advance_ticks(1):
			_advancing_ticks = false
			return false
		logical_tick_advanced.emit(logical_tick)
		_storage_service.flush_removed()
		_schedule_road_builders()
		_field_service.tick(logical_tick)
		_survival_service.tick(logical_tick)
		_villager_service.tick(logical_tick)
		_gather_delivery_service.tick(logical_tick)
		_construction_labor_service.tick(logical_tick)
		_herd_service.tick(logical_tick)
		_workforce_service.tick(logical_tick)
		_worker_job_service.tick(logical_tick)
		GopalaMvpScenario.tick(self,logical_tick)
		_commit_snapshot()
		process_pending_commands()
		fixed_tick_completed.emit(logical_tick)
	_advancing_ticks = false
	return true

func tick_interval_seconds() -> float:
	return _config.tick_interval_seconds

func snapshot() -> GopalaSettlementSnapshot:
	return _build_snapshot(_snapshot_sequence)

func capabilities() -> Dictionary:
	return GopalaSimulationCommand.copy_plain_dictionary(_capabilities)

## Domain-system access to the authoritative registry (mutation stays behind
## this session boundary). Presentation/query consumers must use entity_queries.
func entity_registry() -> GopalaEntityRegistry:
	return _entity_registry

## Read-only query facade for presentation and inspection consumers.
func entity_queries() -> GopalaEntityQueryService:
	return _entity_queries

## Scene-owned single-entity selection service (foundation only).
func selection_service() -> GopalaSelectionService:
	return _selection_service

func coordinate_service() -> GopalaSettlementCoordinateService:
	return _coordinate_service

func occupancy_service() -> GopalaSettlementOccupancyService:
	return _occupancy_service

func placement_service() -> GopalaConstructionPlacementService:
	return _placement_service

func villager_service() -> GopalaVillagerService:
	return _villager_service

func road_service() -> GopalaRoadPlacementService:
	return _road_service

func field_service() -> GopalaFieldService:
	return _field_service

func request_road(cells: Array[Vector2i]) -> int:
	var rows: Array = []
	for cell in cells:
		rows.append([cell.x, cell.y])
	return submit_command(GopalaSimulationCommand.REQUEST_ROAD, {"cells": rows})

func request_cobbled_path(cells: Array[Vector2i]) -> int:
	var rows: Array = []
	for cell in cells:
		rows.append([cell.x, cell.y])
	return submit_command(GopalaSimulationCommand.REQUEST_COBBLED_PATH, {"cells": rows})

func gather_delivery_service() -> GopalaGatherDeliveryService:
	return _gather_delivery_service

func elapsed_logical_nanoseconds() -> int:
	return _clock.elapsed_logical_nanoseconds

func resource_amount(resource_id: StringName) -> int:
	return _ledger.amount(resource_id)

func resource_balances_snapshot() -> Dictionary[StringName, int]:
	return _ledger.balances_snapshot()

func can_afford(costs: Variant) -> bool:
	return _ledger.can_afford(costs)

func validate_resource_transaction(delta: Variant) -> bool:
	return _ledger.validate_transaction(delta)

func apply_authorized_transaction(delta: Variant) -> bool:
	if not delta is Dictionary or not _storage_service.apply_transaction(delta):
		return false
	_commit_snapshot()
	return true

func reset() -> bool:
	# Existing policy: a reset from a snapshot/command listener is allowed and
	# stops the enclosing drain via the session epoch. Only a nested reset during
	# an already-running reset is rejected.
	if _resetting:
		return false
	_resetting = true
	var was_paused := paused
	var old_speed := speed
	_session_epoch += 1
	_queue.reset_new_session()
	if _selection_service != null:
		_selection_service.reset(GopalaSelectionResult.SESSION_RESET)
	if _occupancy_service != null:
		_occupancy_service.reset(GopalaOccupancyOperationResult.SESSION_RESET)
	if _entity_registry != null:
		_entity_registry.reset()
	_entity_ids.reset_new_session()
	_villager_service.reset()
	_clock.reset()
	_ledger.reset()
	_storage_service.stocks.clear()
	_storage_service._positions.clear()
	_storage_service._removed.clear()
	_storage_service.located = false
	if _gather_delivery_service != null:
		_gather_delivery_service.reset()
	if _construction_labor_service != null:
		_construction_labor_service.reset()
	if _field_service != null:
		_field_service.reset()
	_snapshot_sequence = 0
	if not was_paused:
		pause_changed.emit(true)
	if old_speed != 1:
		speed_changed.emit(1)
	session_reset.emit()
	_commit_snapshot()
	_resetting = false
	return true

func _apply_command(command: GopalaSimulationCommand) -> GopalaCommandResult:
	if command.command_id <= 0 or command.submitted_tick < 0:
		return _result(command, GopalaCommandResult.Status.REJECTED,
			GopalaCommandResult.REASON_INVALID_COMMAND)
	var payload: Dictionary = command.payload
	if not GopalaSimulationCommand.validate_plain_data(payload):
		return _result(command, GopalaCommandResult.Status.REJECTED,
			GopalaCommandResult.REASON_INVALID_PAYLOAD)
	
	if command.command_type == GopalaSimulationCommand.REQUEST_GATHER_TIMBER:
		print("Applying REQUEST_GATHER_TIMBER: ", payload)

	match command.command_type:
		SET_PAUSED:
			if payload.size() != 1 or not payload.has("paused") or typeof(payload["paused"]) != TYPE_BOOL:
				return _result(command, GopalaCommandResult.Status.REJECTED,
					GopalaCommandResult.REASON_INVALID_VALUE)
			var changed := _clock.set_paused(bool(payload["paused"]))
			return _result(command, GopalaCommandResult.Status.APPLIED,
				GopalaCommandResult.REASON_APPLIED, {"changed": changed})
		SET_SPEED:
			if payload.size() != 1 or not payload.has("speed") or typeof(payload["speed"]) != TYPE_INT:
				return _result(command, GopalaCommandResult.Status.REJECTED,
					GopalaCommandResult.REASON_INVALID_VALUE)
			var requested_speed: int = payload["speed"]
			if requested_speed < 1 or requested_speed > 4:
				return _result(command, GopalaCommandResult.Status.REJECTED,
					GopalaCommandResult.REASON_INVALID_VALUE)
			var speed_changed_state := _clock.set_speed(requested_speed)
			return _result(command, GopalaCommandResult.Status.APPLIED,
				GopalaCommandResult.REASON_APPLIED, {"changed": speed_changed_state})
		REQUEST_CONSTRUCTION:
			var result = _placement_service.handle_request_construction(command, logical_tick)
			if result.status == GopalaCommandResult.Status.APPLIED:
				_commit_snapshot()
			return result
		GopalaSimulationCommand.REQUEST_ROAD:
			var result := _road_service.handle_request_road(command, logical_tick)
			if result.status == GopalaCommandResult.Status.APPLIED:
				_commit_snapshot()
			return result
		GopalaSimulationCommand.REQUEST_COBBLED_PATH:
			var result := _road_service.handle_request_cobbled_path(command, logical_tick)
			if result.status == GopalaCommandResult.Status.APPLIED:
				_commit_snapshot()
			return result
		GopalaSimulationCommand.REQUEST_SPAWN_VILLAGER:
			if not payload.has("x") or not payload.has("z") or typeof(payload["x"]) != TYPE_FLOAT or typeof(payload["z"]) != TYPE_FLOAT:
				return _result(command, GopalaCommandResult.Status.REJECTED, GopalaCommandResult.REASON_INVALID_PAYLOAD)
			var pos := Vector2(payload["x"], payload["z"])
			var entity_id := _villager_service.spawn_villager(pos)
			if entity_id == 0:
				return _result(command,GopalaCommandResult.Status.REJECTED,&"INVALID_SPAWN_POSITION")
			return _result(command, GopalaCommandResult.Status.APPLIED, GopalaCommandResult.REASON_APPLIED, {"changed": true, "entity_id": entity_id})
		GopalaSimulationCommand.REQUEST_MOVE_VILLAGER:
			if not payload.has("villager_id") or typeof(payload["villager_id"]) != TYPE_INT:
				return _result(command, GopalaCommandResult.Status.REJECTED, GopalaCommandResult.REASON_INVALID_PAYLOAD)
			if not payload.has("x") or not payload.has("z") or typeof(payload["x"]) != TYPE_FLOAT or typeof(payload["z"]) != TYPE_FLOAT:
				return _result(command, GopalaCommandResult.Status.REJECTED, GopalaCommandResult.REASON_INVALID_PAYLOAD)
			var villager_id: int = payload["villager_id"]
			var target := Vector2(payload["x"], payload["z"])
			var success := _villager_service.assign_move_task(villager_id, target)
			if success:
				_workforce_service.manual_override(villager_id,logical_tick)
				return _result(command, GopalaCommandResult.Status.APPLIED, GopalaCommandResult.REASON_APPLIED, {"changed": true})
			else:
				return _result(command, GopalaCommandResult.Status.REJECTED, _villager_service.last_failure if _villager_service.last_failure != &"" else GopalaCommandResult.REASON_INVALID_PAYLOAD)
		GopalaSimulationCommand.ASSIGN_CATTLE_PASTURE:
			return _herd_service.assign_pasture(command,logical_tick)
		GopalaSimulationCommand.CREATE_PASTURE:
			return _herd_service.create_pasture(command,logical_tick)
		GopalaSimulationCommand.CREATE_FIELD:
			return _field_service.create_field(command,logical_tick)
		GopalaSimulationCommand.SET_FIELD_CROP:
			return _field_service.set_crop(command,logical_tick)
		GopalaSimulationCommand.REQUEST_FIELD_WORK:
			return _field_service.request_work(command,logical_tick)
		GopalaSimulationCommand.HARVEST_FIELD:
			return _field_service.harvest_field(command,logical_tick)
		GopalaSimulationCommand.SET_WORKFORCE_POLICY:
			return _workforce_service.configure(command,logical_tick)
		GopalaSimulationCommand.SET_WORKER_AUTOMATION:
			return _workforce_service.set_automatic(command,logical_tick)
		GopalaSimulationCommand.SET_WORK_ROLE:
			var result := _worker_job_service.assign(command,logical_tick)
			if result.status == GopalaCommandResult.Status.APPLIED: _workforce_service.manual_override(int(payload.get("villager_id",0)),logical_tick)
			return result
		GopalaSimulationCommand.REQUEST_STOP_GATHERING:
			return _gather_delivery_service.handle_stop_gathering(command, logical_tick)
		GopalaSimulationCommand.REQUEST_GATHER_TIMBER, GopalaSimulationCommand.REQUEST_GATHER_STONE, GopalaSimulationCommand.REQUEST_GATHER_RESOURCE:
			var result = _gather_delivery_service.handle_request_gather_timber(command, logical_tick)
			if result.status == GopalaCommandResult.Status.APPLIED:
				_workforce_service.manual_override(int(payload.get("villager_id",0)),logical_tick)
				_commit_snapshot()
			return result
		GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER:
			var result = _construction_labor_service.handle_request_assign_builder(command, logical_tick)
			if result.status == GopalaCommandResult.Status.APPLIED:
				_workforce_service.manual_override(int(payload.get("villager_id",0)),logical_tick)
				_commit_snapshot()
			return result
		GopalaSimulationCommand.REQUEST_CANCEL_CONSTRUCTION:
			var target := _entity_queries.snapshot(int(payload.get("entity_id",0)))
			if target != null and target.kind == GopalaEntityKind.ROAD: return _road_service.cancel_work(command,logical_tick)
			var result = _placement_service.handle_request_cancel_construction(command, logical_tick)
			if result.status == GopalaCommandResult.Status.APPLIED:
				_commit_snapshot()
			return result
		_:
			return _result(command, GopalaCommandResult.Status.REJECTED,
				GopalaCommandResult.REASON_UNKNOWN_COMMAND)

func _result(command: GopalaSimulationCommand, status: GopalaCommandResult.Status,
		reason: StringName, details: Dictionary = {}) -> GopalaCommandResult:
	return GopalaCommandResult.new(command.command_id, status, reason, logical_tick, details)

func _make_capabilities() -> Dictionary:
	var map := {}
	for capability in GopalaSimulationConfig.CAPABILITY_NAMES:
		map[capability] = capability in [
			&"simulation_clock", &"command_queue", &"resource_ledger", &"snapshots",
			&"entity_registry", &"selection", &"placement", &"occupancy", &"construction", &"roads", &"workforce_management"
		]
	return map

func _build_snapshot(sequence: int) -> GopalaSettlementSnapshot:
	var registry_state := _entity_registry.registry_snapshot()
	var occupancy_state = _occupancy_service.grid_summary() if _occupancy_service != null else null
	var occ_seq = occupancy_state.occupancy_sequence if occupancy_state != null else 0
	var grid_configured = occupancy_state.configured if occupancy_state != null else false
	var claim_count = occupancy_state.claim_count if occupancy_state != null else 0
	var reserved = occupancy_state.reserved_cell_count if occupancy_state != null else 0
	var occupied = occupancy_state.occupied_cell_count if occupancy_state != null else 0

	var caps = _capabilities.duplicate()

	return GopalaSettlementSnapshot.new(sequence, logical_tick, paused, speed,
		elapsed_logical_time, _ledger.balances_snapshot(), caps,
		registry_state.entity_count, registry_state.counts_by_kind,
		registry_state.registry_sequence, registry_state.counts_by_kind_array,
		grid_configured, occ_seq, claim_count, reserved, occupied)

func _commit_snapshot() -> void:
	_snapshot_sequence += 1
	snapshot_committed.emit(_build_snapshot(_snapshot_sequence))

func _on_registry_transaction_committed(_snapshot: GopalaEntityRegistrySnapshot) -> void:
	# The final reset-state snapshot is committed after clock/ledger/sequence reset.
	if _resetting or _advancing_ticks:
		return
	_commit_snapshot()

func _on_occupancy_changed(_grid_snapshot: GopalaOccupancyGridSnapshot) -> void:
	if _resetting or _advancing_ticks:
		return
	_commit_snapshot()

func _snapshot_sequence_for_tests() -> int:
	return _snapshot_sequence

func _reset_ledger_for_tests() -> void:
	_ledger.reset()
	_storage_service.stocks.clear()
	_storage_service._positions.clear()
	_storage_service._removed.clear()
	_storage_service.located = false

func _seed_resources_for_tests(delta: Dictionary) -> bool:
	if not _ledger._seed_for_tests(delta):
		return false
	_commit_snapshot()
	return true

func _apply_command_for_tests(command: GopalaSimulationCommand) -> GopalaCommandResult:
	return _apply_command(command)

func _queue_pending_count_for_tests() -> int:
	return _queue.pending_count()

func _next_entity_id_for_tests() -> int:
	return _entity_ids._next_for_tests()

func _entity_allocator_for_tests() -> GopalaEntityIdAllocator:
	return _entity_ids

func _advance_runtime_delta_for_tests(delta: float) -> void:
	_physics_process(delta)

func _schedule_road_builders() -> void:
	var owner := _workforce_service.settlement()
	if owner != null and owner.attributes.has("workforce_policy"): return
	var selected := {}
	for road in _entity_queries.snapshots_by_kind(GopalaEntityKind.ROAD):
		if str(road.attributes.get("construction_state","COMPLETED")) in ["COMPLETED","CANCELLED"] or int(road.attributes.get("assigned_builder_id",0)) != 0 or not road.attributes.get("auto_build",false): continue
		for worker in _entity_queries.snapshots_by_kind(GopalaEntityKind.VILLAGER):
			if selected.has(worker.entity_id) or int(worker.attributes.get("active_task_id",0)) != 0 or int(worker.attributes.get("carried_amount",0)) > 0 or str(worker.attributes.get("work_role","NONE")) != "NONE" or str(worker.attributes.get("task_kind","NONE")) != "NONE": continue
			selected[worker.entity_id] = true
			submit_command(GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER,{"villager_id":worker.entity_id,"blueprint_id":road.entity_id},&"road_dispatcher")
			break
