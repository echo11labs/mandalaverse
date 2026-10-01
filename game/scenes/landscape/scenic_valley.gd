extends Node3D
## Landscape-only presentation. Decorations carry no simulation resources.
const FIELD = preload("res://data/maps/sculpted_valley.tres")
var terrain: GopalaSculptedValley = FIELD
var ground_mesh: ArrayMesh
var inspection: Label
var grid_view: MeshInstance3D
var selection: MeshInstance3D
var tree_count := 0
@onready var camera: GopalaScenicCamera = $Camera3D

func _ready() -> void:
	make_ground()
	make_water()
	make_vegetation()
	make_grass()
	make_grid()
	make_hud()
	if "--capture-close" in OS.get_cmdline_user_args(): camera.focus_clearing()
	else: camera.overview()
	if "--capture" in OS.get_cmdline_user_args() or "--capture-close" in OS.get_cmdline_user_args():
		capture.call_deferred()

func ground_color(x: float, z: float, height: float) -> Color:
	var normal := terrain.normal_at(x, z)
	var variation := (terrain.noise_at(x * 3.0, z * 3.0) + 1.0) * 0.5
	var grass := Color("667951").lerp(Color("899362"), variation)
	var bank: float = smoothstep(terrain.river_width(z) + 2.0, terrain.river_width(z) + 7.0, abs(x - terrain.river_center(z)))
	grass = Color("ada587").lerp(grass, bank)
	grass = grass.lerp(Color("74756a"), smoothstep(0.14, 0.45, 1.0 - normal.y))
	var edge: float = maxf(abs(x), abs(z))
	return grass.lerp(Color("91978c"), smoothstep(130, 180, edge))

