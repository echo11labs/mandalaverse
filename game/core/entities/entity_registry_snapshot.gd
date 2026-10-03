class_name GopalaEntityRegistrySnapshot
extends RefCounted

var valid: bool:
	get: return _valid
var schema_version: int:
	get: return _schema_version
var registry_sequence: int:
	get: return _registry_sequence
var entity_count: int:
	get: return _entity_count
var counts_by_kind: Dictionary:
	get: return GopalaEntityRecord.copy_plain_dictionary(_counts_by_kind)
var entities: Array[GopalaEntitySnapshot]:
	get:
		var copied: Array[GopalaEntitySnapshot] = []
		for entity in _entities:
			copied.append(entity)
		return copied
var counts_by_kind_array: Array:
	get: return GopalaPlainData.copy_value(_counts_by_kind_array)

var _valid := false
var _schema_version := 0
var _registry_sequence := 0
var _entity_count := 0
var _counts_by_kind: Dictionary = {}
var _counts_by_kind_array: Array = []
var _entities: Array[GopalaEntitySnapshot] = []

func _init(version: int, sequence: int, snapshots: Array[GopalaEntitySnapshot]) -> void:
	if version <= 0 or sequence < 0:
		return
	var copied: Array[GopalaEntitySnapshot] = []
	var counts: Dictionary = {}
	var previous_id := 0
	for snapshot in snapshots:
		if snapshot == null or not is_instance_valid(snapshot) or not snapshot.valid \
				or snapshot.registry_sequence != sequence or snapshot.entity_id <= previous_id:
			return
		previous_id = snapshot.entity_id
		copied.append(snapshot)
		counts[snapshot.kind] = int(counts.get(snapshot.kind, 0)) + 1
	var count_rows: Array = []
	var kinds: Array = counts.keys()
	kinds.sort()
	for kind in kinds:
		count_rows.append({"kind": String(kind), "count": int(counts[kind])})
	_schema_version = version
	_registry_sequence = sequence
	_entity_count = copied.size()
	_counts_by_kind = GopalaEntityRecord.copy_plain_dictionary(counts)
	_counts_by_kind_array = GopalaPlainData.copy_value(count_rows)
	_entities = copied
	_valid = true
