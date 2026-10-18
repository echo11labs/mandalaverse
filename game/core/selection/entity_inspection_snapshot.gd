class_name GopalaEntityInspectionSnapshot
extends RefCounted
## Immutable read-only inspection DTO. Development/query data only: raw
## attributes are exposed for tooling and tests, not as final player UI.

const SCHEMA_VERSION: int = 1
const REASON_NOT_FOUND: StringName = &"NOT_FOUND"

var valid: bool:
	get: return _valid
var schema_version: int:
	get: return _schema_version
var availability: bool:
	get: return _availability
var unavailable_reason: StringName:
	get: return _unavailable_reason
var entity_id: int:
	get: return _entity_id
var kind: StringName:
	get: return _kind
var lifecycle: GopalaEntityLifecycle.State:
	get: return _lifecycle
var revision: int:
	get: return _revision
var created_tick: int:
	get: return _created_tick
var updated_tick: int:
	get: return _updated_tick
var attributes: Dictionary:
	get: return GopalaPlainData.copy_dictionary(_attributes)
var links: Dictionary:
	get: return GopalaPlainData.copy_dictionary(_links)

var _valid := false
var _schema_version := 0
var _availability := false
var _unavailable_reason: StringName = &""
var _entity_id := 0
var _kind: StringName = &""
var _lifecycle: GopalaEntityLifecycle.State = GopalaEntityLifecycle.State.REMOVED
var _revision := 0
var _created_tick := 0
var _updated_tick := 0
var _attributes: Dictionary = {}
var _links: Dictionary = {}

func _init(available: bool, reason: StringName, id: int, entity_kind: StringName,
		entity_lifecycle: GopalaEntityLifecycle.State, entity_revision: int,
		created: int, updated: int, entity_attributes: Dictionary,
		entity_links: Dictionary) -> void:
	if id < 0:
		return
	if available:
		if not GopalaEntityKind.is_valid(entity_kind) \
				or not GopalaEntityLifecycle.is_valid(entity_lifecycle) \
				or entity_revision <= 0 or created < 0 or updated < created \
				or not GopalaPlainData.validate(entity_attributes) \
				or not GopalaPlainData.validate(entity_links):
			return
		if not reason.is_empty():
			return
	else:
		if reason != REASON_NOT_FOUND:
			return
		if entity_kind != &"" or entity_revision != 0 or entity_attributes.size() > 0 \
				or entity_links.size() > 0:
			return
	_schema_version = SCHEMA_VERSION
	_availability = available
	_unavailable_reason = reason
	_entity_id = id
	_kind = entity_kind
	_lifecycle = entity_lifecycle
	_revision = entity_revision
	_created_tick = created
	_updated_tick = updated
	_attributes = GopalaPlainData.copy_dictionary(entity_attributes)
	_links = GopalaPlainData.copy_dictionary(entity_links)
	_valid = true

static func from_entity(entity: GopalaEntitySnapshot) -> GopalaEntityInspectionSnapshot:
	if entity == null or not entity.valid:
		return unavailable(entity.entity_id if entity != null else 0, REASON_NOT_FOUND)
	return GopalaEntityInspectionSnapshot.new(true, &"", entity.entity_id,
		entity.kind, entity.lifecycle, entity.revision, entity.created_tick,
		entity.updated_tick, entity.attributes, entity.links)

static func unavailable(id: int, reason: StringName) -> GopalaEntityInspectionSnapshot:
	return GopalaEntityInspectionSnapshot.new(false, reason, id, &"",
		GopalaEntityLifecycle.State.REMOVED, 0, 0, 0, {}, {})
