class_name GopalaValleyCamera
extends Camera2D
## Fixed orientation, bounded movement and zoom about the pointer.

signal view_changed

const MIN_ZOOM := 0.17
const MAX_ZOOM := 1.2
var world_bounds: Rect2
var overview_center: Vector2
var camp_position: Vector2
var dragging := false

func _ready() -> void:
	position_smoothing_enabled = false
	for action in ["valley_left", "valley_right", "valley_up", "valley_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var bindings := {"valley_left": [KEY_A, KEY_LEFT], "valley_right": [KEY_D, KEY_RIGHT], "valley_up": [KEY_W, KEY_UP], "valley_down": [KEY_S, KEY_DOWN]}
	for action in bindings:
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)

func configure(bounds: Rect2, center: Vector2, camp: Vector2) -> void:
	world_bounds = bounds
	overview_center = center
	camp_position = camp
	show_overview()

func show_overview() -> void:
	zoom = Vector2.ONE * MIN_ZOOM
	position = overview_center - Vector2(0, 140)
	clamp_position()
	force_update_scroll()
	view_changed.emit()

func show_camp() -> void:
	zoom = Vector2.ONE * 0.62
	position = camp_position
	clamp_position()
	force_update_scroll()
	view_changed.emit()

func set_zoom_at_pointer(value: float) -> void:
	var before := get_global_mouse_position()
	zoom = Vector2.ONE * clampf(value, MIN_ZOOM, MAX_ZOOM)
	force_update_scroll()
	var after := get_global_mouse_position()
	position += before - after
	clamp_position()
	force_update_scroll()
	view_changed.emit()

func clamp_position() -> void:
	# Rectangle deliberately includes the diamond's corners; decorative margins
	# remain visible, but the player cannot lose the map by dragging indefinitely.
	var half := get_viewport_rect().size / (zoom * 2.0)
	var minimum := world_bounds.position + half
	var maximum := world_bounds.end - half
	position.x = clampf(position.x, minimum.x, maximum.x) if minimum.x < maximum.x else world_bounds.get_center().x
	position.y = clampf(position.y, minimum.y, maximum.y) if minimum.y < maximum.y else world_bounds.get_center().y

func _process(delta: float) -> void:
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		dragging = false
	if get_viewport().gui_get_focus_owner() != null:
		return
	var direction := Input.get_vector("valley_left", "valley_right", "valley_up", "valley_down")
	if direction != Vector2.ZERO:
		position += direction * 560.0 * delta / zoom.x
		clamp_position()
		force_update_scroll()
		view_changed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			set_zoom_at_pointer(zoom.x * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15))
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		position -= event.relative / zoom
		clamp_position()
		force_update_scroll()
		view_changed.emit()
		get_viewport().set_input_as_handled()

