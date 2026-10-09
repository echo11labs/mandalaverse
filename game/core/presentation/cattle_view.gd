class_name GopalaCattleView
extends Node3D
## Licensed Styloo model; animation observes herd state and never advances simulation.
const MODEL := preload("res://assets/models/animals/styloo/Cow.glb")
var geometry: Node3D
var player: AnimationPlayer
var current_pose := ""
var measured_bounds := AABB()
var _previous_position := Vector2.ZERO
var _has_previous := false
func _init():
	geometry = Node3D.new()
	geometry.name = "FittedCow"
	add_child(geometry)
	var model := MODEL.instantiate()
	geometry.add_child(model)
	player = model.find_children("*","AnimationPlayer",true,false)[0]
	player.play("iddle")
	player.advance(0.0)
	GopalaScaleStandard.normalize_height(geometry,GopalaScaleStandard.number("cattle","height"))
	measured_bounds = GopalaScaleStandard.bounds_in_parent(geometry)
	update_state({},true)
func update_state(attributes: Dictionary, paused := false, speed := 1.0) -> void:
	player.speed_scale = 0.0 if paused else speed
	var moving := str(attributes.get(&"cattle_move_state",&"IDLE")) == "MOVING"
	var point := Vector2(float(attributes.get(&"position_x",0)),float(attributes.get(&"position_z",0)))
	if moving and _has_previous and point.distance_squared_to(_previous_position) > 0.00000001:
		var direction := point-_previous_position
		rotation.y = atan2(-direction.x,-direction.y)
	_previous_position = point
	_has_previous = true
	var pose := "walk" if moving else "iddle"
	if pose != current_pose:
		player.get_animation(pose).loop_mode = Animation.LOOP_LINEAR
		player.play(pose,0.12)
		current_pose = pose
