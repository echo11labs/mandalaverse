extends SceneTree
const Fixture = preload("res://bench/fixture.gd")
var options := {}
var errors: Array[String] = []
func _initialize(): run.call_deferred()
func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {"count":0,"median":0.0,"p95":0.0,"max":0.0}
	var ordered := values.duplicate()
	ordered.sort()
	return {"count":ordered.size(),"median":ordered[ordered.size()/2],"p95":ordered[mini(ordered.size()-1,ceili(ordered.size()*0.95)-1)],"max":ordered[-1]}
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.contains("="): options[arg.get_slice("=",0).trim_prefix("--")] = arg.get_slice("=",1)
	var smoke: bool = options.get("smoke","false") == "true"
	var width := int(options.get("width","1280"))
	var height := int(options.get("height","800"))
	root.size = Vector2i(width,height)
	root.content_scale_size = Vector2i(width,height)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if options.get("vsync","off") == "on" else DisplayServer.VSYNC_DISABLED)
	var valley = load("res://scenes/mvp.tscn").instantiate()
	root.add_child(valley)
	var fixture := Fixture.setup(valley,smoke)
	var sim: GopalaSettlementSimulation = valley.simulation
	var tick_rate := float(sim.speed) / sim.tick_interval_seconds()
	var warmup := float(options.get("warmup","30"))
	var duration := float(options.get("duration","120"))
	var tick_samples: Array = []
	var frame_samples: Array = []
	var draw_samples: Array = []
	var instance_samples: Array = []
	var memory_samples: Array = []
	var backlog_samples: Array = []
	var activity_windows: Array = []
	var window_min := 40
	var all_min := 40
	var window_index := -1
	var frame_time := Time.get_ticks_usec()
	var start := frame_time
	var next_tick := 0.0
	var capture_files: Array = []
	var camera_points: Array = []
	root.title = "GOPALA benchmark runtime"
	if not smoke:
		root.always_on_top = true
		DisplayServer.window_move_to_foreground()
		for view_name in ["camp", "pasture"]:
			if view_name == "pasture":
				var pasture = sim._herd_service.pastures()[0]
				var point := Vector3(float(pasture.attributes.position_x),0.0,float(pasture.attributes.position_z))
				point.y = valley.ground_height_at(point.x,point.z)
				valley.camera.focus_point(point,0.8)
			await RenderingServer.frame_post_draw
			var path: String = options.get("output","user://benchmark.json").get_basename()+"-"+view_name+".png"
			if root.get_texture().get_image().save_png(path) != OK: errors.append("Capture failed")
			capture_files.append(path)
			camera_points.append({"view":view_name,"target":str(valley.camera.target),"span":valley.camera.size,"yaw":valley.camera.yaw,"pitch":valley.camera.pitch})
		valley.focus_camp()
	start = Time.get_ticks_usec()
	var render_state := {"collect":false,"last":0}
	var on_draw := func():
		var rendered := Time.get_ticks_usec()
		if render_state.collect:
			if render_state.last > 0: frame_samples.append(float(rendered-render_state.last)/1000.0)
			draw_samples.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			instance_samples.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			memory_samples.append(Performance.get_monitor(Performance.MEMORY_STATIC))
		render_state.last = rendered
	RenderingServer.frame_post_draw.connect(on_draw)
	var second_view := false
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := float(now-start)/1000000.0
		var collecting := elapsed >= warmup
		if elapsed >= warmup+duration: break
		if collecting and not render_state.collect:
			render_state.last = 0
		render_state.collect = true if collecting and not smoke else false
		if collecting and not second_view and elapsed-warmup >= duration*0.5:
			var pasture = sim._herd_service.pastures()[0]
			var point := Vector3(float(pasture.attributes.position_x),0.0,float(pasture.attributes.position_z))
			point.y = valley.ground_height_at(point.x,point.z)
			valley.camera.focus_point(point,0.8)
			second_view = true
		# G1-12: at most one due tick per frame; overdue work remains scheduled.
		if elapsed >= next_tick:
			var tick_start := Time.get_ticks_usec()
			var tick_elapsed := float(tick_start-start)/1000000.0
			var tick_collecting := tick_elapsed >= warmup
			if not sim.advance_ticks(1): errors.append("Tick rejected")
			var cost := float(Time.get_ticks_usec()-tick_start)/1000.0
			if tick_collecting: tick_samples.append(cost)
			next_tick += 1.0/tick_rate
			var activity := Fixture.activity(sim)
			if tick_collecting:
				var index := int((tick_elapsed-warmup)/10.0)
				if index != window_index:
					if window_index >= 0: activity_windows.append({"window":window_index,"minimum_active":window_min})
					window_index = index
					print("BENCH_WINDOW=",index," tick=",sim.logical_tick," active=",activity.active)
					window_min = 40
				window_min = mini(window_min,activity.active)
				all_min = mini(all_min,activity.active)
			if tick_collecting:
				var after_tick := minf(float(Time.get_ticks_usec()-start)/1000000.0,warmup+duration-0.000001)
				backlog_samples.append(maxi(0,floori((after_tick-next_tick)*tick_rate)+1))
			if smoke and sim.logical_tick >= 8: break
	RenderingServer.frame_post_draw.disconnect(on_draw)

	if window_index >= 0: activity_windows.append({"window":window_index,"minimum_active":window_min})
	var actual_elapsed := float(Time.get_ticks_usec()-start)/1000000.0
	var workload_valid: bool = fixture.workers == 40 and fixture.cattle == 2 and (smoke or all_min >= 36)
	var final_backlog := maxi(0,floori((minf(actual_elapsed,warmup+duration-0.000001)-next_tick)*tick_rate)+1)
	var rate_sustained: bool = smoke or (tick_samples.size() >= int(duration*tick_rate)-2 and final_backlog <= 1)
	if not smoke and (DisplayServer.get_name() == "headless" or frame_samples.is_empty()): errors.append("No real renderer samples")
	var report := {"schema":1,"smoke":smoke,"ok":errors.is_empty(),"valid":workload_valid and errors.is_empty(),"workload_valid":workload_valid,"tick_rate_sustained":rate_sustained,"sampled_tick_count":tick_samples.size(),"requested_tick_rate":tick_rate,"actual_sampled_tick_rate":float(tick_samples.size())/duration,"pending_tick_backlog":final_backlog,"pending_tick_backlog_stats":stats(backlog_samples),"driver":"At most one unchanged tick call per process frame; overdue ticks remain scheduled","failures":errors,"fixture":fixture,"tick_rate":tick_rate,"logical_ticks":sim.logical_tick,"warmup_seconds":warmup,"collection_seconds":duration,"elapsed_seconds":actual_elapsed,"frame_ms":stats(frame_samples) if smoke or not frame_samples.is_empty() else null,"tick_ms":stats(tick_samples),"draw_calls":stats(draw_samples),"rendered_instances":stats(instance_samples),"static_memory_bytes":stats(memory_samples),"minimum_active":all_min,"activity_windows":activity_windows,"activity_definition":"Live collection/build task or carried goods or job movement; excludes NEED trips and mere assigned roles. Window minimum is strict per sampled tick.","captures":capture_files,"camera_points":camera_points,"world_seed":valley.resolved_world_seed,"godot":Engine.get_version_info(),"display_driver":DisplayServer.get_name(),"screen_size":str(DisplayServer.screen_get_size()),"screen_refresh_rate":DisplayServer.screen_get_refresh_rate(),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"resolution":[width,height],"vsync_requested":options.get("vsync","off"),"vsync_actual":DisplayServer.window_get_vsync_mode()}
	var file := FileAccess.open(options.get("output","user://benchmark.json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t"))
	else: errors.append("Report write failed")
	valley.queue_free()
	await process_frame
	print("GOPALA_TEST_REPORT="+JSON.stringify({"ok":errors.is_empty() and fixture.workers == 40 and fixture.cattle == 2,"checks":4,"failures":errors}))
	quit(0 if errors.is_empty() else 1)
