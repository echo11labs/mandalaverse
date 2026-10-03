class_name GopalaEntitySnapshot
extends RefCounted

var valid: bool:
	get: return _valid
var schema_version: int:
	get: return _schema_version
var registry_sequence: int:
	get: return _registry_sequence
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
	get: return GopalaEntityRecord.copy_plain_dictionary(_attributes)
var links: Dictionary:
	get: return GopalaEntityRecord.copy_plain_dictionary(_links)

var _valid := false
var _schema_version := 0
var _registry_sequence := 0
var _entity_id := 0
var _kind: StringName = &""
var _lifecycle: GopalaEntityLifecycle.State = GopalaEntityLifecycle.State.REMOVED
var _revision := 0
var _created_tick := 0
var _updated_tick := 0
var _attributes: Dictionary = {}
var _links: Dictionary = {}

func _init(version: int, sequence: int, id: int, entity_kind: StringName,
		entity_lifecycle: GopalaEntityLifecycle.State, entity_revision: int,
		created: int, updated: int, entity_attributes: Dictionary,
		entity_links: Dictionary) -> void:
	if version <= 0 or sequence < 0 or id <= 0 \
			or not GopalaEntityKind.is_valid(entity_kind) \
			or not GopalaEntityLifecycle.is_valid(entity_lifecycle) \
			or entity_revision <= 0 or created < 0 or updated < created:
		return
	if not GopalaEntityRecord.validate_plain_data(entity_attributes) \
			or not GopalaEntityRecord.validate_plain_data(entity_links):
		return
	_schema_version = version
	_registry_sequence = sequence
	_entity_id = id
	_kind = entity_kind
	_lifecycle = entity_lifecycle
	_revision = entity_revision
	_created_tick = created
	_updated_tick = updated
	_attributes = GopalaEntityRecord.copy_plain_dictionary(entity_attributes)
	_links = GopalaEntityRecord.copy_plain_dictionary(entity_links)
	_valid = true
