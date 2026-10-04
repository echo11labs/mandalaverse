class_name GopalaOccupancyState
extends RefCounted

const RESERVED: StringName = &"RESERVED"
const OCCUPIED: StringName = &"OCCUPIED"

static func is_valid(state: StringName) -> bool:
	return state == RESERVED or state == OCCUPIED
