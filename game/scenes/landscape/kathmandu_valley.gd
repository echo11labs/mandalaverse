extends Node3D
## Regional geography view; settlement simulation remains a separate layer.
var terrain := GopalaKathmanduTerrain.new()
var ground_mesh: ArrayMesh
var grid_view: MeshInstance3D
var selection: MeshInstance3D
var ground: MeshInstance3D
var hud: GopalaKathmanduHud
var labels: Node3D
var water_segments := 0
var water_network: GopalaWaterNetwork
var sample_pine_height_m := 0.0
var tree_population := 0
@onready var camera = $Camera3D
func _ready() -> void:
	terrain.load_data()
	load_lakes()
	make_ground()
	make_fringe()
	make_rivers()
	make_reconstruction()
	make_map_overlay()
	make_labels()
	make_grid()
	make_lakes()
	make_hud()
	make_trees()
	if not Array(OS.get_cmdline_user_args()).any(func(s: String): return s.begins_with("--capture")):
		camera.overview()
	if "--capture-source" in OS.get_cmdline_user_args(): focus_source()
	if "--capture-water" in OS.get_cmdline_user_args():
		var reach: Dictionary = terrain.metadata.rivers.filter(func(r: Dictionary): return r.name == "Bagmati" and r.points.size() > 500)[0]
		var point: Array = reach.points[int(reach.points.size() * 0.65)]
		camera.focus_point(Vector3(point[0], terrain.height_at(point[0], point[2]), point[2]), 14.0)
	if "--capture-local" in OS.get_cmdline_user_args(): focus_camp()
	if "--capture-edge" in OS.get_cmdline_user_args():
		camera.turn_by(70.0)
		camera.focus_point(Vector3(150.0, terrain.height_at(150.0, 10.0), 10.0), 48.0)
	if "--capture-forest" in OS.get_cmdline_user_args():
		camera.focus_point(Vector3(10.0, terrain.height_at(10.0, -85.0), -85.0), 14.0)
	if "--capture-trees" in OS.get_cmdline_user_args():
		camera.target = Vector3(10.0, terrain.height_at(10.0, -85.0), -85.0)
		camera.size = 3.0
		camera.aim()
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
			var h := terrain.height_at(px,pz)
			
			# Terrain deformation for lakes
			for lake in lakes_data:
				var d := Vector2(px, pz).distance_to(lake.center)
				var effect_radius = maxf(lake.radius * 1.5, 1.5)
				if d < effect_radius:
					var blend := smoothstep(effect_radius, lake.radius * 0.5, d)
					h = lerpf(h, lake.water_level - 0.1, blend)
			
			vertices.append(Vector3(px,h,pz))
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
	ground = MeshInstance3D.new()
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
func fringe_height(x: float, z: float) -> float:
	var edge := maxf(absf(x), absf(z))
	var border := terrain.height_at(clampf(x, -200.0, 200.0), clampf(z, -200.0, 200.0))
	if edge <= 200.0:
		return border
	var rise := smoothstep(200.0, 330.0, edge) * 42.0
	return border + rise
func make_fringe() -> void:
	# Land past the surveyed square, so an oblique view meets hills instead of the clear color.
	var extent := 360.0
	var n := 72
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := extent * 2.0 / n
	for z in range(n):
		for x in range(n):
			var origin := Vector2(-extent + x * step, -extent + z * step)
			var corners := [origin, origin + Vector2(step, 0), origin + Vector2(0, step), origin + Vector2(step, step)]
			var outside := false
			for corner in corners:
				if maxf(absf(corner.x), absf(corner.y)) > 198.0:
					outside = true
			if not outside:
				continue
			var positions: Array[Vector3] = []
			for corner in corners:
				var height := fringe_height(corner.x, corner.y)
				positions.append(Vector3(corner.x, height, corner.y))
			for index in [0, 1, 2, 1, 3, 2]:
				var point: Vector3 = positions[index]
				var inland := terrain.height_at(clampf(point.x, -199.0, 199.0), clampf(point.z, -199.0, 199.0))
				var tint: Color = ground_color(clampf(point.x, -199.0, 199.0), clampf(point.z, -199.0, 199.0))
				tint = tint.lerp(Color("3d5244").srgb_to_linear(), clampf((point.y - inland) / 42.0, 0.0, 1.0))
				surface.set_color(tint)
				surface.set_normal(Vector3.UP)
				surface.add_vertex(point)
	var rim := 80
	for i in range(rim):
		var t0 := float(i) / rim
		var t1 := float(i + 1) / rim
		for edge in range(4):
			var a := rim_point(t0, edge, extent)
			var b := rim_point(t1, edge, extent)
			var cliff := [a, b, a + Vector3.DOWN * 80.0, b, b + Vector3.DOWN * 80.0, a + Vector3.DOWN * 80.0]
			for point in cliff:
				surface.set_color(Color("2c3a30").srgb_to_linear())
				surface.set_normal(Vector3.UP)
				surface.add_vertex(point)
	var fringe := MeshInstance3D.new()
	fringe.name = "TerrainFringe"
	fringe.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/materials/valley_ground.gdshader")
	fringe.material_override = material
	add_child(fringe)
