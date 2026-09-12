extends Control

signal pause_requested
signal start_requested
signal book_requested

const UI = preload("res://frontend/ui/kitchen_theme.gd")
var run_button: Button
var book_button: BaseButton
var pause_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 100
	pause_button = UI.button("")
	pause_button.name = "PauseButton"
	pause_button.position = Vector2(20, 16)
	pause_button.custom_minimum_size = Vector2(44, 44)
	pause_button.size = Vector2(44, 44)
	pause_button.tooltip_text = "暂停营业（Esc）"
	pause_button.add_theme_stylebox_override("normal", UI.style(Color(UI.DARK, 0.78), 10, Color(UI.CREAM, 0.28), 0))
	pause_button.add_theme_stylebox_override("hover", UI.style(UI.DARK, 10, UI.GOLD, 0))
	pause_button.add_theme_stylebox_override("pressed", UI.style(UI.GREEN, 10, UI.GOLD, 0))
	pause_button.pressed.connect(func(): pause_requested.emit())
	add_child(pause_button)
	for x: float in [15.0, 25.0]:
		var bar := ColorRect.new()
		bar.position = Vector2(x, 14)
		bar.size = Vector2(4, 16)
		bar.color = UI.CREAM
		bar.mouse_filter = MOUSE_FILTER_IGNORE
		pause_button.add_child(bar)

	run_button = UI.button("开始营业  →", true)
	run_button.set_anchors_preset(PRESET_CENTER_BOTTOM)
	run_button.offset_left = -150
	run_button.offset_right = 150
	run_button.offset_top = -80
	run_button.offset_bottom = -24
	run_button.add_theme_font_size_override("font_size", 19)
	run_button.pressed.connect(func(): start_requested.emit())
	add_child(run_button)
	var cover_button := TextureButton.new()
	cover_button.texture_normal = load("res://frontend/assets/runtime/v4/ui/harness/harness_book_closed_v1.png")
	cover_button.ignore_texture_size = true
	cover_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	cover_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	book_button = cover_button
	book_button.name = "WorkbookCover"
	book_button.tooltip_text = "翻开工作簿"
	book_button.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	book_button.offset_left = -204
	book_button.offset_top = -168
	book_button.offset_right = -20
	book_button.offset_bottom = -20
	book_button.pressed.connect(func(): book_requested.emit())
	book_button.mouse_entered.connect(func(): book_button.self_modulate = Color(1.15, 1.15, 1.15))
	book_button.mouse_exited.connect(func(): book_button.self_modulate = Color.WHITE)
	book_button.focus_entered.connect(func(): book_button.self_modulate = Color(1.15, 1.15, 1.15))
	book_button.focus_exited.connect(func(): book_button.self_modulate = Color.WHITE)
	add_child(book_button)

func update_state(name_text: String, started: bool, demo: bool) -> void:
	run_button.visible = not started
	book_button.visible = started
	var state_text := "营业中" if started else "准备营业"
	if demo:
		state_text = "演示体验 · 进度不会写入餐厅档案"
	pause_button.tooltip_text = "暂停营业（Esc）\n%s · %s" % [name_text, state_text]
