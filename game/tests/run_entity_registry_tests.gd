extends SceneTree
## Block 3 scene-owned entity registry acceptance. No gameplay records are seeded.

const SIMULATION_SCENE := preload("res://core/simulation/settlement_simulation.tscn")
const MAIN_SCENE := preload("res://scenes/landscape/kathmandu_valley.tscn")

var checks := 0
var failures: Array[String] = []
var _events: Array[String] = []
var _callback_results: Array[GopalaEntityOperationResult] = []
var _simulation_snapshots: Array[GopalaSettlementSnapshot] = []
var _settlement_event_positions: Array[int] = []

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

func _registry(simulation: GopalaSettlementSimulation) -> GopalaEntityRegistry:
	return simulation.entity_registry()

func _on_committed(snapshot: GopalaEntitySnapshot) -> void:
	_events.append("commit:%d:%d" % [snapshot.entity_id, snapshot.revision])

func _on_removed(entity_id: int, kind: StringName, sequence: int) -> void:
	_events.append("removed:%d:%s:%d" % [entity_id, String(kind), sequence])

func _on_registry_changed(snapshot: GopalaEntityRegistrySnapshot) -> void:
	_events.append("changed:%d:%d" % [snapshot.registry_sequence, snapshot.entity_count])

func _on_registry_reset() -> void:
	_events.append("reset")

func _on_simulation_snapshot(snapshot: GopalaSettlementSnapshot) -> void:
	_simulation_snapshots.append(snapshot)
	_settlement_event_positions.append(_events.size())

func run() -> void:
	await _test_ownership_and_fresh_state()
	await _test_create_and_plain_data()
	await _test_update_and_snapshots()
	await _test_links_removal_and_indexes()
	await _test_signal_order_reentrancy_and_reset()
	await _test_scene_lifecycle()
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _test_ownership_and_fresh_state() -> void:
	var simulation := _new_simulation()
	await process_frame
	var registry := _registry(simulation)
	expect(registry != null and is_instance_valid(registry), "simulation owns a valid EntityRegistry")
	var children := simulation.find_children("*", "GopalaEntityRegistry", false, false)
	expect(children.size() == 1 and children[0] == registry, "exactly one direct EntityRegistry child exists")
	expect(registry.get_parent() == simulation, "registry lifetime is a direct child of its settlement session")
	expect(registry.allocator == simulation._entity_allocator_for_tests(),
		"SettlementSimulation explicitly injects its existing ID allocator")
	expect(registry.entity_count == 0 and registry.registry_sequence == 0,
		"fresh registry is empty at sequence zero")
	var empty := registry.registry_snapshot()
	expect(empty.valid and empty.entity_count == 0 and empty.registry_sequence == 0
		and empty.counts_by_kind.is_empty() and empty.entities.is_empty(),
		"fresh registry snapshot reports an empty sequence-zero registry")
	var settlement := simulation.snapshot()
	expect(settlement.valid and settlement.capabilities["entity_registry"]
		and settlement.entity_count == 0 and settlement.entity_counts_by_kind.is_empty()
		and settlement.entity_registry_sequence == 0,
		"settlement snapshot advertises empty registry capability and summary")
	expect(not settlement.capabilities["population"] and not settlement.capabilities["villagers"]
		and not settlement.capabilities["households"] and not settlement.capabilities["buildings"]
		and not settlement.capabilities["tasks"]
		and not settlement.capabilities["inventory"] and not settlement.capabilities["save_load"]
		and not settlement.capabilities["selection"] and not settlement.capabilities["placement"]
		and not settlement.capabilities["construction"],
		"domain gameplay capabilities remain unsupported")
	await _free_simulation(simulation)

