extends SceneTree
var checks := 0
var failures: Array[String] = []
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var terrain: GopalaSculptedValley = load("res://data/maps/sculpted_valley.tres")
	var repeat := GopalaSculptedValley.new()
	for z in range(-90, 91, 3):
		var center := terrain.river_center(z)
		expect(terrain.height_at(center, z) < 0.28, "Riverbed stays submerged")
		expect(absf(terrain.height_at(center + terrain.water_half_width(z), z) - 0.28) < 0.005, "Water edge meets riverbank")
		expect(terrain.height_at(center, z) == repeat.height_at(center, z), "Seed repeats terrain")
	for y in range(48):
		for x in range(48):
			var cell := Vector2i(x, y)
			var point := terrain.cell_position(cell)
			expect(point.is_finite() and terrain.cell_at(point) == cell, "Logical grid round trips")
			if point.y < 0.28: expect(not terrain.is_buildable(cell), "Underwater cells reject buildings")
	for z in range(10, 27, 4):
		for x in range(-36, -19, 4): expect(terrain.is_buildable(terrain.cell_at(Vector3(x, 0, z))), "Clearing admits buildings")
	expect(not terrain.is_buildable(Vector2i(-1, 0)) and not terrain.is_buildable(Vector2i(48, 48)), "Outside settlement rejected")
	var packed: PackedScene = load("res://scenes/landscape/scenic_valley.tscn")
	var world = packed.instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var camera: GopalaScenicCamera = world.get_node("Camera3D")
	expect(world.ground_mesh.get_surface_count() == 1 and world.tree_count > 300, "Terrain and decorative groves generated")
	var arrays: Array = world.ground_mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(0, verts.size(), 97):
		expect(verts[i].is_finite() and normals[i].is_finite() and normals[i].y > 0, "Finite upward terrain normals")
		if absf(verts[i].x) <= 90 and absf(verts[i].z) <= 90:
			expect(absf(verts[i].y - terrain.height_at(verts[i].x, verts[i].z)) < 0.0001, "Visible ground matches logical height")
	for size_value in [32.0, 65.0, 175.0, 190.0]:
		camera.size = size_value
		camera.target = Vector3(-28, 2, 18)
		camera.update_view()
		var point := terrain.cell_position(terrain.cell_at(Vector3(-28, 0, 18)))
		var hit: Dictionary = world.pick(camera.unproject_position(point))
		expect(not hit.is_empty(), "Camera ground ray intersects at each zoom")
		if not hit.is_empty(): expect(terrain.cell_at(hit.position) == terrain.cell_at(point), "Picked cell matches projected ground")
	var grid_event := InputEventKey.new()
	grid_event.keycode = KEY_G
	grid_event.pressed = true
	world._unhandled_input(grid_event)
	expect(world.grid_view.visible, "Planning grid toggles on")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = camera.unproject_position(terrain.cell_position(terrain.cell_at(Vector3(-28, 0, 18))))
	world._unhandled_input(click)
	expect(world.selection.mesh != null and world.inspection.text.contains("Suitable ground"), "Ground inspection selects suitable clearing")
	camera.zoom_by(0.0001)
	expect(camera.size == camera.MIN_SIZE, "Minimum zoom bounded")
	camera.zoom_by(10000)
	expect(camera.size == camera.MAX_SIZE, "Maximum zoom bounded")
	camera.pan(Vector2(1000, -1000))
	expect(absf(camera.target.x) <= 72 and absf(camera.target.z) <= 72, "Camera panning bounded")
	world.queue_free()
	await process_frame
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
