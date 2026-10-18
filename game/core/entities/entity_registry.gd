class_name GopalaEntityRegistry
extends Node

signal entity_committed(snapshot: GopalaEntitySnapshot)
signal entity_removed(entity_id: int, kind: StringName, registry_sequence: int)
signal registry_changed(snapshot: GopalaEntityRegistrySnapshot)
signal registry_reset()
## Internal completion notification emitted only after registry_changed callbacks return.
signal transaction_committed(snapshot: GopalaEntityRegistrySnapshot)

const SCHEMA_VERSION: int = 1
const MAX_SEQUENCE: int = 2_000_000_000

enum RemovalPolicy { REJECT_IF_REFERENCED, CLEAR_INCOMING_REFERENCES }

var _allocator: GopalaEntityIdAllocator
var _records: Dictionary[int, GopalaEntityRecord] = {}
var _kind_ids: Dictionary[StringName, Array] = {}
var _incoming: Dictionary[int, Dictionary] = {}
var _removed_ids: Dictionary[int, bool] = {}
var _sequence := 0
var _mutation_emitting := false
var _mutating := false

var registry_sequence: int:
	get: return _sequence
var entity_count: int:
	get: return _records.size()
var allocator: GopalaEntityIdAllocator:
	get: return _allocator

func configure(allocator: GopalaEntityIdAllocator) -> bool:
	if allocator == null or not is_instance_valid(allocator) or _allocator != null \
			or not _records.is_empty():
		return false
	_allocator = allocator
	return true

func create_entity(kind: StringName, attributes: Dictionary = {},
		links: Dictionary = {}, tick: int = 0) -> GopalaEntityOperationResult:
	if _reject_mutation():
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.REENTRANT_MUTATION)
	if not GopalaEntityKind.is_valid(kind):
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_KIND)
	if tick < 0:
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_TICK)
	if not GopalaEntityRecord.validate_plain_data(attributes):
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_ATTRIBUTES)
	if not GopalaEntityRecord.validate_plain_data(links):
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_LINKS)
	var links_error := _links_error(links)
	if links_error != GopalaEntityOperationResult.APPLIED:
		return _result(GopalaEntityOperationResult.Status.REJECTED, links_error)
	if not _can_commit_transaction():
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_OPERATION)
	_mutating = true
	var entity_id: int = _allocator.allocate()
	if entity_id <= 0 or _records.has(entity_id):
		_mutating = false
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.ID_ALLOCATION_FAILED)
	var record := GopalaEntityRecord.new(entity_id, kind,
		GopalaEntityLifecycle.State.ACTIVE, 1, tick, tick, attributes, links)
	_records[entity_id] = record
	_add_kind_id(kind, entity_id)
	_add_outgoing_references(record)
	_sequence += 1
	var committed := record.snapshot(_sequence)
	_emit_begin()
	entity_committed.emit(committed)
	var final_snapshot := registry_snapshot()
	registry_changed.emit(final_snapshot)
	transaction_committed.emit(final_snapshot)
	_emit_end()
	_mutating = false
	return _result(GopalaEntityOperationResult.Status.APPLIED,
		GopalaEntityOperationResult.APPLIED, entity_id)

