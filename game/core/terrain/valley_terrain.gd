@tool
class_name GopalaValleyTerrain
extends Resource
## Logical terrain is independent of screen positions, camera and sprite shading.

enum Kind { MEADOW, SCRUB, FOREST_FLOOR, EARTH, SHORE, WATER, ROCK, MARSH }
const NAMES := ["Meadow", "Scrub grass", "Woodland ground", "Dry earth", "Riverbank", "River", "Rocky ground", "Wet meadow"]
const PALETTE := [Color("91a275"), Color("7f9168"), Color("60765b"), Color("b3a080"), Color("c6b78f"), Color("5c969d"), Color("a5a796"), Color("829887")]
const VARIANTS := 4
const TILE_SIZE := Vector2i(128, 64)

@export var size: Vector2i = Vector2i(48, 48)
@export var seed_value: int = 260929
@export var camp_cell: Vector2i = Vector2i(13, 28)
@export var cells: PackedByteArray
@export var moisture: PackedByteArray

static func generate(seed_number: int = 260929) -> GopalaValleyTerrain:
	var map := GopalaValleyTerrain.new()
	map.seed_value = seed_number
	map.cells.resize(map.size.x * map.size.y)
	map.moisture.resize(map.cells.size())
	var noise := FastNoiseLite.new()
	noise.seed = seed_number
	noise.frequency = 0.075
	for y in range(map.size.y):
		var river_x := 27.0 + 3.2 * sin(float(y) * 0.14) + noise.get_noise_2d(80, y) * 1.7
		for x in range(map.size.x):
			var cell := Vector2i(x, y)
			var river_distance: float = abs(float(x) - river_x)
			var value: float = noise.get_noise_2d(x, y)
			var kind: int = Kind.MEADOW
			var north_grove: float = pow((x - 10.0) / 10.0, 2) + pow((y - 11.0) / 12.0, 2)
			var east_grove: float = pow((x - 40.0) / 8.0, 2) + pow((y - 22.0) / 17.0, 2)
			if north_grove < 1.0 + value * 0.7 or east_grove < 1.0 + value * 0.6:
				kind = Kind.FOREST_FLOOR
			elif value < -0.13:
				kind = Kind.SCRUB
			elif value > 0.25:
				kind = Kind.EARTH
			if (x < 8 and y < 7 and value > -0.05) or (x > 40 and y > 38 and value > -0.1):
				kind = Kind.ROCK
			if river_distance < 4.8:
				kind = Kind.MARSH if y > 30 and x < river_x else Kind.SHORE
			if river_distance < 2.0:
				kind = Kind.WATER
			# An authored, contiguous clearing supports the first settlement layout.
			if Rect2i(9, 24, 10, 10).has_point(cell):
				kind = Kind.MEADOW
			map.cells[map.index_of(cell)] = kind
			map.moisture[map.index_of(cell)] = clampi(int(88.0 - river_distance * 3.0), 18, 100)
	return map

func contains(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, size).has_point(cell)

func index_of(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x

func kind_at(cell: Vector2i) -> int:
	return cells[index_of(cell)] if contains(cell) else -1

func is_walkable(cell: Vector2i) -> bool:
	var kind := kind_at(cell)
	return kind >= 0 and kind != Kind.WATER and kind != Kind.ROCK

func is_buildable_ground(cell: Vector2i) -> bool:
	return kind_at(cell) in [Kind.MEADOW, Kind.SCRUB, Kind.EARTH]

func variant_at(cell: Vector2i) -> int:
	return posmod(cell.x * 31 + cell.y * 17 + seed_value, VARIANTS)

func validate() -> Array[String]:
	var errors: Array[String] = []
	if size.x < 1 or size.y < 1 or cells.size() != size.x * size.y or moisture.size() != cells.size():
		errors.append("Terrain arrays do not match the map dimensions.")
		return errors
	for kind in cells:
		if kind >= NAMES.size():
			errors.append("Unknown terrain kind.")
	for value in moisture:
		if value > 100:
			errors.append("Moisture exceeds its defined range.")
	if not is_buildable_ground(camp_cell):
		errors.append("The starting clearing is not on suitable ground.")
	return errors

