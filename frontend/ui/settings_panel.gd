extends Control

signal close_requested
signal save_requested

const UI = preload("res://frontend/ui/kitchen_theme.gd")
var model_input: LineEdit
var base_url_input: LineEdit
var api_key_input: LineEdit
var status: Label
var save_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	z_index = 600
	var shade := ColorRect.new()
	shade.color = Color(UI.DARK, 0.8)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 570
	panel.add_theme_stylebox_override("panel", UI.style(UI.PAPER, 18, UI.BORDER, 24))
	center.add_child(panel)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	panel.add_child(form)
	var header := HBoxContainer.new()
	form.add_child(header)
	var title := UI.label("模型设置", 26)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	var close := UI.button("关闭")
	close.pressed.connect(func(): close_requested.emit())
	header.add_child(close)
	form.add_child(UI.label("为这间餐厅保存模型连接信息。", 14, UI.MUTED))
	model_input = _field(form, "模型名称", "输入模型 ID")
	base_url_input = _field(form, "服务地址 · Base URL", "https://api.example.com/v1")
	api_key_input = _field(form, "访问密钥 · API Key", "输入 API Key")
	api_key_input.secret = true
	status = UI.label("", 13, UI.MUTED)
	status.custom_minimum_size = Vector2(520, 38)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(status)
	var note := UI.label("密钥以明文保存在所选文件夹中，请妥善保管该文件。", 12, UI.MUTED)
	form.add_child(note)
	save_button = UI.button("保存配置", true)
	save_button.pressed.connect(func(): save_requested.emit())
	form.add_child(save_button)
	hide()

func _field(parent: Container, title: String, placeholder: String) -> LineEdit:
	parent.add_child(UI.label(title, 13, UI.MUTED))
	var field := LineEdit.new()
	field.custom_minimum_size.y = 42
	field.placeholder_text = placeholder
	parent.add_child(field)
	return field

func set_loading(loading: bool) -> void:
	for field in [model_input, base_url_input, api_key_input]:
		field.editable = not loading
	save_button.disabled = loading