func rim_point(t: float, edge: int, extent: float) -> Vector3:
	var along := lerpf(-extent, extent, t)
	var x := along
	var z := -extent
	if edge == 1:
		x = extent
		z = along
	elif edge == 2:
		x = -along
		z = extent
	elif edge == 3:
		x = -extent
		z = -along
	return Vector3(x, fringe_height(x, z), z)
func river_point(p: Array) -> Vector3:
	# A geographic ribbon follows the visible terrain. This depicts direction,
	# not simulated discharge or a surveyed water-surface elevation.
	return Vector3(p[0],maxf(p[1]*terrain.RELIEF,terrain.height_at(p[0],p[2]))+0.10,p[2])
func make_rivers() -> void:
	var baked: PackedScene = load("res://data/geography/waterways/mapped_rivers.scn")
	var courses := baked.instantiate()
	add_child(courses)
	water_segments = int(courses.get_meta("source_segments", 0))
	water_network = GopalaWaterNetwork.new(terrain)
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

func make_map_overlay() -> void:
	# 1. Create a high-res SubViewport for drawing the map graphics in 2D
	var viewport := SubViewport.new()
	viewport.size = Vector2i(4096, 4096)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	
	# 2. Map drawer script
	var drawer := Node2D.new()
	drawer.set_script(load("res://scenes/landscape/map_overlay_drawer.gd"))
	drawer.set("terrain", terrain)
	if FileAccess.file_exists("res://data/geography/regions_gopala.json"):
		var raw := FileAccess.get_file_as_string("res://data/geography/regions_gopala.json")
		drawer.set("regions", JSON.parse_string(raw))
	viewport.add_child(drawer)
	
	# Compatibility supports sampling the live map texture in the ground shader.
	# A Decal cannot accept ViewportTexture and is unsupported by this renderer.
	viewport.name = "GeographicMapOverlay"
	if ground == null:
		return
	var ground_material: ShaderMaterial = ground.material_override
	ground_material.set_shader_parameter("geographic_overlay", viewport.get_texture())
	ground_material.set_shader_parameter("use_geographic_overlay", true)

	# 4. We still place 3D labels for the regions
	if FileAccess.file_exists("res://data/geography/regions_gopala.json"):
		var file = FileAccess.open("res://data/geography/regions_gopala.json", FileAccess.READ)
		var regions = JSON.parse_string(file.get_as_text())
		if drawer.has_method("get_label_anchor"):
			for region in regions:
				var c = Color(region.tint)
				var anchor: Vector3 = drawer.get_label_anchor(region.name)
				if labels == null:
					labels = Node3D.new()
					labels.name = "GeographicLabels"
					add_child(labels)
				add_label(region.label, anchor, c, 24)

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

var lakes_data: Array = []

