class_name GopalaKathmanduHud
extends CanvasLayer
## Editorial-warm management interface for the Kathmandu valley scene.
## Built in code from GopalaTheme so the running game and the editor agree.
## Public surface is kept compatible with kathmandu_valley.gd.

signal territory_requested
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
signal cancel_road_requested(entity_id: int)
var _road_cancel: Button
var _inspected_road_id := 0
signal road_mode_requested
signal cobbled_path_mode_requested
signal cattle_pasture_selected(pasture_id: int)
signal field_action_requested(action: StringName, field_id: int, worker_id: int, crop_id: StringName)
var _cattle_controls: VBoxContainer
var _pasture_choices: OptionButton
var _field_controls: VBoxContainer
var _field_crop_choices: OptionButton
var _field_worker_choices: OptionButton
var _field_action_button: Button
var _inspected_field_id := 0
var _field_action: StringName = &""
var _pasture_signature := ""
signal work_role_selected(role: StringName)
var _worker_jobs: GridContainer
var _builder_jobs: GridContainer
var _builder_site_choices: OptionButton
var _builder_assign_button: Button
var _builder_release_button: Button

signal help_requested
signal pause_requested
signal save_requested
signal load_requested
signal speed_selected(multiplier: int)
signal new_game_requested
var _mvp_summary: Label
var _summary_strip: PanelContainer
var _summary_readout: Label
var _survival_panel: PanelContainer
var _hud_enabled := false

signal alert_requested(key: String)
var _alert_panel: PanelContainer
var _alert_list: VBoxContainer
var _alert_buttons := {}
var _alert_display_signature := ""

const MODE_HINTS := {
	"Wash": "Territory wash — click any ground to read the chiefdom holding it.",
	"Survey": "Territory survey — frontiers dashed, seats ringed, ridges and rivers are the borders.",
}
const TOAST_LIFETIME := 4.2
const INK_SCRIM := Color(0.11, 0.09, 0.06, 0.93)
const RESOURCE_ICONS := {
	&"timber": "res://addons/at-icons/control/tree.svg",
	&"stone": "res://addons/at-icons/node/rocks.svg",
	&"thatch": "res://assets/ui/icons/grass.svg",
	&"water": "res://addons/at-icons/node2d/droplet.svg",
	&"milk": "res://addons/at-icons/node/glass.svg",
	&"fodder": "res://addons/at-icons/control/sprout.svg",
	&"grain": "res://assets/prototype/good_grain.svg",
	&"wild_food": "res://addons/at-icons/node3d/apple.svg",
}
const CREST_ICON := "res://assets/ui/icons/castle.svg"
const CALENDAR_ICON := "res://assets/ui/icons/hourglass.svg"
const MENU_ICON := "res://assets/ui/icons/cog.svg"
const SAVE_ICON := "res://assets/ui/icons/floppy_disk.svg"
const LOAD_ICON := "res://assets/ui/icons/folder_open.svg"
const BUILDING_ICONS := {
	&"dwelling": "res://assets/ui/icons/house.svg",
	&"stockpile": "res://assets/ui/icons/chest.svg",
	&"timber_camp": "res://assets/ui/icons/tree.svg",
	&"gatherer_shelter": "res://assets/ui/icons/shopping_basket.svg",
	&"water_point": "res://assets/ui/icons/droplet.svg",
	&"cattle_shelter": "res://assets/ui/icons/meat.svg",
	&"pasture": "res://assets/ui/icons/grass.svg",
	&"field": "res://assets/ui/icons/grass.svg",
}
const BUILDING_LABELS := {
	&"dwelling": "Home",
	&"stockpile": "Store",
	&"timber_camp": "Timber",
	&"gatherer_shelter": "Gather",
	&"water_point": "Water",
	&"cattle_shelter": "Cattle",
	&"pasture": "Pasture",
	&"field": "Field",
}
const CATEGORY_ICONS := {
	"All": "res://assets/ui/icons/building.svg",
	"Housing": "res://assets/ui/icons/house.svg",
	"Storage": "res://assets/ui/icons/chest.svg",
	"Resources": "res://assets/ui/icons/tree.svg",
	"Food": "res://assets/ui/icons/meat.svg",
	"Water": "res://assets/ui/icons/droplet.svg",
	"Pasture": "res://assets/ui/icons/grass.svg",
}

var terrain: GopalaKathmanduTerrain
var territory_mode := "Off"
var _tokens: UITokens = UITokens.new()

var _root: Control
var _settlement_name: Label
var _season_line: Label
var _clock_line: Label
var _resource_slots: Dictionary = {}
var _resource_buttons: Dictionary = {}
var _navbar: PanelContainer
var _nav_brand: HBoxContainer
var _nav_resources: PanelContainer
var _nav_actions: HBoxContainer
var _workforce_panel: GopalaWorkforcePanel
var _resource_overview: GopalaResourceOverview
var _minimap: GopalaMinimap
var _minimap_shell: PanelContainer
var _status_shell: PanelContainer
var _build_bar_shell: PanelContainer
var _view_tools_shell: PanelContainer
var _inspection: PanelContainer
var _status_section: GopalaCollapsibleSection
var _inspection_section: GopalaCollapsibleSection
var _build_section: GopalaCollapsibleSection
var _view_section: GopalaCollapsibleSection
var _minimap_section: GopalaCollapsibleSection
var _alerts_section: GopalaCollapsibleSection
var _survival_section: GopalaCollapsibleSection
var _inspect_title: Label
var _inspect_detail: Label
var _inspect_eyebrow: Label
var _inspect_body: RichTextLabel
var _build_card: PanelContainer
var _build_title: Label
var _build_meta: Label
var _build_costs: Label
var _build_toggle: Button
var _category_grid: GridContainer
var _structure_grid: GridContainer
var _category_group: ButtonGroup
var _tab_buttons: Array[Button] = []
var _build_entries: Array[Dictionary] = []
var _active_category := "All"
var _toast_stack: VBoxContainer
var _grid_button: Button
var _names_button: Button
var _speed_buttons: Array[Button] = []
var _pause_button: Button
var _selected_build := StringName("")
var _placement_active := false
var _road_mode := false
var _cobbled_path_mode := false
var _last_place_stamp := 0

# Settlement-specific components; generic action-game fixtures stay in the gallery.
var _health_bar: HealthBar
var _notification_stack: NotificationStack
var _health_visibility_tween: Tween
var _road_tool_button: Button

func _ready() -> void:
	layer = 2
	_build_root()
	_build_top_bar()
	_build_survey_minimap()
	_build_status_card()
	_build_inspection_panel()
	_build_build_bar()
	_build_view_tools()
	_build_toasts()
	_setup_settlement_components()
	_build_resource_overview()
	_root.resized.connect(_layout_hud)
	_layout_hud()
	_reveal_staggered()

func _setup_settlement_components() -> void:
	_health_bar = preload("res://scenes/ui/hud/components/health_bar.tscn").instantiate()
	_health_bar.custom_minimum_size = Vector2(200, 24)
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.visible = false
	_inspect_title.get_parent().add_child(_health_bar)
	_notification_stack = preload("res://scenes/ui/hud/components/notification_stack.tscn").instantiate()
	_notification_stack.notification_scene = preload("res://scenes/ui/hud/components/toast_notification.tscn")
	_notification_stack.max_visible = 2
	_notification_stack.custom_minimum_size.x = 340
	_notification_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notification_stack.z_index = 20
	_root.add_child(_notification_stack)
	var bus := get_node_or_null("/root/EventBus")
	if bus != null:
		bus.notification_requested.connect(_notification_stack.push)

func enable_mvp_controls() -> void:
	_hud_enabled = true
	_status_shell.visible = false
	_build_bar_shell.visible = false
	_refresh_build_toggle()
	_view_tools_shell.visible = true
	var panel := _panel(&"paper")
	panel.name = "SurvivalPanel"
	_survival_panel = panel
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 10
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 14
	panel.offset_top = 248
	panel.offset_right = 314
	panel.offset_bottom = 498
	_root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var column := _column(8)
	margin.add_child(column)
	_survival_section = _new_collapsible_section("Settlement")
	column.add_child(_survival_section)
	_bind_collapsible_section(_survival_section, panel, 42.0, 250.0)
	var content := _survival_section.body()
	content.add_theme_constant_override("separation", 8)
	_mvp_summary = _label("", GopalaTheme.font(GopalaTheme.FONT_UI, 400, 13), 13, GopalaTheme.INK)
	_mvp_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mvp_summary.custom_minimum_size.x = 260
	content.add_child(_mvp_summary)
	var help := Button.new()
	help.text = "Controls & credits"
	help.custom_minimum_size.y = GopalaTheme.NAV_CONTROL_HEIGHT
	help.pressed.connect(func():
		help_requested.emit()
		var dialog := AcceptDialog.new()
		dialog.theme = GopalaTheme.navbar()
		dialog.title = "GOPALA MVP"
		dialog.dialog_text = "Select a settler with left-click. Assign a supply job in the inspection panel.\nPlace a building, then right-click its site with a free settler to build.\nSelect Pasture to mark an 8 × 8 metre grazing plot. Assign Herd and Milk jobs.\nSelect a cow and use Move to pasture to relocate it. Crowding slows grazing production; fodder restores it.\nCows need a completed shelter, grazing or fodder, water, and tending.\nUse the tempo buttons to start, pause, or change speed. Save / Load or F5 / F9.\nWASD pans; wheel zooms; Q/E turns; C focuses the settlement.\nEsc cancels placement, closes panels, then opens the pause menu. Comma / period rotate a building.\n\nPrototype assets: Kenney and Poly Haven (CC0); icons and addons (MIT); fonts (OFL).\nMap data © OpenStreetMap contributors (ODbL): https://www.openstreetmap.org/copyright\nProduced using Copernicus WorldDEM-30 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018\nprovided under COPERNICUS by the European Union and ESA; all rights reserved.\nFull notices and sources are bundled with the build."
		_root.add_child(dialog)
		dialog.popup_centered(Vector2i(700, 420))
		dialog.confirmed.connect(dialog.queue_free)
	)
	content.add_child(help)
	var restart := Button.new()
	restart.text = "New settlement"
	restart.custom_minimum_size.y = GopalaTheme.NAV_CONTROL_HEIGHT
	restart.tooltip_text = "Start a new paused run. Save first to keep the current run."
	restart.pressed.connect(func(): new_game_requested.emit())
	content.add_child(restart)
	_summary_strip = _panel(&"paper")
	_summary_strip.name = "SettlementStatusStrip"
	_summary_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_summary_strip)
	_summary_readout = _label("Settlement preparing…", GopalaTheme.font(GopalaTheme.FONT_UI, 400, 13), 13, GopalaTheme.NAV_TEXT)
	_summary_readout.clip_text = true
	_summary_strip.add_child(_summary_readout)
	_layout_hud()

