class_name GopalaMvpScenario
extends RefCounted

static func setup(sim: GopalaSettlementSimulation, camp: Vector2) -> void:
	if sim._survival_service.enabled(): return
	var policy := sim._survival_service.policy
	sim.entity_registry().create_entity(GopalaEntityKind.SETTLEMENT,{&"scenario_id":&"gopala_mvp_v1",&"survival_enabled":true,&"started_tick":sim.logical_tick,&"objective_state":&"BUILD_SETTLEMENT",&"stable_ticks":0}, {},sim.logical_tick)
	sim.apply_authorized_transaction({&"wild_food":int(policy.starting_food),&"water":int(policy.starting_water)})
	var existing := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)
	for ring in range(2,10):
		for x in range(-ring,ring+1):
			for z in [-ring,ring]:
				if existing.size() >= int(policy.population): break
				var cell := Vector2i(x,z)
				if not sim._route_service.is_open(cell): continue
				var point := sim.coordinate_service().settlement_cell_to_world_xz(cell)
				if existing.any(func(w): return point.distance_to(Vector2(w.attributes.position_x,w.attributes.position_z)) < GopalaScaleStandard.metres_to_world(1.0)): continue
				var id := sim.villager_service().spawn_villager(point)
				if id > 0: existing.append(sim.entity_queries().snapshot(id))
		if existing.size() >= int(policy.population): break
	for i in existing.size():
		sim.entity_registry().update_entity(existing[i].entity_id,{&"display_name":"Settler %d" % (i+1),&"work_role":&"NONE"},{},sim.logical_tick,existing[i].revision)
	for i in 2:
		var location := camp+Vector2(float(i)*2.0,6.0)*GopalaScaleStandard.metres_to_world(1.0)
		sim.entity_registry().create_entity(GopalaEntityKind.ANIMAL,{&"species":&"cattle",&"display_name":"Cow %d" % (i+1),&"position_x":location.x,&"position_z":location.y,&"water_fed":0,&"fodder_fed":0,&"milk_produced":0,&"next_milk_tick":0,&"tended_tick":-1,&"assigned_herder_id":0,&"herd_status":&"NO_PASTURE",&"consumed_goods":{}},{},sim.logical_tick)
	sim._survival_service.tick(sim.logical_tick)

static func tick(sim: GopalaSettlementSimulation, tick_value: int) -> void:
	if not sim._survival_service.enabled(): return
	var scenario: GopalaEntitySnapshot = sim.entity_queries().snapshots_by_kind(GopalaEntityKind.SETTLEMENT).filter(func(s): return s.attributes.get(&"survival_enabled",false))[0]
	if scenario.attributes.get(&"objective_state") in [&"SUCCESS",&"FAILED"]: return
	var completed := {}
	for building in sim.entity_queries().snapshots_by_kind(GopalaEntityKind.BUILDING):
		if str(building.attributes.get("construction_state","COMPLETED")) == "COMPLETED": completed[building.attributes.get("definition_id",&"")] = true
	var workers := sim.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER)
	var cows := sim._herd_service.animals()
	var missing: Array[String] = []
	for id in [&"dwelling",&"stockpile",&"timber_camp",&"gatherer_shelter",&"water_point",&"cattle_shelter"]:
		if not completed.has(id): missing.append(str(id).replace("_"," "))
	if workers.size() < int(sim._survival_service.policy.population): missing.append("eight settlers")
	if workers.any(func(w): return int(w.attributes.get(&"health",100)) == 0):
		sim._survival_service.update(scenario.entity_id,{&"objective_state":&"FAILED",&"objective_reason":"A settler collapsed. Start again or reload an earlier save."},tick_value)
		return
	if workers.any(func(w): return int(w.attributes.get(&"home_id",0)) == 0): missing.append("homes for everyone")
	if workers.any(func(w): return int(w.attributes.get(&"health",100)) < 50): missing.append("healthy settlers")
	if sim.resource_amount(&"wild_food")+sim.resource_amount(&"milk") < 1: missing.append("stored food")
	if sim.resource_amount(&"water") < 1: missing.append("stored water")
	if cows.size() < 2 or cows.any(func(c): return int(c.attributes.get(&"milk_produced",0)) < 2 or tick_value > int(c.attributes.get(&"next_milk_tick",0))+int(sim._survival_service.policy.cattle_cycle_ticks) or int(c.attributes.get(&"pasture_id",0)) == 0 or int(c.attributes.get(&"shelter_id",0)) == 0): missing.append("two tended cows producing milk")
	# Milk is useful only after real collection, not merely generated beside cattle.
	var consumed_milk := 0
	for worker in workers: consumed_milk += int(worker.attributes.get(&"consumed_goods",{}).get(&"milk",0))
	if sim.resource_amount(&"milk")+consumed_milk < 1: missing.append("milk delivered to storage")
	var stable := int(scenario.attributes.get(&"stable_ticks",0))+1 if missing.is_empty() else 0
	var state: StringName = &"SUSTAIN_SETTLEMENT" if missing.is_empty() else &"BUILD_SETTLEMENT"
	if stable >= int(sim._survival_service.policy.objective_ticks): state = &"SUCCESS"
	sim._survival_service.update(scenario.entity_id,{&"stable_ticks":stable,&"objective_state":state,&"objective_reason":"Complete: "+", ".join(missing) if not missing.is_empty() else ("Settlement sustained. Continue building or start again." if state == &"SUCCESS" else "Keep supplies flowing for fifteen logical minutes.")},tick_value)
