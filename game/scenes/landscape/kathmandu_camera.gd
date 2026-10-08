extends Camera3D
## Orthographic settlement camera. Physical scale, terrain pivot and independent world commands.
const PITCH_START := -55.0
const PITCH_MIN := -75.0
const PITCH_MAX := -32.0
const YAW_SPEED := 80.0
const MAP_LIMIT := 200.0
const ZOOM_RESPONSE := 14.0
const TERRAIN_MASK := 2
var MIN_SIZE: float = GopalaScaleStandard.number("camera", "min_span")
var yaw := 45.0
var pitch := PITCH_START
var target := Vector3.ZERO
var dragging := false
var rotating := false
var clamped_last := false
var surface_height: Callable
var terrain: GopalaKathmanduTerrain
var _zoom_goal := -1.0
var _zoom_anchor := Vector2.ZERO
var _drag_screen := Vector2.ZERO

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_HEIGHT
	size = management_size()
	update_view()

func configure_terrain(model: GopalaKathmanduTerrain) -> void:
	terrain = model
	update_view()

func view_size() -> Vector2:
	var view := get_viewport().get_visible_rect().size
	if view.x < 2.0 or view.y < 2.0:
		return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	return view

func camera_distance() -> float:
	return maxf(GopalaScaleStandard.number("camera", "minimum_distance"), size * 1.5)

func aim() -> void:
	rotation_degrees = Vector3(pitch, yaw, 0.0)
	position = target + basis.z * camera_distance()
	near = GopalaScaleStandard.number("camera", "near_clip")
	# Covers regional relief while avoiding the old 400-km depth interval.
	far = camera_distance() + maxf(size * 2.0, GopalaScaleStandard.number("camera", "relief_depth"))

func ground_forward() -> Vector3:
	return Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()

func ground_right() -> Vector3:
	return Vector3(basis.x.x, 0.0, basis.x.z).normalized()

func plane_hit(screen: Vector2, plane_y: float) -> Vector3:
	var origin := project_ray_origin(screen)
	var direction := project_ray_normal(screen)
	var distance := (plane_y - origin.y) / direction.y if absf(direction.y) > 0.00001 else 0.0
	return origin + direction * distance

func maximum_size() -> float:
	# Ground footprint includes viewport aspect, current yaw AND current tilt.
	var angle := deg_to_rad(yaw)
	var aspect := view_size().x / maxf(1.0, view_size().y)
	var slope := 1.0 / sin(deg_to_rad(absf(pitch)))
	var x_span := absf(cos(angle)) * aspect + absf(sin(angle)) * slope
	var z_span := absf(sin(angle)) * aspect + absf(cos(angle)) * slope
	return MAP_LIMIT * 2.0 / maxf(x_span, z_span)

func footprint_fits(span: float) -> bool:
	return span <= maximum_size()

func ground_corners() -> PackedVector3Array:
	var view := view_size()
	var corners := PackedVector3Array()
	for screen in [Vector2.ZERO, Vector2(view.x, 0), view, Vector2(0, view.y)]:
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
	if max_x - min_x >= MAP_LIMIT * 2.0 - 0.001:
		target.x = 0.0
	elif min_x < -MAP_LIMIT:
		target.x += -MAP_LIMIT - min_x
	elif max_x > MAP_LIMIT:
		target.x += MAP_LIMIT - max_x
	if max_z - min_z >= MAP_LIMIT * 2.0 - 0.001:
		target.z = 0.0
	elif min_z < -MAP_LIMIT:
		target.z += -MAP_LIMIT - min_z
	elif max_z > MAP_LIMIT:
		target.z += MAP_LIMIT - max_z
	clamped_last = Vector2(before.x, before.z).distance_to(Vector2(target.x, target.z)) > 0.00001
	if terrain != null:
		target.y = surface_height.call(target.x, target.z) if surface_height.is_valid() else terrain.height_at(target.x, target.z)
	aim()

func update_view() -> void:
	size = clampf(size, MIN_SIZE, maximum_size())
	clamp_to_terrain()

func pitch_for_size(_s: float) -> float:
	# Zoom preserves a chosen tilt; Home explicitly resets orientation.
	return PITCH_START

func management_size() -> float:
	return clampf(GopalaScaleStandard.number("camera", "default_span"), MIN_SIZE, maximum_size())

