class_name GopalaWaterSourceView
extends Node3D

var pick_shape: CollisionShape3D
func build(_entity_id: int, _seed: int, _resource: StringName, _ground: Callable, _position: Vector2) -> void:
	var model: Node3D = preload("res://assets/models/buildings/highlands/SM_Barrel.glb").instantiate()
	model.name = "MeshChild"
	add_child(model)
	GopalaScaleStandard.normalize_height(model,GopalaScaleStandard.number("water_source","height"))

func update_amount(remaining: int, _initial: int) -> void:
	visible = remaining > 0
	if pick_shape != null: pick_shape.set_deferred("disabled",remaining <= 0)
