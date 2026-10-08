class_name GopalaTheme
extends RefCounted
## Builds the GOPALA interface theme in code so the running game and any generated
## .tres share one definition. Editorial direction: warm parchment paper, carbon ink,
## brass trim, and hairline rules. See docs/GOPALA-UI-Font-Receipt.md.
##
## This engine's Theme uses three-argument setters where the first argument is the
## canonical item name ("font", "font_size", "normal", "panel"). Anything that needs
## to differ from a class default is applied per node with add_theme_*_override.

const FONT_DISPLAY := "res://assets/fonts/Fraunces.ttf"
const FONT_UI := "res://assets/fonts/Karla.ttf"
const FONT_MONO := "res://assets/fonts/JetBrainsMono.ttf"
const FONT_FALLBACK := "res://assets/fonts/NotoSansDevanagari.ttf"

const INK := Color("1c1a18")
const INK_MUTED := Color("6b655e")
const INK_FAINT := Color("a8a096")
const PAPER := Color("fdfbf7")
const PAPER_SUNK := Color("f4f1eb")
const PAPER_RAISED := Color("ffffff")
const PAPER_DEEP := Color("e8e0d5")
const BRASS := Color("c9a84c")
const BRASS_DARK := Color("a68a3d")
const BRASS_LIGHT := Color("e0c98d")
const BRASS_PALE := Color("f7efdb")
const TERRA := Color("8b4a3c")
const TERRA_PALE := Color("f7eae7")
const FOREST := Color("4a6b3c")
const FOREST_PALE := Color("eaf1e6")
const RIVER := Color("3c5a7c")
const RIVER_PALE := Color("e6eef6")

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = font(FONT_UI, 400, 15)
	theme.default_font_size = 15

	style_typography(theme)
	style_panels(theme)
	style_buttons(theme)
	style_misc(theme)
	return theme

## Fraunces, Karla and JetBrains Mono are variable fonts. Embolden is used instead of
## picking static cuts so one file covers the whole weight range.
static func font(path: String, weight: int, _size: int = 15) -> Font:
	var variation := FontVariation.new()
	if ResourceLoader.exists(path):
		var file := ResourceLoader.load(path, "FontFile")
		if file is FontFile:
			variation.base_font = file
	if weight >= 600:
		variation.variation_embolden = 0.06
	elif weight >= 500:
		variation.variation_embolden = 0.02
	# Fraunces reads warmer with its soft and wonk axes engaged.
	if path == FONT_DISPLAY:
		variation.variation_opentype = {"SOFT": 40, "WONK": 1, "opsz": 28}
	return variation

