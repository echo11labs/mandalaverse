class_name GopalaOccupancyOperationResult
extends RefCounted

enum Status {
	APPLIED,
	UNCHANGED,
	REJECTED
}

const AVAILABLE = &"AVAILABLE"
const GRID_UNCONFIGURED = &"GRID_UNCONFIGURED"
const EMPTY_CELLS = &"EMPTY_CELLS"
const INVALID_CELLS = &"INVALID_CELLS"
const OUT_OF_BOUNDS = &"OUT_OF_BOUNDS"
const OCCUPIED = &"OCCUPIED"
const INVALID_OWNER = &"INVALID_OWNER"
const NOT_FOUND = &"NOT_FOUND"
const INVALID_STATE = &"INVALID_STATE"
const INVALID_TICK = &"INVALID_TICK"
const ALREADY_RESERVED = &"ALREADY_RESERVED"
const NOT_RESERVED = &"NOT_RESERVED"
const REENTRANT_MUTATION = &"REENTRANT_MUTATION"
const UNKNOWN_ERROR = &"UNKNOWN_ERROR"
const REPLACED = &"REPLACED"
const RELEASED = &"RELEASED"
const REMOVED = &"REMOVED"
const SESSION_RESET = &"SESSION_RESET"

var status: Status
var reason_code: StringName
var out_of_bounds_cells: Array[Vector2i]
var conflicting_cells: Array[Vector2i]
var conflicting_owner_ids: Array[int]
var normalized_cells: Array[Vector2i]
var valid: bool

func _init(p_status: Status, p_reason: StringName, p_valid: bool = false, p_oob: Array[Vector2i] = [], p_conf_cells: Array[Vector2i] = [], p_conf_owners: Array[int] = [], p_norm: Array[Vector2i] = []) -> void:
	status = p_status
	reason_code = p_reason
	valid = p_valid
	out_of_bounds_cells = p_oob.duplicate()
	conflicting_cells = p_conf_cells.duplicate()
	conflicting_owner_ids = p_conf_owners.duplicate()
	normalized_cells = p_norm.duplicate()

func to_plain_data() -> Dictionary:
	return GopalaPlainData.copy_dictionary({
		"status": status,
		"reason_code": reason_code,
		"valid": valid,
		"out_of_bounds_cells": out_of_bounds_cells.duplicate(),
		"conflicting_cells": conflicting_cells.duplicate(),
		"conflicting_owner_ids": conflicting_owner_ids.duplicate(),
		"normalized_cells": normalized_cells.duplicate()
	})
