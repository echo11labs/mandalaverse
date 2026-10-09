class_name GopalaTimberStandView
extends Node3D

var trees: Array[Node3D] = []
var pick_shape: CollisionShape3D

func build(entity_id: int, world_seed: int, ground_height: Callable, world_xz: Vector2) -> void:
	var visual := Node3D.new()
	visual.name = "MeshChild"
	add_child(visual)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + entity_id * 7919
	var scene := load(GopalaNatureModels.resolve("Fir_Tall_A", "res://assets/models/nature/kaykit/Tree_2_A.glb")) as PackedScene
	var base_y: float = ground_height.call(world_xz.x, world_xz.y)
	for i in 3:
		var tree: Node3D = scene.instantiate()
		tree.name = "Tree_%02d" % i
		tree.rotation.y = rng.randf_range(0.0, TAU)
		GopalaScaleStandard.normalize_height(tree, GopalaScaleStandard.number("timber_stand", "tree_height") * rng.randf_range(0.75, 1.0))
		var angle := float(i) * TAU / 3.0
		var offset := Vector2(cos(angle), sin(angle)) * GopalaScaleStandard.metres_to_world(1.8)
		tree.position += Vector3(offset.x, float(ground_height.call(world_xz.x + offset.x, world_xz.y + offset.y)) - base_y, offset.y)
		visual.add_child(tree)
		trees.append(tree)

func _apply_material(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/materials/valley_foliage.gdshader")
		var bounds: AABB = node.mesh.get_aabb()
		material.set_shader_parameter("model_height", bounds.size.y)
		material.set_shader_parameter("model_base_y", bounds.position.y)
		material.set_shader_parameter("trunk_color", Color(0.22, 0.14, 0.09))
		material.set_shader_parameter("leaf_color", Color(0.12, 0.28, 0.14))
		material.set_shader_parameter("leaf_highlight", Color(0.20, 0.42, 0.18))
		material.set_shader_parameter("canopy_fraction", 0.14)
		material.set_shader_parameter("canopy_blend", 0.18)
		node.material_override = material
	for child in node.get_children():
		_apply_material(child)

func update_amount(remaining: int, initial: int) -> void:
	var count := clampi(ceili(float(trees.size()) * maxi(0, remaining) / maxi(1, initial)), 0, trees.size())
	for i in trees.size():
		trees[i].visible = i < count
	visible = remaining > 0
	if pick_shape != null:
		pick_shape.set_deferred("disabled", remaining <= 0)
