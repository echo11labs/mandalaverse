class_name InteractionPrompt
extends Label
## Screen-space interaction prompt that follows an interactable.

@export var offset: Vector2 = Vector2(0.0, -48.0)

var _target: Node2D = null


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_for(target: Node2D, action_name: String = "interact") -> void:
	_target = target
	var key: String = _get_key_label(action_name)
	text = "Press %s to interact" % key
	show()


func hide_prompt() -> void:
	_target = null
	hide()


func _process(_delta: float) -> void:
	if not _target or not visible:
		return
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * _target.global_position
	global_position = screen_pos + offset


func _get_key_label(action_name: String) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for event in events:
		if event is InputEventKey:
			return event.as_text_physical_keycode()
		if event is InputEventJoypadButton:
			return event.as_text()
	return "[%s]" % action_name