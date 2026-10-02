extends SceneTree
## Bake external tree models using ProtonScatter's placement modifiers.
## This script assembles imported meshes; it creates no tree geometry.
## Regional forest only (70m spacing). Detail layer (18m) is now handled by
## EZTreeDraw at runtime via ez_tree_profiles.json.
const CONFIG := "res://data/forest/models.json"
const OUTPUT := "res://data/forest/kathmandu_forest.scn"
const RECEIPT := "res://data/forest/bake-receipt.json"
const GridModifier := preload("res://addons/proton_scatter/src/modifiers/create_inside_grid.gd")
const JitterModifier := preload("res://addons/proton_scatter/src/modifiers/randomize_transforms.gd")
const MergeHelper := preload("res://addons/proton_scatter/src/common/scatter_util.gd")
var terrain := GopalaKathmanduTerrain.new()
var population := 0
var variant_counts := {}
var sample_pine_height_m := 0.0

func _initialize() -> void:
	build.call_deferred()

func make_domain(center: Vector2, extent: Vector2, seed_value: int) -> ProtonScatter:
	var scatter := ProtonScatter.new()
	scatter.global_seed = seed_value
	scatter.force_rebuild_on_load = false
	scatter.enable_updates_in_game = false
	var shape := ProtonScatterShape.new()
	var box := ProtonScatterBoxShape.new()
	box.size = Vector3(extent.x, 1.0, extent.y)
	shape.shape = box
	shape.position = Vector3(center.x, 0.0, center.y)
	scatter.add_child(shape)
	root.add_child(scatter)
	scatter.domain.discover_shapes(scatter)
	return scatter

func candidates(center: Vector2, extent: Vector2, spacing: float, exclude_detail: bool, seed_value: int):
	var scatter := make_domain(center, extent, seed_value)
	var stack := ProtonScatterModifierStack.new()
	var grid := GridModifier.new()
	grid.spacing = Vector3(spacing, 1.0, spacing)
	grid.use_local_space_by_default()
	stack.add(grid)
	var jitter := JitterModifier.new()
	jitter.position = Vector3(spacing * 0.30, 0.0, spacing * 0.30)
	jitter.rotation = Vector3(0.0, 180.0, 0.0)
	stack.add(jitter)
	var habitat := GopalaForestRules.new()
	habitat.terrain = terrain
	habitat.exclude_detail = exclude_detail
	stack.add(habitat)
	var result = await stack.start_update(scatter, scatter.domain)
	scatter.queue_free()
	return result.list

