class_name GopalaWorkerModelView
extends Node3D

const MODEL := preload("res://assets/models/kenney_workers/character-a.glb")
var model_path := "res://assets/models/kenney_workers/character-a.glb"
var player: AnimationPlayer
var current_pose := ""
var _working_loop := false
var measured_bounds := AABB()

func build(entity_id := 0) -> void:
	name = "WorkerVisual"
	var fitted := Node3D.new()
	fitted.name = "FittedModel"
	add_child(fitted)
	# Source-restricted downloads are local-only; public checkouts retain the licensed fallback.
	var local_variants: Array[String] = []
	for number in [4,5,1,2,3,6]:
		var candidate := "res://assets/models/local_villagers/peasant_%d.glb" % number
		if FileAccess.file_exists(candidate): local_variants.append(candidate)
	var local_path := "" if local_variants.is_empty() else local_variants[posmod(entity_id,local_variants.size())]
	var source: PackedScene = MODEL
	if FileAccess.file_exists(local_path):
		source = load(local_path)
		model_path = local_path
	var model := source.instantiate()
	fitted.add_child(model)
	player = model.find_children("*", "AnimationPlayer", true, false)[0]
	player.play("static")
	player.advance(0.0)
	GopalaScaleStandard.normalize_height(fitted, GopalaScaleStandard.number("villager", "height"))
	measured_bounds = GopalaScaleStandard.bounds_in_parent(fitted)
	update_state({})

## Presentation observes simulation; animation never transfers goods or advances work.
func update_state(attributes: Dictionary, paused := false, speed := 1.0) -> void:
	player.speed_scale = 0.0 if paused else speed
	var moving := str(attributes.get(&"movement_state", "IDLE")) == "MOVING"
	var working := str(attributes.get(&"task_state", "")) == "PERFORMING_LABOR"
	var pose := "walk" if moving else ("pick-up" if str(attributes.get(&"task_state", "")) == "PICKING_UP" else "idle")
	if working and not moving:
		pose = "interact-right" if player.has_animation("interact-right") else "pick-up"
	if moving:
		var direction := Vector2(float(attributes.get(&"waypoint_x", attributes.get(&"destination_x", 0))) - float(attributes.get(&"position_x", 0)), float(attributes.get(&"waypoint_z", attributes.get(&"destination_z", 0))) - float(attributes.get(&"position_z", 0)))
		if direction.length_squared() > 0.00000001:
			rotation.y = atan2(direction.x, direction.y)
	if pose != current_pose or working != _working_loop:
		player.get_animation(pose).loop_mode = Animation.LOOP_NONE if pose == "pick-up" and not working else Animation.LOOP_LINEAR
		player.play(pose, 0.12)
		current_pose = pose
		_working_loop = working
