class_name GopalaNatureModels
extends RefCounted
## Optional user-owned models. The reviewed, licensed forest stays the fallback.
const LOCAL_ROOT := "res://assets/models/local_nature/"
const LOCAL_MAP := LOCAL_ROOT + "variants.json"
static var _meshes: Dictionary = {}

static func resolve(id: String, fallback: String) -> String:
	if not FileAccess.file_exists(LOCAL_MAP):
		return fallback
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOCAL_MAP))
	if not parsed is Dictionary:
		return fallback
	var path := String(parsed.get(id, ""))
	if not path.begins_with(LOCAL_ROOT) or not path.ends_with(".glb") or ".." in path:
		return fallback
	if not ResourceLoader.exists(path):
		return fallback
	return path

static func merged(path: String) -> Mesh:
	if _meshes.has(path):
		return _meshes[path]
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	var result := ArrayMesh.new()
	_append(model, Transform3D.IDENTITY, result)
	model.free()
	if result.get_surface_count() == 0:
		return null
	_meshes[path] = result
	return result

static func _append(node: Node3D, parent_transform: Transform3D, target: ArrayMesh) -> void:
	var transform := parent_transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			var tool := SurfaceTool.new()
			tool.append_from(node.mesh, surface, transform)
			tool.set_material(node.get_active_material(surface))
			tool.commit(target)
	for child in node.get_children():
		if child is Node3D:
			_append(child, transform, target)

static func fit_mesh(source: Mesh, reference: AABB) -> Mesh:
	var bounds := source.get_aabb()
	if bounds.size.y <= 0.0:
		return null
	var factor := reference.size.y / bounds.size.y
	var source_anchor := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var target_anchor := Vector3(reference.get_center().x, reference.position.y, reference.get_center().z)
	var transform := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * factor), target_anchor - source_anchor * factor)
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var tool := SurfaceTool.new()
		tool.append_from(source, surface, transform)
		tool.set_material(source.surface_get_material(surface))
		tool.commit(mesh)
	return mesh

static func apply_forest(forest: Node3D) -> int:
	var replacements := {}
	var paths := {}
	var changed := 0
	for child in forest.get_children():
		if not child is MultiMeshInstance3D or child.multimesh == null:
			continue
		var id := String(child.get_meta("variant_id", ""))
		var original := String(child.get_meta("source_path", ""))
		if not paths.has(id):
			paths[id] = resolve(id, original)
		var path: String = paths[id]
		if path == original:
			continue
		if not replacements.has(id):
			var source := merged(path)
			if source == null:
				continue
			replacements[id] = fit_mesh(source, child.multimesh.mesh.get_aabb())
		if replacements[id] == null:
			continue
		# Preserve every placement, rotation, instance count and physical height.
		# Duplicate the batching resource so the shared reviewed bake is immutable.
		var multi: MultiMesh = child.multimesh.duplicate()
		multi.mesh = replacements[id]
		multi.custom_aabb = AABB()
		child.multimesh = multi
		child.set_meta("local_source_path", path)
		changed += 1
	forest.set_meta("local_tree_chunks", changed)
	return changed
