extends SceneTree
func _initialize():
	var forest = load("res://data/forest/kathmandu_forest.scn").instantiate()
	var detail_center = Vector3(10, 0, -85)
	var count_in_view = 0
	for child in forest.get_children():
		if child is MultiMeshInstance3D and child.multimesh:
			for i in child.multimesh.instance_count:
				var t = child.multimesh.get_instance_transform(i)
				var d = Vector2(t.origin.x, t.origin.z).distance_to(Vector2(detail_center.x, detail_center.z))
				if d < 15.0:
					count_in_view += 1
					#print("Tree at ", t.origin, " scale ", t.basis.get_scale())
	print("Trees within 15 units of (10, -85): ", count_in_view)
	quit()
