@tool
class_name GopalaSculptedValley
extends Resource
## Authoritative height field and ground rules for the orthographic 3D valley.

@export var seed_value: int = 260929
@export var extent: float = 180.0
@export var resolution: int = 192
@export var grid_size: int = 48
@export var clearing: Vector2 = Vector2(-28, 18)
var _noise: FastNoiseLite

func noise_at(x: float, z: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = seed_value
		_noise.frequency = 0.025
		_noise.fractal_octaves = 4
	return _noise.get_noise_2d(x, z)

func river_center(z: float) -> float:
	return 7.5 * sin(z * 0.044) + 5.0 * sin(z * 0.018 + 0.7) - 2.0

func river_width(z: float) -> float:
	return 4.2 + 0.85 * sin(z * 0.036 + 1.4)

func height_at(x: float, z: float) -> float:
	var distance: float = abs(x - river_center(z))
	var width := river_width(z)
	var floor_height: float = lerpf(-1.3, 1.15, smoothstep(width * 0.55, width + 3.8, distance))
	var hills := 33.0 * exp(-pow((x + 62.0) / 31.0, 2) - pow((z + 53.0) / 39.0, 2))
	hills += 23.0 * exp(-pow((x - 60.0) / 25.0, 2) - pow((z + 14.0) / 43.0, 2))
	hills += 21.0 * exp(-pow((x + 15.0) / 35.0, 2) - pow((z + 88.0) / 30.0, 2))
	hills += 15.0 * exp(-pow((x - 65.0) / 33.0, 2) - pow((z - 66.0) / 35.0, 2))
	var foothills: float = smoothstep(width + 5.0, width + 22.0, distance)
	var value: float = floor_height + foothills * (hills + noise_at(x, z) * (1.0 + hills * 0.15))
	var clearing_radius: float = Vector2((x - clearing.x) / 19.0, (z - clearing.y) / 23.0).length()
	return lerpf(1.75 + (z - clearing.y) * 0.012, value, smoothstep(0.8, 1.35, clearing_radius))

func normal_at(x: float, z: float) -> Vector3:
	var epsilon := 0.4
	return Vector3(height_at(x - epsilon, z) - height_at(x + epsilon, z), epsilon * 2.0, height_at(x, z - epsilon) - height_at(x, z + epsilon)).normalized()

func water_half_width(z: float) -> float:
	# The water edge follows the sculpted bank rather than a disconnected ribbon.
	var low := 0.0
	var high := river_width(z) + 5.0
	for i in range(14):
		var middle := (low + high) * 0.5
		if height_at(river_center(z) + middle, z) < 0.28:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5

func contains(cell: Vector2i) -> bool:
	return Rect2i(0, 0, grid_size, grid_size).has_point(cell)

func cell_at(position: Vector3) -> Vector2i:
	var side := extent / grid_size
	return Vector2i(floori((position.x + extent * 0.5) / side), floori((position.z + extent * 0.5) / side))

func cell_position(cell: Vector2i) -> Vector3:
	var side := extent / grid_size
	var x := -extent * 0.5 + (cell.x + 0.5) * side
	var z := -extent * 0.5 + (cell.y + 0.5) * side
	return Vector3(x, height_at(x, z), z)

func is_buildable(cell: Vector2i) -> bool:
	if not contains(cell):
		return false
	var center := cell_position(cell)
	var side := extent / grid_size
	for offset in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2.ZERO]:
		var x: float = center.x + offset.x * side
		var z: float = center.z + offset.y * side
		if height_at(x, z) < 0.9 or normal_at(x, z).y < cos(deg_to_rad(12)):
			return false
	return true

func surface_name(position: Vector3) -> String:
	if height_at(position.x, position.z) < 0.28:
		return "River water"
	if abs(position.x - river_center(position.z)) < river_width(position.z) + 5.0:
		return "Riverbank"
	if normal_at(position.x, position.z).y < 0.84:
		return "Rocky slope"
	return "Valley meadow" if height_at(position.x, position.z) < 7.0 else "Wooded foothill"

