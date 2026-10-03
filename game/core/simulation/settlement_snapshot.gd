class_name GopalaSettlementSnapshot
extends RefCounted

var valid: bool:
	get: return _valid
var _valid: bool = false
var schema_version: int:
	get: return _schema_version
var sequence: int:
	get: return _sequence
var logical_tick: int:
	get: return _logical_tick
var paused: bool:
	get: return _paused
var speed: int:
	get: return _speed
var elapsed_logical_time: float:
	get: return _elapsed_logical_time
var resource_balances: Dictionary:
	get: return GopalaSimulationCommand.copy_plain_dictionary(_resource_balances)
var capabilities: Dictionary:
	get: return GopalaSimulationCommand.copy_plain_dictionary(_capabilities)
var entity_count: int:
	get: return _entity_count
var entity_counts_by_kind: Dictionary:
	get: return GopalaPlainData.copy_dictionary(_entity_counts_by_kind)
var entity_counts_by_kind_rows: Array:
	get: return GopalaPlainData.copy_value(_entity_counts_by_kind_rows)
var entity_registry_sequence: int:
	get: return _entity_registry_sequence

var _schema_version: int = 0
var _sequence: int = 0
var _logical_tick: int = 0
var _paused: bool = true
var _speed: int = 1
var _elapsed_logical_time: float = 0.0
var _resource_balances: Dictionary = {}
var _capabilities: Dictionary = {}
var _entity_count := 0
var _entity_counts_by_kind: Dictionary = {}
var _entity_counts_by_kind_rows: Array = []
var _entity_registry_sequence := 0

func _init(snapshot_sequence: int = 0, tick: int = 0, is_paused: bool = true,
		play_speed: int = 1, elapsed_time: float = 0.0,
		balances: Dictionary = {}, capability_map: Dictionary = {},
		registry_count: int = 0, registry_counts_by_kind: Dictionary = {},
		registry_sequence: int = 0, registry_counts_by_kind_rows: Array = []) -> void:
	if snapshot_sequence < 0 or tick < 0 or play_speed < 1 or play_speed > 4 \
			or not is_finite(elapsed_time) or elapsed_time < 0.0 \
			or registry_count < 0 or registry_sequence < 0:
		return
	if not GopalaSimulationCommand.validate_plain_data(balances) \
			or not GopalaSimulationCommand.validate_plain_data(capability_map) \
			or not GopalaPlainData.validate(registry_counts_by_kind) \
			or not GopalaPlainData.validate(registry_counts_by_kind_rows):
		return
	_schema_version = GopalaSimulationConfig.SNAPSHOT_SCHEMA_VERSION
	_sequence = snapshot_sequence
	_logical_tick = tick
	_paused = is_paused
	_speed = play_speed
	_elapsed_logical_time = elapsed_time
	_resource_balances = GopalaSimulationCommand.copy_plain_dictionary(balances)
	_capabilities = GopalaSimulationCommand.copy_plain_dictionary(capability_map)
	_entity_count = registry_count
	_entity_counts_by_kind = GopalaPlainData.copy_dictionary(registry_counts_by_kind)
	_entity_counts_by_kind_rows = GopalaPlainData.copy_value(registry_counts_by_kind_rows)
	_entity_registry_sequence = registry_sequence
	_valid = true