func _test_create_and_plain_data() -> void:
	var simulation := _new_simulation()
	await process_frame
	var registry := _registry(simulation)
	var first_attributes := {"nested": {"values": ["original", 3, true]}}
	var first := registry.create_entity(GopalaEntityKind.SETTLEMENT, first_attributes, {}, 0)
	expect(first.valid and first.status == GopalaEntityOperationResult.Status.APPLIED
		and first.reason_code == GopalaEntityOperationResult.APPLIED and first.entity_id == 1
		and first.registry_sequence == 1,
		"valid creation allocates ID one and commits one sequence")
	first_attributes["nested"]["values"][0] = "caller-mutated"
	expect(registry.snapshot(1).attributes["nested"]["values"][0] == "original",
		"creation defensively copies nested caller attributes")
	var link_input := {"related": [first.entity_id]}
	var second := registry.create_entity(GopalaEntityKind.VILLAGER,
		{"label": "fixture"}, link_input, 0)
	link_input["related"].append(99)
	expect(second.entity_id == 2 and second.registry_sequence == 2
		and registry.snapshot(second.entity_id).links["related"] == [first.entity_id],
		"second creation allocates ID two and defensively copies caller links")
	var invalids: Array[GopalaEntityOperationResult] = [
		registry.create_entity(&"", {}, {}, 0),
		registry.create_entity(&"unknown_kind", {}, {}, 0),
		registry.create_entity(GopalaEntityKind.ROAD, {}, {}, -1),
		registry.create_entity(GopalaEntityKind.ROAD, {"bad": INF}, {}, 0),
	]
	expect(invalids[0].reason_code == GopalaEntityOperationResult.INVALID_KIND
		and invalids[1].reason_code == GopalaEntityOperationResult.INVALID_KIND,
		"empty and unknown entity kinds reject centrally")
	expect(invalids[2].reason_code == GopalaEntityOperationResult.INVALID_TICK
		and invalids[3].reason_code == GopalaEntityOperationResult.INVALID_ATTRIBUTES,
		"negative ticks and non-finite attribute values reject")
	var nested_node := Node.new()
	var nested_reject := registry.create_entity(GopalaEntityKind.ROAD, {"nested": [nested_node]}, {}, 0)
	nested_node.free()
	expect(nested_reject.reason_code == GopalaEntityOperationResult.INVALID_ATTRIBUTES,
		"runtime Objects reject recursively from attributes")
	var runtime_node := Node.new()
	var runtime_resource := load("res://data/resources/timber.tres")
	var object_values := [runtime_node, runtime_resource, Callable(self, "expect"), RID()]
	var object_rejected := true
	for value in object_values:
		object_rejected = object_rejected and not GopalaPlainData.validate({"deep": [{"value": value}]})
	expect(object_rejected, "Node, Resource, Callable and RID reject recursively")
	runtime_node.free()
	var cycle: Array = []
	cycle.append(cycle)
	expect(not GopalaPlainData.validate(cycle), "recursive container cycles reject without recursion overflow")
	var too_deep: Variant = "leaf"
	for _i in range(GopalaPlainData.MAX_NESTING_DEPTH + 2):
		too_deep = [too_deep]
	expect(not GopalaPlainData.validate(too_deep), "containers deeper than the shared limit reject")
	var missing_target := registry.create_entity(GopalaEntityKind.TASK, {}, {"parent": 4242}, 0)
	expect(missing_target.reason_code == GopalaEntityOperationResult.REFERENCE_NOT_FOUND,
		"creation links reject missing targets")
	expect(registry.registry_sequence == 2 and simulation._next_entity_id_for_tests() == 3,
		"all invalid creations leave sequence and allocator unchanged")
	expect(not registry.has_entity(3) and registry.validate_reference(1)
		and not registry.validate_reference(9999),
		"safe reference validation recognizes live IDs only")
	await _free_simulation(simulation)

