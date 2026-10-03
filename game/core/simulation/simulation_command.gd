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

static func validate_plain_data(value: Variant) -> bool:
	return GopalaPlainData.validate(value, GopalaSimulationConfig.MAX_PAYLOAD_DEPTH)

static func copy_plain_dictionary(value: Dictionary) -> Dictionary:
	return GopalaPlainData.copy_dictionary(value)
