class_name GopalaKathmanduHud
extends Control
## Screen layout from the Kirtipur Valley study. Stock, needs and construction are not simulated here.

signal valley_requested
signal source_requested
signal camp_requested
signal grid_changed(on: bool)
signal names_changed(on: bool)

const INK := Color(0.07, 0.06, 0.045, 0.9)
const GOLD := Color("c6a46a")
const PAPER := Color("f4efe4")
const MUTED := Color("c4bba8")
const GROUPS := {
	"All": "The whole valley. Nothing is stored or built yet.",
	"Roads": "No paths are worn in yet.",
	"Housing": "Dwelling is known. It still needs materials, hauling and labor.",
	"Storage": "Stockpile is known. It still needs a site and delivered goods.",
	"Food": "Gatherer Shelter, Water Point, Cattle Shelter and Pasture are known. Nothing produces yet.",
	"Resources": "Timber, stone, thatch, water, wild food, fodder and milk. All at zero.",
	"Decorations": "Trees and stones on this land are scenery, not plantable objects.",
}

var terrain: GopalaKathmanduTerrain
var card_title: Label
var card_body: Label
var scale_label: Label
var grid_button: Button
var names_button: Button
var map: MapPlate
var build_button: Button
var title_box: PanelContainer
var store_row: HBoxContainer
var status_box: PanelContainer
var notice_box: PanelContainer
var tool_rail: VBoxContainer
var map_frame: PanelContainer
var category_row: HBoxContainer
var card: PanelContainer
var credits: Label

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_PASS
	var hud_theme := Theme.new()
	hud_theme.default_font = ui_font()
	hud_theme.set_color("font_color", "Label", PAPER)
	theme = hud_theme
	build_title()
	build_stores()
	build_status()
	build_map()
	build_categories()
	build_action()
	build_card()
	category_row.visible = false
	card.visible = false
	layout.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		layout()

func layout() -> void:
	if not is_instance_valid(title_box):
		return
	var view := get_viewport_rect().size
	if view.x < 100.0:
		return
	var title_width := maxf(title_box.get_combined_minimum_size().x, 250.0)
	var status_width := 132.0
	title_box.position = Vector2(16, 14)
	status_box.position = Vector2(view.x - status_width - 16, 14)
	var stores_width := store_row.get_combined_minimum_size().x
	var gap_left := 16.0 + title_width + 18.0
	var gap_right := view.x - status_width - 32.0
	store_row.position = Vector2(gap_left + maxf(0.0, (gap_right - gap_left - stores_width) * 0.5), 18)
	map_frame.position = Vector2(16, view.y - 200)
	map_frame.size = Vector2(230, 184)
	var build_size := build_button.get_combined_minimum_size()
	build_button.position = Vector2((view.x - build_size.x) * 0.5, view.y - 52)
	var categories_width := category_row.get_combined_minimum_size().x
	category_row.position = Vector2((view.x - categories_width) * 0.5, view.y - 96)
	card.position = Vector2(view.x - 340, view.y - 250)
	card.size = Vector2(324, 180)

func display_font() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Iowan Old Style", "Palatino", "Georgia", "Times New Roman"])
	font.font_weight = 600
	return font

func ui_font() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Avenir Next", "Gill Sans", "Helvetica Neue"])
	return font

func plate(fill: Color, edge: Color, radius := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func paint(button: Button, wide := false) -> void:
	button.add_theme_font_override("font", ui_font())
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color("fff8ea"))
	button.add_theme_color_override("font_pressed_color", Color("1c1812"))
	button.add_theme_color_override("font_hover_pressed_color", Color("1c1812"))
	button.add_theme_stylebox_override("normal", plate(INK, Color(GOLD, 0.45), 6))
	button.add_theme_stylebox_override("hover", plate(Color(0.16, 0.13, 0.09, 0.94), GOLD, 6))
	button.add_theme_stylebox_override("pressed", plate(GOLD, GOLD, 6))
	button.add_theme_stylebox_override("hover_pressed", plate(GOLD, GOLD, 6))
	button.add_theme_stylebox_override("focus", plate(INK, GOLD, 6))
	button.focus_mode = FOCUS_NONE
	button.custom_minimum_size = Vector2(108 if wide else 36, 34)

