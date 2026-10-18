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

var grid_configured: bool:
	get: return _grid_configured
var occupancy_sequence: int:
	get: return _occupancy_sequence
var claim_count: int:
	get: return _claim_count
var reserved_cell_count: int:
	get: return _reserved_cell_count
var occupied_cell_count: int:
	get: return _occupied_cell_count

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
var _grid_configured: bool = false
var _occupancy_sequence: int = 0
var _claim_count: int = 0
var _reserved_cell_count: int = 0
var _occupied_cell_count: int = 0

func _init(snapshot_sequence: int = 0, tick: int = 0, is_paused: bool = true,
		play_speed: int = 1, elapsed_time: float = 0.0,
		balances: Dictionary = {}, capability_map: Dictionary = {},
		registry_count: int = 0, registry_counts_by_kind: Dictionary = {},
		registry_sequence: int = 0, registry_counts_by_kind_rows: Array = [],
		p_grid_configured: bool = false, p_occ_sequence: int = 0,
		p_claim_count: int = 0, p_reserved: int = 0, p_occupied: int = 0) -> void:
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
	_grid_configured = p_grid_configured
	_occupancy_sequence = p_occ_sequence
	_claim_count = p_claim_count
	_reserved_cell_count = p_reserved
	_occupied_cell_count = p_occupied
	_valid = true
