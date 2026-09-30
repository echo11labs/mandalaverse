extends Node2D
## Layer 01: an inspectable 2D landscape, with no settlement simulation.

@onready var ground: TileMapLayer = $Ground
@onready var camera: GopalaValleyCamera = $Camera2D
@onready var overlay: GopalaTerrainOverlay = $TerrainOverlay
var terrain: GopalaValleyTerrain
var status: Label
var zoom_label: Label

func _ready() -> void:
	terrain = load("res://data/maps/starting_valley.tres")
	var errors := terrain.validate()
	if not errors.is_empty():
		push_error("Invalid valley: " + str(errors))
		return
	overlay.terrain = terrain
	overlay.ground = ground
	overlay.camera = camera
	var center := ground.map_to_local(Vector2i(23, 23))
	camera.configure(Rect2(Vector2(-3300, -600), Vector2(6600, 4400)), center, ground.map_to_local(terrain.camp_cell))
	camera.view_changed.connect(_view_changed)
	create_hud()
	_view_changed()
	queue_redraw()
	if "--capture" in OS.get_cmdline_user_args() or "--capture-close" in OS.get_cmdline_user_args():
		if "--capture-close" in OS.get_cmdline_user_args():
			camera.show_camp()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var filename := "landscape-close.png" if "--capture-close" in OS.get_cmdline_user_args() else "landscape-overview.png"
		var code := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../reports/" + filename))
		print("GOPALA_LANDSCAPE_CAPTURE=", code)
		get_tree().quit(code)

func _draw() -> void:
	if terrain == null:
		return
	var top := ground.map_to_local(Vector2i.ZERO) + Vector2(0, -32)
	var right := ground.map_to_local(Vector2i(47, 0)) + Vector2(64, 0)
	var bottom := ground.map_to_local(Vector2i(47, 47)) + Vector2(0, 32)
	var left := ground.map_to_local(Vector2i(0, 47)) + Vector2(-64, 0)
	var depth := Vector2(0, 78)
	draw_colored_polygon(PackedVector2Array([left + Vector2(-38, 26), bottom + Vector2(0, 140), right + Vector2(38, 26), top]), Color(0.035, 0.055, 0.05, 0.3))
	draw_colored_polygon(PackedVector2Array([left, bottom, bottom + depth, left + depth]), Color("716b50"))
	draw_colored_polygon(PackedVector2Array([bottom, right, right + depth, bottom + depth]), Color("5d644e"))
	draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), GopalaValleyTerrain.PALETTE[0])

func create_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var frame := Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(frame)
	var header := PanelContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 26
	header.offset_right = -26
	header.offset_top = 24
	header.offset_bottom = 116
	header.add_theme_stylebox_override("panel", panel_style())
	frame.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	header.add_child(row)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_column)
	var eyebrow := Label.new()
	eyebrow.text = "GOPALA  /  DAWN OF THE VALLEY"
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color("c7c8aa"))
	title_column.add_child(eyebrow)
	var title := Label.new()
	title.text = "The first valley"
	title.add_theme_font_size_override("font_size", 26)
	title_column.add_child(title)
	add_button(row, "Valley", camera.show_overview)
	add_button(row, "Clearing", camera.show_camp)
	add_button(row, "Grid", func(): overlay.show_grid = not overlay.show_grid; overlay.queue_redraw(), true)
	add_button(row, "Suitable ground", func(): overlay.show_buildable = not overlay.show_buildable; overlay.queue_redraw(), true)
	zoom_label = Label.new()
	zoom_label.custom_minimum_size = Vector2(64, 0)
	row.add_child(zoom_label)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 26
	bottom.offset_right = -26
	bottom.offset_top = -100
	bottom.offset_bottom = -24
	bottom.add_theme_stylebox_override("panel", panel_style())
	frame.add_child(bottom)
	var column := VBoxContainer.new()
	bottom.add_child(column)
	status = Label.new()
	status.text = "48 × 48 valley  ·  Select a ground tile to inspect it"
	status.add_theme_font_size_override("font_size", 16)
	column.add_child(status)
	var controls := Label.new()
	controls.text = "Middle-drag / WASD: pan     Scroll: zoom     G: grid     B: ground suitability     Esc: clear selection"
	controls.add_theme_font_size_override("font_size", 12)
	controls.add_theme_color_override("font_color", Color("c7c8aa"))
	column.add_child(controls)
	var caption := Label.new()
	caption.text = "LAYER 01   /   LANDSCAPE FOUNDATION"
	caption.position = Vector2(40, 132)
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("c7c8aa"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(caption)

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.12, 0.115, 0.94)
	style.border_color = Color(0.62, 0.67, 0.5, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func add_button(parent: Control, text: String, callback: Callable, toggle := false) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = toggle
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(80, 38)
	button.pressed.connect(callback)
	parent.add_child(button)

func _view_changed() -> void:
	overlay.queue_redraw()
	if zoom_label != null:
		zoom_label.text = str(int(camera.zoom.x * 100)) + "%"

func select_cell(cell: Vector2i) -> void:
	overlay.selected = cell if terrain.contains(cell) else Vector2i(-1, -1)
	overlay.queue_redraw()
	if not terrain.contains(cell):
		status.text = "Outside the playable valley"
		return
	var kind := terrain.kind_at(cell)
	var suitability := "Suitable building ground" if terrain.is_buildable_ground(cell) else "Keep clear for river access" if kind in [GopalaValleyTerrain.Kind.SHORE, GopalaValleyTerrain.Kind.MARSH] else "Clear vegetation before building" if kind == GopalaValleyTerrain.Kind.FOREST_FLOOR else "Unsuitable building ground"
	status.text = "%s  ·  Cell %d, %d  ·  %s  ·  %s" % [GopalaValleyTerrain.NAMES[kind], cell.x, cell.y, "Walkable" if terrain.is_walkable(cell) else "Blocked", suitability]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select_cell(ground.local_to_map(ground.get_local_mouse_position()))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_G:
			overlay.show_grid = not overlay.show_grid
		elif event.physical_keycode == KEY_B:
			overlay.show_buildable = not overlay.show_buildable
		elif event.physical_keycode == KEY_ESCAPE:
			overlay.selected = Vector2i(-1, -1)
			status.text = "48 × 48 valley  ·  Select a ground tile to inspect it"
		else:
			return
		overlay.queue_redraw()
		get_viewport().set_input_as_handled()
