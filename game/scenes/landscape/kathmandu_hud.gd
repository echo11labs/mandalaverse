class_name GopalaKathmanduHud
extends CanvasLayer
## Editorial-warm management interface for the Kathmandu valley scene.
## Built in code from GopalaTheme so the running game and the editor agree.
## Public surface is kept compatible with kathmandu_valley.gd.

signal valley_requested
signal source_requested
signal camp_requested
signal grid_changed(on: bool)
signal names_changed(on: bool)
signal zoom_in_requested
signal zoom_out_requested
signal turn_left_requested
signal turn_right_requested
signal build_selected(id: StringName)
signal speed_selected(multiplier: int)

const MODE_HINTS := {
	"Wash": "Territory wash — click any ground to read the chiefdom holding it.",
	"Survey": "Territory survey — frontiers dashed, seats ringed, ridges and rivers are the borders.",
}
const TOAST_LIFETIME := 4.2
const INK_SCRIM := Color(0.11, 0.09, 0.06, 0.93)

var terrain: GopalaKathmanduTerrain
var territory_mode := "Off"

var _root: Control
var _settlement_name: Label
var _season_line: Label
var _clock_line: Label
var _resource_slots: Dictionary = {}
var _minimap: GopalaMinimap
var _inspection: PanelContainer
var _inspect_title: Label
var _inspect_detail: Label
var _inspect_eyebrow: Label
var _inspect_body: RichTextLabel
var _build_card: PanelContainer
var _build_title: Label
var _build_meta: Label
var _build_costs: Label
var _tab_buttons: Array[Button] = []
var _build_entries: Array[Dictionary] = []
var _active_category := "All"
var _toast_stack: VBoxContainer
var _grid_button: Button
var _names_button: Button
var _speed_buttons: Array[Button] = []
var _selected_build := StringName("")
var _placement_active := false
var _last_place_stamp := 0

func _ready() -> void:
	layer = 2
	_build_root()
	_build_top_bar()
	_build_status_card()
	_build_inspection_panel()
	_build_build_bar()
	_build_view_tools()
	_build_toasts()
	_reveal_staggered()

# ---------------------------------------------------------------- scaffolding

func _build_root() -> void:
	_root = Control.new()
	_root.name = "Interface"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# CanvasLayer has no theme of its own, so the interface root carries it and
	# every plate, label and button inherits from there.
	_root.theme = GopalaTheme.build()
	add_child(_root)

func _panel(style: StringName, margin := 0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(style))
	if margin > 0:
		var box := MarginContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "top", "bottom"]:
			box.add_theme_constant_override("margin_" + side, margin)
		panel.add_child(box)
	return panel

func _style(style: StringName) -> StyleBox:
	match style:
		&"shell": return GopalaTheme.lifted(GopalaTheme.flat(Color(0, 0, 0, 0), 18), 0.06, 8, 24)
		&"ink": return GopalaTheme.flat(INK_SCRIM, 16, 1, GopalaTheme.BRASS)
		&"paper": return GopalaTheme.flat(GopalaTheme.PAPER, 13, 1, GopalaTheme.BRASS_LIGHT)
		&"paper_raised": return GopalaTheme.flat(GopalaTheme.PAPER_RAISED, 13, 1, GopalaTheme.INK_FAINT)
		&"sunk": return GopalaTheme.flat(GopalaTheme.PAPER_SUNK, 11, 1, GopalaTheme.INK_FAINT)
		&"brass": return GopalaTheme.flat(GopalaTheme.BRASS, 10)
		&"forest": return GopalaTheme.flat(GopalaTheme.FOREST_PALE, 9, 1, GopalaTheme.FOREST)
		&"river": return GopalaTheme.flat(GopalaTheme.RIVER_PALE, 9, 1, GopalaTheme.RIVER)
		&"terra": return GopalaTheme.flat(GopalaTheme.TERRA_PALE, 9, 1, GopalaTheme.TERRA)
	return GopalaTheme.flat(GopalaTheme.PAPER, 12)

