extends SceneTree
## Block 4 selection and inspection foundation acceptance. Test fixtures may
## create entities explicitly; the main Kathmandu scene must stay empty.

const SIMULATION_SCENE := preload("res://core/simulation/settlement_simulation.tscn")
const MAIN_SCENE := preload("res://scenes/landscape/kathmandu_valley.tscn")

var checks := 0
var failures: Array[String] = []
var _events: Array[String] = []

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

func _free_simulation(simulation: GopalaSettlementSimulation) -> void:
	simulation.queue_free()
	await process_frame
	await process_frame

func run() -> void:
	await _test_ownership_and_query_facade()
	await _test_selection_lifecycle()
	await _test_snapshots_and_immutability()
	await _test_refresh_and_update()
	await _test_removal_and_reset()
	await _test_reentrancy_and_signal_reads()
	await _test_adapter()
	await _test_resolver()
	await _test_synthetic_picking()
	await _test_main_scene()
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _test_ownership_and_query_facade() -> void:
	var simulation := _new_simulation()
	await process_frame
	# 1. Exactly one query service and selection service per session.
	var queries_nodes := simulation.find_children("EntityQueryService", "GopalaEntityQueryService", false, false)
	var selection_nodes := simulation.find_children("SelectionService", "GopalaSelectionService", false, false)
	expect(queries_nodes.size() == 1 and selection_nodes.size() == 1,
		"session owns exactly one EntityQueryService and one SelectionService")
	var queries := simulation.entity_queries()
	var selection := simulation.selection_service()
	var registry := simulation.entity_registry()
	expect(queries_nodes[0] == queries and selection_nodes[0] == selection
		and queries.get_parent() == simulation and selection.get_parent() == simulation,
		"services are direct children of SettlementSimulation, not autoloads")
	# 2. Both receive explicit dependencies (one-shot injection).
	var other_registry := GopalaEntityRegistry.new()
	var other_queries := GopalaEntityQueryService.new()
	expect(not queries.configure(other_registry), "query facade injection is one-shot")
	expect(not selection.configure(other_queries, registry), "selection injection is one-shot")
	var fresh_queries := GopalaEntityQueryService.new()
	expect(fresh_queries.configure(other_registry), "fresh facade accepts its first dependency")
	var fresh_queries2 := GopalaEntityQueryService.new()
	expect(fresh_queries2.configure(other_registry) and not fresh_queries2.configure(other_registry),
		"fresh facade proves one-shot configure semantics")
	fresh_queries.free()
	fresh_queries2.free()
	other_registry.free()
	other_queries.free()
	var fresh_selection := GopalaSelectionService.new()
	var unconfigured := fresh_selection.select_entity(1)
	expect(unconfigured.status == GopalaSelectionResult.Status.REJECTED
		and unconfigured.reason_code == GopalaSelectionResult.NOT_CONFIGURED,
		"unconfigured selection rejects without dependencies")
	fresh_selection.free()
	# 3. Query facade reads existing entities.
	var created := registry.create_entity(GopalaEntityKind.BUILDING, {"fixture": true}, {}, 0)
	expect(created.status == GopalaEntityOperationResult.Status.APPLIED, "fixture entity created for reads")
	var entity_id := created.entity_id
	expect(queries.has_entity(entity_id) and queries.validate_reference(entity_id)
		and not queries.validate_reference(99999),
		"facade validates live and missing references")
	expect(queries.snapshot(entity_id) != null and queries.snapshot(entity_id).entity_id == entity_id,
		"facade reads one entity snapshot by ID")
	var by_kind := queries.snapshots_by_kind(GopalaEntityKind.BUILDING)
	expect(by_kind.size() == 1 and by_kind[0].entity_id == entity_id,
		"facade reads snapshots by kind")
	var summary := queries.registry_summary()
	expect(summary["entity_count"] == 1 and summary["registry_sequence"] == 1
		and summary["counts_by_kind"][GopalaEntityKind.BUILDING] == 1,
		"facade reads a defensive registry summary")
	summary["entity_count"] = 99
	expect(queries.registry_summary()["entity_count"] == 1, "registry summary returns defensive copies")
	# 4. Query facade exposes no mutation methods.
	var forbidden := ["create_entity", "update_entity", "remove_entity", "reset",
		"entity_registry", "allocator", "allocate", "select_entity", "clear_selection"]
	var leaked: Array[String] = []
	for method in forbidden:
		if queries.has_method(method):
			leaked.append(method)
	expect(leaked.is_empty(), "query facade exposes no mutation/reset/selection methods: " + str(leaked))
	expect(not selection.has_method("create_entity") and not selection.has_method("update_entity")
		and not selection.has_method("remove_entity") and not selection.has_method("reset_registry"),
		"selection service exposes no registry mutation methods")
	await _free_simulation(simulation)

