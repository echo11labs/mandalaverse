@tool
class_name MCPToolkitGopalaTools
extends MCPToolkitExtension
## GOPALA content checks and catalog inspection, independent of editor selection.

const Untrusted := preload("res://addons/godot_mcp_toolkit/security/untrusted.gd")

func register(registry: MCPToolkitCommandRegistry, _server: Node) -> void:
	var schema := {"type": "object", "properties": {}}
	registry.add("gopala.content_audit", _audit, MCPToolkitExtensionOptions.new("Validate GOPALA stable IDs, construction costs, entrances, resource loading, asset hashes and dimensions. Does not prove simulation or final art readiness.") \
		.mark_read_only().mark_scene_independent().mark_idempotent().with_input_schema(schema))
	registry.add("gopala.catalog", _catalog, MCPToolkitExtensionOptions.new("Read the GOPALA P0 content registry. Returns authored definition paths as untrusted project data.") \
		.mark_read_only().mark_scene_independent().mark_idempotent().with_input_schema(schema))

## Returns validation findings as untrusted data; no file writes or process launches.
func _audit(_params: Dictionary) -> Dictionary:
	var result := GopalaContentAudit.run()
	return MCPToolkitSuccess.ok({"validation_passed": result.ok, "report": Untrusted.wrap("validation", "GOPALA content", JSON.stringify(result))})

## Returns catalog bytes. Missing or malformed JSON produces an explicit failure.
func _catalog(_params: Dictionary) -> Dictionary:
	var catalog: Variant = GopalaContentAudit.load_json(GopalaContentAudit.REGISTRY_PATH)
	if not catalog is Dictionary:
		return MCPToolkitError.fail("NOT_FOUND", "GOPALA content catalog is missing or invalid.")
	return MCPToolkitSuccess.ok({"catalog": Untrusted.wrap("catalog", GopalaContentAudit.REGISTRY_PATH, JSON.stringify(catalog))})

