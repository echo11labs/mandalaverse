class_name GopalaConstructionValidationResult
extends RefCounted

var valid: bool
var reason_code: StringName
var anchor_cell: Vector2i
var transformed_cells: Array[Vector2i]
var blocking_cells: Array[Vector2i]
var warnings: Array[String]

func _init(v: bool, r: StringName, a: Vector2i, t: Array[Vector2i], b: Array[Vector2i], w: Array[String] = []) -> void:
	valid = v
	reason_code = r
	anchor_cell = a
	transformed_cells = t
	blocking_cells = b
	warnings = w
