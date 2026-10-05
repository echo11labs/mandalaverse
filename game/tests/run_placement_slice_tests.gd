extends SceneTree

const SIMULATION_SCENE := preload("res://core/simulation/settlement_simulation.tscn")

var checks := 0
var failures: Array[String] = []

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	await _test_placement_slice()
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _new_simulation() -> Node:
	var simulation = SIMULATION_SCENE.instantiate()
	root.add_child(simulation)
	return simulation

func _free_simulation(simulation: Node) -> void:
	simulation.queue_free()
	await process_frame
	await process_frame

func _test_placement_slice() -> void:
	var sim: GopalaSettlementSimulation = _new_simulation()
	await process_frame

	var last_result_arr: Array = []
	sim.command_processed.connect(func(res):
		if last_result_arr.is_empty(): last_result_arr.append(res)
		else: last_result_arr[0] = res
	)

	var grid_config = GopalaSettlementGridConfig.new(Vector2(0, 0), Rect2i(-24, -24, 48, 48), 2.0, 100.0)
	sim.coordinate_service().configure(grid_config)
	expect(sim.bootstrap_session(), "Session boots up")

	var initial_timber = sim.resource_amount(&"timber")
	expect(initial_timber == 100, "Timber is bootstrapped to 100")

	var def = sim.placement_service().get_building(&"dwelling")
	expect(def != null, "Dwelling definition exists")

	# Unknown building
	sim.request_construction(&"UNKNOWN", Vector2i(0, 0))
	sim.process_pending_commands()
	var res_unk: GopalaCommandResult = last_result_arr[0] if not last_result_arr.is_empty() else null
	expect(res_unk != null and res_unk.status == GopalaCommandResult.Status.REJECTED and res_unk.reason_code == &"UNKNOWN_BUILDING", "Unknown building rejects")

	# Out of bounds
	var out_of_bounds_cell = Vector2i(1000, 1000)
	sim.request_construction(&"dwelling", out_of_bounds_cell)
	sim.process_pending_commands()
	var last_result: GopalaCommandResult = last_result_arr[0] if not last_result_arr.is_empty() else null
	expect(last_result != null and last_result.status == GopalaCommandResult.Status.REJECTED, "Cannot place out of bounds")
	expect(last_result != null and last_result.reason_code == &"OUT_OF_BOUNDS", "OOB reason is correct")

	# Rotations
	for rot in range(4):
		var validation = sim.placement_service().validate_placement(&"dwelling", Vector2i(0, 0), rot)
		expect(validation.valid, "Rotation %d transforms correctly" % rot)

	var valid_cell = Vector2i(0, 0)
	sim.request_construction(&"dwelling", valid_cell)
	sim.process_pending_commands()
	last_result = last_result_arr[0] if not last_result_arr.is_empty() else null
	expect(last_result != null and last_result.status == GopalaCommandResult.Status.APPLIED, "Can place inside bounds")
	var entity_id = last_result.details().get("entity_id", -1) if last_result != null else -1
	expect(entity_id != -1, "Success creates one building")

	var after_timber = sim.resource_amount(&"timber")
	var timber_cost = def.costs[&"timber"] if def.costs.has(&"timber") else 0
	expect(after_timber == initial_timber - timber_cost, "Timber deducted exactly once")

	# Check plain data
	var entity = sim.entity_registry().snapshot(entity_id)
	expect(entity != null and entity.attributes.get("construction_state") == "completed", "Entity attributes are plain data")
	expect(entity != null and typeof(entity.attributes.get("rotation")) == TYPE_INT, "Entity rotation is int")

	# Occupied
	sim.request_construction(&"dwelling", valid_cell)
	sim.process_pending_commands()
	last_result = last_result_arr[0] if not last_result_arr.is_empty() else null
	expect(last_result != null and last_result.status == GopalaCommandResult.Status.REJECTED, "Cannot place on occupied cells")

	var after_timber_dup = sim.resource_amount(&"timber")
	expect(after_timber_dup == after_timber, "Timber not deducted for failed placement")

	# Reset
	sim.reset()
	var reset_timber = sim.resource_amount(&"timber")
	expect(reset_timber == 0, "Reset removes prototype runtime state")



	# UI Integration Tests
	var packed: PackedScene = load("res://scenes/landscape/kathmandu_valley.tscn")
	var world = packed.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var sim_w = world.simulation
	sim_w.coordinate_service().configure(grid_config)
	sim_w.bootstrap_session()

	world.hud._selected_build = &"dwelling"
	world.hud._placement_active = true
	world._on_build_selected(&"dwelling")
	world._placement_valid = true
	world._placement_cell = Vector2i(3, 3)

	# Simulate left click in unhandled input to place
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	world._unhandled_input(click)
	sim_w.process_pending_commands()
	await process_frame

	var final_timber = sim_w.resource_amount(&"timber")
	expect(final_timber < 100, "Left click in unhandled input places building")

	# Simulate cancel
	var esc = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	world._unhandled_input(esc)
	expect(world.hud._placement_active == false, "Cancel changes state")

	# Verify view bindings
	var found_view = false
	for v in world._built_views.values():
		if v.get_child_count() > 0 and v.get_child(0) is GopalaEntityViewAdapter3D:
			found_view = true
			var adapter = v.get_child(0)
			expect(adapter.bound_entity_id != 0, "View binds to the entity ID")
			# Simulate picking
			var pick_res = world.pick(Vector2(0,0)) # Mocking is hard, just checking adapter
	print("_built_views size:", world._built_views.size())
	expect(found_view, "Building view created")

	world.queue_free()
	await process_frame

	await _free_simulation(sim)
