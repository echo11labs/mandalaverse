extends Node3D
## Regional geography view; settlement simulation remains a separate layer.
var terrain := GopalaKathmanduTerrain.new()
const GROUND_QUADS := 512
var _ground_vertices := PackedVector3Array()
var ground_mesh: ArrayMesh
var grid_view: MeshInstance3D
var selection: MeshInstance3D
var ground: MeshInstance3D
var hud: GopalaKathmanduHud
var labels: Node3D
var territory_labels: Node3D
var map_overlay: GopalaMapOverlay
var water_segments := 0
var water_network: GopalaWaterNetwork
var sample_pine_height_m := 0.0
var tree_population := 0
@onready var camera = $Camera3D
@onready var simulation: GopalaSettlementSimulation = $SettlementSimulation
@onready var detail_forest = $DetailForest
@onready var detail_stones = $DetailStones if has_node("DetailStones") else null
@onready var hero_trees = $HeroTrees
@export var mvp_enabled := false
@export var vegetation_seed: int = 43129
## Zero rolls a new world; store this resolved value to reproduce its distribution.
var resolved_world_seed: int = 43129

var _grid_requested := false
var _placement_outline: MeshInstance3D
var _placement_ghost: MeshInstance3D
var _placement_rotation := 0
var _placement_valid := false
var _placement_cell := Vector2i.ZERO
var _built_views := {}
var _blocked_workers := {}
const SAVE_PATH := "user://saves/settlement.json"
var _save_service := GopalaSettlementSave.new()
var _picker: GopalaEntityPickResolver3D
func _ready() -> void:
	resolved_world_seed = vegetation_seed if vegetation_seed != 0 else (int(Time.get_unix_time_from_system()) ^ randi())
	set_meta("world_seed", resolved_world_seed)
	terrain.load_data()
	terrain.camp = _safe_settlement_start()
	camera.configure_terrain(terrain)
	load_lakes()
	make_ground()
	camera.surface_height = ground_height_at
	camera.update_view()
	make_fringe()
	make_rivers()
	make_reconstruction()
	make_map_overlay()
	make_labels()
	make_lakes()
	make_hud()

	_placement_ghost = MeshInstance3D.new()
	_placement_ghost.visible = false
	add_child(_placement_ghost)
	_placement_outline = MeshInstance3D.new()
	_placement_outline.name = "PlacementFootprint"
	_placement_outline.visible = false
	add_child(_placement_outline)

	# Configure grid around existing camp
	var grid_config = GopalaSettlementGridConfig.new(terrain.camp, Rect2i(-24, -24, 48, 48), GopalaScaleStandard.number("units", "logical_meters_per_cell"), GopalaScaleStandard.number("units", "regional_meters_per_world_unit"))
	simulation.coordinate_service().configure(grid_config)
	make_grid()
	simulation.bootstrap_session()
	if not get_tree().has_method("expect"):
		GopalaScenarioSetup.setup_kathmandu_scenario(simulation, terrain.camp)
		_seed_forest_resource_stands()

	var stores = simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING)
	if not stores.is_empty(): simulation._storage_service.enable_locations(stores[0].entity_id)
	_configure_worker_routes()
	if mvp_enabled:
		GopalaMvpScenario.setup(simulation,terrain.camp)
		hud.enable_mvp_controls()
		hud.new_game_requested.connect(func(): get_tree().change_scene_to_file("res://scenes/mvp.tscn"))

	_picker = GopalaEntityPickResolver3D.new()
	_picker.configure(simulation.entity_queries())

	simulation.command_processed.connect(_on_command_processed)
	simulation.snapshot_committed.connect(_on_snapshot_committed)
	# The initial scenario was seeded before presentation subscribed, while paused.
	_on_snapshot_committed(simulation.snapshot())

	make_trees()
	if not Array(OS.get_cmdline_user_args()).any(func(s: String): return s.begins_with("--capture")):
		focus_camp()
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
	if "--capture-territory" in OS.get_cmdline_user_args():
		map_overlay.set_mode(GopalaMapOverlay.Mode.SURVEY)
		cycle_territory_mode()
		camera.focus_point(Vector3(0.0, terrain.height_at(0.0, 0.0), 0.0), camera.maximum_size())
	var scenery_window := GopalaSceneryWindow.new()
	add_child(scenery_window)
	scenery_window.configure(camera, self)
	if Array(OS.get_cmdline_user_args()).any(func(s: String): return s.begins_with("--capture")): capture.call_deferred()
func _configure_worker_routes() -> void:
	var coordinate = simulation.coordinate_service()
	var config = coordinate._config
	var margin := ceili(GopalaScaleStandard.number("navigation", "margin") / config.world_units_per_cell)
	var bounds: Rect2i = config.bounds.grow(margin)
	var lo: Vector2 = coordinate.settlement_cell_to_world_xz(bounds.position) - Vector2.ONE * config.world_units_per_cell
	var hi: Vector2 = coordinate.settlement_cell_to_world_xz(bounds.end) + Vector2.ONE * config.world_units_per_cell
	var region := Rect2(lo,hi-lo)
	var rivers: Array[Dictionary] = []
	for segment in GopalaStoneScatter.river_segments(terrain):
		if region.intersects(segment.bounds): rivers.append(segment)
	var walkable := func(point: Vector2) -> bool:
		return terrain.normal_at(point.x,point.y,true).y >= cos(deg_to_rad(35.0)) and GopalaStoneScatter.outside_displayed_water(point,rivers)
	# Scenario buildings reserve the same cells as placed buildings.
	for building in simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING):
		if simulation.occupancy_service().claim_for_owner(building.entity_id) != null: continue
		var cells: Array[Vector2i] = []
		for pair in building.attributes.get(&"footprint_cells",[]): cells.append(Vector2i(pair[0],pair[1]))
		if not cells.is_empty():
			simulation.occupancy_service().reserve_cells(building.entity_id,cells,0)
			simulation.occupancy_service().commit_reservation(building.entity_id,0)
	simulation._route_service.enable(bounds,walkable)

func _safe_settlement_start() -> Vector2:
	var rivers := GopalaStoneScatter.river_segments(terrain)
	var nearby: Array[Dictionary] = []
	var search := GopalaScaleStandard.number("scenario", "bank_search_radius")
	var region := Rect2(terrain.camp - Vector2.ONE * search * 2.0, Vector2.ONE * search * 4.0)
	for segment in rivers:
		if region.intersects(segment.bounds):
			nearby.append(segment)
	var step := GopalaScaleStandard.number("scenario", "bank_search_step")
	var clearance := GopalaScaleStandard.number("scenario", "camp_clearance")
	for ring in range(ceili(search / step) + 1):
		for direction in 48:
			var angle := float(direction) * TAU / 48.0
			var candidate := terrain.camp + Vector2(cos(angle), sin(angle)) * float(ring) * step
			var valid := terrain.normal_at(candidate.x, candidate.y, true).y >= cos(deg_to_rad(12.0))
			for offset in [Vector2.ZERO, Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
				if not GopalaStoneScatter.outside_displayed_water(candidate + offset * clearance, nearby):
					valid = false
					break
			if valid:
				return candidate
	push_error("No dry settlement start within the configured search radius")
	return terrain.camp

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
	var n := GROUND_QUADS
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for z in range(n+1):
		for x in range(n+1):
			var px := -200.0+x*400.0/n
			var pz := -200.0+z*400.0/n
			var h := terrain.height_at(px,pz)

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
	_ground_vertices = vertices
	ground_mesh = ArrayMesh.new()
	ground_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	ground = MeshInstance3D.new()
	ground.name = "KathmanduRelief"
	# The complete mesh remains the physics/reference surface. Only spatial chunks
	# are rendered, so a local camera no longer submits the entire regional mesh.
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/materials/valley_ground.gdshader")
	ground.material_override = material
	add_child(ground)
	var chunk_quads := int(GopalaScaleStandard.settings().rendering.terrain_chunk_quads)
	for cz in range(0, n, chunk_quads):
		for cx in range(0, n, chunk_quads):
			var chunk_vertices := PackedVector3Array()
			var chunk_normals := PackedVector3Array()
			var chunk_colors := PackedColorArray()
			var chunk_indices := PackedInt32Array()
			var width := mini(chunk_quads, n - cx)
			var depth := mini(chunk_quads, n - cz)
			for z in range(depth + 1):
				for x in range(width + 1):
					var source := (cz + z) * (n + 1) + cx + x
					chunk_vertices.append(vertices[source])
					chunk_normals.append(normals[source])
					chunk_colors.append(colors[source])
			for z in range(depth):
				for x in range(width):
					var a := z * (width + 1) + x
					chunk_indices.append_array(PackedInt32Array([a,a+1,a+width+1,a+1,a+width+2,a+width+1]))
			var chunk_arrays := []
			chunk_arrays.resize(Mesh.ARRAY_MAX)
			chunk_arrays[Mesh.ARRAY_VERTEX] = chunk_vertices
			chunk_arrays[Mesh.ARRAY_NORMAL] = chunk_normals
			chunk_arrays[Mesh.ARRAY_COLOR] = chunk_colors
			chunk_arrays[Mesh.ARRAY_INDEX] = chunk_indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, chunk_arrays)
			var chunk := MeshInstance3D.new()
			chunk.name = "TerrainChunk_%d_%d" % [cx, cz]
			chunk.mesh = mesh
			chunk.material_override = material
			ground.add_child(chunk)
	var body := StaticBody3D.new()
	body.name = "GeographicGround"
	body.collision_layer = 2
	var collider := CollisionShape3D.new()
	collider.shape = ground_mesh.create_trimesh_shape()
	body.add_child(collider)
	add_child(body)
## Height of the actual rendered/pickable triangles, including their diagonal.
## Regional sampling can differ from the full-resolution elevation field between vertices.
func ground_height_at(x: float, z: float) -> float:
	if _ground_vertices.is_empty(): return terrain.height_at(x,z)
	var point := Vector2(clampf(x,-200.0,200.0), clampf(z,-200.0,200.0))
	var offset := (point + Vector2.ONE * 200.0) * float(GROUND_QUADS) / 400.0
	var ix := mini(floori(offset.x), GROUND_QUADS - 1)
	var iz := mini(floori(offset.y), GROUND_QUADS - 1)
	var u := offset.x - float(ix)
	var v := offset.y - float(iz)
	var a := iz * (GROUND_QUADS + 1) + ix
	var h00: float = _ground_vertices[a].y
	var h10: float = _ground_vertices[a + 1].y
	var h01: float = _ground_vertices[a + GROUND_QUADS + 1].y
	var h11: float = _ground_vertices[a + GROUND_QUADS + 2].y
	if u + v <= 1.0: return h00 + u * (h10 - h00) + v * (h01 - h00)
	return h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)

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
	var document := load_territory_document()
	var drawer := GopalaMapOverlay.new()
	drawer.name = "TerritoryOverlay"
	drawer.terrain = terrain
	drawer.document = document
	drawer.regions = document.get("chiefdoms", [])
	drawer.frontiers = document.get("frontiers", [])
	drawer.rim = document.get("rim", {})
	drawer.target_viewport = viewport
	map_overlay = drawer
	viewport.add_child(drawer)

	# Compatibility supports sampling the live map texture in the ground shader.
	# A Decal cannot accept ViewportTexture and is unsupported by this renderer.
	viewport.name = "GeographicMapOverlay"
	if ground == null:
		return
	var ground_material: ShaderMaterial = ground.material_override
	ground_material.set_shader_parameter("geographic_overlay", viewport.get_texture())
	ground_material.set_shader_parameter("use_geographic_overlay", true)

	# 3. Chiefdom labels live in their own node so the F key can hide them
	# independently of the landmark and river labels.
	territory_labels = Node3D.new()
	territory_labels.name = "TerritoryLabels"
	add_child(territory_labels)
	for region in document.get("chiefdoms", []):
		var anchor: Vector3 = drawer.get_label_anchor(String(region.id))
		add_territory_label(String(region.label), anchor, Color(String(region.tint)), 26)

