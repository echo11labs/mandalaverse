class_name GopalaSelectionService
extends Node
## Scene-owned single-entity selection. Authoritative local state is only:
## selected entity ID, local selection sequence, and the emission/reentrancy
## guard. No Node, Resource, RID, Callable, Signal, collider, camera or UI
## references are stored; the injected query/registry services are the only
## object dependencies and they are scene-owned.

signal selection_changed(snapshot: GopalaSelectionSnapshot, result: GopalaSelectionResult)
signal selected_entity_refreshed(snapshot: GopalaSelectionSnapshot)
signal selection_reset(snapshot: GopalaSelectionSnapshot)

const SNAPSHOT_REASON_SELECTED: StringName = &"SELECTED"
const SNAPSHOT_REASON_NOT_SELECTED: StringName = &"NOT_SELECTED"

var _queries: GopalaEntityQueryService
var _registry: GopalaEntityRegistry
var _selected_entity_id := 0
var _selection_sequence := 0
var _emission_depth := 0

var selected_entity_id: int:
	get: return _selected_entity_id
var selection_sequence: int:
	get: return _selection_sequence

## One-shot dependency injection: the read facade plus the registry lifecycle
## signals that invalidate or refresh selection.
func configure(queries: GopalaEntityQueryService, registry: GopalaEntityRegistry) -> bool:
	if queries == null or not is_instance_valid(queries) \
			or registry == null or not is_instance_valid(registry) \
			or _queries != null or _registry != null:
		return false
	_queries = queries
	_registry = registry
	registry.entity_committed.connect(_on_entity_committed)
	registry.entity_removed.connect(_on_entity_removed)
	registry.registry_reset.connect(_on_registry_reset)
	return true

func select_entity(entity_id: int) -> GopalaSelectionResult:
	var reject := _reject_reason()
	if not reject.is_empty():
		return _result(GopalaSelectionResult.Status.REJECTED, reject)
	var previous := _selected_entity_id
	if entity_id <= 0:
		return _result(GopalaSelectionResult.Status.REJECTED,
			GopalaSelectionResult.INVALID_ID, previous)
	var entity := _queries.snapshot(entity_id)
	if entity == null:
		return _result(GopalaSelectionResult.Status.REJECTED,
			GopalaSelectionResult.NOT_FOUND, previous)
	if entity_id == previous:
		return _result(GopalaSelectionResult.Status.UNCHANGED,
			GopalaSelectionResult.ALREADY_SELECTED, entity_id)
	_selected_entity_id = entity_id
	_selection_sequence += 1
	var reason := GopalaSelectionResult.SELECTED if previous == 0 \
		else GopalaSelectionResult.REPLACED
	var state_snapshot := _entity_snapshot(entity, reason)
	var result := _result(GopalaSelectionResult.Status.APPLIED, reason,
		entity_id, previous)
	_emit_changed(state_snapshot, result)
	return result

## Clears selection. Allowed reasons: CLEARED, ENTITY_REMOVED, SESSION_RESET.
func clear_selection(reason: StringName = GopalaSelectionResult.CLEARED) -> GopalaSelectionResult:
	var reject := _reject_reason()
	if not reject.is_empty():
		return _result(GopalaSelectionResult.Status.REJECTED, reject)
	if reason not in [GopalaSelectionResult.CLEARED, GopalaSelectionResult.ENTITY_REMOVED,
			GopalaSelectionResult.SESSION_RESET]:
		reason = GopalaSelectionResult.CLEARED
	var previous := _selected_entity_id
	if previous == 0:
		return _result(GopalaSelectionResult.Status.UNCHANGED,
			GopalaSelectionResult.ALREADY_CLEAR, 0)
	_selected_entity_id = 0
	_selection_sequence += 1
	var state_snapshot := _empty_snapshot(reason)
	var result := _result(GopalaSelectionResult.Status.APPLIED, reason, 0, previous)
	_emit_changed(state_snapshot, result)
	return result

