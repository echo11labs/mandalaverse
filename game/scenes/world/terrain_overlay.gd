class_name GopalaTerrainOverlay
extends Node2D
## Borders and picking feedback share the actual TileMapLayer conversion.

var terrain: GopalaValleyTerrain
var ground: TileMapLayer
var camera: GopalaValleyCamera
var selected := Vector2i(-1, -1)
var show_grid := false
var show_buildable := false
const CARDINALS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const CORNERS := [Vector2(0, -32), Vector2(64, 0), Vector2(0, 32), Vector2(-64, 0)]

func cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center := ground.map_to_local(cell)
	for corner in CORNERS:
		points.append(center + corner)
	return points

func _draw() -> void:
	if terrain == null or ground == null or camera == null:
		return
	for cell in ground.get_used_cells():
		var center := ground.map_to_local(cell)
		if terrain.kind_at(cell) == GopalaValleyTerrain.Kind.WATER:
			for i in range(CARDINALS.size()):
				var neighbor: Vector2i = cell + CARDINALS[i]
				if terrain.contains(neighbor) and terrain.kind_at(neighbor) != GopalaValleyTerrain.Kind.WATER:
					draw_line(center + CORNERS[i], center + CORNERS[(i + 1) % 4], Color("ded1a7"), 5.0, true)
		if show_buildable:
			var color := Color(0.80, 0.97, 0.67, 0.23) if terrain.is_buildable_ground(cell) else Color(0.16, 0.21, 0.2, 0.43)
			draw_colored_polygon(cell_polygon(cell), color)
	if show_grid:
		for y in range(terrain.size.y + 1):
			var first := ground.map_to_local(Vector2i(0, y)) + Vector2(0, -32)
			var last := ground.map_to_local(Vector2i(terrain.size.x - 1, y)) + Vector2(64, 0)
			draw_line(first, last, Color(0.94, 0.96, 0.82, 0.2), 1.0 / camera.zoom.x, true)
		for x in range(terrain.size.x + 1):
			var first := ground.map_to_local(Vector2i(x, 0)) + Vector2(0, -32)
			var last := ground.map_to_local(Vector2i(x, terrain.size.y - 1)) + Vector2(-64, 0)
			draw_line(first, last, Color(0.94, 0.96, 0.82, 0.2), 1.0 / camera.zoom.x, true)
	if terrain.contains(selected):
		var points := cell_polygon(selected)
		draw_colored_polygon(points, Color(1, 0.95, 0.7, 0.17))
		points.append(points[0])
		draw_polyline(points, Color("fff0bc"), 2.0 / camera.zoom.x, true)
	var camp := ground.map_to_local(terrain.camp_cell)
	draw_circle(camp, 6.0 / camera.zoom.x, Color("f3e7bc"))
	draw_arc(camp, 11.0 / camera.zoom.x, 0, TAU, 32, Color(0.98, 0.95, 0.8, 0.7), 1.0 / camera.zoom.x, true)
	var font := ThemeDB.fallback_font
	var text_size := int(13.0 / camera.zoom.x)
	draw_string(font, camp + Vector2(19, -8) / camera.zoom.x, "Starting clearing", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color("324438"))
	draw_string(font, camp + Vector2(18, -9) / camera.zoom.x, "Starting clearing", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color("f3ebd0"))