func _test_selection_lifecycle() -> void:
	var simulation := _new_simulation()
	await process_frame
	var queries := simulation.entity_queries()
	var selection := simulation.selection_service()
	var registry := simulation.entity_registry()
	var a := registry.create_entity(GopalaEntityKind.BUILDING, {}, {}, 0).entity_id
	var b := registry.create_entity(GopalaEntityKind.ROAD, {}, {}, 0).entity_id
	selection.selection_changed.connect(func(s: GopalaSelectionSnapshot, r: GopalaSelectionResult) -> void:
		_events.append("changed:%d:%s:%d" % [s.selected_entity_id, String(r.reason_code), s.selection_sequence]))
	# 5. Fresh selection is NONE at sequence 0.
	var fresh := selection.snapshot()
	expect(fresh.valid and fresh.state == GopalaSelectionSnapshot.State.NONE
		and fresh.selection_sequence == 0 and fresh.selected_entity_id == 0,
		"fresh selection is NONE at sequence zero")
	# 6. Valid ID can be selected.
	_events.clear()
	var selected := selection.select_entity(a)
	expect(selected.status == GopalaSelectionResult.Status.APPLIED
		and selected.reason_code == GopalaSelectionResult.SELECTED
		and selected.previous_entity_id == 0 and selection.selected_entity_id == a
		and selection.selection_sequence == 1,
		"valid ID selects and increments selection sequence once")
	expect(_events == ["changed:%d:SELECTED:1" % a], "select emits exactly one selection_changed")
	# 7. Missing/invalid IDs reject.
	var missing := selection.select_entity(99999)
	var invalid := selection.select_entity(0)
	expect(missing.status == GopalaSelectionResult.Status.REJECTED
		and missing.reason_code == GopalaSelectionResult.NOT_FOUND
		and invalid.status == GopalaSelectionResult.Status.REJECTED
		and invalid.reason_code == GopalaSelectionResult.INVALID_ID,
		"missing and invalid IDs reject with typed reasons")
	# 8. Invalid selection does not clear the existing selection.
	expect(selection.selected_entity_id == a and selection.selection_sequence == 1,
		"failed selections never clear or bump the current selection")
	# 9. Selecting the same ID is UNCHANGED and emits nothing.
	_events.clear()
	var same := selection.select_entity(a)
	expect(same.status == GopalaSelectionResult.Status.UNCHANGED
		and same.reason_code == GopalaSelectionResult.ALREADY_SELECTED
		and selection.selection_sequence == 1 and _events.is_empty(),
		"reselecting the same ID is UNCHANGED and silent")
	# 10. Selecting another valid ID atomically replaces.
	_events.clear()
	var replaced := selection.select_entity(b)
	expect(replaced.status == GopalaSelectionResult.Status.APPLIED
		and replaced.reason_code == GopalaSelectionResult.REPLACED
		and replaced.previous_entity_id == a and selection.selected_entity_id == b
		and selection.selection_sequence == 2,
		"selecting another ID atomically replaces with REPLACED")
	expect(_events == ["changed:%d:REPLACED:2" % b], "replacement emits exactly one selection_changed")
	# 11. Clear increments sequence once.
	_events.clear()
	var cleared := selection.clear_selection()
	expect(cleared.status == GopalaSelectionResult.Status.APPLIED
		and cleared.reason_code == GopalaSelectionResult.CLEARED
		and cleared.previous_entity_id == b and selection.selected_entity_id == 0
		and selection.selection_sequence == 3,
		"clearing a selection increments the sequence once")
	expect(_events == ["changed:0:CLEARED:3"], "clear emits exactly one selection_changed")
	# 12. Clear while empty is UNCHANGED.
	_events.clear()
	var clear_empty := selection.clear_selection()
	expect(clear_empty.status == GopalaSelectionResult.Status.UNCHANGED
		and clear_empty.reason_code == GopalaSelectionResult.ALREADY_CLEAR
		and selection.selection_sequence == 3 and _events.is_empty(),
		"clearing an empty selection is UNCHANGED and silent")
	await _free_simulation(simulation)