func enable_alerts_feed() -> void:
	if _alert_panel != null:
		return
	_alert_panel = _panel(&"paper")
	_alert_panel.name = "AlertsFeed"
	_alert_panel.add_theme_stylebox_override("panel", GopalaTheme.flat(GopalaTheme.NAV_SURFACE, 5, 1, GopalaTheme.NAV_BORDER, 8, 6))
	_alert_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_alert_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_alert_panel.offset_left = 14
	_alert_panel.offset_right = 354
	_alert_panel.offset_top = 508
	_alert_panel.offset_bottom = 660
	_root.add_child(_alert_panel)
	_alerts_section = _new_collapsible_section("Alerts", true)
	_alert_panel.add_child(_alerts_section)
	_alerts_section.body().add_child(_eyebrow("Select an alert to focus"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 80
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_alerts_section.body().add_child(scroll)
	_alert_list = VBoxContainer.new()
	_alert_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_alert_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_alert_list)
	_bind_collapsible_section(_alerts_section, _alert_panel, 42.0, 152.0)
	_alert_panel.visible = false

func set_alerts(rows: Array) -> void:
	if _alert_panel == null:
		return
	var display: Array = []
	for row in rows:
		display.append([row.key, row.severity, row.message])
	var signature := JSON.stringify(display)
	if signature == _alert_display_signature:
		return
	_alert_display_signature = signature
	var live := {}
	for row in rows:
		var key: String = row.key
		live[key] = true
		var button: Button = _alert_buttons.get(key)
		if button == null:
			button = Button.new()
			button.name = "Alert_" + key.replace(":", "_")
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			button.custom_minimum_size.y = GopalaTheme.NAV_CONTROL_HEIGHT
			button.clip_text = true
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(func(): alert_requested.emit(key))
			_alert_list.add_child(button)
			_alert_buttons[key] = button
		var glyph := "!" if row.severity == "critical" else "△" if row.severity == "warning" else "•"
		button.text = "%s %s · %s" % [glyph, str(row.severity).capitalize(), row.message]
		button.tooltip_text = button.text + "\nSelect this subject and focus the camera"
		_alert_list.move_child(button, live.size() - 1)
	for key in _alert_buttons.keys():
		if not live.has(key):
			var button: Button = _alert_buttons[key]
			_alert_list.remove_child(button)
			button.queue_free()
			_alert_buttons.erase(key)
	_alert_panel.visible = not rows.is_empty()
	_alerts_section.set_title("Alerts · %d" % rows.size())
	_layout_hud()

func set_mvp_summary(text: String) -> void:
	if _mvp_summary != null:
		_mvp_summary.text = text
	if _summary_readout != null:
		var lines := text.split("\n")
		_summary_readout.text = "   •   ".join(lines.slice(0, mini(2, lines.size())))
		_summary_readout.tooltip_text = text
		_layout_hud()

func _build_root() -> void:
	_root = Control.new()
	_root.name = "Interface"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = GopalaTheme.navbar()
	add_child(_root)

func _new_collapsible_section(title: String, initially_collapsed := false) -> GopalaCollapsibleSection:
	var scene := load("res://scenes/ui/components/collapsible_section/collapsible_section.tscn") as PackedScene
	var section := scene.instantiate() as GopalaCollapsibleSection
	section.title = title
	section.collapsed = initially_collapsed
	return section

func _bind_collapsible_section(section: GopalaCollapsibleSection, shell: Control, collapsed_height: float, expanded_height: float, fills_viewport := false) -> void:
	section.collapsed_changed.connect(func(is_collapsed: bool) -> void:
		_layout_hud.call_deferred()
		if fills_viewport:
			shell.anchor_bottom = 0.0 if is_collapsed else 1.0
			shell.offset_bottom = shell.offset_top + collapsed_height if is_collapsed else -14.0
		else:
			shell.offset_bottom = shell.offset_top + (collapsed_height if is_collapsed else expanded_height)
	)
	if section.collapsed:
		if fills_viewport:
			shell.anchor_bottom = 0.0
			shell.offset_bottom = shell.offset_top + collapsed_height
		else:
			shell.offset_bottom = shell.offset_top + collapsed_height

func _panel(style: StringName, margin := 0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
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
		&"top_bar":
			var top_box := GopalaTheme.flat(INK_SCRIM, 0)
			top_box.border_width_bottom = 1
			top_box.border_color = GopalaTheme.BRASS_DARK
			top_box.shadow_color = Color(0.08, 0.06, 0.04, 0.35)
			top_box.shadow_offset = Vector2(0, 2)
			top_box.shadow_size = 6
			return top_box
		&"chip":
			return GopalaTheme.flat(Color(0.06, 0.05, 0.04, 0.65), 5, 1, Color(GopalaTheme.BRASS.r, GopalaTheme.BRASS.g, GopalaTheme.BRASS.b, 0.22), 8, 5)
		&"resource_rail":
			return GopalaTheme.flat(GopalaTheme.NAV_INSET, GopalaTheme.NAV_RADIUS, 1, GopalaTheme.NAV_BORDER, 12, 4)
		&"clock_chip":
			return GopalaTheme.flat(GopalaTheme.NAV_INSET, GopalaTheme.NAV_RADIUS, 1, GopalaTheme.NAV_BORDER, 10, 4)
		&"tab_normal": return GopalaTheme.flat(GopalaTheme.NAV_INSET, 5, 1, GopalaTheme.NAV_BORDER, 10, 4)
		&"tab_hover": return GopalaTheme.flat(GopalaTheme.NAV_RAISED, 5, 1, GopalaTheme.BRASS, 10, 4)
		&"tab_active": return GopalaTheme.flat(GopalaTheme.NAV_RAISED, 5, 1, GopalaTheme.BRASS, 10, 4)
		&"ink_bare": return GopalaTheme.flat(Color(0, 0, 0, 0), 4)
		&"shell": return GopalaTheme.lifted(GopalaTheme.flat(Color(0, 0, 0, 0), 18), 0.06, 8, 24)
		&"ink": return GopalaTheme.flat(GopalaTheme.NAV_SURFACE, GopalaTheme.NAV_RADIUS, 1, GopalaTheme.NAV_BORDER)
		&"paper": return GopalaTheme.flat(GopalaTheme.NAV_SURFACE, GopalaTheme.NAV_RADIUS, 1, GopalaTheme.NAV_BORDER)
		&"paper_raised": return GopalaTheme.flat(GopalaTheme.NAV_INSET, GopalaTheme.NAV_RADIUS, 1, GopalaTheme.NAV_BORDER)
		&"sunk": return GopalaTheme.flat(GopalaTheme.NAV_INSET, GopalaTheme.NAV_RADIUS, 1, GopalaTheme.NAV_BORDER)
		&"brass": return GopalaTheme.flat(GopalaTheme.NAV_RAISED, 5, 1, GopalaTheme.BRASS)
		&"forest": return GopalaTheme.flat(GopalaTheme.NAV_SURFACE, 5, 1, GopalaTheme.FOREST)
		&"river": return GopalaTheme.flat(GopalaTheme.NAV_SURFACE, 5, 1, GopalaTheme.RIVER)
		&"terra": return GopalaTheme.flat(GopalaTheme.NAV_SURFACE, 5, 1, GopalaTheme.TERRA)
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
	label.add_theme_color_override("font_color", GopalaTheme.NAV_TEXT if color == GopalaTheme.INK else (GopalaTheme.NAV_MUTED if color == GopalaTheme.INK_MUTED else color))
	return label

func _eyebrow(text_value: String, color := GopalaTheme.BRASS_DARK) -> Label:
	var label := _label(text_value.to_upper(), GopalaTheme.font(GopalaTheme.FONT_UI, 600, 10), 10, color)
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


func _vertical_divider() -> VSeparator:
	var line := StyleBoxLine.new()
	line.color = Color(GopalaTheme.NAV_BORDER.r, GopalaTheme.NAV_BORDER.g, GopalaTheme.NAV_BORDER.b, 0.35)
	line.thickness = 1
	line.vertical = true
	var separator := VSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	separator.add_theme_stylebox_override("separator", line)
	separator.custom_minimum_size = Vector2(1, 24)
	return separator


func _nav_button(name: String, icon_path: String, tooltip: String, is_primary: bool) -> Button:
	var button := Button.new()
	button.text = ""
	button.accessibility_name = name
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(32, GopalaTheme.NAV_CONTROL_HEIGHT)
	button.icon = load(icon_path)
	button.expand_icon = true
	button.name = "Navbar" + name
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_constant_override("icon_max_width", 18)
	button.add_theme_constant_override("icon_max_height", 20)
	button.add_theme_font_size_override("font_size", GopalaTheme.NAV_BODY_SIZE)

	if is_primary:
		# Primary: filled brass
		button.add_theme_stylebox_override("normal", GopalaTheme.flat(GopalaTheme.BRASS, GopalaTheme.NAV_RADIUS, 0, GopalaTheme.BRASS_DARK, 6, 4))
		button.add_theme_stylebox_override("hover", GopalaTheme.flat(GopalaTheme.BRASS_LIGHT, GopalaTheme.NAV_RADIUS, 0, GopalaTheme.BRASS, 6, 4))
		button.add_theme_stylebox_override("pressed", GopalaTheme.flat(GopalaTheme.BRASS_DARK, GopalaTheme.NAV_RADIUS, 0, GopalaTheme.BRASS, 6, 4))
		button.add_theme_stylebox_override("focus", GopalaTheme.flat(Color.TRANSPARENT, GopalaTheme.NAV_RADIUS, 2, GopalaTheme.BRASS_LIGHT, 6, 4))
		button.add_theme_color_override("font_color", GopalaTheme.INK)
		button.add_theme_color_override("font_hover_color", GopalaTheme.INK)
		button.add_theme_color_override("font_pressed_color", GopalaTheme.INK)
		button.add_theme_color_override("font_focus_color", GopalaTheme.INK)
	else:
		# Secondary: outlined
		button.add_theme_stylebox_override("normal", GopalaTheme.flat(GopalaTheme.NAV_INSET, GopalaTheme.NAV_RADIUS, 1, GopalaTheme.NAV_BORDER, 6, 4))
		button.add_theme_stylebox_override("hover", GopalaTheme.flat(GopalaTheme.NAV_RAISED, GopalaTheme.NAV_RADIUS, 1, GopalaTheme.BRASS, 6, 4))
		button.add_theme_stylebox_override("pressed", GopalaTheme.flat(GopalaTheme.NAV_RAISED, GopalaTheme.NAV_RADIUS, 1, GopalaTheme.BRASS, 6, 4))
		button.add_theme_stylebox_override("focus", GopalaTheme.flat(Color.TRANSPARENT, GopalaTheme.NAV_RADIUS, 2, GopalaTheme.BRASS_LIGHT, 6, 4))
		button.add_theme_color_override("font_color", GopalaTheme.NAV_TEXT)
		button.add_theme_color_override("font_hover_color", GopalaTheme.BRASS_LIGHT)
		button.add_theme_color_override("font_pressed_color", GopalaTheme.BRASS_LIGHT)
		button.add_theme_color_override("font_focus_color", GopalaTheme.BRASS_LIGHT)

	return button

func _icon(texture: Texture2D, side: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.custom_minimum_size = Vector2(side, side)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect

func _tool_button(label_text: String, tooltip: String, glyph: String, navbar_reference := false) -> Button:
	var button := Button.new()
	button.text = glyph
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	if navbar_reference:
		button.custom_minimum_size = Vector2(GopalaTheme.NAV_CONTROL_HEIGHT, GopalaTheme.NAV_CONTROL_HEIGHT)
		button.add_theme_font_size_override("font_size", GopalaTheme.NAV_BODY_SIZE)
		button.add_theme_stylebox_override("normal", GopalaTheme.flat(GopalaTheme.NAV_INSET, GopalaTheme.NAV_RADIUS, 0, GopalaTheme.NAV_BORDER, 8, 3))
		for state in ["hover", "pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(state, GopalaTheme.flat(GopalaTheme.NAV_RAISED, GopalaTheme.NAV_RADIUS, 0, GopalaTheme.BRASS, 8, 3))
		button.add_theme_stylebox_override("focus", GopalaTheme.flat(Color.TRANSPARENT, GopalaTheme.NAV_RADIUS, 2, GopalaTheme.BRASS_LIGHT, 8, 3))
		button.add_theme_color_override("font_color", GopalaTheme.NAV_TEXT)
		button.add_theme_color_override("font_hover_color", GopalaTheme.BRASS_LIGHT)
		button.add_theme_color_override("font_pressed_color", GopalaTheme.BRASS_LIGHT)
		button.add_theme_color_override("font_focus_color", GopalaTheme.BRASS_LIGHT)
	else:
		button.custom_minimum_size = Vector2(GopalaTheme.NAV_CONTROL_HEIGHT, GopalaTheme.NAV_CONTROL_HEIGHT)
		button.add_theme_font_size_override("font_size", 14)
	return button

func _reveal_staggered() -> void:
	var settings := GopalaUISettings.settings()
	if settings != null and settings.reduced_motion:
		return
	var groups := []
	_collect_reveal(_root, groups)
	for node in groups:
		node.modulate.a = 0.0
		create_tween().tween_property(node, "modulate:a", 1.0, 0.18)

func _collect_reveal(node: Node, into: Array) -> void:
	for child in node.get_children():
		if child is Control and child.visible:
			into.append(child)

func _build_top_bar() -> void:
	_navbar = _panel(&"top_bar")
	_navbar.name = "Navbar"
	_navbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_navbar.offset_bottom = 52
	_navbar.z_index = 5
	_root.add_child(_navbar)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_navbar.add_child(margin)
	var row := _row(12)
	margin.add_child(row)
	# Equal side slots keep the resource rail centered independently of name length.
	var left := MarginContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.custom_minimum_size.x = 272
	row.add_child(left)
	_nav_brand = _row(8)
	_nav_brand.name = "SettlementIdentity"
	_nav_brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(_nav_brand)
	var crest := _icon(load(CREST_ICON), 24)
	crest.modulate = GopalaTheme.BRASS_LIGHT
	_nav_brand.add_child(crest)
	var title_col := _column(0)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nav_brand.add_child(title_col)
	title_col.add_child(_eyebrow("GOPALA", GopalaTheme.BRASS_LIGHT))
	_settlement_name = _label("Dudhkunda", GopalaTheme.font(GopalaTheme.FONT_DISPLAY, 600, 16), 16, GopalaTheme.NAV_TEXT)
	_settlement_name.clip_text = true
	_settlement_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_col.add_child(_settlement_name)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(center)
	_nav_resources = _panel(&"resource_rail")
	_nav_resources.name = "NavbarResources"
	center.add_child(_nav_resources)
	var rail := _row(8)
	rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_nav_resources.add_child(rail)
	_reload_resources(rail)
	var right := HBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.custom_minimum_size.x = 272
	right.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(right)
	_nav_actions = _row(8)
	_nav_actions.name = "NavbarActions"
	_nav_actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(_nav_actions)
	var clock := _panel(&"clock_chip")
	clock.name = "SimulationClock"
	_nav_actions.add_child(clock)
	var clock_row := _row(6)
	clock.add_child(clock_row)
	var clock_icon := _icon(load(CALENDAR_ICON), 16)
	clock_icon.modulate = GopalaTheme.BRASS_LIGHT
	clock_row.add_child(clock_icon)
	var clock_col := _column(0)
	clock_row.add_child(clock_col)
	_season_line = _label("Paused", GopalaTheme.font(GopalaTheme.FONT_DISPLAY, 600, 12), 12, GopalaTheme.BRASS_LIGHT)
	clock_col.add_child(_season_line)
	_clock_line = _label("Tick 0", GopalaTheme.font(GopalaTheme.FONT_UI, 400, 11), 11, GopalaTheme.NAV_MUTED)
	clock_col.add_child(_clock_line)
	for action in [["Save", SAVE_ICON, "Save settlement (F5)"], ["Load", LOAD_ICON, "Load settlement (F9) · Shift+F9 backup"], ["Menu", MENU_ICON, "Pause menu (Esc)"]]:
		var button := _nav_button(action[0], action[1], action[2], false)
		_nav_actions.add_child(button)
		match action[0]:
			"Save": button.pressed.connect(func(): save_requested.emit())
			"Load": button.pressed.connect(func(): load_requested.emit())
			"Menu": button.pressed.connect(func(): pause_requested.emit())

func _build_survey_minimap() -> void:
	var shell := _panel(&"shell")
	shell.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	shell.offset_left = -184.0
	shell.offset_right = -14.0
	shell.offset_top = 60.0
	shell.offset_bottom = 202.0
	shell.visible = false
	_minimap_shell = shell
	_minimap_section = _new_collapsible_section("Valley map")
	shell.add_child(_minimap_section)
	_root.add_child(shell)
	_bind_collapsible_section(_minimap_section, shell, 42.0, 142.0)
	_minimap = GopalaMinimap.new()
	_minimap.custom_minimum_size = Vector2(140, 100)
	_minimap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_minimap_section.body().add_child(_minimap)

func _reload_resources(rail: HBoxContainer) -> void:
	for child in rail.get_children():
		child.queue_free()
	_resource_slots.clear()
	var catalog := _catalog()
	for path in catalog.get("resources", []):
		var good := load(path) as GopalaResourceDefinition
		if good != null:
			rail.add_child(_resource_slot(good))

func _resource_slot(good: GopalaResourceDefinition) -> Control:
	var button := Button.new()
	button.name = "Resource_" + String(good.id)
	button.accessibility_name = good.display_name + " stock; open resource overview"
	button.tooltip_text = "%s · open resource overview" % good.display_name
	button.custom_minimum_size = Vector2(44, 32)
	button.pressed.connect(func(): show_resource_overview(good.id))
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, GopalaTheme.flat(Color.TRANSPARENT if state == "normal" else GopalaTheme.NAV_RAISED, 3, 0, Color.TRANSPARENT, 4, 2))
	var item := _row(6)
	item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(item)
	var icon_path: String = RESOURCE_ICONS.get(good.id, "")
	var icon_tex: Texture2D = load(icon_path) if ResourceLoader.exists(icon_path) else good.icon
	if icon_tex != null:
		item.add_child(_icon(icon_tex, 18))
	var amount := _label("0", GopalaTheme.font(GopalaTheme.FONT_MONO, 500, 13), 13, GopalaTheme.NAV_TEXT)
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(amount)
	item.resized.connect(func(): button.custom_minimum_size.x = maxf(44.0, item.get_combined_minimum_size().x + 8.0))
	_resource_slots[good.id] = amount
	_resource_buttons[good.id] = button
	return button

func _build_resource_overview() -> void:
	_resource_overview = preload("res://scenes/ui/management/resource_overview.tscn").instantiate()
	_resource_overview.theme = GopalaTheme.navbar()
	add_child(_resource_overview)
	_resource_overview.configure(_catalog(), RESOURCE_ICONS)

func show_resource_overview(resource_id: StringName = &"timber") -> void:
	_resource_overview.select_resource(resource_id)
	_resource_overview.popup_centered_clamped(Vector2i(640, 600), 0.85)

func _shortcut_input(event: InputEvent) -> void:
	if event.is_action_pressed("hud_toggle") and not event.is_echo():
		_root.visible = not _root.visible
		if not _root.visible:
			_resource_overview.hide()
			if _workforce_panel != null: _workforce_panel.hide()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo() and not _placement_active:
		if close_top_panel():
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("workforce_toggle") and not event.is_echo() and _root.visible:
		show_workforce_panel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("management_toggle") and not event.is_echo() and _root.visible:
		show_resource_overview()
		get_viewport().set_input_as_handled()

func _build_status_card() -> void:
	var shell := _panel(&"shell")
	shell.set_anchors_preset(Control.PRESET_TOP_LEFT)
	shell.offset_left = 14.0
	shell.offset_top = 60.0
	shell.offset_right = 314.0
	shell.offset_bottom = 232.0
	shell.visible = false
	_status_shell = shell
	_root.add_child(shell)
	var plate := _panel(&"paper")
	shell.add_child(plate)
	_status_section = _new_collapsible_section("Valley survey")
	plate.add_theme_stylebox_override("panel", GopalaTheme.flat(GopalaTheme.NAV_SURFACE, 5, 1, GopalaTheme.NAV_BORDER, 12, 10))
	plate.add_child(_status_section)
	_bind_collapsible_section(_status_section, shell, 42.0, 172.0)
	var column := _status_section.body()
	column.add_child(_label("Kathmandu valley", GopalaTheme.font(GopalaTheme.FONT_DISPLAY, 500, 16), 16, GopalaTheme.INK))
	column.add_child(_label("40 km across · 1200 m base", GopalaTheme.font(GopalaTheme.FONT_UI, 400, 12), 12, GopalaTheme.INK_MUTED))
	var actions := _row(6)
	column.add_child(actions)
	_grid_button = _tool_button("", "Planning grid · 2 m cells (G)", "▦")
	_grid_button.toggle_mode = true
	_grid_button.toggled.connect(func(on): grid_changed.emit(on))
	actions.add_child(_grid_button)
	_names_button = _tool_button("", "Place names (N)", "Aa")
	_names_button.toggle_mode = true
	_names_button.toggled.connect(func(on): names_changed.emit(on))
	actions.add_child(_names_button)
	var territory := _tool_button("", "Chiefdom survey (F)", "◈")
	territory.pressed.connect(func(): territory_requested.emit())
	actions.add_child(territory)
	var valley := _tool_button("", "Whole valley", "⌖")
	valley.pressed.connect(func(): valley_requested.emit())
	actions.add_child(valley)
	var source := _tool_button("", "Bagmati source", "⌖")
	source.pressed.connect(func(): source_requested.emit())
	actions.add_child(source)
	var camp := _tool_button("", "Local ground", "⌂")
	camp.pressed.connect(func(): camp_requested.emit())
	actions.add_child(camp)
	var speed_row := _row(6)
	column.add_child(speed_row)
	speed_row.add_child(_eyebrow("Tempo"))
	var pause := _tool_button("", "Pause (Space)", "❚❚")
	_pause_button = pause
	pause.toggle_mode = true
	pause.toggled.connect(func(on): speed_selected.emit(0 if on else 1))
	speed_row.add_child(pause)
	for multiplier in [1, 2, 4]:
		var button := Button.new()
		button.text = "%d×" % multiplier
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(40, 30)
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_stylebox_override("normal", _style(&"paper_raised"))
		button.add_theme_stylebox_override("hover", GopalaTheme.flat(GopalaTheme.NAV_RAISED, 5, 1, GopalaTheme.BRASS_DARK))
		button.add_theme_stylebox_override("pressed", GopalaTheme.flat(GopalaTheme.BRASS, 10))
		button.add_theme_stylebox_override("hover_pressed", GopalaTheme.flat(GopalaTheme.BRASS_DARK, 10))
		button.add_theme_stylebox_override("focus", GopalaTheme.flat(Color.TRANSPARENT, 5, 2, GopalaTheme.BRASS_LIGHT))
		button.toggled.connect(func(on): speed_selected.emit(multiplier if on else 0))
		speed_row.add_child(button)
		_speed_buttons.append(button)
	_speed_buttons[0].button_pressed = true

func _build_inspection_panel() -> void:
	var shell := _panel(&"shell")
	shell.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	shell.offset_left = -354.0
	shell.offset_right = -14.0
	shell.offset_top = 212.0
	shell.offset_bottom = 582.0
	shell.visible = false
	_root.add_child(shell)
	_inspection = _panel(&"ink")
	shell.add_child(_inspection)
	shell.name = "InspectionShell"
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", _tokens.space_4)
	margin.add_theme_constant_override("margin_bottom", _tokens.space_4)
	_inspection.add_child(margin)
	_inspection_section = _new_collapsible_section("Inspection")
	margin.add_child(_inspection_section)
	_inspection_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bind_collapsible_section(_inspection_section, shell, 42.0, 370.0)
	var body := _inspection_section.body()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var column := _column(8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	_inspect_eyebrow = _inspection_section.title_label()
	var close := _tool_button("", "Close (Esc)", "✕")
	close.custom_minimum_size = Vector2(30, 30)
	close.pressed.connect(hide_inspection)
	_inspection_section.add_header_control(close)
	_inspect_title = _label("", GopalaTheme.font(GopalaTheme.FONT_DISPLAY, 600, 16), 16, GopalaTheme.PAPER)
	_inspect_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_worker_jobs = GridContainer.new()
	_worker_jobs.columns = 3
	_worker_jobs.add_theme_constant_override("h_separation", 5)
	_worker_jobs.add_theme_constant_override("v_separation", 5)
	_worker_jobs.visible = false
	column.add_child(_worker_jobs)
	_builder_jobs = GridContainer.new()
	_builder_jobs.name = "BuilderJobs"
	_builder_jobs.columns = 2
	_builder_jobs.add_theme_constant_override("h_separation", 5)
	_builder_jobs.add_theme_constant_override("v_separation", 5)
	_builder_jobs.visible = false
	column.add_child(_builder_jobs)
	_builder_site_choices = OptionButton.new()
	_builder_site_choices.fit_to_longest_item = false
	_builder_site_choices.clip_text = true
	_builder_site_choices.name = "BuilderSiteChoices"
	_builder_site_choices.custom_minimum_size.y = GopalaTheme.NAV_CONTROL_HEIGHT
	_builder_site_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_builder_site_choices.tooltip_text = "Choose an unfinished building site for this settler."
	_builder_jobs.add_child(_builder_site_choices)
	_builder_assign_button = Button.new()
	_builder_assign_button.name = "Builder_BUILD"
	_builder_assign_button.text = "Build selected site"
	_builder_assign_button.add_theme_font_size_override("font_size", 12)
	_builder_assign_button.custom_minimum_size.y = GopalaTheme.NAV_CONTROL_HEIGHT
	_builder_assign_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_builder_assign_button.tooltip_text = "Assign this villager to the selected unfinished construction site."
	_builder_assign_button.focus_mode = Control.FOCUS_ALL
	_builder_assign_button.pressed.connect(func(): work_role_selected.emit(&"BUILD"))
	_builder_jobs.add_child(_builder_assign_button)
	_builder_release_button = Button.new()
	_builder_release_button.name = "Builder_STOP_BUILD"
	_builder_release_button.text = "Stop building"
	_builder_release_button.add_theme_font_size_override("font_size", 12)
	_builder_release_button.custom_minimum_size.y = GopalaTheme.NAV_CONTROL_HEIGHT
	_builder_release_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_builder_release_button.tooltip_text = "Stop construction work after returning any carried materials."
	_builder_release_button.focus_mode = Control.FOCUS_ALL
	_builder_release_button.pressed.connect(func(): work_role_selected.emit(&"STOP_BUILD"))
	_builder_jobs.add_child(_builder_release_button)
	for choice in [["Timber", &"timber"], ["Stone", &"stone"], ["Thatch", &"thatch"], ["Wild food", &"wild_food"], ["Fodder", &"fodder"], ["Water", &"water"], ["Milk", &"milk"], ["Herd", &"herder"], ["Stop job", &"NONE"]]:
		var button := Button.new()
		button.text = choice[0]
		button.add_theme_font_size_override("font_size", 12)
		button.custom_minimum_size.y = GopalaTheme.NAV_CONTROL_HEIGHT
		if RESOURCE_ICONS.has(choice[1]) and ResourceLoader.exists(RESOURCE_ICONS[choice[1]]):
			button.icon = load(RESOURCE_ICONS[choice[1]])
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 16)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "Persistent collection: switches sources and waits for storage" if choice[1] != &"NONE" else "Finish any carried delivery, then stop"
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(func(): work_role_selected.emit(choice[1]))
		_worker_jobs.add_child(button)
	_cattle_controls = VBoxContainer.new()
	_cattle_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cattle_controls.visible = false
	_road_cancel = Button.new()
	_road_cancel.text = "Cancel unfinished path work"
	_road_cancel.tooltip_text = "Keep completed cells; recover only unused materials"
	_road_cancel.pressed.connect(func(): cancel_road_requested.emit(_inspected_road_id))
	_road_cancel.hide()
	column.add_child(_road_cancel)
	column.add_child(_cattle_controls)
	_pasture_choices = OptionButton.new()
	_pasture_choices.fit_to_longest_item = false
	_pasture_choices.clip_text = true
	_pasture_choices.text = "Choose pasture"
	_pasture_choices.tooltip_text = "Destination pasture and assigned cattle / grazing capacity"
	_pasture_choices.custom_minimum_size.y = GopalaTheme.NAV_CONTROL_HEIGHT
	_cattle_controls.add_child(_pasture_choices)
	var move := _tool_button("Move to pasture", "Walk to the selected grazing plot", "Move to pasture")
	move.pressed.connect(func():
		if _pasture_choices.selected >= 0:
			cattle_pasture_selected.emit(_pasture_choices.get_item_id(_pasture_choices.selected))
	)
	_cattle_controls.add_child(move)
	_field_controls = VBoxContainer.new()
	_field_controls.name = "FieldControls"
	_field_controls.visible = false
	_field_controls.add_theme_constant_override("separation", 5)
	column.add_child(_field_controls)
	var crop_row := _row(5)
	_field_controls.add_child(crop_row)
	crop_row.add_child(_label("Crop", GopalaTheme.font(GopalaTheme.FONT_UI, 600, 11), 11, GopalaTheme.PAPER))
	_field_crop_choices = OptionButton.new()
	_field_crop_choices.name = "FieldCropChoices"
	_field_crop_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field_crop_choices.custom_minimum_size.y = GopalaTheme.NAV_CONTROL_HEIGHT
	_field_crop_choices.add_item("Cereal grain")
	_field_crop_choices.set_item_metadata(0, &"cereal")
	_field_crop_choices.add_item("Fodder crop")
	_field_crop_choices.set_item_metadata(1, &"fodder_crop")
	crop_row.add_child(_field_crop_choices)
	_field_worker_choices = OptionButton.new()
	_field_worker_choices.name = "FieldWorkerChoices"
	_field_worker_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field_worker_choices.custom_minimum_size.y = GopalaTheme.NAV_CONTROL_HEIGHT
	_field_worker_choices.tooltip_text = "Free settler who will travel to and work this field"
	_field_controls.add_child(_field_worker_choices)
	_field_action_button = Button.new()
	_field_action_button.name = "FieldAction"
	_field_action_button.text = "Set crop"
	_field_action_button.tooltip_text = "Choose a crop on a fallow or harvested terrace, or assign a free worker to field work."
	_field_action_button.accessibility_name = "Field action"
	_field_action_button.custom_minimum_size.y = GopalaTheme.NAV_CONTROL_HEIGHT
	_field_action_button.focus_mode = Control.FOCUS_ALL
	_field_action_button.pressed.connect(func():
		if _inspected_field_id <= 0 or _field_action.is_empty(): return
		var worker_id := 0
		if _field_action == &"WORK":
			if _field_worker_choices.selected < 0: return
			worker_id = _field_worker_choices.get_item_id(_field_worker_choices.selected)
		var crop_id: StringName = _field_crop_choices.get_item_metadata(_field_crop_choices.selected)
		field_action_requested.emit(_field_action, _inspected_field_id, worker_id, crop_id)
	)
	_field_controls.add_child(_field_action_button)

func show_field_controls(field_id: int, stage: StringName, crop_id: StringName, workers: Array) -> void:
	_inspected_field_id = field_id
	_field_controls.visible = true
	var crop_stage := stage in [&"FALLOW", &"HARVESTED"]
	_field_crop_choices.get_parent().visible = crop_stage
	_field_crop_choices.visible = crop_stage
	_field_crop_choices.tooltip_text = "Choose which crop to prepare on this eligible terrace."
	var crop_index := 0
	for index in _field_crop_choices.item_count:
		if _field_crop_choices.get_item_metadata(index) == crop_id:
			crop_index = index
	_field_crop_choices.select(crop_index)
	var previous_worker := _field_worker_choices.get_selected_id()
	_field_worker_choices.clear()
	for worker in workers:
		_field_worker_choices.add_item("Settler #%d · %s" % [worker.id, worker.status], worker.id)
		if worker.id == previous_worker:
			_field_worker_choices.select(_field_worker_choices.item_count - 1)
	if _field_worker_choices.item_count > 0 and _field_worker_choices.selected < 0:
		_field_worker_choices.select(0)
	_field_action = &"SET_CROP" if crop_stage else (&"WORK" if stage in [&"PREPARING", &"GROWING", &"TENDING", &"DROUGHT", &"MATURE"] else &"")
	_field_worker_choices.visible = _field_action == &"WORK"
	_field_worker_choices.tooltip_text = "Free settler who will travel to and work this field"
	if stage == &"PREPARING":
		_field_worker_choices.tooltip_text = "Free settler who will prepare the selected crop"
	elif stage == &"MATURE":
		_field_worker_choices.tooltip_text = "Free settler who will harvest this crop"
	elif stage in [&"GROWING", &"TENDING", &"DROUGHT"]:
		_field_worker_choices.tooltip_text = "Free settler who will tend this crop"
	_field_action_button.text = "Set crop" if _field_action == &"SET_CROP" else ("Assign field work" if _field_action == &"WORK" else "No field action")
	if _field_action == &"WORK":
		_field_action_button.text = "Plant crop" if stage == &"PREPARING" else ("Harvest crop" if stage == &"MATURE" else "Tend field")
	_field_action_button.disabled = _field_action.is_empty() or (_field_action == &"WORK" and _field_worker_choices.item_count == 0)
	_field_worker_choices.disabled = _field_worker_choices.item_count == 0

func show_road_cancel(id: int, enabled: bool) -> void:
	_inspected_road_id = id
	_road_cancel.visible = enabled

func show_builder_sites(rows: Array) -> void:
	var previous_id := _builder_site_choices.get_selected_id() if _builder_site_choices.item_count > 0 else 0
	_builder_site_choices.clear()
	for row in rows:
		_builder_site_choices.add_item(String(row.label), int(row.id))
		if int(row.id) == previous_id:
			_builder_site_choices.select(_builder_site_choices.item_count - 1)
	if _builder_site_choices.item_count > 0 and _builder_site_choices.selected < 0:
		_builder_site_choices.select(0)
	_builder_assign_button.disabled = _builder_site_choices.item_count == 0
	_builder_site_choices.disabled = _builder_site_choices.item_count == 0

func selected_builder_site_id() -> int:
	return _builder_site_choices.get_selected_id() if _builder_site_choices.item_count > 0 and _builder_site_choices.selected >= 0 else 0

func set_builder_job_state(is_builder: bool) -> void:
	_builder_assign_button.disabled = is_builder or _builder_site_choices.item_count == 0
	_builder_release_button.disabled = not is_builder

func set_builder_job_availability(has_free_villager: bool, has_site: bool) -> void:
	_builder_assign_button.disabled = not has_free_villager or not has_site
	_builder_site_choices.disabled = not has_site
	_builder_assign_button.tooltip_text = "Assign a free villager to the selected unfinished site." if has_free_villager and has_site else ("No unstaffed construction sites." if not has_site else "This settler is already working at a site.")

func _build_build_bar() -> void:
	var shell := _panel(&"shell")
	shell.name = "StructurePicker"
	shell.anchor_left = 1.0
	shell.anchor_top = 0.0
	shell.anchor_right = 1.0
	shell.anchor_bottom = 1.0
	shell.offset_left = -14.0
	shell.offset_right = -14.0
	shell.offset_top = 60.0
	shell.offset_bottom = -14.0
	shell.visible = false
	shell.custom_minimum_size.y = 0
	shell.z_index = 10
	_build_bar_shell = shell
	# Theme/icon minimum sizes settle after insertion; re-fit the bounded region
	# when those metrics change rather than keeping its earlier oversized rect.
	shell.minimum_size_changed.connect(func(): _layout_hud.call_deferred())
	_root.add_child(shell)
	var plate := _panel(&"paper")
	plate.name = "StructurePickerPlate"
	shell.add_child(plate)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	plate.add_child(margin)
	var column := _column(7)
	margin.add_child(column)
	_build_section = _new_collapsible_section("Structures · B")
	column.add_child(_build_section)
	_build_section.set_collapsible(false)
	_build_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var close_picker := _tool_button("", "Close structures (B)", "✕")
	close_picker.pressed.connect(toggle_build_picker)
	_build_section.add_header_control(close_picker)
	var content := _build_section.body()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	_build_card = _panel(&"sunk")
	content.add_child(_build_card)
	var card_margin := MarginContainer.new()
	card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		card_margin.add_theme_constant_override("margin_" + side, 7)
	card_margin.add_theme_constant_override("margin_top", 7)
	card_margin.add_theme_constant_override("margin_bottom", 7)
	_build_card.add_child(card_margin)
	_build_card.custom_minimum_size.y = 76
	_build_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var card_text := _column(3)
	card_text.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_text.clip_contents = true
	card_margin.add_child(card_text)
	var card_heading := _row(4)
	card_text.add_child(card_heading)
	var glyph := _label("⌂", GopalaTheme.font(GopalaTheme.FONT_UI, 600, 16), 16, GopalaTheme.BRASS)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_heading.add_child(glyph)
	var heading_text := _column(0)
	heading_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_heading.add_child(heading_text)
	_build_title = _label("Choose a structure", GopalaTheme.font(GopalaTheme.FONT_DISPLAY, 500, 14), 14, GopalaTheme.INK)
	_build_title.custom_minimum_size.y = 19
	_build_title.clip_text = true
	heading_text.add_child(_build_title)
	_build_meta = _label("Select a tile to preview its footprint and cost.", GopalaTheme.font(GopalaTheme.FONT_UI, 400, 10), 10, GopalaTheme.INK_MUTED)
	_build_meta.custom_minimum_size.y = 15
	_build_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading_text.add_child(_build_meta)
	_build_costs = _label("", GopalaTheme.font(GopalaTheme.FONT_MONO, 500, 10), 10, GopalaTheme.BRASS_DARK)
	_build_costs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_costs.max_lines_visible = 2
	_build_costs.custom_minimum_size.y = 24
	_build_costs.clip_text = true
	card_text.add_child(_build_costs)
	_category_grid = GridContainer.new()
	_category_grid.name = "StructureCategories"
	_category_grid.columns = 7
	_category_grid.add_theme_constant_override("h_separation", 4)
	_category_grid.add_theme_constant_override("v_separation", 4)
	content.add_child(_category_grid)
	_category_group = ButtonGroup.new()
	for category in ["All", "Housing", "Storage", "Resources", "Food", "Water", "Pasture"]:
		var button := Button.new()
		button.name = "Category_" + category
		button.tooltip_text = "%s structures" % category if category != "All" else "All structures and zones"
		button.accessibility_name = category
		button.toggle_mode = true
		button.button_group = _category_group
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(32, 32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_constant_override("icon_max_width", 19)
		var icon_path: String = CATEGORY_ICONS.get(category, "")
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			button.icon = load(icon_path)
			button.expand_icon = true
		button.add_theme_stylebox_override("normal", _style(&"tab_normal"))
		button.add_theme_stylebox_override("hover", _style(&"tab_hover"))
		button.add_theme_stylebox_override("pressed", _style(&"tab_active"))
		button.add_theme_stylebox_override("focus", GopalaTheme.flat(Color.TRANSPARENT, 5, 2, GopalaTheme.BRASS_LIGHT))
		button.toggled.connect(func(on):
			if on:
				_select_category(category, on)
		)
		_category_grid.add_child(button)
		_tab_buttons.append(button)
	_tab_buttons[0].button_pressed = true
	var scroll := ScrollContainer.new()
	scroll.name = "StructureScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 100
	content.add_child(scroll)
	_structure_grid = GridContainer.new()
	_structure_grid.name = "StructureStrip"
	_structure_grid.columns = 3
	_structure_grid.add_theme_constant_override("h_separation", 5)
	_structure_grid.add_theme_constant_override("v_separation", 5)
	_structure_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_structure_grid)
	_populate_structures(_structure_grid)
	_build_toggle = _tool_button("", "Open structure picker (B)", "▦")
	_build_toggle.name = "StructurePickerToggle"
	_build_toggle.toggle_mode = true
	_build_toggle.custom_minimum_size = Vector2(28, 28)
	_build_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_build_toggle.offset_left = -42.0
	_build_toggle.offset_right = -14.0
	_build_toggle.offset_top = 154.0
	_build_toggle.offset_bottom = 182.0
	_build_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_toggle.pressed.connect(toggle_build_picker)
	_build_toggle.z_index = 11
	_root.add_child(_build_toggle)
	_refresh_build_toggle()

func _populate_structures(strip: GridContainer) -> void:
	_build_entries.clear()
	var catalog := _catalog()
	for path in catalog.get("buildings", []):
		var definition := load(path) as GopalaBuildingDefinition
		if definition == null:
			continue
		var entry := {"definition": definition, "category": _category_for(definition.id), "button": _structure_button(definition)}
		_build_entries.append(entry)
		strip.add_child(entry["button"])
	var road_button := Button.new()
	road_button.name = "Road_DirtPath"
	road_button.tooltip_text = "Dirt path\nDrag to preview; release to place. Shortcut: R"
	road_button.text = "Dirt path"
	road_button.icon = load("res://assets/ui/icons/road.svg")
	road_button.expand_icon = true
	road_button.add_theme_constant_override("icon_max_width", 24)
	road_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	road_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	road_button.accessibility_name = "Dirt path"
	road_button.focus_mode = Control.FOCUS_ALL
	road_button.custom_minimum_size = Vector2(64, 72)
	road_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	road_button.add_theme_font_size_override("font_size", 10)
	road_button.add_theme_stylebox_override("normal", _style(&"paper_raised"))
	road_button.add_theme_stylebox_override("hover", GopalaTheme.flat(GopalaTheme.NAV_RAISED, 5, 1, GopalaTheme.BRASS_DARK))
	road_button.add_theme_stylebox_override("pressed", GopalaTheme.flat(GopalaTheme.BRASS, 10))
	road_button.pressed.connect(activate_road_mode)
	_build_entries.append({"definition": null, "category": "All", "button": road_button})
	strip.add_child(road_button)
	var cobbled_button := Button.new()
	cobbled_button.name = "Road_CobbledPath"
	cobbled_button.tooltip_text = "Cobbled path upgrade\nSelect finished dirt, then drag. Builders deliver materials before paving. Stone 2 + timber 1 per cell. Shortcut: Shift+R"
	cobbled_button.text = "Pave"
	cobbled_button.icon = load("res://assets/ui/icons/grid_fine.svg")
	cobbled_button.expand_icon = true
	cobbled_button.add_theme_constant_override("icon_max_width", 24)
	cobbled_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	cobbled_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cobbled_button.accessibility_name = "Cobbled path upgrade"
	cobbled_button.focus_mode = Control.FOCUS_ALL
	cobbled_button.custom_minimum_size = Vector2(64, 72)
	cobbled_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cobbled_button.add_theme_font_size_override("font_size", 10)
	cobbled_button.add_theme_stylebox_override("normal", _style(&"paper_raised"))
	cobbled_button.add_theme_stylebox_override("hover", GopalaTheme.flat(GopalaTheme.NAV_RAISED, 5, 1, GopalaTheme.BRASS_DARK))
	cobbled_button.add_theme_stylebox_override("pressed", GopalaTheme.flat(GopalaTheme.BRASS, 10))
	cobbled_button.pressed.connect(activate_cobbled_path_mode)
	_build_entries.append({"definition": null, "category": "All", "button": cobbled_button})
	strip.add_child(cobbled_button)
	for zone_path in catalog.get("zones", []):
		var zone := load(zone_path) as GopalaZoneDefinition
		if zone == null:
			continue
		var entry := {"definition": zone, "category": "Food" if zone.id == &"field" else "Pasture", "button": _zone_button(zone)}
		_build_entries.append(entry)
		strip.add_child(entry["button"])
	_refresh_strip()

func _category_for(id: StringName) -> String:
	match id:
		&"dwelling": return "Housing"
		&"stockpile": return "Storage"
		&"timber_camp": return "Resources"
		&"gatherer_shelter",		&"cattle_shelter", &"field": return "Food"
		&"water_point": return "Water"
		&"pasture": return "Pasture"
	return "All"

func _structure_button(definition: GopalaBuildingDefinition) -> Button:
	var button := Button.new()
	button.name = "Structure_" + String(definition.id)
	button.tooltip_text = "%s\nFootprint %d × %d · %d work\n%s" % [definition.display_name, definition.footprint.x, definition.footprint.y, definition.work_ticks, _cost_text(definition.costs)]
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(64, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = String(BUILDING_LABELS.get(definition.id, definition.display_name))
	button.accessibility_name = definition.display_name
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_constant_override("icon_max_width", 25)
	button.add_theme_stylebox_override("normal", _style(&"paper_raised"))
	button.add_theme_stylebox_override("hover", GopalaTheme.flat(GopalaTheme.NAV_RAISED, 5, 1, GopalaTheme.BRASS_DARK))
	button.add_theme_stylebox_override("pressed", GopalaTheme.flat(GopalaTheme.BRASS, 10))
	button.add_theme_stylebox_override("hover_pressed", GopalaTheme.flat(GopalaTheme.BRASS_DARK, 10))
	button.add_theme_stylebox_override("focus", GopalaTheme.flat(Color.TRANSPARENT, 5, 2, GopalaTheme.BRASS_LIGHT))
	var icon_path: String = BUILDING_ICONS.get(definition.id, "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		button.icon = load(icon_path)
		button.expand_icon = true
	elif definition.prototype_sprite != null:
		button.icon = definition.prototype_sprite
		button.expand_icon = true
	button.toggled.connect(func(on):
		if on:
			_choose_build(definition.id, definition.display_name, "%d × %d footprint · %d work" % [definition.footprint.x, definition.footprint.y, definition.work_ticks], _cost_text(definition.costs))
		elif _selected_build == definition.id:
			clear_build()
	)
	return button

func _zone_button(zone: GopalaZoneDefinition) -> Button:
	var button := Button.new()
	button.name = "Structure_" + String(zone.id)
	button.tooltip_text = "%s\nZone · at least %d cells" % [zone.display_name, zone.minimum_cells]
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(64, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = String(BUILDING_LABELS.get(zone.id, zone.display_name))
	button.accessibility_name = zone.display_name
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_constant_override("icon_max_width", 25)
	button.add_theme_stylebox_override("normal", _style(&"paper_raised"))
	button.add_theme_stylebox_override("hover", GopalaTheme.flat(GopalaTheme.NAV_RAISED, 5, 1, GopalaTheme.BRASS_DARK))
	button.add_theme_stylebox_override("pressed", GopalaTheme.flat(GopalaTheme.BRASS, 10))
	button.add_theme_stylebox_override("hover_pressed", GopalaTheme.flat(GopalaTheme.BRASS_DARK, 10))
	button.add_theme_stylebox_override("focus", GopalaTheme.flat(Color.TRANSPARENT, 5, 2, GopalaTheme.BRASS_LIGHT))
	var icon_path: String = BUILDING_ICONS.get(zone.id, "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		button.icon = load(icon_path)
		button.expand_icon = true
	button.toggled.connect(func(on):
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

func button_for(id: StringName) -> Button:
	if id == &"dirt_path":
		for entry in _build_entries:
			if entry["button"].name == "Road_DirtPath": return entry["button"]
	elif id == &"cobbled_path":
		for entry in _build_entries:
			if entry["button"].name == "Road_CobbledPath": return entry["button"]
	for entry in _build_entries:
		var definition: Resource = entry["definition"]
		if definition != null and definition.get("id") == id:
			return entry["button"]
	return null

func _refresh_strip() -> void:
	for entry in _build_entries:
		var button: Button = entry["button"]
		var shown: bool = entry["category"] == _active_category or _active_category == "All"
		button.visible = shown
		if not shown and button.button_pressed:
			button.set_pressed_no_signal(false)

func _choose_build(id: StringName, title: String, meta: String, costs: String) -> void:
	if _road_tool_button != null: _road_tool_button.set_pressed_no_signal(false)
	_road_mode = false
	_selected_build = id
	_placement_active = true
	_build_title.text = title
	_build_meta.text = meta
	_build_costs.text = costs
	_build_card.add_theme_stylebox_override("panel", _style(&"sunk"))
	build_selected.emit(id)

func activate_road_mode() -> void:
	if _road_mode:
		clear_build()
		return
	_road_mode = true
	if _road_tool_button != null: _road_tool_button.set_pressed_no_signal(true)
	_cobbled_path_mode = false
	_selected_build = &"dirt_path"
	_placement_active = true
	_build_title.text = "Dirt path"
	_build_meta.text = "Drag to plan a route. An idle settler prepares each cell when time runs."
	_build_costs.text = "No materials · 4 work ticks/cell · finished speed ×1.25"
	_build_card.add_theme_stylebox_override("panel", _style(&"sunk"))
	road_mode_requested.emit()

func activate_cobbled_path_mode() -> void:
	if _cobbled_path_mode:
		clear_build()
		return
	var road_button := button_for(&"dirt_path")
	if road_button != null and road_button.button_pressed:
		road_button.set_pressed_no_signal(false)
	_road_mode = true
	if _road_tool_button != null: _road_tool_button.set_pressed_no_signal(true)
	_cobbled_path_mode = true
	_selected_build = &"cobbled_path"
	_placement_active = true
	_build_title.text = "Cobbled path"
	_build_meta.text = "Drag along one existing dirt stretch to upgrade it."
	_build_costs.text = "Per cell · 2 stone + 1 timber · speed ×1.6"
	_build_card.add_theme_stylebox_override("panel", _style(&"sunk"))
	cobbled_path_mode_requested.emit()

func clear_build() -> void:
	if _road_tool_button != null: _road_tool_button.set_pressed_no_signal(false)
	_selected_build = StringName("")
	_placement_active = false
	_road_mode = false
	_cobbled_path_mode = false
	_build_title.text = "Choose a structure"
	_build_meta.text = "Select an icon to see its footprint and cost."
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

func _build_view_tools() -> void:
	_view_tools_shell = _panel(&"paper")
	_view_tools_shell.name = "CommandDock"
	_view_tools_shell.add_theme_stylebox_override("panel", GopalaTheme.flat(GopalaTheme.NAV_SURFACE, 5, 1, GopalaTheme.NAV_BORDER, 8, 6))
	_view_tools_shell.z_index = 5
	_view_tools_shell.visible = false
	_root.add_child(_view_tools_shell)
	_view_section = _new_collapsible_section("Commands")
	_view_tools_shell.add_child(_view_section)
	_view_section.set_collapsible(false)
	_view_section.header().hide()
	var row := _row(6)
	_view_section.body().add_child(row)
	# Move existing tempo controls into one permanent dock; no duplicate commands.
	var tempo_row := _pause_button.get_parent()
	tempo_row.get_parent().remove_child(tempo_row)
	row.add_child(tempo_row)
	row.add_child(_vertical_divider())
	_build_toggle.reparent(row)
	_build_toggle.custom_minimum_size = Vector2(72, 32)
	_build_toggle.text = "Build"
	_build_toggle.icon = load("res://assets/ui/icons/hammer.svg")
	_build_toggle.add_theme_constant_override("icon_max_width", 18)
	_build_toggle.expand_icon = true
	for action in [["Settlement", "person_body", "Settlement needs and objective"], ["Survey", "compass", "View tools and survey"], ["Map", "map", "Toggle valley map"], ["Stock", "chest", "Resource overview (M)"], ["Workers", "person_body", "Workforce priorities and assignments (J)"]]:
		var button := _dock_button(action[0], action[1], action[2])
		row.add_child(button)
		match action[0]:
			"Settlement": button.pressed.connect(toggle_settlement_panel)
			"Survey": button.pressed.connect(toggle_survey_panel)
			"Map": button.pressed.connect(toggle_map_panel)
			"Stock": button.pressed.connect(show_resource_overview)
			"Workers": button.pressed.connect(show_workforce_panel)
	var road := _dock_button("Road", "road", "Place a dirt path (R); Shift+R upgrades")
	_road_tool_button = road
	road.toggle_mode = true
	road.pressed.connect(activate_road_mode)
	row.add_child(road)
	row.add_child(_vertical_divider())
	for tool in [["−", "Zoom out"], ["+", "Zoom in"], ["↺", "Turn left"], ["↻", "Turn right"]]:
		var button := _tool_button("", String(tool[1]), String(tool[0]))
		if tool[0] == "−": button.pressed.connect(func(): zoom_out_requested.emit())
		elif tool[0] == "+": button.pressed.connect(func(): zoom_in_requested.emit())
		elif tool[0] == "↺": button.pressed.connect(func(): turn_left_requested.emit())
		else: button.pressed.connect(func(): turn_right_requested.emit())
		row.add_child(button)

func _dock_button(label_text: String, icon_name: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.tooltip_text = tooltip
	button.accessibility_name = label_text
	button.custom_minimum_size = Vector2(64, 32)
	button.icon = load("res://assets/ui/icons/%s.svg" % icon_name)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 18)
	return button

func toggle_map_panel() -> void:
	_minimap_shell.visible = not _minimap_shell.visible
	if _minimap_shell.visible:
		_build_bar_shell.hide()
		hide_inspection()
	_refresh_build_toggle()

func close_top_panel() -> bool:
	if _workforce_panel != null and _workforce_panel.visible:
		_workforce_panel.hide()
		return true
	if _inspection.get_parent().visible:
		hide_inspection()
		return true
	for panel in [_build_bar_shell, _minimap_shell, _status_shell, _survival_panel]:
		if panel != null and panel.visible:
			panel.hide()
			_refresh_build_toggle()
			return true
	return false

func toggle_settlement_panel() -> void:
	if _survival_panel == null: return
	_survival_panel.visible = not _survival_panel.visible
	_status_shell.hide()
	_layout_hud()

func toggle_survey_panel() -> void:
	_status_shell.visible = not _status_shell.visible
	if _survival_panel != null: _survival_panel.hide()
	_layout_hud()

func set_other_hud_visible(show: bool) -> void:
	_hud_enabled = show
	_view_tools_shell.visible = show
	if _summary_strip != null: _summary_strip.visible = show
	if not show:
		for shell in [_status_shell, _minimap_shell, _build_bar_shell, _survival_panel]:
			if shell != null: shell.hide()
		hide_inspection()
	if _alert_panel != null: _alert_panel.visible = show and not _alert_buttons.is_empty()

func toggle_build_picker() -> void:
	if _build_bar_shell == null: return
	_build_bar_shell.visible = not _build_bar_shell.visible
	if _build_bar_shell.visible:
		hide_inspection()
		_minimap_shell.hide()
	_refresh_build_toggle()
	_layout_hud()

func _refresh_build_toggle() -> void:
	if _build_toggle == null or _build_bar_shell == null: return
	_build_toggle.visible = true
	_build_toggle.text = "Build"
	_build_toggle.set_pressed_no_signal(_build_bar_shell.visible)
	_build_toggle.tooltip_text = "Close structures (B)" if _build_bar_shell.visible else "Open structures (B)"

func _layout_hud() -> void:
	if _root == null or _view_tools_shell == null: return
	var viewport_size := _root.size
	if viewport_size.x < 1 or viewport_size.y < 1: return
	var right_width := clampf(viewport_size.x * 0.25, 310.0, 360.0)
	var panel_height := minf(560.0, viewport_size.y - 160.0)
	_place_region(_build_bar_shell, Rect2(viewport_size.x - right_width - 12, 96, right_width, minf(440, panel_height)))
	var inspection_shell := _inspection.get_parent() as Control
	_place_region(inspection_shell, Rect2(viewport_size.x - right_width - 12, 96, right_width, 70 if _inspection_section.collapsed else panel_height))
	inspection_shell.z_index = 10
	_place_region(_status_shell, Rect2(12, 96, 300, 140 if not _status_section.collapsed else 52))
	if _survival_panel != null:
		_place_region(_survival_panel, Rect2(12, 96, 300, 350 if not _survival_section.collapsed else 56))
	_place_region(_minimap_shell, Rect2(viewport_size.x - 196, 96, 184, 42 if _minimap_section.collapsed else 152))
	if _alert_panel != null:
		_place_region(_alert_panel, Rect2(12, viewport_size.y - (222 if not _alerts_section.collapsed else 112), 300, 152 if not _alerts_section.collapsed else 42))
	_place_region(_view_tools_shell, Rect2(12, viewport_size.y - 56, _view_tools_shell.get_combined_minimum_size().x, 44))
	if _summary_strip != null:
		var text_width := _summary_readout.get_theme_font("font").get_string_size(_summary_readout.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _summary_readout.get_theme_font_size("font_size")).x + 20
		_place_region(_summary_strip, Rect2(12, 58, minf(text_width, viewport_size.x - 24), 30))
	if _notification_stack != null:
		_place_region(_notification_stack, Rect2(viewport_size.x * 0.5 - 170, 96, 340, 0))

func _place_region(control: Control, rect: Rect2) -> void:
	# Preserve the current offsets: resetting to minimum size on every layout pass
	# changes text wrapping and can continuously retrigger minimum-size layout.
	control.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	control.position = rect.position
	control.size = rect.size

func _build_toasts() -> void:
	_toast_stack = VBoxContainer.new()
	_toast_stack.name = "ToastStack"
	_toast_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_stack.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_toast_stack.offset_left = 16.0
	_toast_stack.offset_bottom = -16.0
	_toast_stack.alignment = BoxContainer.ALIGNMENT_END
	_toast_stack.add_theme_constant_override("separation", _tokens.space_2)
	_root.add_child(_toast_stack)

func notify(title: String, body: String, tone: String = "river") -> void:
	# Use new NotificationStack if available, fallback to legacy toast system
	if _notification_stack != null:
		var message: String = title
		if not body.is_empty():
			message += "\n" + body
		_notification_stack.push(message)
		return

	# Legacy toast system
	if _toast_stack == null: return
	var style := &"river"
	match tone:
		"forest": style = &"forest"
		"terra": style = &"terra"
		_: style = &"river"
	var toast := _panel(style)
	var row := _column(2)
	row.add_child(_label(title, GopalaTheme.font(GopalaTheme.FONT_DISPLAY, 600, 14), 14, GopalaTheme.NAV_TEXT))
	var detail := _label(body, GopalaTheme.font(GopalaTheme.FONT_UI, 400, 12), 12, GopalaTheme.NAV_MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(detail)
	toast.add_child(row)
	_toast_stack.add_child(toast)
	var timer := get_tree().create_timer(TOAST_LIFETIME)
	timer.timeout.connect(func():
		if is_instance_valid(toast): toast.queue_free()
	)

func follow(camera: Camera3D) -> void:
	if camera == null or _minimap == null:
		return
	_minimap.set_view(camera.target, float(camera.size))

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

func toggle_grid() -> void:
	if _grid_button != null:
		_grid_button.button_pressed = not _grid_button.button_pressed

func toggle_names() -> void:
	if _names_button != null:
		_names_button.button_pressed = not _names_button.button_pressed

func _compact_stock(amount: int) -> String:
	if amount < 10000: return str(amount)
	if amount < 1000000: return "%dK" % floori(float(amount) / 1000.0)
	if amount < 1000000000: return "%.1fM" % (float(amount) / 1000000.0)
	return "%.1fB" % (float(amount) / 1000000000.0)

func set_resource(id: StringName, amount: int) -> void:
	if _resource_slots.has(id):
		var label: Label = _resource_slots[id]
		if label.text != _compact_stock(amount):
			label.text = _compact_stock(amount)
		var button: Button = _resource_buttons[id]
		button.tooltip_text = "%s · %d units\nOpen resource overview" % [String(id).replace("_", " ").capitalize(), amount]
		if _resource_overview != null:
			_resource_overview.set_stock(id, amount)


func set_health(current: int, maximum: int = 100) -> void:
	if _health_bar != null:
		_health_bar.set_health(current, maximum)
		_show_health_bar()


func _show_health_bar() -> void:
	if _health_visibility_tween != null: _health_visibility_tween.kill()
	if _health_bar == null or _health_bar.visible:
		if _health_bar != null: _health_bar.modulate.a = 1.0
		return
	_health_bar.visible = true
	_health_bar.modulate.a = 0.0
	var tween := create_tween()
	_health_visibility_tween = tween
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_health_bar, "modulate:a", 1.0, 0.3)


func hide_health_bar() -> void:
	if _health_visibility_tween != null: _health_visibility_tween.kill()
	if _health_bar == null or not _health_bar.visible:
		return
	var tween := create_tween()
	_health_visibility_tween = tween
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_health_bar, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func(): _health_bar.visible = false)


func set_clock(day: int, year: int, season: String) -> void:
	if _clock_line != null:
		_clock_line.text = "Day %d · Year %d" % [day, year]
	if _season_line != null:
		_season_line.text = season

func set_settlement_name(value: String) -> void:
	if _settlement_name != null:
		_settlement_name.text = value
		_settlement_name.tooltip_text = value

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
	_show_inspection("Chiefdoms", "Four tributary domains", String(MODE_HINTS.get(mode_name, "")), "\n".join(lines) + "\n[i]Jurisdiction lines are a reconstruction from drainage and relief. No Gopal-period frontier is attested.[/i]")

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
	body.append("[i]Border basis: %s · Evidential confidence: %s[/i]" % [String(chiefdom.get("role", "")).to_lower(), String(chiefdom.get("evidential_confidence", "unknown")).to_upper()])
	_show_inspection("Chiefdom", String(chiefdom.get("name", "")), "Today: %s" % String(chiefdom.get("modern", "")), "\n".join(body))

func hide_chiefdom() -> void:
	hide_inspection()

func hide_inspection() -> void:
	if _inspection == null:
		return
	var shell := _inspection.get_parent() as Control
	if shell != null and shell != _root:
		shell.visible = false
	if _inspection_section != null:
		_inspection_section.set_collapsed(false, false)
	hide_health_bar()

func _show_inspection(eyebrow: String, title: String, detail: String, body: String) -> void:
	if _road_cancel != null: _road_cancel.hide()
	if eyebrow != "Settler" and _health_bar != null:
		if _health_visibility_tween != null: _health_visibility_tween.kill()
		_health_bar.hide()
	if _worker_jobs != null: _worker_jobs.visible = false
	if _builder_jobs != null: _builder_jobs.visible = false
	if _cattle_controls != null: _cattle_controls.visible = false
	if _field_controls != null: _field_controls.visible = false
	var shell := _inspection.get_parent() as Control
	if shell != null:
		shell.visible = true
	_build_bar_shell.hide()
	_minimap_shell.hide()
	_refresh_build_toggle()
	_layout_hud()
	_inspection_section.set_title(eyebrow)
	_inspect_title.text = title
	_inspect_detail.text = detail
	_inspect_detail.visible = not detail.is_empty()
	_inspect_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_body.text = body.replace("[data]", "[color=#d6c79f]").replace("[/data]", "[/color]")
	_inspect_body.visible = not body.is_empty()

func configure_survey(terrain_ref: GopalaKathmanduTerrain, regions: Array) -> void:
	terrain = terrain_ref
	if _minimap != null:
		_minimap.configure(terrain_ref, regions)

func _catalog() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	return parsed if parsed is Dictionary else {}

func set_tempo(paused: bool, speed: int) -> void:
	if _season_line != null: _season_line.text = "Paused" if paused else "%d× speed" % speed
	if _pause_button != null: _pause_button.set_pressed_no_signal(paused)
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(not paused and [1, 2, 4][i] == speed)

func set_simulation_tick(tick: int) -> void:
	if _clock_line != null: _clock_line.text = "Tick %d" % tick

func apply_ui_scale(value: float) -> void:
	_scale_text(_root, clampf(value, 0.8, 1.5))

func _scale_text(node: Node, value: float) -> void:
	if node is Control:
		if not node.has_meta("base_font_size"):
			node.set_meta("base_font_size", node.get_theme_font_size("font_size"))
		node.add_theme_font_size_override("font_size", roundi(int(node.get_meta("base_font_size")) * value))
	for child in node.get_children():
		_scale_text(child, value)

func show_cattle_controls(rows: Array) -> void:
	_cattle_controls.visible = not rows.is_empty()
	var signature := str(rows)
	if signature == _pasture_signature:
		return
	_pasture_signature = signature
	var previous := _pasture_choices.get_selected_id()
	_pasture_choices.clear()
	for row in rows:
		_pasture_choices.add_item(row.label, row.id)
		if row.id == previous:
			_pasture_choices.select(_pasture_choices.item_count - 1)

func bind_workforce(simulation: GopalaSettlementSimulation) -> void:
	if _workforce_panel == null:
		_workforce_panel = GopalaWorkforcePanel.new()
		_workforce_panel.theme = GopalaTheme.navbar()
		add_child(_workforce_panel)
	_workforce_panel.bind_simulation(simulation)

func show_workforce_panel() -> void:
	if _workforce_panel != null: _workforce_panel.popup_centered_clamped(Vector2i(880,720),0.9)
