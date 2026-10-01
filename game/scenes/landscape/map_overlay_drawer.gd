extends Node2D

var terrain
var regions: Array = []

const EXTENT := 200.0
const TEX_SIZE := 4096.0
const FIELD_RES := 64

var ownership: Array = []
var region_colors: Dictionary = {}
var label_points: Dictionary = {}

func _ready() -> void:
	build_region_cache()
	build_field()

func build_field() -> void:
	build_ownership_field()
	smooth_ownership(2)
	compute_label_points()
	queue_redraw()

func build_region_cache() -> void:
	region_colors.clear()
	for region in regions:
		region_colors[region.name] = Color(region.tint)

func world_to_map(x: float, z: float) -> Vector2:
	var u := (x + EXTENT) / (EXTENT * 2.0)
	var v := (z + EXTENT) / (EXTENT * 2.0)
	return Vector2(u * TEX_SIZE, v * TEX_SIZE)

func field_to_world(ix: int, iz: int) -> Vector2:
	var x := lerpf(-EXTENT, EXTENT, float(ix) / float(FIELD_RES - 1))
	var z := lerpf(-EXTENT, EXTENT, float(iz) / float(FIELD_RES - 1))
	return Vector2(x, z)

func build_ownership_field() -> void:
	ownership.clear()
	ownership.resize(FIELD_RES)
	for z in range(FIELD_RES):
		ownership[z] = []
		ownership[z].resize(FIELD_RES)
		for x in range(FIELD_RES):
			var p := field_to_world(x, z)
			ownership[z][x] = best_region_at(p.x, p.y)

func smooth_ownership(iterations: int = 2) -> void:
	for _i in range(iterations):
		var next: Array = []
		next.resize(FIELD_RES)
		for z in range(FIELD_RES):
			next[z] = []
			next[z].resize(FIELD_RES)
			for x in range(FIELD_RES):
				var counts: Dictionary = {}
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var nx := clampi(x + dx, 0, FIELD_RES - 1)
						var nz := clampi(z + dz, 0, FIELD_RES - 1)
						var n: String = ownership[nz][nx]
						counts[n] = int(counts.get(n, 0)) + 1
				var best_name: String = ownership[z][x]
				var best_count: int = -1
				for k in counts.keys():
					if counts[k] > best_count:
						best_name = k
						best_count = counts[k]
				next[z][x] = best_name
		ownership = next

func best_region_at(x: float, z: float) -> String:
	var best_name: String = ""
	var best_score: float = INF
	for region in regions:
		var score: float = region_score(region, x, z)
		if score < best_score:
			best_score = score
			best_name = region.name
	return best_name

func region_score(region: Dictionary, x: float, z: float) -> float:
	var center := Vector2(float(region.center.x), float(region.center.z))
	var p := Vector2(x, z)
	var distance_cost: float = p.distance_to(center)

	var elevation: float = terrain.elevation_at(x, z)
	var slope: float = 1.0 - terrain.normal_at(x, z, true).y

	var slope_cost: float = smoothstep(0.10, 0.34, slope) * 95.0
	var edge_cost: float = smoothstep(1500.0, 2100.0, elevation) * 40.0
	var river_cost: float = river_crossing_penalty(center, p)
	var ridge_cost: float = ridge_penalty(center, p)

	var score: float = distance_cost + slope_cost + edge_cost + river_cost + ridge_cost

	match String(region.get("bias", "")):
		"urban_core":
			score -= smoothstep(1350.0, 1500.0, elevation) * 15.0
		"southern_basin":
			if z > 10.0:
				score -= 10.0
		"eastern_basin":
			if x > 40.0:
				score -= 14.0
		"hill_fort":
			score -= smoothstep(1400.0, 1650.0, elevation) * 42.0
			score += smoothstep(0.0, 0.08, slope) * 12.0
	return score

func river_crossing_penalty(a: Vector2, b: Vector2) -> float:
	return 0.0

func ridge_penalty(a: Vector2, b: Vector2) -> float:
	var steps: int = 6
	var penalty: float = 0.0
	var prev_h: float = terrain.elevation_at(a.x, a.y)
	for i in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var p := a.lerp(b, t)
		var h: float = terrain.elevation_at(p.x, p.y)
		var dh: float = h - prev_h
		if dh > 18.0:
			penalty += dh * 0.35
		var slope: float = 1.0 - terrain.normal_at(p.x, p.y, true).y
		penalty += smoothstep(0.14, 0.42, slope) * 2.0
		prev_h = h
	return minf(penalty, 65.0)

func compute_label_points() -> void:
	label_points.clear()
	for region in regions:
		var samples: Array[Vector2] = []
		for z in range(FIELD_RES):
			for x in range(FIELD_RES):
				if ownership[z][x] == region.name:
					samples.append(field_to_world(x, z))
		if samples.is_empty():
			label_points[region.name] = Vector2(float(region.center.x), float(region.center.z))
			continue
		var centroid := Vector2.ZERO
		for p in samples:
			centroid += p
		centroid /= float(samples.size())
		label_points[region.name] = centroid

func get_label_anchor(region_name: String) -> Vector3:
	var p: Vector2 = label_points.get(region_name, Vector2.ZERO)
	return Vector3(p.x, terrain.height_at(p.x, p.y) + 2.5, p.y)

func _draw() -> void:
	if ownership.is_empty():
		return
	draw_region_wash()
	draw_boundaries()

func draw_region_wash() -> void:
	var cell: float = TEX_SIZE / float(FIELD_RES)
	for z in range(FIELD_RES - 1):
		for x in range(FIELD_RES - 1):
			var owner: String = ownership[z][x]
			var c: Color = region_colors.get(owner, Color.WHITE)
			c.a = 0.08
			var p := world_to_map(field_to_world(x, z).x, field_to_world(x, z).y)
			draw_rect(Rect2(p, Vector2(cell + 1.0, cell + 1.0)), c, true)

func draw_boundaries() -> void:
	for z in range(FIELD_RES - 1):
		for x in range(FIELD_RES - 1):
			var here: String = ownership[z][x]
			var east: String = ownership[z][x + 1]
			var south: String = ownership[z + 1][x]

			var p := field_to_world(x, z)
			var pe := field_to_world(x + 1, z)
			var ps := field_to_world(x, z + 1)

			if here != east:
				var ca: Color = region_colors.get(here, Color.WHITE)
				var cb: Color = region_colors.get(east, Color.WHITE)
				var line_color := ca.lerp(cb, 0.5)
				line_color.a = 0.82
				draw_dashed_line(world_to_map((p.x + pe.x) * 0.5, p.y), world_to_map((p.x + pe.x) * 0.5, ps.y), line_color, 2.2, 8.0)

			if here != south:
				var ca2: Color = region_colors.get(here, Color.WHITE)
				var cb2: Color = region_colors.get(south, Color.WHITE)
				var line_color2 := ca2.lerp(cb2, 0.5)
				line_color2.a = 0.82
				draw_dashed_line(world_to_map(p.x, (p.y + ps.y) * 0.5), world_to_map(pe.x, (p.y + ps.y) * 0.5), line_color2, 2.2, 8.0)