func _test_update_and_snapshots() -> void:
	var simulation := _new_simulation()
	await process_frame
	var registry := _registry(simulation)
	var created := registry.create_entity(GopalaEntityKind.HOUSEHOLD,
		{"name": "first", "remove_me": "yes", "nested": {"items": [1, 2]}}, {}, 2)
	var old_snapshot := registry.snapshot(created.entity_id)
	var old_attributes := old_snapshot.attributes
	old_attributes["nested"]["items"][0] = 999
	var old_links := old_snapshot.links
	old_links["escaped"] = 1
	expect(old_snapshot.attributes["nested"]["items"][0] == 1 and old_snapshot.links.is_empty(),
		"snapshot collection getters are defensive copies")
	var patch := {"name": "updated", "remove_me": null, "new": ["safe"]}
	var before_sequence := registry.registry_sequence
	var updated := registry.update_entity(created.entity_id, patch, {}, 4, 1)
	patch["new"].append("outside")
	expect(updated.status == GopalaEntityOperationResult.Status.APPLIED
		and registry.registry_sequence == before_sequence + 1,
		"successful update commits exactly one registry transaction")
	var current := registry.snapshot(created.entity_id)
	expect(current.revision == 2 and current.updated_tick == 4
		and current.attributes["name"] == "updated" and not current.attributes.has("remove_me")
		and current.attributes["new"] == ["safe"],
		"update increments revision and null patch values remove top-level attribute keys")
	expect(old_snapshot.revision == 1 and old_snapshot.updated_tick == 2
		and old_snapshot.attributes["name"] == "first"
		and old_snapshot.attributes["nested"]["items"] == [1, 2],
		"previous entity snapshot remains immutable after record update")
	var stable_sequence := registry.registry_sequence
	var stable_record := registry.snapshot(created.entity_id)
	var invalid_node := Node.new()
	var failed := registry.update_entity(created.entity_id, {"bad": invalid_node}, {}, 5)
	invalid_node.free()
	var backwards := registry.update_entity(created.entity_id, {"late": true}, {}, 3)
	var stale := registry.update_entity(created.entity_id, {"late": true}, {}, 5, 1)
	var missing_link := registry.update_entity(created.entity_id, {}, {"parent": 9000}, 5)
	expect(failed.reason_code == GopalaEntityOperationResult.INVALID_ATTRIBUTES
		and backwards.reason_code == GopalaEntityOperationResult.INVALID_TICK
		and stale.reason_code == GopalaEntityOperationResult.STALE_REVISION
		and missing_link.reason_code == GopalaEntityOperationResult.REFERENCE_NOT_FOUND,
		"invalid payload, backward tick, stale revision and missing link reject with typed reasons")
	expect(registry.registry_sequence == stable_sequence
		and registry.snapshot(created.entity_id).revision == stable_record.revision
		and registry.snapshot(created.entity_id).attributes == stable_record.attributes,
		"failed updates are atomic and preserve data, revision, and sequence")
	var links_invalid := registry.create_entity(GopalaEntityKind.TASK, {}, {"": 1}, 5)
	var duplicates := registry.create_entity(GopalaEntityKind.TASK, {}, {"members": [created.entity_id, created.entity_id]}, 5)
	expect(links_invalid.reason_code == GopalaEntityOperationResult.INVALID_LINKS
		and duplicates.reason_code == GopalaEntityOperationResult.INVALID_LINKS,
		"empty link names and duplicate IDs within one relationship reject")
	var counts_copy := registry.registry_snapshot().counts_by_kind
	counts_copy[GopalaEntityKind.ROAD] = 42
	expect(registry.registry_snapshot().counts_by_kind.get(GopalaEntityKind.ROAD, 0) == 0,
		"registry snapshot counts are defensive copies")
	var entities_copy := registry.registry_snapshot().entities
	entities_copy.clear()
	expect(registry.registry_snapshot().entity_count == 1,
		"registry snapshot entity list is returned as a defensive array copy")
	await process_frame
	var sim_snapshot := simulation.snapshot()
	expect(sim_snapshot.entity_count == 1 and sim_snapshot.entity_counts_by_kind[GopalaEntityKind.HOUSEHOLD] == 1
		and sim_snapshot.entity_registry_sequence == registry.registry_sequence,
		"settlement snapshot integrates registry count, per-kind counts, and sequence")
	await _free_simulation(simulation)

