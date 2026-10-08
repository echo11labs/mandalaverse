class_name GopalaForagePatchView
extends Node3D

## Original prototype plants. All dimensions come from the metre-based standard.
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
		if resource == &"wild_food":
			var trunk := CylinderMesh.new()
			trunk.height = height * 0.45
			trunk.top_radius = GopalaScaleStandard.number("forage_patch","stem_width") * 0.5
			trunk.bottom_radius = trunk.top_radius
			mesh_part(plant,trunk,Vector3(0,trunk.height*0.5,0),Color(0.30,0.23,0.12))
			var canopy := SphereMesh.new()
			canopy.radius = GopalaScaleStandard.number("forage_patch","shrub_width") * 0.5
			canopy.height = height * 0.65
			mesh_part(plant,canopy,Vector3(0,trunk.height+canopy.height*0.5,0),Color(0.19,0.35,0.12))
			for berry in 4:
				var fruit := SphereMesh.new()
				fruit.radius = GopalaScaleStandard.number("forage_patch","berry_width") * 0.5
				fruit.height = fruit.radius * 2
				var yaw := float(berry) * TAU / 4.0
				mesh_part(plant,fruit,Vector3(cos(yaw)*canopy.radius,trunk.height+canopy.height*0.5,sin(yaw)*canopy.radius),resource_color(resource))
		else:
			for blade in 4:
				var stem := CylinderMesh.new()
				stem.height = height * rng.randf_range(0.75,1.0)
				stem.top_radius = 0
				stem.bottom_radius = GopalaScaleStandard.number("forage_patch","stem_width")
				stem.radial_segments = 4
				var yaw := float(blade) * TAU / 4
				mesh_part(plant,stem,Vector3(cos(yaw)*stem.bottom_radius,stem.height*0.5,sin(yaw)*stem.bottom_radius),resource_color(resource))
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
