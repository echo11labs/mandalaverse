extends SceneTree
## Test map integrity, river continuity, picking and the rendered scene's data.

var checks := 0
var failures: Array[String] = []

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var map: GopalaValleyTerrain = load("res://data/maps/starting_valley.tres")
	expect(map.validate().is_empty(), "Saved map validates.")
	expect(map.size == Vector2i(48, 48) and map.cells.size() == 2304, "Map covers exactly 48 by 48 cells.")
	var repeated := GopalaValleyTerrain.generate(map.seed_value)
	expect(map.cells == repeated.cells and map.moisture == repeated.moisture, "Regeneration is deterministic.")
	expect(map.is_buildable_ground(map.camp_cell), "Camp has suitable ground.")
	expect(not map.is_walkable(Vector2i(-1, 0)) and not map.is_buildable_ground(Vector2i(48, 20)), "Outside cells are rejected.")
	for y in range(24, 34):
		for x in range(9, 19):
			expect(map.is_buildable_ground(Vector2i(x, y)), "Starting clearing stays contiguous.")
	var water_cells: Array[Vector2i] = []
	var kinds: Dictionary = {}
	for y in range(map.size.y):
		for x in range(map.size.x):
			var cell := Vector2i(x, y)
			kinds[map.kind_at(cell)] = true
			if map.kind_at(cell) == GopalaValleyTerrain.Kind.WATER:
				water_cells.append(cell)
				expect(not map.is_walkable(cell) and not map.is_buildable_ground(cell), "Water blocks walking and construction.")
	expect(kinds.size() == GopalaValleyTerrain.NAMES.size(), "All eight terrain surfaces occur.")
	var reached: Dictionary = {water_cells[0]: true}
	var queue: Array[Vector2i] = [water_cells[0]]
	var cursor := 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = current + delta
			if map.kind_at(neighbor) == GopalaValleyTerrain.Kind.WATER and not reached.has(neighbor):
				reached[neighbor] = true
				queue.append(neighbor)
	expect(reached.size() == water_cells.size(), "River is one connected body using four-neighbor movement.")
	expect(water_cells.any(func(cell: Vector2i): return cell.y == 0) and water_cells.any(func(cell: Vector2i): return cell.y == 47), "River reaches both map boundaries.")
	var packed: PackedScene = load("res://scenes/world/valley.tscn")
	var world: Node2D = packed.instantiate()
	root.add_child(world)
	await process_frame
	var ground: TileMapLayer = world.get_node("Ground")
	var camera: GopalaValleyCamera = world.get_node("Camera2D")
	expect(ground.get_used_cells().size() == 2304, "Every logical cell has ground art.")
	for cell in ground.get_used_cells():
		expect(ground.get_cell_atlas_coords(cell).y == map.kind_at(cell), "Tile appearance matches authoritative terrain.")
		expect(ground.local_to_map(ground.map_to_local(cell)) == cell, "Cell centers round-trip correctly.")
	for factor in [0.17, 0.35, 0.62, 1.2]:
		camera.zoom = Vector2.ONE * factor
		camera.position = ground.map_to_local(map.camp_cell)
		camera.force_update_scroll()
		for cell in [Vector2i.ZERO, map.camp_cell, Vector2i(23, 15), Vector2i(47, 47)]:
			var screen := ground.get_global_transform_with_canvas() * ground.map_to_local(cell)
			var local := ground.get_global_transform_with_canvas().affine_inverse() * screen
			expect(ground.local_to_map(local) == cell, "Picking survives pan and zoom transforms.")
	camera.zoom = Vector2.ONE * 0.62
	camera.position = ground.map_to_local(map.camp_cell)
	camera.force_update_scroll()
	var pointer_before := camera.get_global_mouse_position()
	camera.set_zoom_at_pointer(0.8)
	expect(camera.get_global_mouse_position().distance_to(pointer_before) < 0.5, "Zoom retains the ground under the pointer away from bounds.")
	camera.set_zoom_at_pointer(99.0)
	expect(is_equal_approx(camera.zoom.x, camera.MAX_ZOOM), "Maximum zoom clamps.")
	camera.set_zoom_at_pointer(0.01)
	expect(is_equal_approx(camera.zoom.x, camera.MIN_ZOOM), "Minimum zoom clamps.")
	camera.position = Vector2(100000, -100000)
	camera.clamp_position()
	expect(camera.world_bounds.has_point(camera.position), "Camera cannot leave its allowed bounds.")
	world.select_cell(water_cells[0])
	expect(world.get_node("TerrainOverlay").selected == water_cells[0] and "Blocked" in world.status.text, "Water selection explains its restriction.")
	world.select_cell(Vector2i(-1, -1))
	expect(world.get_node("TerrainOverlay").selected == Vector2i(-1, -1), "Outside clicks clear selection.")
	world.queue_free()
	await process_frame
	print("GOPALA_TEST_REPORT=", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures, "river_cells": water_cells.size(), "terrain_surfaces": kinds.size()}))
	quit(0 if failures.is_empty() else 1)