func _test_links_removal_and_indexes() -> void:
	var simulation := _new_simulation()
	await process_frame
	var registry := _registry(simulation)
	registry.entity_committed.connect(_on_committed)
	registry.entity_removed.connect(_on_removed)
	registry.registry_changed.connect(_on_registry_changed)
	var target := registry.create_entity(GopalaEntityKind.SETTLEMENT, {}, {}, 0)
	var source_b := registry.create_entity(GopalaEntityKind.TASK, {}, {"target": target.entity_id}, 1)
	var source_a := registry.create_entity(GopalaEntityKind.TASK, {},
		{"target": [target.entity_id], "other": target.entity_id}, 2)
	var source_c := registry.create_entity(GopalaEntityKind.ROAD, {}, {}, 3)
	expect(source_a.status == GopalaEntityOperationResult.Status.APPLIED
		and source_b.status == GopalaEntityOperationResult.Status.APPLIED,
		"links accept only references to live entities")
	var inbound := registry._incoming_for_tests(target.entity_id)
	expect(inbound.size() == 3, "incoming-reference index records every source relationship")
	var query := registry.snapshots_by_kind(GopalaEntityKind.TASK)
	expect(query.size() == 2 and query[0].entity_id == source_b.entity_id
		and query[1].entity_id == source_a.entity_id,
		"kind query returns deterministic ascending ID order")
	var before_reject_sequence := registry.registry_sequence
	var rejected := registry.remove_entity(target.entity_id,
		GopalaEntityRegistry.RemovalPolicy.REJECT_IF_REFERENCED, 3)
	var reject_details := rejected.details()
	var blockers: Array = reject_details.get("blockers", [])
	expect(rejected.reason_code == GopalaEntityOperationResult.REFERENCED_BY
		and blockers.size() == 3 and int(blockers[0]["entity_id"]) == source_b.entity_id
		and String(blockers[0]["relationship"]) == "target"
		and int(blockers[1]["entity_id"]) == source_a.entity_id
		and String(blockers[1]["relationship"]) == "other"
		and int(blockers[2]["entity_id"]) == source_a.entity_id
		and String(blockers[2]["relationship"]) == "target",
		"REJECT_IF_REFERENCED reports every blocker deterministically")
	expect(registry.has_entity(target.entity_id) and registry.registry_sequence == before_reject_sequence,
		"referenced removal rejection has no mutation")
	var failed_clear := registry.remove_entity(target.entity_id,
		GopalaEntityRegistry.RemovalPolicy.CLEAR_INCOMING_REFERENCES, 0)
	expect(failed_clear.reason_code == GopalaEntityOperationResult.INVALID_TICK
		and registry.has_entity(target.entity_id) and registry.registry_sequence == before_reject_sequence,
		"clear-removal rejects if its tick would move a referring record backward")
	_events.clear()
	var clear_sequence := registry.registry_sequence
	var removed := registry.remove_entity(target.entity_id,
		GopalaEntityRegistry.RemovalPolicy.CLEAR_INCOMING_REFERENCES, 5)
	expect(removed.status == GopalaEntityOperationResult.Status.APPLIED
		and removed.registry_sequence == clear_sequence + 1
		and not registry.has_entity(target.entity_id)
		and registry._was_removed_for_tests(target.entity_id),
		"clear-incoming removal deletes target and advances sequence exactly once")
	var clean_b := registry.snapshot(source_b.entity_id)
	var clean_a := registry.snapshot(source_a.entity_id)
	expect(clean_b.revision == 2 and clean_b.updated_tick == 5 and clean_b.links.is_empty()
		and clean_a.revision == 2 and clean_a.updated_tick == 5 and clean_a.links.is_empty(),
		"all referring records clear atomically and increment revision")
	expect(registry._incoming_for_tests(target.entity_id).is_empty(),
		"incoming-reference index removes deleted target and cleared edges")
	expect(_events == ["commit:%d:2" % source_b.entity_id,
		"commit:%d:2" % source_a.entity_id,
		"removed:%d:settlement:%d" % [target.entity_id, removed.registry_sequence],
		"changed:%d:3" % removed.registry_sequence],
		"remove signal order is sorted incoming commits, removal, then registry change; actual=" + str(_events))
	var not_found := registry.snapshot(target.entity_id)
	var remove_unknown := registry.remove_entity(9999,
		GopalaEntityRegistry.RemovalPolicy.REJECT_IF_REFERENCED, 6)
	var invalid_policy: Variant = registry.remove_entity.call(source_c.entity_id, 999, 6)
	expect(not_found == null and not registry.has_entity(target.entity_id)
		and remove_unknown.reason_code == GopalaEntityOperationResult.NOT_FOUND
		and invalid_policy.reason_code == GopalaEntityOperationResult.INVALID_REMOVAL_POLICY,
		"removed and unknown IDs are not found and invalid policies reject")
	var unreferenced := registry.remove_entity(source_c.entity_id,
		GopalaEntityRegistry.RemovalPolicy.REJECT_IF_REFERENCED, 6)
	expect(unreferenced.status == GopalaEntityOperationResult.Status.APPLIED
		and not registry.has_entity(source_c.entity_id),
		"unreferenced entity removes cleanly with no blockers")
	var new_entity := registry.create_entity(GopalaEntityKind.ROAD, {}, {}, 6)
	expect(new_entity.entity_id > target.entity_id,
		"removed IDs are not reused within the session")
	var final_snapshot := registry.registry_snapshot()
	expect(final_snapshot.entity_count == 3
		and final_snapshot.counts_by_kind[GopalaEntityKind.TASK] == 2
		and final_snapshot.counts_by_kind[GopalaEntityKind.ROAD] == 1,
		"registry-wide snapshot reports accurate entity and kind counts")
	await _free_simulation(simulation)