func _column(separation := 0) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	return box

func _row(separation := 0) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	return box

func _label(text_value: String, font: Font, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _eyebrow(text_value: String) -> Label:
	var label := _label(text_value.to_upper(), GopalaTheme.font(GopalaTheme.FONT_UI, 600, 10), 10, GopalaTheme.BRASS_DARK)
	label.add_theme_constant_override("line_spacing", 0)
	return label

func _rule(color := GopalaTheme.INK_FAINT, alpha := 0.35) -> HSeparator:
	var line := StyleBoxLine.new()
	line.color = Color(color.r, color.g, color.b, alpha)
	line.thickness = 1
	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	separator.add_theme_stylebox_override("separator", line)
	return separator

func _spacer() -> Control:
	var control := Control.new()
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return control

func _icon(texture: Texture2D, side: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.custom_minimum_size = Vector2(side, side)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect

## Square icon-only control used by the map view tools.
func _tool_button(label_text: String, tooltip: String, glyph: String) -> Button:
	var button := Button.new()
	button.text = glyph
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(38, 38)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", _style(&"paper_raised"))
	button.add_theme_stylebox_override("hover", GopalaTheme.flat(GopalaTheme.PAPER_RAISED, 10, 1, GopalaTheme.BRASS_DARK))
	button.add_theme_stylebox_override("pressed", GopalaTheme.flat(GopalaTheme.PAPER_DEEP, 10, 1, GopalaTheme.BRASS))
	button.add_theme_stylebox_override("hover_pressed", GopalaTheme.flat(GopalaTheme.PAPER_DEEP, 10, 1, GopalaTheme.BRASS))
	button.add_theme_stylebox_override("focus", GopalaTheme.flat(Color(0, 0, 0, 0), 10))
	button.add_theme_stylebox_override("disabled", GopalaTheme.flat(GopalaTheme.PAPER_SUNK, 10, 1, GopalaTheme.INK_FAINT))
	return button

## Staggered entrance so the interface assembles instead of appearing at once.
func _reveal_staggered() -> void:
	var groups := []
	_collect_reveal(_root, groups)
	var index := 0
	for node in groups:
		node.modulate.a = 0.0
		if node is Control:
			var control: Control = node
			var target := control.position
			control.position = target + Vector2(0, 10)
			var tween := create_tween()
			tween.set_parallel(true)
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(control, "modulate:a", 1.0, 0.5).set_delay(0.03 * index)
			tween.tween_property(control, "position", target, 0.5).set_delay(0.03 * index)
		else:
			var tween := create_tween()
			tween.tween_property(node, "modulate:a", 1.0, 0.5).set_delay(0.03 * index)
		index += 1

func _collect_reveal(node: Node, into: Array) -> void:
	# Only the HUD's own groups are animated. Descending into containers would
	# fight their layout, because a container re-sorts its children every frame.
	for child in node.get_children():
		if child is Control and child.visible:
			into.append(child)

# ------------------------------------------------------------------- top bar

func _build_top_bar() -> void:
	var shell := _panel(&"shell")
	shell.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shell.offset_left = 16.0
	shell.offset_right = -16.0
	shell.offset_top = 12.0
	shell.offset_bottom = 12.0 + 92.0
	_root.add_child(shell)

	var plate := _panel(&"ink")
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.add_child(plate)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	plate.add_child(margin)

	var row := _row(18)
	margin.add_child(row)

	# Identity: crest, wordmark, and the settlement's own name.
	var identity := _column(1)
	identity.custom_minimum_size.x = 236
	row.add_child(identity)

	var crest := TextureRect.new()
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest.custom_minimum_size = Vector2(58, 58)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var crest_path := "res://assets/ui/theme/crest.png"
	if ResourceLoader.exists(crest_path):
		crest.texture = load(crest_path)
	identity.add_child(crest)

	var words := _column(0)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(words)
	words.add_child(_eyebrow("Gopala · dawn of the valley"))
	_settlement_name = _label("Dudhkunda", GopalaTheme.font(GopalaTheme.FONT_DISPLAY, 600, 26), 26, GopalaTheme.PAPER)
	words.add_child(_settlement_name)

	# Resource rail: tabular counts that never jitter as the simulation runs.
	var rail := _row(6)
	rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rail)
	_reload_resources(rail)

	row.add_child(_spacer())

	# Clock plate: season, day, and the survey toggle.
	var clock := _column(1)
	clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clock.custom_minimum_size.x = 150
	row.add_child(clock)
	clock.add_child(_eyebrow("Calendar"))
	_season_line = _label("Spring", GopalaTheme.font(GopalaTheme.FONT_DISPLAY, 500, 19), 19, GopalaTheme.BRASS_LIGHT)
	clock.add_child(_season_line)
	_clock_line = _label("Day 1 · Year 1", GopalaTheme.font(GopalaTheme.FONT_UI, 400, 12), 12, Color(GopalaTheme.PAPER.r, GopalaTheme.PAPER.g, GopalaTheme.PAPER.b, 0.62))
	clock.add_child(_clock_line)

	row.add_child(_rule())

	# Survey plate: schematic map of the same geography as the 3D scene.
	var survey := _panel(&"ink_bare")
	survey.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	survey.custom_minimum_size = Vector2(84, 84)
	row.add_child(survey)
	_minimap = GopalaMinimap.new()
	_minimap.custom_minimum_size = Vector2(84, 84)
	survey.add_child(_minimap)

## Seven P0 goods, each with a plate and a mono count.
func _reload_resources(rail: HBoxContainer) -> void:
	for child in rail.get_children():
		child.queue_free()
	_resource_slots.clear()
	var catalog := _catalog()
	for path in catalog.get("resources", []):
		var good := load(path) as GopalaResourceDefinition
		if good == null:
			continue
		rail.add_child(_resource_slot(good))

func _resource_slot(good: GopalaResourceDefinition) -> Control:
	var shell := _panel(&"ink_bare")
	shell.tooltip_text = "%s · carries %d at a time" % [good.display_name, good.carry_units]
	var inner := _column(0)
	shell.add_child(inner)
	var head := _row(5)
	inner.add_child(head)
	if good.icon != null:
		head.add_child(_icon(good.icon, 20))
	var amount := _label("0", GopalaTheme.font(GopalaTheme.FONT_MONO, 500, 16), 16, GopalaTheme.PAPER)
	head.add_child(amount)
	var name_line := _label(good.display_name.to_upper(), GopalaTheme.font(GopalaTheme.FONT_UI, 600, 9), 9, Color(GopalaTheme.BRASS.r, GopalaTheme.BRASS.g, GopalaTheme.BRASS.b, 0.75))
	inner.add_child(name_line)
	_resource_slots[good.id] = amount
	return shell

# ------------------------------------------------------------- status card

func _build_status_card() -> void:
	var shell := _panel(&"shell")
	shell.set_anchors_preset(Control.PRESET_TOP_LEFT)
	shell.offset_left = 16.0
	shell.offset_top = 116.0
	shell.offset_right = 16.0 + 236.0
	shell.offset_bottom = 116.0 + 172.0
	_root.add_child(shell)

	var plate := _panel(&"paper")
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.add_child(plate)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	plate.add_child(margin)

	var column := _column(7)
	margin.add_child(column)
	column.add_child(_eyebrow("Valley survey"))
	column.add_child(_rule(GopalaTheme.BRASS, 0.4))
	column.add_child(_label("Kathmandu valley", GopalaTheme.font(GopalaTheme.FONT_DISPLAY, 500, 20), 20, GopalaTheme.INK))

	var scale_note := _label("40 km across · 1200 m base", GopalaTheme.font(GopalaTheme.FONT_UI, 400, 12), 12, GopalaTheme.INK_MUTED)
	column.add_child(scale_note)
	column.add_child(_rule())

	# Actions that used to live as loose keyboard-only shortcuts.
	var actions := _row(6)
	column.add_child(actions)
	_grid_button = _tool_button("", "Planning grid (G)", "▦")
	_grid_button.toggle_mode = true
	_grid_button.toggled.connect(func(on: bool) -> void: grid_changed.emit(on))
	actions.add_child(_grid_button)
	_names_button = _tool_button("", "Place names (N)", "Aa")
	_names_button.toggle_mode = true
	_names_button.toggled.connect(func(on: bool) -> void: names_changed.emit(on))
	actions.add_child(_names_button)
	var territory := _tool_button("", "Chiefdom survey (F)", "◈")
	actions.add_child(territory)

	var valley := _tool_button("", "Whole valley", "⌖")
	valley.pressed.connect(func() -> void: valley_requested.emit())
	actions.add_child(valley)
	var source := _tool_button("", "Bagmati source", "⌖")
	source.pressed.connect(func() -> void: source_requested.emit())
	actions.add_child(source)
	var camp := _tool_button("", "Local ground", "⌂")
	camp.pressed.connect(func() -> void: camp_requested.emit())
	actions.add_child(camp)

	# Time controls, present from the start so speed is never a hidden feature.
	var speed_row := _row(6)
	column.add_child(speed_row)
	speed_row.add_child(_eyebrow("Tempo"))
	var pause := _tool_button("", "Pause (Space)", "❚❚")
	pause.toggle_mode = true
	pause.toggled.connect(func(on: bool) -> void: speed_selected.emit(0 if on else 1))
	speed_row.add_child(pause)
	for multiplier in [1, 2, 4]:
		var button := Button.new()
		button.text = "%d×" % multiplier
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(40, 30)
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_stylebox_override("normal", _style(&"paper_raised"))
		button.add_theme_stylebox_override("hover", GopalaTheme.flat(GopalaTheme.PAPER_RAISED, 10, 1, GopalaTheme.BRASS_DARK))
		button.add_theme_stylebox_override("pressed", GopalaTheme.flat(GopalaTheme.BRASS, 10))
		button.add_theme_stylebox_override("hover_pressed", GopalaTheme.flat(GopalaTheme.BRASS_DARK, 10))
		button.add_theme_stylebox_override("focus", GopalaTheme.flat(Color(0, 0, 0, 0), 10))
		button.toggled.connect(func(on: bool) -> void: speed_selected.emit(multiplier if on else 0))
		speed_row.add_child(button)
		_speed_buttons.append(button)
	_speed_buttons[0].button_pressed = true

# -------------------------------------------------------- inspection panel

func _build_inspection_panel() -> void:
	var shell := _panel(&"shell")
	shell.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	shell.offset_right = -16.0
	shell.offset_top = 116.0
	shell.offset_left = -16.0 - 340.0
	shell.offset_bottom = 116.0 + 396.0
	shell.visible = false
	_root.add_child(shell)

	_inspection = _panel(&"ink")
	_inspection.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.add_child(_inspection)
	_inspect_body = null
	shell.name = "InspectionShell"

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_inspection.add_child(margin)

	var column := _column(6)
	margin.add_child(column)

	# PanelContainer stretches every child, so the close control belongs in the
	# header row rather than floating over the plate.
	var header := _row(8)
	column.add_child(header)
	_inspect_eyebrow = _eyebrow("Inspection")
	_inspect_eyebrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_inspect_eyebrow)
	header.add_child(_spacer())
	var close := _tool_button("", "Close (Esc)", "✕")
	close.custom_minimum_size = Vector2(30, 30)
	close.pressed.connect(hide_inspection)
	header.add_child(close)

	_inspect_title = _label("", GopalaTheme.font(GopalaTheme.FONT_DISPLAY, 600, 24), 24, GopalaTheme.PAPER)
	column.add_child(_inspect_title)
	column.add_child(_rule(GopalaTheme.BRASS, 0.45))
	_inspect_detail = _label("", GopalaTheme.font(GopalaTheme.FONT_UI, 400, 13), 13, GopalaTheme.BRASS_LIGHT)
	column.add_child(_inspect_detail)
	column.add_child(_rule())

	_inspect_body = RichTextLabel.new()
	_inspect_body.bbcode_enabled = true
	_inspect_body.fit_content = true
	_inspect_body.scroll_active = false
	_inspect_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inspect_body.add_theme_font_override("body", GopalaTheme.font(GopalaTheme.FONT_UI, 400, 13))
	_inspect_body.add_theme_font_size_override("body_font_size", 13)
	_inspect_body.add_theme_font_override("data", GopalaTheme.font(GopalaTheme.FONT_MONO, 400, 12))
	_inspect_body.add_theme_color_override("default_color", Color(GopalaTheme.PAPER.r, GopalaTheme.PAPER.g, GopalaTheme.PAPER.b, 0.78))
	column.add_child(_inspect_body)

