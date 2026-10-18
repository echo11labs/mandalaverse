extends SceneTree
## Use a real renderer: the headless dummy renderer does not expose MultiMesh transforms.
var checks := 0
var failures: Array[String] = []
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Forest buffer checks require a real renderer.")
		quit(1)
		return
	var directory := "res://assets/models/nature/kaykit/"
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory + "source-receipt.json"))
	expect(source.license == "CC0-1.0" and FileAccess.file_exists(directory + source.license_file), "Original publisher license retained")
	for path in source.files:
		expect(FileAccess.get_sha256(directory + path) == source.files[path], "Unmodified external model/texture: " + path)
	var proton: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../tools/proton-scatter-source.json"))
	for path in proton.files:
		expect(FileAccess.get_sha256("res://addons/proton_scatter/" + path) == proton.files[path], "Pinned ProtonScatter source: " + path)
	var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/forest/bake-receipt.json"))
	for path in receipt.inputs:
		expect(FileAccess.get_sha256(path) == receipt.inputs[path], "Forest input is current: " + path)
	expect(FileAccess.get_sha256(receipt.output) == receipt.output_sha256, "Saved forest integrity")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/forest/models.json"))
	var variants := {}
	for variant: Dictionary in config.variants: variants[variant.id] = variant
	var terrain := GopalaKathmanduTerrain.new()
	terrain.load_data()
	var rules := GopalaForestRules.new()
	rules.terrain = terrain
	expect(rules.detail_center == Vector2(config.detail_center[0],config.detail_center[1]) and rules.detail_half_extent * 2.0 == config.detail_extent_units, "Dense detail domain and regional exclusion agree")
	expect(not rules.accepts(201.0,0.0,1.0,0.0), "Outside mapped area excluded")
	expect(not rules.accepts(terrain.camp.x,terrain.camp.y,1.0,0.0), "Planning clearing remains open")
	var forest: Node3D = load(receipt.output).instantiate()
	expect(forest.name == "ExternalForest" and float(forest.get_meta("tree_relief_multiplier")) == 1.0, "External forest preserves physical scale independently of relief")
	expect(forest.get_child_count() == int(receipt.chunks), "Spatial chunk count survives serialization")
	var seen := {}
	var count := 0
	var detail_count := 0
	var origin_count := 0
	var uniform_ok := true
	var height_ok := true
	var anchors_ok := true
	var domain_ok := true
	var rivers_ok := true
	var slopes_ok := true
	var elevation_ok := true
	var clearing_ok := true
	var jitter_ok := false
	var minimum_height := INF
	var maximum_height := 0.0
	var yaw_sample := {}
	for group in forest.get_children():
		if not group is MultiMeshInstance3D:
			expect(false, "Forest contains only external mesh batches")
			continue
		var id: String = group.get_meta("variant_id")
		var variant: Dictionary = variants[id]
		expect(group.get_meta("source_path") == variant.path, "Batch references admitted source: " + id)
		var mesh: Mesh = group.multimesh.mesh
		expect(mesh is ArrayMesh and mesh.get_surface_count() == int(source.models[id].surfaces), "Complete imported surfaces: " + id)
		for surface in mesh.get_surface_count():
			var material = mesh.surface_get_material(surface)
			expect(material is StandardMaterial3D and material.albedo_texture != null, "Textured bark and foliage survive save/load: " + id)
		var bounds := mesh.get_aabb()
		for index in group.multimesh.instance_count:
			var placed: Transform3D = group.multimesh.get_instance_transform(index)
			var p := placed.origin
			count += 1
			seen[id] = int(seen.get(id,0)) + 1
			if p.length_squared() < 0.001: origin_count += 1
			var scale := placed.basis.get_scale()
			uniform_ok = uniform_ok and absf(scale.x-scale.y)<0.000001 and absf(scale.y-scale.z)<0.000001
			var height_m := bounds.size.y * scale.y * terrain.METRES_PER_UNIT
			minimum_height = minf(minimum_height,height_m)
			maximum_height = maxf(maximum_height,height_m)
			height_ok = height_ok and height_m >= float(variant.height_min_m)-0.001 and height_m <= float(variant.height_max_m)+0.001
			anchors_ok = anchors_ok and absf(p.y+bounds.position.y*scale.y-terrain.height_at(p.x,p.z))<0.00003
			domain_ok = domain_ok and absf(p.x)<200.0 and absf(p.z)<200.0
			rivers_ok = rivers_ok and terrain.river_distance(p.x,p.z)>=rules.river_clearance_m-0.001
			slopes_ok = slopes_ok and terrain.normal_at(p.x,p.z,true).y>=cos(deg_to_rad(rules.maximum_slope_degrees))-0.000001
			elevation_ok = elevation_ok and terrain.elevation_at(p.x,p.z)>=rules.minimum_elevation_m-0.001
			clearing_ok = clearing_ok and Vector2(p.x,p.z).distance_to(terrain.camp)*terrain.METRES_PER_UNIT>=rules.clearing_radius_m-0.001
			if absf(p.x-rules.detail_center.x)<rules.detail_half_extent and absf(p.z-rules.detail_center.y)<rules.detail_half_extent:
				detail_count+=1
			jitter_ok = jitter_ok or absf(fmod(p.x+200.0,float(config.regional_spacing_m)/100.0))>0.02
			yaw_sample[roundi(placed.basis.get_euler().y * 100.0)] = true
	expect(count == int(receipt.population) and count == int(forest.get_meta("population")), "All baked placements survive save/load")
	expect(origin_count == 0, "No lost/zero MultiMesh transforms")
	# JSON numbers deserialize as floats; compare the integer population values.
	var recorded_counts := {}
	for variant_id in receipt.variants: recorded_counts[variant_id] = int(receipt.variants[variant_id])
	expect(seen == recorded_counts and seen.size() == variants.size(), "All source variants survive with their recorded placement counts")
	expect(uniform_ok and height_ok, "Every tree retains aspect ratio and its specified metre height")
	expect(anchors_ok, "Every model's ground anchor meets the displayed triangle terrain")
	expect(domain_ok and rivers_ok and slopes_ok and elevation_ok and clearing_ok, "Every placement obeys mapped bounds, water clearance, slope, elevation and clearing rules")
	expect(jitter_ok and yaw_sample.size()>100, "Scatter has position jitter and varied orientations")
	# Detail layer is now generated at runtime via EZTreeDraw; baked forest only contains regional layer.
	expect(detail_count > 500 and config.detail_spacing_m < config.regional_spacing_m, "Dense foothill detail exists at closer spacing than regional proxies")
	forest.free()
	await process_frame
	var review: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/forest/review.json"))
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"population":count,"detail_count":detail_count,"physical_height_m":[minimum_height,maximum_height],"source_review_status":review.get("status"),"scope":"Saved-source integrity and placement checks; artistic replacement acceptance is separate."}))
	quit(0 if failures.is_empty() else 1)
