extends SceneTree
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1600,1000)
	root.content_scale_size = root.size
	var stage := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("25322c")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c3d0bd")
	settings.ambient_light_energy = 0.6
	environment.environment = settings
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-65,-35,0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	scene.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.20
	camera.near = 0.0005
	camera.position = Vector3(0.11,0.18,0.20)
	scene.add_child(camera)
	camera.look_at(Vector3(0,0,0.02))
	camera.current = true
	var plane := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(0.24,0.20)
	plane.mesh = plane_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("62744d")
	plane.material_override = material
	scene.add_child(plane)
	var definitions := ["dwelling","stockpile","timber_camp","gatherer_shelter","water_point","cattle_shelter"]
	for index in 6:
		var definition: String = definitions[index]
		var building := GopalaBuildingModelView.new()
		scene.add_child(building)
		building.build(Vector3(0.04,GopalaScaleStandard.number("building","height"),0.04),definition,index,0)
		building.update_stage("COMPLETED",0)
		var at := Vector3((index%3-1)*0.055,0,(floori(float(index)/3.0)-0.5)*0.065)
		building.position = at
		var bounds := building.measured_bounds
		check(bounds.size.x <= 0.0401 and bounds.size.z <= 0.0401 and bounds.size.y <= 0.0401,"Building fit: " + definition)
		check(absf(bounds.position.y) < 0.00001,"Building ground anchor: " + definition)
		var label := Label3D.new()
		label.text = definition.replace("_"," ").capitalize()
		label.font_size = 40
		label.pixel_size = 0.00005
		label.no_depth_test = true
		label.position = at + Vector3(0,0.045,0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		scene.add_child(label)
	for seed in 6:
		var worker := GopalaWorkerModelView.new()
		scene.add_child(worker)
		worker.build(seed)
		worker.position = Vector3((float(seed)-2.5)*0.021,0,0.084)
		check(is_equal_approx(worker.measured_bounds.size.y,0.0175),"Settler retains physical height")
	var overlay := CanvasLayer.new()
	scene.add_child(overlay)
	var title := Label.new()
	title.text = "BUILDING LIBRARY · SIX FACILITIES / SIX SETTLER VARIANTS"
	title.position = Vector2(32,24)
	title.add_theme_font_size_override("font_size",22)
	overlay.add_child(title)
	for frame in 6: await process_frame
	RenderingServer.force_draw.call_deferred()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../reports/building-refresh/%s.png" % stage) == OK,"Actual view capture")
	if stage == "after":
		scene.free()
		var valley = load("res://scenes/mvp.tscn").instantiate()
		root.add_child(valley)
		valley.simulation.set_physics_process(false)
		# Use actual construction, hauling and labor to demonstrate a new home.
		valley.simulation.request_construction(&"dwelling",Vector2i(7,-6))
		valley.simulation.process_pending_commands()
		var homes: Array = valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING).filter(func(b): return b.attributes.get("definition_id") == &"dwelling")
		check(homes.size() == 1,"Actual MVP plans a legal demonstration home")
		if not homes.is_empty():
			var worker: int = valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)[0].entity_id
			valley.simulation.submit_command(GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER,{"villager_id":worker,"blueprint_id":homes[0].entity_id})
			valley.simulation.set_paused(false)
			valley.simulation.process_pending_commands()
			for tick in 1500:
				valley.simulation.advance_ticks(1)
				if valley.simulation.entity_queries().snapshot(homes[0].entity_id).attributes.get("construction_state") == "COMPLETED": break
			check(valley.simulation.entity_queries().snapshot(homes[0].entity_id).attributes.get("construction_state") == "COMPLETED","Actual builder delivers and completes the new home")
			valley.simulation.advance_ticks(2)
			valley.simulation.set_paused(true)
			valley.simulation.process_pending_commands()
			valley.focus_camp()
		var balances: Dictionary = valley.simulation.snapshot().resource_balances.duplicate(true)
		for frame in 6: await process_frame
		RenderingServer.force_draw.call_deferred()
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://../reports/building-refresh/settlement.png") == OK,"Actual MVP capture")
		check(valley.simulation.snapshot().resource_balances == balances,"Asset presentation preserves actual settlement inventory")
		valley.free()
	else:
		scene.free()
	var receipt := {"ok":failures.is_empty(),"checks":checks,"failures":failures}
	FileAccess.open("res://../reports/building-refresh/%s-checks.json" % stage,FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	print("GOPALA_TEST_REPORT=",JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
