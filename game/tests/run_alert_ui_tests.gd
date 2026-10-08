extends SceneTree
var checks := 0
var failures: Array[String] = []
func _initialize(): run.call_deferred()
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label); push_error(label)
func run():
	root.size = Vector2i(1280,800)
	root.content_scale_size = Vector2i(1280,800)
	if "--capture-alerts" in OS.get_cmdline_user_args():
		root.title = "GOPALA alert acceptance capture"
		root.always_on_top = true
		DisplayServer.window_move_to_foreground()
	var valley = load("res://scenes/mvp.tscn").instantiate()
	root.add_child(valley)
	valley.simulation.set_physics_process(false)
	await process_frame
	var hud: GopalaKathmanduHud = valley.hud
	var alerts: GopalaAlertService = valley._alerts_service
	check(alerts.rows().size() >= 2,"Actual paused MVP shows housing and idle alerts")
	check(hud._alert_panel.mouse_filter == Control.MOUSE_FILTER_STOP,"Alert panel consumes input")
	var button: Button = hud._alert_buttons["homeless"]
	check(button.mouse_filter == Control.MOUSE_FILTER_STOP and button.text.contains("Warning") and button.text.contains("△"),"Severity uses glyph and text with STOP input")
	var identity := button.get_instance_id()
	hud.set_alerts(alerts.rows())
	check(hud._alert_buttons["homeless"].get_instance_id() == identity,"Unchanged rows preserve controls and focus")
	if "--capture-alerts" in OS.get_cmdline_user_args():
		valley.focus_camp()
		for i in 3: await RenderingServer.frame_post_draw
		var path := "res://../reports/manual/alerts-1280x800.png"
		check(root.get_texture().get_image().save_png(path) == OK,"Write actual 1280x800 alert screenshot")
	var payload := alerts.focus_payload("homeless")
	button.pressed.emit()
	check(valley.simulation.selection_service().selected_entity_id == payload.entity_id,"Click selects the exact authoritative subject")
	check(is_equal_approx(valley.camera.target.x,payload.position_x) and is_equal_approx(valley.camera.target.z,payload.position_z),"Click moves actual camera to alert subject")
	var worker = valley.simulation.entity_queries().snapshot(payload.entity_id)
	valley.simulation._survival_service.update(worker.entity_id,{&"health":49},valley.simulation.logical_tick)
	alerts.refresh()
	check(hud._alert_buttons.has("health:%d" % worker.entity_id),"New condition inserts a row")
	check(hud._alert_buttons["homeless"].get_instance_id() == identity,"Adding a condition does not rebuild other rows")
	valley.simulation.entity_registry().remove_entity(worker.entity_id,GopalaEntityRegistry.RemovalPolicy.CLEAR_INCOMING_REFERENCES,valley.simulation.logical_tick)
	check(not valley.focus_alert("health:%d" % worker.entity_id),"Gone subject does not select or jump camera")
	alerts.refresh()
	check(not hud._alert_buttons.has("health:%d" % worker.entity_id),"Resolved/deleted subject removes the UI row")
	valley.queue_free()
	await process_frame
	print("GOPALA_TEST_REPORT="+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
