extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,800)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.15,0.19,0.23)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.65
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-25,0)
	sun.light_energy = 0.8
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.55
	world.add_child(camera)
	camera.position = Vector3(0,0.6,1.3)
	camera.look_at(Vector3(0,0.06,0))
	var ids := ["Broad_Oak_C","Broad_Oak_A","Broad_Oak_B","Fir_Young_C","Fir_Tall_B","Fir_Tall_A","Broad_Scrub_A"]
	var names := ["Vegetation · Tree 03","Vegetation · Tree 04","Vegetation · Tree 05","Forest Scene · Small","Forest Scene · Medium","Forest Scene · Tall","KayKit · Scrub"]
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/forest/models.json"))
	for i in ids.size():
		var v: Dictionary = config.variants.filter(func(r):return r.id==ids[i])[0]
		var path := GopalaNatureModels.resolve(v.id,v.path)
		var tree: Node3D = (load(path) as PackedScene).instantiate()
		GopalaScaleStandard.normalize_height(tree,GopalaScaleStandard.metres_to_world(12.0 if i<6 else 3.0))
		tree.position.x = (i%3-1)*0.26 if i<6 else 0.38
		tree.position.z = -0.14 if i<3 else 0.18
		world.add_child(tree)
		var label := Label3D.new()
		label.text = names[i].replace(" · ","\n")
		label.font_size = 36
		label.pixel_size = 0.0003
		label.position = Vector3(tree.position.x,0,tree.position.z+0.09)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://../reports/local/tree-pack-gallery.png")
	world.free()
	quit()
