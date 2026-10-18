class_name GopalaDebugOverlay
extends Node
## Scene-owned, read-only diagnostic view. Timing never enters simulation state.
var sim: GopalaSettlementSimulation
var world: Node3D
var enabled := false
var release_flag := false
var developer_build := OS.is_debug_build()
var samples: Array[float] = []
var path_points: Array[Vector2] = []
var selected_data := {}
var _started_usec := 0
var _started_tick := -1
var _elapsed := 0.0
var _panel: PanelContainer
var _label: Label
var _path: MeshInstance3D

static func allowed(debug_build: bool, flag: bool) -> bool: return debug_build or flag

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.name = "Diagnostics"
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -300
	_panel.offset_right = 300
	_panel.offset_top = 64
	_panel.offset_bottom = 510
	_panel.theme = GopalaTheme.navbar()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_override("font",GopalaTheme.font(GopalaTheme.FONT_MONO,400,12))
	_label.add_theme_font_size_override("font_size",12)
	scroll.add_child(_label)
	_path = MeshInstance3D.new()
	_path.name = "DebugRoute"
	add_child(_path)
	_panel.visible = false
	_path.visible = false

func bind(authority: GopalaSettlementSimulation) -> void:
	_disconnect()
	sim = authority
	samples.clear()
	_started_tick = -1
	sim.logical_tick_advanced.connect(_tick_started)
	sim.fixed_tick_completed.connect(_tick_finished)
	if enabled: refresh()

func _disconnect() -> void:
	if is_instance_valid(sim):
		if sim.logical_tick_advanced.is_connected(_tick_started): sim.logical_tick_advanced.disconnect(_tick_started)
		if sim.fixed_tick_completed.is_connected(_tick_finished): sim.fixed_tick_completed.disconnect(_tick_finished)

func _exit_tree() -> void: _disconnect()

func _tick_started(tick: int) -> void:
	_started_tick = tick
	_started_usec = Time.get_ticks_usec()

func _tick_finished(tick: int) -> void:
	if tick == _started_tick: record_sample(float(Time.get_ticks_usec()-_started_usec)/1000.0)
	_started_tick = -1

func record_sample(milliseconds: float) -> void:
	if not is_finite(milliseconds) or milliseconds < 0.0: return
	samples.append(milliseconds)
	if samples.size() > 300: samples.pop_front()

func timings() -> Dictionary:
	var total := 0.0
	var maximum := 0.0
	for value in samples:
		total += value
		maximum = maxf(maximum,value)
	return {"count":samples.size(),"average":total/maxi(1,samples.size()),"maximum":maximum}

func set_release_flag(value: bool) -> void:
	release_flag = value
	if not allowed(developer_build,release_flag): set_enabled(false)

func toggle() -> void:
	if allowed(developer_build,release_flag): set_enabled(not enabled)

func set_enabled(value: bool) -> void:
	enabled = value and allowed(developer_build,release_flag)
	_panel.visible = enabled
	_path.visible = enabled
	if enabled: refresh()
	else:
		path_points.clear()
		_path.mesh = null

func _process(delta: float) -> void:
	if not enabled: return
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		refresh()

func _unhandled_input(event: InputEvent) -> void:
	if world != null and world.get("menu_input_blocked"): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		toggle()
		get_viewport().set_input_as_handled()

func refresh() -> void:
	if not is_instance_valid(sim): return
	var snapshot := sim.snapshot()
	var time := timings()
	selected_data = GopalaDebugInspection.selected(sim)
	_label.text = "DIAGNOSTICS · F3 to close · read-only\nTick %d · %d× · %s\nObserved tick body: avg %.3f ms / max %.3f ms (%d of last 300 ticks)\nEntities %d · %s\n\n%s" % [snapshot.logical_tick,snapshot.speed,"paused" if snapshot.paused else "running",time.average,time.maximum,time.count,snapshot.entity_count,str(snapshot.entity_counts_by_kind),GopalaDebugInspection.format(selected_data)]
	path_points.clear()
	path_points.assign(selected_data.get("path",[]))
	_draw_path()

func _draw_path() -> void:
	if path_points.size() < 2:
		_path.mesh = null
		return
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffe571")
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,material)
	for point in path_points:
		var height := float(world.ground_height_at(point.x,point.y)) if world != null else 0.0
		mesh.surface_add_vertex(Vector3(point.x,height+GopalaScaleStandard.metres_to_world(0.15),point.y))
	mesh.surface_end()
	_path.mesh = mesh
