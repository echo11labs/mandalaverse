class_name ScoreDisplay
extends Label
## Animated score counter that counts up/down smoothly.

@export var count_duration: float = 0.4

var _displayed_score: int = 0
var _tween: Tween


func _ready() -> void:
	# Optional legacy integration; scene-local callers can bind directly.
	var bus := get_node_or_null("/root/EventBus")
	if bus != null:
		bus.score_changed.connect(_on_score_changed)
	text = "0"


func _on_score_changed(new_score: int) -> void:
	_animate_counter(_displayed_score, new_score)


func _animate_counter(from: int, to: int) -> void:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.tween_method(_set_counter_value, float(from), float(to), count_duration)


func _set_counter_value(value: float) -> void:
	_displayed_score = int(value)
	text = str(_displayed_score)