func overview() -> void:
	_zoom_goal = -1.0
	target = Vector3.ZERO
	pitch = PITCH_START
	size = maximum_size()
	update_view()

func focus_point(point: Vector3, view_span: float) -> void:
	_zoom_goal = -1.0
	target = point
	size = view_span
	update_view()

func reset_focus(point: Vector3) -> void:
	yaw = 45.0
	pitch = PITCH_START
	dragging = false
	rotating = false
	focus_point(point, management_size())

func zoom_by(factor: float) -> void:
	if not is_finite(factor) or factor <= 0.0:
		return
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

func anchor_at(point: Vector3, screen: Vector2) -> void:
	# Following terrain height shifts the view vertically. Reproject at the grabbed
	# point's height until both cursor anchoring and the ground pivot agree.
	for iteration in 12:
		var after := plane_hit(screen, point.y)
		target.x += point.x - after.x
		target.z += point.z - after.z
		update_view()
		if clamped_last or unproject_position(point).distance_to(screen) < 0.05:
			break

func zoom_toward(screen: Vector2, factor: float) -> void:
	var before := terrain_hit(screen)
	zoom_by(factor)
	if not is_inf(before.x):
		anchor_at(before, screen)

func queue_zoom(screen: Vector2, factor: float) -> void:
	if not is_finite(factor) or factor <= 0.0:
		return
	_zoom_anchor = screen
	_zoom_goal = clampf((_zoom_goal if _zoom_goal > 0.0 else size) * factor, MIN_SIZE, maximum_size())

func terrain_hit(screen: Vector2) -> Vector3:
	var origin := project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + project_ray_normal(screen) * far, TERRAIN_MASK)
	query.hit_back_faces = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else Vector3(INF, INF, INF)

func pan_ground(screen_x: float, screen_y: float) -> void:
	target += ground_right() * screen_x + ground_forward() * screen_y
	update_view()

func drag_pan(from: Vector2, to: Vector2) -> void:
	# Match screen-space drag at any tilt, without combining it with world orders.
	anchor_at(plane_hit(from, target.y), to)

func _placement_active() -> bool:
	var parent = get_parent()
	return parent != null and parent.get("hud") != null and parent.hud._placement_active

func _process(delta: float) -> void:
	if _zoom_goal > 0.0:
		var goal := clampf(_zoom_goal, MIN_SIZE, maximum_size())
		var next := exp(lerpf(log(size), log(goal), 1.0 - exp(-ZOOM_RESPONSE * delta)))
		if absf(next - goal) <= maxf(0.000001, goal * 0.0005):
			next = goal
			_zoom_goal = -1.0
		zoom_toward(_zoom_anchor, next / size)
	var direction := Vector2(Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left"), Input.get_action_strength("camera_forward") - Input.get_action_strength("camera_back"))
	if not _placement_active():
		var turn := Input.get_action_strength("camera_rotate_right") - Input.get_action_strength("camera_rotate_left")
		if turn != 0.0:
			turn_by(turn * YAW_SPEED * delta)
	if direction != Vector2.ZERO:
		var speed := 1.5 if Input.is_key_pressed(KEY_SHIFT) else 0.5
		var step := direction.normalized() * size * delta * speed
		pan_ground(step.x, step.y)
	if (dragging or rotating) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		dragging = false
		rotating = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			rotating = event.pressed and event.shift_pressed
			dragging = event.pressed and not event.shift_pressed
			_drag_screen = event.position
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			queue_zoom(event.position, 0.84 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.84)
			get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		queue_zoom(event.position, 1.0 / maxf(0.01, event.factor))
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		drag_pan(event.position, event.position + event.delta * 12.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.is_action("camera_zoom_in"):
			queue_zoom(get_viewport().get_mouse_position(), 0.84)
		elif event.is_action("camera_zoom_out"):
			queue_zoom(get_viewport().get_mouse_position(), 1.0 / 0.84)
	elif event is InputEventMouseMotion and rotating:
		yaw = fposmod(yaw - event.relative.x * 0.22, 360.0)
		pitch = clampf(pitch - event.relative.y * 0.12, PITCH_MIN, PITCH_MAX)
		update_view()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		drag_pan(_drag_screen, event.position)
		_drag_screen = event.position
		get_viewport().set_input_as_handled()
