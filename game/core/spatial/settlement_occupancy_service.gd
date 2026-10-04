class_name GopalaSettlementOccupancyService
extends Node

signal claim_committed(claim_snapshot: GopalaOccupancyClaimSnapshot)
signal claim_released(owner_id: int, previous_claim_snapshot: GopalaOccupancyClaimSnapshot, reason: StringName)
signal occupancy_changed(grid_snapshot: GopalaOccupancyGridSnapshot)
signal occupancy_reset

var _queries: GopalaEntityQueryService
var _registry: GopalaEntityRegistry
var _coordinate: GopalaSettlementCoordinateService
var _sequence: int = 0
var _emission_depth: int = 0

# internal state
var _claims: Dictionary = {} # int owner_id -> _ClaimData
var _cells: Dictionary = {} # Vector2i -> int owner_id

class _ClaimData:
	var owner_entity_id: int
	var state: StringName
	var cells: Array[Vector2i]
	var revision: int
	var created_tick: int
	var updated_tick: int

func configure(queries: GopalaEntityQueryService, registry: GopalaEntityRegistry, coordinate: GopalaSettlementCoordinateService) -> bool:
	if queries == null or registry == null or coordinate == null:
		return false
	if _queries != null or _registry != null or _coordinate != null:
		return false
	_queries = queries
	_registry = registry
	_coordinate = coordinate
	_registry.entity_removed.connect(_on_entity_removed)
	_registry.registry_reset.connect(_on_registry_reset)
	return true

func probe_cells(cells: Array[Vector2i], ignored_owner_id: int = 0) -> GopalaOccupancyOperationResult:
	if _emission_depth > 0:
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.REENTRANT_MUTATION)
	if _coordinate == null or not _coordinate.is_configured():
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.GRID_UNCONFIGURED)
	if cells.is_empty():
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.EMPTY_CELLS)
		
	var out_of_bounds: Array[Vector2i] = []
	var conflicting_cells: Array[Vector2i] = []
	var conflicting_owners: Dictionary = {}
	var normalized: Array[Vector2i] = []
	var seen: Dictionary = {}
	
	for cell in cells:
		if seen.has(cell):
			continue
		seen[cell] = true
		normalized.append(cell)
		if not _coordinate.is_in_bounds(cell):
			out_of_bounds.append(cell)
		elif _cells.has(cell):
			var owner = _cells[cell]
			if owner != ignored_owner_id:
				conflicting_cells.append(cell)
				conflicting_owners[owner] = true
				
	if not out_of_bounds.is_empty():
		var owner_ids: Array[int] = []
		owner_ids.assign(conflicting_owners.keys())
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.OUT_OF_BOUNDS, false, out_of_bounds, conflicting_cells, owner_ids, normalized)
	if not conflicting_cells.is_empty():
		var owner_ids: Array[int] = []
		owner_ids.assign(conflicting_owners.keys())
		owner_ids.sort()
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.OCCUPIED, false, [] as Array[Vector2i], conflicting_cells, owner_ids, normalized)
		
	normalized.sort_custom(func(a,b):
		if a.x != b.x: return a.x < b.x
		return a.y < b.y
	)
	return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.APPLIED, GopalaOccupancyOperationResult.AVAILABLE, true, [] as Array[Vector2i], [] as Array[Vector2i], [] as Array[int], normalized)

func reserve_cells(owner_entity_id: int, cells: Array[Vector2i], tick: int) -> GopalaOccupancyOperationResult:
	if _emission_depth > 0:
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.REENTRANT_MUTATION)
	if owner_entity_id <= 0 or _queries == null or not _queries.has_entity(owner_entity_id):
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.INVALID_OWNER)
	if _claims.has(owner_entity_id):
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.ALREADY_RESERVED)
		
	var probe = probe_cells(cells)
	if not probe.valid:
		return probe
		
	_sequence += 1
	var claim = _ClaimData.new()
	claim.owner_entity_id = owner_entity_id
	claim.state = GopalaOccupancyState.RESERVED
	claim.cells = probe.normalized_cells.duplicate()
	claim.revision = 1
	claim.created_tick = tick
	claim.updated_tick = tick
	_claims[owner_entity_id] = claim
	
	for cell in claim.cells:
		_cells[cell] = owner_entity_id
		
	_emit_changes(claim)
	return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.APPLIED, GopalaOccupancyState.RESERVED)

func commit_reservation(owner_entity_id: int, tick: int) -> GopalaOccupancyOperationResult:
	if _emission_depth > 0:
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.REENTRANT_MUTATION)
	if not _claims.has(owner_entity_id):
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.NOT_RESERVED)
	
	var claim: _ClaimData = _claims[owner_entity_id]
	if claim.state == GopalaOccupancyState.OCCUPIED:
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.INVALID_STATE)
		
	_sequence += 1
	claim.state = GopalaOccupancyState.OCCUPIED
	claim.revision += 1
	claim.updated_tick = tick
	
	_emit_changes(claim)
	return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.APPLIED, GopalaOccupancyState.OCCUPIED)