static func flat(
		bg: Color,
		radius: int,
		border: int = 0,
		border_color: Color = Color(0, 0, 0, 0),
		pad_h: int = 0,
		pad_v: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	box.set_border_width_all(border)
	box.border_color = border_color
	box.content_margin_left = pad_h
	box.content_margin_right = pad_h
	box.content_margin_top = pad_v
	box.content_margin_bottom = pad_v
	box.anti_aliasing = true
	return box

## Soft ambient lift, deliberately far below the usual heavy drop shadow.
static func lifted(box: StyleBoxFlat, strength: float = 0.05, y: float = 6.0, spread: float = 18.0) -> StyleBoxFlat:
	box.shadow_color = Color(0.11, 0.09, 0.06, strength)
	box.shadow_offset = Vector2(0, y)
	box.shadow_size = spread
	return box

static func style_typography(theme: Theme) -> void:
	var ui := font(FONT_UI, 400)
	var ui_medium := font(FONT_UI, 600)
	var mono := font(FONT_MONO, 400)

	theme.set_font("font", "Label", ui)
	theme.set_font_size("font_size", "Label", 15)
	theme.set_color("font_color", "Label", INK)
	theme.set_constant("line_spacing", "Label", 2)
	theme.set_constant("outline_size", "Label", 0)

	theme.set_font("font", "Button", ui_medium)
	theme.set_font_size("font_size", "Button", 15)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", BRASS_DARK)
	theme.set_color("font_focus_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", Color(INK_FAINT.r, INK_FAINT.g, INK_FAINT.b, 0.7))
	theme.set_constant("outline_size", "Button", 0)

	theme.set_font("normal_font", "RichTextLabel", ui)
	theme.set_font("bold_font", "RichTextLabel", ui_medium)
	theme.set_font("mono_font", "RichTextLabel", mono)
	theme.set_font_size("normal_font_size", "RichTextLabel", 13)
	theme.set_font_size("bold_font_size", "RichTextLabel", 13)
	theme.set_font_size("mono_font_size", "RichTextLabel", 12)
	theme.set_color("default_color", "RichTextLabel", INK)
	theme.set_constant("line_separation", "RichTextLabel", 5)

static func style_panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", flat(PAPER, 14, 1, BRASS_LIGHT))
	theme.set_stylebox("panel", "Panel", flat(PAPER, 14, 1, BRASS_LIGHT))

	var rule := StyleBoxLine.new()
	rule.color = Color(INK_FAINT.r, INK_FAINT.g, INK_FAINT.b, 0.4)
	rule.thickness = 1
	theme.set_stylebox("separator", "HSeparator", rule)
	theme.set_constant("separation", "HSeparator", 0)

	var rule_vertical := StyleBoxLine.new()
	rule_vertical.color = Color(INK_FAINT.r, INK_FAINT.g, INK_FAINT.b, 0.4)
	rule_vertical.thickness = 1
	rule_vertical.vertical = true
	theme.set_stylebox("separator", "VSeparator", rule_vertical)

static func style_buttons(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", flat(PAPER, 9, 1, INK_FAINT, 14, 8))
	theme.set_stylebox("hover", "Button", flat(PAPER_DEEP, 9, 1, BRASS_DARK, 14, 8))
	theme.set_stylebox("pressed", "Button", flat(PAPER_SUNK, 9, 1, BRASS, 14, 8))
	theme.set_stylebox("hover_pressed", "Button", flat(PAPER_DEEP, 9, 1, BRASS, 14, 8))
	theme.set_stylebox("focus", "Button", flat(Color(0, 0, 0, 0), 9, 1, BRASS, 14, 8))
	theme.set_stylebox("disabled", "Button", flat(PAPER_SUNK, 9, 1, Color(INK_FAINT.r, INK_FAINT.g, INK_FAINT.b, 0.4), 14, 8))

	theme.set_stylebox("panel", "MenuButton", flat(PAPER, 9, 1, INK_FAINT, 12, 6))

	theme.set_stylebox("panel", "PopupMenu", flat(PAPER, 12, 1, BRASS_LIGHT, 6, 6))
	theme.set_font("font", "PopupMenu", font(FONT_UI, 400))
	theme.set_font_size("font_size", "PopupMenu", 14)
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_stylebox("hover", "PopupMenu", flat(BRASS_PALE, 8))

static func style_misc(theme: Theme) -> void:
	theme.set_stylebox("panel", "TooltipPanel", flat(Color(INK.r, INK.g, INK.b, 0.96), 10, 1, BRASS, 12, 8))
	theme.set_font("font", "TooltipLabel", font(FONT_UI, 400))
	theme.set_font_size("font_size", "TooltipLabel", 13)
	theme.set_color("font_color", "TooltipLabel", PAPER)

	theme.set_stylebox("normal", "LineEdit", flat(PAPER_RAISED, 8, 1, INK_FAINT, 10, 7))
	theme.set_stylebox("focus", "LineEdit", flat(PAPER_RAISED, 8, 1, BRASS_DARK, 10, 7))
	theme.set_font("font", "LineEdit", font(FONT_UI, 400))
	theme.set_font_size("font_size", "LineEdit", 14)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", INK_FAINT)

	var grabber := flat(PAPER, 6)
	grabber.content_margin_left = 3
	grabber.content_margin_right = 3
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", flat(BRASS, 6))
	theme.set_stylebox("grabber_pressed", "VScrollBar", flat(BRASS_DARK, 6))
	theme.set_stylebox("scroll", "VScrollBar", flat(Color(INK_FAINT.r, INK_FAINT.g, INK_FAINT.b, 0.25), 3))
	theme.set_constant("separation", "VScrollBar", 8)

	theme.set_stylebox("panel", "ProgressBar", flat(PAPER_SUNK, 6, 1, INK_FAINT))
	theme.set_color("font_color", "ProgressBar", INK)
# The accepted 52-pixel top navbar is the reference for active gameplay UI.
const NAV_SURFACE := Color("1c180d")
const NAV_RAISED := Color("282313")
const NAV_INSET := Color("15120a")
const NAV_TEXT := Color("fdfbf7")
const NAV_MUTED := Color("bcb6a6")
const NAV_BORDER := Color("61512d")
const NAV_RADIUS := 5
const NAV_BODY_SIZE := 13
const NAV_TITLE_SIZE := 16
const NAV_CONTROL_HEIGHT := 32

static func navbar() -> Theme:
	var theme := build()
	theme.default_font_size = NAV_BODY_SIZE
	for type in ["Label","Button","LineEdit","PopupMenu","TooltipLabel"]:
		theme.set_font_size("font_size",type,NAV_BODY_SIZE)
		theme.set_color("font_color",type,NAV_TEXT)
	for state in ["font_hover_color","font_pressed_color","font_focus_color"]: theme.set_color(state,"Button",BRASS_LIGHT)
	theme.set_color("font_disabled_color","Button",NAV_MUTED)
	theme.set_color("default_color","RichTextLabel",NAV_TEXT)
	theme.set_constant("line_separation","RichTextLabel",3)
	for type in ["Panel","PanelContainer","PopupMenu","Window","AcceptDialog","TooltipPanel"]:
		theme.set_stylebox("panel",type,flat(NAV_SURFACE,NAV_RADIUS,1,NAV_BORDER,10,8))
	for type in ["Button","MenuButton","OptionButton","CheckButton","CheckBox"]:
		theme.set_stylebox("normal",type,flat(NAV_INSET,NAV_RADIUS,1,NAV_BORDER,8,5))
		theme.set_stylebox("hover",type,flat(NAV_RAISED,NAV_RADIUS,1,BRASS,8,5))
		theme.set_stylebox("pressed",type,flat(NAV_RAISED,NAV_RADIUS,1,BRASS,8,5))
		theme.set_stylebox("hover_pressed",type,flat(NAV_RAISED,NAV_RADIUS,1,BRASS_LIGHT,8,5))
		theme.set_stylebox("focus",type,flat(Color.TRANSPARENT,NAV_RADIUS,2,BRASS_LIGHT,8,5))
		theme.set_stylebox("disabled",type,flat(NAV_INSET,NAV_RADIUS,1,NAV_BORDER,8,5))
	for state in ["normal","focus"]: theme.set_stylebox(state,"LineEdit",flat(NAV_INSET,NAV_RADIUS,1,NAV_BORDER,8,5))
	theme.set_stylebox("hover","PopupMenu",flat(NAV_RAISED,NAV_RADIUS))
	theme.set_stylebox("background","ProgressBar",flat(NAV_INSET,NAV_RADIUS,1,NAV_BORDER))
	theme.set_stylebox("fill","ProgressBar",flat(BRASS,NAV_RADIUS))
	theme.set_color("font_color","ProgressBar",NAV_TEXT)
	return theme
