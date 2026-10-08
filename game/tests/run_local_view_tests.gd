extends SceneTree
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)
func run() -> void:
	check(DisplayServer.get_name() != "headless", "Scenery buffer tests use a real renderer")
	var valley = load("res://scenes/landscape/kathmandu_valley.tscn").instantiate()
	root.add_child(valley)
	current_scene = valley
	for frame in 5: await process_frame
	await physics_frame
	var coordinates = valley.simulation.coordinate_service()
	var config = coordinates._config
	check(is_equal_approx(config.meters_per_cell, 2.0), "Planning cells are two metres")
	var grid: PackedVector3Array = valley.grid_view.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(grid.size() == 2 * 49 * 48 * 2, "Visible grid covers exactly the 48x48 logical map")
	for point in grid:
		var offset: Vector2 = (Vector2(point.x,point.z) - config.origin_xz) / config.world_units_per_cell
		check(absf(offset.x + 0.5 - roundf(offset.x + 0.5)) < 0.001 and absf(offset.y + 0.5 - roundf(offset.y + 0.5)) < 0.001, "Grid vertices sit on half-cell borders")
	check(valley.ground.mesh == null and valley.ground.get_child_count() == 256, "Rendered terrain has independent spatial chunks")
	var triangles := 0
	for chunk in valley.ground.get_children():
		var arrays: Array = chunk.mesh.surface_get_arrays(0)
		triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
		check(chunk.material_override == valley.ground.material_override, "Territory overlay shared by terrain chunks")
	check(triangles == 512 * 512 * 2, "Chunk partition preserves every terrain triangle")
	var actors: Array = []
	for kind in [GopalaEntityKind.VILLAGER, GopalaEntityKind.BUILDING]:
		for actor in valley.simulation.entity_queries().snapshots_by_kind(kind): actors.append(valley._built_views[actor.entity_id])
	var middle: Vector3 = (actors[0].position + actors[1].position) * 0.5
	check(Vector2(valley.camera.target.x,valley.camera.target.z).distance_to(Vector2(middle.x,middle.z)) < 0.00001, "Home focus uses current worker and building")
	check(is_equal_approx(valley.camera.size, 0.4), "Startup frames settlement within 40m")
	var balances: Dictionary = valley.simulation.snapshot().resource_balances
	valley.hud._placement_active = true
	valley.hud._selected_build = &"stockpile"
	var cell := Vector2i(5,-5)
	var point: Vector2 = coordinates.settlement_cell_to_world_xz(cell)
	var screen: Vector2 = valley.camera.unproject_position(Vector3(point.x,valley.ground_height_at(point.x,point.y),point.y))
	for turn in [0,1,2,3]:
		valley._placement_rotation = turn
		valley._update_ghost(screen)
		check(valley._placement_cell == cell, "Pointer snaps to logical cell at every rotation")
		var ghost: MeshInstance3D = valley._placement_ghost
		check(is_equal_approx(ghost.mesh.size.x, 0.04) and is_equal_approx(ghost.mesh.size.z, 0.04), "Ghost footprint uses 4m plot")
		check(absf(ghost.position.y - ghost.mesh.size.y * 0.5 - valley.ground_height_at(ghost.position.x,ghost.position.z)) < 0.000001, "Ghost bottom touches terrain")
		check(valley._placement_outline.visible and valley._placement_outline.mesh != null, "Placement shows exact occupied cells")
	valley.hud.clear_build()
	valley._process(0.1)
	check(not valley._placement_outline.visible and not valley._placement_ghost.visible, "Closing build clears visual footprint")
	var window: GopalaSceneryWindow = valley.get_node("LocalSceneryWindow")
	check(window.sources.size() > 0 and window.sources.all(func(source): return not source.visible), "Camera-local scenery excludes coarse regional batches")
	for index in window.cached:
		var entry: Dictionary = window.cached[index]
		var count := 0
		for part in entry.parts: count += part.node.multimesh.instance_count
		check(count == window.sources[index].multimesh.instance_count, "Fine batches preserve original population")
	var forest_point: Vector3 = window.sources[0].global_transform * window.sources[0].multimesh.get_instance_transform(0).origin
	valley.camera.focus_point(forest_point, 0.4)
	window.update_window()
	check(window.active_instances > 0, "Panning into authored forest activates nearby trees")
	for index in window.cached:
		var count := 0
		for part in window.cached[index].parts: count += part.node.multimesh.instance_count
		check(count == window.sources[index].multimesh.instance_count, "Authored forest subdivision preserves every tree")
	valley.camera.overview()
	window.update_window()
	check(window.sources.all(func(source): return source.visible), "Regional overview restores coarse scenery")
	check(window.cached.values().all(func(entry): return not entry.root.visible), "Fine batches hidden at overview; no duplicate rendering")
	valley.focus_camp()
	window.update_window()
	check(window.sources.all(func(source): return not source.visible), "Home restores camera-local scenery")
	check(valley.simulation.snapshot().resource_balances == balances, "View changes preserve resource inventory")
	valley.hud._placement_active = true
	valley.hud._selected_build = &"stockpile"
	valley._placement_rotation = 0
	valley._update_ghost(screen)
	valley._process(0.1)
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../reports/manual/settlement-grid.png")
	# Isolated transforms, attributes and visibility are checked independently of art.
	window.set_process(false)
	var fixture := Node3D.new()
	root.add_child(fixture)
	var source := MultiMeshInstance3D.new()
	fixture.add_child(source)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = BoxMesh.new()
	multi.mesh.size = Vector3.ONE * 0.01
	multi.instance_count = 3
	for index in 3:
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(float(index - 1) * 2.0, 0, 0)))
		multi.set_instance_color(index, Color(0.2 * index,0.3,0.4,1))
		multi.set_instance_custom_data(index, Color(0.1,0.1 * index,0.3,1))
	source.multimesh = multi
	var test_window := GopalaSceneryWindow.new()
	fixture.add_child(test_window)
	valley.camera.focus_point(Vector3.ZERO, 0.4)
	test_window.configure(valley.camera, fixture)
	check(test_window.active_instances == 1, "Local window excludes distant synthetic instances")
	var entry: Dictionary = test_window.cached[0]
	for part in entry.parts:
		var placement: Transform3D = part.node.multimesh.get_instance_transform(0)
		var index := int(roundf(placement.origin.x / 2.0)) + 1
		check(placement == multi.get_instance_transform(index), "Transform survives subdivision exactly")
		check(part.node.multimesh.get_instance_color(0).is_equal_approx(multi.get_instance_color(index)), "Instance tint survives subdivision")
		check(part.node.multimesh.get_instance_custom_data(0).is_equal_approx(multi.get_instance_custom_data(index)), "Instance data survives subdivision")
	valley.camera.focus_point(Vector3(2,0,0),0.4)
	test_window.update_window()
	check(test_window.active_instances == 1 and test_window.cached.size() == 1, "Panning reuses cached fine batches")
	fixture.queue_free()
	valley.queue_free()
	await process_frame
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
