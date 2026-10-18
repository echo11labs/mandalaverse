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
		var names: Array = ["Bush_1_A","Bush_3_A","Bush_2_A","Bush_4_A"] if resource == &"wild_food" else (["Grass_2_A","Grass_2_B"] if resource == &"thatch" else ["Grass_1_A","Grass_2_B"])
		var path := "res://assets/models/nature/kaykit/%s.glb" % names[i % names.size()]
		var model: Node3D = (load(path) as PackedScene).instantiate()
		plant.add_child(model)
		plant.set_meta("source_model",path)
		GopalaScaleStandard.normalize_height(model,height)
		# Fit broad bush variants within the existing shrub-width contract.
		if resource == &"wild_food":
			var bounds := GopalaScaleStandard.bounds_in_parent(model)
			var width := GopalaScaleStandard.horizontal_width(bounds)
			model.scale *= minf(1.0,GopalaScaleStandard.number("forage_patch","shrub_width")/width)
			bounds = GopalaScaleStandard.bounds_in_parent(model)
			model.position -= Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
		plant.rotation.y = float(i)*2.39996323
		var foliage := StandardMaterial3D.new()
		foliage.roughness = 1.0
		foliage.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Per-instance materials preserve shared imported resources. Mature straw
		# and fresh fodder have distinct silhouettes and colors at the game camera.
		var tones: Array = [Color("b6924b"),Color("c5a763"),Color("a98d48")] if resource == &"thatch" else [Color("4e7437"),Color("638442"),Color("3f672e")]
		foliage.albedo_color = tones[i % tones.size()]
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false): mesh.material_override = foliage
		# Place berries on the fitted canopy edge instead of burying them inside it.
		if resource == &"wild_food":
			var canopy := GopalaScaleStandard.bounds_in_parent(model)
			for berry in 4:
				var fruit := SphereMesh.new()
				fruit.radius = GopalaScaleStandard.number("forage_patch","berry_width") * 0.5
				fruit.height = fruit.radius * 2
				var yaw := float(berry) * TAU / 4.0
				mesh_part(plant,fruit,Vector3(cos(yaw)*canopy.size.x*0.5,canopy.size.y*0.65,sin(yaw)*canopy.size.z*0.5),resource_color(resource))
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
