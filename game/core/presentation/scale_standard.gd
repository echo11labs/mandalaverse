class_name GopalaScaleStandard
extends RefCounted

const PATH := "res://data/standards/world_scale.json"
static var _settings: Dictionary = {}

static func settings() -> Dictionary:
	if _settings.is_empty():
		_settings = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _settings.duplicate(true)

static func number(profile: String, key: String) -> float:
	if _settings.is_empty():
		settings()
	var value := float(_settings[profile][key])
	if profile == "units" or key == "piece_count":
		return value
	return metres_to_world(value)

static func metres_to_world(metres: float) -> float:
	return metres / number("units", "regional_meters_per_world_unit")

static func normalize_height(model: Node3D, height: float) -> void:
	var bounds := bounds_in_parent(model)
	if bounds.size.y <= 0.0:
		return
	model.scale *= height / bounds.size.y
	bounds = bounds_in_parent(model)
	model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)

static func carry_size(profile: String) -> Vector3:
	return Vector3(number(profile, "width"), number(profile, "height"), number(profile, "depth"))

## Includes every imported child transform, including root scale and mesh pivots.
## Results are in the model parent's space, ready for ground anchoring.
static func bounds_in_parent(model: Node3D) -> AABB:
	var result := {"found": false, "bounds": AABB()}
	_collect_bounds(model, Transform3D.IDENTITY, result)
	return result.bounds

static func _collect_bounds(node: Node, parent_transform: Transform3D, result: Dictionary) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var box: AABB = transform * (node as MeshInstance3D).mesh.get_aabb()
		result.bounds = result.bounds.merge(box) if result.found else box
		result.found = true
	for child in node.get_children():
		_collect_bounds(child, transform, result)

static func horizontal_width(bounds: AABB) -> float:
	return maxf(bounds.size.x, bounds.size.z)

static func factor_for_width(bounds: AABB, width: float) -> float:
	var source_width := horizontal_width(bounds)
	if source_width <= 0.0 or not is_finite(width) or width <= 0.0:
		return 0.0
	return width / source_width

## Apply yaw before normalization so the final measured footprint meets the target.
## Replacing a mesh with different export units automatically recomputes its factor.
static func normalize_stone(model: Node3D, width: float) -> void:
	var bounds := bounds_in_parent(model)
	var factor := factor_for_width(bounds, width)
	if bounds.size.y > 0.0:
		factor = minf(factor, number("stone_piece", "height_max") / bounds.size.y)
	model.scale *= factor
	bounds = bounds_in_parent(model)
	model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)

static func within_profile(bounds: AABB, profile: String) -> bool:
	return horizontal_width(bounds) <= number(profile, "width_max") + 0.0001 \
		and bounds.size.y <= number(profile, "height_max") + 0.0001