func build_title() -> void:
	title_box = PanelContainer.new()
	var box := title_box
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel", plate(INK, Color(GOLD, 0.75), 10))
	add_child(box)
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var emblem := Control.new()
	emblem.custom_minimum_size = Vector2(34, 34)
	emblem.mouse_filter = MOUSE_FILTER_IGNORE
	emblem.draw.connect(func() -> void:
		var center := emblem.size * 0.5
		emblem.draw_arc(center, 15, 0, TAU, 32, GOLD, 1.4, true)
		emblem.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -9), center + Vector2(8, 7), center + Vector2(-8, 7)]), GOLD)
	)
	row.add_child(emblem)
	var words := VBoxContainer.new()
	words.mouse_filter = MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", -2)
	row.add_child(words)
	var name_label := Label.new()
	name_label.text = "KATHMANDU VALLEY"
	name_label.add_theme_font_override("font", display_font())
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.mouse_filter = MOUSE_FILTER_IGNORE
	words.add_child(name_label)
	var state_label := Label.new()
	state_label.text = "Unsettled ground"
	state_label.add_theme_font_size_override("font_size", 12)
	state_label.add_theme_color_override("font_color", GOLD)
	state_label.mouse_filter = MOUSE_FILTER_IGNORE
	words.add_child(state_label)

func build_stores() -> void:
	store_row = HBoxContainer.new()
	var row := store_row
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = MOUSE_FILTER_PASS
	add_child(row)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	for path in catalog.resources:
		var good: GopalaResourceDefinition = load(path)
		var pill := PanelContainer.new()
		pill.tooltip_text = good.display_name
		pill.mouse_filter = MOUSE_FILTER_STOP
		pill.clip_contents = true
		pill.add_theme_stylebox_override("panel", plate(INK, Color(GOLD, 0.35), 16))
		row.add_child(pill)
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 6)
		inner.mouse_filter = MOUSE_FILTER_IGNORE
		pill.add_child(inner)
		var icon := TextureRect.new()
		icon.texture = good.icon
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		inner.add_child(icon)
		var amount := Label.new()
		amount.text = "0"
		amount.add_theme_font_size_override("font_size", 14)
		amount.mouse_filter = MOUSE_FILTER_IGNORE
		inner.add_child(amount)

func build_status() -> void:
	status_box = PanelContainer.new()
	var box := status_box
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel", plate(INK, Color(GOLD, 0.55), 18))
	add_child(box)
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	scale_label = Label.new()
	scale_label.text = "40 km"
	scale_label.add_theme_font_override("font", display_font())
	scale_label.add_theme_font_size_override("font_size", 16)
	scale_label.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(scale_label)

func build_notices() -> void:
	notice_box = PanelContainer.new()
	var box := notice_box
	box.custom_minimum_size = Vector2(248, 0)
	box.add_theme_stylebox_override("panel", plate(INK, Color(GOLD, 0.45), 10))
	add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	box.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var heading := Label.new()
	heading.text = "NOTICES"
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", GOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var count := Label.new()
	count.text = " 2 "
	count.add_theme_font_size_override("font_size", 12)
	count.add_theme_color_override("font_color", Color("1c1812"))
	count.add_theme_stylebox_override("normal", plate(GOLD, GOLD, 8))
	header.add_child(count)
	for entry in [["Mapped courses", "The named rivers are drawn on the land."], ["Bagdwar", "The spring is marked. Its upper course is an estimate."]]:
		var title := Label.new()
		title.text = entry[0]
		title.add_theme_font_size_override("font_size", 14)
		column.add_child(title)
		var body := Label.new()
		body.text = entry[1]
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(220, 0)
		body.add_theme_font_size_override("font_size", 12)
		body.add_theme_color_override("font_color", MUTED)
		column.add_child(body)

