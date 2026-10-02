extends SceneTree
func _initialize():
	var forest = load("res://data/forest/kathmandu_forest.scn").instantiate()
	var first_multi = forest.get_child(0) as MultiMeshInstance3D
	if first_multi and first_multi.multimesh:
		print("MultiMesh AABB: ", first_multi.multimesh.get_aabb())
		print("Instance 0 Transform: ", first_multi.multimesh.get_instance_transform(0))
	quit()
