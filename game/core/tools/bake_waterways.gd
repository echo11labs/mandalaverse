extends SceneTree
## Rebuild offline meshes/maps after river data, terrain dressing, or shader changes.
const River = preload("res://core/landscape/terrain_river.gd")
const DESTINATION := "res://data/geography/waterways/mapped_rivers.scn"
func _initialize() -> void: bake.call_deferred()
func bake() -> void:
	var terrain := GopalaKathmanduTerrain.new()
	terrain.load_data()
	var courses := Node3D.new()
	courses.name = "MappedRiverCourses"
	root.add_child(courses)
	var segments := 0
	for reach in terrain.metadata.rivers:
		var river := River.new()
		river.configure(reach, terrain)
		courses.add_child(river)
		river.owner = courses
		river.mesh_instance.owner = courses
		segments += reach.points.size() - 1
	courses.set_meta("source_segments", segments)
	courses.set_meta("geography_sha256", FileAccess.get_sha256("res://data/geography/kathmandu.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINATION.get_base_dir()))
	var packed := PackedScene.new()
	var error := packed.pack(courses)
	if error == OK: error = ResourceSaver.save(packed, DESTINATION, ResourceSaver.FLAG_COMPRESS)
	if error == OK:
		var inputs := {}
		for path in ["res://data/geography/kathmandu.json", "res://data/geography/kathmandu-ground-height.f32",
			"res://core/landscape/kathmandu_terrain.gd", "res://core/landscape/terrain_river.gd",
			"res://core/tools/bake_waterways.gd", "res://assets/materials/terrain_river.gdshader",
			"res://addons/waterways/river_manager.gd", "res://addons/waterways/water_helper_methods.gd"]:
			inputs[path] = FileAccess.get_sha256(path)
		var receipt := FileAccess.open(DESTINATION.get_base_dir() + "/receipt.json", FileAccess.WRITE)
		receipt.store_string(JSON.stringify({"inputs": inputs, "output": DESTINATION, "output_sha256": FileAccess.get_sha256(DESTINATION),
			"reaches": courses.get_child_count(), "segments": segments, "flowmap": "CPU UV2 atlas; artistic downstream and shore masks, not collider or hydraulic simulation",
			"licenses": "River geometry: ODbL; elevation: Copernicus DEM; Waterways: MIT; authored integration: project code"}, "\t") + "\n")
	print("GOPALA_WATERWAYS_BAKE=" + JSON.stringify({"ok": error == OK, "reaches": courses.get_child_count(), "segments": segments, "destination": DESTINATION}))
	courses.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
