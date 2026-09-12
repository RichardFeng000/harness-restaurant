extends Control
## Floating confirmation that leaves the underlying page in place.

signal confirmed
signal canceled

const UI = preload("res://frontend/ui/kitchen_theme.gd")

var card: PanelContainer
var title: Label
var cancel_button: Button
var confirm_button: Button


func _ready() -> void:
	set_as_top_level(true)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.name = "ModalBackdrop"
	backdrop.color = Color(0.10, 0.07, 0.04, 0.36)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	card = PanelContainer.new()
	card.name = "McpUninstallConfirmation"
	var surface := UI.style(UI.SURFACE, 12, UI.BORDER, 24)
	surface.shadow_color = Color(0.05, 0.03, 0.01, 0.28)
	surface.shadow_size = 18
	surface.shadow_offset = Vector2(0, 8)
	card.add_theme_stylebox_override("panel", surface)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	card.add_child(body)
	title = UI.label("", 20)
	title.name = "UninstallTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(title)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	body.add_child(actions)
	cancel_button = _button("取消", false)
	cancel_button.name = "CancelUninstall"
	cancel_button.pressed.connect(func(): canceled.emit())
	actions.add_child(cancel_button)
	confirm_button = _button("卸载", true)
	confirm_button.name = "ConfirmUninstall"
	confirm_button.pressed.connect(func(): confirmed.emit())
	actions.add_child(confirm_button)
	for button: Button in [cancel_button, confirm_button]:
		var other := confirm_button if button == cancel_button else cancel_button
		var path := button.get_path_to(other)
		button.focus_next = path
		button.focus_previous = path
		button.focus_neighbor_left = path
		button.focus_neighbor_right = path
		button.focus_neighbor_top = path
		button.focus_neighbor_bottom = path
	card.resized.connect(_center_card)
	get_viewport().size_changed.connect(_resize_overlay)
	_resize_overlay()
	dismiss()


func present(caption: String) -> void:
	title.text = caption
	card.show()
	show()
	_resize_overlay()
	cancel_button.grab_focus()
	_focus_cancel.call_deferred()


func dismiss() -> void:
	card.hide()
	hide()
	title.text = ""


func _resize_overlay() -> void:
	global_position = Vector2.ZERO
	size = get_viewport_rect().size
	var width := maxf(200, minf(360, size.x - 32))
	card.custom_minimum_size = Vector2(width, 158)
	card.size = Vector2(width, 158)
	_center_card()


func _center_card() -> void:
	card.position = (size - card.size) * 0.5


func _focus_cancel() -> void:
	if is_visible_in_tree():
		cancel_button.grab_focus()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		canceled.emit()
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		get_viewport().set_input_as_handled()
		var focused := get_viewport().gui_get_focus_owner()
		if focused == cancel_button:
			confirm_button.grab_focus()
		else:
			cancel_button.grab_focus()
	elif event.is_action_pressed("ui_accept"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused != cancel_button and focused != confirm_button:
			get_viewport().set_input_as_handled()
			cancel_button.grab_focus()


func _button(caption: String, primary: bool) -> Button:
	var button := UI.button(caption, primary)
	button.custom_minimum_size = Vector2(76, 38)
	button.add_theme_font_size_override("font_size", 14)
	if not primary:
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, UI.style(UI.PAPER if state != "normal" else UI.SURFACE, 9, UI.BORDER, 10))
	var focus := UI.style(Color.TRANSPARENT, 9, UI.ACCENT, 0)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	return button
