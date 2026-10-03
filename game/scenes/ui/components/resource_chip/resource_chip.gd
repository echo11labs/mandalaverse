class_name GopalaResourceChip
extends PanelContainer
## Compact stock readout: icon + amount + name.
## Decorative by default so world clicks pass through; interactive chips stop
## the mouse so panel surfaces never leak clicks to the world.

@export var interactive: bool = false
@export var max_display_chars: int = 24

var _tokens: UITokens = UITokens.new()
var _settings: GopalaUISettings
var _icon: TextureRect
var _amount: Label
var _name_label: Label
var _clean_name: String = ""
var _warning: bool = false

func _ready() -> void:
	_settings = GopalaUISettings.settings()
	_icon = get_node_or_null("Column/Row/Icon") as TextureRect
	_amount = get_node_or_null("Column/Row/Amount") as Label
	_name_label = get_node_or_null("Column/Name") as Label
	if _icon == null or _amount == null or _name_label == null:
		push_error("GopalaResourceChip: missing children (need Column/Row/Icon, Column/Row/Amount, Column/Name) at %s" % get_path())
		return
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	for node in [get_node_or_null("Column"), get_node_or_null("Column/Row"), _icon, _amount, _name_label]:
		var control := node as Control
		if control != null:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_amount.add_theme_font_override("font", GopalaTheme.font(GopalaTheme.FONT_MONO, 500, _tokens.text_body))
	_amount.clip_text = true
	_name_label.clip_text = true
	_apply_ui_scale()
	if _settings != null and not _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.connect(_on_settings_changed)

func _exit_tree() -> void:
	if _settings != null and _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.disconnect(_on_settings_changed)

func set_amount(value: int) -> void:
	if _amount != null:
		_amount.text = str(value)

func set_display_name(value: String) -> void:
	_clean_name = value
	if _name_label == null:
		return
	_name_label.text = UITokens.truncate(value, max_display_chars)
	tooltip_text = value
	_refresh_warning_text()

func set_icon(texture: Texture2D) -> void:
	if _icon == null:
		return
	_icon.texture = texture
	_icon.visible = texture != null

## Warning is encoded with a "!" prefix as well as colour (never colour alone).
func set_warning(warning: bool, reason: String = "") -> void:
	_warning = warning
	if warning and not reason.is_empty():
		tooltip_text = reason
	elif not warning:
		tooltip_text = _clean_name
	_refresh_warning_text()

func set_disabled_state(disabled: bool, reason: String = "") -> void:
	self_modulate = Color(1, 1, 1, 0.45) if disabled else Color.WHITE
	if disabled and not reason.is_empty():
		tooltip_text = reason

func _refresh_warning_text() -> void:
	if _name_label == null:
		return
	var shown := UITokens.truncate(_clean_name, max_display_chars)
	if _warning:
		shown = "! " + shown
	_name_label.text = shown

func _apply_ui_scale() -> void:
	if _amount == null or _name_label == null:
		return
	var factor := _settings.ui_scale if _settings != null else 1.0
	_amount.add_theme_font_size_override("font_size", int(UITokens.scaled(float(_tokens.text_body), factor)))
	_name_label.add_theme_font_size_override("font_size", int(UITokens.scaled(float(_tokens.text_meta), factor)))

func _on_settings_changed(key: StringName) -> void:
	if key == GopalaUISettings.KEY_UI_SCALE:
		_apply_ui_scale()