func _test_snapshots_and_immutability() -> void:
	var simulation := _new_simulation()
	await process_frame
	var queries := simulation.entity_queries()
	var selection := simulation.selection_service()
	var registry := simulation.entity_registry()
	var a := registry.create_entity(GopalaEntityKind.HOUSEHOLD, {"name": "alpha", "nested": {"v": [1]}}, {}, 0).entity_id
	selection.select_entity(a)
	var selected_snapshot := selection.snapshot()
	# 13. Selection snapshots are immutable.
	expect(selected_snapshot.valid and selected_snapshot.state == GopalaSelectionSnapshot.State.ENTITY
		and selected_snapshot.selected_entity_id == a
		and selected_snapshot.selected_kind == GopalaEntityKind.HOUSEHOLD
		and selected_snapshot.selected_entity_revision == 1
		and selected_snapshot.selected_registry_sequence == 1
		and selected_snapshot.schema_version == GopalaSelectionSnapshot.SCHEMA_VERSION,
		"selection snapshot carries full identity and sequence fields")
	var copied_attrs := selected_snapshot.entity.attributes
	copied_attrs["name"] = "mutated"
	copied_attrs["nested"]["v"][0] = 999
	expect(selected_snapshot.entity.attributes["name"] == "alpha"
		and selected_snapshot.entity.attributes["nested"]["v"] == [1],
		"embedded entity snapshot getters return defensive copies")
	# 14. Returned attributes/links cannot mutate registry state.
	var entity_snapshot := queries.snapshot(a)
	var out_attrs := entity_snapshot.attributes
	out_attrs["injected"] = true
	expect(registry.snapshot(a).attributes.get("injected", false) == false,
		"mutating returned attributes cannot mutate registry records")
	selection.clear_selection()
	var older := selected_snapshot
	registry.update_entity(a, {"name": "beta"}, {}, 1)
	expect(older.entity.attributes["name"] == "alpha" and older.selected_entity_revision == 1,
		"old selection snapshot remains unchanged after later updates")
	await _free_simulation(simulation)

func _test_refresh_and_update() -> void:
	var simulation := _new_simulation()
	await process_frame
	var queries := simulation.entity_queries()
	var selection := simulation.selection_service()
	var registry := simulation.entity_registry()
	var a := registry.create_entity(GopalaEntityKind.BUILDING, {"label": "one"}, {}, 0).entity_id
	selection.select_entity(a)
	var sequence_before := selection.selection_sequence
	var refreshes: Array[GopalaSelectionSnapshot] = []
	var changes: Array[GopalaSelectionResult] = []
	selection.selected_entity_refreshed.connect(func(s: GopalaSelectionSnapshot) -> void:
		refreshes.append(s))
	selection.selection_changed.connect(func(_s: GopalaSelectionSnapshot, r: GopalaSelectionResult) -> void:
		changes.append(r))
	# 17 (old snapshots captured before update).
	var old_selection := selection.snapshot()
	var old_inspection := queries.inspect(a)
	# 15 + 16: update refreshes inspection without changing selection.
	var updated := registry.update_entity(a, {"label": "two"}, {}, 1)
	expect(updated.status == GopalaEntityOperationResult.Status.APPLIED,
		"fixture entity updated for refresh test")
	expect(refreshes.size() == 1 and refreshes[0].selected_entity_id == a
		and refreshes[0].selected_entity_revision == 2
		and refreshes[0].entity.attributes["label"] == "two"
		and refreshes[0].selection_sequence == sequence_before,
		"entity update emits selected_entity_refreshed with the new revision")
	expect(selection.selected_entity_id == a and selection.selection_sequence == sequence_before
		and changes.is_empty(),
		"entity update keeps the selected ID and does not increment selection sequence")
	var inspection := queries.inspect(a)
	expect(inspection.valid and inspection.availability
		and inspection.revision == 2 and inspection.attributes["label"] == "two"
		and inspection.kind == GopalaEntityKind.BUILDING
		and inspection.lifecycle == GopalaEntityLifecycle.State.ACTIVE,
		"inspection reads the updated entity")
	var selection_now := selection.snapshot()
	expect(selection_now.selected_entity_revision == 2
		and selection_now.selection_sequence == sequence_before,
		"current selection snapshot reflects the refreshed revision")
	# 17. Old selection/inspection snapshots remain unchanged.
	expect(old_selection.selected_entity_revision == 1
		and old_selection.entity.attributes["label"] == "one"
		and old_inspection.revision == 1 and old_inspection.attributes["label"] == "one",
		"old selection and inspection snapshots remain immutable after update")
	# Unavailable inspection for unknown records.
	var missing := queries.inspect(99999)
	expect(missing.valid and not missing.availability
		and missing.unavailable_reason == GopalaEntityInspectionSnapshot.REASON_NOT_FOUND
		and missing.entity_id == 99999,
		"unknown records return unavailable/NOT_FOUND")
	var none_selection_inspection := queries.inspect_selection(GopalaSelectionSnapshot.empty(0, 0, &"PROBE"))
	expect(not none_selection_inspection.availability,
		"inspecting an empty selection is unavailable")
	await _free_simulation(simulation)

