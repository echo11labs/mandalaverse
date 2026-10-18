class_name GopalaProgressMeter
extends ProgressBar
## Themed progress meter with a warning state. Decorative by default; when
## warning it becomes hoverable so the reason tooltip can surface.

@export var warn_below: float = -1.0

var _tokens: UITokens = UITokens.new()
var _settings: GopalaUISettings
var _warning: bool = false

func _ready() -> void:
	_settings = GopalaUISettings.settings()
	show_percentage = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_styles()
	_apply_ui_scale()
	if _settings != null and not _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.connect(_on_settings_changed)

func _exit_tree() -> void:
	if _settings != null and _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.disconnect(_on_settings_changed)

func set_fraction(fraction: float) -> void:
	value = clampf(fraction, 0.0, 1.0) * max_value

## Warning changes colour AND makes the meter hoverable with a reason, so the
## state never depends on colour alone.
func set_warning(warning: bool, reason: String = "") -> void:
	_warning = warning
	mouse_filter = Control.MOUSE_FILTER_STOP if warning else Control.MOUSE_FILTER_IGNORE
	tooltip_text = reason if warning else ""
	_apply_styles()

func set_disabled_state(disabled: bool) -> void:
	self_modulate = Color(1, 1, 1, 0.45) if disabled else Color.WHITE

func _apply_styles() -> void:
	var fill_color := GopalaTheme.TERRA if _warning else GopalaTheme.BRASS
	add_theme_stylebox_override("fill", GopalaTheme.flat(fill_color, _tokens.radius_sm))
	add_theme_stylebox_override("background", GopalaTheme.flat(GopalaTheme.PAPER_SUNK, _tokens.radius_sm, _tokens.border_width, GopalaTheme.INK_FAINT))

func _apply_ui_scale() -> void:
	var factor := _settings.ui_scale if _settings != null else 1.0
	custom_minimum_size = Vector2(0, UITokens.scaled(float(_tokens.icon_sm + _tokens.space_2), factor))
	add_theme_font_size_override("font_size", int(UITokens.scaled(float(_tokens.text_meta), factor)))

func _on_settings_changed(key: StringName) -> void:
	match key:
		GopalaUISettings.KEY_UI_SCALE:
			_apply_ui_scale()
		GopalaUISettings.KEY_HIGH_CONTRAST:
			_apply_styles()
