class_name GopalaMapOverlay
extends Node2D
## Paints the Gopal-era tributary chiefdoms of the Kathmandu Valley onto the terrain.
##
## These are not Voronoi rings. regions_gopala.json authors the valley's natural
## frontier lines as ordered chains of named landmarks. Each landmark is snapped to
## the real thing in the DEM (a named mapped watercourse, or a ridge crest walked out
## from the anchor), the snapped chains are rasterised into a barrier field, and each
## chiefdom then claims ground by multi-source least-cost flood fill from its seat.
## Watercourses and ridgelines therefore end up as the jurisdiction lines themselves.

enum Mode { OFF, WASH, SURVEY }

const REGIONS_PATH := "res://data/geography/regions_gopala.json"
const EXTENT := 200.0
const TEX_SIZE := 4096.0
const FIELD_RES := 256
const CELL := (EXTENT * 2.0) / float(FIELD_RES - 1)
const COST_RES := 128

# Matches the lon/lat to world-unit conversion in kathmandu_valley.gd load_lakes().
const M_PER_DEG_LON := 98565.0
const M_PER_DEG_LAT := 111320.0
const METRES_PER_UNIT := 100.0

const BARRIER_WEIGHT := 240.0
const FRONTIER_SCALE := 1.0
const RIM_STRENGTH := 5.0
const RIM_WALL_CELLS := 1.2
const RIDGE_STRENGTH := 0.66
const PASS_STRENGTH := 0.5
const RIVER_STRENGTH := 1.0
const BARRIER_CELLS := 2.0
const SEED_CLEAR_CELLS := 3.0
const MAX_SNAP := 10.0
const CHAIN_WINDOW := 26.0
const RIDGE_STEPS := 7
const RIDGE_PULLBACK := 0.24

# Contour smoothing. The ownership lattice is 256 cells across, so a boundary walked
# straight off it is a 16 map-pixel staircase and reads as pixelated ink. The drawn
# line is decoupled from that lattice: the region mask is blurred, upsampled, contoured
# at the 0.5 crossing, resampled to even spacing and corner-cut with Chaikin. The
# ownership partition itself is never smoothed, so cell counts and seat assignment
# stay exact while the survey line reads as a drawn curve.
const CONTOUR_RES := 512
const CONTOUR_ISO := 0.5
const CONTOUR_BLUR := 1.7
const CONTOUR_SPACING := 8.0
const CHAIKIN_ITERATIONS := 3
const CHAIKIN_RATIO := 0.25

## World-unit edge of a proximity bucket, 2 km across. Only used to index rivers.
const RIVER_BUCKET := 20.0

const MODE_FILL_ALPHA := [0.0, 0.22, 0.62]
const MODE_EDGE_ALPHA := [0.0, 0.40, 0.96]
const MODE_NAME := ["Off", "Wash", "Survey"]

const DIAGONAL := 1.41421356

class FieldHeap extends RefCounted:
	## Binary min-heap over field cell indices keyed by least-cost distance.
	var items := PackedInt32Array()
	var keys := PackedFloat32Array()

	func is_empty() -> bool:
		return items.is_empty()

	func push(item: int, key: float) -> void:
		items.append(item)
		keys.append(key)
		var i := items.size() - 1
		while i > 0:
			var parent := (i - 1) >> 1
			if keys[parent] <= keys[i]:
				break
			_swap(i, parent)
			i = parent

	func pop() -> int:
		var top := items[0]
		var last := items.size() - 1
		_swap(0, last)
		items.resize(last)
		keys.resize(last)
		var i := 0
		while true:
			var left := 2 * i + 1
			var right := 2 * i + 2
			var smallest := i
			if left < items.size() and keys[left] < keys[smallest]:
				smallest = left
			if right < items.size() and keys[right] < keys[smallest]:
				smallest = right
			if smallest == i:
				break
			_swap(i, smallest)
			i = smallest
		return top

	func _swap(a: int, b: int) -> void:
		var ti := items[a]
		items[a] = items[b]
		items[b] = ti
		var tk := keys[a]
		keys[a] = keys[b]
		keys[b] = tk

var terrain: GopalaKathmanduTerrain
var document: Dictionary = {}
var regions: Array = []
var chains: Dictionary = {}
var frontiers: Array = []
var rim: Dictionary = {}

var target_viewport: SubViewport
var mode: int = Mode.OFF
var built := false

var ownership := PackedInt32Array()
var barrier := PackedFloat32Array()
var wall := PackedByteArray()
var distance := PackedFloat32Array()
var settled := PackedByteArray()
var terrain_cost := PackedFloat32Array()

