@tool
class_name GopalaForestRules
extends ScatterBaseModifier
## Terrain placement only. Tree geometry and textures come from external packs.
@export var minimum_elevation_m := 1420.0
@export var maximum_slope_degrees := 38.0
@export var river_clearance_m := 50.0
@export var clearing_radius_m := 110.0
@export var patch_frequency := 0.28
@export var patch_threshold := -0.08
@export var density := 0.85
@export var detail_center := Vector2(10.0, -85.0)
@export var detail_half_extent := 12.0
@export var exclude_detail := false

var terrain: GopalaKathmanduTerrain

func _init() -> void:
	display_name = "Kathmandu Forest Habitat"
	category = "GOPALA"
	can_override_seed = true
	can_restrict_height = false
	documentation.add_paragraph("Dress externally authored trees onto the visible terrain. Exclude river bands, steep slopes and the planning clearing. Elevation and patch masks are an art treatment, not surveyed historic land cover.")

func accepts(x: float, z: float, patch_value: float, random_value: float) -> bool:
	if absf(x) >= terrain.EXTENT * 0.5 or absf(z) >= terrain.EXTENT * 0.5:
		return false
	if exclude_detail and absf(x - detail_center.x) < detail_half_extent and absf(z - detail_center.y) < detail_half_extent:
		return false
	if Vector2(x, z).distance_to(terrain.camp) * terrain.METRES_PER_UNIT < clearing_radius_m:
		return false
	if terrain.river_distance(x, z) < river_clearance_m:
		return false
	if terrain.normal_at(x, z, true).y < cos(deg_to_rad(maximum_slope_degrees)):
		return false
	if terrain.elevation_at(x, z) < minimum_elevation_m:
		return false
	return patch_value >= patch_threshold and random_value < density

func _process_transforms(transforms, _domain, random_seed: int) -> void:
	if terrain == null:
		terrain = GopalaKathmanduTerrain.new()
		terrain.load_data()
	var noise := FastNoiseLite.new()
	noise.seed = random_seed
	noise.frequency = patch_frequency
	noise.fractal_octaves = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed + 17
	var accepted: Array[Transform3D] = []
	for transform: Transform3D in transforms.list:
		var p := transform.origin
		if not accepts(p.x, p.z, noise.get_noise_2d(p.x, p.z), rng.randf()):
			continue
		transform.origin.y = terrain.height_at(p.x, p.z)
		accepted.append(transform)
	transforms.list = accepted
