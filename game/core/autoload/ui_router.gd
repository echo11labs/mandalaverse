class_name GopalaUIRouter
extends Node
## UIRouter - single owner of major panel and world-tool mode transitions.
## Contract: docs/UI_CONTRACT.md section 5/section 10. Stores modes, IDs and
## plain data payloads only; never retains scene-node references.
##
## Reset contract (explicit, not automatic): autoloads persist across scene
## changes, so nothing here reacts to SceneTree.tree_changed. The future scene
## coordinator must call prepare_for_scene_change()/reset() explicitly
## before/while swapping world scenes, and tests call reset() at
## setup/teardown.
##
## Block 1 deliberately knows nothing about placement, selection or world
## commands; those arrive in later blocks through approved interfaces.

signal mode_changed(previous: StringName, current: StringName, reason: StringName)
signal mode_rejected(requested: StringName, code: StringName)
signal panel_pushed(panel_id: StringName, depth: int)
signal panel_popped(panel_id: StringName, depth: int)
signal reset_performed()

const MODE_NORMAL: StringName = &"normal"
const MODE_BUILD_CATALOG: StringName = &"build_catalog"
const MODE_PLACING_BUILDING: StringName = &"placing_building"
const MODE_DRAWING_ROAD: StringName = &"drawing_road"
const MODE_MARKING_HARVEST: StringName = &"marking_harvest"
const MODE_MARKING_CLEAR: StringName = &"marking_clear"
const MODE_PLACING_ZONE: StringName = &"placing_zone"
const MODE_TERRAFORMING: StringName = &"terraforming"
const MODE_EXPLORING: StringName = &"exploring"
const MODE_COMMANDING_UNITS: StringName = &"commanding_units"
const MODE_MODAL_WINDOW: StringName = &"modal_window"

const WORLD_TOOL_MODES: Array[StringName] = [
	MODE_BUILD_CATALOG,
	MODE_PLACING_BUILDING,
	MODE_DRAWING_ROAD,
	MODE_MARKING_HARVEST,
	MODE_MARKING_CLEAR,
	MODE_PLACING_ZONE,
	MODE_TERRAFORMING,
	MODE_EXPLORING,
	MODE_COMMANDING_UNITS,
]

const MAX_PANEL_DEPTH: int = 8

# Result codes (StringName so tests and UI can compare without parsing text).
const CODE_OK: StringName = &"OK"
const CODE_INVALID_MODE: StringName = &"INVALID_MODE"
const CODE_INVALID_PAYLOAD: StringName = &"INVALID_PAYLOAD"
const CODE_UNKNOWN_MODE: StringName = &"UNKNOWN_MODE"
const CODE_SAME_MODE: StringName = &"SAME_MODE"
const CODE_TRANSITION_FORBIDDEN: StringName = &"TRANSITION_FORBIDDEN"
const CODE_NOT_IN_MODE: StringName = &"NOT_IN_MODE"
const CODE_INVALID_PANEL_ID: StringName = &"INVALID_PANEL_ID"
const CODE_PANEL_OVERFLOW: StringName = &"PANEL_OVERFLOW"
const CODE_EMPTY_STACK: StringName = &"EMPTY_STACK"

class TransitionResult:
	extends RefCounted
	var ok: bool = false
	var code: StringName = &""
	## Mode current after the call, whatever the outcome.
	var mode: StringName = &""

class PopResult:
	extends RefCounted
	var ok: bool = false
	var code: StringName = &""
	var panel_id: StringName = &""
	var payload: Dictionary = {}

## Runtime accessor: `--check-only` compilation cannot resolve autoload
## identifiers in this engine build, so scripts reach the singleton through
## the scene tree with this class_name-typed helper instead.
static func router() -> GopalaUIRouter:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	# Relative lookup: absolute paths error while the tree is still outside its
	# active phase (SceneTree::_initialize), which is when tests resolve it.
	return tree.root.get_node_or_null(^"UIRouter") as GopalaUIRouter

var current_mode: StringName = MODE_NORMAL

var _mode_payload: Dictionary = {}
var _panel_stack: Array[Dictionary] = []
var _transient: Dictionary = {}

# ----------------------------------------------------------------- modes

func request_mode(mode: Variant, payload: Variant = {}) -> TransitionResult:
	var result := TransitionResult.new()
	result.mode = current_mode
	if not (mode is StringName or mode is String):
		mode_rejected.emit(&"", CODE_INVALID_MODE)
		result.code = CODE_INVALID_MODE
		return result
	var next := StringName(mode)
	if payload == null or not (payload is Dictionary):
		mode_rejected.emit(next, CODE_INVALID_PAYLOAD)
		result.code = CODE_INVALID_PAYLOAD
		return result
	if not _is_plain_data(payload):
		mode_rejected.emit(next, CODE_INVALID_PAYLOAD)
		result.code = CODE_INVALID_PAYLOAD
		return result
	if not _is_known_mode(next):
		mode_rejected.emit(next, CODE_UNKNOWN_MODE)
		result.code = CODE_UNKNOWN_MODE
		return result
	if next == current_mode:
		mode_rejected.emit(next, CODE_SAME_MODE)
		result.code = CODE_SAME_MODE
		return result
	if current_mode == MODE_MODAL_WINDOW and _is_world_tool(next):
		# A modal must close through normal before a world tool may start.
		mode_rejected.emit(next, CODE_TRANSITION_FORBIDDEN)
		result.code = CODE_TRANSITION_FORBIDDEN
		return result
	var previous := current_mode
	var reason := _transition_reason(previous, next)
	current_mode = next
	_mode_payload = (payload as Dictionary).duplicate(true)
	_transient.clear()
	result.ok = true
	result.code = CODE_OK
	result.mode = current_mode
	mode_changed.emit(previous, current_mode, reason)
	return result

