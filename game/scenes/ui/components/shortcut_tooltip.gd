class_name ShortcutTooltip
extends RefCounted
## Composes tooltip text that shows the currently resolved InputMap binding.
## Components call apply() on ready and whenever bindings change, so tooltips
## never carry hard-coded key labels (UI_CONTRACT.md section 10).

## Resolved key label for an action, or "" when unbound/unknown.
static func binding_text(action: StringName) -> String:
	if action == &"" or not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event == null:
			continue
		var code: Key = key_event.physical_keycode
		if code == KEY_NONE:
			code = key_event.keycode
		if code != KEY_NONE:
			return OS.get_keycode_string(code)
	return ""

## base text, then "[KEY]" binding, then extra lines; empty parts omitted.
static func compose(base: String, action: StringName = &"", extra: String = "") -> String:
	var lines := PackedStringArray()
	if not base.is_empty():
		lines.append(base)
	var binding := binding_text(action)
	if not binding.is_empty():
		lines.append("[%s]" % binding)
	if not extra.is_empty():
		lines.append(extra)
	return "\n".join(lines)

static func apply(control: Control, action: StringName, base: String = "", extra: String = "") -> void:
	control.tooltip_text = compose(base, action, extra)
