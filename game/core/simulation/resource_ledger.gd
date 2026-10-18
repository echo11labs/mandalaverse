class_name GopalaResourceLedger
extends RefCounted

var _balances: Dictionary[StringName, int] = {}
var _allowed_ids: Dictionary = {}

func _init(allowed_ids: Array[StringName] = GopalaSimulationConfig.RESOURCE_IDS) -> void:
	for resource_id in allowed_ids:
		if not resource_id.is_empty():
			_allowed_ids[resource_id] = true

func amount(resource_id: StringName) -> int:
	return int(_balances.get(resource_id, 0))

func balances_snapshot() -> Dictionary[StringName, int]:
	var copied: Dictionary[StringName, int] = {}
	for resource_id in _balances:
		copied[resource_id] = _balances[resource_id]
	return copied

func can_afford(costs: Variant) -> bool:
	if typeof(costs) != TYPE_DICTIONARY:
		return false
	return _can_afford_dictionary(costs)

func _can_afford_dictionary(costs: Dictionary) -> bool:
	if not _is_integer_delta(costs, true):
		return false
	for resource_id in costs:
		var cost: int = costs[resource_id]
		if cost < 0 or amount(resource_id) < cost:
			return false
	return true

func validate_transaction(delta: Variant) -> bool:
	if not _is_integer_delta(delta, false):
		return false
	for resource_id in delta:
		var current := amount(resource_id)
		var change: int = delta[resource_id]
		if change < 0 and current < -change:
			return false
		if change > 0 and current > GopalaSimulationConfig.MAX_BALANCE - change:
			return false
	return true

## Internal commit point; reached only through the simulation authority.
func apply_authorized_transaction(delta: Variant) -> bool:
	if typeof(delta) != TYPE_DICTIONARY:
		return false
	return _apply_authorized_dictionary(delta)

func _apply_authorized_dictionary(delta: Dictionary) -> bool:
	if not validate_transaction(delta):
		return false
	var next := balances_snapshot()
	for resource_id in delta:
		var next_balance: int = int(next.get(resource_id, 0)) + int(delta[resource_id])
		if next_balance == 0:
			next.erase(resource_id)
		else:
			next[resource_id] = next_balance
	_balances = next
	return true

func _seed_for_tests(delta: Dictionary) -> bool:
	return _apply_authorized_transaction(delta)

func _apply_authorized_transaction(delta: Dictionary) -> bool:
	return _apply_authorized_dictionary(delta)

func _is_integer_delta(value: Variant, allow_zero_costs: bool) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	for key in value:
		if typeof(key) != TYPE_STRING_NAME or StringName(key).is_empty() or not _allowed_ids.has(key):
			return false
		var amount_value: Variant = value[key]
		if typeof(amount_value) != TYPE_INT:
			return false
		if int(amount_value) < -GopalaSimulationConfig.MAX_BALANCE or int(amount_value) > GopalaSimulationConfig.MAX_BALANCE:
			return false
		if allow_zero_costs and int(amount_value) < 0:
			return false
	return true

func reset() -> void:
	_balances.clear()
