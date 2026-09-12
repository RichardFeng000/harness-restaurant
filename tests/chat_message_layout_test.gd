extends SceneTree
## Run: ./scripts/run.sh --headless --script tests/chat_message_layout_test.gd
## Uses in-memory conversations only; no model, network, or user save files.

const ChatPage = preload("res://frontend/scenes/harness/chat_page.tscn")
const BookTheme = preload("res://frontend/ui/book_theme.gd")
var failures: Array[String] = []
var submitted_messages: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var host := Control.new()
	host.position = Vector2(704, 100)
	host.size = Vector2(450, 510)
	host.theme = BookTheme.create()
	root.add_child(host)
	var chat = ChatPage.instantiate()
	host.add_child(chat)
	chat.message_submitted.connect(func(value: String): submitted_messages.append(value))
	await _settle()

	var literal_user := "[b]用户原文[/b]\n第二行 [url=https://example.com]链接字面量[/url]"
	var literal_reply := "[i]回复原文[/i]\n保留换行与方括号。"
	chat._send_text(literal_user)
	_check(chat.add_assistant_message(literal_reply), "当前会话可接收模型回复")
	_check(submitted_messages == [literal_user], "插入模型回复不触发用户提交信号")
	var original_entries: Array = chat._draft()["messages"]
	_check(original_entries.size() == 2 and original_entries[0].get("role") == "user" and original_entries[1].get("role") == "assistant", "消息记录保存用户和模型角色")
	await _settle()
	_check_bodies(chat.messages, [literal_user, literal_reply], ["user", "assistant"])
	_check_layout(chat.messages, "450px 初始消息")

	# A reply targeting an older draft must not steal the current draft or input.
	chat._new_conversation()
	chat._send_text("当前会话的消息")
	chat.message_input.text = "尚未提交的文字"
	chat.message_input.text_changed.emit(chat.message_input.text)
	var current_draft: Dictionary = chat._draft().duplicate(true)
	var user_submission_count := submitted_messages.size()
	_check(chat.add_assistant_message("发给旧会话的回复", "manager", 0), "可以向指定的旧会话写入回复")
	_check(int(chat.active_drafts["manager"]) == 1 and chat._draft() == current_draft, "定向旧会话回复不改变当前会话或未提交输入")
	_check(not chat.messages.get_parsed_text().contains("发给旧会话的回复"), "旧会话回复不出现在当前会话")
	_check(submitted_messages.size() == user_submission_count, "定向插入回复不重复发送用户消息")

	chat.select_staff("cashier", "收银员")
	chat._send_text("收银员的消息")
	_check(chat.add_assistant_message("收银员的回复"), "默认回复归属当前员工")
	var cashier_draft: Dictionary = chat._draft().duplicate(true)
	_check(chat.add_assistant_message("跨员工的旧会话回复", "manager", 0), "可以向其他员工的指定会话插入回复")
	_check(chat._draft() == cashier_draft and chat.current_staff_id == "cashier", "跨员工回复不污染当前员工的会话")
	chat.select_staff("manager", "主管")
	_check(chat._draft() == current_draft and chat.message_input.text == "尚未提交的文字", "切回员工后恢复原来的活动会话和未提交输入")
	chat._select_draft(0)
	await _settle()
	_check_bodies(chat.messages, [literal_user, literal_reply, "发给旧会话的回复", "跨员工的旧会话回复"], ["user", "assistant", "assistant", "assistant"])
	chat.select_staff("cashier", "收银员")
	await _settle()
	_check_bodies(chat.messages, ["收银员的消息", "收银员的回复"], ["user", "assistant"])

	# Resize the same live controls, including messages that must wrap anywhere.
	var long_chinese := "很长的中文消息，需要自动换行并始终留在纸页内。".repeat(18)
	var long_english := "UnbrokenEnglishToken".repeat(32)
	var multiline := "第一行\n\n第三行仍保留空行\n[b]这不是粗体指令[/b]"
	var entries: Array = [
		{"role": "user", "text": "我发出的消息"},
		{"role": "assistant", "text": "模型的回复"},
		{"role": "user", "text": long_chinese},
		{"role": "assistant", "text": long_english},
		{"role": "assistant", "text": multiline},
		{"name": "主管", "text": "没有 role 字段的旧消息"},
	]
	var expected_texts: Array = entries.map(func(entry: Dictionary): return entry["text"])
	for viewport_size in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1280, 720)]:
		root.content_scale_size = viewport_size
		root.size = viewport_size
		var compact: bool = viewport_size.x == 960
		host.position = Vector2(528, 90) if compact else Vector2(704, 100)
		host.size = Vector2(334, 365) if compact else Vector2(450, 510)
		chat.messages.render_entries(entries)
		await _settle()
		var size_label := str(viewport_size)
		_check(chat.size.x <= host.size.x + 1.0 and chat.size.y <= host.size.y + 1.0, "对话页不撑大纸面 " + size_label)
		_check_bodies(chat.messages, expected_texts, ["user", "assistant", "user", "assistant", "assistant", "user"])
		_check_layout(chat.messages, size_label)
		_check(chat.messages.get_v_scroll_bar().visible, "长对话可纵向滚动 " + size_label)
		_check(not chat.messages.get_h_scroll_bar().visible, "长消息不产生横向滚动 " + size_label)
		_check_latest_visible(chat.messages, "载入长对话 " + size_label)
		var long_body: RichTextLabel = chat.messages.rows.get_child(3).find_child("Body", true, false)
		_check(long_body != null and long_body.get_content_height() > 40, "超长英文单词确实换行 " + size_label)
		for text: String in expected_texts:
			_check(chat.messages.get_parsed_text().contains(text), "公开文本接口保留原文 " + size_label)
		if compact:
			chat.messages.scroll_vertical = 0
			await _settle()
			_check(chat.messages.scroll_vertical == 0, "布局完成后允许用户上滚查看旧消息")
			var appended: Array = entries.duplicate(true)
			appended.append({"role": "assistant", "text": "追加的新回复\n" + long_chinese})
			chat.messages.render_entries(appended)
			await _settle()
			_check_latest_visible(chat.messages, "上滚后追加长回复")

	chat.messages.render_entries([])
	await _settle()
	_check(chat.messages.rows.get_child_count() == 0 and chat.messages.get_parsed_text().is_empty(), "空会话没有占位消息或引导文案")
	host.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("Chat message layout test: ", "PASS" if failures.is_empty() else "FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _check_bodies(message_list: Control, expected_texts: Array, expected_roles: Array) -> void:
	var rows: VBoxContainer = message_list.rows
	_check(rows.get_child_count() == expected_texts.size(), "每条记录对应一个可见消息行")
	for index in mini(rows.get_child_count(), expected_texts.size()):
		var row: Control = rows.get_child(index)
		var body: RichTextLabel = row.find_child("Body", true, false)
		_check(row.get_meta("role", "") == expected_roles[index], "切换与重绘后消息角色保持正确：%d" % index)
		_check(body != null, "消息行包含可选择的正文：%d" % index)
		if body != null:
			_check(body.get_parsed_text() == expected_texts[index], "消息原样显示中文、英文、换行和 BBCode：%d" % index)

func _check_layout(message_list: Control, context: String) -> void:
	var list_rect := message_list.get_global_rect()
	for row: Control in message_list.rows.get_children():
		var bubble: Control = row.find_child("Bubble", true, false)
		var body: RichTextLabel = row.find_child("Body", true, false)
		_check(bubble != null, "消息行包含气泡 " + context)
		if bubble == null:
			continue
		var row_rect := row.get_global_rect()
		var bubble_rect := bubble.get_global_rect()
		var left_gap := bubble_rect.position.x - row_rect.position.x
		var right_gap := row_rect.end.x - bubble_rect.end.x
		if row.get_meta("role", "") == "assistant":
			_check(right_gap > left_gap + 8.0, "模型回复靠左 " + context)
		else:
			_check(left_gap > right_gap + 8.0, "用户消息及旧记录靠右 " + context)
		_check(bubble_rect.position.x >= list_rect.position.x - 1.0 and bubble_rect.end.x <= list_rect.end.x + 1.0, "气泡没有横向超出消息纸面 " + context)
		_check(row_rect.end.x <= list_rect.end.x + 1.0, "长消息没有撑宽行容器 " + context)
		if body != null:
			_check(bubble_rect.grow(1.0).encloses(body.get_global_rect()), "正文尺寸包含在气泡内 " + context)
			_check(body.get_content_height() <= body.size.y + 2.0, "换行后正文没有被气泡裁剪 " + context)

func _check_latest_visible(message_list: ScrollContainer, context: String) -> void:
	var scrollbar := message_list.get_v_scroll_bar()
	_check(scrollbar.value + scrollbar.page >= scrollbar.max_value - 2.0, "布局稳定后滚动到最新消息底部 %s（value=%.1f, page=%.1f, max=%.1f）" % [context, scrollbar.value, scrollbar.page, scrollbar.max_value])
	if message_list.rows.get_child_count() > 0:
		var last_row: Control = message_list.rows.get_child(message_list.rows.get_child_count() - 1)
		_check(last_row.get_global_rect().end.y <= message_list.get_global_rect().end.y + 2.0, "最新消息末尾在滚动区域内可见 " + context)

func _settle() -> void:
	for frame in 6:
		await process_frame

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
