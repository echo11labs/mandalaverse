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
	await _test_inspection()
	# Populate optional readouts before checking their labels.
	hud.show_territory("Survey", true, [{"name": "Yambu", "modern": "Kathmandu Durbar Square"}])
	hud.button_for(&"dwelling").button_pressed = true
	_test_controls_are_labelled()
	hud.close_build()
	hud.hide_inspection()
	_test_layout_fits()
	_test_minimap()
	await _test_pasture_dropdown_input()
	hud.queue_free()
	print("GOPALA_TEST_REPORT=", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

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
	expect(hud._resource_slots.size() == 7, "All seven P0 goods need a readout.")
	expect(hud._build_entries.size() == 7, "Six P0 structures plus one pasture zone must be offered.")
	# Decorative plates must not eat clicks meant for the terrain.
	var plates := hud._root.find_children("*", "PanelContainer", true, false)
	expect(plates.size() >= 4, "Interface must be composed of several plates.")
	for plate in plates:
		if plate.get_parent() is PopupMenu:
			expect((plate as Control).mouse_filter == Control.MOUSE_FILTER_STOP,"Interactive dropdown must consume its own clicks.")
			continue
		expect((plate as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Decorative plates must ignore the mouse so world picking still works.")

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
	expect(visible_before == 7, "The All category shows every entry.")
	hud._active_category = "Housing"
	hud._refresh_strip()
	expect(_visible_build_count() == 1, "Housing must narrow the strip to the dwelling.")
	hud._active_category = "All"
	hud._refresh_strip()

	var chosen: Array[StringName] = []
	hud.build_selected.connect(func(id: StringName) -> void: chosen.append(id))
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
		if not control.visible:
			continue
		var combined := control.get_combined_minimum_size()
		expect(combined.x <= float(viewport_size.x), "Plate wider than the frame: " + control.name)
		expect(combined.y <= float(viewport_size.y), "Plate taller than the frame: " + control.name)
	# The build strip must stay inside its bar rather than overflow the screen.
	var strip := hud._root.find_child("StructureStrip", true, false) as Control
	expect(strip != null, "The structure strip must exist.")
	if strip != null:
		expect(strip.get_combined_minimum_size().x <= float(viewport_size.x),
			"The structure strip must fit the frame width.")

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
