class_name GopalaFrontDoor
extends Node
## Scene-owned game flow. Menus block camera/world input and pause the authority.
var world
var settings := GopalaGameSettings.new()
var slots := GopalaSaveSlots.new()
var page := "main"
var buttons := {}
var settings_controls := {}
var _layer: CanvasLayer
var _overlay: Control
var _column: VBoxContainer
var _card: PanelContainer
var _status: Label
var _was_paused := true
var _saved_fingerprint := ""
var _pending_action: Callable
var _return_page := "pause"

func _ready() -> void:
	settings.load_from_disk()
	settings.apply()
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_overlay)
	var shade := ColorRect.new()
	shade.name = "Backdrop"
	shade.color = Color("18170fee")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel",GopalaTheme.flat(Color("211e12"),6,1,GopalaTheme.BRASS_DARK,24,20))
	center.add_child(_card)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation",10)
	_card.add_child(_column)
	show_page("main")

func _clear() -> void:
	buttons.clear()
	settings_controls.clear()
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	var scale := float(settings.values.ui_scale)
	_card.custom_minimum_size.x = minf(520.0*scale,get_viewport().get_visible_rect().size.x-32.0)
	_card.theme = GopalaTheme.navbar()
	_card.theme.default_font_size = roundi(13.0*scale)
	for kind in ["Label","Button","LineEdit","CheckButton"]: _card.theme.set_font_size("font_size",kind,roundi(13.0*scale))

