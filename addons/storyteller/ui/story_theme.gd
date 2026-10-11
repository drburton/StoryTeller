class_name StoryTheme
extends RefCounted
## Builds StoryTeller's default look: dark translucent panels, rounded
## buttons, and readable text. Projects can set their own [Theme] in
## [member StoryConfig.theme] instead.

const ACCENT := Color(0.55, 0.75, 1.0)
const TEXT := Color(0.92, 0.93, 0.96)
## Color of [code][code][/code] text in dialogue boxes.
const CODE := Color(0.98, 0.80, 0.45)
## Focus and highlight color of the high-contrast theme.
const HIGH_CONTRAST_FOCUS := Color(1.0, 0.9, 0.2)


static func build_default() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	var panel := _box(Color(0.07, 0.08, 0.11, 0.9), 10, 14)
	panel.border_color = Color(1, 1, 1, 0.08)
	panel.set_border_width_all(1)
	for type in ["PanelContainer", "Panel"]:
		theme.set_stylebox("panel", type, panel)
	theme.set_stylebox("normal", "Button", _box(Color(0.16, 0.18, 0.24, 0.95), 8, 10))
	theme.set_stylebox("hover", "Button", _box(Color(0.24, 0.28, 0.38, 0.98), 8, 10))
	theme.set_stylebox("pressed", "Button", _box(Color(0.30, 0.37, 0.52, 1.0), 8, 10))
	theme.set_stylebox("disabled", "Button", _box(Color(0.12, 0.13, 0.16, 0.6), 8, 10))
	var focus := _box(Color(0, 0, 0, 0), 8, 10)
	focus.draw_center = false
	focus.border_color = ACCENT
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.6, 0.62, 0.68, 0.7))
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_stylebox("normal", "LineEdit", _box(Color(0.12, 0.13, 0.17, 1.0), 6, 8))
	theme.set_stylebox("focus", "LineEdit", focus)
	# [code] in dialogue, for tales that show script or other code.
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Menlo", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	theme.set_font("mono_font", "RichTextLabel", mono)
	theme.set_font_size("mono_font_size", "RichTextLabel", 18)
	theme.set_color("code_color", "DialogueBox", CODE)
	return theme


## System fonts tried, in order, for the "Readable font" setting: fonts
## designed for legibility first, then common clear sans-serif fonts.
const READABLE_FONTS := [
	"Atkinson Hyperlegible", "Atkinson Hyperlegible Next", "Lexend", "Verdana",
	"Tahoma", "Segoe UI", "Arial", "Helvetica", "DejaVu Sans", "Noto Sans", "sans-serif",
]


## [param base] adjusted for the player's display settings:
## [code]high_contrast[/code] and [code]readable_font[/code] (both bool).
## Returns [param base] itself when neither is on.
static func for_settings(base: Theme, high_contrast_on: bool, readable_font: bool) -> Theme:
	if not high_contrast_on and not readable_font:
		return base
	var theme := high_contrast(base) if high_contrast_on else base.duplicate(true) as Theme
	if readable_font:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(READABLE_FONTS)
		theme.default_font = font
	return theme


## A copy of [param base] with opaque black panels, white borders and text,
## and yellow focus, for the player's "High contrast" setting.
static func high_contrast(base: Theme) -> Theme:
	var theme := base.duplicate(true) as Theme
	var panel := _box(Color.BLACK, 6, 14)
	panel.border_color = Color.WHITE
	panel.set_border_width_all(2)
	for type in ["PanelContainer", "Panel"]:
		theme.set_stylebox("panel", type, panel)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var button := _box(Color.BLACK if state != "pressed" else Color(0.2, 0.2, 0.2), 6, 10)
		button.border_color = HIGH_CONTRAST_FOCUS if state in ["hover", "focus", "pressed"] else Color.WHITE
		button.set_border_width_all(3 if state in ["hover", "focus"] else 2)
		theme.set_stylebox(state, "Button", button)
	var field := _box(Color.BLACK, 4, 8)
	field.border_color = Color.WHITE
	field.set_border_width_all(2)
	theme.set_stylebox("normal", "LineEdit", field)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.75, 0.75, 0.75))
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_color("default_color", "RichTextLabel", Color.WHITE)
	theme.set_color("code_color", "DialogueBox", HIGH_CONTRAST_FOCUS)
	return theme


static func _box(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin * 0.6
	box.content_margin_bottom = margin * 0.6
	return box