func build_tools() -> void:
	tool_rail = VBoxContainer.new()
	var rail := tool_rail
	rail.add_theme_constant_override("separation", 6)
	rail.mouse_filter = MOUSE_FILTER_PASS
	add_child(rail)
	var views := ButtonGroup.new()
	for glyph in ["valley", "source", "camp", "grid", "names"]:
		var button := ToolButton.new()
		button.glyph = glyph
		paint(button)
		button.toggled.connect(func(_on: bool) -> void: button.queue_redraw())
		rail.add_child(button)
		match glyph:
			"valley":
				button.tooltip_text = "Valley"
				button.toggle_mode = true
				button.button_group = views
				button.set_pressed_no_signal(true)
				button.pressed.connect(func() -> void: valley_requested.emit())
			"source":
				button.tooltip_text = "Bagdwar"
				button.toggle_mode = true
				button.button_group = views
				button.pressed.connect(func() -> void: source_requested.emit())
			"camp":
				button.tooltip_text = "Camp"
				button.toggle_mode = true
				button.button_group = views
				button.pressed.connect(func() -> void: camp_requested.emit())
			"grid":
				button.tooltip_text = "Grid"
				button.toggle_mode = true
				grid_button = button
				button.toggled.connect(func(on: bool) -> void: grid_changed.emit(on))
			"names":
				button.tooltip_text = "Names"
				button.toggle_mode = true
				names_button = button
				button.set_pressed_no_signal(true)
				button.toggled.connect(func(on: bool) -> void: names_changed.emit(on))

func build_map() -> void:
	map_frame = PanelContainer.new()
	var frame := map_frame
	frame.add_theme_stylebox_override("panel", plate(INK, Color(GOLD, 0.55), 10))
	add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	frame.add_child(column)
	map = MapPlate.new()
	map.custom_minimum_size = Vector2(190, 132)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.texture = bake_map()
	map.lines = river_lines()
	map.gui_input.connect(_on_map_input)
	column.add_child(map)
	var caption := Label.new()
	caption.text = "Kathmandu"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", GOLD)
	column.add_child(caption)
	credits = Label.new()
	credits.text = "OSM · Copernicus DEM"
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_theme_font_size_override("font_size", 10)
	credits.add_theme_color_override("font_color", Color(PAPER, 0.55))
	credits.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(credits)

func build_categories() -> void:
	category_row = HBoxContainer.new()
	var row := category_row
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = MOUSE_FILTER_PASS
	add_child(row)
	var group := ButtonGroup.new()
	var first := true
	for name_value in ["All", "Roads", "Housing", "Storage", "Food", "Resources", "Decorations"]:
		var button := Button.new()
		button.text = name_value
		button.toggle_mode = true
		button.button_group = group
		paint(button, true)
		button.custom_minimum_size = Vector2(108, 32)
		button.add_theme_font_size_override("font_size", 12)
		if first:
			button.set_pressed_no_signal(true)
			first = false
		button.tooltip_text = GROUPS[name_value]
		row.add_child(button)
	row.visible = false

func build_action() -> void:
	build_button = Button.new()
	build_button.text = "Build"
	build_button.toggle_mode = true
	paint(build_button, true)
	build_button.toggled.connect(func(on: bool) -> void:
		category_row.visible = on
		if on:
			card.visible = false
	)
	add_child(build_button)

func close_build() -> void:
	build_button.set_pressed_no_signal(false)
	category_row.visible = false

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		valley_requested.emit()

func build_card() -> void:
	card = PanelContainer.new()
	var box := card
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel", plate(INK, Color(GOLD, 0.7), 10))
	add_child(box)
	var column := VBoxContainer.new()
	column.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	box.add_child(column)
	card_title = Label.new()
	card_title.text = "Kathmandu Valley"
	card_title.add_theme_font_override("font", display_font())
	card_title.add_theme_font_size_override("font_size", 20)
	card_title.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(card_title)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.7)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(rule)
	card_body = Label.new()
	card_body.text = "Click the land to read it."
	card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_body.custom_minimum_size = Vector2(280, 64)
	card_body.add_theme_font_size_override("font_size", 14)
	card_body.add_theme_color_override("font_color", MUTED)
	card_body.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(card_body)

func show_place(title_text: String, detail: String) -> void:
	close_build()
	card_title.text = title_text
	card_body.text = detail
	card.visible = true

func set_grid(on: bool) -> void:
	if grid_button == null:
		return
	grid_button.set_pressed_no_signal(on)
	grid_button.queue_redraw()

func set_names(on: bool) -> void:
	if names_button == null:
		return
	names_button.set_pressed_no_signal(on)
	names_button.queue_redraw()

