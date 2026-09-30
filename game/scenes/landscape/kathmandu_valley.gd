extends Node3D
## Regional geography view; settlement simulation remains a separate layer.
var terrain := GopalaKathmanduTerrain.new()
var ground_mesh: ArrayMesh
var grid_view: MeshInstance3D
var selection: MeshInstance3D
var hud: GopalaKathmanduHud
var labels: Node3D
var water_segments := 0
@onready var camera = $Camera3D
func _ready() -> void:
	terrain.load_data()
	make_ground()
	make_rivers()
	make_reconstruction()
	make_labels()
	make_grid()
	make_hud()
	make_trees()
	if "--capture-source" in OS.get_cmdline_user_args(): focus_source()
	if "--capture-local" in OS.get_cmdline_user_args(): focus_camp()
	if Array(OS.get_cmdline_user_args()).any(func(s: String): return s.begins_with("--capture")): capture.call_deferred()
func ground_color(x: float,z: float) -> Color:
	var elevation := terrain.elevation_at(x,z)
	var slope := 1.0-terrain.normal_at(x,z,true).y
	var basin := Color("a1a372")
	var foothill := Color("667e5a")
	var ridge := Color("475f4c")
	var result := basin.lerp(foothill,smoothstep(1370,1700,elevation)).lerp(ridge,smoothstep(1900,2550,elevation))
	result = result.lerp(Color("8e8a73"),smoothstep(0.16,0.5,slope)*0.7)
	return result.srgb_to_linear()
