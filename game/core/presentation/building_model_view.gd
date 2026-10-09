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
var complete: Node3D
var frame: Node3D
var measured_bounds := AABB()

func build(size: Vector3, definition: String) -> void:
	name = "BuildingVisual"
	complete = Node3D.new()
	complete.name = "CompletedModel"
	add_child(complete)
	# Solid huts for homes/food shelter; retain open functional shelters elsewhere.
	complete.add_child((HUT if definition in ["dwelling","gatherer_shelter"] else ROOF).instantiate())
	var bounds := GopalaScaleStandard.bounds_in_parent(complete)
	var factor := minf(size.y / bounds.size.y, minf(size.x / bounds.size.x, size.z / bounds.size.z))
	complete.scale *= factor
	bounds = GopalaScaleStandard.bounds_in_parent(complete)
	complete.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	measured_bounds = GopalaScaleStandard.bounds_in_parent(complete)
	frame = FRAME.instantiate()
	frame.name = "ConstructionFrame"
	add_child(frame)
	var frame_bounds := GopalaScaleStandard.bounds_in_parent(frame)
	frame.scale *= minf(size.y/frame_bounds.size.y,minf(size.x/frame_bounds.size.x,size.z/frame_bounds.size.z))
	frame_bounds = GopalaScaleStandard.bounds_in_parent(frame)
	frame.position -= Vector3(frame_bounds.get_center().x,frame_bounds.position.y,frame_bounds.get_center().z)
	# Small goods props distinguish storage and water facilities, within the footprint.
	if definition in ["stockpile", "timber_camp", "water_point"]:
		var prop: Node3D = (BARREL if definition == "water_point" else CRATE).instantiate()
		complete.add_child(prop)
		GopalaScaleStandard.normalize_height(prop, GopalaScaleStandard.number("building", "prop_height") / factor)
		prop.position.x = GopalaScaleStandard.number("building", "prop_offset_x") / factor
		prop.position.z = GopalaScaleStandard.number("building", "prop_offset_z") / factor
		measured_bounds = GopalaScaleStandard.bounds_in_parent(complete)
	if definition in ["cattle_shelter","timber_camp"]:
		var prop: Node3D = (FENCE if definition == "cattle_shelter" else AXE).instantiate()
		complete.add_child(prop)
		var profile := "fence_prop" if definition == "cattle_shelter" else "axe_prop"
		GopalaScaleStandard.normalize_height(prop,GopalaScaleStandard.number(profile,"height")/factor)
		var prop_bounds := GopalaScaleStandard.bounds_in_parent(prop)
		var width := maxf(prop_bounds.size.x,prop_bounds.size.z)*factor
		var limit := GopalaScaleStandard.number(profile,"width_max")
		if width > limit: prop.scale *= limit/width
		# Re-anchor after any width cap; offset remains inside the existing plot.
		prop_bounds = GopalaScaleStandard.bounds_in_parent(prop)
		prop.position -= Vector3(prop_bounds.get_center().x,prop_bounds.position.y,prop_bounds.get_center().z)
		prop.position.z += GopalaScaleStandard.number(profile,"offset_z")/factor
		measured_bounds = GopalaScaleStandard.bounds_in_parent(complete)

func update_stage(state: String, root_half_height: float) -> void:
	position.y = -root_half_height
	complete.visible = state == "COMPLETED"
	frame.visible = state == "UNDER_CONSTRUCTION"