func follow(camera: Camera3D) -> void:
	var point: Vector3 = camera.get("target")
	map.marker = Vector2((point.x + 200.0) / 400.0, (point.z + 200.0) / 400.0)
	map.view_extent = camera.size
	var metres := camera.size * terrain.METRES_PER_UNIT
	scale_label.text = "%.0f km" % (metres / 1000.0) if metres >= 1000.0 else "%d m" % roundi(metres)
	map.queue_redraw()

func bake_map() -> ImageTexture:
	var count := 72
	var image := Image.create(count, count, false, Image.FORMAT_RGBA8)
	for row in count:
		for column in count:
			var x := lerpf(-200.0, 200.0, float(column) / float(count - 1))
			var z := lerpf(-200.0, 200.0, float(row) / float(count - 1))
			var elevation := terrain.elevation_at(x, z)
			var steep := 1.0 - terrain.normal_at(x, z, true).y
			var color := Color("8c9158").lerp(Color("5d734c"), smoothstep(1400, 1900, elevation)).lerp(Color("3e5344"), smoothstep(1900, 2500, elevation))
			color = color.lerp(Color("6e6a58"), clampf(steep * 1.4, 0, 1))
			if terrain.river_distance(x, z) < 80:
				color = color.lerp(Color("1d6368"), 0.85)
			image.set_pixel(column, row, color)
	return ImageTexture.create_from_image(image)

func river_lines() -> PackedVector2Array:
	var lines := PackedVector2Array()
	for river in terrain.metadata.rivers:
		var points: Array = river.points
		var previous := Vector2.INF
		for point in points:
			var current := Vector2((float(point[0]) + 200.0) / 400.0, (float(point[2]) + 200.0) / 400.0)
			if previous != Vector2.INF and previous.distance_to(current) > 0.004:
				lines.append(previous)
				lines.append(current)
			previous = current
	return lines

class ToolButton extends Button:
	var glyph := "valley"
	func _draw() -> void:
		var center := size * 0.5
		var color := Color("1c1812") if button_pressed else Color("f4efe4")
		match glyph:
			"valley":
				draw_colored_polygon(PackedVector2Array([center + Vector2(0, -8), center + Vector2(10, 7), center + Vector2(-10, 7)]), color)
			"source":
				draw_arc(center + Vector2(0, -1), 5, 0, TAU, 16, color, 1.6, true)
				draw_line(center + Vector2(0, 5), center + Vector2(0, 9), color, 1.6, true)
			"camp":
				draw_colored_polygon(PackedVector2Array([center + Vector2(-8, 7), center + Vector2(-8, -1), center + Vector2(0, -8), center + Vector2(8, -1), center + Vector2(8, 7)]), color)
			"grid":
				draw_rect(Rect2(center - Vector2(7, 7), Vector2(14, 14)), color, false, 1.4)
				draw_line(center + Vector2(-7, 0), center + Vector2(7, 0), color, 1.2, true)
				draw_line(center + Vector2(0, -7), center + Vector2(0, 7), color, 1.2, true)
			"names":
				draw_line(center + Vector2(-8, -4), center + Vector2(8, -4), color, 1.5, true)
				draw_line(center + Vector2(-8, 0), center + Vector2(4, 0), color, 1.5, true)
				draw_line(center + Vector2(-8, 4), center + Vector2(8, 4), color, 1.5, true)

class MapPlate extends Control:
	var texture: Texture2D
	var lines := PackedVector2Array()
	var marker := Vector2(0.5, 0.5)
	var view_extent := 405.0
	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if texture:
			draw_texture_rect(texture, rect, false)
		var aspect := 1280.0 / 800.0
		var half := Vector2(minf(view_extent * aspect * 0.5 / 400.0, 0.46), minf(view_extent * 0.5 / 400.0, 0.46))
		var center := rect.position + Vector2(marker.x * rect.size.x, marker.y * rect.size.y)
		var extent := Vector2(half.x * rect.size.x, half.y * rect.size.y)
		draw_rect(Rect2(center - extent, extent * 2.0), Color("f0d698"), false, 1.2)
		for index in range(0, lines.size(), 2):
			draw_line(rect.position + lines[index] * rect.size, rect.position + lines[index + 1] * rect.size, Color("d7f3ef"), 1.0, true)