func _text(value: String, size := 14, muted := false) -> Label:
	var label := Label.new()
	label.text = value
	label.set_meta("base_font_size",size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font",GopalaTheme.font(GopalaTheme.FONT_DISPLAY if size >= 24 else GopalaTheme.FONT_UI,400,size))
	label.add_theme_font_size_override("font_size",roundi(size*float(settings.values.ui_scale)))
	label.add_theme_color_override("font_color",Color("bfb59c") if muted else Color("f7f2df"))
	_column.add_child(label)
	return label

func _button(id: String, title: String, action: Callable, disabled := false) -> Button:
	var button := Button.new()
	button.name = id.to_pascal_case()
	button.text = title
	button.custom_minimum_size.y = GopalaTheme.NAV_CONTROL_HEIGHT*float(settings.values.ui_scale)
	button.disabled = disabled
	button.pressed.connect(action)
	_column.add_child(button)
	buttons[id] = button
	return button

func show_page(next: String) -> void:
	page = next
	_overlay.visible = true
	_clear()
	_text("GOPALA · DAWN OF THE VALLEY",13,true)
	match page:
		"main":
			_text("A home in the valley",30)
			_text("Guide eight settlers and their herd. Gather, build, and sustain your first settlement.",14,true)
			var latest := slots.latest()
			_button("continue","Continue",continue_latest,latest < 0).tooltip_text = "Resume the latest valid save" if latest >= 0 else "Save a settlement to enable Continue"
			_button("new","New settlement",start_new)
			_button("load","Load settlement",func(): show_page("load"))
			_button("settings","Settings",func(): show_page("settings"))
			_button("quit","Quit",request_quit)
			_text("Gameplay reconstruction · prototype art",12,true)
		"pause":
			_text("Settlement paused",28)
			_text("Time stands still while this menu is open.",14,true)
			_button("resume","Resume",resume)
			_button("save","Save settlement",func(): show_page("save"))
			_button("load","Load settlement",func(): show_page("load"))
			_button("settings","Settings",func(): show_page("settings"))
			_button("main","Main menu",request_main_menu)
			_button("quit","Quit",request_quit)
		"save", "load": _slot_page()
		"settings": _settings_page()
	_status = _text("",13,true)
	if not buttons.is_empty():
		for button in buttons.values():
			if not button.disabled:
				button.grab_focus()
				break

func start_new() -> void:
	_drop_world()
	world = preload("res://scenes/mvp.tscn").instantiate()
	world.managed_session = true
	world.pause_menu_requested.connect(func(): open_menu("pause"))
	world.save_menu_requested.connect(func(): open_menu("save"))
	world.load_menu_requested.connect(func(): open_menu("load"))
	world.restart_requested.connect(request_new)
	add_child(world)
	settings.apply(world.camera)
	_saved_fingerprint = ""
	_was_paused = true
	_hide_menu()

func _drop_world() -> void:
	if world != null:
		world.simulation.set_physics_process(false)
		remove_child(world)
		world.queue_free()
		world = null
	var router := GopalaUIRouter.router()
	if router != null: router.prepare_for_scene_change()

func open_menu(next := "pause") -> void:
	if world != null and not _overlay.visible:
		_was_paused = world.simulation.paused
		if not world.simulation.paused:
			world.simulation.set_paused(true)
			world.simulation.process_pending_commands()
		world.menu_input_blocked = true
		world.camera.input_blocked = true
		world.camera.dragging = false
		world.camera.rotating = false
	show_page(next)

func _hide_menu() -> void:
	_overlay.visible = false
	page = "playing"
	if world != null:
		world.menu_input_blocked = false
		world.camera.input_blocked = false

func resume() -> void:
	if world == null: return
	world.simulation.set_paused(_was_paused)
	world.simulation.process_pending_commands()
	_hide_menu()

func fingerprint() -> String:
	if world == null: return ""
	var state: Dictionary = world._save_service.capture(world.simulation,world._save_context(),false)
	state.clock[0] = true # Pause/resume alone is not unsaved gameplay progress.
	state.erase("next_command")
	return JSON.stringify(GopalaSettlementSave.encode(state)).sha256_text()

func has_unsaved_progress() -> bool:
	return world != null and fingerprint() != _saved_fingerprint

func _ask(title: String, explanation: String, action: Callable) -> void:
	_return_page = page
	_pending_action = action
	page = "confirm"
	_clear()
	_text(title,26)
	_text(explanation,14,true)
	_button("cancel","Cancel",func(): show_page(_return_page))
	_button("confirm","Confirm",func(): _pending_action.call())
	buttons.cancel.grab_focus()

func _guard(action: Callable) -> void:
	if has_unsaved_progress():
		_ask("Leave this settlement?","Unsaved progress will be lost. Cancel to return and save first.",action)
	else: action.call()

func request_main_menu() -> void:
	_guard(func(): _drop_world(); show_page("main"))

func request_new() -> void:
	open_menu()
	_guard(start_new)

func request_quit() -> void:
	_guard(func(): get_tree().quit())

func _slot_page() -> void:
	_text("Save settlement" if page == "save" else "Load settlement",26)
	_text("Three named slots · your previous save is retained as a backup.",13,true)
	for row in slots.rows():
		var line := HBoxContainer.new()
		_column.add_child(line)
		var name_edit := LineEdit.new()
		name_edit.text = row.name
		name_edit.max_length = 40
		name_edit.editable = page == "save"
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_edit)
		var button := Button.new()
		button.custom_minimum_size = Vector2(120,GopalaTheme.NAV_CONTROL_HEIGHT)
		button.text = "Save" if page == "save" else ("Load · tick %d" % row.tick if row.valid else ("Unavailable" if row.exists else "Empty"))
		button.disabled = page == "load" and not row.valid
		button.pressed.connect(func():
			if page == "save": request_save(row.slot,name_edit.text)
			else: request_load(row.slot)
		)
		line.add_child(button)
		buttons["slot%d" % row.slot] = button
	_button("back","Back",func(): show_page("pause" if world != null else "main"))

func request_save(slot: int, title: String) -> void:
	if world == null: return
	if FileAccess.file_exists(slots.path(slot)):
		_ask("Overwrite this save?","The previous save will be kept as a .bak file.",func(): save_slot(slot,title))
	else: save_slot(slot,title)

