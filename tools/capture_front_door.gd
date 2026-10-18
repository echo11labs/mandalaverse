extends SceneTree
func _initialize(): run.call_deferred()
func capture(game, page: String) -> void:
	game.open_menu(page)
	for i in 3: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://../reports/manual/front-door-"+page+"-1280x800.png")
func run():
	root.size = Vector2i(1280,800)
	root.content_scale_size = Vector2i(1280,800)
	root.always_on_top = true
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game := GopalaFrontDoor.new()
	game.settings.storage_path = "user://tests/front-door-capture.cfg"
	game.slots.directory = "user://tests/front-door-capture-saves"
	root.add_child(game)
	await capture(game,"main")
	game.start_new()
	await capture(game,"pause")
	await capture(game,"settings")
	game.settings.set_value("ui_scale",1.5)
	await capture(game,"settings")
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://../reports/manual/front-door-scale150-1280x800.png")
	game.settings.set_value("ui_scale",1.0)
	await capture(game,"settings")
	game.queue_free()
	await process_frame
	quit()