func load_lakes() -> void:
	if not FileAccess.file_exists("res://data/geography/lake_polygons.json"):
		return
	var raw := FileAccess.get_file_as_string("res://data/geography/lake_polygons.json")
	var lakes: Array = JSON.parse_string(raw)
	
	var cx := 85.375
	var cy := 27.695
	var m_per_deg_lon := 98565.0 / 100.0
	var m_per_deg_lat := 111320.0 / 100.0
	
	for lake in lakes:
		var center_x: float = (float(lake.lon) - cx) * m_per_deg_lon
		var center_z: float = (cy - float(lake.lat)) * m_per_deg_lat
		
		var poly2d := PackedVector2Array()
		var max_dist := 0.0
		
		if lake.geojson and lake.geojson.type == "Polygon":
			var ring: Array = lake.geojson.coordinates[0]
			for pt in ring:
				var px: float = (float(pt[0]) - cx) * m_per_deg_lon
				var pz: float = (cy - float(pt[1])) * m_per_deg_lat
				var local_x := px - center_x
				var local_z := pz - center_z
				poly2d.append(Vector2(local_x, -local_z))
				max_dist = maxf(max_dist, Vector2(local_x, local_z).length())
				
		if max_dist < 0.1: max_dist = 0.5 # fallback for Point
		
		var w_level := terrain.height_at(center_x, center_z) - 0.05
		
		lakes_data.append({
			"name": lake.name,
			"center": Vector2(center_x, center_z),
			"radius": max_dist,
			"water_level": w_level,
			"poly": poly2d
		})

func make_lakes() -> void:
	if lakes_data.is_empty():
		return
	
	var lakes_node := Node3D.new()
	lakes_node.name = "Ponds"
	add_child(lakes_node)
	
	for lake in lakes_data:
		var pos := Vector3(lake.center.x, lake.water_level, lake.center.y)
		var node: Node3D = null
		
		if not lake.poly.is_empty():
			var indices := Geometry2D.triangulate_polygon(lake.poly)
			if indices.size() > 0:
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_normal(Vector3.UP)
				for pt in lake.poly:
					st.add_vertex(Vector3(pt.x, 0.0, pt.y))
				for idx in indices:
					st.add_index(idx)
				var mesh_instance := MeshInstance3D.new()
				mesh_instance.mesh = st.commit()
				node = mesh_instance
		
		if not node:
			var mesh_instance := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = lake.radius
			mesh.bottom_radius = lake.radius
			mesh.height = 0.02
			mesh_instance.mesh = mesh
			node = mesh_instance
			
		var mat := StandardMaterial3D.new()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color("2e7399")
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.85
		mat.roughness = 0.05
		mat.metallic = 0.2
		node.material_override = mat
			
		node.position = pos
		lakes_node.add_child(node)
		
		add_label(lake.name, pos + Vector3(0, 1.5, 0), Color("a6e1ff"), 18)

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
	hud = preload("res://scenes/ui/hud.tscn").instantiate()
	hud.terrain = terrain
	add_child(hud)
	hud.valley_requested.connect(camera.overview)
	hud.source_requested.connect(focus_source)
	hud.camp_requested.connect(focus_camp)
	hud.grid_changed.connect(func(on: bool) -> void: grid_view.visible = on)
	hud.names_changed.connect(func(on: bool) -> void: labels.visible = on)
	hud.zoom_in_requested.connect(func() -> void: camera.zoom_step(0.84))
	hud.zoom_out_requested.connect(func() -> void: camera.zoom_step(1.0 / 0.84))
	hud.turn_left_requested.connect(func() -> void: camera.turn_by(-15.0))
	hud.turn_right_requested.connect(func() -> void: camera.turn_by(15.0))
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
		if selection != null:
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
	var args := OS.get_cmdline_user_args()
	if not ("--capture-source" in args or "--capture-local" in args or "--capture-edge" in args or "--capture-forest" in args or "--capture-water" in args or "--capture-trees" in args):
		camera.zoom_by(0.84)
	for frame in range(20): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var suffix := "trees" if "--capture-trees" in args else "source" if "--capture-source" in args else "local" if "--capture-local" in args else "edge" if "--capture-edge" in args else "forest" if "--capture-forest" in args else "waterways" if "--capture-water" in args else "overview"
	var path := ProjectSettings.globalize_path("res://../reports/kathmandu-"+suffix+".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error!=OK: push_error("Kathmandu capture failed: "+error_string(error))
	get_tree().quit(0 if error==OK else 1)

func make_trees() -> void:
	var review: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/forest/review.json"))
	if review.get("status") != "accepted":
		return
	var forest_path := "res://data/forest/kathmandu_forest.scn"
	if FileAccess.get_sha256(forest_path) != review.get("accepted_bake_sha256", ""):
		push_warning("Forest bake changed since its visual review; replacement trees require review.")
		return
	var forest: Node3D = load(forest_path).instantiate()
	add_child(forest)
	tree_population = int(forest.get_meta("population"))
	sample_pine_height_m = float(forest.get_meta("sample_pine_height_m"))