# -------------------------------------------------------------- build bar

func _build_build_bar() -> void:
	var shell := _panel(&"shell")
	shell.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shell.offset_left = 16.0
	shell.offset_right = -16.0
	shell.offset_top = -214.0
	shell.offset_bottom = -16.0
	_root.add_child(shell)

	var plate := _panel(&"paper")
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.add_child(plate)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	plate.add_child(margin)

	var column := _column(10)
	margin.add_child(column)

	# Detail plate for the highlighted structure.
	_build_card = _panel(&"sunk")
	column.add_child(_build_card)
	var card_margin := MarginContainer.new()
	card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		card_margin.add_theme_constant_override("margin_" + side, 14)
	card_margin.add_theme_constant_override("margin_top", 10)
	card_margin.add_theme_constant_override("margin_bottom", 10)
	_build_card.add_child(card_margin)
	var card_row := _row(14)
	card_margin.add_child(card_row)
	var card_text := _column(1)
	card_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_row.add_child(card_text)
	_build_title = _label("Choose a structure", GopalaTheme.font(GopalaTheme.FONT_DISPLAY, 500, 18), 18, GopalaTheme.INK)
	card_text.add_child(_build_title)
	_build_meta = _label("Six P0 structures. Costs are drawn from the content catalogue.", GopalaTheme.font(GopalaTheme.FONT_UI, 400, 12), 12, GopalaTheme.INK_MUTED)
	card_text.add_child(_build_meta)
	_build_costs = _label("", GopalaTheme.font(GopalaTheme.FONT_MONO, 500, 12), 12, GopalaTheme.BRASS_DARK)
	_build_costs.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_build_costs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_row.add_child(_build_costs)

	# Category tabs, then the row of placeable structures.
	var tabs := _row(4)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(tabs)
	for category in ["All", "Housing", "Storage", "Resources", "Food", "Water", "Pasture"]:
		var button := Button.new()
		button.text = category
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_stylebox_override("normal", _style(&"tab_normal"))
		button.add_theme_stylebox_override("hover", _style(&"tab_hover"))
		button.add_theme_stylebox_override("pressed", _style(&"tab_active"))
		button.add_theme_stylebox_override("focus", GopalaTheme.flat(Color(0, 0, 0, 0), 8))
		button.add_theme_color_override("font_color", GopalaTheme.INK_MUTED)
		button.add_theme_color_override("font_hover_color", GopalaTheme.INK)
		button.add_theme_color_override("font_pressed_color", GopalaTheme.BRASS_DARK)
		button.toggled.connect(func(on: bool) -> void: _select_category(category, on))
		tabs.add_child(button)
		_tab_buttons.append(button)
	_tab_buttons[0].button_pressed = true

	var strip := _row(8)
	strip.name = "StructureStrip"
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(strip)
	_populate_structures(strip)

