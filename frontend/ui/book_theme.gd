extends RefCounted
## Controls use the book's paper as their background instead of covering it.

const UI = preload("res://frontend/ui/kitchen_theme.gd")
const INK := Color("#49321f")
const MUTED := Color("#735737")
const RULE := Color(0.42, 0.25, 0.10, 0.28)

static func ruled(fill: Color = Color.TRANSPARENT, padding: int = 7) -> StyleBoxFlat:
	var result := UI.style(fill, 2, RULE, padding)
	result.set_border_width_all(0)
	result.border_width_bottom = 1
	return result

static func create() -> Theme:
	var result := UI.create()
	result.default_font_size = 14
	result.set_color("font_color", "Label", INK)
	result.set_color("default_color", "RichTextLabel", INK)
	for kind in ["Button", "OptionButton"]:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			result.set_color(state, kind, INK)
		result.set_stylebox("normal", kind, ruled(Color(1.0, 0.95, 0.77, 0.10)))
		result.set_stylebox("hover", kind, ruled(Color(0.50, 0.27, 0.09, 0.12)))
		result.set_stylebox("pressed", kind, ruled(Color(0.52, 0.24, 0.08, 0.20)))
		result.set_stylebox("disabled", kind, ruled(Color.TRANSPARENT))
		result.set_color("font_disabled_color", kind, MUTED)
		var focus := ruled()
		focus.border_width_bottom = 2
		focus.border_color = UI.ACCENT
		result.set_stylebox("focus", kind, focus)
	result.set_stylebox("normal", "LineEdit", ruled(Color(1, 0.96, 0.82, 0.16), 9))
	var input_focus := ruled()
	input_focus.border_width_bottom = 2
	input_focus.border_color = UI.ACCENT
	result.set_stylebox("focus", "LineEdit", input_focus)
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	result.set_constant("separation", "VBoxContainer", 8)
	result.set_constant("separation", "HBoxContainer", 8)
	return result
