extends Control

signal resume_requested
signal save_requested
signal menu_requested

const UI = preload("res://frontend/ui/kitchen_theme.gd")
var status: Label
var save_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	z_index = 400
	var shade := ColorRect.new()
	shade.color = Color(UI.DARK, 0.78)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 400
	card.add_theme_stylebox_override("panel", UI.style(UI.PAPER, 18, UI.BORDER, 28))
	center.add_child(card)
	var content := VBoxContainer.new()
	card.add_child(content)
	content.add_child(UI.label("SERVICE PAUSED  /  稍作休息", 12, UI.GREEN))
	content.add_child(UI.label("厨房已暂停", 30))
	content.add_child(UI.label("准备好了，就继续今天的营业。", 14, UI.MUTED))
	var resume := UI.button("继续营业  →", true)
	resume.pressed.connect(func(): resume_requested.emit())
	content.add_child(resume)
	save_button = UI.button("保存进度")
	save_button.pressed.connect(func(): save_requested.emit())
	content.add_child(save_button)
	var menu := UI.button("返回主菜单")
	menu.pressed.connect(func(): menu_requested.emit())
	content.add_child(menu)
	status = UI.label("Esc 继续营业 · 进度需要手动保存", 13, UI.MUTED)
	status.custom_minimum_size = Vector2(340, 38)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	hide()
