extends SceneTree
var checks := 0
var failures: Array[String] = []
var territory_summary: Dictionary = {}
func expect(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var terrain := GopalaKathmanduTerrain.new()
	terrain.load_data()
	expect(terrain.source.size()==1025*1025 and terrain.ground.size()==terrain.source.size(),"Complete elevation coverage")
	expect(terrain.metadata.audit.directed_cycles==0,"Reviewed river graph acyclic")
	var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/geography/source-receipt.json"))
	for file_name in receipt.files:
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(FileAccess.get_file_as_bytes("res://data/geography/"+file_name))
		expect(context.finish().hex_encode()==receipt.files[file_name],"Source checksum: "+file_name)
	for i in range(0,terrain.source.size(),1019):
		expect(is_finite(terrain.source[i]) and terrain.source[i]>500 and terrain.source[i]<3000,"Finite source elevation")
	var names: Dictionary = {}
	for river in terrain.metadata.rivers:
		names[river.name] = true
		for i in range(river.points.size()-1):
			var a: Array = river.points[i]
			var b: Array = river.points[i+1]
			expect(b[1]<=a[1]+0.000001,"Conditioned profile does not rise downstream")
			expect(absf(a[0])<=200 and absf(a[2])<=200,"Mapped course remains in region")
	for name_value in ["Bagmati","Bishnumati","Manohara","Hanumante","Dhobi Khola","Balkhu","Nakhu","Godawari","Kodku"]:
		expect(names.has(name_value),"Major river: "+name_value)
	var landmark: Dictionary = terrain.metadata.landmarks[0]
	expect(absf(landmark.lon-85.3907821)<0.00000001 and absf(landmark.lat-27.8108557)<0.00000001,"Mapped Bagdwar coordinates retained")
	var reconstructed: Dictionary = terrain.metadata.reconstruction[0]
	expect(reconstructed.kind=="reconstructed" and reconstructed.confidence.contains("Unsurveyed"),"Estimate explicitly qualified")
	expect(Vector2(reconstructed.points[0][0],reconstructed.points[0][2]).distance_to(Vector2(landmark.position[0],landmark.position[2]))<0.001,"Estimate starts at Bagdwar")
	for y in range(48):
		for x in range(48):
			var cell := Vector2i(x,y)
			expect(terrain.cell_at(terrain.cell_position(cell))==cell,"Local coordinates round trip")
	expect(not terrain.is_buildable(Vector2i(-1,0)),"Outside local grid rejects construction")
	var packed: PackedScene = load("res://scenes/landscape/kathmandu_valley.tscn")
	var world = packed.instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	expect(world.water_segments>10000 and world.has_node("InferredBagdwarHeadwater"),"Mapped and inferred layers exist")
	var courses: Node = world.get_node("MappedRiverCourses")
	expect(courses.get_child_count()>0,"Mapped river courses exist")
	var water: MeshInstance3D = courses.get_child(0).get_node("RiverMeshInstance")
	var water_arrays: Array = water.mesh.surface_get_arrays(0)
	var water_vertices: PackedVector3Array = water_arrays[Mesh.ARRAY_VERTEX]
	expect((water_vertices[1]-water_vertices[0]).cross(water_vertices[2]-water_vertices[0]).y<0,"Water winding faces the lit surface")
	var marker: MeshInstance3D = world.get_node("BagdwarSourceMarker")
	expect(Vector2(marker.position.x,marker.position.z).distance_to(Vector2(landmark.position[0],landmark.position[2]))<0.0001,"Marker is at mapped coordinate")
	var arrays: Array = world.ground_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(0,vertices.size(),1001):
		expect(absf(vertices[i].y-terrain.height_at(vertices[i].x,vertices[i].z))<0.0001,"Mesh matches ground model")
	var camera = world.get_node("Camera3D")
	for size_value in [14.0, 65.0, camera.maximum_size()]:
		var point := terrain.cell_position(Vector2i(24,24))
		camera.focus_point(point,size_value)
		var hit: Dictionary = world.pick(camera.unproject_position(point))
		expect(not hit.is_empty(),"Ground picking at geographic and local zoom")
		if not hit.is_empty(): expect(terrain.cell_at(hit.position)==Vector2i(24,24),"Projected cell picks correctly")
	camera.zoom_by(0.00001)
	expect(is_equal_approx(camera.size, camera.MIN_SIZE),"Minimum zoom bounded")
	camera.zoom_by(100000)
	expect(is_equal_approx(camera.size, camera.maximum_size()),"Maximum zoom stays inside the terrain")
	var camp_point := Vector3(terrain.camp.x, terrain.height_at(terrain.camp.x, terrain.camp.y), terrain.camp.y)
	camera.focus_point(camp_point, camera.management_size())
	var moved_from: Vector3 = camera.target
	Input.action_press("camera_right")
	for _frame in 8:
		await process_frame
	Input.action_release("camera_right")
	expect(camera.target.distance_to(moved_from) > 0.5, "Camera right moves the camp view")
	moved_from = camera.target
	Input.action_press("camera_forward")
	Input.action_press("camera_right")
	for _frame in 8:
		await process_frame
	Input.action_release("camera_forward")
	Input.action_release("camera_right")
	var step: Vector3 = camera.target - moved_from
	var ground := Vector3(step.x, 0, step.z)
	expect(absf(ground.dot(camera.ground_right())) > 0.2 and absf(ground.dot(camera.ground_forward())) > 0.2, "Two camera keys travel diagonally")
	camera.focus_point(Vector3(0, 8, 0), camera.maximum_size())
	var locked: Vector3 = camera.target
	camera.pan_ground(40.0, 0.0)
	expect(camera.clamped_last, "Fit-limit pan is rejected by the terrain clamp")
	expect(camera.target.distance_to(locked) < 2.0, "Fit-limit pan does not travel")
	expect(absf(camera.target.x) <= 200.0 and absf(camera.target.z) <= 200.0, "Pivot stays inside the terrain")
	camera.focus_point(camp_point, camera.management_size())
	var span_before: float = camera.size
	camera.zoom_step(0.84)
	expect(camera.size < span_before - 0.1, "Zoom step draws the view closer")
	var yaw_before: float = camera.yaw
	camera.turn_by(45.0)
	expect(is_equal_approx(fposmod(camera.yaw - yaw_before, 360.0), 45.0), "Turn steps by 45 degrees")
	var drag_from: float = camera.yaw
	var pitch_from: float = camera.pitch
	camera.rotating = true
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80.0, -20.0)
	camera._unhandled_input(motion)
	expect(absf(fposmod(drag_from - camera.yaw, 360.0) - 17.6) < 1.0, "Middle-drag turns continuously with the mouse")
	expect(camera.pitch > pitch_from, "Dragging the middle mouse upward lifts the view")
	expect(camera.pitch >= camera.PITCH_MIN and camera.pitch <= camera.PITCH_MAX, "Tilt stays inside the Farthest Frontier style limits")
	var forest_receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/forest/bake-receipt.json"))
	var forest_review: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/forest/review.json"))
	var approved_hash := String(forest_review.get("accepted_bake_sha256", ""))
	var submitted_hash := String(forest_review.get("submitted_bake_sha256", ""))
	var review_status := String(forest_review.get("status", ""))
	if review_status == "accepted" or review_status == "pending_visual_review":
		var active_hash := approved_hash if review_status == "accepted" else submitted_hash
		expect(not active_hash.is_empty(), "Active forest review state supplies a bake hash")
		expect(FileAccess.get_sha256(forest_receipt.output) == active_hash, "Current forest matches its accepted or submitted visual-review receipt")
		expect(world.tree_population == int(forest_receipt.population) and world.has_node("ExternalForest"), "Main scene loads the hash-pinned forest candidate")
	else:
		expect(world.tree_population == 0 and world.sample_pine_height_m == 0.0, "No unpinned tree population appears in the landscape")
		expect(not world.has_node("ExternalForest"), "An unpinned external forest cannot appear in the landscape")
	expect(not world.has_node("ChirAndBluePine") and not world.has_node("BroadleafStands"), "No procedural canopy fallback restores the removed trees")
	check_territories(world, terrain)
	world.queue_free()
	await process_frame
	print("GOPALA_TEST_REPORT="+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"territory":territory_summary}))
	quit(0 if failures.is_empty() else 1)