func _test_signal_order_reentrancy_and_reset() -> void:
	var simulation := _new_simulation()
	await process_frame
	var registry := _registry(simulation)
	registry.entity_committed.connect(_on_committed)
	registry.entity_removed.connect(_on_removed)
	registry.registry_changed.connect(_on_registry_changed)
	registry.registry_reset.connect(_on_registry_reset)
	simulation.snapshot_committed.connect(_on_simulation_snapshot)
	var reentrant_results: Array[GopalaEntityOperationResult] = []
	var visible_reads: Array[bool] = []
	var callback := func(snapshot: GopalaEntitySnapshot) -> void:
		var live: GopalaEntitySnapshot = registry.snapshot(snapshot.entity_id)
		visible_reads.append(live != null and live.revision == snapshot.revision
			and live.updated_tick == snapshot.updated_tick
			and registry.registry_sequence == snapshot.registry_sequence)
		var attempt := registry.create_entity(GopalaEntityKind.ROAD, {}, {}, 0)
		reentrant_results.append(attempt)
	registry.entity_committed.connect(callback, CONNECT_ONE_SHOT)
	_events.clear()
	var created := registry.create_entity(GopalaEntityKind.SETTLEMENT, {}, {}, 0)
	expect(created.status == GopalaEntityOperationResult.Status.APPLIED
		and reentrant_results.size() == 1
		and reentrant_results[0].reason_code == GopalaEntityOperationResult.REENTRANT_MUTATION,
		"mutation from a commit signal is rejected without recursion")
	expect(visible_reads.size() == 1 and visible_reads[0],
		"reads inside post-commit signals observe the committed record and sequence")
	expect(_events.slice(0, 2) == ["commit:1:1", "changed:1:1"],
		"create signal order is entity commit then registry change")
	expect(registry.entity_count == 1 and registry.registry_sequence == 1
		and simulation._next_entity_id_for_tests() == 2,
		"reentrant failure consumes no ID and changes no counts or sequence")
	expect(_settlement_event_positions.size() == 1 and _settlement_event_positions[0] == 2,
		"settlement snapshot is committed after entity and registry-change signals finish")
	var update := registry.update_entity(created.entity_id, {"after": true}, {}, 1)
	expect(update.status == GopalaEntityOperationResult.Status.APPLIED
		and _events.slice(2, 4) == ["commit:1:2", "changed:2:1"],
		"update signal order is entity commit then registry change")
	var reset_result := registry.reset()
	expect(reset_result and _events.slice(4, 6) == ["reset", "changed:0:0"],
		"registry reset emits one reset signal then one empty registry snapshot")
	expect(registry.entity_count == 0 and registry.registry_sequence == 0
		and registry._kind_index_for_tests().is_empty()
		and registry._incoming_for_tests(created.entity_id).is_empty()
		and not registry._was_removed_for_tests(created.entity_id),
		"registry reset clears records, indexes, incoming edges, sequence, and tombstones")
	var reset_id := registry.create_entity(GopalaEntityKind.SETTLEMENT, {}, {}, 0)
	expect(reset_id.entity_id == 2,
		"registry-only reset leaves allocator session unchanged and does not reuse prior ID")
	await process_frame
	expect(not _simulation_snapshots.is_empty()
		and _simulation_snapshots.back().entity_count == 1
		and _simulation_snapshots.back().entity_registry_sequence == registry.registry_sequence,
		"settlement snapshot updates after registry transaction signals complete")
	await _free_simulation(simulation)

