extends SceneTree
var checks := 0
var failures: Array[String] = []
var codec := GopalaSettlementSave.new()
const PATH := "user://saves/verification-settlement.json"
func _initialize(): run.call_deferred()
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label); push_error(label + " " + codec.error)
func restore(sim, context):
	check(codec.write(PATH,codec.capture(sim,context)),"Write validated snapshot")
	var loaded = codec.restore(codec.read(PATH),sim,context)
	check(loaded != null,"Restore detached settlement")
	if loaded != null:
		root.add_child(loaded)
		loaded.set_physics_process(false)
	return loaded
func run():
	var valley = load("res://scenes/landscape/kathmandu_valley.tscn").instantiate()
	root.add_child(valley)
	var sim = valley.simulation
	sim.set_physics_process(false)
	var context: Dictionary = valley._save_context()
	var worker: int = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)[0].entity_id
	var camp: int = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING)[0].entity_id
	var source: int = 0
	for record in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE):
		if record.attributes.resource_id == &"stone": source = record.entity_id; break
	var available: int = sim.entity_queries().snapshot(source).attributes.available_amount
	var initial: int = sim.resource_amount(&"stone")
	sim.set_paused(false)
	sim.submit_command(GopalaSimulationCommand.REQUEST_GATHER_STONE,{"villager_id":worker,"source_entity_id":source,"destination_entity_id":camp})
	# Save drains accepted commands before taking the snapshot.
	var loaded = restore(sim,context)
	if loaded == null: finish(); return
	check(loaded.entity_queries().snapshot(source).attributes.reserved_amount == 1,"Source reservation survives before pickup")
	check(loaded._villager_service._routes.has(worker),"Cached path rebuilt from requested destination")
	for frame in 2000:
		loaded.advance_ticks(1)
		if loaded.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 1: break
	check(loaded.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 1,"Worker physically picks up stone")
	var carrying = restore(loaded,context)
	loaded.free()
	if carrying == null: finish(); return
	check(carrying.resource_amount(&"stone") == initial and carrying.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 1,"No remote credit or duplicate pickup after carrying restore")
	check(valley.load_settlement(PATH),"Scene loads worker while carrying")
	valley.simulation.set_physics_process(false)
	check(valley._built_views[worker].get_node("CarryVisual").visible,"Restored carried goods visible immediately")
	var blocker: int = carrying.entity_registry().create_entity(GopalaEntityKind.BUILDING,{}).entity_id
	var ring: Array[Vector2i] = [Vector2i(-1,0),Vector2i(-1,1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(0,2),Vector2i(1,2),Vector2i(2,0),Vector2i(2,1)]
	check(carrying.occupancy_service().reserve_cells(blocker,ring,carrying.logical_tick).status == GopalaOccupancyOperationResult.Status.APPLIED,"Block camp access")
	carrying.advance_ticks(3)
	check(carrying.entity_queries().snapshot(worker).attributes.movement_state == &"BLOCKED","Carrying worker blocked without losing goods")
	var blocked = restore(carrying,context)
	carrying.free()
	if blocked == null: finish(); return
	carrying = blocked
	carrying.advance_ticks(3)
	check(carrying.resource_amount(&"stone") == initial and carrying.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 1,"Blocked restore cannot remotely deliver")
	carrying.occupancy_service().release_claim(blocker,&"TEST",carrying.logical_tick)
	for frame in 2000:
		carrying.advance_ticks(1)
		if carrying.resource_amount(&"stone") == initial + 1: break
	check(carrying.resource_amount(&"stone") == initial + 1,"Carried stone delivered exactly once")
	check(carrying.entity_queries().snapshot(source).attributes.available_amount == available - 1,"Source stock consumed exactly once")
	carrying.advance_ticks(10)
	check(carrying.resource_amount(&"stone") == initial + 1,"No repeated delivery after completion")
	# Save a builder with materials in transit, then again during labour.
	var timber_before: int = carrying.resource_amount(&"timber")
	carrying.request_construction(&"stockpile",Vector2i(4,4))
	carrying.process_pending_commands()
	var blueprint: int = carrying._entity_ids._next_id - 1
	carrying.submit_command(GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER,{"villager_id":worker,"blueprint_id":blueprint})
	carrying.process_pending_commands()
	for frame in 2000:
		carrying.advance_ticks(1)
		if carrying.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 1: break
	var building = restore(carrying,context)
	carrying.free()
	if building == null: finish(); return
	check(building.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 1,"Builder carried material preserved")
	for frame in 2000:
		building.advance_ticks(1)
		if building.entity_queries().snapshot(blueprint).attributes.work_completed > 0: break
	var work = building.entity_queries().snapshot(blueprint).attributes.work_completed
	check(work > 0 and building.entity_queries().snapshot(blueprint).attributes.construction_state != "COMPLETED","Reached partial construction")
	var partial = restore(building,context)
	building.free()
	if partial == null: finish(); return
	check(partial.entity_queries().snapshot(blueprint).attributes.work_completed == work,"Partial work and stable building ID restored")
	for frame in 2000:
		partial.advance_ticks(1)
		if partial.entity_queries().snapshot(blueprint).attributes.construction_state == "COMPLETED": break
	check(partial.entity_queries().snapshot(blueprint).attributes.construction_state == "COMPLETED","Restored builder completes construction")
	check(partial.resource_amount(&"timber") == timber_before - 4,"Four construction materials consumed once across restores")
	# A cancelled building disappears while its worker still returns a load.
	partial.request_construction(&"stockpile",Vector2i(10,10))
	partial.process_pending_commands()
	var cancelled_id: int = partial._entity_ids._next_id - 1
	partial.submit_command(GopalaSimulationCommand.REQUEST_ASSIGN_BUILDER,{"villager_id":worker,"blueprint_id":cancelled_id})
	partial.process_pending_commands()
	for frame in 2000:
		partial.advance_ticks(1)
		if partial.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 1: break
	partial.submit_command(GopalaSimulationCommand.REQUEST_CANCEL_CONSTRUCTION,{"entity_id":cancelled_id})
	partial.process_pending_commands()
	var returning = restore(partial,context)
	partial.free()
	if returning == null: finish(); return
	partial = returning
	check(not partial.entity_registry().has_entity(cancelled_id) and partial.entity_registry()._removed_ids.has(cancelled_id),"Removed building tombstone preserved")
	for frame in 2000:
		partial.advance_ticks(1)
		if partial.entity_queries().snapshot(worker).attributes.get(&"carried_amount",0) == 0: break
	check(partial.resource_amount(&"timber") == timber_before - 4,"Cancelled carried material returned and refunded once after load")
	# Preserve full integer precision, pause/speed and sub-tick remainder.
	partial.set_speed(4)
	partial.process_pending_commands()
	partial._physics_process(0.123)
	partial.set_paused(true)
	partial.process_pending_commands()
	check(partial.apply_authorized_transaction({&"stone":9007199254740}),"Large integer stock accepted")
	var paused = restore(partial,context)
	if paused != null:
		check(paused.paused and paused.speed == 4 and paused._clock._fractional_logical_nanoseconds == partial._clock._fractional_logical_nanoseconds,"Clock pause speed and fractional tick preserved")
		check(paused.resource_balances_snapshot() == partial.resource_balances_snapshot(),"Integer resource balances and StringName keys preserved")
		check(paused._queue._next_command_id == partial._queue._next_command_id,"Command IDs remain monotonic")
		var next: int = paused._entity_ids._next_id
		check(paused.villager_service().spawn_villager(Vector2(context.get("x",-74.35)-0.1,12.3)) >= next,"New entity cannot reuse saved IDs")
		paused.free()
	# Invalid files and self-checksummed invalid states cannot mutate the live authority.
	var state := codec.capture(partial,context)
	var before: Dictionary = codec.capture(partial,context)
	var bad := state.duplicate(true)
	bad.records[0][7] = {&"missing":999999}
	check(codec.restore(bad,partial,context) == null,"Invalid references rejected before replacement")
	bad = state.duplicate(true)
	bad.balances[&"stone"] = -1
	check(codec.restore(bad,partial,context) == null,"Negative stock rejected")
	bad = state.duplicate(true)
	bad.context.world_seed += 1
	check(codec.restore(bad,partial,context) == null,"Incompatible world seed rejected")
	check(codec.capture(partial,context) == before,"Failed loads leave live settlement unchanged")
	var backup := codec.read(PATH + ".bak")
	check(not backup.is_empty(),"Previous save backup retained")
	var backup_sim = codec.restore(backup,partial,context)
	check(backup_sim != null,"Previous backup can restore a settlement")
	if backup_sim != null: backup_sim.free()
	check(codec.decode(GopalaSettlementSave.encode(9223372036854775807)) == 9223372036854775807,"Codec retains full int64 range")
	var tiny := 0.0000000000000000000000000123
	check(codec.decode(GopalaSettlementSave.encode(tiny)) == tiny,"Codec retains exact tiny float")
	bad = state.duplicate(true)
	for record in bad.records:
		if record[1] == GopalaEntityKind.RESOURCE_SOURCE: record[6][&"reserved_amount"] = 99; break
	check(codec.restore(bad,partial,context) == null,"Reservation/task imbalance rejected")
	var file := FileAccess.open(PATH,FileAccess.WRITE)
	file.store_string('{"version":2,"checksum":"broken","payload":[]}')
	file.close()
	check(codec.read(PATH).is_empty(),"Corruption rejected")
	file = FileAccess.open(PATH,FileAccess.WRITE)
	file.store_string('{"version":99,"payload":[]}')
	file.close()
	check(codec.read(PATH).is_empty(),"Unknown schema rejected")
	# Exercise actual UI load swaps and query adapters.
	check(valley.save_settlement(PATH),"Scene save works")
	var old_view = valley._built_views[worker]
	check(valley.load_settlement(PATH),"Scene load swaps authority")
	check(valley._built_views[worker] != old_view,"View adapters rebuilt after load")
	valley.simulation.set_physics_process(false)
	partial.free()
	valley.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	finish()
func finish():
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
