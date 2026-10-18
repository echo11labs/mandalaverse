class_name GopalaSceneryWindow
extends Node3D
## Camera-local decoration only. Immutable source meshes and simulation are untouched.
## Coarse authored batches remain available at regional zoom; nearby batches are
## split into small, bounded MultiMeshes once and reused while exploring.
var camera: Camera3D
var sources: Array[MultiMeshInstance3D] = []
var cached: Dictionary = {}
var source_bounds: Array[Rect2] = []
var _last_rect := Rect2()
var _last_local := false
var _elapsed := 1.0
var _serial := 0
var active_instances := 0

func configure(view_camera: Camera3D, scene: Node) -> void:
	name = "LocalSceneryWindow"
	camera = view_camera
	# Dummy renderer does not preserve serialized MultiMesh transform buffers.
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	for group in scene.find_children("*", "MultiMeshInstance3D", true, false):
		if group.multimesh == null or group.multimesh.instance_count == 0:
			continue
		sources.append(group)
		var box: AABB = group.global_transform * group.get_aabb()
		source_bounds.append(Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z)))
	update_window()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.08:
		_elapsed = 0.0
		update_window()

func update_window() -> void:
	if camera == null or sources.is_empty():
		return
	var corners: PackedVector3Array = camera.ground_corners()
	var rect := Rect2(Vector2(corners[0].x, corners[0].z), Vector2.ZERO)
	for corner in corners:
		rect = rect.expand(Vector2(corner.x, corner.z))
	var canopy_reach := GopalaScaleStandard.number("rendering", "canopy_height_max") / maxf(0.1, tan(absf(camera.rotation.x)))
	rect = rect.grow(GopalaScaleStandard.number("rendering", "scenery_padding") + canopy_reach)
	var local := camera.size <= GopalaScaleStandard.number("rendering", "local_span_max")
	if rect == _last_rect and local == _last_local:
		return
	_last_rect = rect
	_last_local = local
	_serial += 1
	active_instances = 0
	var active := {}
	for index in sources.size():
		var source := sources[index]
		if not local:
			source.visible = true
			if cached.has(index): cached[index].root.visible = false
			continue
		source.visible = false
		if not source_bounds[index].intersects(rect, true):
			if cached.has(index): cached[index].root.visible = false
			continue
		if not cached.has(index):
			cached[index] = _split(source)
		var entry: Dictionary = cached[index]
		entry.last_used = _serial
		entry.root.visible = true
		active[index] = true
		for part in entry.parts:
			part.node.visible = part.bounds.intersects(rect, true)
			if part.node.visible: active_instances += part.node.multimesh.instance_count
	# Keep a bounded cache; active groups are never removed while visible.
	var limit := int(GopalaScaleStandard.settings().rendering.scenery_cache_groups)
	while cached.size() > maxi(limit, active.size()):
		var oldest := -1
		var age := _serial + 1
		for index in cached:
			if not active.has(index) and int(cached[index].last_used) < age:
				oldest = index
				age = int(cached[index].last_used)
		if oldest < 0: break
		cached[oldest].root.queue_free()
		cached.erase(oldest)

func _split(source: MultiMeshInstance3D) -> Dictionary:
	var container := Node3D.new()
	add_child(container)
	container.global_transform = source.global_transform
	var original := source.multimesh
	var width := GopalaScaleStandard.number("rendering", "scenery_chunk_width")
	var tiles := {}
	for index in original.instance_count:
		var placement := original.get_instance_transform(index)
		var position := source.global_transform * placement.origin
		var tile := Vector2i(floori(position.x / width), floori(position.z / width))
		if not tiles.has(tile): tiles[tile] = []
		tiles[tile].append(index)
	var parts: Array[Dictionary] = []
	for tile in tiles:
		var indices: Array = tiles[tile]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = original.use_colors
		multi.use_custom_data = original.use_custom_data
		multi.mesh = original.mesh
		multi.instance_count = indices.size()
		var bounds := AABB()
		for index in indices.size():
			var source_index: int = indices[index]
			var placement := original.get_instance_transform(source_index)
			multi.set_instance_transform(index, placement)
			if multi.use_colors: multi.set_instance_color(index, original.get_instance_color(source_index))
			if multi.use_custom_data: multi.set_instance_custom_data(index, original.get_instance_custom_data(source_index))
			var box: AABB = placement * original.mesh.get_aabb()
			bounds = box if index == 0 else bounds.merge(box)
		var group := MultiMeshInstance3D.new()
		group.multimesh = multi
		group.material_override = source.material_override
		group.material_overlay = source.material_overlay
		group.cast_shadow = source.cast_shadow
		group.lod_bias = source.lod_bias
		group.custom_aabb = bounds.grow(GopalaScaleStandard.number("camera", "culling_padding"))
		container.add_child(group)
		var global_box: AABB = container.global_transform * group.custom_aabb
		parts.append({"node": group, "bounds": Rect2(Vector2(global_box.position.x, global_box.position.z), Vector2(global_box.size.x, global_box.size.z))})
	return {"root": container, "parts": parts, "last_used": _serial}
