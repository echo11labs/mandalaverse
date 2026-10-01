@tool
extends "res://addons/waterways/river_manager.gd"
## Waterways mesh/UV2 layout with GOPALA terrain dressing and CPU flow-map baking.
## Flow and shore masks describe an artistic surface, not a discharge simulation.
const WATER_SHADER = preload("res://assets/materials/terrain_river.gdshader")
const SURFACE_LIFT := 0.045
const SAMPLE_SPACING := 0.16
@export var source_id := ""
@export var river_name := ""
@export var covered := false
@export var underground := false
var terrain: GopalaKathmanduTerrain

static func is_hidden_tag(value: Variant) -> bool:
	return str(value).to_lower() in ["true", "yes", "1", "culvert", "building_passage"]

static func half_width(reach: Dictionary) -> float:
	# Deliberately enlarged display widths, in world units. Not surveyed banks.
	return 0.32 if reach.name == "Bagmati" else 0.22 if reach.kind == "river" else 0.10

func configure(reach: Dictionary, model: GopalaKathmanduTerrain) -> void:
	terrain = model
	source_id = reach.id
	river_name = reach.name
	covered = is_hidden_tag(reach.get("covered", false))
	underground = is_hidden_tag(reach.get("tunnel", false))
	name = source_id.replace("/", "_")
	curve = Curve3D.new()
	curve.bake_interval = SAMPLE_SPACING * 0.25
	widths.clear()
	for point in reach.points:
		var position := Vector3(point[0], model.height_at(point[0], point[2]), point[2])
		if curve.point_count > 0 and position.distance_to(curve.get_point_position(curve.point_count - 1)) < 0.00001:
			continue
		# Zero handles preserve the mapped polyline, avoiding Bezier overshoot at banks.
		curve.add_point(position)
		widths.append(half_width(reach))
	shape_step_width_divs = 2
	visible = not covered and not underground

func _generate_river() -> void:
	if terrain == null:
		terrain = GopalaKathmanduTerrain.new()
		terrain.load_data()
	_steps = maxi(1, ceili(curve.get_baked_length() / SAMPLE_SPACING))
	var width_values := WaterHelperMethods.generate_river_width_values(curve, _steps, shape_step_length_divs, shape_step_width_divs, widths)
	var generated := WaterHelperMethods.generate_river_mesh(curve, _steps, shape_step_length_divs, shape_step_width_divs, shape_smoothness, width_values)
	var arrays := generated.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for i in vertices.size():
		vertices[i].y = terrain.height_at(vertices[i].x, vertices[i].z) + SURFACE_LIFT
		# One longitudinal UV unit is one world unit, regardless of tessellation.
		uv[i].y *= curve.get_baked_length() / float(_steps)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	# Tight mapped hairpins can fold a strip quad. Normalize each triangle's
	# winding after dressing so back-facing normals do not darken the surface.
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i + 1]]
		var c := vertices[indices[i + 2]]
		if (b - a).cross(c - a).y > 0.0:
			var swap := indices[i + 1]
			indices[i + 1] = indices[i + 2]
			indices[i + 2] = swap
	arrays[Mesh.ARRAY_INDEX] = indices
	var draped := ArrayMesh.new()
	draped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new()
	surface.create_from(draped, 0)
	surface.generate_normals()
	surface.generate_tangents()
	mesh_instance.mesh = surface.commit()
	_material.shader = WATER_SHADER
	mesh_instance.mesh.surface_set_material(0, _material)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_uv2_sides = WaterHelperMethods.calculate_side(_steps)
	_generate_flowmap(0.0)

func _generate_flowmap(_requested_resolution: float) -> void:
	# Each Waterways UV2 tile holds a curve step. Bake 8 texels across each tile,
	# including its two-tile margin. CPU baking also works in headless verification.
	var tile_size := 8
	var resolution := (_uv2_sides + 2) * tile_size
	var flow := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	var distance := Image.create(resolution, resolution, false, Image.FORMAT_RG8)
	for x in resolution:
		var across := float(x % tile_size) / float(tile_size - 1)
		var shore := absf(across * 2.0 - 1.0)
		for y in resolution:
			var phase := fposmod(float(y) * 0.173 + float(x / tile_size) * 0.137, 1.0)
			flow.set_pixel(x, y, Color(0.5, 0.82, smoothstep(0.55, 1.0, shore), phase))
			distance.set_pixel(x, y, Color(shore, 0.5, 0.0))
	flow_foam_noise = ImageTexture.create_from_image(flow)
	dist_pressure = ImageTexture.create_from_image(distance)
	valid_flowmap = true
	set_materials("i_flowmap", flow_foam_noise)
	set_materials("i_distmap", dist_pressure)
	set_materials("i_valid_flowmap", true)
	set_materials("i_uv2_sides", _uv2_sides)
	progress_notified.emit(1.0, "finished")