## Attribute patch values set/replace a key; top-level null removes that key.
## Nested dictionaries are replaced atomically rather than shallow-merged.
func update_entity(entity_id: int, attribute_patch: Dictionary = {},
		link_patch: Dictionary = {}, tick: int = 0,
		expected_revision: int = 0) -> GopalaEntityOperationResult:
	if _reject_mutation():
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.REENTRANT_MUTATION, entity_id)
	if tick < 0:
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_TICK, entity_id)
	var record: GopalaEntityRecord = _records.get(entity_id)
	if record == null:
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.NOT_FOUND, entity_id)
	if _revision_limit_reached(record):
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_OPERATION, entity_id)
	if tick < record._updated_tick:
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_TICK, entity_id)
	if expected_revision > 0 and expected_revision != record._revision:
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.STALE_REVISION, entity_id)
	if expected_revision < 0:
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.STALE_REVISION, entity_id)
	if not GopalaEntityRecord.validate_plain_data(attribute_patch):
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_ATTRIBUTES, entity_id)
	if not GopalaEntityRecord.validate_plain_data(link_patch):
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_LINKS, entity_id)
	if attribute_patch.is_empty() and link_patch.is_empty():
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_OPERATION, entity_id)
	if not _can_commit_transaction():
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_OPERATION, entity_id)
	var next_attributes := GopalaPlainData.copy_dictionary(record._attributes)
	for key in attribute_patch:
		if attribute_patch[key] == null:
			next_attributes.erase(key)
		else:
			next_attributes[key] = GopalaPlainData.copy_value(attribute_patch[key])
	var next_links := GopalaPlainData.copy_dictionary(record._links)
	for key in link_patch:
		if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME] or StringName(key).is_empty():
			return _result(GopalaEntityOperationResult.Status.REJECTED,
				GopalaEntityOperationResult.INVALID_LINKS, entity_id)
		if link_patch[key] == null:
			next_links.erase(key)
		else:
			next_links[key] = GopalaPlainData.copy_value(link_patch[key])
	var links_error := _links_error(next_links)
	if links_error != GopalaEntityOperationResult.APPLIED:
		return _result(GopalaEntityOperationResult.Status.REJECTED, links_error, entity_id)
	if not _validate_incoming_rewrite(record, next_links):
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_LINKS, entity_id)
	if not _can_commit_transaction():
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_OPERATION, entity_id)
	_mutating = true
	_remove_outgoing_references(record)
	record._attributes = next_attributes
	record._links = next_links
	record._updated_tick = tick
	record._revision += 1
	_add_outgoing_references(record)
	_sequence += 1
	var committed := record.snapshot(_sequence)
	_emit_begin()
	entity_committed.emit(committed)
	var final_snapshot := registry_snapshot()
	registry_changed.emit(final_snapshot)
	transaction_committed.emit(final_snapshot)
	_emit_end()
	_mutating = false
	return _result(GopalaEntityOperationResult.Status.APPLIED,
		GopalaEntityOperationResult.APPLIED, entity_id)

func remove_entity(entity_id: int, removal_policy: RemovalPolicy,
		tick: int = 0) -> GopalaEntityOperationResult:
	if _reject_mutation():
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.REENTRANT_MUTATION, entity_id)
	var record: GopalaEntityRecord = _records.get(entity_id)
	if record == null:
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.NOT_FOUND, entity_id)
	if tick < 0 or tick < record._updated_tick:
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_TICK, entity_id)
	if removal_policy not in [RemovalPolicy.REJECT_IF_REFERENCED,
			RemovalPolicy.CLEAR_INCOMING_REFERENCES]:
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_REMOVAL_POLICY, entity_id)
	var blockers := _incoming_blockers(entity_id)
	if removal_policy == RemovalPolicy.REJECT_IF_REFERENCED and not blockers.is_empty():
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.REFERENCED_BY, entity_id,
			{"blockers": blockers})
	for blocker in blockers:
		var referring: GopalaEntityRecord = _records[int(blocker["entity_id"])]
		if _revision_limit_reached(referring):
			return _result(GopalaEntityOperationResult.Status.REJECTED,
				GopalaEntityOperationResult.INVALID_OPERATION, entity_id)
		if tick < referring._updated_tick:
			return _result(GopalaEntityOperationResult.Status.REJECTED,
				GopalaEntityOperationResult.INVALID_TICK, entity_id)
	if not _can_commit_transaction():
		return _result(GopalaEntityOperationResult.Status.REJECTED,
			GopalaEntityOperationResult.INVALID_OPERATION, entity_id)
	_mutating = true
	var changed_records: Array[GopalaEntityRecord] = []
	if removal_policy == RemovalPolicy.CLEAR_INCOMING_REFERENCES:
		var blocker_ids: Array[int] = []
		for blocker in blockers:
			var blocker_id := int(blocker["entity_id"])
			if blocker_ids.is_empty() or blocker_ids.back() != blocker_id:
				blocker_ids.append(blocker_id)
		for blocker_id in blocker_ids:
			var referring: GopalaEntityRecord = _records[blocker_id]
			_remove_outgoing_references(referring)
			referring._links = _remove_target_from_links(referring._links, entity_id)
			referring._revision += 1
			referring._updated_tick = tick
			_add_outgoing_references(referring)
			changed_records.append(referring)
	_remove_outgoing_references(record)
	_remove_kind_id(record._kind, entity_id)
	_records.erase(entity_id)
	_removed_ids[entity_id] = true
	_sequence += 1
	_emit_begin()
	for changed in changed_records:
		entity_committed.emit(changed.snapshot(_sequence))
	entity_removed.emit(entity_id, record._kind, _sequence)
	var final_snapshot := registry_snapshot()
	registry_changed.emit(final_snapshot)
	transaction_committed.emit(final_snapshot)
	_emit_end()
	_mutating = false
	return _result(GopalaEntityOperationResult.Status.APPLIED,
		GopalaEntityOperationResult.APPLIED, entity_id,
		{"cleared_references": changed_records.size() if removal_policy == RemovalPolicy.CLEAR_INCOMING_REFERENCES else 0})