var region_colors: Dictionary = {}
var region_by_id: Dictionary = {}
var label_points: Dictionary = {}
var river_cache: Dictionary = {}
var river_bounds: Dictionary = {}
var river_grid: Dictionary = {}
var contours: Array = []
var snapped_chains: Dictionary = {}
var snapped_frontiers: Array = []
var snapped_rim := PackedVector2Array()
var last_report: Dictionary = {}

func _ready() -> void:
	build()

# ---------------------------------------------------------------- build pipeline

func build() -> void:
	if terrain == null or regions.is_empty():
		return
	build_region_cache()
	build_river_cache()
	resolve_chains()
	rasterise_barriers()
	compute_terrain_cost()
	grow_territories()
	build_contours()
	compute_label_points()
	last_report = summarise()
	built = true
	queue_redraw()

func build_region_cache() -> void:
	region_colors.clear()
	region_by_id.clear()
	chains.clear()
	for i in range(regions.size()):
		var region: Dictionary = regions[i]
		var id := String(region.get("id", "region_%d" % i))
		region_by_id[id] = region
		region_colors[i] = Color(String(region.get("tint", "#ffffff")))
	for chain in document.get("chains", []):
		chains[String(chain.id)] = chain

func build_river_cache() -> void:
	river_cache.clear()
	river_bounds.clear()
	river_grid.clear()
	for reach in terrain.metadata.get("rivers", []):
		var points := PackedVector2Array()
		for p in reach.get("points", []):
			points.append(Vector2(float(p[0]), float(p[2])))
		if points.size() < 2:
			continue
		if river_cache.has(reach.name):
			river_cache[reach.name].append_array(points)
		else:
			river_cache[reach.name] = points
	for name in river_cache.keys():
		river_bounds[name] = _bounds_of(river_cache[name])
		river_grid[name] = _index_course(river_cache[name])

## Bucket the course into a coarse grid so a proximity query only tests the segments
## that can actually be within reach, instead of walking every mapped vertex.
func _index_course(course: PackedVector2Array) -> Dictionary:
	var cells := {}
	for i in range(course.size() - 1):
		var a := course[i]
		var b := course[i + 1]
		var low_x := int(floorf(minf(a.x, b.x) / RIVER_BUCKET))
		var high_x := int(floorf(maxf(a.x, b.x) / RIVER_BUCKET))
		var low_y := int(floorf(minf(a.y, b.y) / RIVER_BUCKET))
		var high_y := int(floorf(maxf(a.y, b.y) / RIVER_BUCKET))
		for cy in range(low_y, high_y + 1):
			for cx in range(low_x, high_x + 1):
				var key := _cell_key(cx, cy)
				if not cells.has(key):
					cells[key] = []
				cells[key].append(i)
	return cells

func _cell_key(cx: int, cy: int) -> int:
	return (cx + 4096) * 16384 + (cy + 4096)

func _bounds_of(course: PackedVector2Array) -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point in course:
		low.x = minf(low.x, point.x)
		low.y = minf(low.y, point.y)
		high.x = maxf(high.x, point.x)
		high.y = maxf(high.y, point.y)
	if low.x > high.x:
		return Rect2()
	return Rect2(low, high - low)

# ---------------------------------------------------------------- coordinates

func lonlat_to_world(lon: float, lat: float) -> Vector2:
	var origin: Array = terrain.metadata.get("source_center_lonlat", [85.375, 27.695])
	return Vector2(
		(lon - float(origin[0])) * M_PER_DEG_LON / METRES_PER_UNIT,
		(float(origin[1]) - lat) * M_PER_DEG_LAT / METRES_PER_UNIT)

func world_to_map(x: float, z: float) -> Vector2:
	return Vector2(
		(x + EXTENT) / (EXTENT * 2.0) * TEX_SIZE,
		(z + EXTENT) / (EXTENT * 2.0) * TEX_SIZE)

func world_to_map_point(p: Vector2) -> Vector2:
	return world_to_map(p.x, p.y)

func field_index(ix: int, iz: int) -> int:
	return iz * FIELD_RES + ix

func cell_center(ix: int, iz: int) -> Vector2:
	return Vector2(-EXTENT + float(ix) * CELL, -EXTENT + float(iz) * CELL)

func field_cell(p: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(round((p.x + EXTENT) / CELL)), 0, FIELD_RES - 1),
		clampi(int(round((p.y + EXTENT) / CELL)), 0, FIELD_RES - 1))

func seat_world(region: Dictionary) -> Vector2:
	var seat: Dictionary = region.get("seat", {})
	return lonlat_to_world(float(seat.get("lon", 85.375)), float(seat.get("lat", 27.695)))