func _populate_structures(strip: HBoxContainer) -> void:
	_build_entries.clear()
	var catalog := _catalog()
	for path in catalog.get("buildings", []):
		var definition := load(path) as GopalaBuildingDefinition
		if definition == null:
			continue
		var entry := {
			"definition": definition,
			"category": _category_for(definition.id),
			"button": _structure_button(definition),
		}
		_build_entries.append(entry)
		strip.add_child(entry["button"])
	for zone_path in catalog.get("zones", []):
		var zone := load(zone_path) as GopalaZoneDefinition
		if zone == null:
			continue
		var entry := {
			"definition": zone,
			"category": "Pasture",
			"button": _zone_button(zone),
		}
		_build_entries.append(entry)
		strip.add_child(entry["button"])
	_refresh_strip()

## Group the six P0 structures by the job a player thinks in, not by data order.
func _category_for(id: StringName) -> String:
	match id:
		&"dwelling": return "Housing"
		&"stockpile": return "Storage"
		&"timber_camp", &"gatherer_shelter": return "Resources"
		&"water_point": return "Water"
	return "All"

func _structure_button(definition: GopalaBuildingDefinition) -> Button:
	var button := Button.new()
	button.text = definition.display_name
	button.tooltip_text = "%s\nFootprint %d × %d · %d work\n%s" % [
		definition.display_name,
		definition.footprint.x, definition.footprint.y,
		definition.work_ticks,
		_cost_text(definition.costs),
	]
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(132, 40)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _style(&"paper_raised"))
	button.add_theme_stylebox_override("hover", GopalaTheme.flat(GopalaTheme.PAPER_RAISED, 10, 1, GopalaTheme.BRASS_DARK))
	button.add_theme_stylebox_override("pressed", GopalaTheme.flat(GopalaTheme.BRASS, 10))
	button.add_theme_stylebox_override("hover_pressed", GopalaTheme.flat(GopalaTheme.BRASS_DARK, 10))
	button.add_theme_stylebox_override("focus", GopalaTheme.flat(Color(0, 0, 0, 0), 10))
	if definition.prototype_sprite != null:
		button.icon = definition.prototype_sprite
		button.expand_icon = true
	button.toggled.connect(func(on: bool) -> void:
		if on:
			_choose_build(definition.id, definition.display_name, "%d × %d footprint · %d work" % [definition.footprint.x, definition.footprint.y, definition.work_ticks], _cost_text(definition.costs))
		elif _selected_build == definition.id:
			clear_build()
	)
	return button