func _test_removal_and_reset() -> void:
	var simulation := _new_simulation()
	await process_frame
	var selection := simulation.selection_service()
	var registry := simulation.entity_registry()
	var a := registry.create_entity(GopalaEntityKind.BUILDING, {}, {}, 0).entity_id
	var other := registry.create_entity(GopalaEntityKind.ROAD, {}, {}, 0).entity_id
	# 19: removing a different entity does not clear selection.
	selection.select_entity(a)
	_events.clear()
	registry.entity_removed.connect(func(id: int, _k: StringName, _s: int) -> void:
		_events.append("registry_removed:%d" % id))
	registry.registry_changed.connect(func(_s: GopalaEntityRegistrySnapshot) -> void:
		_events.append("registry_changed"))
	selection.selection_changed.connect(func(_s: GopalaSelectionSnapshot, r: GopalaSelectionResult) -> void:
		_events.append("selection_changed:%s" % String(r.reason_code)))
	registry.remove_entity(other, GopalaEntityRegistry.RemovalPolicy.REJECT_IF_REFERENCED, 1)
	expect(selection.selected_entity_id == a and selection.selection_sequence == 1
		and _events == ["registry_removed:%d" % other, "registry_changed"],
		"removing a different entity leaves selection untouched and silent")
	# 18: selected entity removal clears selection synchronously, before registry_changed.
	_events.clear()
	var removed := registry.remove_entity(a, GopalaEntityRegistry.RemovalPolicy.REJECT_IF_REFERENCED, 2)
	expect(removed.status == GopalaEntityOperationResult.Status.APPLIED, "selected entity removed")
	var changed_index := _events.find("registry_changed")
	var selection_index := _events.find("selection_changed:ENTITY_REMOVED")
	expect(selection_index >= 0 and changed_index > selection_index,
		"removal clears selection with ENTITY_REMOVED before registry_changed continues")
	expect(_events.count("selection_changed:ENTITY_REMOVED") == 1,
		"removal emits exactly one selection clear")
	expect(selection.selected_entity_id == 0 and selection.selection_sequence == 2,
		"removal clears the ID and increments selection sequence once")
	# 20: registry-only reset clears a non-empty selection exactly once.
	var b := registry.create_entity(GopalaEntityKind.TASK, {}, {}, 3).entity_id
	selection.select_entity(b)
	expect(selection.selection_sequence == 3, "selection sequence continues after reselection")
	_events.clear()
	registry.reset()
	var clear_events := _events.filter(func(e: String): return e.begins_with("selection_changed"))
	expect(clear_events.size() == 1 and clear_events[0] == "selection_changed:SESSION_RESET",
		"registry reset clears a non-empty selection exactly once with SESSION_RESET")
	expect(selection.selected_entity_id == 0 and selection.selection_sequence == 4,
		"registry reset leaves selection empty with one sequence increment")
	# 21: session reset leaves selection empty at sequence zero, signal exactly once.
	var c := registry.create_entity(GopalaEntityKind.INVENTORY, {}, {}, 4).entity_id
	selection.select_entity(c)
	var resets: Array[GopalaSelectionSnapshot] = []
	var post_changes: Array[GopalaSelectionResult] = []
	selection.selection_reset.connect(func(s: GopalaSelectionSnapshot) -> void:
		resets.append(s))
	selection.selection_changed.connect(func(_s: GopalaSelectionSnapshot, r: GopalaSelectionResult) -> void:
		post_changes.append(r))
	expect(simulation.reset(), "session reset succeeds")
	expect(resets.size() == 1 and resets[0].state == GopalaSelectionSnapshot.State.NONE
		and resets[0].change_reason == GopalaSelectionResult.SESSION_RESET
		and post_changes.is_empty(),
		"session reset emits exactly one selection_reset and no duplicate clear")
	expect(selection.selected_entity_id == 0 and selection.selection_sequence == 0,
		"session reset leaves selection empty with a fresh sequence")
	expect(registry.entity_count == 0 and registry.registry_sequence == 0
		and simulation._next_entity_id_for_tests() == 1,
		"session reset clears registry and restarts the allocator")
	# 22: post-reset selection starts fresh and works.
	var fresh_id := registry.create_entity(GopalaEntityKind.SETTLEMENT, {}, {}, 0).entity_id
	expect(fresh_id == 1 and selection.select_entity(fresh_id).reason_code == GopalaSelectionResult.SELECTED
		and selection.selection_sequence == 1,
		"new session starts with a working fresh selection")
	await _free_simulation(simulation)