func load_territory_document() -> Dictionary:
	if not FileAccess.file_exists(GopalaMapOverlay.REGIONS_PATH):
		push_warning("Territory document missing; the F key will have nothing to paint.")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GopalaMapOverlay.REGIONS_PATH))
	if not parsed is Dictionary:
		push_error("Territory document is not an object.")
		return {}
	return parsed

func add_territory_label(text_value: String, point: Vector3, color: Color, font_size: int) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = point
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0016
	label.font_size = font_size
	label.modulate = color
	label.outline_modulate = Color("1b1710")
	label.outline_size = 8
	territory_labels.add_child(label)

func cycle_territory_mode() -> void:
	if map_overlay == null:
		return
	map_overlay.cycle_mode()
	var survey := map_overlay.mode == GopalaMapOverlay.Mode.SURVEY
	territory_labels.visible = map_overlay.mode != GopalaMapOverlay.Mode.OFF
	var ground_material: ShaderMaterial = ground.material_override
	ground_material.set_shader_parameter("use_geographic_overlay", map_overlay.mode != GopalaMapOverlay.Mode.OFF)
	hud.show_territory(map_overlay.mode_name(), survey, territory_summary())

func territory_summary() -> Array:
	if map_overlay == null or not map_overlay.built:
		return []
	return map_overlay.regions

func describe_chiefdom(region_id: String) -> Dictionary:
	if map_overlay == null:
		return {}
	return map_overlay.region_record(region_id)

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
	var config = simulation.coordinate_service()._config
	var step: float = config.world_units_per_cell
	var bounds: Rect2i = config.bounds
	var lift := GopalaScaleStandard.number("planning", "grid_lift")
	# Cell IDs refer to centres; their borders are half a cell to either side.
	for axis in range(2):
		var rows: int = bounds.size.x if axis == 0 else bounds.size.y
		var segments: int = bounds.size.y if axis == 0 else bounds.size.x
		for row in range(rows + 1):
			for segment in range(segments):
				for end in range(2):
					var offset := Vector2(row - 0.5, segment + end - 0.5) if axis == 0 else Vector2(segment + end - 0.5, row - 0.5)
					var point: Vector2 = config.origin_xz + (Vector2(bounds.position) + offset) * step
					surface.add_vertex(Vector3(point.x, ground_height_at(point.x, point.y) + lift, point.y))
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
	hud.build_selected.connect(_on_build_selected)
	hud.work_role_selected.connect(func(role: StringName):
		var selected = simulation.selection_service().snapshot()
		if selected.state == GopalaSelectionSnapshot.State.ENTITY and selected.entity.kind == GopalaEntityKind.VILLAGER:
			simulation.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":selected.selected_entity_id,"role":role})
	)
	hud.cattle_pasture_selected.connect(func(pasture_id: int):
		var selected = simulation.selection_service().snapshot()
		if selected.state == GopalaSelectionSnapshot.State.ENTITY and selected.entity.kind == GopalaEntityKind.ANIMAL:
			simulation.submit_command(GopalaSimulationCommand.ASSIGN_CATTLE_PASTURE,{"cow_id":selected.selected_entity_id,"pasture_id":pasture_id})
	)
	hud.save_requested.connect(save_settlement)
	hud.load_requested.connect(load_settlement)
	hud.speed_selected.connect(func(mult: int) -> void:
		if mult == 0:
			simulation.set_paused(true)
		else:
			simulation.set_paused(false)
			simulation.set_speed(mult)
	)
	hud.grid_changed.connect(func(on: bool) -> void: _grid_requested = on; grid_view.visible = on or hud._placement_active)
	hud.names_changed.connect(func(on: bool) -> void: labels.visible = on)
	hud.zoom_in_requested.connect(func() -> void: camera.zoom_step(0.84))
	hud.zoom_out_requested.connect(func() -> void: camera.zoom_step(1.0 / 0.84))
	hud.turn_left_requested.connect(func() -> void: camera.turn_by(-15.0))
	hud.turn_right_requested.connect(func() -> void: camera.turn_by(15.0))
	var survey_regions: Array = []
	if map_overlay != null and map_overlay.built:
		survey_regions = map_overlay.regions
	hud.configure_survey(terrain, survey_regions)
func _process(_delta: float) -> void:
	if hud != null:
		hud.follow(camera)
		grid_view.visible = _grid_requested or hud._placement_active
		if not hud._placement_active:
			_placement_ghost.visible = false
			_placement_outline.visible = false
	$MorningSun.directional_shadow_max_distance = camera.camera_distance() + camera.size * 2.0 + GopalaScaleStandard.number("rendering", "shadow_padding")
func focus_source() -> void:
	var p: Array = terrain.metadata.landmarks[0].position
	camera.focus_point(Vector3(p[0],terrain.height_at(p[0],p[2]),p[2]),65)
func focus_camp() -> void:
	var bounds := Rect2(terrain.camp, Vector2.ZERO)
	var found := false
	# Current workers/buildings define home focus; resource distribution does not.
	for kind in [GopalaEntityKind.VILLAGER, GopalaEntityKind.BUILDING]:
		for actor in simulation.entity_queries().snapshots_by_kind(kind):
			var point := Vector2(float(actor.attributes.get(&"position_x", terrain.camp.x)), float(actor.attributes.get(&"position_z", terrain.camp.y)))
			if _built_views.has(actor.entity_id):
				var position: Vector3 = _built_views[actor.entity_id].position
				point = Vector2(position.x, position.z)
			if not found:
				bounds = Rect2(point, Vector2.ZERO)
				found = true
			else:
				bounds = bounds.expand(point)
	var focus := bounds.get_center()
	camera.reset_focus(Vector3(focus.x, ground_height_at(focus.x, focus.y), focus.y))
	# Fit every active actor at arbitrary yaw/viewport proportions, with space to build.
	var required: float = camera.management_size()
	var padding := GopalaScaleStandard.number("camera", "focus_padding")
	var aspect: float = camera.view_size().x / camera.view_size().y
	for corner in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		var relative: Vector3 = Vector3(corner.x, ground_height_at(corner.x, corner.y), corner.y) - camera.target
		required = maxf(required, (absf(camera.basis.x.dot(relative)) + padding) * 2.0 / aspect)
		required = maxf(required, (absf(camera.basis.y.dot(relative)) + padding) * 2.0)
	camera.focus_point(camera.target, required)

func pick(screen: Vector2) -> Dictionary:
	var origin: Vector3 = camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(screen)*1500)
	query.hit_back_faces = true
	return get_world_3d().direct_space_state.intersect_ray(query)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			save_settlement()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F9:
			load_settlement(SAVE_PATH + ".bak" if event.shift_pressed else SAVE_PATH)
			get_viewport().set_input_as_handled()
			return
	if hud == null:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		focus_camp()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if hud._placement_active:
			hud.close_build()
			_placement_ghost.visible = false
			hud.notify("Placement cancelled", "")
		else:
			var selected_worker = simulation.selection_service().snapshot()
			if selected_worker.state == GopalaSelectionSnapshot.State.ENTITY and selected_worker.entity.kind == GopalaEntityKind.VILLAGER:
				simulation.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":selected_worker.selected_entity_id,"role":&"NONE"})
			if selected_worker.state == GopalaSelectionSnapshot.State.ENTITY and selected_worker.entity.kind == GopalaEntityKind.VILLAGER and selected_worker.entity.attributes.get(&"task_kind") == &"GATHER":
				simulation.submit_command(GopalaSimulationCommand.REQUEST_STOP_GATHERING, {"villager_id": selected_worker.selected_entity_id})
				hud.notify("Stopping collection", "Any carried goods will be delivered")
			hud.close_build()
	elif event.is_action_pressed("debug_spawn_villager") and OS.is_debug_build():
		var hit := pick(get_viewport().get_mouse_position())
		if not hit.is_empty():
			simulation.submit_command(GopalaSimulationCommand.REQUEST_SPAWN_VILLAGER, {"x": hit.position.x, "z": hit.position.z})
			hud.notify("Villager spawned", "")
	elif event.is_action_pressed("command_move_selected") and OS.is_debug_build():
		var hit := pick(get_viewport().get_mouse_position())
		if not hit.is_empty():
			var selected = simulation.selection_service().snapshot()
			if selected.state == GopalaSelectionSnapshot.State.ENTITY and selected.entity.kind == GopalaEntityKind.VILLAGER:
				simulation.submit_command(GopalaSimulationCommand.REQUEST_MOVE_VILLAGER, {"villager_id": selected.selected_entity_id, "x": hit.position.x, "z": hit.position.z})
				hud.notify("Move task assigned", "")
	elif event.is_action_pressed("toggle_territory"):
		cycle_territory_mode()

	elif hud._placement_active and event.is_action_pressed("placement_rotate_cw"):
		_placement_rotation = (_placement_rotation + 1) % 4
		_update_ghost(get_viewport().get_mouse_position())
	elif hud._placement_active and event.is_action_pressed("placement_rotate_ccw"):
		_placement_rotation = (_placement_rotation + 3) % 4
		_update_ghost(get_viewport().get_mouse_position())
	elif hud._placement_active and event is InputEventMouseMotion:
		_update_ghost(event.position)
	elif hud._placement_active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _placement_valid:
			if hud._selected_build == &"pasture":
				simulation.submit_command(GopalaSimulationCommand.CREATE_PASTURE,{"cell_x":_placement_cell.x,"cell_y":_placement_cell.y})
			else: simulation.request_construction(hud._selected_build, _placement_cell, _placement_rotation)
		else:
			hud.notify("Cannot place", "Invalid or occupied terrain", "terra")
	elif not hud._placement_active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var hit := pick(event.position)
		if hit.is_empty(): return
		var selected = simulation.selection_service().snapshot()
		if selected.state == GopalaSelectionSnapshot.State.ENTITY and selected.entity.kind == GopalaEntityKind.VILLAGER:
			var entity_id := _picker.resolve_collider(hit.collider)
			if entity_id != 0:
				var target_entity = simulation.entity_queries().snapshot(entity_id)
				if target_entity != null:
					if target_entity.kind == GopalaEntityKind.RESOURCE_SOURCE and target_entity.attributes.get(&"gatherable", false):
						var res_id = target_entity.attributes.get(&"resource_id", &"timber")
						if res_id in GopalaSimulationCommand.COLLECTIBLE_RESOURCES:
							var command_type = GopalaSimulationCommand.REQUEST_GATHER_RESOURCE
							simulation.submit_command(command_type, {
								"villager_id": selected.selected_entity_id,
								"source_entity_id": entity_id,
								"source_revision": target_entity.revision,
								"resource_id": res_id,
								"repeat": true
							})
							hud.notify("Gather order issued", String(res_id).capitalize())
							return
					elif target_entity.kind == GopalaEntityKind.ANIMAL:
						simulation.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":selected.selected_entity_id,"role":&"herder"})
						return
					elif target_entity.kind == GopalaEntityKind.BUILDING and str(target_entity.attributes.get("construction_state","COMPLETED")) == "COMPLETED" and target_entity.attributes.get("definition_id") in [&"timber_camp",&"gatherer_shelter",&"water_point",&"cattle_shelter"]:
						var role: StringName = {&"timber_camp":&"timber",&"gatherer_shelter":&"wild_food",&"water_point":&"water",&"cattle_shelter":&"herder"}[target_entity.attributes.definition_id]
						simulation.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":selected.selected_entity_id,"role":role})
						return
					elif target_entity.kind == GopalaEntityKind.BUILDING and target_entity.attributes.get(&"construction_state", &"COMPLETED") != &"COMPLETED":
						simulation.submit_command(GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER, {
							"villager_id": selected.selected_entity_id,
							"blueprint_id": entity_id
						})
						hud.notify("Builder order issued", "Building site")
						return
			simulation.submit_command(GopalaSimulationCommand.REQUEST_MOVE_VILLAGER, {
				"villager_id": selected.selected_entity_id,
				"x": hit.position.x,
				"z": hit.position.z
			})
			hud.notify("Move task assigned", "")
			return
	elif not hud._placement_active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := pick(event.position)
		if hit.is_empty(): return
		var p: Vector3 = hit.position
		if map_overlay != null and map_overlay.mode != GopalaMapOverlay.Mode.OFF:
			var chiefdom := map_overlay.region_id_at(p.x, p.z)
			if not chiefdom.is_empty():
				hud.show_chiefdom(map_overlay.mode_name(), describe_chiefdom(chiefdom))
				return
		var entity_id := _picker.resolve_collider(hit.collider)
		if entity_id != 0:
			simulation.selection_service().select_entity(entity_id)
			_inspect_selected_entity(entity_id)
			return

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
				selection.mesh = null
		hud.show_place(title_text, detail)

