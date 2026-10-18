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
	camera.size = 0.16
	camera.near = 0.0005
	camera.position = Vector3(0.11,0.18,0.20)
	scene.add_child(camera)
	camera.look_at(Vector3(0,0,0.025))
	camera.current = true
	var plane := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(0.24,0.20)
	plane.mesh = plane_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("62744d")
	plane.material_override = material
	scene.add_child(plane)
	for index in 3:
		var resource: StringName = [&"wild_food",&"thatch",&"fodder"][index]
		var forage := GopalaForagePatchView.new()
		scene.add_child(forage)
		forage.build(143,43129,resource,func(_x,_z):return 0.0,Vector2.ZERO)
		forage.position = Vector3((index-1)*0.05,0,-0.035)
		check(forage.plants.size() == 9,"Forage density unchanged: " + resource)
		check(GopalaScaleStandard.within_profile(GopalaScaleStandard.bounds_in_parent(forage.get_node("MeshChild")),"forage_patch"),"Forage physical bounds: " + resource)
		forage.update_amount(1,20)
		check(forage.plants.filter(func(p):return p.visible).size() == 1,"Depletion preserved: " + resource)
		forage.update_amount(20,20)
		var definition: String = ["stockpile","timber_camp","water_point"][index]
		var building := GopalaBuildingModelView.new()
		scene.add_child(building)
		building.build(Vector3(0.04,0.025,0.04),definition)
		building.update_stage("COMPLETED",0)
		building.position = Vector3((index-1)*0.05,0,0.03)
		var bounds := building.measured_bounds
		check(bounds.size.x <= 0.0401 and bounds.size.z <= 0.0401 and bounds.size.y <= 0.0251,"Building remains inside physical footprint: " + definition)
		check(absf(bounds.position.y) < 0.00001,"Building retains ground anchor: " + definition)
	var stones := GopalaStonePatchView.new()
	scene.add_child(stones)
	stones.build(88,func(_x,_z):return 0.0,Vector2.ZERO)
	stones.position = Vector3(0.07,0,-0.005)
	check(stones.pieces.size() == 11,"Stone density unchanged")
	var overlay := CanvasLayer.new()
	scene.add_child(overlay)
	var title := Label.new()
	title.text = "RESOURCE LIBRARY · " + stage.to_upper() + "\nBerry bushes · Thatch · Fodder\nStorage · Timber camp · Water point"
	title.position = Vector2(32,24)
	title.add_theme_font_size_override("font_size",22)
	overlay.add_child(title)
	for frame in 6: await process_frame
	RenderingServer.force_draw.call_deferred()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../reports/resource-refresh/%s.png" % stage) == OK,"Actual view capture")
	if stage == "after":
		scene.free()
		var valley = load("res://scenes/mvp.tscn").instantiate()
		root.add_child(valley)
		valley.simulation.set_physics_process(false)
		var balances: Dictionary = valley.simulation.snapshot().resource_balances.duplicate(true)
		for frame in 6: await process_frame
		RenderingServer.force_draw.call_deferred()
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://../reports/resource-refresh/settlement.png") == OK,"Actual MVP capture")
		check(valley.simulation.snapshot().resource_balances == balances,"Asset presentation preserves actual settlement inventory")
		valley.free()
	else:
		scene.free()
	var receipt := {"ok":failures.is_empty(),"checks":checks,"failures":failures}
	FileAccess.open("res://../reports/resource-refresh/%s-checks.json" % stage,FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	print("GOPALA_TEST_REPORT=",JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