func make_ground() -> void:
	var n := 256
	var span := 480.0
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for z in range(n + 1):
		for x in range(n + 1):
			var px := -span * 0.5 + x * span / n
			var pz := -span * 0.5 + z * span / n
			var h := terrain.height_at(px, pz)
			# Distant ridges frame the playable valley; they have no buildable cells.
			var far_factor: float = smoothstep(95, 165, -pz)
			h += far_factor * (25.0 + 35.0 * pow(abs(sin(px * 0.043 + 0.4)), 2))
			vertices.append(Vector3(px, h, pz))
			normals.append(terrain.normal_at(px, pz))
			colors.append(ground_color(px, pz, h).lerp(Color("d2d5c6"), smoothstep(43, 68, h)).srgb_to_linear())
	for z in range(n + 1):
		for x in range(n + 1):
			var left := vertices[z * (n + 1) + maxi(x - 1, 0)]
			var right := vertices[z * (n + 1) + mini(x + 1, n)]
			var back := vertices[maxi(z - 1, 0) * (n + 1) + x]
			var front := vertices[mini(z + 1, n) * (n + 1) + x]
			normals[z * (n + 1) + x] = (front - back).cross(right - left).normalized()
	for z in range(n):
		for x in range(n):
			var a := z * (n + 1) + x
			indices.append_array(PackedInt32Array([a, a + 1, a + n + 1, a + 1, a + n + 2, a + n + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	ground_mesh = ArrayMesh.new()
	ground_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/materials/valley_ground.gdshader")
	var ground := MeshInstance3D.new()
	ground.name = "SculptedGround"
	ground.mesh = ground_mesh
	ground.material_override = material
	add_child(ground)
	var body := StaticBody3D.new()
	body.name = "GroundPicking"
	var collider := CollisionShape3D.new()
	collider.shape = ground_mesh.create_trimesh_shape()
	body.add_child(collider)
	add_child(body)

func make_water() -> void:
	var RiverManager = load("res://addons/waterways/river_manager.gd")
	var river_path = RiverManager.new()
	river_path.name = "River"
	
	var curve := Curve3D.new()
	var widths: Array[float] = []
	var z_points := range(-240, 241, 10)
	for i in range(z_points.size()):
		var pz = float(z_points[i])
		var p := Vector3(terrain.river_center(pz), 0.28, pz)
		
		var tangent := Vector3(0, 0, 1)
		if i > 0 and i < z_points.size() - 1:
			var prev_p := Vector3(terrain.river_center(float(z_points[i-1])), 0.28, float(z_points[i-1]))
			var next_p := Vector3(terrain.river_center(float(z_points[i+1])), 0.28, float(z_points[i+1]))
			tangent = (next_p - prev_p).normalized()
			
		var dist := 10.0
		curve.add_point(p, -tangent * dist * 0.25, tangent * dist * 0.25)
		var w = terrain.water_half_width(0) * 2.0
		widths.append(w)
		
	river_path.curve = curve
	river_path.widths = widths
	
	# Optional: keep custom shader or use default Waterways shader. Since Waterways provides better rendering out of the box, we just use default by not overriding
	add_child(river_path)

func foliage_mesh(variant: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.13
	trunk.bottom_radius = 0.25
	trunk.height = 3.0
	trunk.radial_segments = 6
	append_colored(surface, trunk, Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0)), Color("63523d"))
	var random := RandomNumberGenerator.new()
	random.seed = 481 + variant
	if variant == 2:
		for tier in range(4):
			var cone := CylinderMesh.new()
			cone.top_radius = 0.08
			cone.bottom_radius = 2.0 - tier * 0.38
			cone.height = 2.8 - tier * 0.25
			cone.radial_segments = 9
			append_colored(surface, cone, Transform3D(Basis.IDENTITY, Vector3(0, 2.8 + tier * 1.15, 0)), Color("3c604b").lerp(Color("6b7e4b"), tier * 0.18))
		return surface.commit()
	for i in range(6):
		var sphere := SphereMesh.new()
		sphere.radial_segments = 10
		sphere.rings = 5
		sphere.radius = 1.0
		sphere.height = 2.0
		var p := Vector3(random.randf_range(-1.2, 1.2), random.randf_range(3.0, 5.2), random.randf_range(-1.2, 1.2))
		var scale_value := Vector3(random.randf_range(1.3, 2.0), random.randf_range(1.3, 2.0), random.randf_range(1.3, 2.0))
		append_colored(surface, sphere, Transform3D(Basis.IDENTITY.scaled(scale_value), p), Color("354f3c").lerp(Color("7a8950"), random.randf() * 0.8))
	return surface.commit()

func append_colored(surface: SurfaceTool, mesh: Mesh, transform: Transform3D, color: Color) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		surface.set_color(color.srgb_to_linear())
		surface.set_normal((transform.basis.inverse().transposed() * normals[index]).normalized())
		surface.add_vertex(transform * verts[index])

func make_vegetation() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = terrain.seed_value
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/materials/valley_foliage.gdshader")
	for variant in range(3):
		var transforms: Array[Transform3D] = []
		for i in range(650):
			var x := random.randf_range(-110, 110)
			var z := random.randf_range(-110, 100)
			var h := terrain.height_at(x, z)
			var clearing_distance := Vector2((x - terrain.clearing.x) / 24, (z - terrain.clearing.y) / 28).length()
			if h < 1.0 or clearing_distance < 1.0 or terrain.normal_at(x, z).y < 0.77: continue
			if abs(x - terrain.river_center(z)) < terrain.river_width(z) + 5: continue
			if h < 4.0 and random.randf() > 0.17: continue
			var scale_value := random.randf_range(0.55, 1.15)
			transforms.append(Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * scale_value), Vector3(x, h, z)))
		instance_group("Grove" + str(variant), foliage_mesh(variant), transforms, material)
		tree_count += transforms.size()
	var stone := SphereMesh.new()
	stone.radial_segments = 7
	stone.rings = 3
	stone.radius = 1
	stone.height = 2
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_color = Color("8c8b79").srgb_to_linear()
	stone_material.roughness = 0.95
	var rocks: Array[Transform3D] = []
	for i in range(260):
		var z := random.randf_range(-100, 100)
		var x: float = terrain.river_center(z) + (1 if random.randf() > 0.5 else -1) * random.randf_range(terrain.water_half_width(z) + 0.3, terrain.river_width(z) + 6)
		var scale_value := Vector3(random.randf_range(0.4, 1.3), random.randf_range(0.3, 0.8), random.randf_range(0.4, 1.2))
		rocks.append(Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(scale_value), Vector3(x, terrain.height_at(x, z), z)))
	instance_group("RiverStones", stone, rocks, stone_material)

func make_grass() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0, 1.047, 2.094]:
		var right := Vector3(cos(angle), 0, sin(angle))
		surface.set_color(Color("6c7844").srgb_to_linear())
		surface.set_normal(Vector3.UP)
		surface.add_vertex(-right * 0.28)
		surface.add_vertex(right * 0.28)
		surface.add_vertex(Vector3(0.09, 0.58, 0.03))
	var mesh := surface.commit()
	var transforms: Array[Transform3D] = []
	var random := RandomNumberGenerator.new()
	random.seed = terrain.seed_value + 25
	for i in range(8000):
		var x := random.randf_range(-90, 90)
		var z := random.randf_range(-90, 90)
		if terrain.height_at(x, z) < 1.1 or terrain.normal_at(x, z).y < 0.92: continue
		if terrain.noise_at(x * 2.4, z * 2.4) < -0.07: continue
		var size_value := random.randf_range(0.55, 1.25)
		transforms.append(Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * size_value), Vector3(x, terrain.height_at(x, z), z)))
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/materials/valley_foliage.gdshader")
	instance_group("MeadowGrasses", mesh, transforms, material)

