extends Control
## Development-only component gallery: renders every Block 1 component in
## every supported state using sample data held entirely inside this scene.
## It is never registered as a gameplay snapshot provider - Block 1 has no
## provider registry by contract (UI_CONTRACT.md section 7).

const ICON_BUTTON_SCENE := preload("res://scenes/ui/components/icon_button/icon_button.tscn")
const RESOURCE_CHIP_SCENE := preload("res://scenes/ui/components/resource_chip/resource_chip.tscn")
const STAT_ROW_SCENE := preload("res://scenes/ui/components/stat_row/stat_row.tscn")
const STATUS_BADGE_SCENE := preload("res://scenes/ui/components/status_badge/status_badge.tscn")
const TAB_BUTTON_SCENE := preload("res://scenes/ui/components/tab_button/tab_button.tscn")
const PROGRESS_METER_SCENE := preload("res://scenes/ui/components/progress_meter/progress_meter.tscn")
const ALERT_ITEM_SCENE := preload("res://scenes/ui/components/alert_item/alert_item.tscn")
const PANEL_SHELL_SCENE := preload("res://scenes/ui/components/panel_shell/panel_shell.tscn")
const SHORTCUT_TOOLTIP_SCENE := preload("res://scenes/ui/components/shortcut_tooltip/shortcut_tooltip.tscn")

var _tokens: UITokens = UITokens.new()
var _targets: Array[Control] = []
var _scroll: ScrollContainer
var _sections: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GopalaTheme.build()
	_build_layout()

# ----------------------------------------------------------------- building

func _build_layout() -> void:
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_sections = VBoxContainer.new()
	_sections.name = "Sections"
	_sections.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sections.add_theme_constant_override("separation", _tokens.space_3)
	_scroll.add_child(_sections)

	_build_buttons()
	_build_tabs()
	_build_chips()
	_build_stats()
	_build_badges()
	_build_meters()
	_build_alerts()
	_build_panels()
	_build_tooltips()

func _register(control: Control) -> Control:
	_targets.append(control)
	return control

