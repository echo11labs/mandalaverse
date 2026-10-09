class_name GopalaStonePatchView
extends Node3D

var pieces: Array[Node3D] = []
var pick_shape: CollisionShape3D

func build(entity_id: int, ground_height: Callable, world_xz: Vector2) -> void:
	var visual := Node3D.new()
	visual.name = "MeshChild"
	add_child(visual)
	var rng := RandomNumberGenerator.new()
	rng.seed = entity_id * 7919 + 43129
	var scenes := [preload("res://assets/models/nature/kaykit/Rock_1_A.glb"), preload("res://assets/models/nature/kaykit/Rock_3_A.glb")]
	var base_y: float = ground_height.call(world_xz.x, world_xz.y)
	for i in int(GopalaScaleStandard.number("stone_patch", "piece_count")):
		var piece: Node3D = scenes[i % scenes.size()].instantiate()
		piece.name = "Stone_%02d" % i
		piece.rotation.y = rng.randf_range(0.0, TAU)
		var width := rng.randf_range(GopalaScaleStandard.number("stone_piece", "width_min"), GopalaScaleStandard.number("stone_piece", "width_max"))
		GopalaScaleStandard.normalize_stone(piece, width)
		# Centre piece plus spaced rings; a patch of small stones, no anchor boulder.
		var angle := float(i) * 2.39996323
		var radius := sqrt(float(i) / maxf(1.0, GopalaScaleStandard.number("stone_patch", "piece_count") - 1.0)) * GopalaScaleStandard.number("stone_patch", "radius")
		var offset := Vector2(cos(angle), sin(angle)) * radius
		piece.position += Vector3(offset.x, float(ground_height.call(world_xz.x + offset.x, world_xz.y + offset.y)) - base_y, offset.y)
		piece.set_meta("scale_profile", "stone_piece")
		visual.add_child(piece)
		pieces.append(piece)
	set_meta("scale_profile", "stone_patch")

func _apply_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_apply_material(child, material)

func update_amount(remaining: int, initial: int) -> void:
	var visible_count := clampi(int(ceil(float(pieces.size()) * float(maxi(0, remaining)) / float(maxi(1, initial)))), 0, pieces.size())
	for i in pieces.size():
		pieces[i].visible = i < visible_count
	visible = remaining > 0
	if pick_shape != null:
		pick_shape.set_deferred("disabled", remaining <= 0)
