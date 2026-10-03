class_name GopalaCommandQueue
extends RefCounted

var _pending: Array[GopalaSimulationCommand] = []
var _next_command_id: int = 1

func submit(command_type: StringName, submitted_tick: int, payload: Dictionary = {}, source_id: StringName = &"") -> int:
	if submitted_tick < 0 or not GopalaSimulationCommand.validate_plain_data(payload):
		return 0
	if _next_command_id <= 0 or _next_command_id > GopalaSimulationConfig.MAX_SEQUENCE:
		return 0
	var command := GopalaSimulationCommand._from_queue(_next_command_id, command_type, submitted_tick, payload, source_id)
	if not is_instance_valid(command):
		return 0
	_pending.append(command)
	_next_command_id += 1
	return command.command_id

func has_pending() -> bool:
	return not _pending.is_empty()

func pending_count() -> int:
	return _pending.size()

func pop_front() -> GopalaSimulationCommand:
	if _pending.is_empty():
		return null
	return _pending.pop_front()

func reset() -> void:
	_pending.clear()
	# IDs stay monotonic during this session; the owning simulation explicitly
	# starts a new session and resets them when reset() is requested.

func reset_new_session() -> void:
	reset()
	_next_command_id = 1

func last_issued_id() -> int:
	return _next_command_id - 1