func _test_reentrancy_and_signal_reads() -> void:
	var simulation := _new_simulation()
	await process_frame
	var queries := simulation.entity_queries()
	var selection := simulation.selection_service()
	var registry := simulation.entity_registry()
	var a := registry.create_entity(GopalaEntityKind.BUILDING, {}, {}, 0).entity_id
	var b := registry.create_entity(GopalaEntityKind.ROAD, {}, {}, 0).entity_id
	var attempts: Array[GopalaEntityOperationResult] = []
	var results: Array[GopalaSelectionResult] = []
	var read_ok: Array[bool] = []
	var attempted := [false]
	selection.selection_changed.connect(func(s: GopalaSelectionSnapshot, _r: GopalaSelectionResult) -> void:
		# 24: reads during selection signals observe committed state.
		var current := selection.snapshot()
		var live := queries.snapshot(s.selected_entity_id)
		read_ok.append(current.selected_entity_id == s.selected_entity_id
			and current.selection_sequence == s.selection_sequence
			and (s.selected_entity_id == 0 or (live != null and live.entity_id == s.selected_entity_id)))
		# 23: reentrant selection mutation must reject without state change.
		if not attempted[0]:
			attempted[0] = true
			results.append(selection.select_entity(b))
			attempts.append(null))
	_events.clear()
	selection.select_entity(a)
	expect(results.size() == 1 and results[0].status == GopalaSelectionResult.Status.REJECTED
		and results[0].reason_code == GopalaSelectionResult.REENTRANT_MUTATION,
		"reentrant selection mutation from a selection callback rejects")
	expect(selection.selected_entity_id == a and selection.selection_sequence == 1,
		"rejected reentrant mutation does not alter selection or sequence")
	expect(read_ok.size() >= 1 and read_ok[0],
		"reads during selection signals observe committed state")
	# Reactive removal during a selection callback must still invalidate state.
	var removed_during_callback := [false]
	var cleared_reasons: Array[StringName] = []
	selection.selection_changed.connect(func(_s: GopalaSelectionSnapshot, r: GopalaSelectionResult) -> void:
		if r.reason_code == GopalaSelectionResult.ENTITY_REMOVED:
			cleared_reasons.append(r.reason_code))
	selection.clear_selection()
	var snapshot_before := selection.snapshot().selection_sequence
	selection.selection_changed.connect(func(_s: GopalaSelectionSnapshot, _r: GopalaSelectionResult) -> void:
		if not removed_during_callback[0]:
			removed_during_callback[0] = true
			registry.remove_entity(a, GopalaEntityRegistry.RemovalPolicy.REJECT_IF_REFERENCED, 1))
	selection.select_entity(a)
	expect(selection.selected_entity_id == 0
		and selection.selection_sequence == snapshot_before + 2,
		"reactive removal during a selection callback never leaves a stale selected ID")
	expect(cleared_reasons.size() == 1 and cleared_reasons[0] == GopalaSelectionResult.ENTITY_REMOVED,
		"reactive removal clear carries ENTITY_REMOVED")
	await _free_simulation(simulation)

