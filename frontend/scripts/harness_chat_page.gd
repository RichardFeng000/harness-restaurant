extends VBoxContainer

signal message_submitted(message: String)

const KitchenTheme = preload("res://frontend/ui/kitchen_theme.gd")
const ChatMessageList = preload("res://frontend/ui/chat_message_list.gd")

var messages: ScrollContainer
var message_input: LineEdit
var send_button: Button
var draft_picker: OptionButton
var draft_status: Label
var current_staff_id := "manager"
var current_staff_name := "主管"
var staff_drafts: Dictionary = {}
var active_drafts: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var heading := HBoxContainer.new()
	var title := KitchenTheme.label("对话", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	draft_status = KitchenTheme.label("临时草稿 · AI 未连接", 11, KitchenTheme.MUTED)
	draft_status.tooltip_text = "草稿仅在本次运行中保存，切换餐厅或关闭程序后清空。"
	draft_status.mouse_filter = Control.MOUSE_FILTER_PASS
	heading.add_child(draft_status)
	add_child(heading)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	draft_picker = OptionButton.new()
	draft_picker.name = "DraftPicker"
	draft_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draft_picker.custom_minimum_size.y = 32
	draft_picker.fit_to_longest_item = false
	draft_picker.clip_text = true
	draft_picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	draft_picker.add_theme_font_size_override("font_size", 13)
	draft_picker.add_theme_color_override("font_color", KitchenTheme.INK)
	draft_picker.add_theme_color_override("font_hover_color", KitchenTheme.INK)
	draft_picker.add_theme_color_override("font_pressed_color", KitchenTheme.INK)
	draft_picker.add_theme_color_override("font_focus_color", KitchenTheme.INK)
	for state: String in ["normal", "hover", "pressed"]:
		draft_picker.add_theme_stylebox_override(state, _paper_field(0.12 if state == "normal" else 0.3))
	draft_picker.add_theme_stylebox_override("focus", _paper_field(0.0, KitchenTheme.ACCENT))
	var popup := draft_picker.get_popup()
	popup.add_theme_stylebox_override("panel", KitchenTheme.style(KitchenTheme.SURFACE, 10, KitchenTheme.BORDER, 8))
	popup.add_theme_color_override("font_color", KitchenTheme.INK)
	popup.add_theme_color_override("font_hover_color", KitchenTheme.INK)
	popup.add_theme_stylebox_override("hover", KitchenTheme.style(KitchenTheme.PAPER, 6, Color.TRANSPARENT, 4))
	draft_picker.item_selected.connect(_select_draft)
	toolbar.add_child(draft_picker)
	var new_button := KitchenTheme.button("＋")
	new_button.tooltip_text = "新建对话"
	_style_paper_button(new_button)
	new_button.custom_minimum_size = Vector2(32, 32)
	new_button.pressed.connect(_new_conversation)
	toolbar.add_child(new_button)
	add_child(toolbar)
	messages = ChatMessageList.new()
	messages.name = "Messages"
	add_child(messages)
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)
	message_input = LineEdit.new()
	message_input.name = "MessageInput"
	message_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_input.custom_minimum_size = Vector2(0, 36)
	message_input.placeholder_text = "写点什么…"
	message_input.add_theme_font_size_override("font_size", 13)
	message_input.add_theme_stylebox_override("normal", _paper_field(0.12))
	message_input.add_theme_stylebox_override("focus", _paper_field(0.0, KitchenTheme.ACCENT))
	message_input.max_length = 4000
	message_input.text_submitted.connect(_send_text)
	message_input.text_changed.connect(_input_changed)
	input_row.add_child(message_input)
	send_button = KitchenTheme.button("记下")
	send_button.name = "SendButton"
	send_button.tooltip_text = "将这条记录记入当前草稿"
	_style_paper_button(send_button)
	send_button.custom_minimum_size = Vector2(52, 36)
	send_button.disabled = true
	send_button.pressed.connect(_send)
	input_row.add_child(send_button)
	add_child(input_row)
	_restore_staff()


