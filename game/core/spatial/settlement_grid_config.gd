class_name GopalaSettlementGridConfig
extends RefCounted

const SCHEMA_VERSION := 1
const BORDER_TIE_POLICY := "floor_to_negative_infinity"
const AXIS_CONVENTION := "+x_right_+y_up_maps_to_world_+x_right_+z_down"

var origin_xz: Vector2
var bounds: Rect2i
var meters_per_cell: float
var regional_meters_per_world_unit: float
var world_units_per_cell: float

func _init(p_origin_xz: Vector2, p_bounds: Rect2i, p_meters_per_cell: float, p_regional_meters: float) -> void:
	origin_xz = p_origin_xz
	bounds = p_bounds
	meters_per_cell = p_meters_per_cell
	regional_meters_per_world_unit = p_regional_meters
	
	if regional_meters_per_world_unit > 0.0:
		world_units_per_cell = meters_per_cell / regional_meters_per_world_unit
	else:
		world_units_per_cell = 0.0

func is_valid() -> bool:
	if not is_finite(origin_xz.x) or not is_finite(origin_xz.y):
		return false
	if meters_per_cell <= 0.0 or not is_finite(meters_per_cell):
		return false
	if regional_meters_per_world_unit <= 0.0 or not is_finite(regional_meters_per_world_unit):
		return false
	if not bounds.has_area():
		return false
	# Detect integer overflow risk for bounds
	if bounds.position.x < -1000000 or bounds.position.y < -1000000 or bounds.end.x > 1000000 or bounds.end.y > 1000000:
		return false
	return true

func snapshot() -> Dictionary:
	return GopalaPlainData.copy_dictionary({
		"schema_version": SCHEMA_VERSION,
		"origin_xz": [origin_xz.x, origin_xz.y],
		"bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"meters_per_cell": meters_per_cell,
		"regional_meters_per_world_unit": regional_meters_per_world_unit,
		"world_units_per_cell": world_units_per_cell,
		"axis_convention": AXIS_CONVENTION,
		"border_tie_policy": BORDER_TIE_POLICY
	})