func _on_build_selected(id: StringName) -> void:
	grid_view.visible = true
	_placement_rotation = 0
	_update_ghost(get_viewport().get_mouse_position())

func _update_ghost(screen: Vector2) -> void:
	if hud == null or not hud._placement_active or hud._selected_build == StringName(""):
		_placement_ghost.visible = false
		_placement_outline.visible = false
		return
	var p: Vector3 = camera.terrain_hit(screen)
	if is_inf(p.x):
		_placement_ghost.visible = false
		_placement_outline.visible = false
		return
	_placement_cell = simulation.coordinate_service().world_to_settlement_cell(Vector2(p.x, p.z))
	var validation = simulation._herd_service.validate_pasture(_placement_cell) if hud._selected_build == &"pasture" else simulation.placement_service().validate_placement(hud._selected_build, _placement_cell, _placement_rotation)

	_placement_valid = validation.valid

	# Terrain height check manually since simulation doesn't know terrain
	if _placement_valid:
		for cell in validation.transformed_cells:
			var center = simulation.coordinate_service().settlement_cell_to_world_xz(cell)
			var elevation = terrain.height_at(center.x, center.y)
			var cell_local = terrain.cell_at(Vector3(center.x, elevation, center.y))
			if not terrain.is_buildable(cell_local):
				_placement_valid = false
				break

	_placement_ghost.visible = true
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.8, 0.2, 0.5) if _placement_valid else Color(0.8, 0.2, 0.2, 0.5)

	var def = simulation.placement_service().get_building(hud._selected_build)
	var size_x = (4 if hud._selected_build == &"pasture" else def.footprint.x) * simulation.coordinate_service()._config.world_units_per_cell
	var size_y = (4 if hud._selected_build == &"pasture" else def.footprint.y) * simulation.coordinate_service()._config.world_units_per_cell
	if _placement_rotation == 1 or _placement_rotation == 3:
		var temp = size_x
		size_x = size_y
		size_y = temp

	var box = BoxMesh.new()
	box.size = Vector3(size_x, GopalaScaleStandard.number("planning", "grid_lift") if hud._selected_build == &"pasture" else GopalaScaleStandard.number("building", "height"), size_y)
	_placement_ghost.mesh = box
	_placement_ghost.material_override = mat

	# Position at center of transformed cells footprint
	var min_x = INF
	var max_x = -INF
	var min_z = INF
	var max_z = -INF
	for cell in validation.transformed_cells:
		var center = simulation.coordinate_service().settlement_cell_to_world_xz(cell)
		min_x = min(min_x, center.x)
		max_x = max(max_x, center.x)
		min_z = min(min_z, center.y)
		max_z = max(max_z, center.y)

	var center_x = (min_x + max_x) / 2.0
	var center_z = (min_z + max_z) / 2.0
	var h = ground_height_at(center_x, center_z)
	_placement_ghost.position = Vector3(center_x, h + box.size.y * 0.5, center_z)

	var outline := SurfaceTool.new()
	outline.begin(Mesh.PRIMITIVE_LINES)
	var step: float = simulation.coordinate_service()._config.world_units_per_cell
	var lift := GopalaScaleStandard.number("planning", "grid_lift")
	for cell in validation.transformed_cells:
		var center: Vector2 = simulation.coordinate_service().settlement_cell_to_world_xz(cell)
		var corners := [Vector2(-0.5,-0.5), Vector2(0.5,-0.5), Vector2(0.5,0.5), Vector2(-0.5,0.5)]
		for edge in 4:
			for corner in [corners[edge], corners[(edge + 1) % 4]]:
				var point: Vector2 = center + corner * step
				outline.add_vertex(Vector3(point.x, ground_height_at(point.x,point.y) + lift, point.y))
	_placement_outline.mesh = outline.commit()
	_placement_outline.material_override = line_material(Color("67d783") if _placement_valid else Color("e56b62"))
	_placement_outline.visible = true

func _on_command_processed(result: GopalaCommandResult) -> void:
	if result.status == GopalaCommandResult.Status.REJECTED:
		if result.reason_code == &"STORAGE_FULL": hud.notify("Storage full", "Build another stockpile or use stored materials.", "terra")
		elif result.reason_code == &"INVALID_DESTINATION": hud.notify("No storage", "Complete a reachable stockpile before collecting.", "terra")
		elif result.reason_code == &"VILLAGER_BUSY": hud.notify("Worker busy", "Stop the current collection job and finish any carried delivery first.", "terra")
	if result.status == GopalaCommandResult.Status.REJECTED and result.reason_code in [&"NO_ROUTE", &"NO_ACCESS_CELL", &"ROUTE_START_BLOCKED", &"ROUTE_OUT_OF_BOUNDS"]:
		var messages := {&"NO_ROUTE":"No clear route to that location.", &"NO_ACCESS_CELL":"Building access is blocked.", &"ROUTE_START_BLOCKED":"The worker is standing on blocked ground.", &"ROUTE_OUT_OF_BOUNDS":"That location is outside the local travel area."}
		hud.notify("Cannot reach destination",messages[result.reason_code],"terra")
	if result.details().get("command_type", &"") == GopalaSimulationCommand.REQUEST_CONSTRUCTION:
		if result.status == GopalaCommandResult.Status.REJECTED:
			hud.notify("Placement failed", result.reason_code, "terra")
		else:
			hud.notify("Construction started", "Dwelling placed successfully", "forest")
			hud.close_build()
			_placement_ghost.visible = false

