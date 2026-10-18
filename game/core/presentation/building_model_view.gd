class_name GopalaBuildingModelView
extends Node3D

const ROOF := preload("res://assets/models/kenney_survival/structure-roof.glb")
const FRAME := preload("res://assets/models/kenney_survival/structure.glb")
const CANVAS := preload("res://assets/models/kenney_survival/structure-canvas.glb")
const CRATE := preload("res://assets/models/buildings/highlands/SM_WoodCrate.glb")
const BARREL := preload("res://assets/models/buildings/highlands/SM_Barrel.glb")
const HUT := preload("res://assets/models/buildings/highlands/SM_Hut.glb")
const FENCE := preload("res://assets/models/buildings/highlands/SM_WoodFence.glb")
const AXE := preload("res://assets/models/buildings/highlands/SM_Axe.glb")
const LOCAL_ROOT := "res://assets/models/local_buildings/"
var complete: Node3D
var frame: Node3D
var measured_bounds := AABB()
var model_path := ""
var _plot := Vector3.ZERO
var _turn := 0

func build(size: Vector3, definition: String, entity_id: int = 0, turn: int = 0) -> void:
	name = "BuildingVisual"
	_plot = size
	_turn = posmod(turn,4)
	complete = Node3D.new()
	complete.name = "CompletedModel"
	add_child(complete)
	var source: PackedScene = HUT if definition in ["dwelling","gatherer_shelter"] else ROOF
	var target := size
	var candidates: Array = [5,6,11] if definition == "dwelling" else ([2,3] if definition == "stockpile" else ([15] if definition == "gatherer_shelter" else []))
	if not candidates.is_empty():
		var candidate := LOCAL_ROOT + "house_%02d.glb" % candidates[posmod(entity_id,candidates.size())]
		if ResourceLoader.exists(candidate):
			source = load(candidate)
			model_path = candidate
			var inset := GopalaScaleStandard.number("building_presentation","plot_inset")
			target.x -= inset*2.0
			target.z -= inset*2.0
	if model_path.is_empty():
		model_path = source.resource_path
	if definition in ["timber_camp","cattle_shelter","water_point"]:
		source = CANVAS if definition == "timber_camp" else ROOF
		model_path = source.resource_path
		target = Vector3(minf(size.x,GopalaScaleStandard.number("building_presentation","shelter_width")),GopalaScaleStandard.number("building_presentation","shelter_height"),minf(size.z,GopalaScaleStandard.number("building_presentation","shelter_depth")))
		if definition == "water_point":
			target.x = GopalaScaleStandard.number("building_presentation","water_cover_width")
			target.z = target.x
			target.y = GopalaScaleStandard.number("building_presentation","water_cover_height")
	var main := _fit(source,target,float(_turn)*PI*0.5)
	main.name = "FacilityModel"
	complete.add_child(main)
	if model_path.begins_with(LOCAL_ROOT): _warm_atlas(main,Color("53594e") if definition == "stockpile" else Color("995939"))
	frame = _fit(FRAME,size,float(_turn)*PI*0.5)
	frame.name = "ConstructionFrame"
	add_child(frame)
	match definition:
		"stockpile":
			_prop(CRATE,Vector2(-1.2,1.3))
			_prop(CRATE,Vector2(1.2,1.3))
		"gatherer_shelter":
			_prop(CRATE,Vector2(-1.25,1.2))
			_prop(BARREL,Vector2(1.25,1.2))
		"timber_camp":
			_prop(CRATE,Vector2(-0.65,0.35))
			_prop(CRATE,Vector2(0.65,0.35))
			_prop(AXE,Vector2(0.9,0.9),"axe_prop")
			_prop(FENCE,Vector2(0,-1.4),"fence_prop")
		"water_point":
			_prop(BARREL,Vector2(-0.65,0.65))
			_prop(BARREL,Vector2(0.65,0.65))
			_prop(BARREL,Vector2(0,-0.55))
		"cattle_shelter":
			_prop(FENCE,Vector2(-1.45,0),"fence_prop",PI*0.5)
			_prop(FENCE,Vector2(1.45,0),"fence_prop",PI*0.5)
			_prop(FENCE,Vector2(0,-1.45),"fence_prop")
			_prop(BARREL,Vector2(1.1,1.1))
	measured_bounds = GopalaScaleStandard.bounds_in_parent(complete)
	set_meta("source_model",model_path)

func _fit(source: PackedScene, target: Vector3, yaw: float = 0.0) -> Node3D:
	var model := source.instantiate() as Node3D
	model.rotation.y += yaw
	var bounds := GopalaScaleStandard.bounds_in_parent(model)
	model.scale *= minf(target.y/bounds.size.y,minf(target.x/bounds.size.x,target.z/bounds.size.z))
	bounds = GopalaScaleStandard.bounds_in_parent(model)
	model.position -= Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	return model

func _prop(source: PackedScene, at_metres: Vector2, profile: String = "building", yaw: float = 0.0) -> void:
	var height := GopalaScaleStandard.number(profile,"prop_height" if profile == "building" else "height")
	var width := minf(_plot.x,_plot.z)*0.25 if profile == "building" else GopalaScaleStandard.number(profile,"width_max")
	var prop := _fit(source,Vector3(width,height,width),yaw+float(_turn)*PI*0.5)
	var offset := at_metres.rotated(-float(_turn)*PI*0.5)
	var bounds := GopalaScaleStandard.bounds_in_parent(prop)
	# Keep dressing inside the authoritative footprint, even after quarter turns.
	prop.position.x += clampf(GopalaScaleStandard.metres_to_world(offset.x),-_plot.x*0.5+bounds.size.x*0.5,_plot.x*0.5-bounds.size.x*0.5)
	prop.position.z += clampf(GopalaScaleStandard.metres_to_world(offset.y),-_plot.z*0.5+bounds.size.z*0.5,_plot.z*0.5-bounds.size.z*0.5)
	prop.name = "FacilityProp_%d" % complete.get_child_count()
	complete.add_child(prop)

func _warm_atlas(model: Node3D, roof_tint: Color) -> void:
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var original := mesh.get_active_material(0) as StandardMaterial3D
		if original == null or original.albedo_texture == null: continue
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/building_atlas.gdshader")
		material.set_shader_parameter("source_atlas",original.albedo_texture)
		material.set_shader_parameter("roof_color",roof_tint)
		mesh.material_override = material

func update_stage(state: String, root_half_height: float) -> void:
	position.y = -root_half_height
	complete.visible = state == "COMPLETED"
	frame.visible = state == "UNDER_CONSTRUCTION"
