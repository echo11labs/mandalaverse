class_name GopalaScenicCamera
extends Camera3D
## Bounded orthographic management view; panning does not change orientation.

signal changed
const MIN_SIZE := 32.0
const MAX_SIZE := 190.0
var target := Vector3(0, 6, 0)
var dragging := false

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	near = 0.5
	far = 800.0
	size = 175.0
	update_view()

func update_view() -> void:
	target.x = clampf(target.x, -72, 72)
	target.z = clampf(target.z, -72, 72)
	position = target + Vector3(130, 138, 150)
	look_at(target)
	changed.emit()

func overview() -> void:
	target = Vector3(0, 6, -6)
	size = 175.0
	update_view()

func focus_clearing() -> void:
	target = Vector3(-28, 2, 18)
	size = 65.0
	update_view()

func zoom_by(factor: float) -> void:
	size = clampf(size * factor, MIN_SIZE, MAX_SIZE)
	changed.emit()

func _process(delta: float) -> void:
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		dragging = false
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): input.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): input.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): input.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): input.y += 1
	if input != Vector2.ZERO and get_viewport().gui_get_focus_owner() == null:
		pan(input.normalized() * delta * size * 0.5)

func pan(amount: Vector2) -> void:
	var right := Vector3(global_basis.x.x, 0, global_basis.x.z).normalized()
	var down := Vector3(global_basis.z.x, 0, global_basis.z.z).normalized()
	target += right * amount.x + down * amount.y
	update_view()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.88)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		pan(-event.relative * size / get_viewport().get_visible_rect().size.y)
		get_viewport().set_input_as_handled()
