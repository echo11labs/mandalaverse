extends Camera3D
## Fixed settlement view. Pan stays on the ground; zoom cannot reveal the void past the terrain.
const PITCH_START := -55.0
const PITCH_MIN := -75.0
const PITCH_MAX := -32.0
const YAW_SPEED := 80.0
const DISTANCE := 520.0
const MIN_SIZE := 3.0
const MAP_LIMIT := 200.0
const MANAGEMENT_FRACTION := 0.62
var yaw := 45.0
var pitch := PITCH_START
var target := Vector3(0, 8, 0)
var dragging := false
var rotating := false
var clamped_last := false

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_HEIGHT
	near = 0.05
	far = 4000.0
	overview()

func view_size() -> Vector2:
	var view := get_viewport().get_visible_rect().size
	if view.x < 2.0 or view.y < 2.0:
		return Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height")
		)
	return view

func aim() -> void:
	rotation_degrees = Vector3(pitch, yaw, 0.0)
	position = target + basis.z * minf(DISTANCE, maxf(8.0, size * 2.0))

func ground_forward() -> Vector3:
	return Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()

func ground_right() -> Vector3:
	return Vector3(basis.x.x, 0.0, basis.x.z).normalized()

func plane_hit(screen: Vector2, plane_y: float) -> Vector3:
	var origin := project_ray_origin(screen)
	var direction := project_ray_normal(screen)
	var distance := (plane_y - origin.y) / direction.y if absf(direction.y) > 0.00001 else 0.0
	return origin + direction * distance

func footprint_fits(span: float) -> bool:
	var saved := size
	size = span
	aim()
	var corners := ground_corners()
	size = saved
	aim()
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for corner in corners:
		min_x = minf(min_x, corner.x)
		max_x = maxf(max_x, corner.x)
		min_z = minf(min_z, corner.z)
		max_z = maxf(max_z, corner.z)
	return max_x - min_x <= MAP_LIMIT * 2.0 and max_z - min_z <= MAP_LIMIT * 2.0

func maximum_size() -> float:
	var low := MIN_SIZE
	var high := MAP_LIMIT * 2.0
	for _step in 18:
		var mid := (low + high) * 0.5
		if footprint_fits(mid):
			low = mid
		else:
			high = mid
	return low

func ground_corners() -> PackedVector3Array:
	var view := view_size()
	var corners := PackedVector3Array()
	for screen in [Vector2(0, 0), Vector2(view.x, 0), Vector2(view.x, view.y), Vector2(0, view.y)]:
		corners.append(plane_hit(screen, target.y))
	return corners

func clamp_to_terrain() -> void:
	aim()
	var corners := ground_corners()
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for corner in corners:
		min_x = minf(min_x, corner.x)
		max_x = maxf(max_x, corner.x)
		min_z = minf(min_z, corner.z)
		max_z = maxf(max_z, corner.z)
	var before := target
	if max_x - min_x >= MAP_LIMIT * 2.0:
		target.x = 0.0
	elif min_x < -MAP_LIMIT:
		target.x += -MAP_LIMIT - min_x
	elif max_x > MAP_LIMIT:
		target.x += MAP_LIMIT - max_x
	if max_z - min_z >= MAP_LIMIT * 2.0:
		target.z = 0.0
	elif min_z < -MAP_LIMIT:
		target.z += -MAP_LIMIT - min_z
	elif max_z > MAP_LIMIT:
		target.z += MAP_LIMIT - max_z
	clamped_last = before.distance_to(target) > 0.001
	aim()

func update_view() -> void:
	size = clampf(size, MIN_SIZE, maximum_size())
	clamp_to_terrain()

func management_size() -> float:
	return clampf(maximum_size() * MANAGEMENT_FRACTION, MIN_SIZE, maximum_size())

func overview() -> void:
	target = Vector3(0, 8, 0)
	size = management_size()
	update_view()

func focus_point(point: Vector3, view_span: float) -> void:
	target = point
	size = clampf(view_span, MIN_SIZE, maximum_size())
	update_view()

func zoom_by(factor: float) -> void:
	size = clampf(size * factor, MIN_SIZE, maximum_size())
	update_view()

func zoom_step(factor: float) -> void:
	zoom_toward(view_size() * 0.5, factor)

func turn_by(degrees: float) -> void:
	yaw = fposmod(yaw + degrees, 360.0)
	update_view()

func tilt_by(degrees: float) -> void:
	pitch = clampf(pitch + degrees, PITCH_MIN, PITCH_MAX)
	update_view()

func zoom_toward(screen: Vector2, factor: float) -> void:
	var before := terrain_hit(screen)
	zoom_by(factor)
	if is_inf(before.x):
		return
	var after := terrain_hit(screen)
	if is_inf(after.x):
		return
	target.x += before.x - after.x
	target.z += before.z - after.z
	update_view()

func terrain_hit(screen: Vector2) -> Vector3:
	var origin := project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + project_ray_normal(screen) * 4000.0)
	query.hit_back_faces = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3(INF, INF, INF)
	return hit.position

func pan_ground(screen_x: float, screen_y: float) -> void:
	target += ground_right() * screen_x + ground_forward() * screen_y
	update_view()

func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("camera_left"):
		direction.x -= 1.0
	if Input.is_action_pressed("camera_right"):
		direction.x += 1.0
	if Input.is_action_pressed("camera_forward"):
		direction.y += 1.0
	if Input.is_action_pressed("camera_back"):
		direction.y -= 1.0
	var turned := false
	if Input.is_action_pressed("camera_rotate_left"):
		yaw -= YAW_SPEED * delta
		turned = true
	if Input.is_action_pressed("camera_rotate_right"):
		yaw += YAW_SPEED * delta
		turned = true
	if turned:
		yaw = fposmod(yaw, 360.0)
		update_view()
	if direction != Vector2.ZERO:
		var step := direction.normalized() * size * delta * 0.5
		pan_ground(step.x, step.y)
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		dragging = false
	if rotating and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		rotating = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			rotating = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_toward(event.position, 0.84 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.84)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.is_action("camera_zoom_in"):
			zoom_toward(get_viewport().get_mouse_position(), 0.84)
		elif event.is_action("camera_zoom_out"):
			zoom_toward(get_viewport().get_mouse_position(), 1.0 / 0.84)
	elif event is InputEventMouseMotion and rotating:
		yaw = fposmod(yaw - event.relative.x * 0.22, 360.0)
		pitch = clampf(pitch - event.relative.y * 0.12, PITCH_MIN, PITCH_MAX)
		update_view()
	elif event is InputEventMouseMotion and dragging:
		var scale := size / view_size().y
		pan_ground(-event.relative.x * scale, event.relative.y * scale)