func _inspect_selected_entity(entity_id: int) -> void:
	var snap = simulation.entity_queries().snapshot(entity_id)
	if snap == null:
		hud.hide_inspection()
		return

	match snap.kind:
		GopalaEntityKind.BUILDING:
			var def_id = snap.attributes.get(&"definition_id", &"dwelling")
			var title_str = String(def_id).capitalize()
			var cstate = String(snap.attributes.get(&"construction_state", &"COMPLETED"))
			var eyebrow_str = "Building"
			var detail_str = "Completed"
			var body_lines: Array[String] = []

			if cstate != "COMPLETED":
				eyebrow_str = "Construction Site"
				detail_str = cstate.capitalize().replace("_", " ")

				var requirements: Dictionary = snap.attributes.get("required_materials",{})
				for resource in requirements:
					var delivered: int = snap.attributes.get("delivered_materials",{}).get(resource,0)
					var reserved: int = snap.attributes.get("reserved_materials",{}).get(resource,0)
					body_lines.append("[data]%s Delivered[/data]  %d / %d" % [str(resource).replace("_"," ").capitalize(),delivered,int(requirements[resource])])
					if reserved > 0: body_lines.append("[data]%s Reserved[/data]  %d" % [str(resource).capitalize(),reserved])

				var work_req = int(snap.attributes.get(&"work_required", 0))
				var work_done = int(snap.attributes.get(&"work_completed", 0))
				var pct = 0
				if work_req > 0:
					pct = int(round(float(work_done) / float(work_req) * 100.0))
				body_lines.append("[data]Labor Progress[/data]  %d%% (%d / %d ticks)" % [pct, work_done, work_req])

				var builder_id = int(snap.attributes.get(&"assigned_builder_id", 0))
				if builder_id != 0:
					body_lines.append("[data]Assigned Builder[/data]  Villager #%d" % builder_id)
				else:
					body_lines.append("[data]Assigned Builder[/data]  None")
			else:
				var shelter = int(snap.attributes.get(&"shelter_capacity", 0))
				if shelter > 0:
					body_lines.append("[data]Shelter Capacity[/data]  %d" % shelter)
				var accepts = bool(snap.attributes.get(&"accepts_timber", false))
				if accepts:
					body_lines.append("[data]Settlement Storage[/data]  Materials, food and fodder")

			if cstate == "COMPLETED" and simulation._storage_service.destinations(&"timber").any(func(b): return b.entity_id == entity_id):
				for resource in GopalaSimulationCommand.COLLECTIBLE_RESOURCES:
					body_lines.append("[data]%s in this store[/data]  %d / %d · %d incoming" % [String(resource).capitalize(),simulation._storage_service.stored(entity_id,resource),simulation._storage_service.store_capacity(entity_id,resource),simulation._storage_service.incoming_at(entity_id,resource)])
			hud._show_inspection(eyebrow_str, title_str, detail_str, "\n".join(body_lines))

		GopalaEntityKind.ANIMAL:
			var body_lines: Array[String] = []
			body_lines.append("[data]Status[/data]  %s" % str(snap.attributes.get(&"herd_status",&"NO_PASTURE")).replace("_"," "))
			body_lines.append("[data]Milk made[/data]  %d" % int(snap.attributes.get(&"milk_produced",0)))
			var pasture := simulation.entity_queries().snapshot(int(snap.attributes.get(&"pasture_id",0)))
			if pasture != null:
				var support := simulation._herd_service.pasture_summary(pasture)
				body_lines.append("[data]Pasture #%d[/data]  %d / %d cattle" % [pasture.entity_id,support.count,support.capacity])
				body_lines.append("[data]Grazing reserve[/data]  ~%.1f min" % support.grazing_minutes)
				if support.overcrowded: body_lines.append("Crowded: grazing milk cycles ×%d. Supply fodder or move cattle." % support.cycle_multiplier)
			body_lines.append("[data]Travel[/data]  %s" % str(snap.attributes.get(&"cattle_move_state",&"IDLE")).capitalize())
			body_lines.append("Select a settler, then right-click cattle to assign tending.")
			hud._show_inspection("Cattle",str(snap.attributes.get(&"display_name","Cattle")),"Pasture, water, feed and tending", "\n".join(body_lines))
			var choices := []
			for plot in simulation._herd_service.pastures():
				var support := simulation._herd_service.pasture_summary(plot)
				choices.append({"id":plot.entity_id,"label":"Pasture #%d · %d/%d" % [plot.entity_id,support.count,support.capacity]})
			hud.show_cattle_controls(choices)
		GopalaEntityKind.VILLAGER:
			var eyebrow_str = "Settler"
			var title_str = "Villager #%d" % entity_id
			var state_str = String(snap.attributes.get(&"task_state", snap.attributes.get(&"movement_state",&"IDLE"))).capitalize().replace("_", " ")
			var detail_str = "State: %s" % state_str
			var body_lines: Array[String] = []
			var carried = int(snap.attributes.get(&"carried_amount", 0))
			if carried > 0:
				body_lines.append("[data]Carrying[/data]  %d %s" % [carried, str(snap.attributes.get(&"carried_resource_id", &""))])
			else:
				body_lines.append("[data]Carrying[/data]  Empty-handed")
			var building_id = int(snap.attributes.get(&"target_building_id", 0))
			if building_id != 0:
				body_lines.append("[data]Building Site[/data]  Site #%d" % building_id)
			var source_id = int(snap.attributes.get(&"target_source_id", 0))
			if source_id != 0:
				body_lines.append("[data]Target Source[/data]  Resource #%d" % source_id)
			body_lines.append("[data]Work role[/data]  %s" % str(snap.attributes.get(&"work_role",&"NONE")).capitalize())
			body_lines.append("[data]Job status[/data]  %s" % str(snap.attributes.get(&"job_status",&"OFF")).replace("_"," ").capitalize())
			if snap.attributes.has(&"health"):
				body_lines.append("[data]Health[/data]  %d / 100" % int(snap.attributes.health))
				body_lines.append("[data]Needs[/data]  %s" % str(snap.attributes.need_state).replace("_"," ").capitalize())
				body_lines.append("[data]Home[/data]  %s" % ("Dwelling %d" % int(snap.attributes.get(&"home_id",0)) if int(snap.attributes.get(&"home_id",0)) > 0 else "No completed home"))
			hud._show_inspection(eyebrow_str, title_str, detail_str, "\n".join(body_lines))
			hud._worker_jobs.visible = true

		GopalaEntityKind.RESOURCE_SOURCE:
			var res_key = snap.attributes.get(&"resource_id", snap.attributes.get(&"resource_type", &"timber"))
			var rtype = String(res_key).capitalize()
			var eyebrow_str = "Natural Resource"
			var title_str = "Loose Stone Patch" if rtype == "Stone" else ("Timber Stand" if rtype == "Timber" else "%s Patch" % rtype.replace("_"," "))
			var avail = int(snap.attributes.get(&"available_amount", 0))
			var reserved = int(snap.attributes.get(&"reserved_amount", 0))
			var exhausted = bool(snap.attributes.get(&"exhausted", false))
			var detail_str = "Depleted" if exhausted else "%d units available" % avail
			var body_lines: Array[String] = []
			body_lines.append("[data]Available[/data]  %d" % avail)
			body_lines.append("[data]Reserved[/data]  %d" % reserved)
			body_lines.append("[data]World Seed[/data]  %d" % resolved_world_seed)
			body_lines.append("Select a villager, then right-click to collect until depleted. Escape stops collection.")
			hud._show_inspection(eyebrow_str, title_str, detail_str, "\n".join(body_lines))

		_:
			var attrs = ""
			for key in snap.attributes:
				attrs += "[data]" + str(key) + "[/data]  " + str(snap.attributes[key]) + "\n"
			hud._show_inspection(String(snap.kind).capitalize(), "Entity ID %d" % entity_id, "Attributes", attrs)

func _update_building_visual(view: MeshInstance3D, record) -> void:
	if not view.has_meta("full_size"): return
	var full_size: Vector3 = view.get_meta("full_size")
	var base_elev: float = view.get_meta("base_elevation")
	var state = record.attributes.get("construction_state", "COMPLETED")
	var mat: StandardMaterial3D = view.material_override
	if mat == null:
		mat = StandardMaterial3D.new()
		view.material_override = mat

	var box: BoxMesh = view.mesh as BoxMesh
	if box == null: return

	var collider: CollisionShape3D = view.get_meta("collider", null)

	match str(state):
		"BLUEPRINT":
			var h := GopalaScaleStandard.number("building", "blueprint_height")
			box.size = Vector3(full_size.x, h, full_size.z)
			view.position.y = base_elev + h * 0.5
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.3, 0.6, 0.9, 0.5)
			if collider != null:
				collider.position.y = full_size.y * 0.5 - h * 0.5
		"WAITING_FOR_MATERIALS":
			var h := GopalaScaleStandard.number("building", "foundation_height")
			box.size = Vector3(full_size.x, h, full_size.z)
			view.position.y = base_elev + h * 0.5
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.85, 0.65, 0.2, 0.6)
			if collider != null:
				collider.position.y = full_size.y * 0.5 - h * 0.5
		"UNDER_CONSTRUCTION":
			var work_completed = float(record.attributes.get("work_completed", 0))
			var work_required = float(max(1, record.attributes.get("work_required", 1)))
			var progress = clampf(work_completed / work_required, 0.0, 1.0)
			var h = lerpf(GopalaScaleStandard.number("building", "frame_height"), full_size.y, progress)
			box.size = Vector3(full_size.x, h, full_size.z)
			view.position.y = base_elev + h * 0.5
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color = Color(0.75, 0.5, 0.25).lerp(Color(0.6, 0.4, 0.2), progress)
			if collider != null:
				collider.position.y = full_size.y * 0.5 - h * 0.5
		"COMPLETED":
			box.size = full_size
			view.position.y = base_elev + full_size.y * 0.5
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			var is_player: bool = view.get_meta("is_player", true)
			mat.albedo_color = Color(0.6, 0.4, 0.2) if is_player else Color(0.4, 0.2, 0.6)
			if collider != null:
				collider.position.y = 0.0

	var model := view.get_node_or_null("BuildingVisual") as GopalaBuildingModelView
	if model != null:
		model.update_stage(str(state), box.size.y * 0.5)
		if str(state) in ["COMPLETED", "UNDER_CONSTRUCTION"]:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.0

func _on_snapshot_committed(snapshot: GopalaSettlementSnapshot) -> void:
	var balances = snapshot.resource_balances
	for res_id in GopalaSimulationConfig.RESOURCE_IDS:
		hud.set_resource(res_id, balances.get(res_id,0))
	hud.set_tempo(snapshot.paused, snapshot.speed)
	if mvp_enabled: _update_mvp_summary()

	var registry_snap = simulation.entity_registry().registry_snapshot()

	# Prune destroyed/removed views
	var active_ids := {}
	for entity_snapshot in registry_snap.entities:
		active_ids[entity_snapshot.entity_id] = true
	var to_remove := []
	for eid in _built_views.keys():
		if not active_ids.has(eid):
			to_remove.append(eid)
	for eid in to_remove:
		if is_instance_valid(_built_views[eid]):
			_built_views[eid].queue_free()
		_built_views.erase(eid)
		_blocked_workers.erase(eid)

	# Spawn or update primitive views for buildings, villagers, and sources
	for entity_snapshot in registry_snap.entities:
		var entity_id = entity_snapshot.entity_id
		var record = entity_snapshot
		if not _built_views.has(entity_id):
			if record.kind == &"building":
				_spawn_primitive_building(record, entity_id)
			elif record.kind == &"villager":
				_spawn_primitive_villager(record, entity_id)
			elif record.kind == &"resource_source":
				_spawn_primitive_source(record, entity_id)
			elif record.kind == GopalaEntityKind.ANIMAL: _spawn_cattle(record)
			elif record.kind == GopalaEntityKind.ZONE: _spawn_pasture(record)
		if _built_views.has(entity_id):
			if record.kind == GopalaEntityKind.ANIMAL:
				_built_views[entity_id].position = Vector3(record.attributes.position_x,ground_height_at(record.attributes.position_x,record.attributes.position_z),record.attributes.position_z)
			elif record.kind == &"building":
				_update_building_visual(_built_views[entity_id], record)
			elif record.kind == &"villager":
				var px = record.attributes.get("position_x", 0.0)
				var pz = record.attributes.get("position_z", 0.0)
				var h = ground_height_at(px, pz)
				_built_views[entity_id].position = Vector3(px, h + GopalaScaleStandard.number("villager", "height") * 0.5, pz)
				var failure: String = str(record.attributes.get(&"movement_failure", ""))
				if str(record.attributes.get(&"movement_state", "")) == "BLOCKED":
					if _blocked_workers.get(entity_id, "") != failure:
						hud.notify("Route blocked", "Carried goods stay with the worker. Clear access to resume." if int(record.attributes.get(&"carried_amount",0)) > 0 else "Clear the obstruction or choose another destination.", "terra")
						_blocked_workers[entity_id] = failure
				else:
					_blocked_workers.erase(entity_id)
				var carried = record.attributes.get("carried_amount", 0)
				_update_villager_carry_visual(_built_views[entity_id], carried, StringName(record.attributes.get("carried_resource_id", "")))
				(_built_views[entity_id].get_node("WorkerVisual") as GopalaWorkerModelView).update_state(record.attributes, simulation.paused, float(simulation.speed))
			elif record.kind == &"resource_source":
				var exhausted = record.attributes.get("exhausted", false)
				_built_views[entity_id].visible = not exhausted
				var avail = record.attributes.get("available_amount", 5)
				var reserved = record.attributes.get("reserved_amount", 0)
				var is_stone: bool = str(record.attributes.get(&"resource_id", "")) == "stone"
				if is_stone:
					(_built_views[entity_id] as GopalaStonePatchView).update_amount(avail + reserved, int(record.attributes.get(&"initial_amount", 30)))
				elif _built_views[entity_id] is GopalaWaterSourceView:
					(_built_views[entity_id] as GopalaWaterSourceView).update_amount(avail + reserved,int(record.attributes.get(&"initial_amount",12)))
				elif _built_views[entity_id] is GopalaForagePatchView:
					(_built_views[entity_id] as GopalaForagePatchView).update_amount(avail + reserved,int(record.attributes.get(&"initial_amount",15)))
				else:
					(_built_views[entity_id] as GopalaTimberStandView).update_amount(avail + reserved, int(record.attributes.get(&"initial_amount", 5)))


	# Keep inspection updated live for selected entity
	var selected = simulation.selection_service().snapshot()
	if selected.state == GopalaSelectionSnapshot.State.ENTITY:
		_inspect_selected_entity(selected.selected_entity_id)

