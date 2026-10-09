extends SceneTree
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/forest/models.json"))
	var paths := {}
	for v: Dictionary in config.variants:
		var path := GopalaNatureModels.resolve(v.id, v.path)
		paths[v.id] = path
		var mesh := GopalaNatureModels.merged(path)
		check(mesh != null and mesh.get_surface_count() > 0, "Complete variant: " + v.id)
		if mesh != null:
			var ref := AABB(Vector3(-1,-0.2,-1),Vector3(2,3,2))
			var fitted := GopalaNatureModels.fit_mesh(mesh,ref).get_aabb()
			check(is_equal_approx(fitted.size.y,ref.size.y) and absf(fitted.position.y-ref.position.y)<0.0001, "Height and ground anchor: " + v.id)
			check(absf(fitted.get_center().x)<0.0001 and absf(fitted.get_center().z)<0.0001,"Bottom centre: " + v.id)
	# Actual GPU instance storage, including preservation of the immutable source bake.
	var forest: Node3D = load("res://data/forest/kathmandu_forest.scn").instantiate()
	var original: Node3D = load("res://data/forest/kathmandu_forest.scn").instantiate()
	var changed := GopalaNatureModels.apply_forest(forest)
	check(forest.get_child_count()==original.get_child_count(),"Chunk count preserved")
	var same := true
	var bounds_ok := true
	var count := 0
	for i in forest.get_child_count():
		var a: MultiMeshInstance3D = forest.get_child(i)
		var b: MultiMeshInstance3D = original.get_child(i)
		same = same and a.multimesh.instance_count==b.multimesh.instance_count and a.multimesh.buffer==b.multimesh.buffer
		bounds_ok = bounds_ok and is_equal_approx(a.multimesh.mesh.get_aabb().size.y,b.multimesh.mesh.get_aabb().size.y) and absf(a.multimesh.mesh.get_aabb().position.y-b.multimesh.mesh.get_aabb().position.y)<0.0001
		count += a.multimesh.instance_count
		if a.has_meta("local_source_path"):
			check(a.multimesh!=b.multimesh and a.multimesh.mesh!=b.multimesh.mesh,"Shared bake remains immutable")
	check(same,"All instance buffers preserve seed positions, rotations and scales")
	check(bounds_ok,"All regional tree heights and ground anchors preserved")
	check(count==100940,"Forest population preserved")
	var stand := GopalaTimberStandView.new()
	stand.build(321,43129,func(_x,_z):return 0.0,Vector2.ZERO)
	stand.update_amount(1,30)
	check(stand.trees.filter(func(t):return t.visible).size()==1,"Resource depletion retained")
	stand.update_amount(0,30)
	check(not stand.visible,"Exhausted timber stand hides")
	stand.free();forest.free();original.free()
	var report := {"ok":failures.is_empty(),"checks":checks,"failures":failures,"population":count,"local_chunks":changed,"variants":paths}
	FileAccess.open("res://../reports/local/tree-replacement.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("GOPALA_TEST_REPORT="+JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