func _section(title: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = "Section_" + title.replace(" ", "")
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = title
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(heading)
	_sections.add_child(section)
	_register(section)
	return section

func _hrow() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", _tokens.space_2)
	return row

func _long_text() -> String:
	return "Localized long string sample ".repeat(12)

func _build_buttons() -> void:
	var section := _section("Icon buttons")
	var row := _hrow()
	section.add_child(row)
	var default_button := ICON_BUTTON_SCENE.instantiate() as GopalaIconButton
	default_button.name = "IconButton_Default"
	_register(default_button)
	row.add_child(default_button)
	default_button.action = &"tool_select"
	default_button.set_label("Select")
	var action_button := ICON_BUTTON_SCENE.instantiate() as GopalaIconButton
	action_button.name = "IconButton_Action"
	_register(action_button)
	row.add_child(action_button)
	action_button.action = &"tool_build"
	action_button.set_label("Build")
	var disabled_button := ICON_BUTTON_SCENE.instantiate() as GopalaIconButton
	disabled_button.name = "IconButton_Disabled"
	_register(disabled_button)
	row.add_child(disabled_button)
	disabled_button.disabled = true
	disabled_button.set_label("Road")
	disabled_button.tooltip_text = "Unavailable while the simulation is paused"
	var selected_button := ICON_BUTTON_SCENE.instantiate() as GopalaIconButton
	selected_button.name = "IconButton_Selected"
	_register(selected_button)
	row.add_child(selected_button)
	selected_button.selectable = true
	selected_button.action = &"tool_zone"
	selected_button.set_label("Zone")
	selected_button.set_selected(true)
	var long_button := ICON_BUTTON_SCENE.instantiate() as GopalaIconButton
	long_button.name = "IconButton_Long"
	_register(long_button)
	row.add_child(long_button)
	long_button.action = &"tool_harvest"
	long_button.set_label("A very long localized action label for clipping checks")

func _build_tabs() -> void:
	var section := _section("Tabs")
	var row := _hrow()
	section.add_child(row)
	var tab_a := TAB_BUTTON_SCENE.instantiate() as GopalaTabButton
	tab_a.name = "Tab_Default"
	_register(tab_a)
	row.add_child(tab_a)
	tab_a.set_label("Overview")
	var tab_b := TAB_BUTTON_SCENE.instantiate() as GopalaTabButton
	tab_b.name = "Tab_Selected"
	_register(tab_b)
	row.add_child(tab_b)
	tab_b.set_label("Storage")
	tab_b.set_selected(true)
	var tab_c := TAB_BUTTON_SCENE.instantiate() as GopalaTabButton
	tab_c.name = "Tab_Disabled"
	_register(tab_c)
	row.add_child(tab_c)
	tab_c.disabled = true
	tab_c.set_label("Trade")
	var tab_d := TAB_BUTTON_SCENE.instantiate() as GopalaTabButton
	tab_d.name = "Tab_Long"
	_register(tab_d)
	row.add_child(tab_d)
	tab_d.set_label("Ein sehr langer lokalisierter Reitername mit Zusatztext")
	# Keyboard focus path: neighbors are valid only once both tabs are in tree.
	tab_a.focus_neighbor_right = tab_b.get_path()
	tab_b.focus_neighbor_left = tab_a.get_path()

func _build_chips() -> void:
	var section := _section("Resource chips")
	var row := _hrow()
	section.add_child(row)
	var normal_chip := RESOURCE_CHIP_SCENE.instantiate() as GopalaResourceChip
	normal_chip.name = "Chip_Normal"
	_register(normal_chip)
	row.add_child(normal_chip)
	normal_chip.set_display_name("Timber")
	normal_chip.set_amount(128)
	var warning_chip := RESOURCE_CHIP_SCENE.instantiate() as GopalaResourceChip
	warning_chip.name = "Chip_Warning"
	_register(warning_chip)
	row.add_child(warning_chip)
	warning_chip.set_display_name("Wild food")
	warning_chip.set_amount(3)
	warning_chip.set_warning(true, "Below reserve threshold: 3 < 10")
	var disabled_chip := RESOURCE_CHIP_SCENE.instantiate() as GopalaResourceChip
	disabled_chip.name = "Chip_Disabled"
	_register(disabled_chip)
	row.add_child(disabled_chip)
	disabled_chip.set_display_name("Milk")
	disabled_chip.set_amount(0)
	disabled_chip.set_disabled_state(true, "No storage building available")
	var interactive_chip := RESOURCE_CHIP_SCENE.instantiate() as GopalaResourceChip
	interactive_chip.name = "Chip_Interactive"
	interactive_chip.interactive = true
	_register(interactive_chip)
	row.add_child(interactive_chip)
	interactive_chip.set_display_name("Stone")
	interactive_chip.set_amount(64)
	var long_chip := RESOURCE_CHIP_SCENE.instantiate() as GopalaResourceChip
	long_chip.name = "Chip_Long"
	_register(long_chip)
	row.add_child(long_chip)
	long_chip.set_display_name(_long_text())
	long_chip.set_amount(7)

func _build_stats() -> void:
	var section := _section("Stat rows")
	var normal_row := STAT_ROW_SCENE.instantiate() as GopalaStatRow
	normal_row.name = "StatRow_Normal"
	_register(normal_row)
	section.add_child(normal_row)
	normal_row.set_key("Population")
	normal_row.set_value_text("8 / 12")
	var warning_row := STAT_ROW_SCENE.instantiate() as GopalaStatRow
	warning_row.name = "StatRow_Warning"
	_register(warning_row)
	section.add_child(warning_row)
	warning_row.set_key("Food months")
	warning_row.set_value_text("1.2")
	warning_row.set_warning(true)
	var long_row := STAT_ROW_SCENE.instantiate() as GopalaStatRow
	long_row.name = "StatRow_Long"
	_register(long_row)
	section.add_child(long_row)
	long_row.set_key(_long_text())
	long_row.set_value_text("42")

func _build_badges() -> void:
	var section := _section("Status badges")
	var row := _hrow()
	section.add_child(row)
	var labels := {
		&"neutral": "Neutral",
		&"positive": "Healthy",
		&"warning": "Low",
		&"critical": "Critical",
		&"disabled": "Locked",
	}
	for severity in [&"neutral", &"positive", &"warning", &"critical", &"disabled"]:
		var badge := STATUS_BADGE_SCENE.instantiate() as GopalaStatusBadge
		badge.name = "Badge_" + String(severity)
		_register(badge)
		row.add_child(badge)
		badge.set_severity(severity)
		badge.set_text(labels[severity])
	var long_badge := STATUS_BADGE_SCENE.instantiate() as GopalaStatusBadge
	long_badge.name = "Badge_Long"
	_register(long_badge)
	row.add_child(long_badge)
	long_badge.set_severity(&"warning")
	long_badge.set_text(_long_text())

func _build_meters() -> void:
	var section := _section("Progress meters")
	var row := _hrow()
	section.add_child(row)
	var plain_meter := PROGRESS_METER_SCENE.instantiate() as GopalaProgressMeter
	plain_meter.name = "Meter_Plain"
	_register(plain_meter)
	row.add_child(plain_meter)
	plain_meter.set_fraction(0.3)
	var warn_meter := PROGRESS_METER_SCENE.instantiate() as GopalaProgressMeter
	warn_meter.name = "Meter_Warning"
	_register(warn_meter)
	row.add_child(warn_meter)
	warn_meter.warn_below = 0.6
	warn_meter.set_fraction(0.55)
	warn_meter.set_warning(true, "Storage is below the target level")
	var disabled_meter := PROGRESS_METER_SCENE.instantiate() as GopalaProgressMeter
	disabled_meter.name = "Meter_Disabled"
	_register(disabled_meter)
	row.add_child(disabled_meter)
	disabled_meter.set_fraction(0.9)
	disabled_meter.set_disabled_state(true)

func _build_alerts() -> void:
	var section := _section("Alerts")
	var info_alert := ALERT_ITEM_SCENE.instantiate() as GopalaAlertItem
	info_alert.name = "Alert_Info"
	_register(info_alert)
	section.add_child(info_alert)
	info_alert.set_alert(&"alert_info", &"neutral", "Granary constructed", true)
	var warning_alert := ALERT_ITEM_SCENE.instantiate() as GopalaAlertItem
	warning_alert.name = "Alert_Warning"
	_register(warning_alert)
	section.add_child(warning_alert)
	warning_alert.set_alert(&"alert_warning", &"warning", "Two settlers have no assigned home", true)
	var critical_alert := ALERT_ITEM_SCENE.instantiate() as GopalaAlertItem
	critical_alert.name = "Alert_CriticalDisabled"
	_register(critical_alert)
	section.add_child(critical_alert)
	critical_alert.set_alert(&"alert_critical", &"critical", "Fire risk in the storage district", true)
	critical_alert.set_action_enabled(false, "Requires a watchtower before it can be located")
	var long_alert := ALERT_ITEM_SCENE.instantiate() as GopalaAlertItem
	long_alert.name = "Alert_Long"
	_register(long_alert)
	section.add_child(long_alert)
	long_alert.set_alert(&"alert_long", &"neutral", _long_text(), false)

func _build_panels() -> void:
	var section := _section("Panel shells")
	var interactive_shell := PANEL_SHELL_SCENE.instantiate() as GopalaPanelShell
	interactive_shell.name = "Shell_Interactive"
	_register(interactive_shell)
	section.add_child(interactive_shell)
	var inner_row := STAT_ROW_SCENE.instantiate() as GopalaStatRow
	inner_row.name = "StatRow_InShell"
	_register(inner_row)
	interactive_shell.body().add_child(inner_row)
	inner_row.set_key("Housing capacity")
	inner_row.set_value_text("12 / 16")
	var decorative_shell := PANEL_SHELL_SCENE.instantiate() as GopalaPanelShell
	decorative_shell.name = "Shell_Decorative"
	decorative_shell.interactive = false
	_register(decorative_shell)
	section.add_child(decorative_shell)
	var inner_chip := RESOURCE_CHIP_SCENE.instantiate() as GopalaResourceChip
	inner_chip.name = "Chip_InShell"
	_register(inner_chip)
	decorative_shell.body().add_child(inner_chip)
	inner_chip.set_display_name("Fodder")
	inner_chip.set_amount(24)

func _build_tooltips() -> void:
	var section := _section("Shortcut tooltips")
	var row := _hrow()
	section.add_child(row)
	var tooltip_button := ICON_BUTTON_SCENE.instantiate() as GopalaIconButton
	tooltip_button.name = "Tooltip_Demo"
	_register(tooltip_button)
	row.add_child(tooltip_button)
	tooltip_button.action = &"overlay_cycle"
	tooltip_button.set_label("Overlay")
	tooltip_button.base_tooltip = "Cycle map overlay"
	tooltip_button.refresh_binding()

	var hint := SHORTCUT_TOOLTIP_SCENE.instantiate() as GopalaShortcutTooltip
	hint.name = "Shortcut_Bound"
	_register(hint)
	row.add_child(hint)
	hint.set_action(&"hud_grid")
	hint.set_label("Toggle grid")
	hint.set_description("Show or hide the build grid")

	var unbound := SHORTCUT_TOOLTIP_SCENE.instantiate() as GopalaShortcutTooltip
	unbound.name = "Shortcut_Unbound"
	_register(unbound)
	row.add_child(unbound)
	unbound.set_action(&"not_a_real_action")
	unbound.set_label("Unbound action")

	var disabled := SHORTCUT_TOOLTIP_SCENE.instantiate() as GopalaShortcutTooltip
	disabled.name = "Shortcut_Disabled"
	_register(disabled)
	row.add_child(disabled)
	disabled.set_action(&"overlay_cycle")
	disabled.set_label("Overlays")
	disabled.set_disabled_state(true, "Unavailable while a modal window is open")

	var focused := SHORTCUT_TOOLTIP_SCENE.instantiate() as GopalaShortcutTooltip
	focused.name = "Shortcut_Focused"
	_register(focused)
	row.add_child(focused)
	focused.set_action(&"camera_focus_settlement")
	focused.set_label("Focus settlement")
	focused.set_focusable(true)
	focused.call_deferred("grab_focus")

	# The long-text state gets its own row so its description width cannot
	# squeeze the other instances on narrow virtual resolutions.
	var long_row := _hrow()
	section.add_child(long_row)
	var long_hint := SHORTCUT_TOOLTIP_SCENE.instantiate() as GopalaShortcutTooltip
	long_hint.name = "Shortcut_Long"
	_register(long_hint)
	long_row.add_child(long_hint)
	long_hint.set_action(&"tool_harvest")
	long_hint.set_label(_long_text())
	long_hint.set_description(_long_text())

# ----------------------------------------------------------------- inspection

## Layout facts per registered control: rectangles, minimum needs, squeeze and
## horizontal overflow. Validated programmatically at exact virtual sizes.
func layout_report() -> Array:
	var out: Array = []
	var viewport := get_viewport_rect().size
	for node in _targets:
		var control := node
		if not control.visible:
			continue
		var rect := control.get_global_rect()
		var needs := control.get_combined_minimum_size()
		out.append({
			"name": String(control.name),
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"needs": [needs.x, needs.y],
			"squeezed": needs.x > rect.size.x + 1.0 or needs.y > rect.size.y + 1.0,
			"outside": rect.position.x < -1.0 or rect.end.x > viewport.x + 1.0,
		})
	return out

## Minimum width/height the whole gallery needs; width must fit any viewport,
## height may scroll on short screens and must fit 3840x2160.
func content_min_size() -> Vector2:
	if _sections == null:
		return Vector2.ZERO
	return _sections.get_combined_minimum_size()

func target_count() -> int:
	return _targets.size()

func control_named(node_name: String) -> Control:
	for node in _targets:
		if String(node.name) == node_name:
			return node
	return null
