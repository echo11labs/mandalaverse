class_name GopalaEntityRecord
extends RefCounted

const SCHEMA_VERSION: int = 1

var _entity_id: int
var _kind: StringName
var _lifecycle: GopalaEntityLifecycle.State
var _revision: int
var _created_tick: int
var _updated_tick: int
var _attributes: Dictionary
var _links: Dictionary

func _init(entity_id: int, kind: StringName, lifecycle: GopalaEntityLifecycle.State,
		revision: int, created_tick: int, updated_tick: int,
		attributes: Dictionary, links: Dictionary) -> void:
	_entity_id = entity_id
	_kind = kind
	_lifecycle = lifecycle
	_revision = revision
	_created_tick = created_tick
	_updated_tick = updated_tick
	_attributes = copy_plain_dictionary(attributes)
	_links = copy_plain_dictionary(links)

func snapshot(registry_sequence: int) -> GopalaEntitySnapshot:
	return GopalaEntitySnapshot.new(SCHEMA_VERSION, registry_sequence, _entity_id,
		_kind, _lifecycle, _revision, _created_tick, _updated_tick,
		_attributes, _links)

static func validate_plain_data(value: Variant, max_depth: int = GopalaPlainData.MAX_NESTING_DEPTH) -> bool:
	return GopalaPlainData.validate(value, max_depth)

static func copy_plain_dictionary(value: Dictionary) -> Dictionary:
	return GopalaPlainData.copy_dictionary(value)

static func _copy_plain(value: Variant) -> Variant:
	return GopalaPlainData.copy_value(value)