func instance_group(label: String, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in range(transforms.size()): multimesh.set_instance_transform(i, transforms[i])
	var group := MultiMeshInstance3D.new()
	group.name = label
	group.multimesh = multimesh
	group.material_override = material
	add_child(group)

func line_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = false
	return material

func make_grid() -> void:
	grid_view = MeshInstance3D.new()
	grid_view.name = "PlanningGrid"
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	var step := terrain.extent / terrain.grid_size
	for row in range(terrain.grid_size + 1):
		for segment in range(192):
			for axis in range(2):
				for end in range(2):
					var a := -90.0 + row * step
					var b := -90.0 + (segment + end) * 180.0 / 192.0
					var x := a if axis == 0 else b
					var z := b if axis == 0 else a
					surface.add_vertex(Vector3(x, maxf(0.32, terrain.height_at(x, z)) + 0.06, z))
	grid_view.mesh = surface.commit()
	grid_view.material_override = line_material(Color(0.92, 0.89, 0.68, 0.28))
	grid_view.visible = false
	add_child(grid_view)
	selection = MeshInstance3D.new()
	selection.name = "SelectedCell"
	selection.material_override = line_material(Color("f4cd81"))
	add_child(selection)

func make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(32, 26)
	var backdrop := Panel.new()
	backdrop.position = Vector2(20, 18)
	backdrop.size = Vector2(440, 152)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.115, 0.105, 0.88)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	backdrop.add_theme_stylebox_override("panel", style)
	layer.add_child(backdrop)
	layer.add_child(box)
	var title := Label.new()
	title.text = "GOPALA  /  DAWN OF THE VALLEY"
	title.add_theme_color_override("font_color", Color("e8ddba"))
	title.add_theme_font_size_override("font_size", 13)
	box.add_child(title)
	var heading := Label.new()
	heading.text = "The first valley"
	heading.add_theme_font_size_override("font_size", 30)
	box.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "A river, wooded hills, and room for a village."
	subtitle.add_theme_color_override("font_color", Color("d3d7c6"))
	box.add_child(subtitle)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	for text_value in ["Valley", "Starting clearing", "Planning grid"]:
		var button := Button.new()
		button.text = text_value
		button.custom_minimum_size.y = 34
		actions.add_child(button)
		if text_value == "Valley": button.pressed.connect(camera.overview)
		elif text_value == "Starting clearing": button.pressed.connect(camera.focus_clearing)
		else: button.pressed.connect(func(): grid_view.visible = not grid_view.visible)
	var footer := Panel.new()
	footer.position = Vector2(20, 718)
	footer.size = Vector2(1000, 40)
	footer.add_theme_stylebox_override("panel", style)
	layer.add_child(footer)
	inspection = Label.new()
	inspection.position = Vector2(32, 730)
	inspection.text = "LANDSCAPE STUDY   ·   Click ground to inspect   ·   Scroll to zoom   ·   Middle-drag / WASD to pan   ·   G: grid"
	inspection.add_theme_font_size_override("font_size", 14)
	layer.add_child(inspection)

func pick(screen: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen) * 700)
	query.hit_back_faces = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_G:
		grid_view.visible = not grid_view.visible
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := pick(event.position)
		if hit.is_empty(): return
		var cell := terrain.cell_at(hit.position)
		if not terrain.contains(cell):
			inspection.text = "Distant landscape · Outside the settlement area"
			selection.mesh = null
			return
		var center := terrain.cell_position(cell)
		inspection.text = "%s   ·   Cell %d, %d   ·   %s" % [terrain.surface_name(center), cell.x, cell.y, "Suitable ground" if terrain.is_buildable(cell) else "Unsuitable ground"]
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_LINES)
		var side := terrain.extent / terrain.grid_size
		var corners := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
		for i in range(4):
			for c in [corners[i], corners[(i + 1) % 4]]:
				var x: float = center.x + c.x * side
				var z: float = center.z + c.y * side
				surface.add_vertex(Vector3(x, maxf(0.32, terrain.height_at(x, z)) + 0.15, z))
		selection.mesh = surface.commit()

func capture() -> void:
	for frame in range(30): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://../reports/landscape-3d-clearing.png" if "--capture-close" in OS.get_cmdline_user_args() else "res://../reports/landscape-3d-overview.png"
	var error := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	if error != OK: push_error("Landscape capture failed: " + error_string(error))
	get_tree().quit(0 if error == OK else 1)
