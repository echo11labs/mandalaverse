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
	for pack in ["kenney_survival", "kenney_workers", "nature/kaykit", "animals/styloo", "buildings/highlands"]:
		var folder := "res://assets/models/%s/" % pack
		var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "source-receipt.json"))
		check(receipt.license == "CC0-1.0", "Admitted CC0 source: " + pack)
		for path in receipt.files:
			check(FileAccess.get_sha256(folder + path) == receipt.files[path], "Unmodified source/dependency/license: " + str(path))
	var extension_root := "res://assets/models/nature/kaykit/"
	var extension: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(extension_root + "resource-refresh-receipt.json"))
	check(extension.license == "CC0-1.0", "Resource refresh retains admitted CC0 license")
	check(FileAccess.get_sha256(extension_root + "LICENSE.txt") == extension.license_sha256,"Resource refresh license matches original archive")
	for path in extension.files:
		check(FileAccess.get_sha256(extension_root + path) == extension.files[path],"Resource refresh copied-byte integrity: " + path)
	var cow := GopalaCattleView.new()
	root.add_child(cow)
	check(cow.player.has_animation("iddle") and cow.player.has_animation("walk"),"Styloo source idle and walk animations retained")
	check(cow.current_pose == "iddle","Grazing/tended cattle uses idle")
	cow.update_state({&"cattle_move_state":&"MOVING"},false,4.0)
	check(cow.current_pose == "walk" and cow.player.speed_scale == 4.0,"Herd movement selects source walk at simulation speed")
	cow.update_state({&"cattle_move_state":&"IDLE",&"herd_status":&"READY"},true)
	check(cow.current_pose == "iddle" and cow.player.speed_scale == 0.0,"Paused/tended cattle returns to frozen idle")
	check(is_equal_approx(cow.measured_bounds.size.y,GopalaScaleStandard.number("cattle","height")),"Imported cattle preserves target height")
	cow.free()
	var worker := GopalaWorkerModelView.new()
	root.add_child(worker)
	worker.build()
	check(is_equal_approx(worker.measured_bounds.size.y, GopalaScaleStandard.number("villager", "height")), "Worker is 1.75m, including every imported child")
	check(absf(worker.measured_bounds.position.y) < 0.000001, "Worker feet ground anchored")
	check(worker.current_pose == "idle", "Idle pose available")
	if FileAccess.file_exists("res://assets/models/local_villagers/peasant_4.glb"):
		check(worker.model_path.ends_with("peasant_4.glb"),"Local downloaded villager replaces the fallback when available")
		var variant := GopalaWorkerModelView.new()
		root.add_child(variant)
		variant.build(1)
		check(variant.model_path.ends_with("peasant_5.glb"),"Entity IDs deterministically choose the second villager variant")
		check(is_equal_approx(variant.measured_bounds.size.y,GopalaScaleStandard.number("villager","height")),"Second downloaded villager fits the same metre standard")
		variant.free()
	else:
		check(worker.model_path.ends_with("character-a.glb"),"Public checkout retains redistributable character fallback")
	worker.update_state({&"movement_state": &"MOVING", &"destination_x": 1.0})
	check(worker.current_pose == "walk", "Simulation movement selects walk")
	worker.update_state({&"task_state": &"PICKING_UP"})
	check(worker.current_pose == "pick-up", "Pickup state selects source animation")
	worker.update_state({}, true)
	check(worker.player.speed_scale == 0.0, "Paused simulation freezes animation")
	measurements.append({"asset": "character-a.glb", "size_metres": worker.measured_bounds.size * 100.0, "ground_metres": worker.measured_bounds.position.y * 100.0})
	worker.queue_free()
	for definition in ["stockpile", "dwelling", "timber_camp", "gatherer_shelter", "water_point", "cattle_shelter"]:
		var source = load("res://data/buildings/%s.tres" % definition)
		for turn in [0, 1, 2, 3]:
			var size := Vector3(source.footprint.x * GopalaScaleStandard.metres_to_world(GopalaScaleStandard.number("units", "logical_meters_per_cell")), GopalaScaleStandard.number("building", "height"), source.footprint.y * GopalaScaleStandard.metres_to_world(GopalaScaleStandard.number("units", "logical_meters_per_cell")))
			if turn % 2 == 1:
				size = Vector3(size.z, size.y, size.x)
			var building := GopalaBuildingModelView.new()
			root.add_child(building)
			building.build(size, definition, turn, turn)
			var bounds := building.measured_bounds
			check(bounds.size.x <= size.x + 0.000001 and bounds.size.z <= size.z + 0.000001 and bounds.size.y <= size.y + 0.000001, "Model fits actual footprint and height: " + definition)
			check(absf(bounds.position.y) < 0.000001, "Building bottom anchor: " + definition)
			for state in ["BLUEPRINT", "WAITING_FOR_MATERIALS", "UNDER_CONSTRUCTION", "COMPLETED"]:
				building.update_stage(state, size.y * 0.5)
				check(building.complete.visible == (state == "COMPLETED"), "Roof appears only after completion")
				check(building.frame.visible == (state == "UNDER_CONSTRUCTION"), "Frame follows construction state")
				check(is_equal_approx(building.position.y, -size.y * 0.5), "Ground anchor compensates stage root height")
			measurements.append({"definition": definition, "rotation_probe": turn, "size_metres": bounds.size * 100.0, "footprint_metres": size * 100.0})
			building.queue_free()
	var valley = load("res://scenes/landscape/kathmandu_valley.tscn").instantiate()
	root.add_child(valley)
	await process_frame
	var queries = valley.simulation.entity_queries()
	var villager = queries.snapshots_by_kind(GopalaEntityKind.VILLAGER)[0]
	var worker_root: MeshInstance3D = valley._built_views[villager.entity_id]
	check(worker_root.material_override.albedo_color.a == 0.0, "Live worker capsule is hidden")
	check(worker_root.get_node_or_null("WorkerVisual") != null, "Live entity has imported worker")
	check(worker_root.find_children("*", "CollisionShape3D", true, false).size() == 1, "Worker picking collider retained")
	check(worker_root.get_node("WorkerVisual").player.speed_scale == 0.0, "Paused startup freezes live worker animation")
	var camp = queries.snapshots_by_kind(GopalaEntityKind.BUILDING)[0]
	var building_root: MeshInstance3D = valley._built_views[camp.entity_id]
	check(building_root.material_override.albedo_color.a == 0.0, "Live camp primitive is hidden")
	check(building_root.get_node("BuildingVisual").complete.visible, "Live completed camp has timber shelter")
	check(building_root.get_meta("collider").shape.size == building_root.get_meta("full_size"), "Full plot picking shape retained")
	valley.queue_free()
	await process_frame
	var file := FileAccess.open("res://../reports/model-asset-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "ok": failures.is_empty(), "measurements": measurements, "standard_revision": GopalaScaleStandard.settings().revision}, "\t"))
	file.close()
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
