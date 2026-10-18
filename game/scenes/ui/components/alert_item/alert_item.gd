class_name GopalaAlertItem
extends HBoxContainer
## One notification row: severity glyph, message, optional action button.
## Decorative surface ignores the mouse; the action button stops it.

signal action_requested(alert_id: StringName)

@export var max_message_chars: int = 80

var _tokens: UITokens = UITokens.new()
var _settings: GopalaUISettings
var _glyph: Label
var _message: Label
var _action: Button
var _alert_id: StringName = &""
var _severity: StringName = &"neutral"
var _clean_message: String = ""

func _ready() -> void:
	_settings = GopalaUISettings.settings()
	_glyph = get_node_or_null("Glyph") as Label
	_message = get_node_or_null("Message") as Label
	_action = get_node_or_null("Action") as Button
	if _glyph == null or _message == null or _action == null:
		push_error("GopalaAlertItem: missing children (need Glyph, Message, Action) at %s" % get_path())
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action.mouse_filter = Control.MOUSE_FILTER_STOP
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.clip_text = true
	if not _action.pressed.is_connected(_on_action_pressed):
		_action.pressed.connect(_on_action_pressed)
	_apply_ui_scale()
	if _settings != null and not _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.connect(_on_settings_changed)

func _exit_tree() -> void:
	if _settings != null and _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.disconnect(_on_settings_changed)

func set_alert(alert_id: StringName, severity: StringName, message: String, actionable: bool) -> void:
	_alert_id = alert_id
	_severity = severity
	_clean_message = message
	visible = true
	_refresh_glyph()
	_refresh_message()
	_action.visible = actionable

func set_action_enabled(enabled: bool, reason: String = "") -> void:
	_action.disabled = not enabled
	# Disabled controls must state a reason, never sit silent.
	_action.tooltip_text = reason if not enabled else "Show in world"

func _refresh_glyph() -> void:
	if _glyph == null:
		return
	var style: Dictionary = GopalaStatusBadge.severity_style(_severity)
	_glyph.text = String(style["glyph"])
	_glyph.add_theme_color_override("font_color", style["fg"])
	_glyph.custom_minimum_size = Vector2(float(_tokens.icon_sm), 0)

func _refresh_message() -> void:
	if _message == null:
		return
	_message.text = UITokens.truncate(_clean_message, max_message_chars)
	tooltip_text = _clean_message
	var style: Dictionary = GopalaStatusBadge.severity_style(_severity)
	_message.add_theme_color_override("font_color", style["fg"] if _severity == &"critical" else GopalaTheme.INK)

func _apply_ui_scale() -> void:
	if _glyph == null or _message == null:
		return
	var factor := _settings.ui_scale if _settings != null else 1.0
	_glyph.add_theme_font_size_override("font_size", int(UITokens.scaled(float(_tokens.text_body), factor)))
	_message.add_theme_font_size_override("font_size", int(UITokens.scaled(float(_tokens.text_body), factor)))
	_action.custom_minimum_size = Vector2(
		UITokens.scaled(float(_tokens.control_height_md), factor),
		UITokens.scaled(float(_tokens.control_height_sm), factor))

func _on_action_pressed() -> void:
	action_requested.emit(_alert_id)

func _on_settings_changed(key: StringName) -> void:
	if key == GopalaUISettings.KEY_UI_SCALE:
		_apply_ui_scale()
