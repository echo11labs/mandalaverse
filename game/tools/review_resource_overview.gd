extends SceneTree
## Render receipt for the actual paused MVP, never substituted gameplay data.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		root.content_scale_size = resolution
		var valley = load("res://scenes/mvp.tscn").instantiate()
		root.add_child(valley)
		for frame in 40:
			await process_frame
		valley.hud.show_resource_overview(&"timber")
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		print("RESOURCE_LAYOUT=", JSON.stringify({"size": str(valley.hud._resource_overview.size), "position": str(valley.hud._resource_overview.position), "content_scale": str(valley.hud._resource_overview.content_scale_size), "detail": str(valley.hud._resource_overview._detail.get_global_rect()), "viewport": str(root.get_visible_rect())}))
		var overview: Window = valley.hud._resource_overview
		if overview.position.y < 0 or overview.position.y + overview.size.y > resolution.y:
			push_error("Rendered resource window exceeds viewport")
			quit(1)
			return
		var path := "res://../reports/hud-research/resources-%dx%d.png" % [resolution.x, resolution.y]
		var error := root.get_texture().get_image().save_png(path)
		print("RESOURCE_CAPTURE=", JSON.stringify({"resolution": str(resolution), "path": path, "save_error": error}))
		root.remove_child(valley)
		valley.free()
	quit()
