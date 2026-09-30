extends SceneTree
## Assertions cover rejection behavior as well as real resource import.

var failures: Array[String] = []
var checks := 0

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _initialize() -> void:
	var report := GopalaContentAudit.run()
	expect(report.ok, "Authored catalog and asset hashes must load cleanly.")
	expect(report.counts == {"resources": 7, "buildings": 6, "zones": 1}, "P0 definition counts.")
	expect(report.prototype_assets >= 19 and not report.production_art_approved, "Prototype art must remain visibly provisional.")
	var good: GopalaResourceDefinition = load("res://data/resources/timber.tres")
	var building: GopalaBuildingDefinition = load("res://data/buildings/dwelling.tres")
	var records: Array[Resource] = [good, building]
	expect(GopalaContentAudit.check_records(records).is_empty() == false, "Missing cost goods must fail.")
	var duplicate: Array[Resource] = [good, good]
	expect(not GopalaContentAudit.check_records(duplicate).is_empty(), "Duplicate stable IDs must fail.")
	var broken: GopalaBuildingDefinition = building.duplicate(true)
	broken.costs.clear()
	broken.footprint = Vector2i(0, 2)
	var invalid_size: Array[Resource] = [good, broken]
	expect(not GopalaContentAudit.check_records(invalid_size).is_empty(), "Empty footprints must fail.")
	broken.footprint = Vector2i(2, 2)
	broken.entrance = Vector2i(1, 1)
	expect(not GopalaContentAudit.check_records(invalid_size).is_empty(), "Entrances inside buildings must fail.")
	broken.entrance = Vector2i(-1, 1)
	expect(GopalaContentAudit.check_records(invalid_size).is_empty(), "Adjacent entrance must pass.")
	broken.costs[&"unknown_good"] = 2
	expect(not GopalaContentAudit.check_records(invalid_size).is_empty(), "Unknown construction goods must fail.")
	broken.costs.clear()
	broken.costs[&"timber"] = -1
	expect(not GopalaContentAudit.check_records(invalid_size).is_empty(), "Negative costs must fail.")
	var empty: GopalaResourceDefinition = good.duplicate(true)
	empty.id = &""
	var bad_id: Array[Resource] = [empty]
	expect(not GopalaContentAudit.check_records(bad_id).is_empty(), "Empty stable IDs must fail.")
	var unknown: Array[Resource] = [Resource.new()]
	expect(not GopalaContentAudit.check_records(unknown).is_empty(), "Unknown definition classes must fail without crashing.")
	var manifest: Dictionary = GopalaContentAudit.load_json(GopalaContentAudit.MANIFEST_PATH)
	var changed: Dictionary = manifest.duplicate(true)
	changed.assets[0].sha256 = "incorrect"
	expect(not GopalaContentAudit.run(changed).ok, "Changed image bytes or hashes must fail.")
	changed = manifest.duplicate(true)
	changed.assets[0].width = 999
	expect(not GopalaContentAudit.run(changed).ok, "Incorrect image dimensions must fail.")
	changed = manifest.duplicate(true)
	changed.assets[0].path = "res://assets/missing.png"
	expect(not GopalaContentAudit.run(changed).ok, "Missing asset files must fail.")
	changed = manifest.duplicate(true)
	changed.assets[0].path = "res://assets/../../outside.png"
	expect(not GopalaContentAudit.run(changed).ok, "Asset paths escaping the asset tree must fail.")
	changed = manifest.duplicate(true)
	changed.assets[1].id = changed.assets[0].id
	expect(not GopalaContentAudit.run(changed).ok, "Duplicate asset IDs must fail.")
	changed = manifest.duplicate(true)
	changed.assets[0].status = "production_approved"
	expect(not GopalaContentAudit.run(changed).ok, "Changing a status label must not approve production art.")
	expect(not GopalaContentAudit.run([]).ok, "Malformed asset manifest must fail without crashing.")
	print("GOPALA_TEST_REPORT=", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures, "content": report}))
	quit(0 if failures.is_empty() else 1)
