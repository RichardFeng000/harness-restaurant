extends Control

signal new_requested
signal continue_requested
signal folder_requested
signal settings_requested
signal demo_requested

const UI = preload("res://frontend/ui/kitchen_theme.gd")
var folder_label: Label
var continue_button: Button
var new_button: Button
var heading: Label
var description: Label
var content: VBoxContainer
var card: PanelContainer
var layout: VBoxContainer
var margin: MarginContainer
var footer: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://frontend/assets/runtime/legacy/environment/restaurant-final-2_5d.png")
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var shade := ColorRect.new()
	shade.color = Color(UI.DARK, 0.55)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)

	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var brand := UI.label("H / K    HARNESS KITCHEN", 19, UI.CREAM)
	brand.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(brand)
	header.add_child(UI.label("本地餐厅  /  你的协作空间", 13, UI.CREAM))
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 36)
	layout.add_child(body)

	card = PanelContainer.new()
	card.custom_minimum_size.x = 430
	card.add_theme_stylebox_override("panel", UI.style(UI.PAPER, 18, UI.BORDER, 28))
	body.add_child(card)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)
	content.add_child(UI.label("TODAY'S SERVICE  /  今日营业", 12, UI.GREEN))
	heading = UI.label("把想法，\n做成一道好菜。", 36)
	content.add_child(heading)
	description = UI.label("安排员工、整理资料，\n在自己的餐厅里开始协作。", 16, UI.MUTED)
	content.add_child(description)
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_child(spacer)
	var location := PanelContainer.new()
	location.add_theme_stylebox_override("panel", UI.style(UI.SURFACE, 10, UI.BORDER, 12))
	content.add_child(location)
	var location_box := VBoxContainer.new()
	location_box.add_theme_constant_override("separation", 4)
	location.add_child(location_box)
	location_box.add_child(UI.label("餐厅档案", 12, UI.MUTED))
	folder_label = UI.label("选择一个文件夹，安放你的餐厅", 15)
	folder_label.custom_minimum_size.x = 340
	folder_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	location_box.add_child(folder_label)
	continue_button = UI.button("继续营业  →", true)
	continue_button.pressed.connect(func(): continue_requested.emit())
	content.add_child(continue_button)
	new_button = UI.button("创建新餐厅", true)
	new_button.pressed.connect(func(): new_requested.emit())
	content.add_child(new_button)
	var utilities := HBoxContainer.new()
	content.add_child(utilities)
	var folder := UI.button("选择本地文件夹")
	folder.size_flags_horizontal = SIZE_EXPAND_FILL
	folder.pressed.connect(func(): folder_requested.emit())
	utilities.add_child(folder)
	var settings := UI.button("模型设置")
	settings.pressed.connect(func(): settings_requested.emit())
	utilities.add_child(settings)
	var demo := UI.button("先逛逛演示餐厅  →")
	demo.flat = true
	demo.pressed.connect(func(): demo_requested.emit())
	content.add_child(demo)

	var story := VBoxContainer.new()
	story.size_flags_horizontal = SIZE_EXPAND_FILL
	story.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(story)
	story.add_child(UI.label("一间小餐厅，无限种可能。", 26, UI.CREAM))
	var caption := UI.label("用熟悉的厨房，组织你的 AI 工作流。", 15, UI.CREAM)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.add_child(caption)
	var chips := HBoxContainer.new()
	story.add_child(chips)
	for text in ["员工协作", "知识与记忆", "本地档案"]:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UI.style(Color(UI.DARK, 0.88), 8, Color(UI.CREAM, 0.2), 10))
		chip.add_child(UI.label(text, 13, UI.CREAM))
		chips.add_child(chip)
	footer = UI.label("从演示开始探索，或选择本地文件夹创建餐厅。", 12, UI.CREAM)
	layout.add_child(footer)
	resized.connect(_adapt)
	_adapt()

func set_can_continue(available: bool) -> void:
	continue_button.visible = available
	UI.set_primary(new_button, not available)
	continue_button.tooltip_text = "恢复上次保存的餐厅" if available else "还没有已保存的餐厅，可以先创建或体验演示"

func _adapt() -> void:
	if heading == null:
		return
	var compact := size.y < 650
	heading.text = "把想法，做成好菜。" if compact else "把想法，\n做成一道好菜。"
	heading.add_theme_font_size_override("font_size", 25 if compact else 36)
	description.text = "从这里开始今天的协作。" if compact else "安排员工、整理资料，\n在自己的餐厅里开始协作。"
	content.add_theme_constant_override("separation", 8 if compact else 12)
	layout.add_theme_constant_override("separation", 12 if compact else 20)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20 if compact else 28)
	card.add_theme_stylebox_override("panel", UI.style(UI.PAPER, 18, UI.BORDER, 20 if compact else 28))
	footer.visible = not compact
