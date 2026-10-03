class_name GopalaStatusBadge
extends PanelContainer
## Severity badge: glyph + colour + text. Every severity carries a distinct
## glyph so state never depends on colour alone (UI_CONTRACT section 10).

@export var max_display_chars: int = 24

const SEVERITIES: Array[StringName] = [&"neutral", &"positive", &"warning", &"critical", &"disabled"]

var _tokens: UITokens = UITokens.new()
var _settings: GopalaUISettings
var _text_label: Label
var _severity: StringName = &"neutral"
var _clean_text: String = ""

## Shared severity mapping so alerts and badges cannot drift apart.
static func severity_style(severity: StringName) -> Dictionary:
	match severity:
		&"positive":
			return {"glyph": "+", "bg": GopalaTheme.FOREST_PALE, "fg": GopalaTheme.FOREST}
		&"warning":
			return {"glyph": "!", "bg": GopalaTheme.BRASS_PALE, "fg": GopalaTheme.BRASS_DARK}
		&"critical":
			return {"glyph": "\u00d7", "bg": GopalaTheme.TERRA_PALE, "fg": GopalaTheme.TERRA}
		&"disabled":
			return {"glyph": "\u2013", "bg": GopalaTheme.PAPER_SUNK, "fg": GopalaTheme.INK_FAINT}
	return {"glyph": "\u2022", "bg": GopalaTheme.PAPER_SUNK, "fg": GopalaTheme.INK}

func _ready() -> void:
	_settings = GopalaUISettings.settings()
	_text_label = get_node_or_null("Text") as Label
	if _text_label == null:
		push_error("GopalaStatusBadge: missing child 'Text' at %s" % get_path())
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.clip_text = true
	set_severity(&"neutral")
	_apply_ui_scale()
	if _settings != null and not _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.connect(_on_settings_changed)

func _exit_tree() -> void:
	if _settings != null and _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.disconnect(_on_settings_changed)

func set_severity(severity: StringName) -> void:
	if not SEVERITIES.has(severity):
		push_error("GopalaStatusBadge: unknown severity '%s'; use neutral/positive/warning/critical/disabled" % String(severity))
		severity = &"neutral"
	_severity = severity
	_restyle()
	_refresh_text()

func set_text(value: String) -> void:
	_clean_text = value
	_refresh_text()

func severity() -> StringName:
	return _severity

func _restyle() -> void:
	var style: Dictionary = severity_style(_severity)
	var border: Color = style["fg"]
	var box := GopalaTheme.flat(style["bg"], _tokens.radius_sm, _tokens.border_width, border,
		float(_tokens.space_2), float(_tokens.space_1))
	add_theme_stylebox_override("panel", box)

func _refresh_text() -> void:
	if _text_label == null:
		return
	var style: Dictionary = severity_style(_severity)
	var shown := UITokens.truncate(_clean_text, max_display_chars)
	_text_label.text = "%s %s" % [style["glyph"], shown] if not shown.is_empty() else String(style["glyph"])
	_text_label.add_theme_color_override("font_color", style["fg"])

func _apply_ui_scale() -> void:
	if _text_label == null:
		return
	var factor := _settings.ui_scale if _settings != null else 1.0
	_text_label.add_theme_font_size_override("font_size", int(UITokens.scaled(float(_tokens.text_meta), factor)))

func _on_settings_changed(key: StringName) -> void:
	if key == GopalaUISettings.KEY_UI_SCALE:
		_apply_ui_scale()