func _test_adapter() -> void:
	var simulation := _new_simulation()
	await process_frame
	var queries := simulation.entity_queries()
	var registry := simulation.entity_registry()
	var entity := registry.create_entity(GopalaEntityKind.BUILDING, {"view": true}, {}, 0)
	var entity_id := entity.entity_id
	var adapter := GopalaEntityViewAdapter3D.new()
	adapter.name = "TestEntityView"
	expect(adapter.configure(queries), "adapter accepts explicit query dependency")
	expect(not adapter.configure(queries), "adapter dependency injection is one-shot")
	root.add_child(adapter)
	# 25: binds only a live entity.
	expect(adapter.bind_entity(entity_id) and adapter.bound_entity_id == entity_id
		and adapter.is_resolved(),
		"adapter binds only a live entity and resolves")
	# 26: rejects invalid entity IDs.
	expect(not adapter.bind_entity(99999) and not adapter.bind_entity(0)
		and adapter.bound_entity_id == entity_id,
		"adapter rejects invalid entity IDs without dropping the live binding")
	# 28: tree exit is safe and unbinds presentation state.
	var adapter_ref: WeakRef = weakref(adapter)
	root.remove_child(adapter)
	expect(adapter.bound_entity_id == 0 and not adapter.is_resolved(),
		"adapter tree exit unbinds presentation state")
	root.add_child(adapter)
	expect(adapter.bind_entity(entity_id), "adapter rebinds after re-entering the tree")
	# 27: becomes unresolved after entity removal.
	registry.remove_entity(entity_id, GopalaEntityRegistry.RemovalPolicy.REJECT_IF_REFERENCED, 1)
	expect(adapter.bound_entity_id == entity_id and not adapter.is_resolved(),
		"adapter becomes unresolvable after entity removal without a call")
	adapter.queue_free()
	await process_frame
	await process_frame
	expect(not is_instance_valid(adapter_ref.get_ref()),
		"freed adapter instance is invalid via instance-validity check")
	await _free_simulation(simulation)

func _test_resolver() -> void:
	var simulation := _new_simulation()
	await process_frame
	var queries := simulation.entity_queries()
	var registry := simulation.entity_registry()
	var entity_id := registry.create_entity(GopalaEntityKind.BUILDING, {}, {}, 0).entity_id
	var fixture := Node3D.new()
	fixture.name = "ResolverFixture"
	var adapter := GopalaEntityViewAdapter3D.new()
	adapter.name = "ResolverAdapter"
	adapter.configure(queries)
	adapter.bind_entity(entity_id)
	var body := StaticBody3D.new()
	body.name = "ResolverBody"
	adapter.add_child(body)
	fixture.add_child(adapter)
	root.add_child(fixture)
	var decoy_root := Node3D.new()
	decoy_root.name = "DecorativeProp"
	var decoy := StaticBody3D.new()
	decoy_root.add_child(decoy)
	root.add_child(decoy_root)
	var resolver := GopalaEntityPickResolver3D.new()
	expect(resolver.configure(queries), "resolver accepts explicit query dependency")
	expect(not resolver.configure(queries), "resolver dependency injection is one-shot")
	# 29: finds an adapter on a collider ancestor.
	expect(resolver.resolve_collider(body) == entity_id,
		"resolver finds an adapter on a collider ancestor")
	# 30: misses ordinary terrain/decorative colliders.
	expect(resolver.resolve_collider(decoy) == GopalaEntityPickResolver3D.MISS
		and resolver.resolve_collider(null) == GopalaEntityPickResolver3D.MISS,
		"resolver misses ordinary terrain/decorative colliders")
	# 31: misses disabled and stale adapters.
	adapter.selectable_enabled = false
	expect(resolver.resolve_collider(body) == GopalaEntityPickResolver3D.MISS,
		"resolver misses disabled adapters")
	adapter.selectable_enabled = true
	expect(resolver.resolve_collider(body) == entity_id,
		"resolver resolves an enabled live adapter again")
	registry.remove_entity(entity_id, GopalaEntityRegistry.RemovalPolicy.REJECT_IF_REFERENCED, 1)
	expect(resolver.resolve_collider(body) == GopalaEntityPickResolver3D.MISS,
		"resolver misses stale adapters after entity removal")
	# Injectable collision mask, not a hard-coded production layer.
	expect(resolver.collision_mask() == 1, "resolver default mask is explicit")
	resolver.set_collision_mask(4)
	expect(resolver.collision_mask() == 4, "resolver collision mask is injectable")
	resolver.set_collision_mask(1)
	fixture.queue_free()
	decoy_root.queue_free()
	await process_frame
	await process_frame
	await _free_simulation(simulation)

