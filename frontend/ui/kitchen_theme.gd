extends RefCounted
## Shared palette and control styles for the restaurant interface.

const INK := Color("#30271f")
const MUTED := Color("#77695b")
const PAPER := Color("#f6efdf")
const SURFACE := Color("#fffaf0")
const BORDER := Color("#d9cbb5")
const ACCENT := Color("#a54732")
const DARK := Color("#242c25")
const CREAM := Color("#fff6e3")
const GOLD := Color("#d8b777")
const GREEN := Color("#52694d")

static func style(bg: Color, radius: int = 12, border: Color = Color.TRANSPARENT, padding: int = 16) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = bg
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(radius)
	result.content_margin_left = padding
	result.content_margin_right = padding
	result.content_margin_top = padding
	result.content_margin_bottom = padding
	return result

static func label(value: String, font_size: int = 16, color: Color = INK) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func button(value: String, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size.y = 46
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_primary(result, primary)
	return result

static func set_primary(result: Button, primary: bool) -> void:
	if not primary:
		for state in ["normal", "hover", "pressed"]:
			result.remove_theme_stylebox_override(state)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			result.remove_theme_color_override(state)
	else:
		for state in ["normal", "hover", "pressed"]:
			var color := ACCENT.lightened(0.08) if state == "hover" else ACCENT
			if state == "pressed":
				color = ACCENT.darkened(0.12)
			result.add_theme_stylebox_override(state, style(color, 9, color, 12))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			result.add_theme_color_override(state, CREAM)

static func create() -> Theme:
	var result := Theme.new()
	result.default_font_size = 16
	result.set_color("font_color", "Label", INK)
	result.set_color("default_color", "RichTextLabel", INK)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(state, "Button", INK)
	result.set_color("font_disabled_color", "Button", MUTED)
	result.set_stylebox("normal", "Button", style(SURFACE, 9, BORDER, 12))
	result.set_stylebox("hover", "Button", style(PAPER.darkened(0.035), 9, GOLD, 12))
	result.set_stylebox("pressed", "Button", style(BORDER, 9, MUTED, 12))
	result.set_stylebox("disabled", "Button", style(PAPER.darkened(0.05), 9, BORDER, 12))
	var focus := style(Color.TRANSPARENT, 9, ACCENT, 0)
	focus.set_border_width_all(2)
	result.set_stylebox("focus", "Button", focus)
	result.set_stylebox("focus", "LineEdit", focus)
	result.set_stylebox("normal", "LineEdit", style(SURFACE, 9, BORDER, 12))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_color("caret_color", "LineEdit", ACCENT)
	result.set_color("selection_color", "LineEdit", Color(ACCENT, 0.25))
	result.set_constant("separation", "VBoxContainer", 12)
	result.set_constant("separation", "HBoxContainer", 12)
	result.set_stylebox("panel", "PanelContainer", style(SURFACE, 12, BORDER))
	return result
