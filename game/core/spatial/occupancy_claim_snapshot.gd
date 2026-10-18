class_name GopalaOccupancyClaimSnapshot
extends RefCounted

var owner_entity_id: int
var state: StringName
var cells: Array[Vector2i]
var revision: int
var created_tick: int
var updated_tick: int

func _init(p_owner: int, p_state: StringName, p_cells: Array[Vector2i], p_rev: int, p_created: int, p_updated: int) -> void:
	owner_entity_id = p_owner
	state = p_state
	cells = p_cells.duplicate()
	revision = p_rev
	created_tick = p_created
	updated_tick = p_updated

func to_plain_data() -> Dictionary:
	var plain_cells: Array = []
	for cell in cells:
		plain_cells.append([cell.x, cell.y])
	return {
		"owner_entity_id": owner_entity_id,
		"state": state,
		"cells": plain_cells,
		"revision": revision,
		"created_tick": created_tick,
		"updated_tick": updated_tick
	}
