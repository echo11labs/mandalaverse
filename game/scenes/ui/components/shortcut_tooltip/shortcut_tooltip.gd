class_name GopalaShortcutTooltip
extends PanelContainer
## Visual shortcut hint: keycap + action label + optional description line.
## Reuses the ShortcutTooltip InputMap formatter, so the shown binding always
## matches the live binding - never a hard-coded key label
## (UI_CONTRACT.md section 10). The root stops mouse input so world clicks
## cannot leak through, while every decorative child ignores it outright.

@export var action: StringName = &""
@export var base_label: String = ""
@export var description: String = ""
@export var max_display_chars: int = 24
@export var max_description_chars: int = 60
## Keyboard-focus state: off for passive hints, on for hints that participate
## in the focus path (gallery demonstrates both).
@export var focusable: bool = false

## Shown in the keycap when the action has no resolvable binding, so the
## unbound state is a glyph difference, never colour alone.
const UNBOUND_GLYPH: String = "?"

var _tokens: UITokens = UITokens.new()
var _settings: GopalaUISettings
var _body: VBoxContainer
var _row: HBoxContainer
var _keycap: PanelContainer
var _keycap_text: Label
var _label: Label
var _description: Label
var _disabled: bool = false
var _disabled_reason: String = ""

func _ready() -> void:
	_settings = GopalaUISettings.settings()
	_body = get_node_or_null("Body") as VBoxContainer
	_row = get_node_or_null("Body/Row") as HBoxContainer
	_keycap = get_node_or_null("Body/Row/Keycap") as PanelContainer
	_keycap_text = get_node_or_null("Body/Row/Keycap/KeycapText") as Label
	_label = get_node_or_null("Body/Row/Label") as Label
	_description = get_node_or_null("Body/Description") as Label
	if _body == null or _row == null or _keycap == null or _keycap_text == null \
			or _label == null or _description == null:
		push_error("GopalaShortcutTooltip: missing children (need Body > Row > Keycap > KeycapText, Body > Row > Label, Body > Description) at %s" % get_path())
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	for child in [_body, _row, _keycap, _keycap_text, _label, _description]:
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keycap_text.clip_text = true
	_label.clip_text = true
	_description.clip_text = true
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_focusable(focusable)
	refresh()
	_apply_ui_scale()
	_restyle_root()
	if _settings != null and not _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.connect(_on_settings_changed)

func _exit_tree() -> void:
	if _settings != null and _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.disconnect(_on_settings_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		if is_node_ready():
			_restyle_root()

## Switches the bound action and re-derives the keycap from InputMap.
func set_action(value: StringName) -> void:
	action = value
	refresh()

func set_label(value: String) -> void:
	base_label = value
	refresh()

func set_description(value: String) -> void:
	description = value
	if _description != null:
		_description.text = UITokens.truncate(value, max_description_chars)
		_description.visible = not value.is_empty()
	refresh()

func set_focusable(value: bool) -> void:
	focusable = value
	focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE

## Disabled state dims the hint and forces the reason into the tooltip.
func set_disabled_state(disabled: bool, reason: String = "") -> void:
	_disabled = disabled
	_disabled_reason = reason if disabled else ""
	self_modulate = Color(1, 1, 1, 0.45) if disabled else Color.WHITE
	refresh()

## Re-derives keycap, label and tooltip from the live InputMap binding.
func refresh() -> void:
	if _keycap == null or _keycap_text == null or _label == null:
		return
	var binding := ShortcutTooltip.binding_text(action)
	_keycap_text.text = binding if not binding.is_empty() else UNBOUND_GLYPH
	_restyle_keycap(not binding.is_empty())
	_label.text = UITokens.truncate(base_label, max_display_chars)
	_label.tooltip_text = base_label
	var lines := ShortcutTooltip.compose(base_label, action, description)
	if _disabled and not _disabled_reason.is_empty():
		lines = lines + "\n" + _disabled_reason
	tooltip_text = lines
	if _description != null:
		_description.text = UITokens.truncate(description, max_description_chars)
		_description.visible = not description.is_empty()

func _restyle_keycap(bound: bool) -> void:
	var border := GopalaTheme.BRASS_DARK if bound else GopalaTheme.INK_FAINT
	var bg := GopalaTheme.BRASS_PALE if bound else GopalaTheme.PAPER_SUNK
	_keycap.add_theme_stylebox_override("panel",
		GopalaTheme.flat(bg, _tokens.radius_sm, _tokens.border_width, border,
			_tokens.space_1, _tokens.space_1))

func _restyle_root() -> void:
	var border := GopalaTheme.BRASS_DARK if has_focus() else GopalaTheme.INK_FAINT
	add_theme_stylebox_override("panel",
		GopalaTheme.flat(GopalaTheme.PAPER, _tokens.radius_md, _tokens.border_width, border,
			_tokens.space_2, _tokens.space_1))

func _apply_ui_scale() -> void:
	if _label == null or _keycap_text == null or _description == null:
		return
	var factor := _settings.ui_scale if _settings != null else 1.0
	_keycap_text.add_theme_font_size_override("font_size",
		int(UITokens.scaled(float(_tokens.text_meta), factor)))
	var body_size := int(UITokens.scaled(float(_tokens.text_body), factor))
	_label.add_theme_font_size_override("font_size", body_size)
	_description.add_theme_font_size_override("font_size", body_size)
	custom_minimum_size.y = UITokens.scaled(float(_tokens.control_height_sm), factor)

func _on_settings_changed(key: StringName) -> void:
	if key == GopalaUISettings.KEY_UI_SCALE:
		_apply_ui_scale()
