class_name GopalaIconButton
extends Button
## Square icon/text button for docks and toolbars.
## The tooltip shows the currently resolved InputMap binding for `action`.

@export var action: StringName = &""
@export var base_tooltip: String = ""
@export var square_target: bool = true
@export var selectable: bool = false
@export var max_display_chars: int = 16

var _tokens: UITokens = UITokens.new()
var _settings: GopalaUISettings

func _ready() -> void:
	_settings = GopalaUISettings.settings()
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_text = true
	if selectable:
		toggle_mode = true
	_apply_ui_scale()
	refresh_binding()
	if _settings != null and not _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.connect(_on_settings_changed)

func _exit_tree() -> void:
	if _settings != null and _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.disconnect(_on_settings_changed)

## Re-reads the binding; call after rebinding actions.
func refresh_binding() -> void:
	ShortcutTooltip.apply(self, action, base_tooltip)

## Bounds the visible label for long localized text; full text stays in the
## tooltip via base_tooltip.
func set_label(value: String) -> void:
	base_tooltip = value
	text = UITokens.truncate(value, max_display_chars)
	refresh_binding()

func set_selected(selected: bool) -> void:
	if selectable:
		set_pressed_no_signal(selected)

func _apply_ui_scale() -> void:
	var factor := _settings.ui_scale if _settings != null else 1.0
	if square_target:
		var side := UITokens.scaled(float(_tokens.control_min_target), factor)
		custom_minimum_size = Vector2(side, side)
	else:
		var height := UITokens.scaled(float(_tokens.control_height_md), factor)
		custom_minimum_size = Vector2(0, height)

func _on_settings_changed(key: StringName) -> void:
	if key == GopalaUISettings.KEY_UI_SCALE:
		_apply_ui_scale()
