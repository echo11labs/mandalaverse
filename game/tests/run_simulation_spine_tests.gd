extends SceneTree
## Block 1.5 deterministic settlement-simulation spine acceptance.

const MAIN_SCENE := preload("res://scenes/landscape/kathmandu_valley.tscn")
const SIMULATION_SCENE := preload("res://core/simulation/settlement_simulation.tscn")

var checks := 0
var failures: Array[String] = []
var _events: Array[String] = []
var _results: Array[GopalaCommandResult] = []
var _snapshots: Array[GopalaSettlementSnapshot] = []
var _tick_events: Array[int] = []
var _pause_events: Array[bool] = []
var _speed_events: Array[int] = []

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _initialize() -> void:
	run.call_deferred()

func _new_simulation() -> GopalaSettlementSimulation:
	var simulation := SIMULATION_SCENE.instantiate() as GopalaSettlementSimulation
	root.add_child(simulation)
	return simulation

func _on_snapshot(snapshot: GopalaSettlementSnapshot) -> void:
	_events.append("snapshot:%d" % snapshot.sequence)
	_snapshots.append(snapshot)

func _on_result(result: GopalaCommandResult) -> void:
	_events.append("result:%d" % result.command_id)
	_results.append(result)

func _on_tick(tick: int) -> void:
	_events.append("tick:%d" % tick)
	_tick_events.append(tick)

func _on_pause(paused: bool) -> void:
	_events.append("pause:%s" % str(paused))
	_pause_events.append(paused)

func _on_speed(speed: int) -> void:
	_events.append("speed:%d" % speed)
	_speed_events.append(speed)

func run() -> void:
	await _test_clock()
	await _test_commands()
	await _test_ledger_and_snapshots()
	await _test_reset_and_ids()
	await _test_scene_integration()
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _test_clock() -> void:
	var sim := _new_simulation()
	sim.command_processed.connect(_on_result)
	await process_frame
	expect(sim.paused and sim.logical_tick == 0 and sim.speed == 1,
		"new simulation begins paused at tick zero and speed one")
	expect(sim.resource_balances_snapshot().is_empty(), "production ledger starts empty")
	expect(is_equal_approx(sim.tick_interval_seconds(), 1.0), "prototype tick interval is one second from config")
	expect(not sim.advance_ticks(1) and sim.logical_tick == 0,
		"paused simulation does not advance through the manual tick API")
	var queued_pause := sim.set_paused(false)
	expect(queued_pause > 0 and sim.paused, "pause command acceptance does not mutate before processing")
	expect(sim.process_pending_commands() == 1 and not sim.paused,
		"pause command processes while the simulation clock was paused")
	expect(sim.advance_ticks(3) and sim.logical_tick == 3 and is_equal_approx(sim.elapsed_logical_time, 3.0),
		"manual ticks deterministically advance logical time")
	expect(not sim.advance_ticks(-1) and sim.logical_tick == 3,
		"negative manual tick count is rejected without state change")
	var start := sim.logical_tick
	sim._advance_runtime_delta_for_tests(4.0)
	expect(sim.logical_tick == start + 4, "runtime delta advances logical ticks when unpaused")
	sim.set_paused(true)
	sim.process_pending_commands()
	var paused_tick := sim.logical_tick
	sim._advance_runtime_delta_for_tests(20.0)
	expect(sim.logical_tick == paused_tick, "pause prevents runtime logical ticks")

	var whole := GopalaSimulationClock.new()
	whole.configure(1_000_000_000)
	whole.set_paused(false)
	whole.advance_frame(4.0)
	var partitioned := GopalaSimulationClock.new()
	partitioned.configure(1_000_000_000)
	partitioned.set_paused(false)
	for delta in [0.1, 0.3, 0.2, 0.4, 1.0, 2.0]:
		partitioned.advance_frame(delta)
	expect(whole.logical_tick == partitioned.logical_tick
		and whole.elapsed_logical_nanoseconds == partitioned.elapsed_logical_nanoseconds,
		"equal elapsed time with different frame partitions produces equal state")

	var runtime_paused_tick := sim.logical_tick
	sim._advance_runtime_delta_for_tests(5.0)
	expect(sim.logical_tick == runtime_paused_tick, "paused runtime accumulation freezes the tick")
	for speed_value in [1, 2, 3, 4]:
		sim.set_paused(true)
		sim.process_pending_commands()
		sim.set_speed(speed_value)
		var before_results := _results.size()
		sim.process_pending_commands()
		expect(sim.speed == speed_value and _results.size() == before_results + 1,
			"speed %dx accepted while paused" % speed_value)
	var invalid_id := sim.set_speed(5)
	sim.process_pending_commands()
	expect(sim.speed == 4 and _results.back().command_id == invalid_id
		and _results.back().status == GopalaCommandResult.Status.REJECTED,
		"invalid speed rejected without changing speed")
	sim.queue_free()
	await process_frame
	await process_frame

