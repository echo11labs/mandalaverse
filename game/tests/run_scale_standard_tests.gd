extends SceneTree

var failures: Array[String] = []
var checks := 0
var measurements: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func run() -> void:
	var standard := GopalaScaleStandard.settings()
	check(standard.schema_version == 1 and int(standard.revision) > 0, "Versioned scale standard")
	for profile in ["units", "villager", "stone_piece", "stone_patch", "stone_scenery", "stone_carry", "timber_carry", "forage_patch", "forage_carry", "water_source", "water_carry", "cattle", "milk_carry", "pasture", "fence_prop", "axe_prop", "dirt_path", "cobbled_path", "terrace_field", "building_presentation"]:
		for key in standard[profile]:
			if typeof(standard[profile][key]) in [TYPE_FLOAT, TYPE_INT]:
				check(is_finite(float(standard[profile][key])) and float(standard[profile][key]) > 0.0, "Positive finite scale value: %s.%s" % [profile, key])
	check(GopalaScaleStandard.number("terrace_field", "width") <= GopalaScaleStandard.number("units", "logical_meters_per_cell") * 4.0, "Terrace width occupies exactly four logical cells")
	check(GopalaScaleStandard.number("terrace_field", "length") <= GopalaScaleStandard.number("units", "logical_meters_per_cell") * 4.0, "Terrace length occupies exactly four logical cells")
	check(GopalaScaleStandard.number("stone_piece", "width_max") <= GopalaScaleStandard.number("villager", "height") * 0.2, "Hand-sized stones relative to villager")
	check(GopalaScaleStandard.number("stone_patch", "pick_width") >= GopalaScaleStandard.number("stone_patch", "width_max"), "Picking bounds cover stone patch")
	check(is_equal_approx(GopalaScaleStandard.number("units", "regional_meters_per_world_unit"), GopalaKathmanduTerrain.METRES_PER_UNIT), "Scale conversion matches actual terrain")
	check(is_equal_approx(GopalaScaleStandard.number("villager", "height"), 1.75 / GopalaKathmanduTerrain.METRES_PER_UNIT), "Human uses metre conversion, not map marker units")
	check(is_equal_approx(GopalaScaleStandard.number("dirt_path", "width"),1.2/GopalaKathmanduTerrain.METRES_PER_UNIT),"Path width uses authored metre dimensions")
	check(is_equal_approx(GopalaScaleStandard.number("dirt_path", "depth"),0.04/GopalaKathmanduTerrain.METRES_PER_UNIT),"Path depth is converted consistently into terrain units")
	check(is_equal_approx(GopalaScaleStandard.number("cobbled_path", "width"),1.5/GopalaKathmanduTerrain.METRES_PER_UNIT),"Cobbled paths use their measured metre width")
	check(is_equal_approx(GopalaScaleStandard.number("cobbled_path", "depth"),0.08/GopalaKathmanduTerrain.METRES_PER_UNIT),"Cobbled pavers rise above the ground by the authored metre profile")
	check(is_equal_approx(GopalaScaleStandard.number("terrace_field", "width"),8.0/GopalaKathmanduTerrain.METRES_PER_UNIT),"Terrace field width converts its authored eight metres")
	check(is_equal_approx(GopalaScaleStandard.number("terrace_field", "length"),8.0/GopalaKathmanduTerrain.METRES_PER_UNIT),"Terrace field length converts its authored eight metres")
	check(is_equal_approx(GopalaScaleStandard.number("terrace_field", "bed_lift"),0.08/GopalaKathmanduTerrain.METRES_PER_UNIT),"Terrace bed lift converts its authored metre dimension")
	check(is_equal_approx(GopalaScaleStandard.number("terrace_field", "riser_height"),0.3/GopalaKathmanduTerrain.METRES_PER_UNIT),"Terrace retaining riser converts its authored metre dimension")
	check(is_equal_approx(float(standard.terrace_field.riser_threshold),0.25),"Terrace riser threshold remains a metre-valued measurement")
	var river_script = load("res://core/landscape/terrain_river.gd")
	for reach in [{"name": "Bagmati", "kind": "river"}, {"name": "Bishnumati", "kind": "river"}, {"name": "stream", "kind": "stream"}]:
		var river_width: float = river_script.half_width(reach) * 2.0
		check(river_width > GopalaScaleStandard.number("villager", "height") * 10.0, "Human remains much smaller than flowing river: %s" % reach.name)
	for name in ["Rock_3_A", "Rock_1_A", "Rock_1_B", "Rock_3_B"]:
		var path := "res://assets/models/nature/kaykit/%s.glb" % name
		var source: PackedScene = load(path)
		for yaw in [0.0, 0.7, 1.6, 2.7]:
			for export_scale in [0.01, 1.0, 100.0]:
				var model: Node3D = source.instantiate()
				model.scale *= export_scale
				model.rotation.y = yaw
				var source_bounds := GopalaScaleStandard.bounds_in_parent(model)
				var width := GopalaScaleStandard.number("stone_piece", "width_max")
				GopalaScaleStandard.normalize_stone(model, width)
				var fitted := GopalaScaleStandard.bounds_in_parent(model)
				check(GopalaScaleStandard.within_profile(fitted, "stone_piece"), "Export units/yaw cannot produce oversized stones")
				check(absf(fitted.position.y) < 0.0001 and absf(fitted.get_center().x) < 0.0001 and absf(fitted.get_center().z) < 0.0001, "Imported pivots normalize to bottom-centre anchor")
				measurements.append({"asset": path, "sha256": FileAccess.get_sha256(path), "export_scale_probe": export_scale, "yaw": yaw, "source_size": [source_bounds.size.x, source_bounds.size.y, source_bounds.size.z], "fitted_size": [fitted.size.x, fitted.size.y, fitted.size.z]})
				model.free()
	# Nested transforms must contribute to dimensions, not just the first mesh.
	var synthetic := Node3D.new()
	var nested := Node3D.new()
	nested.scale = Vector3.ONE * 7.0
	nested.position = Vector3(8, -4, 6)
	synthetic.add_child(nested)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	nested.add_child(mesh)
	GopalaScaleStandard.normalize_stone(synthetic, GopalaScaleStandard.number("stone_piece", "width_max"))
	check(GopalaScaleStandard.within_profile(GopalaScaleStandard.bounds_in_parent(synthetic), "stone_piece"), "Nested transform normalization")
	check(absf(GopalaScaleStandard.bounds_in_parent(synthetic).position.y) < 0.0001, "Nested pivot ground anchor")
	synthetic.free()
	var patch := GopalaStonePatchView.new()
	patch.build(100, func(_x, _z): return 0.0, Vector2.ZERO)
	var bounds := GopalaScaleStandard.bounds_in_parent(patch.get_node("MeshChild"))
	check(GopalaScaleStandard.within_profile(bounds, "stone_patch"), "Complete stone patch stays within footprint")
	var piece_scale := patch.pieces[0].scale
	patch.update_amount(1, 40)
	check(patch.pieces.filter(func(piece): return piece.visible).size() == 1, "Depletion removes pieces instead of changing their physical size")
	check(patch.pieces[0].scale == piece_scale, "Depletion preserves individual stone size")
	patch.update_amount(0, 40)
	check(not patch.visible, "Empty patch hides")
	patch.free()
	var forage_measurements: Array[Dictionary] = []
	for resource in [&"thatch",&"wild_food",&"fodder"]:
		var forage := GopalaForagePatchView.new()
		forage.build(143,43129,resource,func(_x,_z): return 0.0,Vector2.ZERO)
		var fitted := GopalaScaleStandard.bounds_in_parent(forage.get_node("MeshChild"))
		check(GopalaScaleStandard.within_profile(fitted,"forage_patch"),"Forage patch measured within metre profile")
		check(absf(fitted.position.y) < 0.0001,"Forage plants touch ground at bottom anchor")
		check(fitted.size.y < GopalaScaleStandard.number("villager","height"),"Forage remains smaller than human reference")
		var original_size := forage.plants[0].scale
		forage.update_amount(1,20)
		check(forage.plants.filter(func(plant): return plant.visible).size() == 1 and forage.plants[0].scale == original_size,"Forage depletion removes plants without enlarging them")
		forage.update_amount(0,20)
		check(not forage.visible,"Empty forage hides")
		forage_measurements.append({"resource":resource,"source_sha256":FileAccess.get_sha256("res://core/presentation/forage_patch_view.gd"),"size_metres":[fitted.size.x*100,fitted.size.y*100,fitted.size.z*100],"bounds_bottom":fitted.position.y})
		forage.free()
	var water_view := GopalaWaterSourceView.new()
	water_view.build(1,1,&"water",func(_x,_z): return 0.0,Vector2.ZERO)
	var water_bounds := GopalaScaleStandard.bounds_in_parent(water_view.get_node("MeshChild"))
	check(GopalaScaleStandard.within_profile(water_bounds,"water_source"),"Water barrel normalized to target metre dimensions")
	check(absf(water_bounds.position.y) < 0.0001 and absf(water_bounds.get_center().x) < 0.0001 and absf(water_bounds.get_center().z) < 0.0001,"Water barrel bottom-centre anchor includes imported transforms")
	measurements.append({"asset":"res://assets/models/buildings/highlands/SM_Barrel.glb","sha256":FileAccess.get_sha256("res://assets/models/buildings/highlands/SM_Barrel.glb"),"fitted_size":[water_bounds.size.x,water_bounds.size.y,water_bounds.size.z]})
	water_view.free()
	var cow := GopalaCattleView.new()
	var cow_bounds := GopalaScaleStandard.bounds_in_parent(cow)
	check(GopalaScaleStandard.within_profile(cow_bounds,"cattle"),"Imported cattle meets metre dimensions")
	check(is_equal_approx(cow_bounds.size.y,GopalaScaleStandard.number("cattle","height")) and absf(cow_bounds.position.y) < 0.0001 and absf(cow_bounds.get_center().z) < 0.0001,"Cattle target height and bottom-centre ground anchor")
	check(cow_bounds.size.y < GopalaScaleStandard.number("villager","height"),"Cattle shoulder remains below a human reference")
	measurements.append({"asset":"res://core/presentation/cattle_view.gd","sha256":FileAccess.get_sha256("res://core/presentation/cattle_view.gd"),"fitted_size":[cow_bounds.size.x,cow_bounds.size.y,cow_bounds.size.z]})
	cow.free()
	var forest_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/forest/models.json"))
	for variant: Dictionary in forest_config.variants:
		var path := GopalaNatureModels.resolve(variant.id, variant.path)
		var tree: Node3D = (load(path) as PackedScene).instantiate()
		var target_m := (float(variant.height_min_m)+float(variant.height_max_m))*0.5
		GopalaScaleStandard.normalize_height(tree, GopalaScaleStandard.metres_to_world(target_m))
		var tree_bounds := GopalaScaleStandard.bounds_in_parent(tree)
		check(is_equal_approx(tree_bounds.size.y*100.0,target_m),"Tree uses existing metre height: " + variant.id)
		check(absf(tree_bounds.position.y)<0.0001 and absf(tree_bounds.get_center().x)<0.0001 and absf(tree_bounds.get_center().z)<0.0001,"Tree bottom-centre including imported transforms: " + variant.id)
		measurements.append({"variant":variant.id,"asset":path,"sha256":FileAccess.get_sha256(path),"target_height_metres":target_m,"fitted_size":[tree_bounds.size.x,tree_bounds.size.y,tree_bounds.size.z]})
		tree.free()

	for definition in ["dwelling","stockpile","timber_camp","gatherer_shelter","water_point","cattle_shelter"]:
		for turn in 4:
			var building := GopalaBuildingModelView.new()
			building.build(Vector3(0.04,GopalaScaleStandard.number("building","height"),0.04),definition,turn,turn)
			var fitted := building.measured_bounds
			check(fitted.size.x <= 0.04001 and fitted.size.z <= 0.04001 and fitted.size.y <= GopalaScaleStandard.number("building","height")+0.00001,"New facility and dressing fit existing plot in all rotations: " + definition)
			check(absf(fitted.position.y) < 0.00001,"New facility ground anchor: " + definition)
			measurements.append({"definition":definition,"rotation":turn,"asset":building.model_path,"sha256":FileAccess.get_sha256(building.model_path),"view_sha256":FileAccess.get_sha256("res://core/presentation/building_model_view.gd"),"size_metres":[fitted.size.x*100,fitted.size.y*100,fitted.size.z*100]})
			building.free()
	for seed in 6:
		var worker := GopalaWorkerModelView.new()
		worker.build(seed)
		check(is_equal_approx(worker.measured_bounds.size.y,GopalaScaleStandard.number("villager","height")),"All settler variants retain 1.75m height")
		check(absf(worker.measured_bounds.position.y) < 0.00001,"All settler variants retain ground anchor")
		check(worker.player.has_animation("walk") and worker.player.has_animation("pick-up"),"All settler variants retain work animations")
		measurements.append({"asset":worker.model_path,"sha256":FileAccess.get_sha256(worker.model_path),"size_metres":[worker.measured_bounds.size.x*100,worker.measured_bounds.size.y*100,worker.measured_bounds.size.z*100]})
		worker.free()
	for resource in [&"stone",&"timber",&"water",&"milk",&"thatch",&"fodder",&"wild_food"]:
		var goods := GopalaCarriedGoodsView.new()
		goods.build(resource)
		var target := GopalaScaleStandard.carry_size(GopalaCarriedGoodsView.profile(resource))
		var fitted := goods.measured_bounds
		check(fitted.size.x <= target.x+0.00001 and fitted.size.y <= target.y+0.00001 and fitted.size.z <= target.z+0.00001,"Goods models fit carry dimensions: " + resource)
		measurements.append({"resource":resource,"asset":"res://core/presentation/carried_goods_view.gd","sha256":FileAccess.get_sha256("res://core/presentation/carried_goods_view.gd"),"size_metres":[fitted.size.x*100,fitted.size.y*100,fitted.size.z*100]})
		goods.free()
	var report := {"ok": failures.is_empty(), "checks": checks, "failures": failures, "standard_path": GopalaScaleStandard.PATH, "standard_sha256": FileAccess.get_sha256(GopalaScaleStandard.PATH), "revision": standard.revision, "units": standard.units, "profiles": standard, "mesh_measurements": measurements,"forage_measurements":forage_measurements, "patch_size": [bounds.size.x, bounds.size.y, bounds.size.z], "scope": "Regenerated on verification: standard values, imported mesh bounds, export-scale/yaw/nested-pivot normalization, patch footprint and depletion. Live terrain patches are checked in stone-resource-tests; path dimensions are checked against the terrain units contract."}
	var file := FileAccess.open("res://../reports/scale-audit.json", FileAccess.WRITE)
	if file == null:
		check(false, "Scale audit file could be written")
	else:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
