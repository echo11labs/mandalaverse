extends SceneTree

var checks := 0
var failures: Array[String] = []
const SAVE_PATH := "user://saves/agriculture-field-test.json"

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func issue(sim: GopalaSettlementSimulation, command_type: StringName, payload: Dictionary) -> GopalaCommandResult:
	return sim._apply_command_for_tests(GopalaSimulationCommand._from_queue(
		checks + 1, command_type, sim.logical_tick, payload, &"field_test"))

func run() -> void:
	var sim := GopalaSettlementSimulation.new()
	root.add_child(sim)
	sim.set_physics_process(false)
	sim.coordinate_service().configure(GopalaSettlementGridConfig.new(
		Vector2.ZERO, Rect2i(-24, -24, 48, 48), 2.0, 100.0))
	check(sim.bootstrap_session(), "Field simulation boots with its normal resource ledger")
	sim._route_service.enable(Rect2i(-24, -24, 48, 48))
	var worker_id := sim.villager_service().spawn_villager(Vector2.ZERO)
	check(worker_id > 0, "Worker spawns on the traversable settlement grid")
	sim.set_paused(false)
	sim.process_pending_commands()

	var created := issue(sim, GopalaSimulationCommand.CREATE_FIELD, {"cell_x": 4, "cell_y": 4})
	check(created.status == GopalaCommandResult.Status.APPLIED, "Valid field command claims a 4-by-4 plot")
	var field_id := int(created.details().get("entity_id", 0))
	var field := sim.entity_queries().snapshot(field_id)
	check(field != null and field.attributes.get(&"field_stage") == &"FALLOW", "New field starts fallow")
	check(sim.occupancy_service().claim_for_owner(field_id).cells.size() == 16, "Field occupancy reserves every plot cell")
	var overlap := issue(sim, GopalaSimulationCommand.CREATE_FIELD, {"cell_x": 6, "cell_y": 6})
	check(overlap.status == GopalaCommandResult.Status.REJECTED, "Overlapping field placement is rejected")

	var cereal: GopalaCropDefinition = sim.field_service().crop_definition(&"cereal")
	var fodder: GopalaCropDefinition = sim.field_service().crop_definition(&"fodder_crop")
	check(cereal != null and cereal.harvest_resource == &"grain", "Cereal data resolves to grain output")
	check(fodder != null and fodder.harvest_resource == &"fodder", "Fodder crop data resolves to fodder output")
	var selected := issue(sim, GopalaSimulationCommand.SET_FIELD_CROP, {"field_id": field_id, "crop_id": &"cereal"})
	check(selected.status == GopalaCommandResult.Status.APPLIED, "Eligible soil accepts a data-defined crop")
	field = sim.entity_queries().snapshot(field_id)
	var planting_outlook := sim.field_service().crop_outlook(field,sim.logical_tick)
	check(not planting_outlook.growth_started and planting_outlook.harvest_resource == &"grain" and planting_outlook.estimated_yield > 0,
		"Crop outlook reports data-defined potential grain yield before growth starts")
	var early_season := sim.field_service().seasonal_outlook(field,0)
	var wet_season := sim.field_service().seasonal_outlook(field,GopalaFieldService.SEASON_TICKS*2)
	var dry_season := sim.field_service().seasonal_outlook(field,GopalaFieldService.SEASON_TICKS)
	check(early_season.current_season == "Dry" and early_season.next_season == "Pre-monsoon" and early_season.next_season_tick == GopalaFieldService.SEASON_TICKS,
		"Season outlook names the current and next deterministic climate phases")
	check(wet_season.current_season == "Monsoon" and wet_season.next_season == "Cool/dry" and wet_season.moisture_trend == "drier",
		"Monsoon outlook warns about the following dry trend")
	check(dry_season.moisture_trend == "wetter" and wet_season.next_season_moisture < sim.field_service().seasonal_outlook(field,GopalaFieldService.SEASON_TICKS).next_season_moisture,
		"Season outlook forecasts lower moisture during the cool/dry phase than before pre-monsoon")
	var year_wrap := sim.field_service().seasonal_outlook(field,GopalaFieldService.CLIMATE_YEAR_TICKS-1)
	check(year_wrap.next_season == "Dry" and year_wrap.next_season_tick == GopalaFieldService.CLIMATE_YEAR_TICKS,
		"Climate forecast wraps into the next year's dry season")
	var dry_revision := sim.entity_registry().update_entity(field_id,{&"field_stage":&"DROUGHT",&"growth_progress_ticks":cereal.growth_ticks/2,&"moisture":cereal.minimum_moisture-0.05},{},sim.logical_tick,field.revision)
	check(dry_revision.status == GopalaEntityOperationResult.Status.APPLIED, "Field outlook fixture enters a dry growth condition")
	field = sim.entity_queries().snapshot(field_id)
	var dry_outlook := sim.field_service().crop_outlook(field,sim.logical_tick)
	check(dry_outlook.growth_paused and dry_outlook.growth_percent == 50 and dry_outlook.productive_ticks_remaining == cereal.growth_ticks/2,
		"Dry-field outlook warns that growth is paused while preserving productive-time progress")
	check(dry_outlook.earliest_ready_tick == sim.logical_tick+cereal.growth_ticks/2, "Earliest maturity forecast uses only remaining productive ticks")
	var mature_fixture := sim.entity_registry().update_entity(field_id,{&"field_stage":&"MATURE",&"growth_progress_ticks":cereal.growth_ticks,&"moisture":cereal.minimum_moisture},{},sim.logical_tick,field.revision)
	check(mature_fixture.status == GopalaEntityOperationResult.Status.APPLIED, "Field outlook fixture reaches crop maturity")
	field = sim.entity_queries().snapshot(field_id)
	var mature_outlook := sim.field_service().crop_outlook(field,sim.logical_tick)
	check(not mature_outlook.growth_paused and mature_outlook.growth_percent == 100 and mature_outlook.earliest_ready_tick == sim.logical_tick,
		"Mature crop outlook reports harvest readiness without a future wait")
	check(mature_outlook.estimated_yield == sim.field_service().harvest_output(field,cereal), "Outlook yield matches the harvest transaction estimate")
	var restore_preparing := sim.entity_registry().update_entity(field_id,{&"field_stage":&"PREPARING",&"growth_progress_ticks":0,&"moisture":field.attributes.get(&"base_moisture",0.5)},{},sim.logical_tick,field.revision)
	check(restore_preparing.status == GopalaEntityOperationResult.Status.APPLIED, "Read-only outlook fixture restores normal crop preparation")
	field = sim.entity_queries().snapshot(field_id)
	var assigned := issue(sim, GopalaSimulationCommand.REQUEST_FIELD_WORK, {"field_id": field_id, "villager_id": worker_id})
	check(assigned.status == GopalaCommandResult.Status.APPLIED, "Worker receives the field preparation task")
	check(sim.entity_queries().snapshot(worker_id).attributes.get(&"task_kind") == &"FIELD", "Field task owns the worker")

	var codec := GopalaSettlementSave.new()
	check(codec.write(SAVE_PATH, codec.capture(sim, {})), "Active field task writes a validated save")
	var restored := codec.restore(codec.read(SAVE_PATH), sim, {})
	check(restored != null, "Active field task restores: " + codec.error)
	if restored == null:
		sim.free()
		finish()
		return
	sim.free()
	sim = restored
	root.add_child(sim)
	sim.set_physics_process(false)
	check(sim.field_service()._tasks.has(worker_id), "Restored field task retains worker ownership")
	check(sim.entity_queries().snapshot(worker_id).attributes.get("movement_state") == &"MOVING", "Restored field worker resumes its route")

	for _frame in 200:
		sim.advance_ticks(1)
		field = sim.entity_queries().snapshot(field_id)
		if field.attributes.get(&"field_stage") == &"PLANTED":
			break
	field = sim.entity_queries().snapshot(field_id)
	check(field.attributes.get(&"field_stage") == &"PLANTED", "Worker completes planting after load")
	check(not sim.field_service()._tasks.has(worker_id), "Completed planting releases its worker task")

	sim.advance_ticks(20)
	field = sim.entity_queries().snapshot(field_id)
	check(int(field.attributes.get(&"growth_progress_ticks", 0)) > 0, "Crop growth advances on authoritative simulation ticks")
	var moisture_before_tending := float(field.attributes.moisture)
	var tending := issue(sim, GopalaSimulationCommand.REQUEST_FIELD_WORK, {"field_id": field_id, "villager_id": worker_id})
	check(tending.status == GopalaCommandResult.Status.APPLIED, "Growing field accepts a tending task")
	for _frame in 100:
		sim.advance_ticks(1)
		if not sim.field_service()._tasks.has(worker_id):
			break
	field = sim.entity_queries().snapshot(field_id)
	check(not sim.field_service()._tasks.has(worker_id), "Tending work completes and frees the worker")
	check(float(field.attributes.moisture) > moisture_before_tending, "Completed tending restores field moisture")

	var crop := sim.field_service().crop_definition(&"cereal")
	sim.advance_ticks(crop.growth_ticks)
	field = sim.entity_queries().snapshot(field_id)
	check(field.attributes.get(&"field_stage") == &"MATURE", "Crop reaches maturity after its configured growth duration")
	check(int(field.attributes.get(&"growth_progress_ticks", 0)) == crop.growth_ticks, "Growth progress is bounded by crop data")
	var expected_yield := sim.field_service().harvest_output(field, crop)
	var harvested := issue(sim, GopalaSimulationCommand.HARVEST_FIELD, {"field_id": field_id, "villager_id": worker_id})
	check(harvested.status == GopalaCommandResult.Status.APPLIED, "Mature crop can be assigned for harvest")
	for _frame in 100:
		sim.advance_ticks(1)
		field = sim.entity_queries().snapshot(field_id)
		if field.attributes.get(&"field_stage") == &"HARVESTED":
			break
	field = sim.entity_queries().snapshot(field_id)
	check(field.attributes.get(&"field_stage") == &"HARVESTED", "Worker completes harvest")
	check(field.attributes.get(&"crop_id") == &"", "Harvest clears the crop for the next planting cycle")
	var grain_patches := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.RESOURCE_SOURCE).filter(
		func(source): return source.attributes.get(&"resource_id") == &"grain" and source.attributes.get(&"recovered_goods", false))
	check(grain_patches.size() == 1 and grain_patches[0].attributes.get(&"available_amount") == expected_yield,
		"Harvest creates the data- and soil-scaled grain at the field edge")
	if grain_patches.size() == 1:
		var grain_point := Vector2(grain_patches[0].attributes.position_x,grain_patches[0].attributes.position_z)
		var grain_cell := sim.coordinate_service().world_to_settlement_cell(grain_point)
		check(sim._route_service.is_open(grain_cell), "Harvested grain is spawned on an accessible, non-field cell")
		var store_id: int = sim.entity_registry().create_entity(GopalaEntityKind.BUILDING,{&"definition_id":&"stockpile",&"position_x":-0.12,&"position_z":0.0,&"storage_capacity":{&"grain":100}}).entity_id
		sim._storage_service.enable_locations(store_id)
		check(sim._storage_service.store_has_space(store_id,&"grain"), "Located stockpile has capacity for harvested grain")
		var gather_command := GopalaSimulationCommand._from_queue(checks+1,GopalaSimulationCommand.REQUEST_GATHER_RESOURCE,sim.logical_tick,{"villager_id":worker_id,"source_entity_id":grain_patches[0].entity_id,"destination_entity_id":store_id,"resource_id":&"grain"},&"field_test")
		var collection := sim.gather_delivery_service().handle_request_gather_timber(gather_command,sim.logical_tick)
		check(collection.status == GopalaCommandResult.Status.APPLIED, "Harvested grain can enter the ordinary physical gathering-and-hauling loop")
		for _frame in 200:
			sim.advance_ticks(1)
			if sim._storage_service.stored(store_id,&"grain") == 1:
				break
		check(sim._storage_service.stored(store_id,&"grain") == 1, "Hauler physically delivers one harvested grain to the stockpile")
	check(not sim.field_service()._tasks.has(worker_id), "Harvest completion releases worker ownership")

	sim.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
	finish()

func finish() -> void:
	print("GOPALA_TEST_REPORT=" + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
