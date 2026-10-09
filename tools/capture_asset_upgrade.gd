extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var options := {}
	for arg in OS.get_cmdline_user_args():
		if arg.contains("="): options[arg.get_slice("=",0)] = arg.get_slice("=",1)
	root.size = Vector2i(int(options.get("--width","1280")),int(options.get("--height","800")))
	root.content_scale_size = root.size
	root.always_on_top = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var valley = load("res://scenes/mvp.tscn").instantiate()
	root.add_child(valley)
	valley.simulation.set_physics_process(false)
	for i in 2: await process_frame # Let startup focus finish before fixed camera probes.
	valley.camera.set_process(false)
	valley.camera.set_process_unhandled_input(false)
	valley.set_process_unhandled_input(false)
	var views := ["camp","cattle","source","forest"]
	if options.get("--gallery","") == "true": views.append("buildings")
	for view in views:
		if view == "camp":
			valley.focus_camp()
			valley.camera.focus_point(valley.camera.target,0.336) # Match the recorded before probe.
		elif view == "cattle":
			var cow = valley.simulation._herd_service.animals()[0]
			var p := Vector3(cow.attributes.position_x,0,cow.attributes.position_z)
			p.y = valley.ground_height_at(p.x,p.z)
			valley.camera.focus_point(p,GopalaScaleStandard.number("camera","inspection_span"))
		elif view == "source": valley.focus_source()
		elif view == "buildings":
			var center := Vector3(-74.35,0,12.5)
			var definitions := ["dwelling","gatherer_shelter","water_point","cattle_shelter","timber_camp","stockpile"]
			for i in definitions.size():
				var source = load("res://data/buildings/%s.tres" % definitions[i])
				var model := GopalaBuildingModelView.new()
				valley.add_child(model)
				var height := GopalaScaleStandard.number("building","height")
				var cell := GopalaScaleStandard.metres_to_world(2.0)
				model.build(Vector3(source.footprint.x*cell,height,source.footprint.y*cell),definitions[i])
				model.frame.visible = false
				var point := center+Vector3((i%3-1)*0.07,0,(i/3)*0.07)
				point.y = valley.ground_height_at(point.x,point.z)
				model.position = point
			center.y = valley.ground_height_at(center.x,center.z)
			valley.camera.focus_point(center+Vector3(0,0,0.035),0.24)
			root.title = "GOPALA presentation-only building gallery"
		else: valley.camera.focus_point(Vector3(10,valley.ground_height_at(10,-85),-85),3.0)
		for i in 4: await process_frame
		RenderingServer.force_draw() # Screenshot-only readback; never a benchmark sample.
		var path: String = options["--output"]+"-"+view+".png"
		if root.get_texture().get_image().save_png(path) != OK: quit(1); return
		print("ASSET_CAPTURE="+JSON.stringify({"path":path,"target":str(valley.camera.target),"span":valley.camera.size,"resolution":str(root.size)}))
		await process_frame
	valley.free()
	await process_frame
	quit()