func has_entity(entity_id: int) -> bool:
	return _records.has(entity_id)

func validate_reference(entity_id: int) -> bool:
	return _records.has(entity_id)

func snapshot(entity_id: int) -> GopalaEntitySnapshot:
	var record: GopalaEntityRecord = _records.get(entity_id)
	return record.snapshot(_sequence) if record != null else null

func snapshots_by_kind(kind: StringName) -> Array[GopalaEntitySnapshot]:
	var result: Array[GopalaEntitySnapshot] = []
	if not GopalaEntityKind.is_valid(kind):
		return result
	for entity_id in _kind_ids.get(kind, []):
		var record: GopalaEntityRecord = _records.get(entity_id)
		if record != null:
			result.append(record.snapshot(_sequence))
	return result

func registry_snapshot() -> GopalaEntityRegistrySnapshot:
	var snapshots: Array[GopalaEntitySnapshot] = []
	var ids: Array = _records.keys()
	ids.sort()
	for entity_id in ids:
		snapshots.append((_records[entity_id] as GopalaEntityRecord).snapshot(_sequence))
	return GopalaEntityRegistrySnapshot.new(SCHEMA_VERSION, _sequence, snapshots)

## Lightweight summary for read facades: no EntitySnapshot objects are built.
func registry_summary() -> Dictionary:
	var counts: Dictionary = {}
	for kind in _kind_ids:
		counts[kind] = _kind_ids[kind].size()
	return {"registry_sequence": _sequence, "entity_count": _records.size(),
		"counts_by_kind": GopalaPlainData.copy_dictionary(counts)}

func reset() -> bool:
	if _reject_mutation():
		return false
	_mutating = true
	_records.clear()
	_kind_ids.clear()
	_incoming.clear()
	_removed_ids.clear()
	_sequence = 0
	_emit_begin()
	registry_reset.emit()
	var final_snapshot := registry_snapshot()
	registry_changed.emit(final_snapshot)
	transaction_committed.emit(final_snapshot)
	_emit_end()
	_mutating = false
	return true

func _reject_mutation() -> bool:
	return _allocator == null or not is_instance_valid(_allocator) \
		or _mutation_emitting or _mutating

func _can_commit_transaction() -> bool:
	return _sequence < MAX_SEQUENCE

func _revision_limit_reached(record: GopalaEntityRecord) -> bool:
	return record._revision >= MAX_SEQUENCE

func _result(status: GopalaEntityOperationResult.Status, reason: StringName,
		entity_id: int = 0, details: Dictionary = {}) -> GopalaEntityOperationResult:
	return GopalaEntityOperationResult.new(status, reason, entity_id, _sequence, details)

func _emit_begin() -> void:
	_mutation_emitting = true

func _emit_end() -> void:
	_mutation_emitting = false

func _links_error(links: Dictionary) -> StringName:
	for relationship in links:
		if typeof(relationship) not in [TYPE_STRING, TYPE_STRING_NAME] or StringName(relationship).is_empty():
			return GopalaEntityOperationResult.INVALID_LINKS
		var raw_ids: Variant = links[relationship]
		var ids: Array = raw_ids if raw_ids is Array else [raw_ids]
		var unique: Dictionary = {}
		for raw_id in ids:
			if typeof(raw_id) != TYPE_INT or int(raw_id) <= 0:
				return GopalaEntityOperationResult.INVALID_LINKS
			var linked_id := int(raw_id)
			if unique.has(linked_id):
				return GopalaEntityOperationResult.INVALID_LINKS
			if not _records.has(linked_id):
				return GopalaEntityOperationResult.REFERENCE_NOT_FOUND
			unique[linked_id] = true
	return GopalaEntityOperationResult.APPLIED

