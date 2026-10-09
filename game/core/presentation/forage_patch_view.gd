class_name GopalaForagePatchView
extends Node3D

## Selected KayKit plants on the original deterministic points. All dimensions come from the metre-based standard.
var plants: Array[Node3D] = []
var pick_shape: CollisionShape3D

static func resource_color(resource: StringName) -> Color:
	match resource:
		&"water": return Color(0.18,0.48,0.72)
		&"thatch": return Color(0.68,0.51,0.20)
		&"fodder": return Color(0.28,0.47,0.13)
		&"wild_food": return Color(0.60,0.15,0.12)
	return Color(0.8,0.6,0.2)

func build(entity_id: int, world_seed: int, resource: StringName, ground_height: Callable, world_xz: Vector2) -> void:
	var visual := Node3D.new()
	visual.name = "MeshChild"
	add_child(visual)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + entity_id * 7919
	var base_y: float = ground_height.call(world_xz.x,world_xz.y)
	for i in int(GopalaScaleStandard.number("forage_patch","piece_count")):
		var plant := Node3D.new()
		visual.add_child(plant)
		var angle := rng.randf_range(0.0,TAU)
		var offset := Vector2(cos(angle),sin(angle)) * GopalaScaleStandard.number("forage_patch","radius") * sqrt(rng.randf())
		plant.position = Vector3(offset.x,float(ground_height.call(world_xz.x+offset.x,world_xz.y+offset.y))-base_y,offset.y)
		var height := GopalaScaleStandard.number("forage_patch","plant_height") * rng.randf_range(0.65,1.0)
		var path := "res://assets/models/nature/kaykit/Bush_1_A.glb" if resource == &"wild_food" and i % 2 == 0 else "res://assets/models/nature/kaykit/Bush_2_A.glb" if resource == &"wild_food" else "res://assets/models/nature/kaykit/Grass_1_A.glb"
		var model: Node3D = (load(path) as PackedScene).instantiate()
		plant.add_child(model)
		GopalaScaleStandard.normalize_height(model,height)
		# Same deterministic scatter points and density; distinguish forage by existing berry markers.
		if resource == &"wild_food":
			for berry in 4:
				var fruit := SphereMesh.new()
				fruit.radius = GopalaScaleStandard.number("forage_patch","berry_width") * 0.5
				fruit.height = fruit.radius * 2
				var yaw := float(berry) * TAU / 4.0
				mesh_part(plant,fruit,Vector3(cos(yaw)*GopalaScaleStandard.number("forage_patch","shrub_width")*0.5,height*0.65,sin(yaw)*GopalaScaleStandard.number("forage_patch","shrub_width")*0.5),resource_color(resource))
		if resource != &"wild_food":
			for unused_blade in 4: rng.randf() # Preserve the original scatter RNG sequence.
		plants.append(plant)

func mesh_part(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	part.material_override = material
	parent.add_child(part)

func update_amount(remaining: int, initial: int) -> void:
	var count := clampi(ceili(float(plants.size())*maxi(0,remaining)/maxi(1,initial)),0,plants.size())
	for i in plants.size(): plants[i].visible = i < count
	visible = remaining > 0
	if pick_shape != null: pick_shape.set_deferred("disabled",remaining <= 0)