func _spawn_primitive_villager(record, entity_id: int) -> void:
	var view = MeshInstance3D.new()
	var box = CapsuleMesh.new()
	box.radius = GopalaScaleStandard.number("villager", "radius")
	box.height = GopalaScaleStandard.number("villager", "height")
	view.mesh = box
	var px = record.attributes.get("position_x", 0.0)
	var pz = record.attributes.get("position_z", 0.0)
	var h = ground_height_at(px, pz)
	view.position = Vector3(px, h + box.height * 0.5, pz)
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 0, 0, 0)
	view.material_override = mat
	add_child(view)

	var adapter = GopalaEntityViewAdapter3D.new()
	adapter.configure(simulation.entity_queries())
	adapter.bind_entity(entity_id)
	view.add_child(adapter)

	var body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	col.shape = box.create_trimesh_shape()
	body.add_child(col)
	adapter.add_child(body)
	
	var worker := GopalaWorkerModelView.new()
	view.add_child(worker)
	worker.build()
	worker.position.y = -box.height * 0.5
	worker.update_state(record.attributes, simulation.paused, float(simulation.speed))

	# Carry visual
	var carry = MeshInstance3D.new()
	carry.name = "CarryVisual"
	var timber_box = BoxMesh.new()
	timber_box.size = GopalaScaleStandard.carry_size("timber_carry")
	carry.mesh = timber_box
	var cmat = StandardMaterial3D.new()
	cmat.albedo_color = Color(0.8, 0.6, 0.2)
	carry.material_override = cmat
	carry.position = Vector3(0, GopalaScaleStandard.metres_to_world(0.4), GopalaScaleStandard.metres_to_world(0.3))
	carry.visible = false
	view.add_child(carry)

	_built_views[entity_id] = view

func _update_villager_carry_visual(view: Node3D, carried: int, resource_id: StringName = &"timber") -> void:
	var carry = view.get_node_or_null("CarryVisual")
	if carry != null:
		carry.visible = (carried > 0)
		carry.mesh.size = GopalaScaleStandard.carry_size("stone_carry" if resource_id == &"stone" else ("timber_carry" if resource_id == &"timber" else ("water_carry" if resource_id == &"water" else ("milk_carry" if resource_id == &"milk" else "forage_carry"))))
		carry.material_override.albedo_color = Color(0.48, 0.46, 0.43) if resource_id == &"stone" else GopalaForagePatchView.resource_color(resource_id)

func _spawn_stone_source(record, entity_id: int) -> void:
	var view := GopalaStonePatchView.new()
	var px: float = record.attributes.get(&"position_x", 0.0)
	var pz: float = record.attributes.get(&"position_z", 0.0)
	view.position = Vector3(px, ground_height_at(px, pz), pz)
	view.build(entity_id, ground_height_at, Vector2(px, pz))
	add_child(view)
	var adapter := GopalaEntityViewAdapter3D.new()
	adapter.configure(simulation.entity_queries())
	adapter.bind_entity(entity_id)
	view.add_child(adapter)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GopalaScaleStandard.number("stone_patch", "pick_width"), GopalaScaleStandard.number("stone_patch", "pick_height"), GopalaScaleStandard.number("stone_patch", "pick_width"))
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	body.add_child(shape)
	adapter.add_child(body)
	view.pick_shape = shape
	view.update_amount(int(record.attributes.get(&"available_amount", 0)) + int(record.attributes.get(&"reserved_amount", 0)), int(record.attributes.get(&"initial_amount", 30)))
	_built_views[entity_id] = view

func _spawn_forage_source(record, entity_id: int) -> void:
	var view = GopalaWaterSourceView.new() if record.attributes.resource_id in [&"water",&"milk"] else GopalaForagePatchView.new()
	var px: float = record.attributes.get(&"position_x",0.0)
	var pz: float = record.attributes.get(&"position_z",0.0)
	view.position = Vector3(px,ground_height_at(px,pz),pz)
	add_child(view)
	view.build(entity_id,resolved_world_seed,record.attributes.resource_id,ground_height_at,Vector2(px,pz))
	var adapter := GopalaEntityViewAdapter3D.new()
	adapter.configure(simulation.entity_queries())
	adapter.bind_entity(entity_id)
	view.add_child(adapter)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GopalaScaleStandard.number("water_source" if record.attributes.resource_id in [&"water",&"milk"] else "forage_patch","pick_width"),GopalaScaleStandard.number("water_source" if record.attributes.resource_id in [&"water",&"milk"] else "forage_patch","pick_height"),GopalaScaleStandard.number("water_source" if record.attributes.resource_id in [&"water",&"milk"] else "forage_patch","pick_width"))
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	body.add_child(shape)
	adapter.add_child(body)
	view.pick_shape = shape
	view.update_amount(int(record.attributes.get(&"available_amount",0))+int(record.attributes.get(&"reserved_amount",0)),int(record.attributes.get(&"initial_amount",15)))
	_built_views[entity_id] = view

func _spawn_primitive_source(record, entity_id: int) -> void:
	if str(record.attributes.get(&"resource_id", "")) == "stone":
		_spawn_stone_source(record, entity_id)
		return
	if record.attributes.get(&"resource_id") in [&"thatch",&"wild_food",&"fodder",&"water",&"milk"]:
		_spawn_forage_source(record,entity_id)
		return
	var view := GopalaTimberStandView.new()
	var px: float = record.attributes.get(&"position_x", 0.0)
	var pz: float = record.attributes.get(&"position_z", 0.0)
	view.position = Vector3(px, ground_height_at(px, pz), pz)
	add_child(view)
	view.build(entity_id, resolved_world_seed, ground_height_at, Vector2(px, pz))
	var adapter = GopalaEntityViewAdapter3D.new()
	adapter.configure(simulation.entity_queries())
	adapter.bind_entity(entity_id)
	view.add_child(adapter)
	var body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var tree_bounds := GopalaScaleStandard.bounds_in_parent(view.get_node("MeshChild"))
	shape.size = Vector3(maxf(tree_bounds.size.x, GopalaScaleStandard.number("timber_stand", "pick_width")), maxf(tree_bounds.size.y, GopalaScaleStandard.number("timber_stand", "pick_height")), maxf(tree_bounds.size.z, GopalaScaleStandard.number("timber_stand", "pick_width")))
	col.shape = shape
	col.position = Vector3(tree_bounds.get_center().x, tree_bounds.position.y + shape.size.y * 0.5, tree_bounds.get_center().z)
	view.pick_shape = col
	body.add_child(col)
	adapter.add_child(body)
	_built_views[entity_id] = view