func make_ground() -> void:
	var n := 512
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for z in range(n+1):
		for x in range(n+1):
			var px := -200.0+x*400.0/n
			var pz := -200.0+z*400.0/n
			vertices.append(Vector3(px,terrain.height_at(px,pz),pz))
			normals.append(terrain.normal_at(px,pz))
			colors.append(ground_color(px,pz))
	for z in range(n):
		for x in range(n):
			var a := z*(n+1)+x
			indices.append_array(PackedInt32Array([a,a+1,a+n+1,a+1,a+n+2,a+n+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	ground_mesh = ArrayMesh.new()
	ground_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var ground := MeshInstance3D.new()
	ground.name = "KathmanduRelief"
	ground.mesh = ground_mesh
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/materials/valley_ground.gdshader")
	ground.material_override = material
	add_child(ground)
	var body := StaticBody3D.new()
	body.name = "GeographicGround"
	var collider := CollisionShape3D.new()
	collider.shape = ground_mesh.create_trimesh_shape()
	body.add_child(collider)
	add_child(body)
func river_point(p: Array) -> Vector3:
	# A geographic ribbon follows the visible terrain. This depicts direction,
	# not simulated discharge or a surveyed water-surface elevation.
	return Vector3(p[0],maxf(p[1]*terrain.RELIEF,terrain.height_at(p[0],p[2]))+0.10,p[2])
func make_rivers() -> void:
	var RiverManager = load("res://addons/waterways/river_manager.gd")
	var arrows := SurfaceTool.new()
	arrows.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var waterways_node = Node3D.new()
	waterways_node.name = "MappedRiverCourses"
	add_child(waterways_node)
	
	for river in terrain.metadata.rivers:
		var points: Array = river.points
		if points.size() < 2:
			continue
		
		var width: float = 1.0 if river.kind == "river" else 0.35
		if river.name == "Bagmati": width = 1.2
		var arrow_distance: float = 0.0
		
		var river_node = RiverManager.new()
		river_node.name = river.name.replace(" ", "_") if river.name != "" else "UnnamedRiver"
		
		var new_curve: Curve3D = Curve3D.new()
		var new_widths: Array[float] = []
		
		for i in range(points.size()):
			var p: Vector3 = river_point(points[i])
			var tangent: Vector3
			if i == 0:
				tangent = (river_point(points[1]) - p).normalized()
			elif i == points.size() - 1:
				tangent = (p - river_point(points[i-1])).normalized()
			else:
				tangent = (river_point(points[i+1]) - river_point(points[i-1])).normalized()
			
			if tangent == Vector3.ZERO: tangent = Vector3.FORWARD
			
			var dist: float = 0.0
			if i < points.size() - 1:
				dist = p.distance_to(river_point(points[i+1]))
			else:
				dist = p.distance_to(river_point(points[i-1]))
				
			var out_dir: Vector3 = tangent * 0.25 * dist
			var in_dir: Vector3 = -out_dir
			
			new_curve.add_point(p, in_dir, out_dir)
			new_widths.append(width)
			
			if i < points.size() - 1:
				water_segments += 1
				var next_p: Vector3 = river_point(points[i+1])
				arrow_distance += p.distance_to(next_p)
				if river.name != "Unnamed stream" and arrow_distance > 6:
					var delta: Vector3 = next_p - p
					var direction: Vector3 = Vector3(delta.x, 0, delta.z).normalized()
					var right: Vector3 = Vector3(-direction.z, 0, direction.x) * width * 0.5
					var center: Vector3 = next_p + Vector3.UP * 0.05
					for point in [center+direction*0.7, center-direction*0.45+right.normalized()*0.42, center-direction*0.45-right.normalized()*0.42]:
						arrows.add_vertex(point)
					arrow_distance = 0
		
		river_node.curve = new_curve
		river_node.widths = new_widths
		# We want a more realistic water color/material from waterways
		# RiverManager has shape properties and material type
		# Keep default for now (Water shader)
		waterways_node.add_child(river_node)

	var arrow_mesh := MeshInstance3D.new()
	arrow_mesh.name = "DownstreamArrows"
	arrow_mesh.mesh = arrows.commit()
	arrow_mesh.material_override = line_material(Color("d2e8db"))
	add_child(arrow_mesh)
func make_reconstruction() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for reach in terrain.metadata.reconstruction:
		var points: Array = reach.points
		for i in range(points.size()-1):
			if i%3==2: continue
			var a := Vector3(points[i][0],0,points[i][2])
			var b := Vector3(points[i+1][0],0,points[i+1][2])
			var direction := (b-a).normalized()
			var side := Vector3(-direction.z,0,direction.x)*0.3
			for p in [a-side,a+side,b-side,a+side,b+side,b-side]:
				p.y = terrain.height_at(p.x,p.z)+0.20
				surface.add_vertex(p)
	var mesh := MeshInstance3D.new()
	mesh.name = "InferredBagdwarHeadwater"
	mesh.mesh = surface.commit()
	mesh.material_override = line_material(Color("dda961"))
	add_child(mesh)

func line_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
func add_label(text_value: String,point: Vector3,color: Color,font_size: int=18) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = Vector3(point.x,terrain.height_at(point.x,point.z)+2.5,point.z)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0016
	label.font_size = font_size
	label.modulate = color
	label.outline_modulate = Color("23372e")
	label.outline_size = 6
	labels.add_child(label)
func make_labels() -> void:
	labels = Node3D.new()
	labels.name = "GeographicLabels"
	add_child(labels)
	for landmark in terrain.metadata.landmarks:
		var p: Array = landmark.position
		var caption: String = landmark.name
		if landmark.kind == "mapped_source": caption = "Bagdwar · Bagmati source"
		var marker_point := Vector3(p[0],p[1],p[2])
		if landmark.kind == "mapped_source":
			marker_point.x += 34
			marker_point.z += 10
			var sphere := SphereMesh.new()
			sphere.radius = 0.65
			sphere.height = 1.3
			var marker := MeshInstance3D.new()
			marker.name = "BagdwarSourceMarker"
			marker.mesh = sphere
			marker.position = Vector3(p[0],terrain.height_at(p[0],p[2])+0.65,p[2])
			marker.material_override = line_material(Color("f0d698"))
			add_child(marker)
			var lead := SurfaceTool.new()
			lead.begin(Mesh.PRIMITIVE_LINES)
			for segment in range(24):
				for end in range(2):
					var t := float(segment+end)/24
					var x: float = lerpf(p[0],marker_point.x,t)
					var z: float = lerpf(p[2],marker_point.z,t)
					lead.add_vertex(Vector3(x,terrain.height_at(x,z)+0.4,z))
			var leader := MeshInstance3D.new()
			leader.mesh = lead.commit()
			leader.material_override = line_material(Color("e4deba"))
			add_child(leader)
		add_label(caption,marker_point,Color("e7dab1"),18)
	var chosen: Dictionary = {}
	for river in terrain.metadata.rivers:
		if river.name not in ["Bagmati","Bishnumati","Manohara","Hanumante","Nakhu","Godawari","Dhobi Khola","Balkhu","Kodku"]: continue
		if not chosen.has(river.name) or river.points.size()>chosen[river.name].points.size(): chosen[river.name] = river
	for name_value in chosen:
		var river: Dictionary = chosen[name_value]
		if name_value == "Bagmati":
			for reach in terrain.metadata.rivers:
				if reach.id == "way/751466758": river = reach
		var p: Array = river.points[int(river.points.size()*0.55)]
		add_label(name_value,Vector3(p[0]-2,p[1],p[2]),Color("b6e1df"),17)
	labels.visible = false
func make_grid() -> void:
	grid_view = MeshInstance3D.new()
	grid_view.name = "LocalPlanningGrid"
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	var half := terrain.GRID_SIZE*terrain.CELL_SIZE*0.5
	for row in range(terrain.GRID_SIZE+1):
		for segment in range(terrain.GRID_SIZE):
			for axis in range(2):
				for end in range(2):
					var a := -half+row*terrain.CELL_SIZE
					var b := -half+(segment+end)*terrain.CELL_SIZE
					var x: float = terrain.camp.x+(a if axis==0 else b)
					var z: float = terrain.camp.y+(b if axis==0 else a)
					surface.add_vertex(Vector3(x,terrain.height_at(x,z)+0.035,z))
	grid_view.mesh = surface.commit()
	grid_view.material_override = line_material(Color("c6c694"))
	grid_view.visible = false
	add_child(grid_view)
	selection = MeshInstance3D.new()
	selection.material_override = line_material(Color("eec979"))
	add_child(selection)
func make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = GopalaKathmanduHud.new()
	hud.terrain = terrain
	layer.add_child(hud)
	hud.valley_requested.connect(camera.overview)
	hud.source_requested.connect(focus_source)
	hud.camp_requested.connect(focus_camp)
	hud.grid_changed.connect(func(on: bool) -> void: grid_view.visible = on)
	hud.names_changed.connect(func(on: bool) -> void: labels.visible = on)
func _process(_delta: float) -> void:
	hud.follow(camera)
func focus_source() -> void:
	var p: Array = terrain.metadata.landmarks[0].position
	camera.focus_point(Vector3(p[0],terrain.height_at(p[0],p[2]),p[2]),65)
func focus_camp() -> void:
	camera.focus_point(Vector3(terrain.camp.x,terrain.height_at(terrain.camp.x,terrain.camp.y),terrain.camp.y),camera.management_size())
func pick(screen: Vector2) -> Dictionary:
	var origin: Vector3 = camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(screen)*1500)
	query.hit_back_faces = true
	return get_world_3d().direct_space_state.intersect_ray(query)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		focus_camp()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hud.close_build()
	elif event is InputEventKey and event.pressed and event.keycode==KEY_G:
		grid_view.visible = not grid_view.visible
		hud.set_grid(grid_view.visible)
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var hit := pick(event.position)
		if hit.is_empty(): return
		var p: Vector3 = hit.position
		var river := terrain.nearest_river(p)
		var elevation := roundi(terrain.elevation_at(p.x,p.z))
		var title_text := "Valley floor"
		var detail := "%d m" % elevation
		if river.distance < 140:
			title_text = river.name
			detail = "%d m  ·  %s" % [elevation, "Estimated headwater" if river.reconstructed else "Mapped course"]
		var source_position: Array = terrain.metadata.landmarks[0].position
		if Vector2(p.x,p.z).distance_to(Vector2(source_position[0],source_position[2]))<1.2:
			title_text = "Bagdwar"
			detail = "%d m  ·  Source of the Bagmati" % elevation
		var cell := terrain.cell_at(p)
		if terrain.contains(cell):
			detail += "  ·  %s" % ["Ground will hold a camp" if terrain.is_buildable(cell) else "Too steep, or too near the water"]
			var center := terrain.cell_position(cell)
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_LINES)
			var corners := [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]
			for i in range(4):
				for corner in [corners[i],corners[(i+1)%4]]:
					var x: float = center.x+corner.x*terrain.CELL_SIZE
					var z: float = center.z+corner.y*terrain.CELL_SIZE
					surface.add_vertex(Vector3(x,terrain.height_at(x,z)+0.05,z))
			selection.mesh = surface.commit()
		else:
			selection.mesh = null
		hud.show_place(title_text, detail)
func capture() -> void:
	if not ("--capture-source" in OS.get_cmdline_user_args() or "--capture-local" in OS.get_cmdline_user_args()):
		camera.zoom_by(0.84)
	for frame in range(20): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var suffix := "source" if "--capture-source" in OS.get_cmdline_user_args() else "local" if "--capture-local" in OS.get_cmdline_user_args() else "overview"
	var path := ProjectSettings.globalize_path("res://../reports/kathmandu-"+suffix+".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error!=OK: push_error("Kathmandu capture failed: "+error_string(error))
	get_tree().quit(0 if error==OK else 1)

func get_gltf_mesh(path: String) -> Mesh:
	var scene = load(path) as PackedScene
	if not scene: return null
	var node = scene.instantiate()
	var mesh: Mesh = null
	for child in node.get_children():
		if child is MeshInstance3D:
			mesh = child.mesh
			break
	node.queue_free()
	return mesh

func make_trees() -> void:
	var pine_mesh = get_gltf_mesh("res://assets/models/trees/StylizedNature/Pine_1.gltf")
	var oak_mesh = get_gltf_mesh("res://assets/models/trees/StylizedNature/CommonTree_1.gltf")
	var small_mesh = get_gltf_mesh("res://assets/models/trees/StylizedNature/Bush_Common.gltf")
	
	if not pine_mesh or not oak_mesh or not small_mesh:
		print("Warning: Tree meshes not found")
		return

	var random := RandomNumberGenerator.new()
	random.seed = 42
	
	var pine_transforms: Array[Transform3D] = []
	var oak_transforms: Array[Transform3D] = []
	var small_transforms: Array[Transform3D] = []

	var half := terrain.GRID_SIZE*terrain.CELL_SIZE*0.5
	for i in range(15000):
		var x := random.randf_range(-half, half)
		var z := random.randf_range(-half, half)
		# Convert to world coordinates matching terrain.camp offset if necessary?
		# Actually the terrain covers -200 to 200, wait, the loop for ground is -200 to +200.
		x = random.randf_range(-200.0, 200.0)
		z = random.randf_range(-200.0, 200.0)
		
		var elevation := terrain.elevation_at(x, z)
		var h := terrain.height_at(x, z)
		var slope := 1.0 - terrain.normal_at(x, z, true).y
		
		# Trees prefer foothills and ridges (elevation > 1350) and moderate slopes
		if elevation < 1350 and random.randf() > 0.05: continue
		if slope > 0.6: continue # too steep
		
		# Keep away from rivers (basic approximation)
		var near_river := false
		for river in terrain.metadata.rivers:
			for p in river.points:
				if Vector2(p[0]-x, p[2]-z).length() < 4.0:
					near_river = true
					break
			if near_river: break
		if near_river: continue

		var scale_val := random.randf_range(0.7, 1.3)
		var t := Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * scale_val), Vector3(x, h, z))
		
		if elevation > 1800:
			pine_transforms.append(t)
		elif elevation > 1450:
			if random.randf() > 0.3:
				oak_transforms.append(t)
			else:
				pine_transforms.append(t)
		else:
			if random.randf() > 0.5:
				oak_transforms.append(t)
			else:
				var bush_t = Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * scale_val * 1.8), Vector3(x, h, z))
				small_transforms.append(bush_t)

	instance_group("PineForest", pine_mesh, pine_transforms, null)
	instance_group("OakForest", oak_mesh, oak_transforms, null)
	instance_group("SmallTrees", small_mesh, small_transforms, null)

func instance_group(label: String, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.size() == 0 or not mesh: return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in range(transforms.size()): multimesh.set_instance_transform(i, transforms[i])
	var group := MultiMeshInstance3D.new()
	group.name = label
	group.multimesh = multimesh
	if material: group.material_override = material
	add_child(group)
