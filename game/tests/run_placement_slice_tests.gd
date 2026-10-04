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
	
	var out_of_bounds_cell = Vector2i(1000, 1000)
	sim.request_construction(&"dwelling", out_of_bounds_cell)
	sim.process_pending_commands()
	var last_result: GopalaCommandResult = last_result_arr[0] if not last_result_arr.is_empty() else null
	expect(last_result != null and last_result.status == GopalaCommandResult.Status.REJECTED, "Cannot place out of bounds")
	expect(last_result != null and last_result.reason_code == &"OUT_OF_BOUNDS", "OOB reason is correct")
	
	var valid_cell = Vector2i(0, 0)
	sim.request_construction(&"dwelling", valid_cell)
	sim.process_pending_commands()
	last_result = last_result_arr[0] if not last_result_arr.is_empty() else null
	expect(last_result != null and last_result.status == GopalaCommandResult.Status.APPLIED, "Can place inside bounds")
	
	var after_timber = sim.resource_amount(&"timber")
	expect(after_timber == initial_timber - def.costs.get("timber", 0), "Timber deducted")
	
	sim.request_construction(&"dwelling", valid_cell)
	sim.process_pending_commands()
	last_result = last_result_arr[0] if not last_result_arr.is_empty() else null
	expect(last_result != null and last_result.status == GopalaCommandResult.Status.REJECTED, "Cannot place on occupied cells")
	
	var after_timber_dup = sim.resource_amount(&"timber")
	expect(after_timber_dup == after_timber, "Timber not deducted for failed placement")
	
	await _free_simulation(sim)
