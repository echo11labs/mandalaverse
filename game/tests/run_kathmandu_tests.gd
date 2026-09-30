extends SceneTree
var checks := 0
var failures: Array[String] = []
func expect(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var terrain := GopalaKathmanduTerrain.new()
	terrain.load_data()
	expect(terrain.source.size()==1025*1025 and terrain.ground.size()==terrain.source.size(),"Complete elevation coverage")
	expect(terrain.metadata.audit.directed_cycles==0,"Reviewed river graph acyclic")
	var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/geography/source-receipt.json"))
	for file_name in receipt.files:
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(FileAccess.get_file_as_bytes("res://data/geography/"+file_name))
		expect(context.finish().hex_encode()==receipt.files[file_name],"Source checksum: "+file_name)
	for i in range(0,terrain.source.size(),1019):
		expect(is_finite(terrain.source[i]) and terrain.source[i]>500 and terrain.source[i]<3000,"Finite source elevation")
	var names: Dictionary = {}
	for river in terrain.metadata.rivers:
		names[river.name] = true
		for i in range(river.points.size()-1):
			var a: Array = river.points[i]
			var b: Array = river.points[i+1]
			expect(b[1]<=a[1]+0.000001,"Conditioned profile does not rise downstream")
			expect(absf(a[0])<=200 and absf(a[2])<=200,"Mapped course remains in region")
	for name_value in ["Bagmati","Bishnumati","Manohara","Hanumante","Dhobi Khola","Balkhu","Nakhu","Godawari","Kodku"]:
		expect(names.has(name_value),"Major river: "+name_value)
	var landmark: Dictionary = terrain.metadata.landmarks[0]
	expect(absf(landmark.lon-85.3907821)<0.00000001 and absf(landmark.lat-27.8108557)<0.00000001,"Mapped Bagdwar coordinates retained")
	var reconstructed: Dictionary = terrain.metadata.reconstruction[0]
	expect(reconstructed.kind=="reconstructed" and reconstructed.confidence.contains("Unsurveyed"),"Estimate explicitly qualified")
	expect(Vector2(reconstructed.points[0][0],reconstructed.points[0][2]).distance_to(Vector2(landmark.position[0],landmark.position[2]))<0.001,"Estimate starts at Bagdwar")
	for y in range(48):
		for x in range(48):
			var cell := Vector2i(x,y)
			expect(terrain.cell_at(terrain.cell_position(cell))==cell,"Local coordinates round trip")
	expect(not terrain.is_buildable(Vector2i(-1,0)),"Outside local grid rejects construction")
	var packed: PackedScene = load("res://scenes/landscape/kathmandu_valley.tscn")
	var world = packed.instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	expect(world.water_segments>10000 and world.has_node("InferredBagdwarHeadwater"),"Mapped and inferred layers exist")
	var courses: Node = world.get_node("MappedRiverCourses")
	expect(courses.get_child_count()>0,"Mapped river courses exist")
	var water: MeshInstance3D = courses.get_child(0).get_node("RiverMeshInstance")
	var water_arrays: Array = water.mesh.surface_get_arrays(0)
	var water_vertices: PackedVector3Array = water_arrays[Mesh.ARRAY_VERTEX]
	expect((water_vertices[1]-water_vertices[0]).cross(water_vertices[2]-water_vertices[0]).y<0,"Water winding faces the lit surface")
	var marker: MeshInstance3D = world.get_node("BagdwarSourceMarker")
	expect(Vector2(marker.position.x,marker.position.z).distance_to(Vector2(landmark.position[0],landmark.position[2]))<0.0001,"Marker is at mapped coordinate")
	var arrays: Array = world.ground_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(0,vertices.size(),1001):
		expect(absf(vertices[i].y-terrain.height_at(vertices[i].x,vertices[i].z))<0.0001,"Mesh matches ground model")
	var camera = world.get_node("Camera3D")
	for size_value in [14.0, 65.0, camera.maximum_size()]:
		var point := terrain.cell_position(Vector2i(24,24))
		camera.focus_point(point,size_value)
		var hit: Dictionary = world.pick(camera.unproject_position(point))
		expect(not hit.is_empty(),"Ground picking at geographic and local zoom")
		if not hit.is_empty(): expect(terrain.cell_at(hit.position)==Vector2i(24,24),"Projected cell picks correctly")
	camera.zoom_by(0.00001)
	expect(is_equal_approx(camera.size, camera.MIN_SIZE),"Minimum zoom bounded")
	camera.zoom_by(100000)
	expect(is_equal_approx(camera.size, camera.maximum_size()),"Maximum zoom stays inside the terrain")
	var camp_point := Vector3(terrain.camp.x, terrain.height_at(terrain.camp.x, terrain.camp.y), terrain.camp.y)
	camera.focus_point(camp_point, camera.management_size())
	var moved_from: Vector3 = camera.target
	Input.action_press("camera_right")
	for _frame in 8:
		await process_frame
	Input.action_release("camera_right")
	expect(camera.target.distance_to(moved_from) > 0.5, "Camera right moves the camp view")
	moved_from = camera.target
	Input.action_press("camera_forward")
	Input.action_press("camera_right")
	for _frame in 8:
		await process_frame
	Input.action_release("camera_forward")
	Input.action_release("camera_right")
	var step: Vector3 = camera.target - moved_from
	var ground := Vector3(step.x, 0, step.z)
	expect(absf(ground.dot(camera.ground_right())) > 0.2 and absf(ground.dot(camera.ground_forward())) > 0.2, "Two camera keys travel diagonally")
	camera.focus_point(Vector3(0, 8, 0), camera.maximum_size())
	var locked: Vector3 = camera.target
	camera.pan_ground(40.0, 0.0)
	expect(camera.clamped_last, "Fit-limit pan is rejected by the terrain clamp")
	expect(camera.target.distance_to(locked) < 2.0, "Fit-limit pan does not travel")
	expect(absf(camera.target.x) <= 200.0 and absf(camera.target.z) <= 200.0, "Pivot stays inside the terrain")
	world.queue_free()
	await process_frame
	print("GOPALA_TEST_REPORT="+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
