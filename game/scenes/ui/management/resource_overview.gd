class_name GopalaResourceOverview
extends Window
## Read-only, catalogue-driven management panel. Quantities arrive from the HUD's
## snapshot binding; no timers, world references, or economic commands live here.

var _goods: Dictionary = {}
var _stock: Dictionary = {}
var _buttons: Dictionary = {}
var _buildings: Array[GopalaBuildingDefinition] = []
var _selected: StringName = &""
var _detail: RichTextLabel
var _list: VBoxContainer
var _filter: LineEdit
var _previous_focus: WeakRef

func _ready() -> void:
	# Own a bounded size with container layout inside the embedded window.
	wrap_controls = false
	min_size = Vector2i(600, 500)
	close_requested.connect(hide)
	window_input.connect(_on_window_input)
	about_to_popup.connect(_remember_focus)
	visibility_changed.connect(_restore_focus)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", GopalaTheme.flat(GopalaTheme.NAV_SURFACE, 4, 1, GopalaTheme.NAV_BORDER, 10, 10))
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "RESOURCES IN YOUR SETTLEMENT"
	heading.add_theme_color_override("font_color", GopalaTheme.BRASS_LIGHT)
	column.add_child(heading)
	var explanation := Label.new()
	explanation.text = "Live stock balance · select a good to see its construction uses"
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(explanation)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Find a resource…"
	_filter.accessibility_name = "Filter settlement resources"
	_filter.text_changed.connect(_apply_filter)
	column.add_child(_filter)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.custom_minimum_size.y = 130
	_detail.scroll_active = true
	column.add_child(_detail)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size.y = 32
	close.pressed.connect(hide)
	column.add_child(close)

func _on_window_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		hide()
		set_input_as_handled()

func configure(catalog: Dictionary, icons: Dictionary) -> void:
	for path in catalog.get("buildings", []):
		var building := load(path) as GopalaBuildingDefinition
		if building != null:
			_buildings.append(building)
	var group := ButtonGroup.new()
	for path in catalog.get("resources", []):
		var good := load(path) as GopalaResourceDefinition
		if good == null:
			continue
		_goods[good.id] = good
		var button := Button.new()
		button.name = "Stock_" + String(good.id)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size.y = 34
		button.add_theme_constant_override("icon_max_width", 18)
		button.expand_icon = true
		var icon_path: String = icons.get(good.id, "")
		button.icon = load(icon_path) if ResourceLoader.exists(icon_path) else good.icon
		button.pressed.connect(select_resource.bind(good.id))
		_list.add_child(button)
		_buttons[good.id] = button
		set_stock(good.id, 0)

func set_stock(id: StringName, amount: int) -> void:
	if not _goods.has(id) or (_stock.has(id) and int(_stock[id]) == amount):
		return
	_stock[id] = amount
	var good: GopalaResourceDefinition = _goods[id]
	var button: Button = _buttons[id]
	button.text = "%s     %d" % [good.display_name, amount]
	button.accessibility_name = "%s: %d units" % [good.display_name, amount]
	button.tooltip_text = "%s · %d units in the live settlement balance" % [good.display_name, amount]
	if _selected == id:
		_refresh_detail()

func select_resource(id: StringName) -> void:
	if not _goods.has(id):
		return
	_selected = id
	_filter.clear()
	_apply_filter("")
	(_buttons[id] as Button).set_pressed_no_signal(true)
	_refresh_detail()

func _refresh_detail() -> void:
	var good: GopalaResourceDefinition = _goods[_selected]
	var uses := PackedStringArray()
	for building in _buildings:
		if building.costs.has(_selected):
			uses.append("%s (%d)" % [building.display_name, building.costs[_selected]])
	_detail.text = "[b]%s[/b]   %d units\nCarry capacity: %d units per trip\n\n[b]Construction uses[/b]\n%s" % [
		good.display_name, int(_stock.get(_selected, 0)), good.carry_units,
		", ".join(uses) if not uses.is_empty() else "No construction cost in the current catalogue."]

func _apply_filter(query: String) -> void:
	for id in _buttons:
		(_buttons[id] as Button).visible = query.strip_edges().is_empty() or (_goods[id] as GopalaResourceDefinition).display_name.to_lower().contains(query.strip_edges().to_lower())

func _remember_focus() -> void:
	var control := get_parent().get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(control) if control != null else null
	_filter.call_deferred("grab_focus")

func _restore_focus() -> void:
	if visible or _previous_focus == null:
		return
	var control := _previous_focus.get_ref() as Control
	if is_instance_valid(control) and control.is_visible_in_tree():
		control.grab_focus()
