class_name GopalaSelectionResult
extends RefCounted
## Typed result for selection operations. Separate from CommandResult and
## EntityOperationResult so selection outcomes stay explicit.

enum Status { APPLIED, UNCHANGED, REJECTED }

const SELECTED: StringName = &"SELECTED"
const REPLACED: StringName = &"REPLACED"
const CLEARED: StringName = &"CLEARED"
const ALREADY_SELECTED: StringName = &"ALREADY_SELECTED"
const ALREADY_CLEAR: StringName = &"ALREADY_CLEAR"
const INVALID_ID: StringName = &"INVALID_ID"
const NOT_FOUND: StringName = &"NOT_FOUND"
const ENTITY_REMOVED: StringName = &"ENTITY_REMOVED"
const SESSION_RESET: StringName = &"SESSION_RESET"
const REENTRANT_MUTATION: StringName = &"REENTRANT_MUTATION"
## Internal defensive guard when the service has no injected dependencies.
const NOT_CONFIGURED: StringName = &"NOT_CONFIGURED"

var status: Status:
	get: return _status
var reason_code: StringName:
	get: return _reason_code
var selected_entity_id: int:
	get: return _selected_entity_id
var previous_entity_id: int:
	get: return _previous_entity_id
var selection_sequence: int:
	get: return _selection_sequence
var valid: bool:
	get: return _valid

var _status: Status = Status.REJECTED
var _reason_code: StringName = NOT_CONFIGURED
var _selected_entity_id := 0
var _previous_entity_id := 0
var _selection_sequence := 0
var _details: Dictionary = {}
var _valid := false

func _init(result_status: Status, reason: StringName, current_id: int,
		previous_id: int, sequence: int, details: Dictionary = {}) -> void:
	if result_status not in [Status.APPLIED, Status.UNCHANGED, Status.REJECTED]:
		return
	if current_id < 0 or previous_id < 0 or sequence < 0 or reason.is_empty():
		return
	if not GopalaPlainData.validate(details):
		return
	_status = result_status
	_reason_code = reason
	_selected_entity_id = current_id
	_previous_entity_id = previous_id
	_selection_sequence = sequence
	_details = GopalaPlainData.copy_dictionary(details)
	_valid = true

func details() -> Dictionary:
	return GopalaPlainData.copy_dictionary(_details)
