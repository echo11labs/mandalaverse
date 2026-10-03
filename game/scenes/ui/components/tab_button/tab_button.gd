class_name GopalaTabButton
extends Button
## Toggle tab button for panel headers and catalog categories.

@export var action: StringName = &""
@export var base_tooltip: String = ""
@export var max_display_chars: int = 18

var _tokens: UITokens = UITokens.new()
var _settings: GopalaUISettings

func _ready() -> void:
	_settings = GopalaUISettings.settings()
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	toggle_mode = true
	clip_text = true
	_apply_ui_scale()
	refresh_binding()
	if _settings != null and not _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.connect(_on_settings_changed)

func _exit_tree() -> void:
	if _settings != null and _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.disconnect(_on_settings_changed)

func set_label(value: String) -> void:
	text = UITokens.truncate(value, max_display_chars)
	base_tooltip = value if text != value else base_tooltip
	refresh_binding()

func set_selected(selected: bool) -> void:
	set_pressed_no_signal(selected)

func refresh_binding() -> void:
	ShortcutTooltip.apply(self, action, base_tooltip)

func _apply_ui_scale() -> void:
	var factor := _settings.ui_scale if _settings != null else 1.0
	var width := UITokens.scaled(80.0, factor)
	var height := UITokens.scaled(float(_tokens.control_height_sm), factor)
	custom_minimum_size = Vector2(width, height)
	add_theme_font_size_override("font_size", int(UITokens.scaled(float(_tokens.text_body), factor)))

func _on_settings_changed(key: StringName) -> void:
	if key == GopalaUISettings.KEY_UI_SCALE:
		_apply_ui_scale()
