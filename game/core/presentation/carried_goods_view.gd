class_name GopalaCarriedGoodsView
extends Node3D
## Goods presentation observes cargo; it never creates or transfers inventory.
var resource_id: StringName
var measured_bounds := AABB()

static func profile(resource: StringName) -> String:
	match resource:
		&"stone": return "stone_carry"
		&"timber": return "timber_carry"
		&"water": return "water_carry"
		&"milk": return "milk_carry"
	return "forage_carry"

func build(resource: StringName) -> void:
	resource_id = resource
	name = "GoodsModel"
	var target := GopalaScaleStandard.carry_size(profile(resource))
	if resource == &"timber":
		for i in 3:
			var log := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = target.x/5.0
			cylinder.bottom_radius = cylinder.top_radius
			cylinder.height = target.z
			cylinder.radial_segments = 8
			log.mesh = cylinder
			log.rotation.x = PI*0.5
			log.position = Vector3((float(i)-1.0)*target.x*0.25, target.y*(0.45 if i == 1 else 0.25),0)
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("775438")
			material.roughness = 1.0
			log.material_override = material
			add_child(log)
	else:
		var path := "res://assets/models/nature/kaykit/Rock_1_B.glb" if resource == &"stone" else "res://assets/models/buildings/highlands/SM_Barrel.glb" if resource in [&"water",&"milk"] else "res://assets/models/buildings/highlands/SM_WoodCrate.glb" if resource == &"wild_food" else "res://assets/models/nature/kaykit/Grass_2_B.glb"
		var model := (load(path) as PackedScene).instantiate() as Node3D
		add_child(model)
		var bounds := GopalaScaleStandard.bounds_in_parent(model)
		model.scale *= minf(target.y/bounds.size.y,minf(target.x/bounds.size.x,target.z/bounds.size.z))
		bounds = GopalaScaleStandard.bounds_in_parent(model)
		model.position -= Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
		if resource in [&"thatch",&"fodder"]:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("b6924b") if resource == &"thatch" else Color("638442")
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.roughness = 1.0
			for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false): mesh.material_override = material
	measured_bounds = GopalaScaleStandard.bounds_in_parent(self)
	position.y = -target.y*0.5
