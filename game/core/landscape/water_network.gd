class_name GopalaWaterNetwork
extends RefCounted
## Read-only water-source geometry. Does not create inventory, yields, or reservations.
const River = preload("res://core/landscape/terrain_river.gd")
const BIN_SIZE := 2.0
var terrain: GopalaKathmanduTerrain
var bins: Dictionary = {}
var source_count := 0

func _init(model: GopalaKathmanduTerrain) -> void:
	terrain = model
	for reach in terrain.metadata.rivers:
		if River.is_hidden_tag(reach.get("covered", false)) or River.is_hidden_tag(reach.get("tunnel", false)):
			continue
		source_count += 1
		for i in range(reach.points.size() - 1):
			var a := Vector2(reach.points[i][0], reach.points[i][2])
			var b := Vector2(reach.points[i + 1][0], reach.points[i + 1][2])
			if a.distance_squared_to(b) < 0.00000001:
				continue
			var segment := {"a": a, "b": b, "source_id": reach.id, "name": reach.name, "half_width": River.half_width(reach)}
			var lower := Vector2i(floori((minf(a.x,b.x)-0.35)/BIN_SIZE),floori((minf(a.y,b.y)-0.35)/BIN_SIZE))
			var upper := Vector2i(floori((maxf(a.x,b.x)+0.35)/BIN_SIZE),floori((maxf(a.y,b.y)+0.35)/BIN_SIZE))
			for x in range(lower.x, upper.x + 1):
				for y in range(lower.y, upper.y + 1):
					var key := Vector2i(x, y)
					if not bins.has(key): bins[key] = []
					bins[key].append(segment)

func sample(point: Vector3) -> Dictionary:
	var result := {"has_water": false, "source_id": "", "name": "", "distance_m": INF, "surface_y": 0.0, "flow_direction": Vector3.ZERO, "mapped": true}
	var p := Vector2(point.x, point.z)
	var key := Vector2i(floori(p.x / BIN_SIZE), floori(p.y / BIN_SIZE))
	for segment in bins.get(key, []):
		var a: Vector2 = segment.a
		var delta: Vector2 = segment.b - a
		var t := clampf((p - a).dot(delta) / delta.length_squared(), 0.0, 1.0)
		var distance := p.distance_to(a + delta * t)
		if distance * terrain.METRES_PER_UNIT >= result.distance_m: continue
		var direction := delta.normalized()
		result = {"has_water": distance <= segment.half_width, "source_id": segment.source_id, "name": segment.name,
			"distance_m": distance * terrain.METRES_PER_UNIT, "surface_y": terrain.height_at(point.x,point.z) + River.SURFACE_LIFT,
			"flow_direction": Vector3(direction.x, 0.0, direction.y), "mapped": true}
	return result
