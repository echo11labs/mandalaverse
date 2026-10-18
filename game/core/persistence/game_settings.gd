class_name GopalaGameSettings
extends RefCounted
## Front-door preferences; independent of settlement saves and simulation balance.
const DEFAULTS := {"master":1.0,"music":0.8,"sfx":0.8,"ui_scale":1.0,"edge_pan":false,"pan_speed":1.0,"fullscreen":false,"debug_overlay":false}
var values := DEFAULTS.duplicate()
var storage_path := "user://settings.cfg"
var error := ""

func set_value(key: String, value: Variant) -> bool:
	if not DEFAULTS.has(key): return false
	if DEFAULTS[key] is bool:
		if not value is bool: return false
	else:
		if not (value is float or value is int) or not is_finite(float(value)): return false
		var low := 0.8 if key == "ui_scale" else (0.25 if key == "pan_speed" else 0.0)
		var high := 1.5 if key == "ui_scale" else (3.0 if key == "pan_speed" else 1.0)
		value = clampf(float(value),low,high)
	values[key] = value
	return true

func load_from_disk() -> bool:
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(storage_path) != OK: return false
	if cfg.get_value("settings","version",0) != 1: return false
	for key in DEFAULTS: set_value(key,cfg.get_value("settings",key,DEFAULTS[key]))
	return true

func save_to_disk() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("settings","version",1)
	for key in values: cfg.set_value("settings",key,values[key])
	var result := cfg.save(storage_path)
	error = "" if result == OK else "Settings could not be saved: "+error_string(result)
	return result == OK

func apply(camera: Camera3D = null, apply_window := true) -> void:
	for pair in [["master","Master"],["music","Music"],["sfx","SFX"]]:
		var index := AudioServer.get_bus_index(pair[1])
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count-1
			AudioServer.set_bus_name(index,pair[1])
			AudioServer.set_bus_send(index,"Master")
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(0.0001,float(values[pair[0]]))))
		AudioServer.set_bus_mute(index,float(values[pair[0]]) <= 0.0)
	var ui := GopalaUISettings.settings()
	if ui != null: ui.ui_scale = float(values.ui_scale)
	if camera != null:
		camera.set("edge_pan_enabled",values.edge_pan)
		camera.set("pan_speed_multiplier",values.pan_speed)
		var hud = camera.get_parent().get("hud")
		if hud != null: hud.apply_ui_scale(float(values.ui_scale))
		var overlay = camera.get_parent().get("debug_overlay")
		if overlay != null: overlay.set_release_flag(bool(values.debug_overlay))
	if apply_window and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
