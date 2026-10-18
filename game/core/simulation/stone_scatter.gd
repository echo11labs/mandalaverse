class_name GopalaStoneScatter
extends RefCounted

## Logical deposits, independent of rendering and decorative stone density.
## Terrain predicate rejects water/cliffs; bounded attempts allow sparse maps.
static func generate(camp: Vector2, seed_value: int, valid_ground: Callable, count: int = 24, profile: Dictionary = {}) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + int(profile.get("seed_offset", 11927))
	var deposits: Array[Dictionary] = []
	for attempt in range(maxi(0, count) * 40):
		if deposits.size() >= count:
			break
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(float(profile.get("radius_min_metres", 1000.0)) / GopalaScaleStandard.number("units", "regional_meters_per_world_unit"), float(profile.get("radius_max_metres", 4000.0)) / GopalaScaleStandard.number("units", "regional_meters_per_world_unit"))
		var pos := camp + Vector2(cos(angle), sin(angle)) * radius
		if not valid_ground.call(pos):
			continue
		var overlaps := false
		for deposit in deposits:
			if pos.distance_to(deposit.position) < float(profile.get("spacing_metres", 500.0)) / GopalaScaleStandard.number("units", "regional_meters_per_world_unit"):
				overlaps = true
				break
		if overlaps:
			continue
		deposits.append({"position": pos, "amount": rng.randi_range(int(profile.get("amount_min", 15)), int(profile.get("amount_max", 45)))})
	return deposits

## Displayed banks can be wider than the sampled geographic distance field.
static func river_segments(terrain: GopalaKathmanduTerrain) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var river_script = preload("res://core/landscape/terrain_river.gd")
	for reach in terrain.metadata.rivers:
		if river_script.is_hidden_tag(reach.get("covered", false)) or river_script.is_hidden_tag(reach.get("tunnel", false)):
			continue
		var width: float = river_script.half_width(reach) + GopalaScaleStandard.metres_to_world(1.0)
		for i in range(reach.points.size() - 1):
			var a := Vector2(reach.points[i][0], reach.points[i][2])
			var b := Vector2(reach.points[i + 1][0], reach.points[i + 1][2])
			segments.append({"a": a, "b": b, "width": width, "bounds": Rect2(a, Vector2.ZERO).expand(b).grow(width)})
	return segments

static func outside_displayed_water(position: Vector2, segments: Array[Dictionary]) -> bool:
	for segment in segments:
		if not segment.bounds.has_point(position):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(position, segment.a, segment.b)
		if position.distance_to(closest) <= float(segment.width):
			return false
	return true