func _spawn_primitive_building(record, entity_id: int) -> void:
	var def_id_attr = record.attributes.get("definition_id", "")
	var def = simulation.placement_service().get_building(StringName(def_id_attr))
	
	var is_player = record.attributes.has("construction_state")
	var size_x = 2.0
	var size_y = 2.0
	var col = Color(0.6, 0.4, 0.2)
	
	if not is_player:
		col = Color(0.4, 0.2, 0.6) # Scenario camp is purple
		if def != null:
			size_x = def.footprint.x * simulation.coordinate_service()._config.world_units_per_cell
			size_y = def.footprint.y * simulation.coordinate_service()._config.world_units_per_cell
		else:
			size_x = 4.0
			size_y = 4.0
	else:
		if def == null:
			push_error("No building def for: " + str(def_id_attr))
			return
		size_x = def.footprint.x * simulation.coordinate_service()._config.world_units_per_cell
		size_y = def.footprint.y * simulation.coordinate_service()._config.world_units_per_cell

	var cells = record.attributes.get("footprint_cells", [])
	var center_x = record.attributes.get("position_x", 0.0)
	var center_z = record.attributes.get("position_z", 0.0)
	if cells.size() > 0:
		var min_x = INF
		var max_x = -INF
		var min_z = INF
		var max_z = -INF
		for cell in cells:
			var center = simulation.coordinate_service().settlement_cell_to_world_xz(Vector2i(cell[0], cell[1]))
			min_x = min(min_x, center.x)
			max_x = max(max_x, center.x)
			min_z = min(min_z, center.y)
			max_z = max(max_z, center.y)
		center_x = (min_x + max_x) / 2.0
		center_z = (min_z + max_z) / 2.0

	var h = ground_height_at(center_x, center_z)

	var view = MeshInstance3D.new()
	var box = BoxMesh.new()
	if record.attributes.get("rotation", 0) == 1 or record.attributes.get("rotation", 0) == 3:
		var temp = size_x
		size_x = size_y
		size_y = temp
	box.size = Vector3(size_x, GopalaScaleStandard.number("planning", "grid_lift") if hud._selected_build == &"pasture" else GopalaScaleStandard.number("building", "height"), size_y)
	view.mesh = box
	view.position = Vector3(center_x, h + box.size.y * 0.5, center_z)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	view.material_override = mat
	add_child(view)

	view.set_meta("base_elevation", h)
	view.set_meta("full_size", box.size)
	view.set_meta("is_player", is_player)

	var adapter = GopalaEntityViewAdapter3D.new()
	adapter.configure(simulation.entity_queries())
	adapter.bind_entity(entity_id)
	view.add_child(adapter)

	var body = StaticBody3D.new()
	var collider = CollisionShape3D.new()
	var col_shape = BoxShape3D.new()
	col_shape.size = box.size
	collider.shape = col_shape
	body.add_child(collider)
	adapter.add_child(body)
	view.set_meta("collider", collider)

	var building_model := GopalaBuildingModelView.new()
	view.add_child(building_model)
	building_model.build(box.size, str(def_id_attr))
	_built_views[entity_id] = view
	_update_building_visual(view, record)

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	if not ("--capture-source" in args or "--capture-local" in args or "--capture-edge" in args or "--capture-forest" in args or "--capture-water" in args or "--capture-trees" in args):
		camera.zoom_by(0.84)
	for frame in range(20): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var suffix := "trees" if "--capture-trees" in args else "territory" if "--capture-territory" in args else "source" if "--capture-source" in args else "local" if "--capture-local" in args else "edge" if "--capture-edge" in args else "forest" if "--capture-forest" in args else "waterways" if "--capture-water" in args else "overview"
	var path := ProjectSettings.globalize_path("res://../reports/kathmandu-"+suffix+".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error!=OK: push_error("Kathmandu capture failed: "+error_string(error))
	get_tree().quit(0 if error==OK else 1)

func make_trees() -> void:
	var review: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/forest/review.json"))
	var forest_path := "res://data/forest/kathmandu_forest.scn"
	# The submitted candidate must be visible in the running scene so it can actually be
	# reviewed. Acceptance remains a separate editorial decision: only an accepted bake
	# is recorded in accepted_bake_sha256, but a hash-pinned submitted bake is safe to
	# present while its visual review is pending.
	var status := String(review.get("status", ""))
	var expected_hash := ""
	if status == "accepted":
		expected_hash = String(review.get("accepted_bake_sha256", ""))
	elif status == "pending_visual_review":
		expected_hash = String(review.get("submitted_bake_sha256", ""))
	if expected_hash.is_empty():
		push_warning("No reviewed or submitted forest bake is available; trees are disabled.")
		return
	if FileAccess.get_sha256(forest_path) != expected_hash:
		push_warning("Forest bake does not match its reviewed or submitted receipt; trees are disabled.")
		return
	if status != "accepted":
		print("FOREST_PENDING_VISUAL_REVIEW loading submitted bake: " + forest_path)
	var forest: Node3D = load(forest_path).instantiate()
	add_child(forest)
	tree_population = int(forest.get_meta("population"))
	sample_pine_height_m = float(forest.get_meta("sample_pine_height_m"))
	_generate_detail_vegetation()


func _generate_detail_vegetation() -> void:
	if detail_forest == null:
		return
	for child in detail_forest.get_children():
		child.queue_free()
	if hero_trees != null:
		for child in hero_trees.get_children():
			child.queue_free()

	var active_seed: int = resolved_world_seed

	var config_path := "res://data/forest/models.json"
	if not FileAccess.file_exists(config_path):
		return
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	var variants: Array = config.get("variants", [])
	if variants.is_empty():
		return

	var models := {}
	var conifer_ids: Array[String] = []
	var broadleaf_ids: Array[String] = []
	var scrub_ids: Array[String] = []

	for v: Dictionary in variants:
		var scene: PackedScene = load(v.path)
		if scene == null:
			continue
		var inst = scene.instantiate()
		var mesh: Mesh = null
		var bounds := AABB()
		for c in inst.get_children():
			if c is MeshInstance3D and c.mesh != null:
				mesh = c.mesh
				bounds = mesh.get_aabb()
				break
		inst.free()
		if mesh == null:
			continue
		var id: String = v.id
		models[id] = {"mesh": mesh, "bounds": bounds, "variant": v}
		if id.begins_with("Broad_Scrub"):
			scrub_ids.append(id)
		elif v.kind == "conifer":
			conifer_ids.append(id)
		else:
			broadleaf_ids.append(id)

	if models.is_empty():
		return

	# Shared material cache by plant category for zero shader thrashing
	var foliage_shader: Shader = load("res://assets/materials/valley_foliage.gdshader")
	var cat_materials: Dictionary = {}
	for cat in ["scrub", "fir_tall", "conifer", "oak", "default"]:
		var mat := ShaderMaterial.new()
		mat.shader = foliage_shader
		if cat == "scrub":
			mat.set_shader_parameter("trunk_color", Color(0.24, 0.16, 0.10))
			mat.set_shader_parameter("leaf_color", Color(0.18, 0.38, 0.14))
			mat.set_shader_parameter("leaf_highlight", Color(0.28, 0.52, 0.20))
			mat.set_shader_parameter("canopy_fraction", 0.08)
			mat.set_shader_parameter("canopy_blend", 0.16)
		elif cat == "fir_tall":
			mat.set_shader_parameter("trunk_color", Color(0.20, 0.13, 0.08))
			mat.set_shader_parameter("leaf_color", Color(0.08, 0.22, 0.10))
			mat.set_shader_parameter("leaf_highlight", Color(0.16, 0.34, 0.15))
			mat.set_shader_parameter("canopy_fraction", 0.15)
			mat.set_shader_parameter("canopy_blend", 0.20)
		elif cat == "conifer":
			mat.set_shader_parameter("trunk_color", Color(0.22, 0.14, 0.09))
			mat.set_shader_parameter("leaf_color", Color(0.10, 0.25, 0.12))
			mat.set_shader_parameter("leaf_highlight", Color(0.18, 0.38, 0.16))
			mat.set_shader_parameter("canopy_fraction", 0.14)
			mat.set_shader_parameter("canopy_blend", 0.18)
		elif cat == "oak":
			mat.set_shader_parameter("trunk_color", Color(0.25, 0.16, 0.10))
			mat.set_shader_parameter("leaf_color", Color(0.16, 0.36, 0.13))
			mat.set_shader_parameter("leaf_highlight", Color(0.26, 0.50, 0.20))
			mat.set_shader_parameter("canopy_fraction", 0.12)
			mat.set_shader_parameter("canopy_blend", 0.18)
		else:
			mat.set_shader_parameter("trunk_color", Color(0.24, 0.15, 0.09))
			mat.set_shader_parameter("leaf_color", Color(0.18, 0.38, 0.15))
			mat.set_shader_parameter("leaf_highlight", Color(0.30, 0.54, 0.22))
			mat.set_shader_parameter("canopy_fraction", 0.12)
			mat.set_shader_parameter("canopy_blend", 0.18)
		cat_materials[cat] = mat

	var rng := RandomNumberGenerator.new()
	rng.seed = active_seed

	var biome_noise := FastNoiseLite.new()
	biome_noise.seed = active_seed
	biome_noise.frequency = 0.016

	var patch_noise := FastNoiseLite.new()
	patch_noise.seed = active_seed + 317
	patch_noise.frequency = 0.048

	# Farthest Frontier style spatially divided MultiMesh chunks
	const CHUNK_SIZE := 20.0
	var chunk_batches: Dictionary = {}

	var grid_step := 1.25
	var min_coord := -180.0
	var max_coord := 180.0
	var cliff_cos := cos(deg_to_rad(38.0))
	var camp_pos := terrain.camp
	var test_forest_center := Vector2(10.0, -85.0)

	var x := min_coord
	while x <= max_coord:
		var z := min_coord
		while z <= max_coord:
			var jx := x + rng.randf_range(-0.45, 0.45)
			var jz := z + rng.randf_range(-0.45, 0.45)
			z += grid_step

			if absf(jx) > 192.0 or absf(jz) > 192.0:
				continue

			var dist_camp := Vector2(jx, jz).distance_to(camp_pos)
			if dist_camp < 5.8:
				continue

			var dist_test := Vector2(jx, jz).distance_to(test_forest_center)
			var r_dist := terrain.river_distance(jx, jz)

			# Keep river channels 100% clear (Bagmati half-width is 32m)
			if r_dist < 38.0:
				continue

			var norm := terrain.normal_at(jx, jz, true)
			if norm.y < cliff_cos:
				continue

			var elev := terrain.elevation_at(jx, jz)
			var b_val := biome_noise.get_noise_2d(jx, jz)
			var p_val := patch_noise.get_noise_2d(jx, jz)

			# Farthest Frontier zone selection: prioritize settlement domain, river corridor, and mountain copses
			var in_settlement_zone := (dist_camp <= 48.0)
			var in_river_zone := (r_dist <= 85.0)
			var in_test_zone := (dist_test <= 30.0)
			var in_forest_biome := (b_val > -0.05) or (elev > 1450.0)

			# Skip barren or far distant unpopulated areas to maximize FPS
			if not (in_settlement_zone or in_river_zone or in_test_zone or in_forest_biome):
				continue

			var spawn := false
			var undergrowth := false
			var cluster_count := 1

			if in_river_zone:
				spawn = (p_val > -0.20) and (rng.randf() < 0.65)
				undergrowth = rng.randf() < 0.30
				if spawn and rng.randf() < 0.40:
					cluster_count = 2
			elif in_settlement_zone:
				spawn = (p_val > -0.12) and (rng.randf() < 0.55)
				undergrowth = rng.randf() < 0.25
				if spawn and rng.randf() < 0.45:
					cluster_count = 2
			elif in_test_zone:
				spawn = (p_val > -0.25) and (rng.randf() < 0.70)
				undergrowth = rng.randf() < 0.30
				if spawn and rng.randf() < 0.50:
					cluster_count = 2 if rng.randf() < 0.60 else 3
			elif in_forest_biome:
				spawn = (p_val > -0.15) and (rng.randf() < 0.58)
				undergrowth = rng.randf() < 0.25
				if spawn and rng.randf() < 0.35:
					cluster_count = 2

			if not spawn:
				continue

			for c_idx in cluster_count:
				var cx := jx
				var cz := jz
				if c_idx > 0:
					cx += rng.randf_range(-0.42, 0.42)
					cz += rng.randf_range(-0.42, 0.42)
					if terrain.river_distance(cx, cz) < 38.0 or absf(cx) > 192.0 or absf(cz) > 192.0:
						continue

				var is_sub_undergrowth := undergrowth or (c_idx > 1)
				var chosen_id := ""
				if is_sub_undergrowth and not scrub_ids.is_empty():
					chosen_id = scrub_ids[rng.randi_range(0, scrub_ids.size() - 1)]
				elif in_river_zone:
					var choices: Array[String] = broadleaf_ids if not broadleaf_ids.is_empty() else scrub_ids
					if not choices.is_empty():
						chosen_id = choices[rng.randi_range(0, choices.size() - 1)]
				elif elev < 1450.0:
					if rng.randf() < 0.75 and not broadleaf_ids.is_empty():
						chosen_id = broadleaf_ids[rng.randi_range(0, broadleaf_ids.size() - 1)]
					elif not conifer_ids.is_empty():
						chosen_id = conifer_ids[rng.randi_range(0, conifer_ids.size() - 1)]
				elif elev < 1900.0:
					if rng.randf() < 0.55 and not conifer_ids.is_empty():
						chosen_id = conifer_ids[rng.randi_range(0, conifer_ids.size() - 1)]
					elif not broadleaf_ids.is_empty():
						chosen_id = broadleaf_ids[rng.randi_range(0, broadleaf_ids.size() - 1)]
				else:
					if not conifer_ids.is_empty():
						chosen_id = conifer_ids[rng.randi_range(0, conifer_ids.size() - 1)]
					elif not broadleaf_ids.is_empty():
						chosen_id = broadleaf_ids[rng.randi_range(0, broadleaf_ids.size() - 1)]

				if chosen_id.is_empty():
					chosen_id = variants[rng.randi_range(0, variants.size() - 1)].id

				var model_info: Dictionary = models[chosen_id]
				var bounds: AABB = model_info.bounds

				var height_units := 0.45
				if chosen_id.begins_with("Broad_Scrub"):
					height_units = rng.randf_range(0.12, 0.22)
				elif chosen_id.begins_with("Fir_Tall"):
					height_units = rng.randf_range(0.55, 0.80)
				elif chosen_id.begins_with("Fir") or chosen_id.begins_with("Pine"):
					height_units = rng.randf_range(0.40, 0.60)
				elif chosen_id.begins_with("Broad_Oak"):
					height_units = rng.randf_range(0.35, 0.52)
				else:
					height_units = rng.randf_range(0.30, 0.44)

				var factor := height_units / bounds.size.y
				var yaw := rng.randf_range(0.0, TAU)
				var c_norm := terrain.normal_at(cx, cz, true)
				var tilt_x := c_norm.z * 0.08
				var tilt_z := -c_norm.x * 0.08

				var t := Transform3D()
				t.basis = Basis.from_euler(Vector3(tilt_x, yaw, tilt_z)).scaled(Vector3.ONE * factor)
				t.origin.x = cx
				t.origin.z = cz
				t.origin.y = terrain.height_at(cx, cz) - bounds.position.y * factor

				# Assign to spatial chunk for frustum culling
				var tile_x := floori(cx / CHUNK_SIZE)
				var tile_z := floori(cz / CHUNK_SIZE)
				var chunk_key := "%s_%d_%d" % [chosen_id, tile_x, tile_z]
				if not chunk_batches.has(chunk_key):
					chunk_batches[chunk_key] = {
						"id": chosen_id,
						"tile_x": tile_x,
						"tile_z": tile_z,
						"transforms": [] as Array[Transform3D],
						"min_y": INF,
						"max_y": -INF
					}
				var b_entry: Dictionary = chunk_batches[chunk_key]
				b_entry.transforms.append(t)
				b_entry.min_y = minf(b_entry.min_y, t.origin.y)
				b_entry.max_y = maxf(b_entry.max_y, t.origin.y + bounds.size.y * factor)
		x += grid_step

	# Instantiate spatially chunked MultiMeshes
	for chunk_key: String in chunk_batches:
		var b_entry: Dictionary = chunk_batches[chunk_key]
		var id: String = b_entry.id
		var list: Array[Transform3D] = b_entry.transforms
		if list.is_empty():
			continue

		var group := MultiMeshInstance3D.new()
		group.name = "Chunk_" + chunk_key
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = models[id].mesh
		multi.instance_count = list.size()
		for i in list.size():
			multi.set_instance_transform(i, list[i])
		group.multimesh = multi

		# Merge transformed mesh bounds: crowns and satellites can cross tile borders.
		var cull_bounds: AABB = list[0] * multi.mesh.get_aabb()
		for transform in list:
			cull_bounds = cull_bounds.merge(transform * multi.mesh.get_aabb())
		group.custom_aabb = cull_bounds.grow(GopalaScaleStandard.number("camera", "culling_padding"))
		# Orthographic visibility follows its frustum, not distance to the camera.
		group.visibility_range_end = 0.0

		# Shadow optimization: undergrowth doesn't need dynamic shadow cascades
		if id.begins_with("Broad_Scrub"):
			group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

		var cat := "scrub" if id.begins_with("Broad_Scrub") else "fir_tall" if id.begins_with("Fir_Tall") else "conifer" if (id.begins_with("Fir") or id.begins_with("Pine")) else "oak" if id.begins_with("Broad_Oak") else "default"
		group.material_override = cat_materials.get(cat, cat_materials["default"])
		group.lod_bias = 0.8
		detail_forest.add_child(group)

	_generate_hero_trees(models, broadleaf_ids, conifer_ids, rng)
	_generate_detail_stones(active_seed, rng)


func _generate_hero_trees(models: Dictionary, broadleaf_ids: Array[String], conifer_ids: Array[String], rng: RandomNumberGenerator) -> void:
	if hero_trees == null:
		return
	var landmark_points: Array[Vector3] = [
		Vector3(terrain.camp.x + 8.5, 0.0, terrain.camp.y + 7.2),
		Vector3(terrain.camp.x - 7.8, 0.0, terrain.camp.y - 8.5),
		Vector3(terrain.camp.x + 14.0, 0.0, terrain.camp.y - 12.0),
		Vector3(-95.0, 0.0, 18.0),
		Vector3(-92.0, 0.0, 24.0),
		Vector3(10.0, 0.0, -85.0),
		Vector3(14.0, 0.0, -80.0),
		Vector3(terrain.camp.x - 18.0, 0.0, terrain.camp.y + 22.0),
		Vector3(-45.0, 0.0, 32.0),
		Vector3(-60.0, 0.0, -25.0)
	]

	var fallback_key: String = ""
	for k in models.keys():
		fallback_key = String(k)
		break

	var hero_id: String = "Broad_Oak_D" if models.has("Broad_Oak_D") else (broadleaf_ids[0] if not broadleaf_ids.is_empty() else fallback_key)
	var hero_conifer: String = "Fir_Tall_A" if models.has("Fir_Tall_A") else (conifer_ids[0] if not conifer_ids.is_empty() else fallback_key)

	for i in landmark_points.size():
		var pt: Vector3 = landmark_points[i]
		var id: String = hero_id if (i % 2 == 0) else hero_conifer
		if not models.has(id):
			continue
		var model_info: Dictionary = models[id]
		var mesh: Mesh = model_info.mesh
		var bounds: AABB = model_info.bounds
		var v_info: Dictionary = model_info.variant

		var mi := MeshInstance3D.new()
		mi.name = "HeroTree_%d" % i
		mi.mesh = mesh
		var hero_mat := ShaderMaterial.new()
		hero_mat.shader = load("res://assets/materials/valley_foliage.gdshader")
		hero_mat.set_shader_parameter("model_height", bounds.size.y)
		hero_mat.set_shader_parameter("model_base_y", bounds.position.y)
		hero_mat.set_shader_parameter("trunk_color", Color(0.24, 0.15, 0.09))
		hero_mat.set_shader_parameter("leaf_color", Color(0.16, 0.36, 0.13))
		hero_mat.set_shader_parameter("leaf_highlight", Color(0.26, 0.50, 0.20))
		hero_mat.set_shader_parameter("canopy_fraction", 0.14)
		hero_mat.set_shader_parameter("canopy_blend", 0.20)
		mi.material_override = hero_mat

		var hero_height := rng.randf_range(0.85, 1.25)
		var factor := hero_height / bounds.size.y
		var yaw := rng.randf_range(0.0, TAU)
		mi.scale = Vector3.ONE * factor
		mi.rotation = Vector3(0, yaw, 0)
		var y := terrain.height_at(pt.x, pt.z) - bounds.position.y * factor
		mi.position = Vector3(pt.x, y, pt.z)
		hero_trees.add_child(mi)


func _seed_forest_resource_stands() -> void:
	var registry = simulation.entity_registry()
	if registry == null:
		return
	# Seeding only initializes a world. Repeated calls cannot restore harvested stock.
	if simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE).any(func(source): return source.attributes.has(&"scatter_seed")):
		return
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/resource_distribution.json"))
	var all_rivers := GopalaStoneScatter.river_segments(terrain)
	var river_segments: Array[Dictionary] = []
	var local_region := Rect2(terrain.camp - Vector2.ONE * 2.0, Vector2.ONE * 4.0)
	for segment in all_rivers:
		if local_region.intersects(segment.bounds):
			river_segments.append(segment)
	for resource_id in GopalaSimulationCommand.COLLECTIBLE_RESOURCES:
		if not config.has(str(resource_id)): continue
		var profile: Dictionary = config[str(resource_id)]
		var deposits := GopalaStoneScatter.generate(terrain.camp, resolved_world_seed,
			func(pos: Vector2) -> bool:
				if terrain.river_distance(pos.x, pos.y) < 38.0 or terrain.normal_at(pos.x, pos.y, true).y < cos(deg_to_rad(35.0)) or not GopalaStoneScatter.outside_displayed_water(pos, river_segments):
					return false
				for sample in range(1, ceili(pos.distance_to(terrain.camp) / GopalaScaleStandard.metres_to_world(2.0)) + 1):
					var point := terrain.camp.move_toward(pos, float(sample) * GopalaScaleStandard.metres_to_world(2.0))
					if not GopalaStoneScatter.outside_displayed_water(point, river_segments):
						return false
				for source in simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE):
					var clearance: float = float(profile.get("cross_resource_spacing_metres",config["cross_resource_spacing_metres"]))
					if source.attributes.get(&"resource_id") == &"timber": clearance = maxf(clearance,float(profile.get("timber_clearance_metres",clearance)))
					if pos.distance_to(Vector2(source.attributes.get(&"position_x", 0.0), source.attributes.get(&"position_z", 0.0))) < GopalaScaleStandard.metres_to_world(clearance):
						return false
				return true, int(profile["count"]), profile)
		for deposit in deposits:
			registry.create_entity(GopalaEntityKind.RESOURCE_SOURCE, {
				&"resource_id": resource_id,
				&"available_amount": deposit.amount,
				&"initial_amount": deposit.amount,
				&"reserved_amount": 0,
				&"position_x": deposit.position.x,
				&"position_z": deposit.position.y,
				&"gatherable": true,
				&"exhausted": false,
				&"scatter_seed": resolved_world_seed
			})


