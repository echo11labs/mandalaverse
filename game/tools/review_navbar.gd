extends SceneTree
## Real-renderer navbar checks, including narrow screens and long runtime values.
var failures: Array[String] = []
var checks := 0

class ClickProbe extends Node:
	var count := 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: count += 1

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var hud := load("res://scenes/ui/hud.tscn").instantiate() as GopalaKathmanduHud
	root.add_child(hud)
	var probe := ClickProbe.new()
	root.add_child(probe)
	var menu_requests: Array = []
	var saves: Array = []
	var loads: Array = []
	hud.pause_requested.connect(func(): menu_requests.append(true))
	hud.save_requested.connect(func(): saves.append(true))
	hud.load_requested.connect(func(): loads.append(true))
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(3840, 2160)]:
		root.size = resolution
		root.content_scale_size = resolution
		for stress in [false, true]:
			hud.set_settlement_name("Dudhkunda — upper valley settlement with a very long name" if stress else "Dudhkunda")
			hud.set_tempo(true, 1)
			hud.set_simulation_tick(2147483647 if stress else 0)
			for id in hud._resource_slots:
				hud.set_resource(id, 2147483647 if stress else 100)
			for frame in 12: await process_frame
			var bounds := Rect2(Vector2.ZERO, Vector2(resolution.x, 52))
			check(is_equal_approx(hud._navbar.size.y, 52), "Navbar preserves 52px height")
			check(is_equal_approx(hud._nav_brand.get_global_rect().position.x, 12), "Settlement identity aligns to left margin")
			check(is_equal_approx(hud._nav_resources.get_global_rect().get_center().x, resolution.x * 0.5), "Resources are centered")
			check(is_equal_approx(hud._nav_actions.get_global_rect().end.x, resolution.x - 12), "Actions align to right margin")
			check(not hud._nav_brand.get_global_rect().intersects(hud._nav_resources.get_global_rect()), "Identity clears resources")
			check(not hud._nav_resources.get_global_rect().intersects(hud._nav_actions.get_global_rect()), "Resources clear actions")
			for region in [hud._nav_brand, hud._nav_resources, hud._nav_actions]:
				check(bounds.encloses(region.get_global_rect()), "Navbar cluster fits " + str(resolution))
			for name in ["NavbarSave", "NavbarLoad", "NavbarMenu"]:
				var button := hud._root.find_child(name, true, false) as Button
				check(button != null and button.icon != null and button.size == Vector2(32,32), "Action has recognizable icon and uniform 32px hit target")
			if stress:
				check(hud._resource_buttons[&"timber"].tooltip_text.contains("2147483647"), "Compact stock retains exact tooltip quantity")
			await RenderingServer.frame_post_draw
			var path := "res://../reports/navbar/navbar-%d-%s.png" % [resolution.x, "stress" if stress else "normal"]
			check(root.get_texture().get_image().get_region(Rect2i(0,0,resolution.x,52)).save_png(path) == OK, "Navbar capture saved")
	for name in ["NavbarSave", "NavbarLoad", "NavbarMenu"]:
		var button := hud._root.find_child(name, true, false) as Button
		click(button.get_global_rect().get_center(), true)
		click(button.get_global_rect().get_center(), false)
		await process_frame
	check(saves.size() == 1 and loads.size() == 1 and menu_requests.size() == 1, "Mouse clicks dispatch one matching request per navbar action")
	check(probe.count == 0, "Navbar actions do not leak into world input")
	click(Vector2(20,45),true)
	click(Vector2(20,45),false)
	await process_frame
	check(probe.count == 0, "Navbar background blocks world clicks")
	root.remove_child(hud)
	hud.free()
	probe.queue_free()
	root.size = Vector2i(1920,1080)
	root.content_scale_size = Vector2i(1920,1080)
	var valley = load("res://scenes/mvp.tscn").instantiate()
	root.add_child(valley)
	for frame in 30: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../reports/navbar/gameplay-1920.png") == OK, "Capture actual MVP with its real stock values")
	root.remove_child(valley)
	valley.free()
	var receipt := {"ok":failures.is_empty(),"checks":checks,"failures":failures}
	var file := FileAccess.open("res://../reports/navbar/navbar-checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"\t"))
	print("GOPALA_TEST_REPORT=",JSON.stringify(receipt))
	await process_frame
	quit(0 if failures.is_empty() else 1)

func click(point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	root.push_input(event, true)
