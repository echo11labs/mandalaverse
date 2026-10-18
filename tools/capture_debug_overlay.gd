extends SceneTree
func _initialize(): run.call_deferred()
func capture(name: String) -> void:
	for i in 3: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://../reports/manual/debug-"+name+"-1280x800.png")
func run():
	root.size = Vector2i(1280,800)
	root.content_scale_size = Vector2i(1280,800)
	root.always_on_top = true
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var world = load("res://scenes/mvp.tscn").instantiate()
	root.add_child(world)
	world.simulation.set_physics_process(false)
	world.camera.set_process(false)
	world.camera.set_process_unhandled_input(false)
	var sim: GopalaSettlementSimulation = world.simulation
	var worker := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)[0]
	var point := Vector2(worker.attributes.position_x,worker.attributes.position_z)
	sim.villager_service().assign_move_task(worker.entity_id,point+Vector2(0.12,0.08))
	sim.selection_service().select_entity(worker.entity_id)
	sim.set_paused(false)
	sim.process_pending_commands()
	sim.advance_ticks(2)
	sim.set_paused(true)
	sim.process_pending_commands()
	world.debug_overlay.toggle()
	world.debug_overlay.refresh()
	world.focus_camp()
	await capture("villager")
	var store := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING)[0]
	sim.selection_service().select_entity(store.entity_id)
	world.debug_overlay.refresh()
	await capture("store")
	world.queue_free()
	await process_frame
	quit()
