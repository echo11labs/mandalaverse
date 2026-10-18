class_name GopalaStatRow
extends HBoxContainer
## Key/value row for context panels and management windows.
## Decorative: ignores the mouse so world picking continues underneath.

@export var max_key_chars: int = 40
@export var max_value_chars: int = 16

var _tokens: UITokens = UITokens.new()
var _settings: GopalaUISettings
var _key_label: Label
var _value_label: Label
var _slot: HBoxContainer

func _ready() -> void:
	_settings = GopalaUISettings.settings()
	_key_label = get_node_or_null("Key") as Label
	_value_label = get_node_or_null("Value") as Label
	_slot = get_node_or_null("Slot") as HBoxContainer
	if _key_label == null or _value_label == null or _slot == null:
		push_error("GopalaStatRow: missing children (need Key, Value, Slot) at %s" % get_path())
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node in [_key_label, _value_label, _slot]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_label.clip_text = true
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_label.clip_text = true
	_value_label.add_theme_font_override("font", GopalaTheme.font(GopalaTheme.FONT_MONO, 500, _tokens.text_body))
	_apply_ui_scale()
	if _settings != null and not _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.connect(_on_settings_changed)

func _exit_tree() -> void:
	if _settings != null and _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.disconnect(_on_settings_changed)

func set_key(value: String) -> void:
	if _key_label == null:
		return
	_key_label.text = UITokens.truncate(value, max_key_chars)
	_key_label.tooltip_text = value

func set_value_text(value: String) -> void:
	if _value_label == null:
		return
	_value_label.text = UITokens.truncate(value, max_value_chars)
	_value_label.tooltip_text = value

## Warning is encoded with a "!" prefix as well as colour (never colour alone).
func set_warning(warning: bool) -> void:
	if _value_label == null:
		return
	var base := _value_label.text.trim_prefix("! ")
	if warning and not base.begins_with("!"):
		_value_label.text = "! " + base
		_value_label.add_theme_color_override("font_color", GopalaTheme.TERRA)
	else:
		_value_label.text = base
		_value_label.add_theme_color_override("font_color", GopalaTheme.INK)

func set_slot_visible(visible: bool) -> void:
	if _slot != null:
		_slot.visible = visible

func set_slot_child(child: Control) -> void:
	if _slot == null:
		return
	_slot.add_child(child)

func _apply_ui_scale() -> void:
	if _key_label == null or _value_label == null:
		return
	var factor := _settings.ui_scale if _settings != null else 1.0
	_key_label.add_theme_font_size_override("font_size", int(UITokens.scaled(float(_tokens.text_body), factor)))
	_value_label.add_theme_font_size_override("font_size", int(UITokens.scaled(float(_tokens.text_body), factor)))

func _on_settings_changed(key: StringName) -> void:
	if key == GopalaUISettings.KEY_UI_SCALE:
		_apply_ui_scale()
