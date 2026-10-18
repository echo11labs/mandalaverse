class_name UITokens
extends Resource
## Central measurable UI tokens: spacing, sizing, typography scale, motion.
## GopalaTheme remains the single Theme builder for colours, fonts and
## styleboxes; these tokens govern layout and motion values shared by every
## Block 1 component. Values mirror the legacy HUD's hand-written numbers so
## adopting tokens never changes rendered appearance.

@export_group("Spacing")
@export var space_1: int = 4
@export var space_2: int = 8
@export var space_3: int = 12
@export var space_4: int = 16
@export var space_5: int = 24
@export var space_6: int = 32

@export_group("Sizing")
@export var control_height_sm: int = 32
@export var control_height_md: int = 40
@export var control_height_lg: int = 52
## Minimum pointer target for primary controls (44-56px design rule).
@export var control_min_target: int = 44
@export var icon_sm: int = 16
@export var icon_md: int = 24
@export var icon_lg: int = 32

@export_group("Typography")
@export var text_meta: int = 13
@export var text_body: int = 15
@export var text_heading: int = 20
@export var text_title: int = 26

@export_group("Motion")
@export var motion_fast: float = 0.10
@export var motion_normal: float = 0.18
@export var motion_slow: float = 0.26

@export_group("Shape")
@export var radius_sm: int = 8
@export var radius_md: int = 9
@export var radius_panel: int = 14
@export var border_width: int = 1

## Multiplies a token value by the active UI scale.
## The 0.8-1.5 clamp mirrors UISettings.UI_SCALE_MIN/MAX; kept literal here so
## tokens never depend on an autoload.
static func scaled(value: float, ui_scale: float) -> float:
	return value * clampf(ui_scale, 0.8, 1.5)

## Bound a display string for layout safety; full text belongs in a tooltip.
static func truncate(text: String, max_chars: int) -> String:
	if max_chars <= 0 or text.length() <= max_chars:
		return text
	return text.substr(0, max_chars) + "..."