func _test_commands() -> void:
	_results.clear()
	_snapshots.clear()
	_events.clear()
	var sim := _new_simulation()
	sim.command_processed.connect(_on_result)
	sim.snapshot_committed.connect(_on_snapshot)
	sim.logical_tick_advanced.connect(_on_tick)
	sim.pause_changed.connect(_on_pause)
	sim.speed_changed.connect(_on_speed)
	await process_frame
	var original_payload := {"speed": 2}
	var nested_payload := {"nested": {"items": ["before"]}}
	var first_id := sim.submit_command(GopalaSimulationCommand.SET_SPEED, original_payload)
	expect(first_id > 0, "valid plain command submission returns its monotonic id")
	var copied_command := GopalaSimulationCommand._from_queue(50, &"TEST", 0, nested_payload, &"test")
	var escaped_payload: Dictionary = copied_command.payload
	escaped_payload["nested"]["items"][0] = "mutated copy"
	expect(copied_command.payload["nested"]["items"][0] == "before",
		"command payload getter returns a defensive deep copy")
	original_payload["speed"] = 4
	nested_payload["nested"]["items"][0] = "after"
	var second_id := sim.submit_command(GopalaSimulationCommand.SET_PAUSED, {"paused": false})
	expect(first_id == 1 and second_id == 2 and second_id > first_id,
		"command IDs are unique and monotonically increasing")
	var first_processed_count := sim.process_pending_commands()
	expect(first_processed_count == 2, "both FIFO commands processed while paused")
	expect(sim.speed == 2 and not sim.paused, "submitted payload was deep copied and commands applied FIFO")
	expect(_results.size() == 2 and _results[0].command_id == first_id
		and _results[1].command_id == second_id, "one typed result emitted in FIFO order")
	expect(_events == ["speed:2", "snapshot:2", "result:1", "pause:false", "snapshot:3", "result:2"],
		"state signal, committed snapshot, then typed result are emitted in order")

	var invalid_payload_id := sim.submit_command(GopalaSimulationCommand.SET_PAUSED, {"paused": "false"})
	expect(invalid_payload_id > 0, "submissions from result callbacks are deferred to the next queue drain")
	var unknown_id := sim.submit_command(&"MADE_UP", {})
	var forced_command := GopalaSimulationCommand._from_queue(900, GopalaSimulationCommand.SET_SPEED, sim.logical_tick, {"speed": 4}, &"")
	forced_command._payload["callback"] = Callable(self, "expect")
	var invalid_payload_result := sim._apply_command_for_tests(forced_command)
	expect(invalid_payload_result.status == GopalaCommandResult.Status.REJECTED
		and invalid_payload_result.reason_code == GopalaCommandResult.REASON_INVALID_PAYLOAD,
		"manually injected runtime-object command is rejected without mutation")
	var object_payload := {"node": Node.new()}
	var rejected_id := sim.submit_command(GopalaSimulationCommand.SET_SPEED, object_payload)
	(object_payload["node"] as Node).free()
	expect(rejected_id == 0, "runtime Object payload rejected on submission")
	var resource_payload := {"resource": load("res://data/resources/timber.tres")}
	expect(sim.submit_command(GopalaSimulationCommand.SET_SPEED, resource_payload) == 0,
		"Resource payload rejected on submission")
	expect(sim.submit_command(GopalaSimulationCommand.SET_SPEED, {"callback": Callable(self, "expect")}) == 0,
		"Callable payload rejected on submission")
	expect(sim.submit_command(GopalaSimulationCommand.SET_SPEED, {"signal": sim.command_processed}) == 0,
		"Signal payload rejected on submission")
	expect(sim.submit_command(GopalaSimulationCommand.SET_SPEED, {"rid": RID()}) == 0,
		"RID payload rejected on submission")
	expect(sim.process_pending_commands() == 2, "invalid and unknown commands each processed once")
	expect(_results.size() == 4 and _results[2].command_id == invalid_payload_id
		and _results[2].status == GopalaCommandResult.Status.REJECTED
		and _results[3].command_id == unknown_id
		and _results[3].reason_code == GopalaCommandResult.REASON_UNKNOWN_COMMAND,
		"invalid and unknown commands reject with typed results")
	expect(sim.speed == 2 and not sim.paused, "rejected commands never mutate state")
	expect(sim.process_pending_commands() == 0 and _results.size() == 4,
		"processed command IDs cannot be applied twice")

	var construction_id := sim.request_construction(&"dwelling", Vector2i(2, 3))
	var starting_id := sim._next_entity_id_for_tests()
	var starting_balances := sim.resource_balances_snapshot()
	var pending_before := sim._queue_pending_count_for_tests()
	sim.process_pending_commands()
	var construction_result: GopalaCommandResult = _results.back()
	expect(construction_id > 0 and construction_result.status == GopalaCommandResult.Status.UNSUPPORTED
		and construction_result.reason_code == GopalaCommandResult.REASON_PLACEMENT_UNAVAILABLE,
		"construction command returns UNSUPPORTED / PLACEMENT_UNAVAILABLE")
	expect(sim.resource_balances_snapshot() == starting_balances
		and sim._next_entity_id_for_tests() == starting_id
		and sim._queue_pending_count_for_tests() == 0 and pending_before == 1,
		"unsupported construction charges nothing, allocates no entity, and retains no construction state")
	sim.queue_free()
	await process_frame
	await process_frame

