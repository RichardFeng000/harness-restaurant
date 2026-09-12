extends SceneTree
## Run: godot --headless --path . --script tests/harness_book_test.gd
## This suite uses only in-memory drafts and reads the existing staff CSV.

const BookSystem = preload("res://frontend/scenes/harness_book_system.tscn")
const SkillRuntime = preload("res://backend/skills/staff_skill_runtime.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)


func _run() -> void:
	var book = BookSystem.instantiate()
	book.set_skill_runtime(SkillRuntime.new())
	root.add_child(book)
	await process_frame
	_check(book.staff_permissions.has("hamster"), "CSV roster must include the hamster")
	_check(book.staff_buttons.size() == book.staff_permissions.size(), "Avatar roster must follow the CSV")
	for staff_id: String in book.staff_permissions:
		book._select_staff(staff_id)
		for page_id: String in book.page_buttons:
			var expected := bool(book.staff_permissions[staff_id].get("can_" + page_id, false))
			_check(book.page_buttons[page_id].visible == expected, "Navigation permission mismatch: " + staff_id + "/" + page_id)
		_check(book.staff_buttons[staff_id].button_pressed, "Selected avatar must match current staff")
		_check(book.chat_page.current_staff_id == staff_id, "Chat identity must follow the selected staff")
		_check(book.portal_page.selected_id == staff_id, "Roster identity must follow the selected staff")
	book._select_staff("manager")
	book.show_portal()
	var portal = book.portal_page
	_check(not portal.staff_rows.has("manager"), "The portal must list managed employees, excluding the manager")
	portal.search.text = "仓鼠"
	portal.search.text_changed.emit("仓鼠")
	_check(portal.ledger.get_child_count() == 1, "Chinese name search must filter the roster")
	_check(portal.ledger.get_child(0).tooltip_text == "管理仓鼠的 MCP 权限", "Search must find the CSV hamster management record")
	portal.ledger.get_child(0).pressed.emit()
	_check(book.current_staff_id == "manager" and portal.selected_id == "manager" and book.staff_buttons["manager"].button_pressed, "Choosing an employee for authorization must retain the manager identity")
	_check(book.chat_page.current_staff_id == "manager" and book.mcp_page.selected_staff_id == "manager", "A portal target must not change the chat or MCP owner")
	_check(book.current_page == "portal" and portal.permission_target_id == "hamster" and portal.permissions_panel.visible, "The employee row must open their permissions within the portal")
	var permissions = portal.permissions_panel
	_check(not permissions.item_views.is_empty(), "The portal must list tools available for authorization")
	for tool_id: String in permissions.item_views:
		var view: Dictionary = permissions.item_views[tool_id]
		var grant: CheckBox = view.get("authorized")
		_check(grant != null and grant.text == "授权" and grant.name == "ToolAuthorized", "Each tool must have a single authorization action: " + tool_id)
		_check(view.item.find_children("*", "CheckBox", true, false).size() == 1, "Install and use must share one grant: " + tool_id)
		_check(view.item.find_child("CanInstall", true, false) == null and view.item.find_child("CanUse", true, false) == null, "Separate installation and use controls must be absent: " + tool_id)
	_check(portal.close_permissions(), "Returning from permissions must close the nested panel")
	portal.search.text = "HEAD_CHEF"
	portal.search.text_changed.emit("HEAD_CHEF")
	_check(portal.ledger.get_child_count() == 1, "Staff ID search must ignore case")
	_check(portal.ledger.get_child(0).tooltip_text == "管理主厨的 MCP 权限", "Staff ID search must find the matching management record")
	portal.search.text = "没有这位员工"
	portal.search.text_changed.emit(portal.search.text)
	_check(portal.result_count.text.begins_with("显示 0 /"), "Unmatched search must show an empty result count")
	book.staff_buttons["hamster"].pressed.emit()
	_check(book.current_page == "chat", "Restricted staff must leave the admin-only roster")
	_check(book.current_staff_id == "hamster" and book.staff_buttons["hamster"].button_pressed and portal.selected_id == "hamster", "Avatar selection must switch the current staff identity consistently")
	_check(not portal.open_permissions("hamster") and not portal.permissions_panel.visible, "Nonmanager identity must not open the portal permission panel")
	book.show_knowledge()
	_check(book.current_page == "chat", "Direct navigation must also enforce permissions")
	var chat = book.chat_page
	chat.message_input.text = "   "
	chat.message_input.text_changed.emit("   ")
	_check(chat.send_button.disabled, "Whitespace-only input must disable submission")
	chat._send_text("   ")
	_check(chat._draft()["messages"].is_empty(), "Whitespace-only input must not create a record")
	var literal_text := "[b]原样保留[/b] [url=https://example.com]文字[/url]"
	chat.message_input.text = literal_text
	chat.message_input.text_changed.emit(literal_text)
	_check(not chat.send_button.disabled, "Nonempty input must enable submission")
	chat.send_button.pressed.emit()
	_check(chat.messages.get_parsed_text().contains(literal_text), "User input must remain literal, including BBCode brackets")
	_check(chat._draft()["messages"].size() == 1, "One submission must create exactly one user record")
	_check(chat.send_button.disabled, "Submission must clear and disable the input")
	chat.message_input.text = "尚未提交的文字"
	chat.message_input.text_changed.emit(chat.message_input.text)
	chat._new_conversation()
	_check(chat.staff_drafts["hamster"].size() == 2, "New draft must retain the previous draft")
	chat.draft_picker.item_selected.emit(0)
	_check(chat.message_input.text == "尚未提交的文字", "Switching drafts must restore unfinished input")
	book._select_staff("manager")
	_check(chat._draft()["messages"].is_empty(), "A different staff member must get an isolated draft")
	book._select_staff("hamster")
	_check(chat.message_input.text == "尚未提交的文字", "Switching staff must retain that staff member's unfinished input")
	book.close()
	await create_timer(0.8).timeout
	_check(not book.visible, "Closing animation must return to the restaurant")
	book.open()
	_check(chat._draft()["messages"].size() == 1, "Closing the workbook must preserve the current session")
	book.reset_session()
	_check(book.current_staff_id == "manager" and book.current_page == "chat", "Session reset must return to manager/chat")
	_check(chat.staff_drafts.size() == 1 and chat.staff_drafts.has("manager"), "Session reset must remove all previous staff drafts")
	_check(chat._draft()["messages"].is_empty() and chat.message_input.text.is_empty(), "Session reset must clear records and unfinished input")
	_check(portal.search.text.is_empty(), "Session reset must clear roster search")
	await process_frame
	book.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: workbook permissions, roster search, draft isolation, literal text and session reset")
	else:
		print("FAIL: %d workbook checks" % failures.size())
	quit(0 if failures.is_empty() else 1)
