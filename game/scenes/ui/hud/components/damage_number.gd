class_name DamageNumber
extends Label
## Floating damage number that rises and fades out.

@export var rise_distance: float = 40.0
@export var lifetime: float = 0.7
@export var critical_color: Color = Color(1.0, 0.3, 0.1)
@export var normal_color: Color = Color(1.0, 1.0, 1.0)
@export var normal_size: int = 24
@export var critical_size: int = 32


func show_damage(amount: int, is_critical: bool = false) -> void:
	text = str(amount) if not is_critical else "!" + str(amount)
	modulate.a = 1.0
	add_theme_font_size_override("font_size", critical_size if is_critical else normal_size)
	modulate = critical_color if is_critical else normal_color
	_play_animation()


func _play_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(self, "position:y", position.y - rise_distance, lifetime) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)

	tween.tween_property(self, "modulate:a", 0.0, lifetime * 0.5) \
		.set_delay(lifetime * 0.5) \
		.set_ease(Tween.EASE_IN)

	tween.finished.connect(queue_free)