func _test_ledger_and_snapshots() -> void:
	var sim := _new_simulation()
	await process_frame
	sim._seed_resources_for_tests({&"timber": 4, &"stone": 1})
	expect(not sim.can_afford({&"timber": 8}), "insufficient cost is rejected")
	sim._reset_ledger_for_tests()
	expect(not sim.can_afford({&"timber": 1}), "empty ledger cannot afford positive cost")
	expect(not sim.validate_resource_transaction({&"timber": -1}), "negative balance transaction rejected")
	expect(not sim.validate_resource_transaction({&"invalid": 1}), "unknown resource ID rejected")
	expect(not sim.validate_resource_transaction({&"": 1}), "empty resource ID rejected")
	expect(not sim.validate_resource_transaction({&"timber": 1.5}), "non-integer resource delta rejected")
	expect(not sim.validate_resource_transaction([&"timber", 1]), "non-dictionary ledger transaction rejected")
	expect(not sim.validate_resource_transaction({&"timber": GopalaSimulationConfig.MAX_BALANCE + 1}),
		"overflow-risk resource delta rejected")
	expect(sim._seed_resources_for_tests({&"timber": 10, &"stone": 2}), "isolated test setup seeds ledger")
	expect(sim.can_afford({&"timber": 8, &"stone": 2}), "ledger can afford an available cost")
	expect(not sim.can_afford({&"timber": 11}), "ledger rejects insufficient cost")
	var before := sim.resource_balances_snapshot()
	expect(not sim.validate_resource_transaction({&"timber": -3, &"stone": -3}),
		"transaction invalid on one resource")
	expect(sim.resource_balances_snapshot() == before, "failed multi-resource validation leaves all balances unchanged")
	expect(sim.apply_authorized_transaction({&"timber": -4, &"stone": -1}),
		"authorized multi-resource transaction commits")
	expect(sim.resource_amount(&"timber") == 6 and sim.resource_amount(&"stone") == 1,
		"atomic transaction commits every delta")
	var balances_copy := sim.resource_balances_snapshot()
	balances_copy[&"timber"] = 999
	expect(sim.resource_amount(&"timber") == 6, "ledger snapshot is defensive")

	var prior_commit_sequence := sim._snapshot_sequence_for_tests()
	var old_snapshot := sim.snapshot()
	var old_sequence := old_snapshot.sequence
	var old_tick := old_snapshot.logical_tick
	var old_balances: Dictionary = old_snapshot.resource_balances
	var old_capabilities: Dictionary = old_snapshot.capabilities
	old_balances[&"timber"] = 777
	old_capabilities["population"] = true
	expect(sim.resource_amount(&"timber") == 6 and sim.capabilities()["population"] == false,
		"mutating returned snapshot collections cannot mutate simulation state")
	expect(old_snapshot.resource_balances[&"timber"] == 6
		and old_snapshot.capabilities["population"] == false,
		"snapshot collection getters return defensive deep copies")
	var snapshot_payload := {"mutable": [1, {"value": "original"}]}
	var standalone_snapshot := GopalaSettlementSnapshot.new(99, 3, true, 1, 3.0,
		{}, {"nested": snapshot_payload})
	snapshot_payload["mutable"][1]["value"] = "changed"
	var returned_capabilities: Dictionary = standalone_snapshot.capabilities
	returned_capabilities["nested"]["mutable"][1]["value"] = "mutated return"
	expect(standalone_snapshot.capabilities["nested"]["mutable"][1]["value"] == "original",
		"snapshot constructor defensively copies nested input data")
	var sequence_before := sim.snapshot().sequence
	sim.set_paused(false)
	sim.process_pending_commands()
	sim.advance_ticks(2)
	var new_snapshot := sim.snapshot()
	expect(new_snapshot.sequence > prior_commit_sequence and new_snapshot.sequence > old_sequence and new_snapshot.sequence > sequence_before,
		"committed snapshot sequences increase monotonically")
	expect(old_snapshot.sequence == old_sequence and old_snapshot.logical_tick == old_tick
		and old_snapshot.resource_balances[&"timber"] == 6,
		"older snapshot remains unchanged after ticks and ledger updates")
	expect(_capabilities_are_exact(sim.capabilities()), "capability table exactly covers supported and unsupported systems")

	var forbidden_payload := {"node": Node.new()}
	var invalid_snapshot := GopalaSettlementSnapshot.new(1, 0, true, 1, 0.0, forbidden_payload, {})
	expect(not invalid_snapshot.valid and invalid_snapshot.resource_balances.is_empty(),
		"snapshot constructor rejects runtime Objects without retaining them")
	(forbidden_payload["node"] as Node).free()
	sim.queue_free()
	await process_frame
	await process_frame