func _paper_field(opacity: float, line_color: Color = KitchenTheme.BORDER) -> StyleBoxFlat:
	var field := KitchenTheme.style(Color(KitchenTheme.CREAM, opacity), 0, line_color, 6)
	field.set_border_width_all(0)
	field.border_width_bottom = 1
	return field


func _style_paper_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", KitchenTheme.ACCENT)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, _paper_field(0.0 if state == "normal" or state == "disabled" else 0.3))
	button.add_theme_stylebox_override("focus", _paper_field(0.0, KitchenTheme.ACCENT))


func focus_input() -> void:
	if is_visible_in_tree():
		message_input.grab_focus()


func select_staff(staff_id: String, display_name: String) -> void:
	current_staff_id = staff_id
	current_staff_name = display_name
	if is_node_ready():
		_restore_staff()


func reset_session(staff_id: String = "manager", display_name: String = "主管") -> void:
	staff_drafts.clear()
	active_drafts.clear()
	current_staff_id = staff_id
	current_staff_name = display_name
	if is_node_ready():
		_restore_staff()


func _restore_staff() -> void:
	if not staff_drafts.has(current_staff_id):
		staff_drafts[current_staff_id] = [{"messages": [], "input": ""}]
		active_drafts[current_staff_id] = 0
	_refresh_picker()
	_render_draft()


func _refresh_picker() -> void:
	draft_picker.clear()
	var drafts: Array = staff_drafts[current_staff_id]
	for index in drafts.size():
		var entries: Array = drafts[index]["messages"]
		var caption := "新对话" if entries.is_empty() else str(entries[0]["text"]).left(20)
		draft_picker.add_item(caption if drafts.size() == 1 else "%02d  ·  %s" % [index + 1, caption])
	draft_picker.select(int(active_drafts[current_staff_id]))


func _draft() -> Dictionary:
	return staff_drafts[current_staff_id][int(active_drafts[current_staff_id])]


func _select_draft(index: int) -> void:
	active_drafts[current_staff_id] = index
	_render_draft()
	focus_input()


func _new_conversation() -> void:
	var drafts: Array = staff_drafts[current_staff_id]
	drafts.append({"messages": [], "input": ""})
	active_drafts[current_staff_id] = drafts.size() - 1
	_refresh_picker()
	_render_draft()
	focus_input()


func _render_draft() -> void:
	var entries: Array = _draft()["messages"]
	messages.render_entries(entries)
	message_input.text = str(_draft()["input"])
	send_button.disabled = message_input.text.strip_edges().is_empty()


func _input_changed(value: String) -> void:
	_draft()["input"] = value
	send_button.disabled = value.strip_edges().is_empty()


func _send() -> void:
	_send_text(message_input.text)


func _send_text(value: String) -> void:
	var clean_message := value.strip_edges()
	if clean_message.is_empty():
		return
	var draft := _draft()
	draft["messages"].append({"role": "user", "name": current_staff_name, "text": clean_message})
	draft["input"] = ""
	_refresh_picker()
	_render_draft()
	message_submitted.emit(clean_message)
	focus_input()

func add_assistant_message(value: String, staff_id: String = "", draft_index: int = -1) -> bool:
	if value.strip_edges().is_empty():
		return false
	var target_staff := current_staff_id if staff_id.is_empty() else staff_id
	if not staff_drafts.has(target_staff):
		return false
	var index := int(active_drafts[target_staff]) if draft_index < 0 else draft_index
	var drafts: Array = staff_drafts[target_staff]
	if index < 0 or index >= drafts.size():
		return false
	drafts[index]["messages"].append({"role": "assistant", "name": "模型", "text": value})
	if target_staff == current_staff_id and index == int(active_drafts[current_staff_id]):
		_refresh_picker()
		messages.render_entries(_draft()["messages"])
	return true
