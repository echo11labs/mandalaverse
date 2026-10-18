extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		var valley = load("res://scenes/mvp.tscn").instantiate()
		root.mode = Window.MODE_WINDOWED
		root.size = resolution
		root.add_child(valley)
		for frame in 18:
			await process_frame
		valley.hud.set_alerts([])
		valley.hud._status_shell.visible = false
		valley.hud._minimap_shell.visible = false
		valley.hud._view_tools_shell.visible = false
		valley.hud._build_bar_shell.visible = true
		valley.hud._build_toggle.visible = true
		valley.hud._build_toggle.text = "×"
		valley.hud._refresh_build_toggle()
		await process_frame
		await RenderingServer.frame_post_draw
		_save_capture("/tmp/gopala-picker-%dx%d.png" % [resolution.x, resolution.y], valley, resolution)
		root.remove_child(valley)
		valley.free()
	quit()

func _save_capture(path: String, valley: Node, resolution: Vector2i) -> void:
	root.get_texture().get_image().save_png(path)
	print("PICKER_CAPTURE ", resolution, " saved=", path,
		" viewport=", root.size,
		" panel=", valley.hud._build_bar_shell.get_global_rect(),
		" category_grid=", valley.hud._category_grid.get_global_rect(),
		" structure_grid=", valley.hud._structure_grid.get_global_rect(),
		" build_card=", valley.hud._build_card.get_global_rect(),
		" title=", valley.hud._build_title.get_global_rect(), " / ", valley.hud._build_title.text,
		" meta=", valley.hud._build_meta.get_global_rect(), " / ", valley.hud._build_meta.text,
		" costs=", valley.hud._build_costs.get_global_rect())
