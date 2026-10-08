class_name GopalaBuildingModelView
extends Node3D

const ROOF := preload("res://assets/models/kenney_survival/structure-roof.glb")
const FRAME := preload("res://assets/models/kenney_survival/structure.glb")
const CANVAS := preload("res://assets/models/kenney_survival/structure-canvas.glb")
const CRATE := preload("res://assets/models/kenney_survival/box.glb")
const BARREL := preload("res://assets/models/kenney_survival/barrel.glb")
var complete: Node3D
var frame: Node3D
var measured_bounds := AABB()

func build(size: Vector3, definition: String) -> void:
	name = "BuildingVisual"
	complete = Node3D.new()
	complete.name = "CompletedModel"
	add_child(complete)
	complete.add_child(ROOF.instantiate())
	if definition == "dwelling":
		complete.add_child(CANVAS.instantiate())
	var bounds := GopalaScaleStandard.bounds_in_parent(complete)
	var factor := minf(size.y / bounds.size.y, minf(size.x / bounds.size.x, size.z / bounds.size.z))
	complete.scale *= factor
	bounds = GopalaScaleStandard.bounds_in_parent(complete)
	complete.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	measured_bounds = GopalaScaleStandard.bounds_in_parent(complete)
	frame = FRAME.instantiate()
	frame.name = "ConstructionFrame"
	add_child(frame)
	frame.scale *= factor
	frame.position = complete.position
	# Small goods props distinguish storage and water facilities, within the footprint.
	if definition in ["stockpile", "timber_camp", "water_point"]:
		var prop: Node3D = (BARREL if definition == "water_point" else CRATE).instantiate()
		complete.add_child(prop)
		GopalaScaleStandard.normalize_height(prop, GopalaScaleStandard.number("building", "prop_height") / factor)
		prop.position.x = GopalaScaleStandard.number("building", "prop_offset_x") / factor
		prop.position.z = GopalaScaleStandard.number("building", "prop_offset_z") / factor
		measured_bounds = GopalaScaleStandard.bounds_in_parent(complete)

func update_stage(state: String, root_half_height: float) -> void:
	position.y = -root_half_height
	complete.visible = state == "COMPLETED"
	frame.visible = state == "UNDER_CONSTRUCTION"
