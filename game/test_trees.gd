extends SceneTree

func _initialize():
	print("Testing trees...")
	var config = JSON.parse_string(FileAccess.get_file_as_string("res://data/forest/models.json"))
	var path = config.variants[0].path
	print("First variant path: ", path)
	var scene = load(path)
	if not scene:
		print("Could not load scene")
	else:
		var node = scene.instantiate()
		for child in node.get_children():
			if child is MeshInstance3D:
				print("Mesh bounds: ", child.mesh.get_aabb())
				print("Node scale: ", child.scale)
	
	var forest = load("res://data/forest/kathmandu_forest.scn")
	if forest:
		var f_node = forest.instantiate()
		var first_multi = f_node.get_child(0) as MultiMeshInstance3D
		if first_multi and first_multi.multimesh:
			print("MultiMesh instance count: ", first_multi.multimesh.instance_count)
			if first_multi.multimesh.instance_count > 0:
				var t = first_multi.multimesh.get_instance_transform(0)
				print("Transform 0: ", t)
				print("Origin Y: ", t.origin.y)
				print("Scale: ", t.basis.get_scale())
		else:
			print("No multimesh found in first child")
	else:
		print("Could not load kathmandu_forest.scn")
	quit()
