extends SceneTree
## Interface assertions for the editorial-warm HUD. A screenshot cannot be judged
## by an automated suite, so these checks verify the things a screenshot would
## hide: that fonts resolve, that every plate carries the intended style, that no
## control is unlabelled, that the layout fits the target resolution, and that
## placement and inspection state actually reach the player.

class WorldPickProbe extends Node:
	var clicks := 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			clicks += 1

var failures: Array[String] = []
var checks := 0
var hud: GopalaKathmanduHud
var viewport_size := Vector2i(1600, 900)

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	_test_fonts()
	_test_input_map()
	_test_theme()
	hud = load("res://scenes/ui/hud.tscn").instantiate() as GopalaKathmanduHud
	root.add_child(hud)
	root.size = viewport_size
	root.content_scale_size = viewport_size
	var terrain := GopalaKathmanduTerrain.new()
	terrain.load_data()
	hud.configure_survey(terrain, [
		{"id": "yambu", "name": "Yambu", "modern": "Kathmandu Durbar Square", "tint": "#e0a24a",
		 "seat": {"lon": 85.3076, "lat": 27.7047}, "role": "Royal seat", "jurisdiction": "core",
		 "authority": "su z erain", "evidential_confidence": "inferred", "summary": "test"},
	])
	await process_frame
	await process_frame
	_test_structure()
	_test_resources()
	await _test_build_bar()
	await _test_structure_picker()
	await _test_inspection()
	await _test_collapsible_sections()
	await _test_field_controls()
	# Populate optional readouts before checking their labels.
	hud.show_territory("Survey", true, [{"name": "Yambu", "modern": "Kathmandu Durbar Square"}])
	hud.button_for(&"dwelling").button_pressed = true
	_test_controls_are_labelled()
	hud.close_build()
	hud.hide_inspection()
	_test_layout_fits()
	_test_minimap()
	await _test_pasture_dropdown_input()
	await _test_resource_overview()
	hud.queue_free()
	print("GOPALA_TEST_REPORT=", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _test_resource_overview() -> void:
	var overview := hud._resource_overview
	expect(overview != null and overview.exclusive, "Resource management must block input to the world.")
	expect(overview._buttons.size() == 8 and overview._buttons.has(&"grain"), "Resource management includes every catalogue good, including harvested grain and zero stock.")
	var world := WorldPickProbe.new()
	root.add_child(world)
	_click_at(hud._resource_buttons[&"timber"].get_global_rect().get_center())
	await process_frame
	await process_frame
	expect(overview.visible and overview._selected == &"timber", "A resource counter opens its matching detail.")
	var row_id: int = overview._buttons[&"timber"].get_instance_id()
	hud.set_resource(&"timber", 91)
	expect(overview._buttons[&"timber"].text.contains("91"), "Snapshot updates reach the open management row.")
	expect(overview._detail.text.contains("91") and overview._detail.text.contains("Dwelling"), "Details include live stock and real catalogue construction uses.")
	expect(overview._buttons[&"timber"].get_instance_id() == row_id, "Stock updates preserve the row and its focus state.")
	overview._filter.text = "water"
	overview._filter.text_changed.emit("water")
	expect(overview._buttons[&"water"].visible and not overview._buttons[&"timber"].visible, "Search filters by resource name.")
	_click_at(Vector2(480, 400))
	await process_frame
	expect(world.clicks == 0, "World clicks cannot leak through an exclusive resource window.")
	overview.hide()
	await process_frame
	var shortcut := InputEventKey.new()
	shortcut.physical_keycode = KEY_M
	shortcut.pressed = true
	root.push_input(shortcut)
	await process_frame
	expect(overview.visible, "The management InputMap shortcut opens the resource window.")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	expect(not overview.visible, "Escape closes management before reaching world input.")
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(3440, 1440), Vector2i(3840, 2160)]:
		root.size = resolution
		root.content_scale_size = resolution
		hud.show_resource_overview(&"water")
		for frame in 12:
			await process_frame
		expect(overview.size.x <= resolution.x and overview.size.y <= resolution.y, "Management window fits " + str(resolution))
		expect(overview.position.y >= 0 and overview.position.y + overview.size.y <= resolution.y, "Management window stays vertically on screen " + str(resolution))
		expect(overview._detail.get_global_rect().end.y <= overview.size.y, "Resource details stay inside the management window " + str(resolution))
		expect(overview._list.get_combined_minimum_size().x < overview.size.x, "Resource names fit " + str(resolution))
		overview.hide()
	root.size = viewport_size
	root.content_scale_size = viewport_size
	world.queue_free()

