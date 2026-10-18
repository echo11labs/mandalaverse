class_name GopalaEntityOperationResult
extends RefCounted

enum Status { APPLIED, REJECTED }

const APPLIED: StringName = &"APPLIED"
const INVALID_KIND: StringName = &"INVALID_KIND"
const INVALID_ATTRIBUTES: StringName = &"INVALID_ATTRIBUTES"
const INVALID_LINKS: StringName = &"INVALID_LINKS"
const INVALID_TICK: StringName = &"INVALID_TICK"
const NOT_FOUND: StringName = &"NOT_FOUND"
const STALE_REVISION: StringName = &"STALE_REVISION"
const REFERENCE_NOT_FOUND: StringName = &"REFERENCE_NOT_FOUND"
const REFERENCED_BY: StringName = &"REFERENCED_BY"
const INVALID_REMOVAL_POLICY: StringName = &"INVALID_REMOVAL_POLICY"
const INVALID_OPERATION: StringName = &"INVALID_OPERATION"
const REENTRANT_MUTATION: StringName = &"REENTRANT_MUTATION"
const ID_ALLOCATION_FAILED: StringName = &"ID_ALLOCATION_FAILED"

var status: Status:
	get: return _status
var reason_code: StringName:
	get: return _reason_code
var entity_id: int:
	get: return _entity_id
var registry_sequence: int:
	get: return _registry_sequence
var valid: bool:
	get: return _valid

var _status: Status = Status.REJECTED
var _reason_code: StringName = INVALID_OPERATION
var _entity_id := 0
var _registry_sequence := 0
var _details: Dictionary = {}
var _valid := false

func _init(result_status: Status, reason: StringName, id: int,
		sequence: int, details: Dictionary = {}) -> void:
	if result_status not in [Status.APPLIED, Status.REJECTED] or sequence < 0:
		return
	if not GopalaEntityRecord.validate_plain_data(details):
		return
	_status = result_status
	_reason_code = reason
	_entity_id = id
	_registry_sequence = sequence
	_details = GopalaEntityRecord.copy_plain_dictionary(details)
	_valid = true

func details() -> Dictionary:
	return GopalaEntityRecord.copy_plain_dictionary(_details)
