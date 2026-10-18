class_name GopalaCollapsibleSection
extends VBoxContainer
## Reusable HUD section that keeps its labeled toggle visible while its body is folded.

signal collapsed_changed(collapsed: bool)

@export var title: String = "Section"
@export var collapsible: bool = true
@export var collapsed: bool = false

var _heading: HBoxContainer
var _title_label: Label
var _toggle: Button
var _content: VBoxContainer

func _ready() -> void:
	_heading = get_node_or_null("Header") as HBoxContainer
	_title_label = get_node_or_null("Header/Title") as Label
	_toggle = get_node_or_null("Header/Collapse") as Button
	_content = get_node_or_null("Content") as VBoxContainer
	if _heading == null or _title_label == null or _toggle == null or _content == null:
		push_error("GopalaCollapsibleSection: expected Header/Title, Header/Collapse and Content")
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", 7)
	_toggle.focus_mode = Control.FOCUS_ALL
	_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle.custom_minimum_size = Vector2(30, 30)
	_toggle.add_theme_stylebox_override("normal", GopalaTheme.flat(GopalaTheme.NAV_INSET, 7, 1, GopalaTheme.NAV_BORDER))
	_toggle.add_theme_stylebox_override("hover", GopalaTheme.flat(GopalaTheme.NAV_RAISED, 7, 1, GopalaTheme.BRASS))
	_toggle.add_theme_stylebox_override("pressed", GopalaTheme.flat(GopalaTheme.NAV_RAISED, 7, 1, GopalaTheme.BRASS))
	_toggle.add_theme_color_override("font_color", GopalaTheme.BRASS_LIGHT)
	_toggle.add_theme_font_size_override("font_size", 13)
	_toggle.toggle_mode = true
	_toggle.pressed.connect(_on_toggle_pressed)
	set_title(title)
	set_collapsible(collapsible)
	set_collapsed(collapsed, false)

func body() -> VBoxContainer:
	if _content == null:
		_content = get_node_or_null("Content") as VBoxContainer
	return _content

func header() -> HBoxContainer:
	if _heading == null:
		_heading = get_node_or_null("Header") as HBoxContainer
	return _heading

func title_label() -> Label:
	if _title_label == null:
		_title_label = get_node_or_null("Header/Title") as Label
	return _title_label

func add_header_control(control: Control) -> void:
	var header_row := header()
	if header_row == null or control == null:
		return
	header_row.add_child(control)
	header_row.move_child(control, maxi(0, header_row.get_child_count() - 2))

func set_title(value: String) -> void:
	title = value
	var label := title_label()
	if label != null:
		label.text = value
		label.tooltip_text = value

func set_collapsible(value: bool) -> void:
	collapsible = value
	var button := _toggle if _toggle != null else get_node_or_null("Header/Collapse") as Button
	if button != null:
		button.visible = value
		button.disabled = not value

func set_collapsed(value: bool, emit_signal: bool = true) -> void:
	var next := value if collapsible else false
	if collapsed == next and body() != null and body().visible == (not next):
		_refresh_toggle()
		return
	collapsed = next
	var content := body()
	if content != null:
		content.visible = not collapsed
	_refresh_toggle()
	if emit_signal:
		collapsed_changed.emit(collapsed)

func toggle() -> void:
	if collapsible:
		set_collapsed(not collapsed)

func _on_toggle_pressed() -> void:
	toggle()

func _refresh_toggle() -> void:
	var button := _toggle if _toggle != null else get_node_or_null("Header/Collapse") as Button
	if button == null:
		return
	button.set_pressed_no_signal(collapsed)
	button.text = "+" if collapsed else "−"
	button.accessibility_name = ("Expand " if collapsed else "Collapse ") + title
	button.tooltip_text = ("Expand " if collapsed else "Collapse ") + title
