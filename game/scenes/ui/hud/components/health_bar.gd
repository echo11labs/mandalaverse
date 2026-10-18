class_name HealthBar
extends ProgressBar
## Smooth health bar with tween animation for health changes.
## Can be controlled directly or via HealthComponent-like interface.

@export var tween_duration: float = 0.25

var _tween: Tween


func _ready() -> void:
	step = 0.0
	min_value = 0
	max_value = 100
	value = 100


func set_health(current: int, maximum: int = 100) -> void:
	max_value = maximum
	_animate_to(current)


func set_max_health(maximum: int) -> void:
	max_value = maximum


func _animate_to(target_value: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(self, "value", target_value, tween_duration)