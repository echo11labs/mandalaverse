extends SceneTree
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func run() -> void:
	var valley = load("res://scenes/mvp.tscn").instantiate()
	root.add_child(valley)
	valley.simulation.set_physics_process(false)
	valley.camera.input_blocked = true
	valley.set_process_unhandled_input(false)
	for frame in 5: await process_frame
	var panel: GopalaWorkforcePanel = valley.hud._workforce_panel
	check(panel != null and not panel.visible,"Workers panel begins closed")
	valley.hud.show_workforce_panel()
	check(panel.visible,"Workers entry point opens management window")
	panel._enabled.button_pressed = true
	check(valley.simulation._workforce_service.policy().enabled,"Enable control submits validated policy")
	panel._rows.stone.target.value = 2
	check(valley.simulation._workforce_service.policy().jobs.stone.target == 2,"Staffing control changes authoritative target")
	panel._rows.stone.priority.select(3)
	panel._rows.stone.priority.item_selected.emit(3)
	check(valley.simulation._workforce_service.policy().jobs.stone.priority == 3,"Priority control changes authoritative policy")
	valley.simulation.set_paused(false);valley.simulation.process_pending_commands()
	valley.simulation.advance_ticks(40)
	valley.simulation.set_paused(true);valley.simulation.process_pending_commands()
	panel.refresh()
	check(panel._workers.size() == 8,"Roster includes every actual MVP settler")
	var first: int = panel._workers.keys()[0]
	panel._workers[first].auto.button_pressed = false
	check(valley.simulation.entity_queries().snapshot(first).attributes.workforce_excluded,"Roster can return an automatic worker to manual ownership")
	panel._workers[first].auto.button_pressed = true
	check(valley.simulation.entity_queries().snapshot(first).attributes.workforce_managed,"Roster can re-enrol a worker without losing cargo")
	var balances: Dictionary = valley.simulation.snapshot().resource_balances.duplicate(true)
	for resolution in [Vector2i(1280,800),Vector2i(1920,1080)]:
		root.size = resolution
		root.content_scale_size = resolution
		panel.popup_centered_clamped(Vector2i(880,720),0.9)
		for frame in 6: await process_frame
		check(panel.size.x <= resolution.x and panel.size.y <= resolution.y,"Management window fits viewport")
		check(panel._rows.milk.status.is_visible_in_tree(),"All job rows remain visible")
		RenderingServer.force_draw.call_deferred()
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://../reports/workforce/panel-%dx%d.png" % [resolution.x,resolution.y]) == OK,"Capture management panel")
	check(valley.simulation.snapshot().resource_balances == balances,"Panel refresh and controls never alter inventory")
	panel.close_requested.emit()
	check(not panel.visible,"Window close works")
	valley.simulation.advance_ticks(1)
	check(not panel.visible,"Simulation updates do not reopen workforce window")
	valley.hud.show_workforce_panel()
	panel._workers[first].root.get_child(0).pressed.emit()
	check(not panel.visible and valley.simulation.selection_service().snapshot().selected_entity_id == first,"Roster name opens the selected settler inspector")
	var shortcut := InputEventKey.new()
	shortcut.physical_keycode = KEY_J
	shortcut.pressed = true
	valley.hud._shortcut_input(shortcut)
	check(panel.visible,"J shortcut opens workforce window")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	panel.window_input.emit(event)
	check(not panel.visible,"Escape closes workforce panel")
	var old: GopalaSettlementSimulation = valley.simulation
	var codec := GopalaSettlementSave.new()
	var restored := codec.restore(codec.capture(old,{}),old,{})
	check(restored != null,"Actual MVP workforce state validates for restoration")
	if restored != null:
		panel.bind_simulation(restored)
		check(panel.simulation == restored and restored.snapshot_committed.is_connected(panel._on_snapshot),"Panel rebinds to restored simulation")
		restored.free()
	valley.free()
	var receipt := {"ok":failures.is_empty(),"checks":checks,"failures":failures}
	FileAccess.open("res://../reports/workforce/render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	print("GOPALA_TEST_REPORT=",JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