func _test_synthetic_picking() -> void:
	var simulation := _new_simulation()
	await process_frame
	var queries := simulation.entity_queries()
	var registry := simulation.entity_registry()
	var entity_id := registry.create_entity(GopalaEntityKind.BUILDING, {"pick": true}, {}, 0).entity_id
	# Test-only 3D fixture: orthographic camera + body + adapter + explicit entity.
	var fixture := Node3D.new()
	fixture.name = "PickFixture"
	var adapter := GopalaEntityViewAdapter3D.new()
	adapter.name = "PickAdapter"
	adapter.configure(queries)
	adapter.bind_entity(entity_id)
	var body := StaticBody3D.new()
	body.name = "PickBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	shape.shape = box
	body.add_child(shape)
	adapter.add_child(body)
	var camera := Camera3D.new()
	camera.name = "PickCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.0
	camera.position = Vector3(0, 20, 0)
	camera.rotation = Vector3(-PI / 2.0, 0, 0)
	camera.current = true
	fixture.add_child(adapter)
	fixture.add_child(camera)
	root.add_child(fixture)
	await process_frame
	await process_frame
	var resolver := GopalaEntityPickResolver3D.new()
	resolver.configure(queries)
	var space := camera.get_world_3d().direct_space_state
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var from := camera.project_ray_origin(center)
	var normal := camera.project_ray_normal(center)
	# 32: real synthetic camera ray resolves the test entity.
	var resolved := resolver.pick(space, from, from + normal * 100.0)
	expect(resolved == entity_id,
		"synthetic orthographic camera ray resolves the test entity")
	# 33: ray miss returns no entity.
	var edge := Vector2(viewport_size.x - 1.0, 1.0)
	var miss_from := camera.project_ray_origin(edge)
	var miss_normal := camera.project_ray_normal(edge)
	expect(resolver.pick(space, miss_from, miss_from + miss_normal * 100.0)
		== GopalaEntityPickResolver3D.MISS,
		"ray miss returns no entity")
	# 34: fixture cleanup leaves no orphan nodes.
	var fixture_ref: WeakRef = weakref(fixture)
	var adapter_ref: WeakRef = weakref(adapter)
	var body_ref: WeakRef = weakref(body)
	fixture.queue_free()
	await process_frame
	await process_frame
	expect(not is_instance_valid(fixture_ref.get_ref())
		and not is_instance_valid(adapter_ref.get_ref())
		and not is_instance_valid(body_ref.get_ref()),
		"fixture cleanup leaves no orphan nodes")
	await _free_simulation(simulation)

func _test_main_scene() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# 35: main scene contains one session, registry, query service and selection service.
	var sessions := main.find_children("SettlementSimulation", "GopalaSettlementSimulation", true, false)
	expect(sessions.size() == 1, "main scene contains exactly one settlement session")
	if sessions.size() == 1:
		var simulation := sessions[0] as GopalaSettlementSimulation
		expect(simulation.find_children("EntityRegistry", "GopalaEntityRegistry", false, false).size() == 1
			and simulation.find_children("EntityQueryService", "GopalaEntityQueryService", false, false).size() == 1
			and simulation.find_children("SelectionService", "GopalaSelectionService", false, false).size() == 1,
			"main scene session owns exactly one registry, query service and selection service")
		# 36: main scene still contains zero production entities and empty selection.
		expect(simulation.entity_registry().entity_count == 0
			and simulation.entity_queries().registry_summary()["entity_count"] == 0,
			"main scene registry remains empty of production entities")
		var selection := simulation.selection_service()
		expect(selection.selected_entity_id == 0 and selection.selection_sequence == 0
			and selection.snapshot().state == GopalaSelectionSnapshot.State.NONE,
			"main scene selection remains empty")
	main.queue_free()
	await process_frame
	await process_frame
