class_name GopalaPanelShell
extends PanelContainer
## Generic panel surface wrapping a body container.
## Interactive shells stop the mouse so clicks inside panels never reach the
## world; decorative shells ignore it (UI_CONTRACT section 10).

@export var interactive: bool = true

var _tokens: UITokens = UITokens.new()
var _settings: GopalaUISettings
var _body_margin: MarginContainer
var _body: VBoxContainer

func _ready() -> void:
	_settings = GopalaUISettings.settings()
	_body_margin = get_node_or_null("BodyMargin") as MarginContainer
	_body = get_node_or_null("BodyMargin/Body") as VBoxContainer
	if _body_margin == null or _body == null:
		push_error("GopalaPanelShell: missing children (need BodyMargin > Body) at %s" % get_path())
		return
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_interactive(interactive)
	_apply_ui_scale()
	if _settings != null and not _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.connect(_on_settings_changed)

func _exit_tree() -> void:
	if _settings != null and _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.disconnect(_on_settings_changed)

func body() -> VBoxContainer:
	return _body

func set_interactive(interactive_shells: bool) -> void:
	interactive = interactive_shells
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE

func _apply_ui_scale() -> void:
	if _body_margin == null:
		return
	var factor := _settings.ui_scale if _settings != null else 1.0
	var side := int(UITokens.scaled(float(_tokens.space_4), factor))
	var vertical := int(UITokens.scaled(float(_tokens.space_3), factor))
	_body_margin.add_theme_constant_override("margin_left", side)
	_body_margin.add_theme_constant_override("margin_right", side)
	_body_margin.add_theme_constant_override("margin_top", vertical)
	_body_margin.add_theme_constant_override("margin_bottom", vertical)

func _on_settings_changed(key: StringName) -> void:
	if key == GopalaUISettings.KEY_UI_SCALE:
		_apply_ui_scale()