func save_slot(slot: int, title: String) -> bool:
	if world == null or slot < 0 or slot > 2: return false
	if not _overlay.visible: open_menu("save")
	var ok: bool = world.save_settlement(slots.path(slot))
	if ok:
		slots.record(slot,title)
		_saved_fingerprint = fingerprint()
	show_page("save")
	_status.text = ("Settlement saved." if slots.error.is_empty() else slots.error) if ok else world._save_service.error
	return ok

func request_load(slot: int) -> void:
	_guard(func(): load_slot(slot))

func continue_latest() -> void:
	var slot := slots.latest()
	if slot >= 0: load_slot(slot)

func load_slot(slot: int) -> bool:
	if slot < 0 or slot > 2: return false
	var created := world == null
	if created: start_new()
	if not world.load_settlement(slots.path(slot)):
		var message: String = world._save_service.error
		if created: _drop_world()
		open_menu("load")
		_status.text = message
		return false
	if not world.simulation.paused:
		world.simulation.set_paused(true)
		world.simulation.process_pending_commands()
	_was_paused = true
	_saved_fingerprint = fingerprint()
	settings.apply(world.camera)
	_hide_menu()
	return true

func _settings_page() -> void:
	_text("Settings",26)
	for entry in [["master","Master volume",0.0,1.0],["music","Music volume",0.0,1.0],["sfx","Effects volume",0.0,1.0],["ui_scale","UI scale",0.8,1.5],["pan_speed","Camera pan speed",0.25,3.0]]:
		var line := HBoxContainer.new()
		_column.add_child(line)
		var label := Label.new()
		label.text = entry[1]
		label.custom_minimum_size.x = 150
		line.add_child(label)
		var slider := HSlider.new()
		slider.min_value = entry[2]
		slider.max_value = entry[3]
		slider.step = 0.05
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value = settings.values[entry[0]]
		line.add_child(slider)
		var readout := Label.new()
		readout.custom_minimum_size.x = 50
		readout.text = "%.0f%%" % (slider.value*100.0)
		line.add_child(readout)
		slider.value_changed.connect(func(value):
			readout.text = "%.0f%%" % (value*100.0)
			_update_setting(entry[0],value)
		)
		settings_controls[entry[0]] = slider
	for entry in [["edge_pan","Pan at screen edges"],["fullscreen","Fullscreen"],["debug_overlay","Allow diagnostics (F3)"]]:
		var toggle := CheckButton.new()
		toggle.text = entry[1]
		toggle.button_pressed = settings.values[entry[0]]
		toggle.toggled.connect(func(value): _update_setting(entry[0],value))
		_column.add_child(toggle)
		settings_controls[entry[0]] = toggle
	_button("back","Back",func(): show_page("pause" if world != null else "main"))

func _update_setting(key: String, value: Variant) -> void:
	settings.set_value(key,value)
	settings.apply(world.camera if world != null else null)
	var ok := settings.save_to_disk()
	_status.text = "Saved" if ok else settings.error
	if key == "ui_scale":
		_scale_menu(_card,float(value))
		_card.custom_minimum_size.x = minf(520.0*float(value),get_viewport().get_visible_rect().size.x-32.0)

func _scale_menu(node: Node, value: float) -> void:
	if node is Control:
		if not node.has_meta("base_font_size"): node.set_meta("base_font_size",13)
		node.add_theme_font_size_override("font_size",roundi(int(node.get_meta("base_font_size"))*value))
	for child in node.get_children(): _scale_menu(child,value)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if _overlay.visible:
		if event.keycode == KEY_ESCAPE:
			if page == "pause": resume()
			elif page == "confirm": show_page(_return_page)
			elif page != "main": show_page("pause" if world != null else "main")
			get_viewport().set_input_as_handled()
		return
	if event.keycode in [KEY_F5,KEY_F9]:
		open_menu("save" if event.keycode == KEY_F5 else "load")
		get_viewport().set_input_as_handled()
