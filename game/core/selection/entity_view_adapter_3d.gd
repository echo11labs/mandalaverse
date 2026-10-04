class_name GopalaEntityViewAdapter3D
extends Node3D
## Presentation-only binding between a world view node and an entity ID.
## Never stored in the registry, snapshots, commands, attributes or links.
## Validates through the read-only query facade; creates/updates nothing.

signal bound_entity_changed(entity_id: int)

var bound_entity_id: int:
	get: return _bound_entity_id
var selectable_enabled: bool = true

var _queries: GopalaEntityQueryService
var _bound_entity_id := 0

## One-shot dependency injection of the read-only facade.
func configure(queries: GopalaEntityQueryService) -> bool:
	if queries == null or not is_instance_valid(queries) or _queries != null:
		return false
	_queries = queries
	return true

## Binds only a live entity. An invalid/missing ID rejects and leaves the
## previous binding untouched.
func bind_entity(entity_id: int) -> bool:
	if _queries == null or not is_instance_valid(_queries) or entity_id <= 0:
		return false
	if not _queries.has_entity(entity_id):
		return false
	_bound_entity_id = entity_id
	bound_entity_changed.emit(entity_id)
	return true

func unbind_entity() -> void:
	if _bound_entity_id == 0:
		return
	_bound_entity_id = 0
	bound_entity_changed.emit(0)

## Resolution state: bound, enabled, and the entity still exists in the
## registry. Removal of the entity makes this false without any adapter call.
func is_resolved() -> bool:
	return _bound_entity_id > 0 and selectable_enabled \
		and _queries != null and is_instance_valid(_queries) \
		and _queries.has_entity(_bound_entity_id)

## Leaving the tree unbinds presentation state so stale adapters cannot resolve.
func _exit_tree() -> void:
	if _bound_entity_id != 0:
		_bound_entity_id = 0
		bound_entity_changed.emit(0)
