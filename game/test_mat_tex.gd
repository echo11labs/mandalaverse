extends SceneTree
func _initialize():
	var config = JSON.parse_string(FileAccess.get_file_as_string("res://data/forest/models.json"))
	var path = config.variants[0].path
	var scene = load(path)
	var node = scene.instantiate()
	for child in node.get_children():
		if child is MeshInstance3D:
			var mat = child.mesh.surface_get_material(0)
			if mat and mat is StandardMaterial3D:
				print("Albedo color: ", mat.albedo_color)
				print("Albedo texture: ", mat.albedo_texture)
	quit()
