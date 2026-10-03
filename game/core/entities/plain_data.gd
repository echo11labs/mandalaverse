class_name GopalaPlainData
extends RefCounted

const MAX_NESTING_DEPTH: int = 32

## Accepted data: null, bool, int, finite float, String, StringName, Array, and
## Dictionary with String/StringName/int keys. Runtime Objects, RIDs, Signals,
## Callables, unsupported variants, cycles, and nesting beyond max_depth reject.
static func validate(value: Variant, max_depth: int = MAX_NESTING_DEPTH) -> bool:
	if max_depth < 0:
		return false
	var ancestors: Array[Variant] = []
	return _validate(value, 0, max_depth, ancestors)

static func _validate(value: Variant, depth: int, max_depth: int,
		ancestors: Array[Variant]) -> bool:
	if depth > max_depth:
		return false
	if value == null or typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME]:
		return true
	if typeof(value) in [TYPE_OBJECT, TYPE_RID, TYPE_SIGNAL, TYPE_CALLABLE]:
		return false
	if typeof(value) == TYPE_FLOAT:
		return is_finite(float(value))
	if value is Array or value is Dictionary:
		for ancestor in ancestors:
			if is_same(value, ancestor):
				return false
		ancestors.append(value)
		if value is Array:
			for item in value:
				if not _validate(item, depth + 1, max_depth, ancestors):
					ancestors.pop_back()
					return false
		else:
			for key in value:
				if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT]:
					ancestors.pop_back()
					return false
				if not _validate(value[key], depth + 1, max_depth, ancestors):
					ancestors.pop_back()
					return false
		ancestors.pop_back()
		return true
	return false

static func copy_dictionary(value: Dictionary) -> Dictionary:
	return copy_value(value) as Dictionary

static func copy_value(value: Variant) -> Variant:
	if value is Dictionary:
		var copied: Dictionary = {}
		for key in value:
			copied[key] = copy_value(value[key])
		return copied
	if value is Array:
		var copied: Array = []
		for item in value:
			copied.append(copy_value(item))
		return copied
	return value