func chiefdom_index(chiefdoms: Array, chiefdom_id: String) -> int:
	for i in range(chiefdoms.size()):
		if String((chiefdoms[i] as Dictionary).get("id","")) == chiefdom_id:
			return i
	return -1

func border_on_river(drawer: GopalaMapOverlay, region_index: int, river_name: String) -> int:
	if region_index < 0:
		return -1
	var count := 0
	for point in drawer.contour_vertices(region_index):
		if drawer.distance_to_river(point, river_name, 300.0) < 300.0:
			count += 1
	return count

func check_territories(world: Node, terrain: GopalaKathmanduTerrain) -> void:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(GopalaMapOverlay.REGIONS_PATH))
	expect(document is Dictionary,"Territory document parses")
	if not document is Dictionary: return
	var data: Dictionary = document
	expect(int(data.schema)==2,"Territory document is schema 2")
	var chiefdoms: Array = data.get("chiefdoms", [])
	expect(chiefdoms.size()==4,"Four tributary chiefdoms")
	var ids: Dictionary = {}
	for chiefdom in chiefdoms:
		ids[String(chiefdom.id)] = true
		expect(String(chiefdom.get("label",""))!="" and String(chiefdom.get("role",""))!="","Chiefdom carries a label and a role")
		expect(String(chiefdom.get("summary",""))!="" and String(chiefdom.get("jurisdiction",""))!="","Chiefdom carries extent prose")
		expect(String(chiefdom.get("evidential_confidence",""))=="inferred","Chiefdom border confidence is inferred, never attested")
	var pairs: Dictionary = {}
	for frontier in data.get("frontiers",[]):
		var between: Array = frontier.get("between",[])
		expect(between.size()==2 and ids.has(String(between[0])) and ids.has(String(between[1])),"Frontier names two known chiefdoms")
		pairs[String(between[0])+"--"+String(between[1])] = true
	expect(pairs.size()==5,"Five frontiers describe the four chiefdoms")
	var chain_ids: Dictionary = {}
	for chain in data.get("chains",[]):
		chain_ids[String(chain.id)] = (chain.get("anchors",[]) as Array).size()
	for frontier in data.get("frontiers",[]):
		var spans: Array = frontier.get("segments",[])
		expect(not spans.is_empty(),"Frontier resolves at least one chain span")
		for segment in spans:
			expect(chain_ids.has(String(segment.get("chain",""))),"Frontier segment references a declared chain")
			expect(int(segment.get("from",0))<=int(segment.get("to",0)),"Frontier span runs forwards along its chain")
			expect(int(segment.get("to",0))<int(chain_ids.get(String(segment.get("chain","")),0)),"Frontier span stays inside its chain")
	var drawer: GopalaMapOverlay = world.get_node("GeographicMapOverlay/TerritoryOverlay")
	expect(drawer.built and drawer.ownership.size()==GopalaMapOverlay.FIELD_RES*GopalaMapOverlay.FIELD_RES,"Territory ownership field covers the basin")
	var land := drawer.land_cells()
	expect(land>0,"Least-cost fill claimed ground")
	for chiefdom in chiefdoms:
		var id := String(chiefdom.id)
		var seat: Vector2 = drawer.lonlat_to_world(float(chiefdom.seat.lon),float(chiefdom.seat.lat))
		expect(absf(seat.x)<=GopalaMapOverlay.EXTENT and absf(seat.y)<=GopalaMapOverlay.EXTENT,"Seat falls inside the surveyed extent: "+id)
		expect(drawer.owned_cells(id)>land/100,"Chiefdom holds a defensible share of the valley: "+id)
		expect(drawer.region_id_at(seat.x,seat.y)==id,"Seat lies inside its own domain: "+id)
	expect(drawer.owned_cells("kirtipur")<drawer.owned_cells("yambu"),"The spur domain is the smallest, because the ground is")
	expect(drawer.land_cells()<GopalaMapOverlay.FIELD_RES*GopalaMapOverlay.FIELD_RES,"The basin rim is impassable, so the fill does not claim the surrounding hills")
	expect(drawer.region_id_at(-66.0,-11.0)=="yambu","Royal seat ground reads as Yambu")
	expect(drawer.region_id_at(-49.0,21.0)=="lalitapur","Patan bowl ground reads as Lalitapur")
	expect(drawer.region_id_at(-95.0,18.0)=="kirtipur","Kirtipur spur reads as Kirtipur")
	expect(drawer.region_id_at(53.0,27.0)=="bhakata","Eastern terraces read as Bhakata")
	expect(drawer.region_id_at(0.0,-180.0)=="","Ground beyond the rim belongs to no chiefdom")
	var snapped := 0
	for chain in drawer.snapped_chains.values():
		snapped += int(chain.moved)
	expect(snapped>0,"Frontier landmarks snapped onto real rivers and ridge crests")
	expect(drawer.snapped_rim[0].distance_to(drawer.snapped_rim[drawer.snapped_rim.size()-1])<0.001,"The basin rim closes on itself")
	for chain_id in ["bagmati_core","bagmati_west_reach","balkhu_line","hanumante_march"]:
		var chain: Dictionary = (data.get("chains",[]) as Array).filter(func(c): return c.id==chain_id)[0]
		var river_anchors: Array = (chain.anchors as Array).filter(func(a): return a.get("basis","")=="river")
		expect(river_anchors.size()>0,"%s declares at least one watercourse anchor" % chain_id)
		for anchor in river_anchors:
			var authored := drawer.lonlat_to_world(float(anchor.lon),float(anchor.lat))
			expect(drawer.distance_to_river(authored,String(anchor.get("river",chain.get("river",""))),200.0)<200.0,"%s anchor is on its mapped watercourse: %s" % [chain_id, String(anchor.get("name",""))])
	var bhakata := chiefdom_index(chiefdoms,"bhakata")
	var yambu := chiefdom_index(chiefdoms,"yambu")
	var lalitapur := chiefdom_index(chiefdoms,"lalitapur")
	expect(border_on_river(drawer,bhakata,"Bagmati")>20,"Part of the Bhakata border lies on the Bagmati")
	expect(border_on_river(drawer,yambu,"Bagmati")>20,"Part of the Yambu border lies on the Bagmati")
	expect(border_on_river(drawer,bhakata,"Hanumante")>10,"Part of the Bhakata border lies on the Hanumante")
	expect(border_on_river(drawer,lalitapur,"Hanumante")>10,"Part of the Lalitapur border lies on the Hanumante")
	for _i in range(3):
		drawer.cycle_mode()
	expect(drawer.mode==GopalaMapOverlay.Mode.OFF,"Three presses of F return the territory view to off")
	drawer.set_mode(GopalaMapOverlay.Mode.SURVEY)
	expect(drawer.contours.size()==4,"Survey contours exist for all four chiefdoms")
	for i in range(drawer.contours.size()):
		expect(not (drawer.contours[i] as Array).is_empty(),"Survey contour traced: "+String(chiefdoms[i].id))
	expect(InputMap.has_action("toggle_territory"),"F is bound as a rebindable territory action")
	expect(InputMap.action_get_events("toggle_territory")[0].physical_keycode==KEY_F,"The territory action is bound to F")
	territory_summary = drawer.summarise()
	territory_summary.snapped = {}
	for chain_id in drawer.snapped_chains.keys():
		territory_summary.snapped[chain_id] = int(drawer.snapped_chains[chain_id].moved)
	territory_summary.borders_on_river = {}
	for chiefdom in chiefdoms:
		var index := chiefdom_index(chiefdoms,String(chiefdom.id))
		territory_summary.borders_on_river[String(chiefdom.id)] = {
			"Bagmati": border_on_river(drawer,index,"Bagmati"),
			"Hanumante": border_on_river(drawer,index,"Hanumante"),
			"Balkhu": border_on_river(drawer,index,"Balkhu"),
			"contour_vertices": drawer.contour_vertices(index).size(),
		}
	drawer.set_mode(GopalaMapOverlay.Mode.OFF)
	world.cycle_territory_mode()
	expect(drawer.mode==GopalaMapOverlay.Mode.WASH and world.territory_labels.visible,"F from the scene enters the wash and shows the chiefdom labels")
	world.cycle_territory_mode()
	expect(drawer.mode==GopalaMapOverlay.Mode.SURVEY,"Second F reaches the survey mode")
	world.cycle_territory_mode()
	expect(drawer.mode==GopalaMapOverlay.Mode.OFF and not world.territory_labels.visible,"Third F returns to bare terrain")
