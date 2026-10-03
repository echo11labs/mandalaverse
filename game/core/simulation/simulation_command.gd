class_name GopalaSimulationCommand
extends RefCounted

const SET_PAUSED: StringName = &"SET_PAUSED"
const SET_SPEED: StringName = &"SET_SPEED"
const REQUEST_CONSTRUCTION: StringName = &"REQUEST_CONSTRUCTION"
const KNOWN_TYPES: Array[StringName] = [SET_PAUSED, SET_SPEED, REQUEST_CONSTRUCTION]

var command_id: int:
	get: return _command_id
var command_type: StringName:
	get: return _command_type
var submitted_tick: int:
	get: return _submitted_tick
var payload: Dictionary:
	get: return copy_plain_dictionary(_payload)
var source_id: StringName:
	get: return _source_id
var _command_id: int
var _command_type: StringName
var _submitted_tick: int
var _payload: Dictionary
var _source_id: StringName

static func _from_queue(id: int, type: StringName, tick: int, data: Dictionary, source: StringName) -> GopalaSimulationCommand:
	var command := GopalaSimulationCommand.new()
	command._command_id = id
	command._command_type = type
	command._submitted_tick = tick
	command._payload = copy_plain_dictionary(data)
	command._source_id = source
	return command

static func validate_plain_data(value: Variant, depth: int = 0) -> bool:
	if depth > GopalaSimulationConfig.MAX_PAYLOAD_DEPTH:
		return false
	if value == null or typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME]:
		return true
	if typeof(value) == TYPE_OBJECT:
		return false
	if typeof(value) == TYPE_RID:
		return false
	if typeof(value) == TYPE_SIGNAL:
		return false
	if typeof(value) == TYPE_CALLABLE:
		return false
	if typeof(value) == TYPE_FLOAT:
		return is_finite(float(value))
	if value is Array:
		for item in value:
			if not validate_plain_data(item, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT]:
				return false
			if not validate_plain_data(value[key], depth + 1):
				return false
		return true
	return false

static func copy_plain_dictionary(value: Dictionary) -> Dictionary:
	return _copy_plain(value) as Dictionary

static func _copy_plain(value: Variant) -> Variant:
	if value is Dictionary:
		var copied: Dictionary = {}
		for key in value:
			copied[key] = _copy_plain(value[key])
		return copied
	if value is Array:
		var copied: Array = []
		for item in value:
			copied.append(_copy_plain(item))
		return copied
	return value
