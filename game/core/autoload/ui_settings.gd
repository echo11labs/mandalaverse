class_name GopalaUISettings
extends Node
## UISettings - durable HUD presentation preferences with validation.
## Contract: docs/UI_CONTRACT.md section 0/section 10. Persists a versioned
## schema to user://ui_settings.json; missing, malformed and future-version
## files fall back to safe defaults without crashing. Keybinding persistence
## is out of scope until the rebinding service exists (Block 6).

signal changed(key: StringName)

const SAVE_PATH: String = "user://ui_settings.json"
const FORMAT_VERSION: int = 1

const UI_SCALE_MIN: float = 0.8
const UI_SCALE_MAX: float = 1.5
const TOOLTIP_DELAY_MIN: float = 0.0
const TOOLTIP_DELAY_MAX: float = 2.0
const NOTIFICATION_DURATION_MIN: float = 0.5
const NOTIFICATION_DURATION_MAX: float = 30.0
const COLOR_BLIND_MODES: Array[StringName] = [
	&"off", &"protanopia", &"deuteranopia", &"tritanopia",
]

const KEY_UI_SCALE: StringName = &"ui_scale"
const KEY_HIGH_CONTRAST: StringName = &"high_contrast"
const KEY_REDUCED_MOTION: StringName = &"reduced_motion"
const KEY_TOOLTIP_DELAY: StringName = &"tooltip_delay"
const KEY_NOTIFICATION_DURATION: StringName = &"notification_duration"
const KEY_COLOR_BLIND_MODE: StringName = &"color_blind_mode"

## Runtime accessor: `--check-only` compilation cannot resolve autoload
## identifiers in this engine build, so scripts reach the singleton through
## the scene tree with this class_name-typed helper instead.
static func settings() -> GopalaUISettings:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	# Relative lookup: absolute paths error while the tree is still outside its
	# active phase (SceneTree::_initialize), which is when tests resolve it.
	return tree.root.get_node_or_null(^"UISettings") as GopalaUISettings

## Result of the most recent load_from_disk(): &"missing", &"ok",
## &"malformed" or &"future_version". Lets tests assert recovery paths
## without emitting engine warnings.
var last_load_status: StringName = &"missing"

## Injectable storage location (FIX 2 test isolation). Production default is
## SAVE_PATH; tests repoint this at a unique path under user://tests/ and
## restore it afterwards, so the production file is never written by tests.
var storage_path: String = SAVE_PATH

var ui_scale: float = 1.0:
	set(value):
		var next := clampf(float(value), UI_SCALE_MIN, UI_SCALE_MAX)
		if not is_equal_approx(next, ui_scale):
			ui_scale = next
			changed.emit(KEY_UI_SCALE)

var high_contrast: bool = false:
	set(value):
		if value != high_contrast:
			high_contrast = value
			changed.emit(KEY_HIGH_CONTRAST)

var reduced_motion: bool = false:
	set(value):
		if value != reduced_motion:
			reduced_motion = value
			changed.emit(KEY_REDUCED_MOTION)

var tooltip_delay: float = 0.3:
	set(value):
		var next := clampf(float(value), TOOLTIP_DELAY_MIN, TOOLTIP_DELAY_MAX)
		if not is_equal_approx(next, tooltip_delay):
			tooltip_delay = next
			changed.emit(KEY_TOOLTIP_DELAY)

var notification_duration: float = 4.0:
	set(value):
		var next := clampf(float(value), NOTIFICATION_DURATION_MIN, NOTIFICATION_DURATION_MAX)
		if not is_equal_approx(next, notification_duration):
			notification_duration = next
			changed.emit(KEY_NOTIFICATION_DURATION)

var color_blind_mode: StringName = &"off":
	set(value):
		var next := StringName(value)
		if COLOR_BLIND_MODES.has(next) and next != color_blind_mode:
			color_blind_mode = next
			changed.emit(KEY_COLOR_BLIND_MODE)

func _ready() -> void:
	load_from_disk()

## Validates one key/value pair. Returns false (leaving state untouched) for
## unknown keys or wrong types; numeric values are clamped into safe ranges.
func set_value(key: StringName, value: Variant) -> bool:
	match key:
		KEY_UI_SCALE:
			if not (value is float or value is int):
				return false
			ui_scale = float(value)
			return true
		KEY_HIGH_CONTRAST:
			if not value is bool:
				return false
			high_contrast = value
			return true
		KEY_REDUCED_MOTION:
			if not value is bool:
				return false
			reduced_motion = value
			return true
		KEY_TOOLTIP_DELAY:
			if not (value is float or value is int):
				return false
			tooltip_delay = float(value)
			return true
		KEY_NOTIFICATION_DURATION:
			if not (value is float or value is int):
				return false
			notification_duration = float(value)
			return true
		KEY_COLOR_BLIND_MODE:
			if not (value is String or value is StringName):
				return false
			var mode := StringName(value)
			if not COLOR_BLIND_MODES.has(mode):
				return false
			color_blind_mode = mode
			return true
	return false

func as_dict() -> Dictionary:
	return {
		"ui_scale": ui_scale,
		"high_contrast": high_contrast,
		"reduced_motion": reduced_motion,
		"tooltip_delay": tooltip_delay,
		"notification_duration": notification_duration,
		"color_blind_mode": String(color_blind_mode),
	}

func reset_to_defaults() -> void:
	set_value(KEY_UI_SCALE, 1.0)
	set_value(KEY_HIGH_CONTRAST, false)
	set_value(KEY_REDUCED_MOTION, false)
	set_value(KEY_TOOLTIP_DELAY, 0.3)
	set_value(KEY_NOTIFICATION_DURATION, 4.0)
	set_value(KEY_COLOR_BLIND_MODE, &"off")

func save_to_disk() -> bool:
	var data := as_dict()
	data["version"] = FORMAT_VERSION
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file == null:
		push_warning("UISettings: cannot write %s (%s)" % [storage_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

## Returns true only when a file was read and applied. Failures never crash:
## state falls back to safe defaults and last_load_status explains why.
## silent=true suppresses the production push_warning (used by tests).
func load_from_disk(silent: bool = false) -> bool:
	if not FileAccess.file_exists(storage_path):
		last_load_status = &"missing"
		return false
	var text := FileAccess.get_file_as_string(storage_path)
	# JSON.new().parse() reports failure through its return code; the
	# JSON.parse_string() convenience wrapper prints an engine ERROR line that
	# the verify gate (and headless logs) treat as a real failure.
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK or not json.data is Dictionary:
		last_load_status = &"malformed"
		if not silent:
			push_warning("UISettings: %s is not a JSON object; using defaults." % storage_path)
		reset_to_defaults()
		return false
	var data: Dictionary = json.data
	var version := int(data.get("version", -1))
	if version > FORMAT_VERSION:
		last_load_status = &"future_version"
		if not silent:
			push_warning("UISettings: %s has future version %d; using defaults." % [storage_path, version])
		reset_to_defaults()
		return false
	if version < 1:
		last_load_status = &"malformed"
		if not silent:
			push_warning("UISettings: %s has no valid version; using defaults." % storage_path)
		reset_to_defaults()
		return false
	# A successful load replaces every value: defaults first, then file data.
	reset_to_defaults()
	for key in [KEY_UI_SCALE, KEY_HIGH_CONTRAST, KEY_REDUCED_MOTION, KEY_TOOLTIP_DELAY, KEY_NOTIFICATION_DURATION, KEY_COLOR_BLIND_MODE]:
		if data.has(key):
			set_value(key, data[key])
	last_load_status = &"ok"
	return true
