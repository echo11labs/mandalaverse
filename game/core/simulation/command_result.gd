class_name GopalaCommandResult
extends RefCounted

enum Status { APPLIED, REJECTED, UNSUPPORTED }

const REASON_APPLIED: StringName = &"APPLIED"
const REASON_INVALID_COMMAND: StringName = &"INVALID_COMMAND"
const REASON_INVALID_PAYLOAD: StringName = &"INVALID_PAYLOAD"
const REASON_INVALID_VALUE: StringName = &"INVALID_VALUE"
const REASON_PLACEMENT_UNAVAILABLE: StringName = &"PLACEMENT_UNAVAILABLE"
const REASON_UNKNOWN_COMMAND: StringName = &"UNKNOWN_COMMAND"

var command_id: int:
	get: return _command_id
var status: Status:
	get: return _status
var reason_code: StringName:
	get: return _reason_code
var processed_tick: int:
	get: return _processed_tick
var _command_id: int
var _status: Status
var _reason_code: StringName
var _processed_tick: int
var _details: Dictionary
var _valid: bool = false

func _init(id: int, result_status: Status, result_reason: StringName, tick: int,
		details: Dictionary = {}) -> void:
	_command_id = id
	_status = result_status
	_reason_code = result_reason
	_processed_tick = tick
	if not GopalaSimulationCommand.validate_plain_data(details):
		return
	_details = GopalaSimulationCommand.copy_plain_dictionary(details)
	_valid = true

var valid: bool:
	get: return _valid

func details() -> Dictionary:
	return GopalaSimulationCommand.copy_plain_dictionary(_details)