func _capabilities_are_exact(value: Dictionary) -> bool:
	var expected := {
		"simulation_clock": true, "command_queue": true, "resource_ledger": true, "snapshots": true,
		"entity_registry": true,
		"population": false, "villagers": false, "households": false, "buildings": false,
		"tasks": false, "inventory": false,
		"housing": false, "weather": false, "seasons": false,
		"selection": false, "placement": false, "occupancy": false, "construction": false,
		"professions": false, "production": false, "logistics": false, "alerts": false, "save_load": false,
	}
	return value == expected

func _test_reset_and_ids() -> void:
	var allocator := GopalaEntityIdAllocator.new()
	expect(allocator.allocate() == 1 and allocator.allocate() == 2 and allocator.allocate() == 3,
		"entity IDs begin at one and increase monotonically")
	allocator.reset_new_session()
	expect(allocator.allocate() == 1, "explicit new-session reset restarts entity IDs")
	var sim := _new_simulation()
	await process_frame
	var first_id := sim.set_speed(3)
	sim.set_paused(false)
	sim.process_pending_commands()
	var later_id := sim.set_speed(4)
	expect(later_id > first_id, "command IDs increase within a session")
	var queued_at_reset := sim.set_speed(4)
	sim.reset()
	expect(queued_at_reset > 0 and sim.paused and sim.speed == 1 and sim.logical_tick == 0
		and sim.resource_balances_snapshot().is_empty()
		and sim._next_entity_id_for_tests() == 1,
		"simulation reset clears transient state and begins a new ID session")
	expect(sim._queue_pending_count_for_tests() == 0, "reset clears pending commands")
	expect(sim._snapshot_sequence_for_tests() == 1,
		"reset starts a new snapshot sequence with the reset-state commit")
	var reset_id := sim.set_speed(2)
	expect(reset_id == 1, "command IDs restart after explicit simulation reset")
	var next_session_snapshot_id := sim._snapshot_sequence_for_tests()
	sim.process_pending_commands()
	expect(sim._snapshot_sequence_for_tests() > next_session_snapshot_id,
		"new-session snapshot sequence continues increasing after reset")
	sim.process_pending_commands()
	sim.queue_free()
	await process_frame
	await process_frame

	var reentrant := _new_simulation()
	await process_frame
	var reset_during_snapshot := func(_snapshot: GopalaSettlementSnapshot) -> void:
		reentrant.reset()
	reentrant.snapshot_committed.connect(reset_during_snapshot, CONNECT_ONE_SHOT)
	reentrant.set_speed(3)
	reentrant.set_paused(false)
	expect(reentrant.process_pending_commands() == 1,
		"a reset from a snapshot listener safely stops draining the cleared old-session batch")
	expect(reentrant.paused and reentrant.speed == 1 and reentrant._queue_pending_count_for_tests() == 0
		and reentrant._snapshot_sequence_for_tests() == 1,
		"reentrant reset leaves only the new session reset snapshot and no stale queued commands")
	reentrant.queue_free()
	await process_frame
	await process_frame

func _test_scene_integration() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var matches := main.find_children("SettlementSimulation", "GopalaSettlementSimulation", true, false)
	expect(matches.size() == 1, "Kathmandu main scene contains exactly one SettlementSimulation")
	if not matches.is_empty():
		var simulation := matches[0] as GopalaSettlementSimulation
		expect(simulation.paused and simulation.logical_tick == 0
			and simulation.resource_balances_snapshot().is_empty(),
			"scene-scoped main simulation starts paused, empty, and at tick zero")
		var freed: WeakRef = weakref(simulation)
		main.queue_free()
		await process_frame
		await process_frame
		expect(freed.get_ref() == null, "scene removal frees its simulation child")
	else:
		main.queue_free()
		await process_frame
