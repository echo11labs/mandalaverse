class_name GopalaEntityLifecycle
extends RefCounted

enum State { ACTIVE, REMOVED }

static func is_valid(state: int) -> bool:
	return state == State.ACTIVE or state == State.REMOVED
