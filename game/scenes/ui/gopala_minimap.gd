class_name GopalaMinimap
extends Control
## Schematic survey minimap drawn from the same geography as the 3D scene.
## Rivers, the source landmark and the camp marker come from the loaded terrain
## metadata, so the plate can never drift out of step with the world it summarises.

const EXTENT := 400.0
const TERRITORY_PATH := "res://data/geography/regions_gopala.json"

var terrain: GopalaKathmanduTerrain
var regions: Array = []
var camera_position := Vector2.ZERO
var camera_size := 100.0
var territory_mode := "Off"
var territory_tint := 1

func _init() -> void:
	custom_minimum_size = Vector2(168, 168)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(terrain_ref: GopalaKathmanduTerrain, region_list: Array) -> void:
	terrain = terrain_ref
	regions = region_list
	queue_redraw()

func set_view(center: Vector3, view_size: float) -> void:
	camera_position = Vector2(center.x, center.z)
	camera_size = view_size
	queue_redraw()

func set_territory(mode: String) -> void:
	territory_mode = mode
	queue_redraw()

func world_to_local_point(world: Vector2) -> Vector2:
	var inset := 10.0
	var side := minf(size.x, size.y) - inset * 2.0
	var origin := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
	var unit := world / EXTENT * 0.5 + Vector2(0.5, 0.5)
	return origin + unit * side

func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5
	var centre := size * 0.5
	draw_circle(centre, radius, GopalaTheme.PAPER)

	# An unloaded terrain has no elevation field or river graph, so the plate
	# falls back to blank paper rather than sampling past the end of the array.

	if terrain != null and terrain.source.size() > 0:
		_draw_relief_shading(radius)
		_draw_rivers()
		_draw_camp()
	_draw_territory(radius)
	_draw_viewfinder(radius)
	_draw_frame(radius)

func _has_geography() -> bool:
	return terrain != null and terrain.source.size() > 0 and terrain.metadata.has("rivers")

## Cheap hillshade: sample the elevation field on a coarse lattice so the plate
## reads as terrain instead of blank paper.
func _draw_relief_shading(radius: float) -> void:
	var samples := 26
	var step := radius * 2.0 / float(samples)
	var low := Color("efe6d2")
	var high := Color("b9c0a1")
	for row in samples:
		for column in samples:
			var local := Vector2(column * step, row * step)
			var world := _local_to_world(local, radius)
			var elevation := terrain.elevation_at(world.x, world.y)
			var t := clampf((elevation - 1300.0) / 1200.0, 0.0, 1.0)
			draw_rect(Rect2(local, Vector2(step + 0.5, step + 0.5)), low.lerp(high, t))

func _local_to_world(local: Vector2, radius: float) -> Vector2:
	var unit := local / (radius * 2.0)
	return (unit - Vector2(0.5, 0.5)) * EXTENT

func _draw_rivers() -> void:
	for river in terrain.metadata.get("rivers", []):
		var points: Array = river.get("points", [])
		_draw_polyline(points, Color("8fb4c4"), 1.6)
	for river in terrain.metadata.get("reconstruction", []):
		var points: Array = river.get("points", [])
		_draw_polyline(points, Color("d8ab63"), 1.2)

func _draw_polyline(points: Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	var previous := Vector2.ZERO
	var started := false
	for point in points:
		if point is Array and point.size() >= 3:
			var projected := world_to_local_point(Vector2(point[0], point[2]))
			if started:
				draw_line(previous, projected, color, width, true)
			previous = projected
			started = true

func _draw_camp() -> void:
	var marker := world_to_local_point(terrain.camp)
	draw_circle(marker, 4.5, GopalaTheme.BRASS)
	draw_arc(marker, 7.5, 0.0, TAU, 24, GopalaTheme.BRASS_DARK, 1.2, true)

func _draw_territory(radius: float) -> void:
	if territory_mode == "Off" or regions.is_empty():
		return
	var alpha := 0.18 if territory_mode == "Wash" else 0.30
	for region in regions:
		var anchor: Variant = region.get("seat", {})
		if not anchor is Dictionary:
			continue
		var tint := Color(String(region.get("tint", "#c9a84c")))
		tint.a = alpha
		var seat := world_to_local_point(Vector2(float(anchor.get("lon", 85.3)) - 85.375, 27.695 - float(anchor.get("lat", 27.70))))
		draw_circle(seat, 5.0, tint)

## A brass frame showing exactly how much ground the current camera covers.
func _draw_viewfinder(radius: float) -> void:
	var extent_world := maxf(camera_size * 2.0, 12.0)
	var half := extent_world / EXTENT * (radius * 2.0) * 0.5
	var centre := world_to_local_point(camera_position)
	var box := Rect2(centre - Vector2(half, half), Vector2(half * 2.0, half * 2.0)).abs()
	box = box.intersection(Rect2(Vector2.ZERO, size))
	if box.size.x > 6.0 and box.size.y > 6.0:
		draw_rect(box, Color(GopalaTheme.BRASS.r, GopalaTheme.BRASS.g, GopalaTheme.BRASS.b, 0.55), false, 1.4)

func _draw_frame(radius: float) -> void:
	draw_arc(size * 0.5, radius - 1.0, 0.0, TAU, 64, GopalaTheme.BRASS, 1.6, true)
	draw_arc(size * 0.5, radius - 3.5, 0.0, TAU, 64, Color(GopalaTheme.BRASS.r, GopalaTheme.BRASS.g, GopalaTheme.BRASS.b, 0.35), 1.0, true)