## Session boundary: clears selection and restarts the local sequence at 0.
## Emits selection_reset exactly once when something was selected; no signal
## when already clear (prevents a duplicate clear during SettlementSimulation
## reset, which resets selection before the registry).
func reset(reason: StringName = GopalaSelectionResult.SESSION_RESET) -> GopalaSelectionResult:
	var reject := _reject_reason()
	if not reject.is_empty():
		return _result(GopalaSelectionResult.Status.REJECTED, reject)
	var previous := _selected_entity_id
	_selected_entity_id = 0
	_selection_sequence = 0
	if previous == 0:
		return _result(GopalaSelectionResult.Status.UNCHANGED,
			GopalaSelectionResult.ALREADY_CLEAR, 0)
	var state_snapshot := _empty_snapshot(reason)
	var result := _result(GopalaSelectionResult.Status.APPLIED, reason, 0, previous)
	_emission_depth += 1
	selection_reset.emit(state_snapshot)
	_emission_depth -= 1
	return result

## Read-only snapshot of current selection state. Reason is derived:
## SELECTED while an entity is selected, NOT_SELECTED while empty.
func snapshot() -> GopalaSelectionSnapshot:
	if _selected_entity_id == 0:
		return _empty_snapshot(SNAPSHOT_REASON_NOT_SELECTED)
	var entity := _queries.snapshot(_selected_entity_id) if _queries != null else null
	if entity == null:
		return _empty_snapshot(GopalaSelectionResult.NOT_FOUND)
	return _entity_snapshot(entity, SNAPSHOT_REASON_SELECTED)

func _on_entity_committed(entity: GopalaEntitySnapshot) -> void:
	if entity == null or entity.entity_id != _selected_entity_id:
		return
	var refreshed := _entity_snapshot(entity, SNAPSHOT_REASON_SELECTED)
	_emission_depth += 1
	selected_entity_refreshed.emit(refreshed)
	_emission_depth -= 1

## Reactive invalidation runs even while a selection signal is dispatching:
## a removal must never leave a stale selected ID. The nested state commit is
## complete before its own signals fire.
func _on_entity_removed(entity_id: int, _kind: StringName, _registry_sequence: int) -> void:
	if entity_id == 0 or entity_id != _selected_entity_id:
		return
	_selected_entity_id = 0
	_selection_sequence += 1
	var state_snapshot := _empty_snapshot(GopalaSelectionResult.ENTITY_REMOVED)
	var result := _result(GopalaSelectionResult.Status.APPLIED,
		GopalaSelectionResult.ENTITY_REMOVED, 0, entity_id)
	_emit_changed(state_snapshot, result)

func _on_registry_reset() -> void:
	if _selected_entity_id == 0:
		return
	var previous := _selected_entity_id
	_selected_entity_id = 0
	_selection_sequence += 1
	var state_snapshot := _empty_snapshot(GopalaSelectionResult.SESSION_RESET)
	var result := _result(GopalaSelectionResult.Status.APPLIED,
		GopalaSelectionResult.SESSION_RESET, 0, previous)
	_emit_changed(state_snapshot, result)

func _reject_reason() -> StringName:
	if _queries == null or not is_instance_valid(_queries) \
			or _registry == null or not is_instance_valid(_registry):
		return GopalaSelectionResult.NOT_CONFIGURED
	if _emission_depth > 0:
		return GopalaSelectionResult.REENTRANT_MUTATION
	return &""

func _result(status: GopalaSelectionResult.Status, reason: StringName,
		current_id: int = 0, previous_id: int = 0,
		details: Dictionary = {}) -> GopalaSelectionResult:
	return GopalaSelectionResult.new(status, reason, current_id, previous_id,
		_selection_sequence, details)

func _registry_sequence() -> int:
	if _queries == null or not is_instance_valid(_queries):
		return 0
	return int(_queries.registry_summary().get("registry_sequence", 0))

func _entity_snapshot(entity: GopalaEntitySnapshot, reason: StringName) -> GopalaSelectionSnapshot:
	return GopalaSelectionSnapshot.new(_selection_sequence, entity.entity_id,
		entity.kind, entity.revision, _registry_sequence(),
		GopalaSelectionSnapshot.State.ENTITY, reason, entity)

func _empty_snapshot(reason: StringName) -> GopalaSelectionSnapshot:
	return GopalaSelectionSnapshot.empty(_selection_sequence, _registry_sequence(), reason)

func _emit_changed(state_snapshot: GopalaSelectionSnapshot,
		result: GopalaSelectionResult) -> void:
	_emission_depth += 1
	selection_changed.emit(state_snapshot, result)
	_emission_depth -= 1