func build() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Forest baking needs a real renderer to preserve MultiMesh buffers. Run tools/godot.py --script core/tools/bake_forest.gd without --headless.")
		quit(1)
		return
	if not FileAccess.file_exists(CONFIG):
		push_error("Forest models.json is missing: admit the chosen external asset pack before baking.")
		quit(1)
		return
	terrain.load_data()
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	var variants: Array = config.variants
	if variants.is_empty():
		push_error("Forest has no admitted external tree variants.")
		quit(1)
		return
	var models := {}
	var pine_ids: Array[String] = []
	var broad_ids: Array[String] = []
	for variant: Dictionary in variants:
		var item := ProtonScatterItem.new()
		item.path = variant.path
		var merged: MeshInstance3D = MergeHelper.get_merged_meshes_from(item)
		item.queue_free()
		if merged == null or merged.mesh == null:
			push_error("Unable to import complete tree model: " + str(variant.path))
			quit(1)
			return
		models[variant.id] = {"mesh":merged.mesh,"bounds":merged.mesh.get_aabb(),"variant":variant}
		merged.queue_free()
		if variant.kind == "conifer": pine_ids.append(variant.id)
		else: broad_ids.append(variant.id)
	var region: Array[Transform3D] = await candidates(Vector2.ZERO, Vector2.ONE * terrain.EXTENT, float(config.regional_spacing_m) / terrain.METRES_PER_UNIT, true, int(config.seed))
	var detail: Array[Transform3D] = await candidates(Vector2(config.detail_center[0], config.detail_center[1]), Vector2.ONE * float(config.detail_extent_units), float(config.detail_spacing_m) / terrain.METRES_PER_UNIT, false, int(config.seed) + 1)
	region.append_array(detail)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.seed) + 991
	var chunks := {}
	for placed: Transform3D in region:
		var position := placed.origin
		var physical_normal := terrain.normal_at(position.x, position.z, true)
		var elevation := terrain.elevation_at(position.x, position.z)
		var conifer := elevation >= 2200.0 or (physical_normal.z > 0.12 and rng.randf() < 0.65)
		var choices := pine_ids if conifer else broad_ids
		if choices.is_empty(): choices = pine_ids + broad_ids
		var id: String = choices[rng.randi_range(0, choices.size() - 1)]
		var model: Dictionary = models[id]
		var variant: Dictionary = model.variant
		var height_m := rng.randf_range(float(variant.height_min_m), float(variant.height_max_m))
		var bounds: AABB = model.bounds
		# Uniform physical scale: relief exaggeration moves the root, never stretches trees.
		var factor := height_m / terrain.METRES_PER_UNIT / bounds.size.y
		placed.basis = placed.basis.orthonormalized().scaled(Vector3.ONE * factor)
		placed.origin.y -= bounds.position.y * factor
		var tile := Vector2i(floori(position.x / float(config.chunk_size_units)), floori(position.z / float(config.chunk_size_units)))
		var key := "%s_%s_%s" % [id, tile.x, tile.y]
		if not chunks.has(key): chunks[key] = {"id":id,"tile":tile,"transforms":[] as Array[Transform3D]}
		chunks[key].transforms.append(placed)
		variant_counts[id] = int(variant_counts.get(id, 0)) + 1
		population += 1
		if conifer and sample_pine_height_m == 0.0: sample_pine_height_m = height_m
	var forest := Node3D.new()
	forest.name = "ExternalForest"
	forest.set_meta("population", population)
	forest.set_meta("sample_pine_height_m", sample_pine_height_m)
	forest.set_meta("source_pack", config.source_pack)
	forest.set_meta("metres_per_unit", terrain.METRES_PER_UNIT)
	forest.set_meta("tree_relief_multiplier", 1.0)
	for key: String in chunks:
		var chunk: Dictionary = chunks[key]
		var group := MultiMeshInstance3D.new()
		group.name = key
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = models[chunk.id].mesh
		multi.instance_count = chunk.transforms.size()
		for i in chunk.transforms.size(): multi.set_instance_transform(i, chunk.transforms[i])
		group.multimesh = multi
		group.set_meta("variant_id", chunk.id)
		group.set_meta("source_path", models[chunk.id].variant.path)
		group.lod_bias = 0.5
		forest.add_child(group)
		group.owner = forest
	var packed := PackedScene.new()
	var error := packed.pack(forest)
	if error == OK: error = ResourceSaver.save(packed, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	forest.free()
	if error != OK:
		push_error("Forest scene could not be saved: " + str(error))
		quit(1)
		return
	var inputs := {}
	for path: String in [CONFIG, "res://assets/models/trees/PolyHavenFoliage/source-receipt.json", "res://data/geography/kathmandu.json", "res://data/geography/kathmandu-source-height.f32", "res://data/geography/kathmandu-ground-height.f32", "res://data/geography/kathmandu-river-distance.f32", "res://core/landscape/kathmandu_terrain.gd", "res://core/landscape/forest_rules.gd", "res://core/tools/bake_forest.gd"]:
		inputs[path] = FileAccess.get_sha256(path)
	var report := {"ok":true,"population":population,"chunks":chunks.size(),"variants":variant_counts,"sample_pine_height_m":sample_pine_height_m,"output":OUTPUT,"output_sha256":FileAccess.get_sha256(OUTPUT),"inputs":inputs,"placement_engine":"ProtonScatter 4.2.0","scope":"Externally authored models, art-directed forest proxy; not a vegetation survey or resource inventory."}
	var file := FileAccess.open(RECEIPT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("GOPALA_FOREST_BAKE=" + JSON.stringify(report))
	quit(0)