func exit_current_mode(reason: Variant = &"exited") -> TransitionResult:
	var result := TransitionResult.new()
	result.mode = current_mode
	if current_mode == MODE_NORMAL:
		result.code = CODE_NOT_IN_MODE
		return result
	var previous := current_mode
	current_mode = MODE_NORMAL
	_mode_payload = {}
	_transient.clear()
	result.ok = true
	result.code = CODE_OK
	result.mode = current_mode
	var safe_reason := &"exited"
	if reason is StringName or reason is String:
		safe_reason = StringName(reason)
	mode_changed.emit(previous, current_mode, safe_reason)
	return result

func is_world_tool(mode: Variant) -> bool:
	if not (mode is StringName or mode is String):
		return false
	return _is_world_tool(StringName(mode))

func world_tool_modes() -> Array[StringName]:
	return WORLD_TOOL_MODES.duplicate()

func get_mode_payload() -> Dictionary:
	return _mode_payload.duplicate(true)

# ----------------------------------------------------------------- panels

func push_panel(panel_id: Variant, payload: Variant = {}) -> TransitionResult:
	var result := TransitionResult.new()
	result.mode = current_mode
	if not (panel_id is StringName or panel_id is String):
		result.code = CODE_INVALID_PANEL_ID
		return result
	var id := StringName(panel_id)
	if String(id).is_empty():
		result.code = CODE_INVALID_PANEL_ID
		return result
	if payload == null or not (payload is Dictionary) or not _is_plain_data(payload):
		result.code = CODE_INVALID_PAYLOAD
		return result
	if _panel_stack.size() >= MAX_PANEL_DEPTH:
		result.code = CODE_PANEL_OVERFLOW
		return result
	_panel_stack.append({"id": id, "payload": (payload as Dictionary).duplicate(true)})
	result.ok = true
	result.code = CODE_OK
	result.mode = current_mode
	panel_pushed.emit(id, _panel_stack.size())
	return result

func pop_panel() -> PopResult:
	var result := PopResult.new()
	if _panel_stack.is_empty():
		result.code = CODE_EMPTY_STACK
		return result
	var entry: Dictionary = _panel_stack.pop_back()
	var id := StringName(entry.get("id", &""))
	result.ok = true
	result.code = CODE_OK
	result.panel_id = id
	var stored: Variant = entry.get("payload", {})
	result.payload = stored.duplicate(true) if stored is Dictionary else {}
	panel_popped.emit(id, _panel_stack.size())
	return result

func panel_depth() -> int:
	return _panel_stack.size()

func peek_panel_id() -> StringName:
	if _panel_stack.is_empty():
		return &""
	return StringName(_panel_stack[_panel_stack.size() - 1].get("id", &""))

func has_panel(panel_id: StringName) -> bool:
	for entry in _panel_stack:
		if StringName(entry.get("id", &"")) == panel_id:
			return true
	return false

# ----------------------------------------------------------------- transient

func set_transient(key: StringName, value: Variant) -> bool:
	if not _is_plain_data(value):
		return false
	_transient[key] = value
	return true

func get_transient(key: StringName, fallback: Variant = null) -> Variant:
	return _transient.get(key, fallback)

func clear_transient() -> void:
	_transient.clear()

# ----------------------------------------------------------------- lifecycle

func reset() -> void:
	var previous := current_mode
	current_mode = MODE_NORMAL
	_mode_payload = {}
	_panel_stack.clear()
	_transient.clear()
	if previous != MODE_NORMAL:
		mode_changed.emit(previous, MODE_NORMAL, &"reset")
	reset_performed.emit()

## Explicit scene-transition hook: delegates to reset(). Named for the future
## scene coordinator, which must call this before/while changing world scenes
## (autoloads survive scene changes, so no reset ever happens automatically).
func prepare_for_scene_change() -> void:
	reset()

# ----------------------------------------------------------------- internals

func _is_known_mode(mode: StringName) -> bool:
	return mode == MODE_NORMAL or mode == MODE_MODAL_WINDOW or _is_world_tool(mode)

func _is_world_tool(mode: StringName) -> bool:
	return WORLD_TOOL_MODES.has(mode)

func _transition_reason(previous: StringName, next: StringName) -> StringName:
	if previous == MODE_MODAL_WINDOW and next == MODE_NORMAL:
		return &"closed"
	if _is_world_tool(previous) and next == MODE_NORMAL:
		return &"exited"
	if previous == MODE_NORMAL:
		return &"entered"
	return &"switched"

## Payloads must contain plain data only. Objects (including Node references)
## are rejected so the router can never retain scene references.
func _is_plain_data(value: Variant, depth: int = 0) -> bool:
	if depth > 8:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, \
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_RECT2, TYPE_COLOR:
			return true
		TYPE_DICTIONARY:
			for key in value:
				if not _is_plain_data(key, depth + 1):
					return false
				if not _is_plain_data(value[key], depth + 1):
					return false
			return true
		TYPE_ARRAY:
			for item in value:
				if not _is_plain_data(item, depth + 1):
					return false
			return true
		_:
			return false