# ---------------------------------------------------------------- snapping

func resolve_chains() -> void:
	snapped_chains.clear()
	for id in chains.keys():
		var chain: Dictionary = chains[id]
		var points := PackedVector2Array()
		var names := PackedStringArray()
		var moved := 0
		var previous := Vector2.ZERO
		for anchor in chain.get("anchors", []):
			var authored := anchor_world(anchor)
			var snapped := snap_anchor(anchor, authored, previous)
			if snapped.distance_to(authored) > 0.01:
				moved += 1
			points.append(snapped)
			names.append(String(anchor.get("name", "")))
			previous = snapped
		snapped_chains[id] = {"points": points, "names": names, "moved": moved, "chain": chain}
	resolve_rim()

func resolve_rim() -> void:
	snapped_rim = PackedVector2Array()
	if rim.is_empty():
		return
	var previous := Vector2.ZERO
	var first := true
	for anchor in rim.get("anchors", []):
		var authored := anchor_world(anchor)
		var snapped := snap_anchor(anchor, authored, previous if not first else authored)
		snapped_rim.append(snapped)
		previous = snapped
		first = false
	if bool(rim.get("closed", false)) and snapped_rim.size() > 2:
		snapped_rim.append(snapped_rim[0])

func anchor_world(anchor: Dictionary) -> Vector2:
	if anchor.has("lon"):
		return lonlat_to_world(float(anchor.lon), float(anchor.lat))
	return Vector2(float(anchor.get("x", 0.0)), float(anchor.get("z", 0.0)))

func snap_anchor(anchor: Dictionary, authored: Vector2, previous: Vector2) -> Vector2:
	match String(anchor.get("basis", "pass")):
		"river":
			return snap_to_river(String(anchor.get("river", "")), authored, previous)
		"ridge":
			return snap_to_ridge(authored)
		_:
			return authored

## Pulls an anchor onto the named watercourse. Candidates are also restricted to a
## window around the previous anchor in the same chain, so a chain cannot jump onto
## a different reach of the same river where two reaches run close together.
func snap_to_river(river_name: String, p: Vector2, previous: Vector2) -> Vector2:
	var courses: PackedVector2Array = river_cache.get(river_name, PackedVector2Array())
	if courses.is_empty():
		return p
	var best := p
	var best_d := MAX_SNAP
	for i in range(courses.size() - 1):
		var closest := closest_point_on_segment(p, courses[i], courses[i + 1])
		if closest.distance_to(previous) > CHAIN_WINDOW:
			continue
		var d := closest.distance_to(p)
		if d < best_d:
			best_d = d
			best = closest
	return best

func snap_to_ridge(p: Vector2) -> Vector2:
	var step := CELL * 0.9
	var cursor := p
	for _i in range(RIDGE_STEPS):
		var best := cursor
		var best_h := terrain.elevation_at(cursor.x, cursor.y)
		var gradient := Vector2(
			terrain.elevation_at(cursor.x + step, cursor.y) - terrain.elevation_at(cursor.x - step, cursor.y),
			terrain.elevation_at(cursor.x, cursor.y + step) - terrain.elevation_at(cursor.x, cursor.y - step))
		var tangent := Vector2(-gradient.y, gradient.x)
		if tangent.length_squared() < 0.000001:
			tangent = Vector2(step, 0.0)
		else:
			tangent = tangent.normalized() * step
		for side in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var candidate: Vector2 = cursor + tangent * side
			var h := terrain.elevation_at(candidate.x, candidate.y)
			if h > best_h:
				best_h = h
				best = candidate
		cursor = best.lerp(p, RIDGE_PULLBACK)
	return cursor

func closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var delta := b - a
	if delta.length_squared() < 0.0000001:
		return a
	return a + delta * clampf((p - a).dot(delta) / delta.length_squared(), 0.0, 1.0)

# ---------------------------------------------------------------- barriers

func rasterise_barriers() -> void:
	barrier.resize(FIELD_RES * FIELD_RES)
	barrier.fill(0.0)
	snapped_frontiers.clear()
	for frontier in frontiers:
		var polyline := PackedVector2Array()
		var strengths := PackedFloat32Array()
		for segment in frontier.get("segments", []):
			var resolved: Dictionary = snapped_chains.get(String(segment.get("chain", "")), {})
			var points: PackedVector2Array = resolved.get("points", PackedVector2Array())
			var first := clampi(int(segment.get("from", 0)), 0, maxi(points.size() - 1, 0))
			var last := clampi(int(segment.get("to", 0)), first, maxi(points.size() - 1, 0))
			for i in range(first, last + 1):
				if polyline.size() > 0 and polyline[polyline.size() - 1].distance_to(points[i]) < 0.0001:
					continue
				polyline.append(points[i])
				strengths.append(anchor_strength(_chain_anchor_at(String(segment.get("chain", "")), i)))
			rasterise_polyline(polyline, strengths, FRONTIER_SCALE)
			polyline = PackedVector2Array()
			strengths = PackedFloat32Array()
		snapped_frontiers.append({"frontier": frontier, "points": _frontier_points(frontier)})
	rasterise_polyline(snapped_rim, _rim_strengths(), RIM_STRENGTH)
	rasterise_rim_wall()
	clear_seeds()

