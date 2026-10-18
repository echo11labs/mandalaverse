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
	for index in 20:
		var source_path := "res://assets/models/local_buildings/house_%02d.glb" % (index+1)
		var model: Node3D = (load(source_path) as PackedScene).instantiate()
		scene.add_child(model)
		GopalaScaleStandard.normalize_height(model,0.025)
		model.position += Vector3((index%5-2)*0.04,0,(floori(float(index)/5.0)-1.5)*0.035)
		var label := Label3D.new()
		label.text = "%02d" % (index+1)
		label.font_size = 64
		label.pixel_size = 0.00008
		label.position = model.position + Vector3(0,0.026,0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		scene.add_child(label)
	var overlay := CanvasLayer.new()
	scene.add_child(overlay)
	var title := Label.new()
	title.text = "SUPPLIED HOUSE MODELS · VISUAL CATALOG"
	title.position = Vector2(32,24)
	title.add_theme_font_size_override("font_size",22)
	overlay.add_child(title)
	for frame in 6: await process_frame
	RenderingServer.force_draw.call_deferred()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../reports/building-refresh/catalog.png") == OK,"Actual view capture")
	scene.free()
	var receipt := {"ok":failures.is_empty(),"checks":checks,"failures":failures}
	FileAccess.open("res://../reports/building-refresh/catalog-checks.json",FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	print("GOPALA_TEST_REPORT=",JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
