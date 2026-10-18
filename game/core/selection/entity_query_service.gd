class_name GopalaEntityQueryService
extends Node
## Read-only facade over one EntityRegistry for presentation and query consumers.
## Exposes no mutation path: create/update/remove/reset and the allocator stay
## behind SettlementSimulation's domain boundary.

var _registry: GopalaEntityRegistry

## One-shot dependency injection; the parent session owns the lifetime.
func configure(registry: GopalaEntityRegistry) -> bool:
	if registry == null or not is_instance_valid(registry) or _registry != null:
		return false
	_registry = registry
	return true

func has_entity(entity_id: int) -> bool:
	return _registry != null and is_instance_valid(_registry) and _registry.has_entity(entity_id)

func snapshot(entity_id: int) -> GopalaEntitySnapshot:
	if _registry == null or not is_instance_valid(_registry):
		return null
	return _registry.snapshot(entity_id)

func snapshots_by_kind(kind: StringName) -> Array[GopalaEntitySnapshot]:
	if _registry == null or not is_instance_valid(_registry):
		return []
	return _registry.snapshots_by_kind(kind)

## Defensive summary DTO: registry_sequence, entity_count, counts_by_kind.
## Does not materialize per-entity snapshots.
func registry_summary() -> Dictionary:
	if _registry == null or not is_instance_valid(_registry):
		return {"registry_sequence": 0, "entity_count": 0, "counts_by_kind": {}}
	return GopalaPlainData.copy_dictionary(_registry.registry_summary())

func validate_reference(entity_id: int) -> bool:
	return has_entity(entity_id)

## Read-only inspection of one entity by ID.
func inspect(entity_id: int) -> GopalaEntityInspectionSnapshot:
	var entity := snapshot(entity_id)
	if entity == null:
		return GopalaEntityInspectionSnapshot.unavailable(entity_id, &"NOT_FOUND")
	return GopalaEntityInspectionSnapshot.from_entity(entity)

## Read-only inspection derived from a selection snapshot.
func inspect_selection(selection: GopalaSelectionSnapshot) -> GopalaEntityInspectionSnapshot:
	if selection == null or selection.state != GopalaSelectionSnapshot.State.ENTITY:
		return GopalaEntityInspectionSnapshot.unavailable(0, &"NOT_FOUND")
	return inspect(selection.selected_entity_id)
