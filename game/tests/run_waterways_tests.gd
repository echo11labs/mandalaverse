extends SceneTree
const River = preload("res://core/landscape/terrain_river.gd")
var checks := 0
var failures: Array[String] = []
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../tools/waterways-source.json"))
	for path in source.files:
		expect(FileAccess.get_sha256("res://addons/waterways/" + path) == source.files[path], "Vendored source hash: " + path)
	var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/geography/waterways/receipt.json"))
	for path in receipt.inputs:
		expect(FileAccess.get_sha256(path) == receipt.inputs[path], "Bake input is current: " + path)
	expect(FileAccess.get_sha256(receipt.output) == receipt.output_sha256, "Baked output integrity")
	var terrain := GopalaKathmanduTerrain.new()
	terrain.load_data()
	var network := GopalaWaterNetwork.new(terrain)
	var packed: PackedScene = load(receipt.output)
	var courses := packed.instantiate()
	root.add_child(courses)
	expect(courses.get_child_count() == terrain.metadata.rivers.size(), "All mapped reaches survive bake/save/load")
	var sources := {}
	for reach in terrain.metadata.rivers: sources[reach.id] = reach
	var vertices_checked := 0
	var visible_reaches := 0
	for river in courses.get_children():
		expect(river is River, "Baked node remains an editable Waterways River")
		expect(sources.has(river.source_id), "Stable mapped way ID retained")
		var reach: Dictionary = sources[river.source_id]
		expect(river.river_name == reach.name, "Mapped name retained")
		expect(river.curve.point_count >= 2 and river.widths.size() == river.curve.point_count, "Valid curve and widths after deserialization")
		for index in [0, river.curve.point_count - 1]:
			var source_point: Array = reach.points[0 if index == 0 else reach.points.size() - 1]
			var point: Vector3 = river.curve.get_point_position(index)
			expect(Vector2(point.x, point.z).distance_to(Vector2(source_point[0], source_point[2])) < 0.00001, "Mapped reach endpoint preserved")
		expect(river.visible == (not River.is_hidden_tag(reach.covered) and not River.is_hidden_tag(reach.tunnel)), "Covered waterways stay hidden")
		if river.visible: visible_reaches += 1
		expect(river.valid_flowmap and river.flow_foam_noise != null and river.dist_pressure != null, "Flow and shore maps load baked")
		expect(river.get_shader_parameter("i_valid_flowmap") == true, "Loaded material uses baked maps")
		expect(river.mesh_instance.get_active_material(0).shader == River.WATER_SHADER, "Renderer-compatible material restored")
		var flow: Image = river.flow_foam_noise.get_image()
		var shore_pixel := flow.get_pixel(8, 12)
		var center_pixel := flow.get_pixel(12, 12)
		expect(center_pixel.g > 0.5, "Texture flow moves downstream")
		expect(shore_pixel.b > center_pixel.b + 0.4, "Baked foam concentrated at banks")
		var arrays: Array = river.mesh_instance.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		expect(vertices.size() > 0 and uv2.size() == vertices.size(), "Waterways mesh and UV2 atlas exist")
		for i in range(0, vertices.size(), maxi(1, vertices.size() / 24)):
			vertices_checked += 1
			expect(vertices[i].is_finite() and normals[i].is_finite() and uv2[i].is_finite(), "Finite baked mesh attributes")
			expect(absf(vertices[i].y - terrain.height_at(vertices[i].x, vertices[i].z) - River.SURFACE_LIFT) < 0.0001, "Water surface stays above visible terrain")
			expect(normals[i].y > 0.0, "Water surface normals face upward")
		if river.visible:
			var point: Vector3 = river.curve.get_point_position(0)
			var sample := network.sample(point)
			expect(sample.has_water and sample.source_id != "", "Visible mapped source is queryable")
			expect(sample.flow_direction.is_finite() and absf(sample.flow_direction.length() - 1.0) < 0.0001, "Queried downstream direction is normalized")
	expect(visible_reaches == network.source_count, "Rendering and source queries agree on visible reaches")
	var outside := network.sample(Vector3(900, 0, 900))
	expect(not outside.has_water and outside.flow_direction == Vector3.ZERO, "Outside network returns dry land")
	# A synthetic straight reach verifies dry banks and direction independently of the rendered geometry.
	var fixture := GopalaKathmanduTerrain.new()
	fixture.load_data()
	fixture.metadata = {"rivers": [{"id": "fixture/downstream", "name": "Bagmati", "kind": "river", "points": [[-1.0, 0.0, 0.0], [1.0, 0.0, 0.0]]}]}
	var query := GopalaWaterNetwork.new(fixture)
	expect(query.sample(Vector3.ZERO).flow_direction.dot(Vector3.RIGHT) > 0.999, "Water query follows supplied downstream ordering")
	expect(query.sample(Vector3(0, 0, 0.31)).has_water, "Inside display bank contains water")
	expect(not query.sample(Vector3(0, 0, 0.34)).has_water, "Outside display bank has no water")
	courses.queue_free()
	await process_frame
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures, "reaches": sources.size(), "visible_reaches": visible_reaches, "vertices_sampled": vertices_checked}))
	quit(0 if failures.is_empty() else 1)