## Vendored fonts must load and produce real metrics, otherwise every "premium"
## typography decision silently falls back to the engine default.
func _test_fonts() -> void:
	for path in [GopalaTheme.FONT_DISPLAY, GopalaTheme.FONT_UI, GopalaTheme.FONT_MONO, GopalaTheme.FONT_FALLBACK]:
		expect(FileAccess.file_exists(path), "Font file must ship in the project: " + path)
	var display := GopalaTheme.font(GopalaTheme.FONT_DISPLAY, 500)
	var ui := GopalaTheme.font(GopalaTheme.FONT_UI, 400)
	var mono := GopalaTheme.font(GopalaTheme.FONT_MONO, 500)
	expect(display.get_string_size("Gopala", HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x > 20.0, "Display face must measure real glyph widths.")
	expect(ui.get_string_size("Dwelling", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > 15.0, "Interface face must measure real glyph widths.")
	# Tabular counts must not jitter, so digits must share one advance width.
	var zero := mono.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var eight := mono.get_string_size("8", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	expect(is_equal_approx(zero, eight), "Resource digits must be monospaced so counts do not jitter.")
	expect(FileAccess.file_exists("res://assets/fonts/OFL-Fraunces.txt"), "Font licence receipts must ship with the fonts.")

func _test_input_map() -> void:
	expect(InputMap.has_action(&"tool_road"), "R must have a project dirt-path action.")
	if InputMap.has_action(&"tool_road"):
		var road_bindings := InputMap.action_get_events(&"tool_road")
		expect(road_bindings.any(func(event): return event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_R),
			"The dirt-path shortcut must be R.")
	expect(InputMap.has_action(&"tool_build"), "B must have a project build-toggle action.")
	if InputMap.has_action(&"tool_build"):
		var bindings := InputMap.action_get_events(&"tool_build")
		expect(bindings.any(func(event): return event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_B),
			"The build-picker shortcut must be B.")

func _test_theme() -> void:
	var theme := GopalaTheme.build()
	expect(theme.default_font != null, "Theme must define a default interface font.")
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		expect(theme.get_stylebox(state, "Button") != null, "Buttons need a " + state + " style.")
	expect(theme.get_stylebox("panel", "PanelContainer") != null, "Panels need a plate style.")
	expect(theme.get_color("font_color", "Button") != Color(0, 0, 0, 1), "Buttons need an explicit ink colour.")
	# The palette must stay warm and paper-based rather than default grey.
	var plate: StyleBoxFlat = theme.get_stylebox("panel", "PanelContainer")
	expect(plate.bg_color.r > plate.bg_color.b, "Panel plate must read as warm paper, not blue-grey.")
	expect(GopalaTheme.BRASS.r > GopalaTheme.BRASS.b, "Brass accent must stay warm.")

func _test_structure() -> void:
	expect(hud._root != null, "HUD must build an interface root.")
	expect(hud._root.theme != null, "CanvasLayer has no theme, so the interface root must carry it.")
	expect(hud._minimap != null, "The survey plate must hold a minimap.")
	expect(hud._resource_slots.size() == 8 and hud._resource_slots.has(&"grain"), "All eight catalogue goods, including harvested grain, need a readout.")
	expect(hud._build_entries.size() == 10 and hud.button_for(&"field") != null, "Six P0 structures, two zones, and dirt/cobbled path tools must be offered.")
	expect(hud._root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Uncovered HUD space passes world clicks.")
	for panel in [hud._build_bar_shell, hud._inspection, hud._status_shell, hud._view_tools_shell]:
		expect(panel.mouse_filter == Control.MOUSE_FILTER_STOP, "Interactive panel backgrounds consume clicks.")

func _test_resources() -> void:
	for path in ["res://data/resources/timber.tres", "res://data/resources/milk.tres"]:
		var good := load(path) as GopalaResourceDefinition
		hud.set_resource(good.id, 42)
		var slot: Label = hud._resource_slots[good.id]
		expect(slot.text == "42", "Setting a stock must update the readout for " + String(good.id))
	hud.set_resource(&"unknown_good", 3)

func _test_build_bar() -> void:
	hud._refresh_strip()
	var visible_before := _visible_build_count()
	expect(visible_before == 10, "The All category shows every structure, zone, and path tool.")
	hud._active_category = "Housing"
	hud._refresh_strip()
	expect(_visible_build_count() == 1, "Housing must narrow the strip to the dwelling.")
	hud._active_category = "All"
	hud._refresh_strip()

	var chosen: Array[StringName] = []
	hud.build_selected.connect(func(id: StringName) -> void: chosen.append(id))
	var road := hud.button_for(&"dirt_path")
	expect(road != null and road.tooltip_text.contains("release to place"), "Path tool explains its drag-to-place interaction.")
	var cobbled := hud.button_for(&"cobbled_path")
	expect(cobbled != null and cobbled.accessibility_name == "Cobbled path upgrade", "Cobbled path upgrade has a clear accessible name.")
	expect(cobbled.tooltip_text.contains("2 + timber 1 per cell") and cobbled.tooltip_text.contains("Shift+R"), "Upgrade tooltip discloses its material costs and shortcut.")
	var cobbled_modes := []
	hud.cobbled_path_mode_requested.connect(func(): cobbled_modes.append(true))
	hud.activate_cobbled_path_mode()
	expect(hud._road_mode and hud._cobbled_path_mode and hud._selected_build == &"cobbled_path", "Upgrade tool enters the dedicated road-upgrade interaction mode.")
	expect(hud._build_costs.text.contains("2 stone + 1 timber") and hud._build_costs.text.contains("×1.6"), "Upgrade detail card exposes price and movement benefit.")
	expect(cobbled_modes.size() == 1, "Upgrade mode signals the world preview adapter.")
	hud.clear_build()
	var dwelling := hud.button_for(&"dwelling")
	expect(dwelling != null, "The dwelling must appear in the build strip.")
	dwelling.button_pressed = true
	await process_frame
	expect(chosen == [&"dwelling"], "Choosing a structure must report it for placement.")
	expect(hud._placement_active, "Choosing a structure must arm placement mode.")
	expect(hud._build_title.text == "Dwelling", "The build card must name the chosen structure.")
	expect("timber" in hud._build_costs.text, "The build card must show real material costs from the catalogue.")
	expect(hud._build_meta.text.contains("2 × 2"), "The build card must show the authored footprint.")
	hud.close_build()
	await process_frame
	expect(not hud._placement_active, "Escape must cancel placement.")
	expect(hud._build_title.text == "Choose a structure", "Cancelling must clear the build card.")
	expect(not dwelling.button_pressed, "Cancelling must release the strip button.")
	# An unavailable job must be able to state a reason rather than stay silent.
	expect(dwelling.tooltip_text.contains("Footprint"), "Every structure needs a readable tooltip.")

func _test_structure_picker() -> void:
	expect(hud._build_bar_shell.size.x >= 310 and hud._build_bar_shell.size.x <= 360, "Picker width stays readable and bounded.")
	expect(is_equal_approx(hud._build_bar_shell.get_global_rect().end.x, viewport_size.x - 12), "Picker keeps its right margin.")
	expect(hud._structure_grid.columns == 3, "Structure choices render in a readable three-column grid.")
	expect(hud._category_grid.columns == 7, "Category switches render in an icon grid.")
	expect(hud._build_toggle != null and hud._build_toggle.visible and hud._build_toggle.tooltip_text.contains("B"), "A visible picker toggle advertises the B shortcut.")
	expect(hud.button_for(&"dwelling").icon != null, "Structure tiles carry clear icons.")
	expect(hud.button_for(&"dirt_path") != null and hud.button_for(&"dirt_path").accessibility_name == "Dirt path", "The dirt-path option is clearly labelled for mouse and assistive input.")
	expect(hud.button_for(&"dwelling").accessibility_name == "Dwelling", "Icon-led tiles retain their full accessible names.")
	hud._status_shell.visible = true
	hud._build_bar_shell.visible = false
	hud._refresh_build_toggle()
	expect(hud._build_toggle.visible, "The dedicated toggle remains available with the picker closed.")
	hud.toggle_build_picker()
	for frame in 8: await process_frame
	expect(hud._build_bar_shell.get_global_rect().end.y <= viewport_size.y - 64, "Picker leaves the command dock clear.")
	expect(hud._build_bar_shell.visible and hud._build_toggle.visible and hud._build_toggle.button_pressed, "The toggle opens the picker and shows the close affordance.")
	expect(hud._build_toggle.get_parent() is HBoxContainer, "The build toggle is container-aligned in the dock.")
	expect(hud._build_toggle.tooltip_text.contains("Close"), "Build toggle communicates its open state.")
	expect(hud._build_title.size.y >= 18.0 and hud._build_meta.size.y >= 14.0, "The default preview card reserves space for its title and hint.")
	hud.toggle_build_picker()
	expect(not hud._build_bar_shell.visible and not hud._build_toggle.button_pressed, "The toggle closes the picker without changing its state unexpectedly.")

func _visible_build_count() -> int:
	var total := 0
	for entry in hud._build_entries:
		if (entry["button"] as Button).visible:
			total += 1
	return total

func _test_inspection() -> void:
	hud.show_place("Valley floor", "1340 m · Ground will hold a camp")
	await process_frame
	expect(_inspection_visible(), "Inspecting ground must open the panel.")
	expect(hud._inspect_title.text == "Valley floor", "The panel must name what was inspected.")
	expect("1340 m" in hud._inspect_detail.text, "The panel must show the inspected detail.")

	hud.show_territory("Survey", true, [{"name": "Yambu", "modern": "Kathmandu Durbar Square"}])
	await process_frame
	expect(_inspection_visible(), "Territory mode must open the panel.")
	expect(hud._inspect_title.text == "Four tributary domains", "Territory mode must summarise the chiefdoms.")
	expect("Yambu" in hud._inspect_body.text, "Territory mode must list the chiefdoms.")
	expect(hud._minimap.territory_mode == "Survey", "Territory mode must reach the minimap.")

	var chiefdom := {
		"name": "Lalitapur", "modern": "Patan Durbar Square", "role": "Monastic seat",
		"summary": "A river-side domain.", "jurisdiction": "east bank",
		"authority": "Buddhist chapter", "evidential_confidence": "inferred",
	}
	hud.show_chiefdom("Survey", chiefdom)
	await process_frame
	expect(hud._inspect_title.text == "Lalitapur", "A clicked chiefdom must be named.")
	expect("INFERRED" in hud._inspect_body.text, "The panel must publish evidential confidence.")
	expect("Buddhist chapter" in hud._inspect_body.text, "The panel must show documented authority.")

	hud.show_territory("Off", false, [])
	await process_frame
	expect(not _inspection_visible(), "Leaving territory mode must close the panel.")
	hud.show_chiefdom("Wash", {})
	expect(not _inspection_visible(), "An empty chiefdom must not open a blank panel.")

func _inspection_visible() -> bool:
	var shell := hud._inspection.get_parent() as Control
	return shell != null and shell.visible

func _test_collapsible_sections() -> void:
	var component := (load("res://scenes/ui/components/collapsible_section/collapsible_section.tscn") as PackedScene).instantiate() as GopalaCollapsibleSection
	root.add_child(component)
	await process_frame
	component.set_title("Flexible panel")
	expect(component.title_label().text == "Flexible panel", "Reusable section updates its visible title.")
	expect(component.body() != null and component.body().visible, "Reusable section starts expanded with a live body.")
	var change_events: Array[bool] = []
	component.collapsed_changed.connect(func(value: bool): change_events.append(value))
	component.toggle()
	expect(component.collapsed and not component.body().visible, "Collapsing hides only the section content.")
	expect(component.get_node("Header/Collapse").visible, "Collapse control remains visible when folded.")
	expect(component.get_node("Header/Collapse").tooltip_text == "Expand Flexible panel", "Fold toggle exposes an accessible expand label.")
	component.toggle()
	expect(not component.collapsed and component.body().visible, "Expanding restores section content.")
	expect(change_events == [true, false], "Section emits one state change per user toggle.")
	component.queue_free()
	await process_frame

	for section in [hud._status_section, hud._inspection_section, hud._build_section, hud._view_section, hud._minimap_section]:
		expect(section != null and section.get_node_or_null("Header/Collapse") != null and section.body() != null, "Every primary HUD panel uses the reusable collapsible section.")
	var status_height := hud._status_shell.size.y
	hud._status_section.set_collapsed(true)
	expect(hud._status_section.collapsed and hud._status_shell.size.y < status_height, "Valley survey folds and shrinks to its header.")
	hud._status_section.set_collapsed(false)
	expect(not hud._status_section.collapsed and hud._status_shell.size.y > 42.0, "Valley survey expands to its contents.")
	expect(not hud._build_section.collapsible, "Construction has one close affordance and keeps its scroll area available.")

func _test_controls_are_labelled() -> void:
	# Backlog G-027: every critical icon needs text or a tooltip.
	for button in hud._root.find_children("*", "Button", true, false):
		var has_text := not (button as Button).text.strip_edges().is_empty()
		expect(has_text or not (button as Button).tooltip_text.is_empty(),
			"Unlabelled control: " + (button as Button).name)
	for label in hud._root.find_children("*", "Label", true, false):
		expect(not (label as Label).text.is_empty(), "Empty label rendered: " + (label as Label).name)

func _test_layout_fits() -> void:
	# Nothing may spill outside a modest desktop frame, or the plate becomes unusable.
	await process_frame
	hud._root.size = Vector2(viewport_size)
	for plate in hud._root.find_children("*", "PanelContainer", true, false):
		var control: Control = plate
		if not control.is_visible_in_tree():
			continue
		var combined := control.get_combined_minimum_size()
		expect(combined.x <= float(viewport_size.x), "Plate wider than the frame: " + control.name)
		expect(combined.y <= float(viewport_size.y), "Plate taller than the frame: %s (%s; min %s)" % [control.name, str(combined), str(control.custom_minimum_size)])
	expect(hud._build_bar_shell.size.x <= 360.0, "Construction remains a bounded contextual panel.")
	var strip := hud._root.find_child("StructureStrip", true, false) as Control
	expect(strip != null, "The structure grid must exist.")

func _test_minimap() -> void:
	var minimap := GopalaMinimap.new()
	minimap.size = Vector2(168, 168)
	root.add_child(minimap)
	var terrain := GopalaKathmanduTerrain.new()
	terrain.load_data()
	expect(terrain.source.size() > 0, "The elevation field must load for the minimap.")
	minimap.configure(terrain, [])
	var centre := minimap.world_to_local_point(Vector2.ZERO)
	expect(centre.is_equal_approx(minimap.size * 0.5), "The minimap must centre the origin.")
	var corner := minimap.world_to_local_point(Vector2(200, 200))
	expect(corner.x > centre.x and corner.y > centre.y, "The minimap must map north-east to the lower right.")
	expect(corner.x <= minimap.size.x and corner.y <= minimap.size.y, "The mapped extent must stay inside the plate.")
	# Drawing must survive an empty document instead of crashing the frame.
	minimap.set_territory("Survey")
	minimap.queue_redraw()
	await process_frame
	# An unloaded terrain must degrade to blank paper, never sample past its arrays.
	var blank := GopalaMinimap.new()
	blank.size = Vector2(120, 120)
	root.add_child(blank)
	blank.configure(GopalaKathmanduTerrain.new(), [])
	blank.queue_redraw()
	await process_frame
	blank.queue_free()
	minimap.queue_free()
## Exercise viewport input dispatch rather than emitting a button signal: the
## popup must select a real pasture and consume the mouse before world picking.
func _test_pasture_dropdown_input() -> void:
	root.gui_embed_subwindows = true
	var probe := WorldPickProbe.new()
	root.add_child(probe)
	hud.show_place("Cattle", "Choose a destination")
	hud.show_cattle_controls([{"id": 101, "label": "North pasture"}, {"id": 202, "label": "South pasture"}])
	await process_frame
	await process_frame
	_click_at(Vector2(700, 500))
	expect(probe.clicks == 1, "World picking observer must receive an unobstructed terrain click.")
	var before := probe.clicks
	var choice := hud._pasture_choices
	_click_at(choice.get_global_rect().get_center())
	await process_frame
	var popup := choice.get_popup()
	expect(popup.visible, "Clicking the pasture selector must open its actual popup.")
	var panel := popup.get_theme_stylebox("panel")
	var top := panel.get_content_margin(SIDE_TOP)
	var bottom := panel.get_content_margin(SIDE_BOTTOM)
	var row_height := (float(popup.size.y) - top - bottom) / float(popup.item_count)
	_click_at(Vector2(popup.position) + Vector2(float(popup.size.x) * 0.5, top + row_height * 1.5))
	await process_frame
	expect(choice.get_selected_id() == 202, "Clicking the second popup row must select South pasture.")
	expect(not popup.visible, "Selecting a pasture must close the popup.")
	expect(probe.clicks == before, "Opening and selecting a pasture must never reach world picking.")
	probe.queue_free()
	hud.show_cattle_controls([])

## Field controls are state-aware: crop choice is available only before planting,
## while a free settler is required for plant/tend/harvest work. Real GUI clicks
## must be consumed before the landscape's unhandled world picker sees them.
func _test_field_controls() -> void:
	var field_button := hud.button_for(&"field")
	expect(field_button != null and field_button.accessibility_name == "Terraced Field", "Terraced field is available as a named placement option.")
	expect(field_button != null and field_button.tooltip_text.contains("Zone"), "Field placement identifies itself as a zone.")
	var field_actions: Array = []
	hud.field_action_requested.connect(func(action: StringName, field_id: int, worker_id: int, crop_id: StringName):
		field_actions.append([action, field_id, worker_id, crop_id])
	)
	var world := WorldPickProbe.new()
	root.add_child(world)
	hud.show_place("Terraced field", "Field #91")
	hud.show_field_controls(91, &"FALLOW", &"", [])
	await process_frame
	await process_frame
	expect(hud._field_controls.visible and hud._field_crop_choices.get_parent().visible, "Fallow fields expose the crop selector.")
	expect(not hud._field_worker_choices.visible and hud._field_action_button.text == "Set crop", "Crop selection does not require a worker.")
	_click_at(hud._field_crop_choices.get_global_rect().get_center())
	await process_frame
	var popup := hud._field_crop_choices.get_popup()
	expect(popup.visible, "Crop selector opens its real option popup.")
	if popup.visible:
		var panel := popup.get_theme_stylebox("panel")
		var top := panel.get_content_margin(SIDE_TOP)
		var bottom := panel.get_content_margin(SIDE_BOTTOM)
		var row_height := (float(popup.size.y) - top - bottom) / float(popup.item_count)
		_click_at(Vector2(popup.position) + Vector2(float(popup.size.x) * 0.5, top + row_height * 1.5))
		await process_frame
	expect(hud._field_crop_choices.get_item_metadata(hud._field_crop_choices.selected) == &"fodder_crop", "Player can choose the data-backed fodder crop.")
	expect(world.clicks == 0, "Crop-picker clicks and popup choices do not leak to world selection/placement.")
	hud._field_action_button.pressed.emit()
	expect(field_actions.size() == 1 and field_actions[0] == [&"SET_CROP", 91, 0, &"fodder_crop"], "Set crop emits the selected field and crop without requiring a worker.")

	hud.show_field_controls(91, &"PREPARING", &"fodder_crop", [{"id": 7, "status": "Ready"}])
	expect(not hud._field_crop_choices.get_parent().visible and hud._field_worker_choices.visible, "Preparing fields lock crop choice and request a worker.")
	expect(hud._field_action_button.text == "Plant crop" and not hud._field_action_button.disabled, "Prepared field offers planting to an available settler.")
	hud._field_action_button.pressed.emit()
	expect(field_actions.size() == 2 and field_actions[1] == [&"WORK", 91, 7, &"fodder_crop"], "Plant order emits the selected worker and field.")
	hud.show_field_controls(91, &"GROWING", &"fodder_crop", [{"id": 7, "status": "Ready"}])
	expect(hud._field_action_button.text == "Tend field", "Growing field offers tending.")
	hud.show_field_controls(91, &"MATURE", &"fodder_crop", [])
	expect(hud._field_action_button.text == "Harvest crop" and hud._field_action_button.disabled, "Mature field offers harvest but disables it without an available worker.")
	hud.show_field_controls(91, &"MATURE", &"fodder_crop", [{"id": 8, "status": "Ready"}])
	expect(not hud._field_action_button.disabled, "Harvest becomes available when a free worker is supplied.")
	hud._field_action_button.pressed.emit()
	expect(field_actions.size() == 3 and field_actions[2] == [&"WORK", 91, 8, &"fodder_crop"], "Harvest order targets the chosen free settler.")
	world.queue_free()
	hud._show_inspection("Field test", "Field", "", "")
	hud._field_controls.hide()
	hud.hide_inspection()

func _click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
