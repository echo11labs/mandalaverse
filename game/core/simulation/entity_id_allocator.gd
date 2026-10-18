class_name GopalaEntityIdAllocator
extends RefCounted

var _next_id: int = 1

func allocate() -> int:
	if _next_id <= 0 or _next_id > GopalaSimulationConfig.MAX_SEQUENCE:
		return 0
	var allocated := _next_id
	_next_id += 1
	return allocated

## Reset explicitly begins a new simulation session; IDs may start at one again.
func reset_new_session() -> void:
	_next_id = 1

func _next_for_tests() -> int:
	return _next_id