func _zone_button(zone: GopalaZoneDefinition) -> Button:
	var button := Button.new()
	button.text = zone.display_name
	button.tooltip_text = "%s\nZone · at least %d cells" % [zone.display_name, zone.minimum_cells]
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(132, 40)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _style(&"paper_raised"))
	button.add_theme_stylebox_override("hover", GopalaTheme.flat(GopalaTheme.PAPER_RAISED, 10, 1, GopalaTheme.BRASS_DARK))
	button.add_theme_stylebox_override("pressed", GopalaTheme.flat(GopalaTheme.BRASS, 10))
	button.add_theme_stylebox_override("hover_pressed", GopalaTheme.flat(GopalaTheme.BRASS_DARK, 10))
	button.add_theme_stylebox_override("focus", GopalaTheme.flat(Color(0, 0, 0, 0), 10))
	button.toggled.connect(func(on: bool) -> void:
		if on:
			_choose_build(zone.id, zone.display_name, "Zone · at least %d cells" % zone.minimum_cells, "")
		elif _selected_build == zone.id:
			clear_build()
	)
	return button

func _select_category(category: String, on: bool) -> void:
	if not on:
		return
	_active_category = category
	_refresh_strip()

## Strip control for a catalogue entry, used by the build bar and its tests.
func button_for(id: StringName) -> Button:
	for entry in _build_entries:
		var definition: Resource = entry["definition"]
		if definition != null and definition.get("id") == id:
			return entry["button"]
	return null