func _validate_incoming_rewrite(record: GopalaEntityRecord, next_links: Dictionary) -> bool:
	# Validate the whole proposed graph, allowing this record's old outgoing links to be replaced.
	var proposed: Dictionary = {}
	for entity_id in _records:
		var candidate: GopalaEntityRecord = _records[entity_id]
		proposed[entity_id] = next_links if candidate == record else candidate._links
	for entity_id in proposed:
		var links: Dictionary = proposed[entity_id]
		for relationship in links:
			var raw_ids: Variant = links[relationship]
			var ids: Array = raw_ids if raw_ids is Array else [raw_ids]
			var unique: Dictionary = {}
			for raw_id in ids:
				if typeof(raw_id) != TYPE_INT or int(raw_id) <= 0 or not _records.has(int(raw_id)):
					return false
				if unique.has(int(raw_id)):
					return false
				unique[int(raw_id)] = true
	return true

func _add_kind_id(kind: StringName, entity_id: int) -> void:
	if not _kind_ids.has(kind):
		_kind_ids[kind] = []
		_kind_ids[kind].append(entity_id)
	else:
		_kind_ids[kind].append(entity_id)
		_kind_ids[kind].sort()

func _remove_kind_id(kind: StringName, entity_id: int) -> void:
	if not _kind_ids.has(kind):
		return
	_kind_ids[kind].erase(entity_id)
	if _kind_ids[kind].is_empty():
		_kind_ids.erase(kind)

func _add_outgoing_references(record: GopalaEntityRecord) -> void:
	for relationship in record._links:
		var raw_ids: Variant = record._links[relationship]
		var ids: Array = raw_ids if raw_ids is Array else [raw_ids]
		for raw_id in ids:
			var target_id := int(raw_id)
			if not _incoming.has(target_id):
				_incoming[target_id] = {}
			var references: Dictionary = _incoming[target_id]
			var source_relationship := "%d|%s" % [record._entity_id, String(relationship)]
			references[source_relationship] = {"entity_id": record._entity_id,
				"relationship": String(relationship)}

func _remove_outgoing_references(record: GopalaEntityRecord) -> void:
	for relationship in record._links:
		var raw_ids: Variant = record._links[relationship]
		var ids: Array = raw_ids if raw_ids is Array else [raw_ids]
		for raw_id in ids:
			var target_id := int(raw_id)
			if not _incoming.has(target_id):
				continue
			var references: Dictionary = _incoming[target_id]
			references.erase("%d|%s" % [record._entity_id, String(relationship)])
			if references.is_empty():
				_incoming.erase(target_id)

func _incoming_blockers(entity_id: int) -> Array:
	var blockers: Array = []
	if not _incoming.has(entity_id):
		return blockers
	var references: Dictionary = _incoming[entity_id]
	for key in references:
		blockers.append(GopalaPlainData.copy_dictionary(references[key]))
	blockers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.entity_id) == int(b.entity_id):
			return String(a.relationship) < String(b.relationship)
		return int(a.entity_id) < int(b.entity_id))
	return blockers

func _remove_target_from_links(links: Dictionary, entity_id: int) -> Dictionary:
	var output := GopalaPlainData.copy_dictionary(links)
	for relationship in output.keys():
		var raw_ids: Variant = output[relationship]
		if raw_ids is Array:
			var retained: Array = []
			for raw_id in raw_ids:
				if int(raw_id) != entity_id:
					retained.append(raw_id)
			if retained.is_empty():
				output.erase(relationship)
			else:
				output[relationship] = retained
		elif int(raw_ids) == entity_id:
			output.erase(relationship)
	return output

func _was_removed_for_tests(entity_id: int) -> bool:
	return _removed_ids.has(entity_id)

func _incoming_for_tests(entity_id: int) -> Dictionary:
	return GopalaPlainData.copy_dictionary(_incoming.get(entity_id, {}))

func _kind_index_for_tests() -> Dictionary:
	return GopalaPlainData.copy_dictionary(_kind_ids)
