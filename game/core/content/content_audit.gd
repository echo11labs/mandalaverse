@tool
class_name GopalaContentAudit
extends RefCounted
## Shared by headless verification and MCP; never changes project files.

const REGISTRY_PATH := "res://data/catalog.json"
const MANIFEST_PATH := "res://assets/manifest.json"

static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func check_records(records: Array[Resource]) -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	var goods: Dictionary = {}
	for record in records:
		if record == null:
			errors.append("A definition failed to load.")
			continue
		if not (record is GopalaResourceDefinition or record is GopalaBuildingDefinition or record is GopalaZoneDefinition):
			errors.append("Unsupported definition type.")
			continue
		var key: String = str(record.id)
		if key.is_empty() or not key.is_valid_identifier():
			errors.append("Invalid stable ID: " + key)
		if seen.has(key):
			errors.append("Duplicate stable ID: " + key)
		seen[key] = true
		if record.display_name.strip_edges().is_empty():
			errors.append("Missing display name: " + key)
		if record is GopalaResourceDefinition:
			goods[key] = true
			if record.carry_units < 1 or record.icon == null:
				errors.append("Invalid carrying capacity or missing icon: " + key)
	for record in records:
		if record is GopalaBuildingDefinition:
			var size: Vector2i = record.footprint
			var entry: Vector2i = record.entrance
			if size.x < 1 or size.y < 1 or size.x > 16 or size.y > 16:
				errors.append("Invalid footprint: " + str(record.id))
			var adjacent := ((entry.x == -1 or entry.x == size.x) and entry.y >= 0 and entry.y < size.y) or ((entry.y == -1 or entry.y == size.y) and entry.x >= 0 and entry.x < size.x)
			if not adjacent:
				errors.append("Entrance must border the footprint: " + str(record.id))
			if record.work_ticks <= 0 or record.prototype_sprite == null:
				errors.append("Invalid work requirement or missing sprite: " + str(record.id))
			for key in record.costs:
				if not goods.has(str(key)) or record.costs[key] <= 0:
					errors.append("Unknown good or invalid cost: " + str(record.id) + "/" + str(key))
			for key in record.inventory_limits:
				if not goods.has(str(key)) or record.inventory_limits[key] <= 0 or record.inventory_limits[key] > GopalaSimulationConfig.MAX_BALANCE:
					errors.append("Unknown good or invalid storage limit: " + str(record.id) + "/" + str(key))
		elif record is GopalaZoneDefinition and record.minimum_cells < 1:
			errors.append("Invalid zone minimum: " + str(record.id))
	return errors

static func run(manifest_override: Variant = null) -> Dictionary:
	var errors: Array[String] = []
	var records: Array[Resource] = []
	var catalog: Variant = load_json(REGISTRY_PATH)
	var counts := {"resources": 0, "buildings": 0, "zones": 0}
	if not catalog is Dictionary or catalog.get("schema_version") != 1:
		return {"ok": false, "errors": ["Invalid content catalog."], "counts": counts}
	var paths: Dictionary = {}
	for category in counts:
		var entries: Variant = catalog.get(category)
		if not entries is Array:
			errors.append("Missing catalog category: " + category)
			continue
		for path in entries:
			if not path is String or not path.begins_with("res://data/") or ".." in path:
				errors.append("Invalid definition path.")
				continue
			if paths.has(path):
				errors.append("Duplicate catalog path: " + path)
			paths[path] = true
			if not ResourceLoader.exists(path):
				errors.append("Missing definition: " + path)
				continue
			var record: Resource = load(path)
			var correct_kind: bool = (category == "resources" and record is GopalaResourceDefinition) or (category == "buildings" and record is GopalaBuildingDefinition) or (category == "zones" and record is GopalaZoneDefinition)
			if not correct_kind:
				errors.append("Wrong definition category: " + path)
			records.append(record)
			counts[category] += 1
	errors.append_array(check_records(records))
	var assets: Variant = load_json(MANIFEST_PATH) if manifest_override == null else manifest_override
	var prototype_count := 0
	if not assets is Dictionary or assets.get("schema_version") != 1 or not assets.get("assets") is Array:
		errors.append("Invalid asset manifest.")
	else:
		var asset_ids: Dictionary = {}
		for entry in assets.assets:
			if not entry is Dictionary:
				errors.append("Malformed asset entry.")
				continue
			var asset_id: String = str(entry.get("id", ""))
			if asset_id.is_empty() or asset_ids.has(asset_id):
				errors.append("Missing or duplicate asset ID.")
			asset_ids[asset_id] = true
			var path: String = str(entry.get("path", ""))
			if not path.begins_with("res://assets/") or ".." in path or not FileAccess.file_exists(path):
				errors.append("Missing or invalid asset path: " + asset_id)
				continue
			var image := Image.new()
			var decode_error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
			if decode_error != OK or image.is_empty():
				errors.append("Undecodable image: " + asset_id)
				continue
			if image.get_width() != int(entry.get("width", 0)) or image.get_height() != int(entry.get("height", 0)):
				errors.append("Asset dimensions differ from manifest: " + asset_id)
			if FileAccess.get_sha256(path) != entry.get("sha256", ""):
				errors.append("Asset checksum differs: " + asset_id)
			if entry.get("origin") != "original_procedural" or entry.get("status") != "prototype":
				errors.append("Unreviewed asset provenance or status: " + asset_id)
			prototype_count += 1
	return {"ok": errors.is_empty(), "errors": errors, "counts": counts, "prototype_assets": prototype_count, "production_art_approved": false}
