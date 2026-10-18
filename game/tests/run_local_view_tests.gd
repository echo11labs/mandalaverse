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

func _mouse_motion(point: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	return event

func _mouse_button(point: Vector2, button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	return event

func run() -> void:
	check(DisplayServer.get_name() != "headless", "Scenery buffer tests use a real renderer")
	var valley = load("res://scenes/landscape/kathmandu_valley.tscn").instantiate()
	root.add_child(valley)
	current_scene = valley
	for frame in 5: await process_frame
	await physics_frame
	var initial_positions: Array[Vector2] = []
	for kind in [GopalaEntityKind.VILLAGER, GopalaEntityKind.BUILDING]:
		for actor in valley.simulation.entity_queries().snapshots_by_kind(kind):
			var actor_position := Vector2(float(actor.attributes.get("position_x", valley.terrain.camp.x)), float(actor.attributes.get("position_z", valley.terrain.camp.y)))
			if valley._built_views.has(actor.entity_id):
				var actor_view: Vector3 = valley._built_views[actor.entity_id].position
				actor_position = Vector2(actor_view.x, actor_view.z)
			initial_positions.append(actor_position)
	if not initial_positions.is_empty():
		var initial_bounds := Rect2(initial_positions[0], Vector2.ZERO)
		for index in range(1, initial_positions.size()): initial_bounds = initial_bounds.expand(initial_positions[index])
		check(Vector2(valley.camera.target.x, valley.camera.target.z).distance_to(initial_bounds.get_center()) < 0.00001, "Startup camera centres the initial settlement bounds")
	valley.simulation.set_paused(false)
	valley.simulation.process_pending_commands()
	var home_cell := Vector2i(7,-6)
	var home_point: Vector2 = valley.simulation.coordinate_service().settlement_cell_to_world_xz(home_cell)
	var home_screen: Vector2 = valley.camera.unproject_position(Vector3(home_point.x,valley.ground_height_at(home_point.x,home_point.y),home_point.y))
	valley.hud._placement_active = true
	valley.hud._selected_build = &"dwelling"
	valley._placement_cell = home_cell
	valley._placement_valid = valley.simulation.placement_service().validate_placement(&"dwelling",home_cell,0).valid
	valley._unhandled_input(_mouse_button(home_screen,MOUSE_BUTTON_LEFT,true))
	valley.simulation.process_pending_commands()
	var homes: Array = valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING).filter(func(b): return b.attributes.get("definition_id") == &"dwelling")
	check(homes.size() == 1, "A valid house placement creates a construction site")
	# Plant a real field through the same placement/input and selection adapters
	# used by the game, then issue crop/work orders through the field inspector.
	var field_anchor := Vector2i.ZERO
	var field_validation: GopalaConstructionValidationResult = valley.simulation.field_service().validate_field(field_anchor)
	for y in range(-18, 19):
		for x in range(-18, 19):
			if field_validation.valid: break
			var candidate := Vector2i(x, y)
			field_validation = valley.simulation.field_service().validate_field(candidate)
			if field_validation.valid: field_anchor = candidate
	if field_validation.valid:
		valley.hud._placement_active = true
		valley.hud._selected_build = &"field"
		valley._placement_cell = field_anchor
		valley._placement_valid = true
		var field_point: Vector2 = valley.simulation.coordinate_service().settlement_cell_to_world_xz(field_anchor)
		var field_screen: Vector2 = valley.camera.unproject_position(Vector3(field_point.x, valley.ground_height_at(field_point.x, field_point.y), field_point.y))
		valley._unhandled_input(_mouse_button(field_screen, MOUSE_BUTTON_LEFT, true))
		valley.simulation.process_pending_commands()
		var fields: Array[GopalaEntitySnapshot] = valley.simulation.field_service().fields()
		check(fields.size() == 1, "A valid placement click creates a field through the GUI command path")
		if fields.size() == 1:
			var field_id := fields[0].entity_id
			check(valley.hud._inspect_title.text == "Field #%d" % field_id, "Newly placed field opens its contextual inspector")
			check(valley.hud._inspect_body.text.contains("Field condition") and valley.hud._inspect_body.text.contains("No crop selected"), "Placed field inspector exposes its crop condition")
			check(valley.hud._inspect_body.text.contains("Season") and valley.hud._inspect_body.text.contains("Dry"), "Field inspector names the current and upcoming seasons")
			var crop_order: Array = []
			valley.hud.field_action_requested.connect(func(action: StringName, selected_field_id: int, worker_id: int, crop_id: StringName): crop_order.append([action, selected_field_id, worker_id, crop_id]))
			valley.hud.show_field_controls(field_id, &"FALLOW", &"", [])
			valley.hud._field_crop_choices.select(0)
			valley.hud._field_action_button.pressed.emit()
			valley.simulation.process_pending_commands()
			check(crop_order.size() == 1 and crop_order[0][0] == &"SET_CROP", "Field crop selector emits a player crop order")
			var preparing_field: GopalaEntitySnapshot = valley.simulation.entity_queries().snapshot(field_id)
			check(preparing_field.attributes.get(&"field_stage") == &"PREPARING", "Player crop order reaches the authoritative field simulation")
			valley._inspect_selected_entity(field_id)
			check(valley.hud._inspect_body.text.contains("Potential yield") and valley.hud._inspect_body.text.contains("grain"), "Field inspector forecasts crop-specific potential yield before planting")
			var available_workers: Array = []
			for candidate in valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER):
				if int(candidate.attributes.get("active_task_id", 0)) == 0 and int(candidate.attributes.get("carried_amount", 0)) == 0 and candidate.attributes.get("task_kind") == &"NONE" and valley.simulation._survival_service.ready_for_work(candidate):
					available_workers.append(candidate)
			check(not available_workers.is_empty(), "The settlement provides a free settler for field work")
			if not available_workers.is_empty():
				var worker_for_field: GopalaEntitySnapshot = available_workers[0]
				valley.hud.show_field_controls(field_id, &"PREPARING", &"cereal", [{"id": worker_for_field.entity_id, "status": "Ready"}])
				valley.hud._field_worker_choices.select(0)
				valley.hud._field_action_button.pressed.emit()
				valley.simulation.process_pending_commands()
				check(crop_order.size() == 2 and crop_order[1][0] == &"WORK", "Plant action emits an available worker order")
				check(valley.simulation.field_service()._tasks.has(worker_for_field.entity_id), "Player field-work order reaches field task assignment")
				check(int(valley.simulation.entity_queries().snapshot(worker_for_field.entity_id).attributes.get("active_task_id", 0)) > 0, "Field assignment owns a real settler task")
				var growing_field: GopalaEntitySnapshot = valley.simulation.entity_queries().snapshot(field_id)
				for tick in 1000:
					if growing_field.attributes.get(&"field_stage") in [&"PLANTED",&"GROWING"]: break
					valley.simulation.advance_ticks(1)
					growing_field = valley.simulation.entity_queries().snapshot(field_id)
				valley._inspect_selected_entity(field_id)
				check(growing_field.attributes.get(&"field_stage") in [&"PLANTED",&"GROWING"] and valley.hud._inspect_body.text.contains("Harvest outlook") and valley.hud._inspect_body.text.contains("Expected mature"), "Field inspector exposes crop growth and a live maturity outlook after planting")
				check(valley.hud._inspect_body.text.contains("Season ahead") and valley.hud._inspect_body.text.contains("moisture"), "Active field inspector forecasts the next season's moisture trend")
				valley.simulation.field_service().cancel_worker(worker_for_field.entity_id, valley.simulation.logical_tick)
				check(not valley.simulation.field_service()._tasks.has(worker_for_field.entity_id), "Integration fixture releases the field worker for later construction checks")
	else:
		check(false, "Integration fixture must locate valid field terrain: " + String(field_validation.reason_code))
	var builder: GopalaEntitySnapshot = valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)[0]
	var home: GopalaEntitySnapshot = homes[0]
	valley.simulation.selection_service().select_entity(builder.entity_id)
	valley._inspect_selected_entity(builder.entity_id)
	# Tick/content refreshes must preserve the player's inspector visibility.
	var inspector: Control = valley.hud._inspection.get_parent()
	valley.hud._inspection_section.get_node("Header/Collapse").pressed.emit()
	valley.simulation.advance_ticks(2)
	valley._on_selected_entity_refreshed(valley.simulation.selection_service().snapshot())
	check(valley.hud._inspection_section.collapsed and inspector.visible, "Settler inspector stays collapsed across ticks and selected-entity refreshes")
	check(not valley.hud._inspection_section.body().visible and inspector.size.y == 70, "Collapsed settler inspector keeps only its compact header")
	valley.hud._inspection_section.get_node("Header/Collapse").pressed.emit()
	check(not valley.hud._inspection_section.collapsed and valley.hud._inspection_section.body().visible, "Settler inspector expands from its header button")
	for control in valley.hud._inspection_section.header().get_children():
		if control is Button and control.tooltip_text == "Close (Esc)": control.pressed.emit()
	valley.simulation.advance_ticks(2)
	valley._on_selected_entity_refreshed(valley.simulation.selection_service().snapshot())
	check(not inspector.visible, "Closing settler inspector survives simulation and selection-content updates")
	valley.hud.toggle_build_picker()
	valley._refresh_selected_inspection()
	check(valley.hud._build_bar_shell.visible and not inspector.visible, "Closed settler inspector does not replace the structure picker on refresh")
	valley._inspect_selected_entity(builder.entity_id)
	check(inspector.visible and not valley.hud._inspection_section.collapsed, "Clicking the settler explicitly reopens and expands its inspector")
	valley.hud.close_top_panel()
	valley._refresh_selected_inspection()
	check(not inspector.visible, "Escape-style close also remains closed on refresh")
	valley._inspect_selected_entity(builder.entity_id)
	valley._refresh_builder_job_controls()
	check(valley.hud._builder_jobs.visible and not valley.hud._builder_assign_button.disabled, "Villager inspector offers an assignable build job when a plot is available")
	check(valley.hud.selected_builder_site_id() == home.entity_id, "The house plot is available in the builder site selector")
	valley.hud._builder_assign_button.pressed.emit()
	valley.simulation.process_pending_commands()
	var staffed_home: GopalaEntitySnapshot = valley.simulation.entity_queries().snapshot(home.entity_id)
	check(int(staffed_home.attributes.get("assigned_builder_id",0)) == builder.entity_id, "Build selected site assigns the selected settler to the house")
	var assigned_worker: GopalaEntitySnapshot = valley.simulation.entity_queries().snapshot(builder.entity_id)
	check(assigned_worker.attributes.get("task_kind") == &"BUILD" and int(assigned_worker.attributes.get("active_task_id",0)) > 0, "Builder assignment creates an active construction task")
	check(valley.hud._builder_jobs.visible and valley.hud._builder_assign_button.disabled and not valley.hud._builder_release_button.disabled, "Assigned builder gets stop control and cannot take another site")
	check(valley.hud._inspect_detail.text.contains("Site #%d" % home.entity_id), "Villager inspector identifies its active build site")
	var actual_work_ticks := int(staffed_home.attributes.get("work_required", 0))
	for tick in range(actual_work_ticks + 2000):
		var latest_site: GopalaEntitySnapshot = valley.simulation.entity_queries().snapshot(home.entity_id)
		if latest_site == null or latest_site.attributes.get("construction_state", "") == "COMPLETED":
			break
		valley.simulation.advance_ticks(1)
	var completed_home: GopalaEntitySnapshot = valley.simulation.entity_queries().snapshot(home.entity_id)
	check(completed_home.attributes.get("construction_state", "") == "COMPLETED", "Assigned villager delivers materials and completes the dwelling through simulation ticks")
	check(int(completed_home.attributes.get("work_completed", 0)) == actual_work_ticks, "Completed dwelling reports all required labor ticks")
	check(int(completed_home.attributes.get("assigned_builder_id",0)) == 0, "Completion releases the villager's builder assignment")
	var released_worker: GopalaEntitySnapshot = valley.simulation.entity_queries().snapshot(builder.entity_id)
	check(released_worker.attributes.get("task_kind") == &"NONE" and int(released_worker.attributes.get("active_task_id",0)) == 0, "Completed construction frees the villager for another job")
	valley._inspect_selected_entity(home.entity_id)
	check(valley.hud._inspect_body.text.contains("100 / %d ticks" % actual_work_ticks), "Completed house inspection preserves final labor progress")
	valley._inspect_selected_entity(builder.entity_id)
	valley._refresh_builder_job_controls()
	check(valley.hud._builder_jobs.visible and valley.hud._builder_assign_button.disabled and valley.hud._builder_release_button.disabled, "Completed builder has no active Stop building action")
	var next_cell := Vector2i(12, -6)
	valley.simulation.request_construction(&"dwelling", next_cell)
	valley.simulation.process_pending_commands()
	var next_sites: Array[GopalaEntitySnapshot] = valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING).filter(func(item): return item.attributes.get("definition_id") == &"dwelling" and item.attributes.get("construction_state") != "COMPLETED")
	check(next_sites.size() == 1, "A second dwelling plot can be queued after completing the first")
	var next_home: GopalaEntitySnapshot = next_sites[0]
	valley._inspect_selected_entity(builder.entity_id)
	valley._refresh_builder_job_controls()
	check(not valley.hud._builder_assign_button.disabled and valley.hud.selected_builder_site_id() == next_home.entity_id, "Builder selector offers the next unfinished plot")
	valley.hud._builder_assign_button.pressed.emit()
	valley.simulation.process_pending_commands()
	check(int(valley.simulation.entity_queries().snapshot(next_home.entity_id).attributes.get("assigned_builder_id",0)) == builder.entity_id, "The same villager can be assigned to a second construction site")
	valley.hud._builder_release_button.pressed.emit()
	var released_site: GopalaEntitySnapshot = valley.simulation.entity_queries().snapshot(next_home.entity_id)
	var stopped_worker: GopalaEntitySnapshot = valley.simulation.entity_queries().snapshot(builder.entity_id)
	check(int(released_site.attributes.get("assigned_builder_id",0)) == 0 and stopped_worker.attributes.get("task_kind") == &"NONE", "Stop building releases an unstarted assignment cleanly")
	valley.simulation._construction_labor_service._tasks.clear()
	var build_toggle := InputEventKey.new()
	build_toggle.physical_keycode = KEY_B
	build_toggle.pressed = true
	valley._unhandled_input(build_toggle)
	check(valley.hud._build_bar_shell.visible, "Pressing B opens the structure picker")
	valley._unhandled_input(build_toggle)
	check(not valley.hud._build_bar_shell.visible, "Pressing B again closes the structure picker")
	var road_shortcut := InputEventKey.new()
	road_shortcut.physical_keycode = KEY_R
	road_shortcut.pressed = true
	valley._unhandled_input(road_shortcut)
	check(valley.hud._road_mode and valley.hud._placement_active, "Pressing R enters dirt-path mode")
	check(not valley._placement_ghost.visible, "Road mode suppresses building ghosts")
	var cobbled_shortcut := InputEventKey.new()
	cobbled_shortcut.physical_keycode = KEY_R
	cobbled_shortcut.pressed = true
	cobbled_shortcut.shift_pressed = true
	valley._unhandled_input(cobbled_shortcut)
	check(valley.hud._cobbled_path_mode and valley.hud._selected_build == &"cobbled_path", "Shift+R selects cobbled upgrade mode")
	valley._unhandled_input(road_shortcut)
	check(not valley.hud._road_mode and not valley.hud._placement_active, "R exits road-upgrade mode")
	valley._unhandled_input(road_shortcut)
	check(valley.hud._road_mode and valley.hud._placement_active and not valley.hud._cobbled_path_mode, "R enters dirt-path mode after leaving upgrade mode")
	valley._unhandled_input(road_shortcut)
	check(not valley.hud._road_mode and not valley.hud._placement_active, "R toggles dirt-path mode off")
	valley._unhandled_input(road_shortcut)
	check(valley.hud._road_mode and valley.hud._placement_active, "R re-enters dirt-path mode")
	var coordinates = valley.simulation.coordinate_service()
	var origin_cell := Vector2i(2,2)
	var end_cell := Vector2i(5,2)
	valley._road_start_cell = origin_cell
	valley._road_end_cell = end_cell
	valley._update_road_preview()
	check(valley._orthogonal_cells(origin_cell,end_cell) == [Vector2i(2,2),Vector2i(3,2),Vector2i(4,2),Vector2i(5,2)], "Dragging across four cells previews a continuous route")
	check(valley._road_preview.visible and valley._road_preview.mesh != null, "Road mode shows a visible build preview")
	var to_cell := func(cell: Vector2i) -> Vector2:
		var point: Vector2 = coordinates.settlement_cell_to_world_xz(cell)
		return valley.camera.unproject_position(Vector3(point.x,valley.ground_height_at(point.x,point.y),point.y))
	var before_roads: int = valley.simulation.road_service().road_cells().size()
	var origin_screen := to_cell.call(origin_cell) as Vector2
	var end_screen := to_cell.call(end_cell) as Vector2
	valley._unhandled_input(_mouse_button(origin_screen,MOUSE_BUTTON_LEFT,true))
	check(valley._road_dragging, "Pressing begins a path drag at the selected grid cell")
	valley._unhandled_input(_mouse_motion(end_screen))
	check(valley._road_end_cell == end_cell and valley._road_preview_cells.size() == 4, "Moving extends preview across each traversed cell")
	valley._unhandled_input(_mouse_button(end_screen,MOUSE_BUTTON_LEFT,false))
	valley.simulation.process_pending_commands()
	check(valley.simulation.road_service().road_cells().size() == before_roads + 4, "Mouse drag releases a real road placement command")
	check(not valley._road_preview.visible and not valley._road_views.is_empty(), "Placed paths persist visually and clear their preview")
	var road_records: Array[GopalaEntitySnapshot] = valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.ROAD)
	if not road_records.is_empty():
		var road_record: GopalaEntitySnapshot = road_records[0]
		_complete_fixture_path(valley.simulation,road_record.entity_id)
		var upgraded_cells: Array[Vector2i] = []
		for pair in road_record.attributes.road_cells: upgraded_cells.append(Vector2i(pair[0],pair[1]))
		check(valley.simulation.apply_authorized_transaction({&"stone":upgraded_cells.size()*2,&"timber":upgraded_cells.size()}), "Renderer fixture supplies exact upgrade stock")
		valley.simulation.request_cobbled_path(upgraded_cells)
		valley.simulation.process_pending_commands()
		_complete_fixture_path(valley.simulation,road_record.entity_id)
		var upgraded_record: GopalaEntitySnapshot = valley.simulation.entity_queries().snapshot(road_record.entity_id)
		check(upgraded_record != null and upgraded_record.attributes.cobbled_cells.size() == upgraded_cells.size(), "Cobbled upgrade mutates the existing persistent road segment")
		var upgraded_view: Node3D = valley._road_views[road_record.entity_id]
		check(int(upgraded_view.get_meta("road_revision", -1)) == upgraded_record.revision, "Road view rebuilds when a segment changes quality")
		var paver_batches := upgraded_view.find_children("*", "MultiMeshInstance3D", true, false)
		check(paver_batches.size() == upgraded_cells.size(), "Cobbled cells batch pavers without one render node per stone")
		check(paver_batches.all(func(batch: MultiMeshInstance3D): return batch.multimesh.instance_count >= 1), "Cobbled paver batches retain the authored stone instances")
	valley._unhandled_input(InputEventKey.new())
	valley.hud.clear_build()
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
	# An occluded macOS test window may skip automatic redraws. Request the
	# real render explicitly so capture does not wait indefinitely.
	RenderingServer.force_draw.call_deferred()
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

func _complete_fixture_path(sim: GopalaSettlementSimulation, id: int) -> void:
	var paused_before := sim.paused
	sim.set_paused(false)
	sim.process_pending_commands()
	for tick in 1500:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(id).attributes.get("construction_state") == "COMPLETED": break
	check(sim.entity_queries().snapshot(id).attributes.get("construction_state") == "COMPLETED","Renderer path fixture completes through builders")
	sim.set_paused(paused_before)
	sim.process_pending_commands()
