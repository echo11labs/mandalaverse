class_name GopalaEntityPickResolver3D
extends RefCounted
## Presentation-only resolver: maps a physics collider to an entity ID by
## walking the collider's ancestor chain for a live EntityViewAdapter3D.
## Never iterates SceneTree groups, never retains colliders, never mutates the
## registry, and validates the final ID through the read-only query facade.

const MISS: int = 0

var _queries: GopalaEntityQueryService
var _collision_mask: int = 1

## One-shot dependency injection of the read-only facade.
func configure(queries: GopalaEntityQueryService) -> bool:
	if queries == null or not is_instance_valid(queries) or _queries != null:
		return false
	_queries = queries
	return true

## Injectable collision mask; not hard-coded to any production layer.
func set_collision_mask(mask: int) -> void:
	_collision_mask = mask if mask > 0 else 1

func collision_mask() -> int:
	return _collision_mask

## Returns a validated entity ID, or MISS (0) for terrain, decorative props,
## stale/unbound/disabled adapters, freed nodes, or invalid IDs.
func resolve_collider(collider: Variant) -> int:
	var node := collider as Node
	if node == null or not is_instance_valid(node):
		return MISS
	var current: Node = node
	while current != null and is_instance_valid(current):
		if current is GopalaEntityViewAdapter3D:
			return _validated_id(current as GopalaEntityViewAdapter3D)
		current = current.get_parent()
	return MISS

## Real ray pick through the injected collision mask. The collider reference
## lives only inside this call.
func pick(space_state: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> int:
	if space_state == null or _queries == null or not is_instance_valid(_queries):
		return MISS
	var query := PhysicsRayQueryParameters3D.create(from, to, _collision_mask)
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return MISS
	return resolve_collider(hit.get("collider"))

func _validated_id(adapter: GopalaEntityViewAdapter3D) -> int:
	if adapter == null or not is_instance_valid(adapter) \
			or not adapter.selectable_enabled:
		return MISS
	var entity_id := adapter.bound_entity_id
	if entity_id <= 0 or not _queries.has_entity(entity_id):
		return MISS
	return entity_id
