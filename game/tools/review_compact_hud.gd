extends SceneTree
## Captures the actual MVP and checks HUD footprint and region intersections.
var failures: Array[String] = []
var checks := 0
var measurements: Array = []
class WorldClickProbe extends Node:
	var clicks := 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: clicks += 1

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		root.size = resolution
		root.content_scale_size = resolution
		var valley = load("res://scenes/mvp.tscn").instantiate()
		root.add_child(valley)
		var probe := WorldClickProbe.new()
		root.add_child(probe)
		for frame in 30: await process_frame
		var hud: GopalaKathmanduHud = valley.hud
		check(not hud._build_bar_shell.visible and not hud._status_shell.visible and not hud._survival_panel.visible, "Startup leaves detailed panels closed " + str(resolution))
		var area: float = 52.0 * resolution.x + hud._summary_strip.size.x * hud._summary_strip.size.y + hud._view_tools_shell.size.x * hud._view_tools_shell.size.y + hud._alert_panel.size.x * hud._alert_panel.size.y
		var fraction: float = area / (float(resolution.x) * resolution.y)
		check(fraction < 0.18, "Default HUD covers less than 18% of screen " + str(resolution))
		measurements.append({"resolution":str(resolution), "default_hud_fraction":fraction})
		await capture(hud, resolution, "default")
		hud.toggle_build_picker()
		for frame in 8: await process_frame
		print("BUILD_LAYOUT=", hud._build_bar_shell.get_global_rect(), " min=", hud._build_bar_shell.get_combined_minimum_size(), " anchors=",hud._build_bar_shell.anchor_bottom)
		check(hud._build_bar_shell.visible, "Build opens from dock")
		check(hud._build_meta.get_global_rect().end.x <= hud._build_bar_shell.get_global_rect().end.x, "Build description stays inside panel")
		var scroll := hud._root.find_child("StructureScroll", true, false) as ScrollContainer
		check(scroll.size.y >= 200, "Construction has usable vertical scroll space")
		check(hud._structure_grid.get_combined_minimum_size().x <= scroll.size.x, "All structure columns fit horizontally")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = hud._build_bar_shell.get_global_rect().end - Vector2(20, 20)
		root.push_input(click)
		await process_frame
		check(probe.clicks == 0, "Construction panel background blocks world commands")
		click.pressed = false
		root.push_input(click)
		await capture(hud, resolution, "build")
		var workers: Array = valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)
		valley._inspect_selected_entity(workers[0].entity_id)
		for frame in 8: await process_frame
		check(not hud._build_bar_shell.visible and hud._inspection.get_parent().visible, "Inspection replaces construction")
		await capture(hud, resolution, "inspection")
		hud.hide_inspection()
		hud.toggle_settlement_panel()
		hud._alerts_section.set_collapsed(false)
		for frame in 8: await process_frame
		check(not hud._survival_panel.get_global_rect().intersects(hud._alert_panel.get_global_rect()), "Settlement and expanded alerts do not overlap")
		await capture(hud, resolution, "settlement-alerts")
		hud.notify("HUD check", "Notification layout validation")
		hud.notify("HUD check", "Notification layout validation")
		for frame in 4: await process_frame
		check(hud._notification_stack._active.size() == 1, "Repeated notifications are deduplicated")
		check(hud._notification_stack._active[0].get_node("MarginContainer/MessageLabel").text.contains("HUD check"), "Notifications render their actual message")
		check(bounds_for(resolution).encloses(hud._notification_stack.get_global_rect()), "Notification stack fits viewport")
		await capture(hud, resolution, "notification")
		probe.queue_free()
		root.remove_child(valley)
		valley.free()
	var receipt := {"ok": failures.is_empty(), "checks":checks, "failures":failures,"measurements":measurements}
	var file := FileAccess.open("res://../reports/hud-layout/layout-checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "\t"))
	print("GOPALA_TEST_REPORT=", JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)

func bounds_for(resolution: Vector2i) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(resolution))

func capture(hud: GopalaKathmanduHud, resolution: Vector2i, state: String) -> void:
	await RenderingServer.frame_post_draw
	var panels: Array[Control] = [hud._view_tools_shell, hud._build_bar_shell, hud._inspection.get_parent(), hud._status_shell, hud._survival_panel, hud._alert_panel]
	var bounds := Rect2(Vector2.ZERO, Vector2(resolution))
	for panel in panels:
		if panel.visible:
			check(bounds.encloses(panel.get_global_rect()), "Visible region fits viewport: " + panel.name + " " + state)
	var dock := hud._view_tools_shell.get_global_rect()
	for panel in panels.slice(1):
		if panel.visible:
			check(not dock.intersects(panel.get_global_rect()), "Panel clears command dock: " + panel.name)
	var path := "res://../reports/hud-layout/%s-%dx%d.png" % [state,resolution.x,resolution.y]
	check(root.get_texture().get_image().save_png(path) == OK, "Capture " + state)
