extends SceneTree
## Block 1 foundation tests: UIRouter transitions, UISettings persistence and
## validation, required InputMap actions, tokens/theme, component contracts and
## exact virtual-resolution layout checks for the component gallery.

const GALLERY_SCENE := preload("res://scenes/ui/component_gallery.tscn")

class WorldInputReceiver extends Node:
	var left_mouse_presses := 0

	func _unhandled_input(event: InputEvent) -> void:
		var mouse_event := event as InputEventMouseButton
		if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			left_mouse_presses += 1

var failures: Array[String] = []
var checks := 0
var _mode_events: Array = []
var _reject_events: Array = []
var _reset_fired := false

# Autoload singletons reached through class_name accessors: bare autoload
# identifiers do not resolve when a script runs via --script, and
# --check-only cannot see them either (recorded Block 1 toolchain finding).
var router: GopalaUIRouter
var settings: GopalaUISettings
var legacy_events: Node

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _expect_control_descendants_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			expect((child as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"decorative child %s ignores the mouse" % String(child.get_path()))
		_expect_control_descendants_ignore(child)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	router = GopalaUIRouter.router()
	settings = GopalaUISettings.settings()
	legacy_events = root.get_node_or_null(^"UIEvents")
	_test_autoloads()
	_test_router()
	_test_settings()
	_test_input_map()
	_test_tokens_and_theme()
	_test_shortcut_tooltip()
	await _test_components()
	await _test_virtual_resolutions()
	print("GOPALA_TEST_REPORT=", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

# ------------------------------------------------------------------ autoloads

func _test_autoloads() -> void:
	expect(router != null, "UIRouter autoload is available")
	expect(settings != null, "UISettings autoload is available")
	expect(legacy_events != null, "UIEvents autoload is available")
	if router != null:
		for method in ["request_mode", "exit_current_mode", "push_panel", "pop_panel", "reset"]:
			expect(router.has_method(method), "UIRouter exposes " + method)
	if settings != null:
		for method in ["set_value", "as_dict", "save_to_disk", "load_from_disk", "reset_to_defaults"]:
			expect(settings.has_method(method), "UISettings exposes " + method)
	# The four legacy UIEvents signals must survive Block 1 untouched.
	if legacy_events != null:
		for signal_name in ["resource_updated", "objective_progressed", "build_action_requested", "event_logged"]:
			expect(legacy_events.has_signal(signal_name), "legacy UIEvents signal preserved: " + signal_name)

# ---------------------------------------------------------------------- router

func _on_mode_changed(previous: StringName, current: StringName, reason: StringName) -> void:
	_mode_events.append([previous, current, reason])

func _on_mode_rejected(requested: StringName, code: StringName) -> void:
	_reject_events.append([requested, code])

func _test_router() -> void:
	router.reset()
	_mode_events.clear()
	_reject_events.clear()
	_reset_fired = false
	if not router.mode_changed.is_connected(_on_mode_changed):
		router.mode_changed.connect(_on_mode_changed)
	if not router.mode_rejected.is_connected(_on_mode_rejected):
		router.mode_rejected.connect(_on_mode_rejected)
	if not router.reset_performed.is_connected(_on_reset):
		router.reset_performed.connect(_on_reset)

	expect(router.current_mode == &"normal", "router starts in normal")
	expect(router.panel_depth() == 0, "router starts with an empty panel stack")

	# One world tool at a time: tool -> tool replaces cleanly.
	var entered := router.request_mode(&"build_catalog")
	expect(entered.ok and entered.code == &"OK", "enter build_catalog succeeds")
	expect(router.current_mode == &"build_catalog", "current mode is build_catalog")
	expect(_mode_events.size() == 1 and _mode_events[0][2] == &"entered", "enter emits entered")
	var switched := router.request_mode(&"drawing_road")
	expect(switched.ok and router.current_mode == &"drawing_road", "tool switch succeeds")
	expect(_mode_events.size() == 2 and _mode_events[1][0] == &"build_catalog" and _mode_events[1][2] == &"switched",
		"tool switch emits switched from the previous tool")

	# Modal flow.
	var to_modal := router.request_mode(&"modal_window")
	expect(to_modal.ok and router.current_mode == &"modal_window", "modal opens from a tool")
	var forbidden := router.request_mode(&"marking_harvest")
	expect(not forbidden.ok and forbidden.code == &"TRANSITION_FORBIDDEN",
		"modal rejects direct transition to a world tool")
	expect(router.current_mode == &"modal_window", "rejected transition leaves mode unchanged")
	expect(_reject_events.size() == 1 and _reject_events[0][1] == &"TRANSITION_FORBIDDEN",
		"mode_rejected reports the typed code")
	var closed := router.request_mode(&"normal")
	expect(closed.ok and _mode_events.back()[2] == &"closed", "modal closes through normal")

	# Rejections: unknown, same, bad payload types, object payloads.
	var unknown := router.request_mode(&"warp_zone")
	expect(not unknown.ok and unknown.code == &"UNKNOWN_MODE", "unknown mode rejected")
	var same := router.request_mode(&"normal")
	expect(not same.ok and same.code == &"SAME_MODE", "same mode rejected")
	var bad_payload := router.request_mode(&"build_catalog", "not-a-dict")
	expect(not bad_payload.ok and bad_payload.code == &"INVALID_PAYLOAD", "non-dict payload rejected")
	var scratch := Node.new()
	var object_payload := router.request_mode(&"build_catalog", {"node": scratch})
	expect(not object_payload.ok and object_payload.code == &"INVALID_PAYLOAD",
		"payload containing an Object is rejected (no node references retained)")
	scratch.free()
	expect(router.current_mode == &"normal", "all rejected requests leave normal untouched")

	# Exit rules.
	var not_in_mode := router.exit_current_mode()
	expect(not not_in_mode.ok and not_in_mode.code == &"NOT_IN_MODE", "exit from normal rejected")
	router.request_mode(&"terraforming")
	var exited := router.exit_current_mode()
	expect(exited.ok and router.current_mode == &"normal", "exit returns to normal")
	expect(_mode_events.back()[2] == &"exited", "exit reason is exited")

	# Payload storage: copied, not referenced; cleared on exit.
	var payload := {"building": &"dwelling", "count": 1}
	var with_payload := router.request_mode(&"placing_building", payload)
	expect(with_payload.ok, "mode with payload succeeds")
	payload["count"] = 99
	var stored: Dictionary = router.get_mode_payload()
	expect(StringName(stored.get("building", &"")) == &"dwelling" and int(stored.get("count", 0)) == 1,
		"payload is deep-copied")
	router.exit_current_mode()
	expect(router.get_mode_payload().is_empty(), "payload cleared on exit")

	# Transient state.
	expect(router.set_transient(&"k", 5), "plain transient value accepted")
	expect(int(router.get_transient(&"k", 0)) == 5, "transient readable")
	var scratch_two := Node.new()
	expect(not router.set_transient(&"bad", scratch_two), "node transient rejected")
	scratch_two.free()

	# Panel stack.
	var pushed := router.push_panel(&"context", {"entity": 7})
	expect(pushed.ok and router.panel_depth() == 1 and router.peek_panel_id() == &"context",
		"panel push works")
	expect(router.has_panel(&"context"), "has_panel finds the stack entry")
	var bad_id := router.push_panel(&"")
	expect(not bad_id.ok and bad_id.code == &"INVALID_PANEL_ID", "empty panel id rejected")
	var bad_panel_payload := router.push_panel(&"other", 42)
	expect(not bad_panel_payload.ok and bad_panel_payload.code == &"INVALID_PAYLOAD",
		"non-dict panel payload rejected")
	var popped := router.pop_panel()
	expect(popped.ok and popped.panel_id == &"context" and int(popped.payload.get("entity", 0)) == 7,
		"pop returns id and payload")
	var empty := router.pop_panel()
	expect(not empty.ok and empty.code == &"EMPTY_STACK", "pop on empty stack rejected")
	for index in 8:
		var depth_push := router.push_panel(&"p", {"n": index})
		expect(depth_push.ok, "panel push %d within depth" % index)
	var overflow := router.push_panel(&"p")
	expect(not overflow.ok and overflow.code == &"PANEL_OVERFLOW", "panel overflow rejected")

	# Reset clears everything.
	router.request_mode(&"placing_zone", {"a": 1})
	router.reset()
	_reset_check()

	# Explicit scene-transition contract: prepare_for_scene_change() delegates
	# to reset(); autoloads survive scene changes and never reset automatically.
	router.request_mode(&"marking_clear", {"a": 1})
	router.push_panel(&"context_panel", {"x": 2})
	router.set_transient(&"k", 9)
	_reset_fired = false
	router.prepare_for_scene_change()
	expect(_reset_fired, "prepare_for_scene_change emits reset_performed")
	expect(router.current_mode == &"normal", "prepare_for_scene_change returns to normal")
	expect(router.get_mode_payload().is_empty(), "prepare_for_scene_change clears the payload")
	expect(router.panel_depth() == 0, "prepare_for_scene_change clears the panel stack")
	expect(router.get_transient(&"k") == null, "prepare_for_scene_change clears transient data")

func _on_reset() -> void:
	_reset_fired = true

func _reset_check() -> void:
	expect(_reset_fired, "reset emits reset_performed")
	expect(router.current_mode == &"normal", "reset returns to normal")
	expect(router.panel_depth() == 0, "reset clears the panel stack")
	expect(router.get_mode_payload().is_empty(), "reset clears the mode payload")
	expect(router.get_transient(&"k") == null, "reset clears transient state")

# -------------------------------------------------------------------- settings

func _write_settings_file(text_value: String) -> void:
	var file := FileAccess.open(settings.storage_path, FileAccess.WRITE)
	expect(file != null, "settings file writable for test")
	if file != null:
		file.store_string(text_value)
		file.close()

func _test_settings() -> void:
	# FIX 2 isolation: every disk test runs against a unique user://tests path.
	# The production file is snapshotted first and must stay byte-identical.
	var production_path := GopalaUISettings.SAVE_PATH
	var production_existed := FileAccess.file_exists(production_path)
	var production_content := FileAccess.get_file_as_string(production_path) if production_existed else ""
	var production_mtime := FileAccess.get_modified_time(production_path) if production_existed else 0
	var test_dir := "user://tests/ui_settings_%d_%d/" % [Time.get_ticks_usec(), randi()]
	expect(DirAccess.make_dir_recursive_absolute(test_dir) == OK, "test settings directory created")
	var test_file := test_dir + "ui_settings.json"
	settings.storage_path = test_file
	expect(settings.storage_path != production_path, "tests use an isolated storage path")

	settings.reset_to_defaults()
	expect(is_equal_approx(settings.ui_scale, 1.0), "default ui_scale is 1.0")
	expect(settings.high_contrast == false, "default high_contrast false")
	expect(settings.reduced_motion == false, "default reduced_motion false")
	expect(is_equal_approx(settings.tooltip_delay, 0.3), "default tooltip_delay 0.3")
	expect(is_equal_approx(settings.notification_duration, 4.0), "default notification_duration 4.0")
	expect(settings.color_blind_mode == &"off", "default color_blind_mode off")

	# Missing file on the fresh test path reports missing without crashing.
	expect(not settings.load_from_disk(true), "missing file returns false")
	expect(settings.last_load_status == &"missing", "missing file status recorded")

	# Validation and clamping.
	expect(settings.set_value(&"ui_scale", 0.5), "ui_scale accepts a numeric value")
	expect(is_equal_approx(settings.ui_scale, settings.UI_SCALE_MIN), "ui_scale clamps to 0.8")
	expect(settings.set_value(&"ui_scale", 2.0) and is_equal_approx(settings.ui_scale, settings.UI_SCALE_MAX),
		"ui_scale clamps to 1.5")
	expect(not settings.set_value(&"ui_scale", "wide"), "ui_scale rejects wrong type")
	expect(is_equal_approx(settings.ui_scale, settings.UI_SCALE_MAX), "rejected value leaves state unchanged")
	expect(not settings.set_value(&"not_a_key", 1), "unknown key rejected")
	expect(not settings.set_value(&"color_blind_mode", &"xray"), "unknown color-blind mode rejected")
	expect(settings.set_value(&"color_blind_mode", "protanopia") and settings.color_blind_mode == &"protanopia",
		"valid color-blind mode accepted")
	expect(settings.set_value(&"high_contrast", true) and settings.high_contrast, "bool accepted")
	expect(not settings.set_value(&"high_contrast", 1), "high_contrast rejects non-bool")
	expect(settings.set_value(&"tooltip_delay", 99.0) and is_equal_approx(settings.tooltip_delay, settings.TOOLTIP_DELAY_MAX),
		"tooltip_delay clamps to max")
	expect(settings.set_value(&"notification_duration", 0.01)
		and is_equal_approx(settings.notification_duration, settings.NOTIFICATION_DURATION_MIN),
		"notification_duration clamps to min")

	# Save / load roundtrip.
	settings.reset_to_defaults()
	settings.ui_scale = 1.25
	settings.high_contrast = true
	settings.color_blind_mode = &"deuteranopia"
	expect(settings.save_to_disk(), "save_to_disk succeeds")
	expect(settings.load_from_disk(true), "load_from_disk reads the saved file")
	expect(settings.last_load_status == &"ok", "load status ok")
	expect(is_equal_approx(settings.ui_scale, 1.25), "ui_scale roundtrips")
	expect(settings.high_contrast, "high_contrast roundtrips")
	expect(settings.color_blind_mode == &"deuteranopia", "color_blind_mode roundtrips")

	# Malformed data recovers to defaults without crashing.
	_write_settings_file("{ this is not json")
	expect(not settings.load_from_disk(true), "malformed file rejected")
	expect(settings.last_load_status == &"malformed", "malformed status recorded")
	expect(is_equal_approx(settings.ui_scale, 1.0), "malformed data falls back to defaults")
	expect(settings.color_blind_mode == &"off", "malformed data resets all fields")

	# Future versions fall back to defaults.
	_write_settings_file("{\"version\": 999, \"ui_scale\": 1.4}")
	expect(not settings.load_from_disk(true), "future version rejected")
	expect(settings.last_load_status == &"future_version", "future_version status recorded")
	expect(is_equal_approx(settings.ui_scale, 1.0), "future version falls back to defaults")

	# Wrong field types inside a valid file are ignored individually.
	_write_settings_file("{\"version\": 1, \"ui_scale\": \"huge\", \"high_contrast\": 1, \"notification_duration\": 7.5}")
	expect(settings.load_from_disk(true), "valid version applies")
	expect(settings.last_load_status == &"ok", "status ok with partial bad fields")
	expect(is_equal_approx(settings.ui_scale, 1.0), "bad ui_scale ignored")
	expect(settings.high_contrast == false, "bad high_contrast ignored")
	expect(is_equal_approx(settings.notification_duration, 7.5), "good field applied")

	# Save writes only to the isolated path, then restore + prove production safe.
	settings.reset_to_defaults()
	expect(settings.save_to_disk(), "save_to_disk succeeds on the test path")
	expect(FileAccess.file_exists(test_file), "settings file exists at " + test_file)
	settings.reset_to_defaults()
	expect(is_equal_approx(settings.ui_scale, 1.0), "defaults restored for later stages")

	settings.storage_path = production_path
	expect(settings.storage_path == GopalaUISettings.SAVE_PATH, "storage_path restored to production default")
	expect(FileAccess.file_exists(production_path) == production_existed,
		"production settings existence untouched")
	if production_existed:
		expect(FileAccess.get_modified_time(production_path) == production_mtime,
			"production settings mtime untouched")
		expect(FileAccess.get_file_as_string(production_path) == production_content,
			"production settings content untouched")

	# Delete only test-owned files.
	DirAccess.remove_absolute(test_file)
	DirAccess.remove_absolute(test_dir)
	expect(not FileAccess.file_exists(test_file), "test settings file cleaned up")

# ------------------------------------------------------------------- input map

func _test_input_map() -> void:
	var expected := {
		"simulation_pause": 32,
		"simulation_speed_1": 49,
		"simulation_speed_2": 50,
		"simulation_speed_3": 51,
		"simulation_speed_4": 52,
		"tool_select": 86,
		"tool_build": 66,
		"tool_road": 82,
		"tool_harvest": 72,
		"tool_clear": 88,
		"tool_zone": 90,
		"tool_terraform": 84,
		"tool_explore": 89,
		"overlay_cycle": 79,
		"placement_rotate_cw": 46,
		"placement_rotate_ccw": 44,
		"hud_toggle": 4194332,
		"management_toggle": 77,
		"notification_next": 74,
		"camera_focus_settlement": 67,
		"hud_grid": 71,
		"hud_names": 78,
	}
	for action in expected:
		var action_name := StringName(action)
		expect(InputMap.has_action(action_name), "action exists: " + action)
		if not InputMap.has_action(action_name):
			continue
		var events := InputMap.action_get_events(action_name)
		expect(events.size() >= 1, "action has a default binding: " + action)
		if events.is_empty():
			continue
		var key := events[0] as InputEventKey
		expect(key != null and key.physical_keycode == int(expected[action]),
			"action %s default physical keycode %d" % [action, int(expected[action])])
	var legacy_actions := ["camera_forward", "camera_back", "camera_left", "camera_right",
			"camera_zoom_in", "camera_zoom_out", "camera_rotate_left", "camera_rotate_right",
			"toggle_territory"]
	for legacy in legacy_actions:
		expect(InputMap.has_action(StringName(legacy)), "legacy action preserved: " + legacy)
	expect(not InputMap.has_action(&"build_menu_toggle"),
		"build_menu_toggle removed; tool_build is the single build action")
	# FIX 3 duplicate scan: among the project's own actions (Block 1 + legacy)
	# no keyboard event may be shared by two actions. Engine-builtin ui_*
	# defaults are upstream Godot behaviour and out of scope here.
	var project_actions := PackedStringArray()
	for action in expected:
		project_actions.append(String(action))
	for legacy_action in legacy_actions:
		project_actions.append(String(legacy_action))
	var event_owners := {}
	for action in project_actions:
		var action_name := StringName(action)
		if not InputMap.has_action(action_name):
			continue
		for event in InputMap.action_get_events(action_name):
			var key := event as InputEventKey
			if key == null:
				continue
			var code: Key = key.physical_keycode
			if code == KEY_NONE:
				code = key.keycode
			if code == KEY_NONE:
				continue
			var owners: Array = event_owners.get(code, [])
			if not owners.has(String(action)):
				owners.append(String(action))
			event_owners[code] = owners
	var shared := PackedStringArray()
	for code in event_owners:
		var owners: Array = event_owners[code]
		if owners.size() > 1:
			shared.append(str(owners))
	expect(shared.is_empty(),
		"no two GOPALA actions share a default key event (violations: " + ", ".join(shared) + ")")

# -------------------------------------------------------------- tokens / theme

func _test_tokens_and_theme() -> void:
	var tokens := UITokens.new()
	expect(tokens.space_1 == 4 and tokens.space_4 == 16 and tokens.space_6 == 32, "spacing tokens")
	expect(tokens.control_min_target == 44 and tokens.control_height_lg == 52, "sizing tokens")
	expect(tokens.text_body == 15 and tokens.text_heading == 20, "typography tokens")
	expect(is_equal_approx(tokens.motion_fast, 0.10) and is_equal_approx(tokens.motion_slow, 0.26),
		"motion tokens")
	expect(is_equal_approx(UITokens.scaled(100.0, 0.8), 80.0), "scaled() applies 80%")
	expect(is_equal_approx(UITokens.scaled(100.0, 2.0), 150.0), "scaled() clamps to 150%")
	expect(UITokens.truncate("abcdef", 4) == "abcd...", "truncate shortens long text")
	expect(UITokens.truncate("abc", 10) == "abc", "truncate leaves short text")
	var theme := GopalaTheme.build()
	expect(theme.default_font != null, "theme default font set")
	expect(theme.get_stylebox("normal", "Button") != null, "theme button styles present")
	expect(theme.get_stylebox("panel", "PanelContainer") != null, "theme panel style present")

func _test_shortcut_tooltip() -> void:
	expect(ShortcutTooltip.binding_text(&"hud_grid") == "G", "hud_grid resolves to G")
	expect(ShortcutTooltip.binding_text(&"no_such_action") == "", "unknown action resolves empty")
	var composed := ShortcutTooltip.compose("Toggle grid", &"hud_grid")
	expect(composed.contains("[G]") and composed.contains("Toggle grid"), "compose includes text and binding")
	InputMap.add_action("test_scratch_binding")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_K
	InputMap.action_add_event(&"test_scratch_binding", event)
	expect(ShortcutTooltip.binding_text(&"test_scratch_binding") == "K", "rebinding reflected immediately")
	InputMap.erase_action(&"test_scratch_binding")

# ------------------------------------------------------------------ components

func _test_components() -> void:
	settings.reset_to_defaults()

	# Icon button: states, focus, binding tooltip, long text, UI scale.
	var icon := (load("res://scenes/ui/components/icon_button/icon_button.tscn") as PackedScene).instantiate() as GopalaIconButton
	expect(icon != null, "icon button scene instantiates")
	root.add_child(icon)
	await process_frame
	expect(icon.focus_mode == Control.FOCUS_ALL, "icon button is focusable")
	expect(icon.mouse_filter == Control.MOUSE_FILTER_STOP, "icon button stops the mouse")
	expect(icon.clip_text, "icon button clips long labels")
	expect(is_equal_approx(icon.custom_minimum_size.y, 44.0), "icon button target at 100% scale")
	icon.grab_focus()
	expect(icon.has_focus(), "icon button takes keyboard focus")
	icon.action = &"hud_grid"
	icon.refresh_binding()
	expect(icon.tooltip_text.contains("[G]"), "icon tooltip shows resolved binding")
	icon.set_label("This label is far longer than sixteen characters")
	expect(icon.text.length() <= 19, "icon label truncated for long text")
	expect(icon.tooltip_text.contains("far longer"), "icon tooltip keeps full text")
	settings.set_value(&"ui_scale", 1.5)
	expect(is_equal_approx(icon.custom_minimum_size.y, 66.0), "icon button grows at 150%")
	settings.set_value(&"ui_scale", 0.8)
	expect(is_equal_approx(icon.custom_minimum_size.y, 35.2), "icon button shrinks at 80%")
	settings.set_value(&"ui_scale", 1.0)
	expect(is_equal_approx(icon.custom_minimum_size.y, 44.0), "icon button restored to 100%")
	icon.queue_free()
	await process_frame

	# Resource chip: decorative default, interactive variant, warning, long text.
	var chip := (load("res://scenes/ui/components/resource_chip/resource_chip.tscn") as PackedScene).instantiate() as GopalaResourceChip
	expect(chip != null, "resource chip scene instantiates")
	root.add_child(chip)
	await process_frame
	expect(chip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "decorative chip ignores mouse")
	expect(chip.get_node_or_null("Column/Row/Amount") != null, "chip required nodes exist")
	chip.set_amount(42)
	expect((chip.get_node("Column/Row/Amount") as Label).text == "42", "chip amount updates")
	chip.set_display_name("Long resource name ".repeat(20))
	expect((chip.get_node("Column/Name") as Label).text.length() <= 27, "chip name truncated")
	expect(chip.tooltip_text.contains("Long resource name"), "chip tooltip keeps full name")
	chip.set_warning(true, "Below reserve")
	expect((chip.get_node("Column/Name") as Label).text.begins_with("!"), "chip warning has a glyph prefix")
	expect(chip.tooltip_text == "Below reserve", "chip warning tooltip states the reason")
	chip.queue_free()
	await process_frame
	var hot_chip := (load("res://scenes/ui/components/resource_chip/resource_chip.tscn") as PackedScene).instantiate() as GopalaResourceChip
	hot_chip.interactive = true
	root.add_child(hot_chip)
	await process_frame
	expect(hot_chip.mouse_filter == Control.MOUSE_FILTER_STOP, "interactive chip stops the mouse")
	hot_chip.queue_free()
	await process_frame

	# Stat row.
	var stat := (load("res://scenes/ui/components/stat_row/stat_row.tscn") as PackedScene).instantiate() as GopalaStatRow
	expect(stat != null, "stat row scene instantiates")
	root.add_child(stat)
	await process_frame
	expect(stat.mouse_filter == Control.MOUSE_FILTER_IGNORE, "stat row ignores mouse")
	expect(stat.get_node_or_null("Key") != null and stat.get_node_or_null("Value") != null, "stat row required nodes")
	stat.set_key("Key ".repeat(40))
	expect((stat.get_node("Key") as Label).text.length() <= 43, "stat key truncated")
	stat.set_value_text("7")
	stat.set_warning(true)
	expect((stat.get_node("Value") as Label).text.begins_with("!"), "stat warning glyph present")
	stat.queue_free()
	await process_frame

	# Status badge: severity glyphs, never colour alone.
	var badge := (load("res://scenes/ui/components/status_badge/status_badge.tscn") as PackedScene).instantiate() as GopalaStatusBadge
	expect(badge != null, "badge scene instantiates")
	root.add_child(badge)
	await process_frame
	expect(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE, "badge ignores mouse")
	expect(badge.get_node_or_null("Text") != null, "badge required node")
	badge.set_severity(&"warning")
	badge.set_text("Low")
	expect((badge.get_node("Text") as Label).text.begins_with("!"), "warning badge glyph")
	badge.set_severity(&"critical")
	badge.set_text("Starvation")
	expect((badge.get_node("Text") as Label).text.begins_with("\u00d7"), "critical badge glyph")
	badge.queue_free()
	await process_frame

	# Tab button: selection + focus neighbours.
	var tab := (load("res://scenes/ui/components/tab_button/tab_button.tscn") as PackedScene).instantiate() as GopalaTabButton
	expect(tab != null, "tab scene instantiates")
	root.add_child(tab)
	await process_frame
	expect(tab.mouse_filter == Control.MOUSE_FILTER_STOP, "tab stops the mouse")
	expect(tab.focus_mode == Control.FOCUS_ALL, "tab focusable")
	tab.set_label("A tab label longer than eighteen characters")
	expect(tab.text.length() <= 21, "tab label truncated")
	tab.set_selected(true)
	expect(tab.button_pressed, "tab selected state applies")
	tab.queue_free()
	await process_frame

	# Progress meter: styles, warning hover.
	var meter := (load("res://scenes/ui/components/progress_meter/progress_meter.tscn") as PackedScene).instantiate() as GopalaProgressMeter
	expect(meter != null, "meter scene instantiates")
	root.add_child(meter)
	await process_frame
	expect(meter.mouse_filter == Control.MOUSE_FILTER_IGNORE, "meter ignores mouse by default")
	var fill := meter.get_theme_stylebox("fill") as StyleBoxFlat
	expect(fill != null and fill.bg_color == GopalaTheme.BRASS, "meter fill uses theme brass")
	meter.set_warning(true, "Below target")
	expect(meter.mouse_filter == Control.MOUSE_FILTER_STOP, "warning meter becomes hoverable")
	expect(meter.tooltip_text == "Below target", "warning meter tooltip states the reason")
	meter.queue_free()
	await process_frame

	# Alert item: severity, action wiring, disabled reason, long text.
	var alert := (load("res://scenes/ui/components/alert_item/alert_item.tscn") as PackedScene).instantiate() as GopalaAlertItem
	expect(alert != null, "alert scene instantiates")
	root.add_child(alert)
	await process_frame
	expect(alert.mouse_filter == Control.MOUSE_FILTER_IGNORE, "alert surface ignores mouse")
	expect(alert.get_node_or_null("Action") != null, "alert required nodes")
	var captured: Array = []
	alert.action_requested.connect(func(id: StringName) -> void: captured.append(id))
	alert.set_alert(&"alert_1", &"warning", "Food is low", true)
	var action_button := alert.get_node("Action") as Button
	expect(action_button.mouse_filter == Control.MOUSE_FILTER_STOP, "alert action stops the mouse")
	action_button.pressed.emit()
	expect(captured.size() == 1 and StringName(captured[0]) == &"alert_1", "action emits alert id")
	alert.set_action_enabled(false, "Requires a watchtower")
	expect(action_button.disabled and action_button.tooltip_text.contains("watchtower"),
		"disabled action states its reason")
	alert.set_alert(&"alert_2", &"neutral", "Long message ".repeat(30), false)
	expect((alert.get_node("Message") as Label).text.length() <= 83, "alert message truncated")
	expect(alert.tooltip_text.contains("Long message"), "alert tooltip keeps full text")
	alert.queue_free()
	await process_frame

	# Panel shell: interactive vs decorative mouse policy.
	var shell := (load("res://scenes/ui/components/panel_shell/panel_shell.tscn") as PackedScene).instantiate() as GopalaPanelShell
	expect(shell != null, "shell scene instantiates")
	root.add_child(shell)
	await process_frame
	expect(shell.mouse_filter == Control.MOUSE_FILTER_STOP, "interactive shell stops the mouse")
	expect(shell.body() != null, "shell exposes its body container")
	shell.set_interactive(false)
	expect(shell.mouse_filter == Control.MOUSE_FILTER_IGNORE, "decorative shell ignores mouse")
	shell.queue_free()
	await process_frame

	# Collapsible HUD section: visible heading, accessible state, live body and events.
	var collapsible := (load("res://scenes/ui/components/collapsible_section/collapsible_section.tscn") as PackedScene).instantiate() as GopalaCollapsibleSection
	expect(collapsible != null, "collapsible section scene instantiates")
	root.add_child(collapsible)
	await process_frame
	expect(collapsible.body() != null and collapsible.title_label() != null, "collapsible section exposes its body and title")
	collapsible.set_title("Construction")
	var changes: Array[bool] = []
	collapsible.collapsed_changed.connect(func(value: bool): changes.append(value))
	collapsible.get_node("Header/Collapse").pressed.emit()
	expect(collapsible.collapsed and not collapsible.body().visible, "collapse button hides content")
	expect(collapsible.title_label().visible and collapsible.get_node("Header/Collapse").visible, "header controls remain visible while folded")
	expect(collapsible.get_node("Header/Collapse").accessibility_name == "Expand Construction", "collapse control has an accessible expanding name")
	collapsible.get_node("Header/Collapse").pressed.emit()
	expect(not collapsible.collapsed and collapsible.body().visible, "collapse button restores content")
	expect(changes == [true, false], "collapse state changes emit once")
	collapsible.set_collapsible(false)
	collapsible.set_collapsed(true)
	expect(not collapsible.collapsed and collapsible.body().visible and not collapsible.get_node("Header/Collapse").visible, "non-collapsible section stays expanded")
	collapsible.queue_free()
	await process_frame

	# Shortcut tooltip: structure, binding updates, unbound/disabled states,
	# long text, mouse routing, focus ring and UI scaling.
	var hint := (load("res://scenes/ui/components/shortcut_tooltip/shortcut_tooltip.tscn") as PackedScene).instantiate() as GopalaShortcutTooltip
	expect(hint != null, "shortcut tooltip scene instantiates")
	expect(hint.mouse_filter == Control.MOUSE_FILTER_STOP,
		"shortcut scene serializes its root with STOP before _ready")
	root.add_child(hint)
	await process_frame
	expect(hint.get_node_or_null("Body/Row/Keycap") != null
		and hint.get_node_or_null("Body/Row/Keycap/KeycapText") != null
		and hint.get_node_or_null("Body/Row/Label") != null
		and hint.get_node_or_null("Body/Description") != null,
		"shortcut tooltip required nodes exist")
	expect(hint.mouse_filter == Control.MOUSE_FILTER_STOP,
		"shortcut root stops the mouse to prevent world-click leakage")
	expect(hint.focus_mode == Control.FOCUS_NONE, "passive shortcut hint is not focusable by default")
	for decorative_child in hint.find_children("*", "Control", true, false):
		expect((decorative_child as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "decorative child %s ignores the mouse" % String(decorative_child.get_path()))

	# Route two actual viewport clicks through GUI dispatch: first prove the
	# receiver sees an unblocked click, then click the tooltip's visible area.
	# STOP must mark that GUI event handled before world _unhandled_input runs.
	hint.position = Vector2(64.0, 64.0)
	hint.size = Vector2(320.0, 64.0)
	var world_receiver := WorldInputReceiver.new()
	root.add_child(world_receiver)
	await process_frame
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2(8.0, 8.0)
	root.get_viewport().push_input(outside_click, true)
	await process_frame
	var outside_release := InputEventMouseButton.new()
	outside_release.button_index = MOUSE_BUTTON_LEFT
	outside_release.pressed = false
	outside_release.position = outside_click.position
	root.get_viewport().push_input(outside_release, true)
	await process_frame
	expect(world_receiver.left_mouse_presses == 1,
		"world receiver observes a click outside the shortcut tooltip")
	var tooltip_click := InputEventMouseButton.new()
	tooltip_click.button_index = MOUSE_BUTTON_LEFT
	tooltip_click.pressed = true
	tooltip_click.position = hint.get_global_rect().get_center()
	expect(hint.get_global_rect().has_point(tooltip_click.position),
		"synthetic mouse press targets the shortcut tooltip bounds")
	root.get_viewport().push_input(tooltip_click, true)
	await process_frame
	expect(world_receiver.left_mouse_presses == 1,
		"synthetic click on shortcut tooltip does not reach world input")
	var tooltip_release := InputEventMouseButton.new()
	tooltip_release.button_index = MOUSE_BUTTON_LEFT
	tooltip_release.pressed = false
	tooltip_release.position = tooltip_click.position
	root.get_viewport().push_input(tooltip_release, true)
	await process_frame
	world_receiver.queue_free()
	await process_frame

	# Binding resolves from InputMap and follows action changes.
	var keycap_text := hint.get_node("Body/Row/Keycap/KeycapText") as Label
	hint.set_action(&"hud_grid")
	hint.set_label("Toggle grid")
	expect(keycap_text.text == "G" and keycap_text.text == ShortcutTooltip.binding_text(&"hud_grid"),
		"keycap shows the resolved binding")
	expect(hint.tooltip_text.contains("[G]") and hint.tooltip_text.contains("Toggle grid"),
		"tooltip composes label and binding")
	hint.set_action(&"overlay_cycle")
	expect(keycap_text.text == "O", "binding update follows set_action")

	# Live InputMap rebinding is reflected after refresh().
	InputMap.add_action("test_hint_binding")
	var hint_event := InputEventKey.new()
	hint_event.physical_keycode = KEY_K
	InputMap.action_add_event(&"test_hint_binding", hint_event)
	hint.set_action(&"test_hint_binding")
	expect(keycap_text.text == "K", "rebound action shows the new key")
	InputMap.erase_action(&"test_hint_binding")

	# Unbound state: glyph instead of a key, no bracket line in the tooltip.
	hint.set_action(&"not_a_real_action")
	expect(keycap_text.text == GopalaShortcutTooltip.UNBOUND_GLYPH, "unbound state uses a glyph")
	expect(not hint.tooltip_text.contains("["), "unbound tooltip omits the binding")

	# Description visibility and long-text truncation.
	hint.set_description("Show or hide the build grid")
	expect(hint.get_node("Body/Description").visible, "description shows when set")
	expect((hint.get_node("Body/Description") as Label).text == "Show or hide the build grid",
		"short description stays complete")
	hint.set_description("Description ".repeat(30))
	expect((hint.get_node("Body/Description") as Label).text.length() <= 63, "long description truncated")
	expect(hint.tooltip_text.contains("Description Description Description"),
		"composed tooltip keeps the full description")
	hint.set_label("A shortcut label much longer than twenty-four characters")
	var label_node := hint.get_node("Body/Row/Label") as Label
	expect(label_node.text.length() <= 27, "long label truncated")
	expect(label_node.tooltip_text.contains("longer than twenty-four"), "label tooltip keeps full text")
	expect(hint.tooltip_text.contains("longer than twenty-four"), "composed tooltip keeps full label")

	# Disabled state dims the hint and forces the reason into the tooltip.
	hint.set_disabled_state(true, "Unavailable while paused")
	expect(hint.self_modulate.a < 1.0, "disabled shortcut dims")
	expect(hint.tooltip_text.contains("Unavailable while paused"), "disabled reason surfaces in tooltip")
	hint.set_disabled_state(false)
	expect(is_equal_approx(hint.self_modulate.a, 1.0), "enabled shortcut restores opacity")

	# Keyboard-focus state with a visible focus ring.
	hint.set_focusable(true)
	expect(hint.focus_mode == Control.FOCUS_ALL, "focusable shortcut enters the focus path")
	hint.grab_focus()
	await process_frame
	expect(hint.has_focus(), "shortcut hint grabs keyboard focus")
	var focus_box := hint.get_theme_stylebox("panel") as StyleBoxFlat
	expect(focus_box != null and focus_box.border_color == GopalaTheme.BRASS_DARK,
		"focused shortcut shows the focus ring")
	hint.release_focus()
	await process_frame
	var rest_box := hint.get_theme_stylebox("panel") as StyleBoxFlat
	expect(rest_box != null and rest_box.border_color == GopalaTheme.INK_FAINT,
		"unfocused shortcut restores the resting ring")
	hint.set_focusable(false)
	expect(hint.focus_mode == Control.FOCUS_NONE, "hint returns to passive focus mode")

	# UI-scale state.
	settings.reset_to_defaults()
	expect(is_equal_approx(hint.custom_minimum_size.y, 32.0), "shortcut height at 100% scale")
	settings.set_value(&"ui_scale", 1.5)
	expect(is_equal_approx(hint.custom_minimum_size.y, 48.0), "shortcut grows at 150%")
	settings.set_value(&"ui_scale", 0.8)
	expect(is_equal_approx(hint.custom_minimum_size.y, 25.6), "shortcut shrinks at 80%")
	settings.set_value(&"ui_scale", 1.0)
	hint.queue_free()
	await process_frame

# ------------------------------------------------------- virtual resolutions

func _test_virtual_resolutions() -> void:
	var saved_size := root.size
	var targets: Array[Vector2i] = [
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
		Vector2i(2560, 1080),
		Vector2i(3840, 2160),
	]
	for target in targets:
		root.size = Vector2(target)
		await process_frame
		await process_frame
		expect(Vector2i(root.size) == target,
			"virtual size %dx%d honored (got %s)" % [target.x, target.y, root.size])
		var gallery := GALLERY_SCENE.instantiate() as Control
		expect(gallery != null, "gallery scene instantiates")
		root.add_child(gallery)
		for frame_index in 4:
			await process_frame
		expect(gallery.target_count() >= 30, "gallery registers components at %dx%d" % [target.x, target.y])
		var report: Array = gallery.layout_report()
		expect(report.size() >= 30, "layout report produced entries at %dx%d" % [target.x, target.y])
		var shortcut_states := 0
		for item in report:
			if String(item["name"]).begins_with("Shortcut_"):
				shortcut_states += 1
		expect(shortcut_states >= 5,
			"shortcut-tooltip states layout-checked at %dx%d" % [target.x, target.y])
		var outside := 0
		var squeezed := 0
		var first_bad := ""
		for item in report:
			if bool(item["outside"]):
				outside += 1
				if first_bad.is_empty():
					first_bad = String(item["name"])
			if bool(item["squeezed"]):
				squeezed += 1
				if first_bad.is_empty():
					first_bad = String(item["name"]) + " (squeezed)"
		expect(outside == 0, "no horizontal overflow at %dx%d (first: %s)" % [target.x, target.y, first_bad])
		expect(squeezed == 0, "no squeezed controls at %dx%d (first: %s)" % [target.x, target.y, first_bad])
		var min_size: Vector2 = gallery.content_min_size()
		expect(min_size.x <= float(target.x) + 1.0,
			"gallery content width fits %dx%d (needs %d)" % [target.x, target.y, int(min_size.x)])
		if target.y >= 2160:
			expect(min_size.y <= float(target.y) + 1.0,
				"gallery content fits 4K height without scrolling (needs %d)" % int(min_size.y))
		else:
			expect(min_size.y > 0.0, "gallery content lays out vertically at %dx%d" % [target.x, target.y])
		gallery.queue_free()
		await process_frame
	root.size = saved_size
