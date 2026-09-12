extends SceneTree
## Run: ./scripts/run.sh --headless --script tests/book_open_transition_test.gd
## Exercises book opening/closing, blocked transition input and the skill binding.

const MainScene = preload("res://frontend/scenes/main.tscn")
const Api = preload("res://backend/harness_api.gd")
const Runtime = preload("res://backend/skills/staff_skill_runtime.gd")
const Store = preload("res://frontend/state/workspace_store.gd")

var failures: Array[String] = []
var completed_openings := 0
var completed_closings := 0
var closed_events := 0
var temporary_dir := "/tmp/harness_book_transition_%d" % Time.get_ticks_usec()

class TestTime:
	extends RefCounted
	var hour := 9
	var calls := 0
	func execute() -> Dictionary:
		calls += 1
		return {"ok": true, "data": {
			"hour": hour, "minute": 22, "second": 33,
			"time": "%02d:22:33" % hour, "date": "2026-09-11",
			"timezone": "Test", "utc_offset_minutes": 0,
		}}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(temporary_dir)
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var reader := TestTime.new()
	var main = MainScene.instantiate()
	main.api = Api.new(temporary_dir.path_join("database.csv"), false)
	main.api.skills = Runtime.new(reader)
	main.store = Store.new(temporary_dir.path_join("save.json"), temporary_dir.path_join("workspace.json"))
	root.add_child(main)
	await process_frame
	main._open_demo()
	main._start_agent_run()
	await process_frame
	var book = main.harness_layer
	book.opening.finished.connect(func(): completed_openings += 1)
	book.opening.closing_finished.connect(func(): completed_closings += 1)
	book.closed.connect(func(): closed_events += 1)
	var runtime = main.api.skills
	var initial_skill_state: Dictionary = runtime.export_state()
	var expected_labels := {
		"chat": "对话", "portal": "门户", "knowledge": "知识库",
		"memory": "记忆", "mcp": "MCP",
	}
	for page_id: String in expected_labels:
		_check(book.page_buttons[page_id].text == expected_labels[page_id], "导航应显示原功能名：" + expected_labels[page_id])
	_check(book.close_button.text == "×" and book.close_button.tooltip_text.contains("合上书本") and book.close_button.tooltip_text.contains("Esc"), "右上角使用带关闭提示的 × 按钮")

	await _click(main.hud.book_button)
	_check(book.visible and book.opening.is_playing, "点击书封面开始翻书动画")
	_check(main.hud.book_button.modulate.a == 0.0, "书封面抬起时原入口不重复绘制")
	await _wait_seconds(0.50)
	main.hud.book_requested.emit()
	await _wait_seconds(0.55)
	_check(completed_openings == 1 and not book.opening.is_playing, "重复打开不延长或重启已有翻书动画")
	_check(book.visible and root.gui_get_focus_owner() == book.chat_page.message_input, "翻书完成后显示对话并恢复输入焦点")
	await _type_text("保留这条记录")
	await _click(book.chat_page.send_button)
	await _type_text("尚未提交")
	var saved_entries: Array = book.chat_page._draft()["messages"].duplicate(true)
	var saved_input: String = book.chat_page.message_input.text
	_check(saved_entries.size() == 1 and saved_input == "尚未提交", "关闭前建立一条草稿并保留未提交文字")
	var close_started := Time.get_ticks_msec()
	await _click(book.close_button)
	_check(book.visible and book.is_closing and closed_events == 0, "点击 × 后先播放合书动画，完成前保持可见且不发 closed")
	_check(main.hud.book_button.modulate.a == 0.0, "合书回到入口前不提前显示第二个书封面")
	await _type_text("不应写入")
	await _key(KEY_ENTER)
	await _click(book.chat_page.send_button)
	_check(book.chat_page._draft()["messages"] == saved_entries and book.chat_page.message_input.text == saved_input, "合书时键盘和发送按钮不能修改草稿")
	await _wait_until(close_started + 250)
	await _escape()
	book.close()
	await _wait_until(close_started + 500)
	await _escape()
	await _wait_until(close_started + 800)
	_check(not book.visible and not book.is_closing and completed_closings == 1 and closed_events == 1, "重复 close 和 Esc 不重启合书，首次请求后按时结束且只通知一次")
	_check(not paused and root.gui_get_focus_owner() == main.hud.book_button, "合书完成后保持营业并恢复书封面焦点")
	_check(main.hud.book_button.modulate.a == 1.0, "合书回到入口后恢复原封面显示")

	await _click(main.hud.book_button)
	await _wait_seconds(0.18)
	book.close()
	_check(book.visible and book.is_closing, "翻开途中关闭会转入合书动画")
	await _wait_seconds(1.0)
	_check(not book.visible and not book.opening.is_playing and completed_openings == 1 and closed_events == 2, "翻开途中反向合书后不会迟到重显或发出开书完成事件")
	_check(root.gui_get_focus_owner() == main.hud.book_button and main.hud.book_button.modulate.a == 1.0, "反向合书恢复入口，已取消的开书不会抢焦点")

	await _click(main.hud.book_button)
	await _wait_seconds(0.18)
	await _escape()
	_check(book.visible and book.is_closing, "翻开时按 Esc 也会先播放合书")
	await _escape()
	await _wait_seconds(1.0)
	_check(not book.visible and not book.opening.is_playing and completed_openings == 1 and closed_events == 3, "连按 Esc 可从开书返回入口，之后保持关闭")
	_check(not paused and root.gui_get_focus_owner() == main.hud.book_button, "Esc 关闭翻书后保持营业并恢复封面焦点")

	await _click(main.hud.book_button)
	await _wait_seconds(1.05)
	_check(book.visible and not book.opening.visible and completed_openings == 2, "取消后可再次完整翻开且移除动画遮挡")
	_check(book.chat_page._draft()["messages"] == saved_entries and book.chat_page.message_input.text == saved_input, "反复开合后保留记录及未提交草稿")
	await _click(book.portal_button)
	_check(book.current_page == "portal" and root.gui_get_focus_owner() == book.portal_page.search, "动画后门户按钮可点击且搜索可获得焦点")
	await _click(book.staff_buttons["hamster"])
	await _click(book.mcp_button)
	_check(book.current_staff_id == "hamster" and book.current_page == "mcp", "动画后可以切换仓鼠并打开 MCP")
	_check(book.skill_runtime == runtime and book.mcp_page.runtime == runtime, "翻书与导航保留原技能运行时绑定")
	_check(runtime.export_state() == initial_skill_state, "打开和关闭书本不修改员工技能安装状态")
	var time_entry = book.mcp_page.content.get_node("Skill_local-time")
	await _click(time_entry.find_child("SkillDetails", true, false))
	var sync_button = time_entry.find_child("ExecuteSkill", true, false)
	_check(sync_button != null and sync_button.is_visible_in_tree(), "展开时间 Skill 后可查看同步操作")
	if sync_button != null:
		book.mcp_page.scroll.ensure_control_visible(sync_button)
		await process_frame
		reader.hour = 11
		var calls_before: int = reader.calls
		await _click(sync_button)
		_check(reader.calls > calls_before, "MCP 页立即同步按钮调用已绑定的时间 Skill")
		var clock = main.restaurant_scene.get_node("Furniture/HamsterClock")
		_check(int(clock._seconds_of_day) == 40953, "同步结果继续驱动餐厅墙钟")
		_check(book.mcp_page.find_child("CurrentTime", true, false).text == "11:22:33", "MCP 页继续展示同一运行时的执行结果")
		# Isolate UI clicks from the separately tested one-second background poll.
		main.timekeeper.set_process(false)
		var calls_before_close: int = reader.calls
		await _click(book.close_button)
		await _click(sync_button)
		await _key(KEY_ENTER)
		await _wait_seconds(0.8)
		_check(reader.calls == calls_before_close, "合书期间被遮挡的立即同步按钮与键盘不能执行技能")
		_check(not book.visible and closed_events == 4, "MCP 页也可完整合书返回入口")
		await _click(main.hud.book_button)
		await _wait_seconds(1.05)
		_check(book.current_page == "mcp" and book.current_staff_id == "hamster" and book.mcp_page.runtime == runtime, "再次开书保留仓鼠、MCP 页与原技能运行时")
		_check(runtime.export_state() == initial_skill_state, "合书不修改时间技能的安装与启用状态")

	await _click(book.close_button)
	_check(book.is_closing, "返回菜单前确实有正在播放的合书动画")
	var closed_before_menu := closed_events
	var animations_before_menu := completed_closings
	main._back_to_menu()
	var menu_focus := root.gui_get_focus_owner()
	_check(not book.visible and not book.is_closing and not book.opening.is_playing, "返回菜单立即隐藏工作簿并取消合书")
	await _wait_seconds(0.9)
	_check(not book.visible and closed_events == closed_before_menu and completed_closings == animations_before_menu, "被菜单取消的合书不会迟到通知或重显")
	_check(root.gui_get_focus_owner() == menu_focus, "取消合书后不会抢走菜单焦点")
	main.queue_free()
	await process_frame
	for file_name in ["save.json", "workspace.json", "database.csv"]:
		var file_path := temporary_dir.path_join(file_name)
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	DirAccess.remove_absolute(temporary_dir)
	if failures.is_empty():
		print("Book opening transition test: PASS")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _click(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion)
	for is_pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = is_pressed
		root.push_input(event)
	await process_frame
	await process_frame

func _escape() -> void:
	await _key(KEY_ESCAPE)

func _key(keycode: Key) -> void:
	for is_pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = is_pressed
		root.push_input(event)
	await process_frame
	await process_frame

func _type_text(value: String) -> void:
	for index in value.length():
		for is_pressed in [true, false]:
			var event := InputEventKey.new()
			event.unicode = value.unicode_at(index)
			event.pressed = is_pressed
			root.push_input(event)
	await process_frame
	await process_frame

func _wait_until(deadline_msec: int) -> void:
	while Time.get_ticks_msec() < deadline_msec:
		await process_frame

func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
