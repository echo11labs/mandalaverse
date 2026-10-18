extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var valley = load("res://scenes/mvp.tscn").instantiate()
	root.mode = Window.MODE_WINDOWED
	root.add_child(valley)
	var worker: int = valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)[0].entity_id
	valley.simulation.selection_service().select_entity(worker)
	valley._inspect_selected_entity(worker)
	var captures := []
	for resolution in [Vector2i(1280,800),Vector2i(1920,1080)]:
		root.mode = Window.MODE_WINDOWED
		root.size = resolution
		for frame in 15: await process_frame
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://../reports/mvp-%dx%d.png" % [resolution.x,resolution.y])
		root.get_texture().get_image().save_png(path)
		captures.append({"size":[resolution.x,resolution.y],"capture":path,"worker_controls":valley.hud._worker_jobs.get_global_rect(),"camera_controls":valley.hud._view_tools_shell.get_global_rect(),"build_bar":valley.hud._build_bar_shell.get_global_rect()})
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920,1080)
	# Measure the rendered MVP at 4x with eight persistent workers, after warmup.
	var workers: Array[GopalaEntitySnapshot] = valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)
	for i in workers.size(): valley.simulation.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":workers[i].entity_id,"role": [&"stone",&"wild_food",&"timber",&"thatch",&"wild_food",&"fodder",&"timber",&"stone"][i]})
	valley.simulation.set_speed(4);valley.simulation.set_paused(false);valley.simulation.process_pending_commands()
	for frame in 60: await process_frame
	var samples: Array[float] = []
	var started := Time.get_ticks_usec()
	var last := started
	while Time.get_ticks_usec()-started < 10000000:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now-last)/1000.0)
		last = now
	samples.sort()
	var total := 0.0
	for sample in samples: total += sample
	var report := {"ok":true,"device":OS.get_processor_name(),"renderer":RenderingServer.get_video_adapter_name(),"resolution":[root.size.x,root.size.y],"population":workers.size(),"speed":4,"samples":samples.size(),"mean_frame_ms":total/maxi(samples.size(),1),"p95_frame_ms":samples[int(samples.size()*0.95)],"p99_frame_ms":samples[int(samples.size()*0.99)],"captures":captures,"scope":"Development render on this Mac, initial eight-worker settlement; no low-end device or exported-build performance claim."}
	var file := FileAccess.open("res://../reports/mvp-render-review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("GOPALA_TEST_REPORT="+JSON.stringify(report))
	quit()