func _test_scene_lifecycle() -> void:
	var simulation := _new_simulation()
	await process_frame
	var registry := _registry(simulation)
	var registry_ref: WeakRef = weakref(registry)
	var simulation_ref: WeakRef = weakref(simulation)
	var reset_signals := [0]
	simulation.session_reset.connect(func() -> void: reset_signals[0] += 1)
	var entity := registry.create_entity(GopalaEntityKind.SETTLEMENT, {}, {}, 0)
	expect(entity.entity_id == 1, "new simulation begins a new allocator session")
	expect(simulation.reset() and reset_signals[0] == 1,
		"session reset succeeds once and announces completion after registry clearing")
	expect(simulation.paused and simulation.speed == 1 and simulation.logical_tick == 0
		and registry.entity_count == 0 and registry.registry_sequence == 0
		and simulation._next_entity_id_for_tests() == 1
		and simulation._queue_pending_count_for_tests() == 0,
		"session reset clears registry, queue, clock, ledger, sequences and restarts allocator")
	var after_reset := registry.create_entity(GopalaEntityKind.SETTLEMENT, {}, {}, 0)
	expect(after_reset.entity_id == 1,
		"session reset permits ID one only in the new session")
	simulation.queue_free()
	await process_frame
	await process_frame
	expect(not is_instance_valid(registry_ref.get_ref())
		and not is_instance_valid(simulation_ref.get_ref()),
		"removing the settlement session frees its registry child")
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var sessions := main.find_children("SettlementSimulation", "GopalaSettlementSimulation", true, false)
	expect(sessions.size() == 1, "main Kathmandu scene contains exactly one session")
	if sessions.size() == 1:
		var registries := sessions[0].find_children("EntityRegistry", "GopalaEntityRegistry", true, false)
		expect(registries.size() == 1 and registries[0].get_parent() == sessions[0]
			and registries[0].entity_count == 0,
			"main scene session has one direct empty registry and no production entities")
	main.queue_free()
	await process_frame
	await process_frame

func _free_simulation(simulation: GopalaSettlementSimulation) -> void:
	simulation.queue_free()
	await process_frame
	await process_frame
