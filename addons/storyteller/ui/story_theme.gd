class_name StoryTheme
extends RefCounted
## Builds StoryTeller's default look: dark translucent panels, rounded
## buttons, and readable text. Projects can set their own [Theme] in
## [member StoryConfig.theme] instead.

const ACCENT := Color(0.55, 0.75, 1.0)
const TEXT := Color(0.92, 0.93, 0.96)


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