func _generate_detail_stones(active_seed: int, rng: RandomNumberGenerator) -> void:
	if detail_stones == null:
		detail_stones = get_node_or_null("DetailStones")
	if detail_stones == null:
		detail_stones = Node3D.new()
		detail_stones.name = "DetailStones"
		add_child(detail_stones)
	for child in detail_stones.get_children():
		child.queue_free()

	var lr_scene: PackedScene = load("res://assets/models/stone_scatter/large_rock.glb")
	var sr_scene: PackedScene = load("res://assets/models/stone_scatter/small_rock.glb")
	if lr_scene == null or sr_scene == null:
		return
	var lr_inst = lr_scene.instantiate()
	var sr_inst = sr_scene.instantiate()
	var lr_mesh: Mesh = null
	var sr_mesh: Mesh = null
	for c in lr_inst.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			lr_mesh = (c as MeshInstance3D).mesh
			break
	for c in sr_inst.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			sr_mesh = (c as MeshInstance3D).mesh
			break
	lr_inst.free()
	sr_inst.free()
	if lr_mesh == null or sr_mesh == null:
		return

	var rock_material = load("res://assets/models/stone_scatter/m_rock.tres")
	if rock_material == null:
		var def_mat := StandardMaterial3D.new()
		def_mat.albedo_color = Color(0.44, 0.41, 0.39)
		rock_material = def_mat

	var stone_noise := FastNoiseLite.new()
	stone_noise.seed = active_seed + 11927
	stone_noise.frequency = 0.032

	var patch_noise := FastNoiseLite.new()
	patch_noise.seed = active_seed + 5519
	patch_noise.frequency = 0.075

	const CHUNK_SIZE := 20.0
	var chunk_batches: Dictionary = {}

	var grid_step := 2.5
	var min_coord := -170.0
	var max_coord := 170.0
	var cliff_cos := cos(deg_to_rad(45.0))
	var camp_pos := terrain.camp

	var x := min_coord
	while x <= max_coord:
		var z := min_coord
		while z <= max_coord:
			var jx := x + rng.randf_range(-0.8, 0.8)
			var jz := z + rng.randf_range(-0.8, 0.8)
			z += grid_step

			if absf(jx) > 185.0 or absf(jz) > 185.0:
				continue

			var dist_camp := Vector2(jx, jz).distance_to(camp_pos)
			if dist_camp < 6.0:
				continue

			var r_dist := terrain.river_distance(jx, jz)
			if r_dist < 38.0:
				continue

			var norm := terrain.normal_at(jx, jz, true)
			if norm.y < cliff_cos:
				continue

			var s_val := stone_noise.get_noise_2d(jx, jz)
			var p_val := patch_noise.get_noise_2d(jx, jz)
			var elev := terrain.elevation_at(jx, jz)

			# Farthest Frontier style rock distribution:
			# Rocky hillsides (exposed bedrock), river gravel banks, mountain slopes, and settlement clearings
			var in_rocky_slope := (norm.y < 0.94 and s_val > -0.15)
			var in_river_bank := (r_dist >= 40.0 and r_dist <= 75.0 and p_val > 0.12)
			var in_highlands := (elev > 1460.0 and s_val > -0.05)
			var in_camp_field := (dist_camp <= 45.0 and s_val > 0.08 and p_val > -0.10)
			var in_general_patch := (s_val > 0.22)

			if not (in_rocky_slope or in_river_bank or in_highlands or in_camp_field or in_general_patch):
				continue

			var cluster_seed_prob := 0.75 if (in_camp_field or in_river_bank) else 0.50
			if rng.randf() > cluster_seed_prob:
				continue

			var satellite_count := rng.randi_range(1, 3) if rng.randf() < 0.70 else 0

			# 1. Decorative loose stone, normalized from mesh dimensions.
			var main_yaw := rng.randf_range(0.0, TAU)
			var up := norm.lerp(Vector3.UP, 0.6).normalized()
			var right := Vector3(cos(main_yaw), 0, sin(main_yaw)).slide(up).normalized()
			var forward := up.cross(right).normalized()
			var main_basis := Basis(right, up, forward)
			var main_bounds: AABB = Transform3D(main_basis, Vector3.ZERO) * lr_mesh.get_aabb()
			var main_scale := GopalaScaleStandard.factor_for_width(main_bounds, rng.randf_range(GopalaScaleStandard.number("stone_scenery", "width_min"), GopalaScaleStandard.number("stone_scenery", "width_max")))
			var my := terrain.height_at(jx, jz) - main_bounds.position.y * main_scale
			var tx := int(floor(jx / CHUNK_SIZE))
			var tz := int(floor(jz / CHUNK_SIZE))
			var lr_key := "large_rock_%d_%d" % [tx, tz]

			if not chunk_batches.has(lr_key):
				chunk_batches[lr_key] = {
					"id": "large_rock",
					"tile_x": tx,
					"tile_z": tz,
					"transforms": [],
					"min_y": my,
					"max_y": my
				}
			var lr_entry: Dictionary = chunk_batches[lr_key]
			lr_entry.min_y = minf(lr_entry.min_y, my)
			lr_entry.max_y = maxf(lr_entry.max_y, my + main_bounds.end.y * main_scale)

			var t := Transform3D(
				Basis(right * main_scale, up * main_scale, forward * main_scale),
				Vector3(jx, my, jz)
			)
			lr_entry.transforms.append(t)

			# 2. Satellite small rocks
			for s in satellite_count:
				var s_rad := rng.randf_range(0.35, 1.2)
				var s_ang := rng.randf_range(0.0, TAU)
				var sx := jx + cos(s_ang) * s_rad
				var sz := jz + sin(s_ang) * s_rad
				if absf(sx) > 185.0 or absf(sz) > 185.0 or terrain.river_distance(sx, sz) < 38.0:
					continue
				var s_norm := terrain.normal_at(sx, sz, true)
				var s_yaw := rng.randf_range(0.0, TAU)
				var s_up := s_norm.lerp(Vector3.UP, 0.5).normalized()
				var s_right := Vector3(cos(s_yaw), 0, sin(s_yaw)).slide(s_up).normalized()
				var s_forward := s_up.cross(s_right).normalized()
				var small_bounds: AABB = Transform3D(Basis(s_right, s_up, s_forward), Vector3.ZERO) * sr_mesh.get_aabb()
				var s_scale := GopalaScaleStandard.factor_for_width(small_bounds, rng.randf_range(GopalaScaleStandard.number("stone_scenery", "satellite_width_min"), GopalaScaleStandard.number("stone_scenery", "satellite_width_max")))
				var sy := terrain.height_at(sx, sz) - small_bounds.position.y * s_scale
				var stx := int(floor(sx / CHUNK_SIZE))
				var stz := int(floor(sz / CHUNK_SIZE))
				var sr_key := "small_rock_%d_%d" % [stx, stz]

				if not chunk_batches.has(sr_key):
					chunk_batches[sr_key] = {
						"id": "small_rock",
						"tile_x": stx,
						"tile_z": stz,
						"transforms": [],
						"min_y": sy,
						"max_y": sy
					}
				var sr_entry: Dictionary = chunk_batches[sr_key]
				sr_entry.min_y = minf(sr_entry.min_y, sy)
				sr_entry.max_y = maxf(sr_entry.max_y, sy + small_bounds.end.y * s_scale)

				var st_trans := Transform3D(
					Basis(s_right * s_scale, s_up * s_scale, s_forward * s_scale),
					Vector3(sx, sy, sz)
				)
				sr_entry.transforms.append(st_trans)
		x += grid_step

	for b_key in chunk_batches:
		var b_entry: Dictionary = chunk_batches[b_key]
		var id: String = b_entry.id
		var list: Array = b_entry.transforms
		if list.is_empty():
			continue

		var group := MultiMeshInstance3D.new()
		group.name = "Stones_%s" % b_key
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = lr_mesh if id == "large_rock" else sr_mesh
		multi.instance_count = list.size()
		for i in list.size():
			multi.set_instance_transform(i, list[i])
		group.multimesh = multi

		# Merge transformed mesh bounds: crowns and satellites can cross tile borders.
		var cull_bounds: AABB = list[0] * multi.mesh.get_aabb()
		for transform in list:
			cull_bounds = cull_bounds.merge(transform * multi.mesh.get_aabb())
		group.custom_aabb = cull_bounds.grow(GopalaScaleStandard.number("camera", "culling_padding"))
		# Orthographic visibility follows its frustum, not distance to the camera.
		group.visibility_range_end = 0.0

		if id == "small_rock":
			group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

		group.material_override = rock_material
		group.lod_bias = 0.8
		detail_stones.add_child(group)