func _refresh_strip() -> void:
	for entry in _build_entries:
		var shown: bool = entry["category"] == _active_category or _active_category == "All"
		var button: Button = entry["button"]
		button.visible = shown
		if not shown and button.button_pressed:
			button.set_pressed_no_signal(false)

func _choose_build(id: StringName, title: String, meta: String, costs: String) -> void:
	_selected_build = id
	_placement_active = true
	_build_title.text = title
	_build_meta.text = meta
	_build_costs.text = costs
	_build_card.add_theme_stylebox_override("panel", _style(&"sunk"))
	build_selected.emit(id)

func clear_build() -> void:
	_selected_build = StringName("")
	_placement_active = false
	_build_title.text = "Choose a structure"
	_build_meta.text = "Six P0 structures. Costs are drawn from the content catalogue."
	_build_costs.text = ""
	for entry in _build_entries:
		var button: Button = entry["button"]
		if button.button_pressed:
			button.set_pressed_no_signal(false)

func _cost_text(costs: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in costs.keys():
		parts.append("%s %d" % [String(key), int(costs[key])])
	parts.sort()
	return "  ·  ".join(parts)

# -------------------------------------------------------------- view tools

func _build_view_tools() -> void:
	var shell := _panel(&"shell")
	shell.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	shell.offset_right = -16.0
	shell.offset_bottom = -16.0
	shell.offset_left = -16.0 - 232.0
	shell.offset_top = -16.0 - 44.0
	_root.add_child(shell)

	var plate := _panel(&"paper")
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.add_child(plate)

	var row := _row(5)
	plate.add_child(row)
	var tools := [
		["−", "Zoom out", func() -> void: zoom_out_requested.emit()],
		["+", "Zoom in", func() -> void: zoom_in_requested.emit()],
		["↺", "Turn left", func() -> void: turn_left_requested.emit()],
		["↻", "Turn right", func() -> void: turn_right_requested.emit()],
	]
	for tool in tools:
		var button := _tool_button("", String(tool[1]), String(tool[0]))
		if String(tool[0]) == "−":
			button.pressed.connect(func() -> void: zoom_out_requested.emit())
		elif String(tool[0]) == "+":
			button.pressed.connect(func() -> void: zoom_in_requested.emit())
		elif String(tool[0]) == "↺":
			button.pressed.connect(func() -> void: turn_left_requested.emit())
		else:
			button.pressed.connect(func() -> void: turn_right_requested.emit())
		row.add_child(button)
	var hint := _label("Esc cancels placement", GopalaTheme.font(GopalaTheme.FONT_UI, 400, 12), 12, GopalaTheme.INK_MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hint)

# ------------------------------------------------------------------ toasts

func _build_toasts() -> void:
	_toast_stack = VBoxContainer.new()
	_toast_stack.name = "ToastStack"
	_toast_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_stack.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_toast_stack.offset_left = 16.0
	_toast_stack.offset_bottom = -16.0
	_toast_stack.alignment = BoxContainer.ALIGNMENT_END
	_toast_stack.add_theme_constant_override("separation", 8)
	_root.add_child(_toast_stack)

func notify(title: String, body: String, tone: String = "river") -> void:
	if _toast_stack == null:
		return
	var style := &"river"
	match tone:
		"forest": style = &"forest"
		"terra": style = &"terra"
	var shell := _panel(&"shell")
	shell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_toast_stack.add_child(shell)
	var plate := _panel(style)
	plate.custom_minimum_size.x = 268
	shell.add_child(plate)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	plate.add_child(margin)
	var column := _column(1)
	margin.add_child(column)
	column.add_child(_label(title, GopalaTheme.font(GopalaTheme.FONT_DISPLAY, 500, 16), 16, GopalaTheme.INK))
	if not body.is_empty():
		column.add_child(_label(body, GopalaTheme.font(GopalaTheme.FONT_UI, 400, 12), 12, GopalaTheme.INK_MUTED))

	shell.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(shell, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(TOAST_LIFETIME)
	tween.tween_property(shell, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(shell.queue_free)

# ------------------------------------------------------------ public surface

func follow(camera: Camera3D) -> void:
	if camera == null or _minimap == null:
		return
	_minimap.set_view(camera.global_position, float(camera.size))

func close_build() -> void:
	if _placement_active:
		clear_build()
	hide_inspection()

func set_grid(on: bool) -> void:
	if _grid_button != null and _grid_button.button_pressed != on:
		_grid_button.set_pressed_no_signal(on)

func set_names(on: bool) -> void:
	if _names_button != null and _names_button.button_pressed != on:
		_names_button.set_pressed_no_signal(on)

## Keyboard shortcuts route through the buttons so the plate and the world never
## disagree about whether the grid or the labels are showing.
func toggle_grid() -> void:
	if _grid_button != null:
		_grid_button.button_pressed = not _grid_button.button_pressed

func toggle_names() -> void:
	if _names_button != null:
		_names_button.button_pressed = not _names_button.button_pressed

func set_resource(id: StringName, amount: int) -> void:
	if _resource_slots.has(id):
		(_resource_slots[id] as Label).text = str(amount)

func set_clock(day: int, year: int, season: String) -> void:
	if _clock_line != null:
		_clock_line.text = "Day %d · Year %d" % [day, year]
	if _season_line != null:
		_season_line.text = season

func set_settlement_name(value: String) -> void:
	if _settlement_name != null:
		_settlement_name.text = value

## Ground inspection: the readout the player gets from a plain terrain click.
func show_place(title_text: String, detail: String) -> void:
	var stamp := Time.get_ticks_msec()
	if stamp - _last_place_stamp < 40 and title_text.is_empty():
		return
	_last_place_stamp = stamp
	_show_inspection("Ground", title_text, detail, "")

func show_territory(mode_name: String, _survey: bool, chiefdoms: Array) -> void:
	territory_mode = mode_name
	if _minimap != null:
		_minimap.set_territory(mode_name)
	if mode_name == "Off":
		hide_inspection()
		return
	var lines := PackedStringArray()
	for chiefdom in chiefdoms:
		if chiefdom is Dictionary:
			lines.append("[b]%s[/b]  %s" % [String(chiefdom.get("name", "")), String(chiefdom.get("modern", ""))])
	_show_inspection(
		"Chiefdoms",
		"Four tributary domains",
		String(MODE_HINTS.get(mode_name, "")),
		"\n".join(lines) + "\n[i]Jurisdiction lines are a reconstruction from drainage and relief. No Gopal-period frontier is attested.[/i]",
	)

func show_chiefdom(mode_name: String, chiefdom: Dictionary) -> void:
	if chiefdom.is_empty():
		return
	territory_mode = mode_name
	if _minimap != null:
		_minimap.set_territory(mode_name)
	var body := PackedStringArray()
	body.append(String(chiefdom.get("role", "")))
	body.append("")
	body.append(String(chiefdom.get("summary", "")))
	body.append("")
	body.append("[data]Extent[/data]  %s" % String(chiefdom.get("jurisdiction", "")))
	body.append("[data]Authority[/data]  %s" % String(chiefdom.get("authority", "")))
	body.append("")
	body.append("[i]Border basis: %s · Evidential confidence: %s[/i]" % [
		String(chiefdom.get("role", "")).to_lower(),
		String(chiefdom.get("evidential_confidence", "unknown")).to_upper(),
	])
	_show_inspection(
		"Chiefdom",
		String(chiefdom.get("name", "")),
		"Today: %s" % String(chiefdom.get("modern", "")),
		"\n".join(body),
	)

func hide_chiefdom() -> void:
	hide_inspection()

func hide_inspection() -> void:
	if _inspection == null:
		return
	var shell := _inspection.get_parent() as Control
	if shell != null and shell != _root:
		shell.visible = false

func _show_inspection(eyebrow: String, title: String, detail: String, body: String) -> void:
	var shell := _inspection.get_parent() as Control
	if shell != null:
		shell.visible = true
	_inspect_eyebrow.text = eyebrow.to_upper()
	_inspect_title.text = title
	_inspect_detail.text = detail
	_inspect_detail.visible = not detail.is_empty()
	_inspect_body.text = body
	_inspect_body.visible = not body.is_empty()

func configure_survey(terrain_ref: GopalaKathmanduTerrain, regions: Array) -> void:
	terrain = terrain_ref
	if _minimap != null:
		_minimap.configure(terrain_ref, regions)

func _catalog() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	return parsed if parsed is Dictionary else {}