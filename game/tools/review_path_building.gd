extends SceneTree
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1920,1080)
	root.content_scale_size = Vector2i(1920,1080)
	var valley = load("res://scenes/mvp.tscn").instantiate()
	root.add_child(valley)
	valley.simulation.set_physics_process(false)
	for frame in 20: await process_frame
	var cells: Array[Vector2i] = []
	for y in range(-3,7):
		var candidate: Array[Vector2i] = []
		for x in range(-2,4): candidate.append(Vector2i(x,y))
		if valley.simulation.road_service().validate_cells(candidate).valid:
			cells = candidate
			break
	check(cells.size() == 6,"Actual MVP has a legal six-cell path near camp")
	if cells.is_empty(): finish(valley); return
	valley.simulation.request_road(cells)
	valley.simulation.process_pending_commands()
	var road_id: int = valley.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.ROAD)[0].entity_id
	valley.simulation.selection_service().select_entity(road_id)
	valley._inspect_selected_entity(road_id)
	await capture("planned")
	valley.simulation.set_paused(false)
	valley.simulation.process_pending_commands()
	for tick in 600:
		valley.simulation.advance_ticks(1)
		if GopalaRoadPlacementService.built_cells(valley.simulation.entity_queries().snapshot(road_id)).size() == 3: break
	await capture("builder-working")
	complete(valley.simulation,road_id)
	await capture("dirt-finished")
	valley.simulation.request_cobbled_path(cells)
	valley.simulation.process_pending_commands()
	complete(valley.simulation,road_id)
	valley._inspect_selected_entity(road_id)
	await capture("paving-finished")
	var road_view: Node3D = valley._road_views[road_id]
	var batches := road_view.find_children("*","MultiMeshInstance3D",true,false)
	check(batches.size() == 6,"Each finished cell batches its paving stones")
	for batch in batches:
		check(batch.multimesh.instance_count <= 100,"Paver counts stay bounded after one metre conversion")
		check(batch.material_override.vertex_color_use_as_albedo,"Stone variation is actually enabled")
		check(batch.multimesh.mesh.size.x <= GopalaScaleStandard.number("cobbled_path","paver_width"),"Stones obey authored metre width")
	var adapter: GopalaEntityViewAdapter3D
	for child in road_view.get_children():
		if child is GopalaEntityViewAdapter3D: adapter = child
	check(adapter != null and adapter.bound_entity_id == road_id,"Road geometry can resolve to its selectable entity")
	if adapter != null:
		check(valley._picker.resolve_collider(adapter.get_child(0)) == road_id,"Road collider resolves through the actual picker")
	finish(valley)

func complete(sim: GopalaSettlementSimulation, id: int) -> void:
	for tick in 1500:
		sim.advance_ticks(1)
		if sim.entity_queries().snapshot(id).attributes.get("construction_state") == "COMPLETED": return
	check(false,"Actual MVP builder finishes the path job")

func capture(stage: String) -> void:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../reports/path-building/%s.png" % stage) == OK,"Capture " + stage)

func finish(valley: Node) -> void:
	var receipt := {"ok":failures.is_empty(),"checks":checks,"failures":failures}
	var file := FileAccess.open("res://../reports/path-building/render-checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"\t"))
	valley.free()
	print("GOPALA_TEST_REPORT=",JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