func _save_context() -> Dictionary:
	var fingerprints := {}
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	for category in ["resources", "buildings", "zones"]:
		for path in catalog[category]: fingerprints[path] = FileAccess.get_sha256(path)
	for name in ["kathmandu.json","kathmandu-ground-height.f32","kathmandu-river-distance.f32"]:
		fingerprints[name] = FileAccess.get_sha256(GopalaKathmanduTerrain.DIRECTORY + name)
	return {"world_seed": resolved_world_seed, "content": fingerprints,
		"standards": FileAccess.get_sha256("res://data/standards/world_scale.json"),
		"catalog": FileAccess.get_sha256("res://data/catalog.json"),
		"world": "kathmandu_local_v1", "mvp":mvp_enabled,"mvp_policy":FileAccess.get_sha256(GopalaSurvivalService.POLICY_PATH)}

func _update_mvp_summary() -> void:
	var workers := simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)
	var housed := workers.filter(func(w): return int(w.attributes.get(&"home_id",0)) > 0).size()
	var healthy := workers.filter(func(w): return int(w.attributes.get(&"health",100)) >= 50).size()
	var food_minutes := float(simulation.resource_amount(&"wild_food")+simulation.resource_amount(&"milk")) * float(simulation._survival_service.policy.meal_interval_ticks) / (60.0*maxi(1,workers.size()))
	var water_minutes := float(simulation.resource_amount(&"water")) * float(simulation._survival_service.policy.drink_interval_ticks) / (60.0*maxi(1,workers.size()))
	var scenarios := simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.SETTLEMENT).filter(func(e): return e.attributes.get(&"survival_enabled",false))
	var objective := "Build the six structures, two homes and pasture. Assign supply jobs, a herder and milk carrier."
	if not scenarios.is_empty():
		var meta: Dictionary = scenarios[0].attributes
		objective = "%s · %d / 15 min\n%s" % [str(meta.get(&"objective_state",&"BUILD_SETTLEMENT")).replace("_"," ").capitalize(),int(meta.get(&"stable_ticks",0))/60,str(meta.get(&"objective_reason",objective))]
	var cows := simulation._herd_service.animals()
	var grazing := 0
	for pasture in simulation._herd_service.pastures(): grazing += int(pasture.attributes.grazing_available)
	var milk := 0
	for cow in cows: milk += int(cow.attributes.get(&"milk_produced",0))
	hud.set_mvp_summary("Healthy %d/%d · Housed %d/%d\nFood ~%.1f min · Water ~%.1f min\nCattle %d · Grazing %d · Milk made %d\n\n%s" % [healthy,workers.size(),housed,workers.size(),food_minutes,water_minutes,cows.size(),grazing,milk,objective])

func save_settlement(path: String = SAVE_PATH) -> bool:
	if mvp_enabled and path == SAVE_PATH: path = "user://saves/mvp.json"
	var state := _save_service.capture(simulation, _save_context())
	var ok := _save_service.write(path, state)
	hud.notify("Settlement saved" if ok else "Save failed", "Worker tasks and goods preserved · F9 to load" if ok else _save_service.error)
	return ok

func load_settlement(path: String = SAVE_PATH) -> bool:
	if mvp_enabled and path in [SAVE_PATH,SAVE_PATH+".bak"]: path = "user://saves/mvp.json"+(".bak" if path.ends_with(".bak") else "")
	var state := _save_service.read(path)
	if state.is_empty():
		hud.notify("Load failed", _save_service.error)
		return false
	var restored := _save_service.restore(state, simulation, _save_context())
	if restored == null:
		hud.notify("Load failed", _save_service.error)
		return false
	# Every query adapter is rebuilt against the new authority. Old node caches
	# cannot survive reused IDs or stale placement/selection references.
	var previous := simulation
	previous.set_physics_process(false)
	remove_child(previous)
	simulation = restored
	restored.name = "SettlementSimulation"
	add_child(restored)
	_picker = GopalaEntityPickResolver3D.new()
	_picker.configure(restored.entity_queries())
	for view in _built_views.values():
		if is_instance_valid(view):
			remove_child(view)
			view.queue_free()
	_built_views.clear()
	_blocked_workers.clear()
	hud.clear_build()
	hud.hide_inspection()
	selection.visible = false
	_placement_ghost.visible = false
	_placement_outline.visible = false
	restored.command_processed.connect(_on_command_processed)
	restored.snapshot_committed.connect(_on_snapshot_committed)
	_on_snapshot_committed(restored.snapshot())
	previous.queue_free()
	focus_camp()
	hud.notify("Settlement loaded", "Resources, construction and worker tasks restored")
	return true

func _spawn_cattle(record):
	var view := GopalaCattleView.new()
	view.name = "Cattle_%d" % record.entity_id
	add_child(view)
	_built_views[record.entity_id] = view
	var body := StaticBody3D.new()
	body.collision_layer = 16
	var adapter := GopalaEntityViewAdapter3D.new()
	adapter.configure(simulation.entity_queries())
	adapter.bind_entity(record.entity_id)
	view.add_child(adapter)
	adapter.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GopalaScaleStandard.number("cattle","pick_width"),GopalaScaleStandard.number("cattle","height"),GopalaScaleStandard.number("cattle","pick_length"))
	shape.shape = box
	shape.position.y = box.size.y*0.5
	body.add_child(shape)
func _spawn_pasture(record):
	var view := MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	var step: float = simulation.coordinate_service()._config.world_units_per_cell
	for row in record.attributes.zone_cells:
		var center := simulation.coordinate_service().settlement_cell_to_world_xz(Vector2i(row[0],row[1]))
		var corners := [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]
		for i in 4:
			for corner in [corners[i],corners[(i+1)%4]]:
				var location: Vector2 = center+corner*step
				surface.add_vertex(Vector3(location.x,ground_height_at(location.x,location.y)+GopalaScaleStandard.number("planning","grid_lift"),location.y))
	view.mesh = surface.commit()
	view.material_override = line_material(Color("b7c274"))
	add_child(view)
	_built_views[record.entity_id] = view