func replace_claim(owner_entity_id: int, state: StringName, cells: Array[Vector2i], tick: int) -> GopalaOccupancyOperationResult:
	if _emission_depth > 0:
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.REENTRANT_MUTATION)
	if owner_entity_id <= 0 or _queries == null or not _queries.has_entity(owner_entity_id):
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.INVALID_OWNER)
	if not GopalaOccupancyState.is_valid(state):
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.INVALID_STATE)
		
	var probe = probe_cells(cells, owner_entity_id)
	if not probe.valid:
		return probe
		
	var old_claim: _ClaimData = _claims.get(owner_entity_id)
	if old_claim != null:
		for cell in old_claim.cells:
			_cells.erase(cell)
			
	var rev = 1
	var created = tick
	if old_claim != null:
		rev = old_claim.revision + 1
		created = old_claim.created_tick
		
	_sequence += 1
	var claim = _ClaimData.new()
	claim.owner_entity_id = owner_entity_id
	claim.state = state
	claim.cells = probe.normalized_cells.duplicate()
	claim.revision = rev
	claim.created_tick = created
	claim.updated_tick = tick
	_claims[owner_entity_id] = claim
	
	for cell in claim.cells:
		_cells[cell] = owner_entity_id
		
	_emit_changes(claim)
	return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.APPLIED, GopalaOccupancyOperationResult.REPLACED)

func release_claim(owner_entity_id: int, reason: StringName, tick: int) -> GopalaOccupancyOperationResult:
	if _emission_depth > 0:
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.REENTRANT_MUTATION)
	if not _claims.has(owner_entity_id):
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.NOT_FOUND)
		
	var claim: _ClaimData = _claims[owner_entity_id]
	var snapshot = _make_snapshot(claim)
	
	_sequence += 1
	for cell in claim.cells:
		_cells.erase(cell)
	_claims.erase(owner_entity_id)
	
	_emission_depth += 1
	claim_released.emit(owner_entity_id, snapshot, reason)
	occupancy_changed.emit(grid_snapshot())
	_emission_depth -= 1
	
	return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.APPLIED, GopalaOccupancyOperationResult.RELEASED)

func claim_for_owner(owner_entity_id: int) -> GopalaOccupancyClaimSnapshot:
	if _claims.has(owner_entity_id):
		return _make_snapshot(_claims[owner_entity_id])
	return null

func claim_at(cell: Vector2i) -> GopalaOccupancyClaimSnapshot:
	if _cells.has(cell):
		return claim_for_owner(_cells[cell])
	return null

func is_blocked(cell: Vector2i) -> bool:
	if _coordinate == null or not _coordinate.is_configured():
		return true
	if not _coordinate.is_in_bounds(cell):
		return true
	return _cells.has(cell)

func grid_snapshot() -> GopalaOccupancyGridSnapshot:
	var conf = _coordinate.is_configured() if _coordinate != null else false
	var b_summary = _coordinate.config_snapshot() if conf else {}
	var c_count = _claims.size()
	var r_count = 0
	var o_count = 0
	var arr: Array[Dictionary] = []
	
	var owner_ids = _claims.keys()
	owner_ids.sort()
	for id in owner_ids:
		var c: _ClaimData = _claims[id]
		if c.state == GopalaOccupancyState.RESERVED:
			r_count += c.cells.size()
		elif c.state == GopalaOccupancyState.OCCUPIED:
			o_count += c.cells.size()
		arr.append(_make_snapshot(c).to_plain_data())
		
	return GopalaOccupancyGridSnapshot.new(conf, _sequence, b_summary, c_count, r_count, o_count, arr)

func reset(reason: StringName) -> GopalaOccupancyOperationResult:
	if _emission_depth > 0:
		return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.REJECTED, GopalaOccupancyOperationResult.REENTRANT_MUTATION)
	_sequence = 0
	_claims.clear()
	_cells.clear()
	_emission_depth += 1
	occupancy_reset.emit()
	occupancy_changed.emit(grid_snapshot())
	_emission_depth -= 1
	return GopalaOccupancyOperationResult.new(GopalaOccupancyOperationResult.Status.APPLIED, reason)

func _make_snapshot(claim: _ClaimData) -> GopalaOccupancyClaimSnapshot:
	return GopalaOccupancyClaimSnapshot.new(claim.owner_entity_id, claim.state, claim.cells.duplicate(), claim.revision, claim.created_tick, claim.updated_tick)

func _emit_changes(claim: _ClaimData) -> void:
	_emission_depth += 1
	claim_committed.emit(_make_snapshot(claim))
	occupancy_changed.emit(grid_snapshot())
	_emission_depth -= 1

func _on_entity_removed(entity_id: int, _kind: StringName, _reg_seq: int) -> void:
	if _claims.has(entity_id):
		release_claim(entity_id, GopalaOccupancyOperationResult.REMOVED, 0)

func _on_registry_reset() -> void:
	if _claims.is_empty() and _sequence == 0:
		return
	reset(GopalaOccupancyOperationResult.SESSION_RESET)
