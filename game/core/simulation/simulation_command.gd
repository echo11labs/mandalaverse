class_name GopalaSimulationCommand
extends RefCounted

const SET_PAUSED: StringName = &"SET_PAUSED"
const SET_WORK_ROLE: StringName = &"SET_WORK_ROLE"
const SET_SPEED: StringName = &"SET_SPEED"
const REQUEST_CONSTRUCTION: StringName = &"REQUEST_CONSTRUCTION"
const REQUEST_SPAWN_VILLAGER: StringName = &"REQUEST_SPAWN_VILLAGER"
const REQUEST_MOVE_VILLAGER: StringName = &"REQUEST_MOVE_VILLAGER"
const COLLECTIBLE_RESOURCES: Array[StringName] = [&"timber", &"stone", &"thatch", &"wild_food", &"fodder", &"water", &"milk"]
const REQUEST_GATHER_RESOURCE: StringName = &"REQUEST_GATHER_RESOURCE"
const REQUEST_GATHER_STONE: StringName = &"REQUEST_GATHER_STONE"
const REQUEST_GATHER_TIMBER: StringName = &"REQUEST_GATHER_TIMBER"
const REQUEST_STOP_GATHERING: StringName = &"REQUEST_STOP_GATHERING"
const REQUEST_ASSIGN_BUILDER: StringName = &"REQUEST_ASSIGN_BUILDER"
const REQUEST_CANCEL_CONSTRUCTION: StringName = &"REQUEST_CANCEL_CONSTRUCTION"
const ASSIGN_CATTLE_PASTURE: StringName = &"ASSIGN_CATTLE_PASTURE"
const CREATE_PASTURE: StringName = &"CREATE_PASTURE"
const KNOWN_TYPES: Array[StringName] = [
	CREATE_PASTURE,
	ASSIGN_CATTLE_PASTURE,
	SET_PAUSED,
	SET_SPEED,
	SET_WORK_ROLE,
	REQUEST_CONSTRUCTION,
	REQUEST_SPAWN_VILLAGER,
	REQUEST_MOVE_VILLAGER,
	REQUEST_GATHER_TIMBER,
	REQUEST_GATHER_STONE,
	REQUEST_GATHER_RESOURCE,
	REQUEST_STOP_GATHERING,
	REQUEST_ASSIGN_BUILDER,
	REQUEST_CANCEL_CONSTRUCTION
]

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
