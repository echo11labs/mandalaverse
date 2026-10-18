class_name NotificationStack
extends VBoxContainer
## Toast-style notification stack with queue and auto-dismiss.

@export var notification_scene: PackedScene
@export var max_visible: int = 5
@export var auto_dismiss_time: float = 3.0

var _queue: Array[String] = []
var _active: Array[Control] = []


func _ready() -> void:
	# The owner supplies notifications through push(), avoiding duplicate delivery.
	pass


func push(message: String) -> void:
	if message.is_empty() or _queue.has(message): return
	for toast in _active:
		if toast.get_meta("message", "") == message: return
	if _queue.size() >= 16: _queue.pop_front()
	_queue.append(message)
	_flush_queue()


func _flush_queue() -> void:
	while _queue.size() > 0 and _active.size() < max_visible:
		_show_next()


func _show_next() -> void:
	var message: String = _queue.pop_front()
	var toast: Control = notification_scene.instantiate()

	toast.set_meta("message", message)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = toast.get_node("MarginContainer/MessageLabel")
	if label:
		label.text = message
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(toast.get_node("MarginContainer") as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	toast.modulate.a = 0.0
	add_child(toast)
	_active.append(toast)

	var tween: Tween = create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.2)

	var timer: Timer = Timer.new()
	timer.wait_time = auto_dismiss_time
	timer.one_shot = true
	toast.add_child(timer)
	timer.timeout.connect(_dismiss.bind(toast))
	timer.start()


func _dismiss(toast: Control) -> void:
	_active.erase(toast)

	var tween: Tween = toast.create_tween()
	tween.tween_property(toast, "modulate:a", 0.0, 0.2)
	tween.finished.connect(func() -> void:
		toast.queue_free()
		_flush_queue()
	)