## The basin rim is stamped into an impassable mask with its own radius. A rim
## that is only a high cost does not seal anything: least-cost fill always reaches
## every cell, so the territories would spill across the hills and claim the whole
## 40 km survey area. Only the rim is a wall; frontiers stay crossable, so two
## chiefdoms still meet on their shared frontier instead of leaving a gap.
func rasterise_rim_wall() -> void:
	wall.resize(FIELD_RES * FIELD_RES)
	wall.fill(0)
	var radius := int(ceil(RIM_WALL_CELLS))
	var reach := float(radius) * CELL
	for i in range(snapped_rim.size() - 1):
		var a := snapped_rim[i]
		var b := snapped_rim[i + 1]
		var steps := maxi(1, int(ceil(a.distance_to(b) / (CELL * 0.5))))
		for s in range(steps + 1):
			var centre := field_cell(a.lerp(b, float(s) / float(steps)))
			for dz in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					var ix := centre.x + dx
					var iz := centre.y + dz
					if ix < 0 or iz < 0 or ix >= FIELD_RES or iz >= FIELD_RES:
						continue
					if float(dx * dx + dz * dz) * CELL <= reach:
						wall[field_index(ix, iz)] = 1

func _frontier_points(frontier: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for segment in frontier.get("segments", []):
		var resolved: Dictionary = snapped_chains.get(String(segment.get("chain", "")), {})
		var points: PackedVector2Array = resolved.get("points", PackedVector2Array())
		var first := clampi(int(segment.get("from", 0)), 0, maxi(points.size() - 1, 0))
		var last := clampi(int(segment.get("to", 0)), first, maxi(points.size() - 1, 0))
		for i in range(first, last + 1):
			if out.size() > 0 and out[out.size() - 1].distance_to(points[i]) < 0.0001:
				continue
			out.append(points[i])
	return out

func _chain_anchor_at(chain_id: String, index: int) -> Dictionary:
	var chain: Dictionary = chains.get(chain_id, {})
	var anchors: Array = chain.get("anchors", [])
	if index < 0 or index >= anchors.size():
		return {}
	return anchors[index]

func _rim_strengths() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for anchor in rim.get("anchors", []):
		out.append(anchor_strength(anchor))
	return out

func anchor_strength(anchor: Dictionary) -> float:
	match String(anchor.get("basis", "pass")):
		"river":
			return RIVER_STRENGTH
		"ridge":
			return RIDGE_STRENGTH
		_:
			return PASS_STRENGTH

func rasterise_polyline(points: PackedVector2Array, strengths: PackedFloat32Array, weight: float) -> void:
	for i in range(points.size() - 1):
		var s0: float = strengths[i] if i < strengths.size() else 1.0
		var s1: float = strengths[i + 1] if i + 1 < strengths.size() else s0
		stamp_segment(points[i], points[i + 1], weight * (s0 + s1) * 0.5)

func stamp_segment(a: Vector2, b: Vector2, weight: float) -> void:
	if weight <= 0.0:
		return
	var span := a.distance_to(b)
	var steps := maxi(1, int(ceil(span / (CELL * 0.5))))
	for s in range(steps + 1):
		stamp_barrier(a.lerp(b, float(s) / float(steps)), weight)

func stamp_barrier(p: Vector2, weight: float) -> void:
	var centre := field_cell(p)
	var radius := int(ceil(BARRIER_CELLS))
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var ix := centre.x + dx
			var iz := centre.y + dz
			if ix < 0 or iz < 0 or ix >= FIELD_RES or iz >= FIELD_RES:
				continue
			var offset := sqrt(float(dx * dx + dz * dz)) * CELL
			var falloff := clampf(1.0 - offset / (BARRIER_CELLS * CELL), 0.0, 1.0)
			var index := field_index(ix, iz)
			barrier[index] = maxf(barrier[index], weight * falloff)

func clear_seeds() -> void:
	var radius := int(ceil(SEED_CLEAR_CELLS))
	for region in regions:
		var centre := field_cell(seat_world(region))
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var ix := centre.x + dx
				var iz := centre.y + dz
				if ix < 0 or iz < 0 or ix >= FIELD_RES or iz >= FIELD_RES:
					continue
				barrier[field_index(ix, iz)] = 0.0

# ---------------------------------------------------------------- least-cost fill

func compute_terrain_cost() -> void:
	terrain_cost.resize(COST_RES * COST_RES)
	var step := (EXTENT * 2.0) / float(COST_RES - 1)
	for iz in range(COST_RES):
		for ix in range(COST_RES):
			var p := Vector2(-EXTENT + float(ix) * step, -EXTENT + float(iz) * step)
			var elevation := terrain.elevation_at(p.x, p.y)
			var slope := 1.0 - terrain.normal_at(p.x, p.y, true).y
			terrain_cost[iz * COST_RES + ix] = \
				1.0 + 9.0 * smoothstep(0.08, 0.55, slope) + 6.0 * smoothstep(1320.0, 1850.0, elevation)

func cost_at(ix: int, iz: int) -> float:
	var fx := clampf(float(ix) / float(FIELD_RES - 1) * float(COST_RES - 1), 0.0, float(COST_RES - 1))
	var fz := clampf(float(iz) / float(FIELD_RES - 1) * float(COST_RES - 1), 0.0, float(COST_RES - 1))
	var cx := clampi(floori(fx), 0, COST_RES - 2)
	var cz := clampi(floori(fz), 0, COST_RES - 2)
	var tx := fx - float(cx)
	var tz := fz - float(cz)
	var a := terrain_cost[cz * COST_RES + cx]
	var b := terrain_cost[cz * COST_RES + cx + 1]
	var c := terrain_cost[(cz + 1) * COST_RES + cx]
	var d := terrain_cost[(cz + 1) * COST_RES + cx + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)

func grow_territories() -> void:
	var count := FIELD_RES * FIELD_RES
	ownership.resize(count)
	ownership.fill(-1)
	distance.resize(count)
	distance.fill(INF)
	settled.resize(count)
	settled.fill(0)

	var heap := FieldHeap.new()
	for i in range(regions.size()):
		var seed := field_cell(seat_world(regions[i]))
		var index := field_index(seed.x, seed.y)
		ownership[index] = i
		distance[index] = 0.0
		heap.push(index, 0.0)

	while not heap.is_empty():
		var index := heap.pop()
		if settled[index] == 1:
			continue
		settled[index] = 1
		var owner_id: int = ownership[index]
		var ox := index % FIELD_RES
		var oz := index / FIELD_RES
		var base := distance[index]
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nx := ox + dx
				var nz := oz + dz
				if nx < 0 or nz < 0 or nx >= FIELD_RES or nz >= FIELD_RES:
					continue
				var neighbour := field_index(nx, nz)
				if settled[neighbour] == 1 or wall[neighbour] == 1:
					continue
				var span := CELL * (DIAGONAL if dx != 0 and dz != 0 else 1.0)
				var candidate := base + span * cost_at(nx, nz) + BARRIER_WEIGHT * barrier[neighbour]
				if candidate < distance[neighbour] - 0.000001:
					distance[neighbour] = candidate
					ownership[neighbour] = owner_id
					heap.push(neighbour, candidate)

# ---------------------------------------------------------------- contours

func build_contours() -> void:
	contours.clear()
	var step := (EXTENT * 2.0) / float(CONTOUR_RES - 1)
	for i in range(regions.size()):
		var field := soft_region_field(i)
		var loops := stitch(contour_segments(field, CONTOUR_RES, step, CONTOUR_ISO))
		contours.append(smooth_loops(loops))

## Blurred, bilinearly upsampled ownership mask for one region, ready to contour.
## Blurring the lattice turns each 90-degree cell corner into a rounded ramp, and the
## finer grid lets the crossing be placed anywhere inside that ramp rather than only on
## cell boundaries. Nothing here is written back to the ownership array.
func soft_region_field(region_index: int) -> PackedFloat32Array:
	var mask := PackedFloat32Array()
	mask.resize(FIELD_RES * FIELD_RES)
	for index in range(mask.size()):
		mask[index] = 1.0 if ownership[index] == region_index else 0.0
	mask = blur_field(mask, FIELD_RES, CONTOUR_BLUR)
	var step := (EXTENT * 2.0) / float(FIELD_RES - 1)
	var fine := PackedFloat32Array()
	fine.resize(CONTOUR_RES * CONTOUR_RES)
	var ratio := float(CONTOUR_RES - 1) / float(FIELD_RES - 1)
	for iz in range(CONTOUR_RES):
		var fz := float(iz) / ratio
		var z0 := clampi(int(floor(fz)), 0, FIELD_RES - 2)
		var tz := fz - float(z0)
		var row := iz * CONTOUR_RES
		var row_a := z0 * FIELD_RES
		var row_b := row_a + FIELD_RES
		for ix in range(CONTOUR_RES):
			var fx := float(ix) / ratio
			var x0 := clampi(int(floor(fx)), 0, FIELD_RES - 2)
			var tx := fx - float(x0)
			var top: float = lerpf(mask[row_a + x0], mask[row_a + x0 + 1], tx)
			var bottom: float = lerpf(mask[row_b + x0], mask[row_b + x0 + 1], tx)
			fine[row + ix] = lerpf(top, bottom, tz)
	return fine

## Two-pass separable box blur, which approximates a Gaussian closely enough to round
## the lattice corners without shifting a straight frontier away from the watercourse.
func blur_field(field: PackedFloat32Array, res: int, radius: float) -> PackedFloat32Array:
	var r := int(round(radius))
	if r < 1:
		return field
	var out := field
	for pass_index in range(2):
		out = _blur_axis(out, res, r, true)
		out = _blur_axis(out, res, r, false)
	return out

func _blur_axis(field: PackedFloat32Array, res: int, r: int, horizontal: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(field.size())
	var span := r * 2 + 1
	for iz in range(res):
		var row := iz * res
		for ix in range(res):
			var total := 0.0
			for offset in range(-r, r + 1):
				var sample := clampi(ix + offset, 0, res - 1) if horizontal else clampi(iz + offset, 0, res - 1)
				total += field[row + sample] if horizontal else field[sample * res + ix]
			out[row + ix] = total / float(span)
	return out

## Marching squares over a scalar field. `step` is the world-unit distance between
## field nodes and every emitted point is already in map-pixel space.
func contour_segments(field: PackedFloat32Array, res: int, step: float, iso: float) -> Array:
	var segments := []
	var last := res - 2
	for iz in range(last):
		var row := iz * res
		var row_next := row + res
		var origin_y := -EXTENT + float(iz) * step
		for ix in range(last):
			var v0 := field[row + ix]
			var v1 := field[row + ix + 1]
			var v2 := field[row_next + ix + 1]
			var v3 := field[row_next + ix]
			var code := 0
			if v0 >= iso:
				code |= 1
			if v1 >= iso:
				code |= 2
			if v2 >= iso:
				code |= 4
			if v3 >= iso:
				code |= 8
			if code == 0 or code == 15:
				continue
			var origin_x := -EXTENT + float(ix) * step
			var top_left := Vector2(origin_x, origin_y)
			var top_right := Vector2(origin_x + step, origin_y)
			var bottom_right := Vector2(origin_x + step, origin_y + step)
			var bottom_left := Vector2(origin_x, origin_y + step)
			var top := world_to_map_point(_iso_edge(top_left, top_right, v0, v1, iso))
			var right := world_to_map_point(_iso_edge(top_right, bottom_right, v1, v2, iso))
			var bottom := world_to_map_point(_iso_edge(bottom_left, bottom_right, v3, v2, iso))
			var left := world_to_map_point(_iso_edge(top_left, bottom_left, v0, v3, iso))
			match code:
				1, 14:
					segments.append([left, top])
				2, 13:
					segments.append([top, right])
				3, 12:
					segments.append([left, right])
				4, 11:
					segments.append([right, bottom])
				6, 9:
					segments.append([top, bottom])
				7, 8:
					segments.append([left, bottom])
				5:
					segments.append([left, top])
					segments.append([right, bottom])
				10:
					segments.append([top, right])
					segments.append([bottom, left])
	return segments

func _iso_edge(a: Vector2, b: Vector2, va: float, vb: float, iso: float) -> Vector2:
	var denominator := va - vb
	if absf(denominator) < 0.000001:
		return a
	return a.lerp(b, clampf((iso - va) / denominator, 0.0, 1.0))

## Even-spacing resample followed by Chaikin corner cutting. The resample matters:
## Chaikin cuts a fixed fraction of each segment, so uneven input segments give uneven
## rounding and the staircase survives as a rhythm of sharp and soft corners.
## Loops arrive from stitch() as rings of distinct points that close geometrically, so
## they are resampled and cut as rings; the short closing segment is left in place
## because _draw() closes the path when it draws.
func smooth_loops(loops: Array) -> Array:
	var out := []
	for loop in loops:
		var points: PackedVector2Array = loop as PackedVector2Array
		if points.size() < 4:
			out.append(points)
			continue
		points = _chaikin(_resample(points, CONTOUR_SPACING), CHAIKIN_ITERATIONS)
		if points.size() >= 3:
			out.append(points)
	return out

func _resample(points: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	if total < spacing * 2.0:
		return points
	var count := maxi(int(total / spacing), 3)
	var step_length := total / float(count)
	var out := PackedVector2Array()
	var carried := 0.0
	out.append(points[0])
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var segment := a.distance_to(b)
		if segment < 0.000001:
			continue
		var travelled := step_length - carried
		while travelled <= segment:
			out.append(a.lerp(b, travelled / segment))
			travelled += step_length
		carried = segment - (travelled - step_length)
	return out

func _chaikin(points: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var current := points
	for _pass in range(iterations):
		var count := current.size()
		if count < 4:
			break
		var out := PackedVector2Array()
		out.resize(count * 2)
		for i in range(count):
			var a := current[i]
			var b := current[(i + 1) % count]
			out[i * 2] = a.lerp(b, CHAIKIN_RATIO)
			out[i * 2 + 1] = a.lerp(b, 1.0 - CHAIKIN_RATIO)
		current = out
	return current

func stitch(segments: Array) -> Array:
	var adjacency := {}
	for segment in segments:
		var a := _point_key(segment[0])
		var b := _point_key(segment[1])
		if a == b:
			continue
		if not adjacency.has(a):
			adjacency[a] = []
		if not adjacency.has(b):
			adjacency[b] = []
		adjacency[a].append(b)
		adjacency[b].append(a)
	var visited := {}
	var loops := []
	for start in adjacency.keys():
		if visited.has(start):
			continue
		var loop := PackedVector2Array()
		var cursor: int = start
		var guard := 0
		while guard < 1000000:
			guard += 1
			if visited.has(cursor):
				break
			visited[cursor] = true
			loop.append(_point_from_key(cursor))
			var next := -1
			for candidate in adjacency[cursor]:
				if not visited.has(candidate):
					next = candidate
					break
			if next == -1:
				break
			cursor = next
			if cursor == start:
				break
		if loop.size() >= 3:
			loops.append(loop)
	return loops

func _point_key(p: Vector2) -> int:
	return (int(round(p.x * 8.0)) << 16) | (int(round(p.y * 8.0)) & 0xFFFF)

func _point_from_key(key: int) -> Vector2:
	return Vector2(float(key >> 16) / 8.0, float(key & 0xFFFF) / 8.0)

# ---------------------------------------------------------------- queries

func compute_label_points() -> void:
	label_points.clear()
	for i in range(regions.size()):
		var id := String(regions[i].get("id", "region_%d" % i))
		var samples: Array[Vector2] = []
		for iz in range(FIELD_RES):
			for ix in range(FIELD_RES):
				if ownership[field_index(ix, iz)] == i:
					samples.append(cell_center(ix, iz))
		if samples.is_empty():
			label_points[id] = seat_world(regions[i])
			continue
		var centroid := Vector2.ZERO
		for p in samples:
			centroid += p
		label_points[id] = centroid / float(samples.size())

func get_label_anchor(region_id: String) -> Vector3:
	var p: Vector2 = label_points.get(region_id, Vector2.ZERO)
	return Vector3(p.x, terrain.height_at(p.x, p.y) + 2.5, p.y)

func region_id_at(x: float, z: float) -> String:
	var cell := field_cell(Vector2(x, z))
	var index := ownership[field_index(cell.x, cell.y)]
	if index < 0 or index >= regions.size():
		return ""
	return String(regions[index].get("id", ""))

func region_record(region_id: String) -> Dictionary:
	return region_by_id.get(region_id, {})

## Distance in metres from a world point to a named mapped watercourse.
## Pass `limit` when only a threshold matters: the cached course bounds reject most
## contour points outright, which is what keeps the survey-line checks cheap now that
## the smoothed contours carry far more vertices than the raw 256 lattice produced.
func distance_to_river(point: Vector2, river_name: String, limit: float = INF) -> float:
	var course: PackedVector2Array = river_cache.get(river_name, PackedVector2Array())
	if course.is_empty():
		return INF
	var bounded := limit < INF
	var reach := limit / METRES_PER_UNIT
	if bounded:
		var bounds: Rect2 = river_bounds.get(river_name, Rect2())
		if not bounds.grow(reach).has_point(point):
			return INF
	var best := INF
	if not bounded:
		for i in range(course.size() - 1):
			var d := closest_point_on_segment(point, course[i], course[i + 1]).distance_to(point)
			if d < best:
				best = d
		return best * METRES_PER_UNIT
	var cell: Dictionary = river_grid.get(river_name, {})
	var span := maxi(int(ceilf(reach / RIVER_BUCKET)), 1)
	var centre := Vector2i(int(floorf(point.x / RIVER_BUCKET)), int(floorf(point.y / RIVER_BUCKET)))
	for cy in range(centre.y - span, centre.y + span + 1):
		for cx in range(centre.x - span, centre.x + span + 1):
			var key := _cell_key(cx, cy)
			if not cell.has(key):
				continue
			for i in cell[key]:
				var d := closest_point_on_segment(point, course[i], course[i + 1]).distance_to(point)
				if d < best:
					best = d
	return best * METRES_PER_UNIT

func contour_vertices(region_index: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var span := EXTENT * 2.0
	for loop in contours[region_index]:
		for point in loop:
			out.append(Vector2(point.x / TEX_SIZE * span - EXTENT, point.y / TEX_SIZE * span - EXTENT))
	return out

func owned_cells(region_id: String) -> int:
	var count := 0
	for i in range(regions.size()):
		if String(regions[i].get("id", "")) == region_id:
			for index in range(ownership.size()):
				if ownership[index] == i:
					count += 1
			return count
	return 0

func land_cells() -> int:
	var count := 0
	for index in range(ownership.size()):
		if ownership[index] >= 0:
			count += 1
	return count

func summarise() -> Dictionary:
	var report := {"chiefdoms": {}, "land_cells": land_cells(), "mode": mode}
	for region in regions:
		var id := String(region.get("id", ""))
		var owned := owned_cells(id)
		report.chiefdoms[id] = {
			"cells": owned,
			"fraction": float(owned) / maxf(float(land_cells()), 1.0),
			"seat": seat_world(region),
		}
	return report

# ---------------------------------------------------------------- modes

func set_mode(value: int) -> void:
	mode = clampi(value, 0, MODE_NAME.size() - 1)
	if not last_report.is_empty():
		last_report.mode = mode
	if target_viewport != null:
		target_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()

func cycle_mode() -> void:
	set_mode((mode + 1) % MODE_NAME.size())

func mode_name() -> String:
	return String(MODE_NAME[clampi(mode, 0, MODE_NAME.size() - 1)])

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not built or mode == Mode.OFF:
		return
	var fill_alpha := float(MODE_FILL_ALPHA[mode])
	var edge_alpha := float(MODE_EDGE_ALPHA[mode])
	var edge_width: float = 2.0 if mode == Mode.WASH else 3.4
	for i in range(contours.size()):
		var colour: Color = region_colors.get(i, Color.WHITE)
		colour.a = fill_alpha
		for loop in contours[i]:
			draw_colored_polygon(loop, colour)
	for i in range(contours.size()):
		var outline: Color = region_colors.get(i, Color.WHITE).darkened(0.42)
		outline.a = edge_alpha
		for loop in contours[i]:
			var closed: PackedVector2Array = (loop as PackedVector2Array).duplicate()
			if closed.size() > 2 and closed[0].distance_to(closed[closed.size() - 1]) > 0.01:
				closed.append(closed[0])
			draw_polyline(closed, outline, edge_width, true)
	if mode == Mode.SURVEY:
		draw_frontier_marks(edge_alpha)

func draw_frontier_marks(edge_alpha: float) -> void:
	var ink := Color("f2e3c4")
	ink.a = edge_alpha
	for entry in snapped_frontiers:
		var points: PackedVector2Array = entry.points
		for i in range(points.size() - 1):
			var a := world_to_map_point(points[i])
			var b := world_to_map_point(points[i + 1])
			if a.distance_to(b) > 240.0:
				continue
			draw_dashed_line(a, b, ink, 2.0, 14.0, true)
	for i in range(snapped_rim.size()):
		draw_frontier_mark(snapped_rim[i], ink, 7.0)
	for i in range(regions.size()):
		var seat_world_point := seat_world(regions[i])
		var seat := world_to_map_point(seat_world_point)
		var seat_colour: Color = region_colors.get(i, Color.WHITE)
		seat_colour.a = edge_alpha
		draw_circle(seat, 7.0, seat_colour)
		draw_arc(seat, 12.0, 0.0, TAU, 20, ink, 1.6, true)

func draw_frontier_mark(p: Vector2, ink: Color, size: float) -> void:
	var centre := world_to_map_point(p)
	var diamond := PackedVector2Array([
		centre + Vector2(0.0, -size), centre + Vector2(size, 0.0),
		centre + Vector2(0.0, size), centre + Vector2(-size, 0.0), centre + Vector2(0.0, -size)])
	draw_polyline(diamond, ink, 1.8, true)
