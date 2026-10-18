class_name GopalaSelectionSnapshot
extends RefCounted
## Immutable selection DTO. Contains only plain data plus an optional immutable
## EntitySnapshot; never Node/Resource/collider/camera references.

const SCHEMA_VERSION: int = 1

enum State { NONE, ENTITY }

var valid: bool:
	get: return _valid
var schema_version: int:
	get: return _schema_version
var selection_sequence: int:
	get: return _selection_sequence
var selected_entity_id: int:
	get: return _selected_entity_id
var selected_kind: StringName:
	get: return _selected_kind
var selected_entity_revision: int:
	get: return _selected_entity_revision
var selected_registry_sequence: int:
	get: return _selected_registry_sequence
var state: State:
	get: return _state
var change_reason: StringName:
	get: return _change_reason
var entity: GopalaEntitySnapshot:
	get: return _entity

var _valid := false
var _schema_version := 0
var _selection_sequence := 0
var _selected_entity_id := 0
var _selected_kind: StringName = &""
var _selected_entity_revision := 0
var _selected_registry_sequence := 0
var _state: State = State.NONE
var _change_reason: StringName = &""
var _entity: GopalaEntitySnapshot = null

func _init(sequence: int = 0, entity_id: int = 0, kind: StringName = &"",
		entity_revision: int = 0, registry_sequence: int = 0,
		selection_state: State = State.NONE, reason: StringName = &"",
		entity_snapshot: GopalaEntitySnapshot = null) -> void:
	if sequence < 0 or entity_id < 0 or entity_revision < 0 or registry_sequence < 0:
		return
	if selection_state == State.ENTITY:
		if entity_id <= 0 or entity_revision <= 0 or not GopalaEntityKind.is_valid(kind) \
				or entity_snapshot == null or not entity_snapshot.valid \
				or entity_snapshot.entity_id != entity_id \
				or entity_snapshot.revision != entity_revision:
			return
	elif entity_id != 0 or entity_revision != 0 or not kind.is_empty() or entity_snapshot != null:
		return
	if reason.is_empty():
		return
	_schema_version = SCHEMA_VERSION
	_selection_sequence = sequence
	_selected_entity_id = entity_id
	_selected_kind = kind
	_selected_entity_revision = entity_revision
	_selected_registry_sequence = registry_sequence
	_state = selection_state
	_change_reason = reason
	_entity = entity_snapshot
	_valid = true

static func empty(sequence: int, registry_sequence: int, reason: StringName) -> GopalaSelectionSnapshot:
	return GopalaSelectionSnapshot.new(sequence, 0, &"", 0, registry_sequence,
		State.NONE, reason, null)
