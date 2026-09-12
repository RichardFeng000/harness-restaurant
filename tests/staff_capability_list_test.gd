extends SceneTree
## Run: ./scripts/run.sh --headless --script tests/staff_capability_list_test.gd
## All runtime state stays in memory; no external MCP, model, or user saves.

const SkillsPage = preload("res://frontend/ui/staff_skills_page.gd")
const BookTheme = preload("res://frontend/ui/book_theme.gd")
const Runtime = preload("res://backend/skills/staff_skill_runtime.gd")
const Timekeeper = preload("res://frontend/world/hamster_timekeeper.gd")
var failures: Array[String] = []

class MultipleSkills:
	extends RefCounted
	signal skill_changed(staff_id: String, skill_id: String)
	signal execution_completed(staff_id: String, skill_id: String, result: Dictionary)
	var states := {
		"alpha": {"installed": true, "enabled": true},
		"beta": {"installed": true, "enabled": true},
	}
	var calls: Array[Dictionary] = []
	func list_skills(_staff_id: String) -> Array:
		var result: Array = []
		for id: String in states:
			result.append({"id": id, "name": "时间工具 Alpha" if id == "alpha" else "日程工具 Beta", "description": "供列表测试的独立能力", "permissions": ["system.time.read"], "authorized": true, "can_install": true, "can_use": true, "installed": states[id].installed, "enabled": states[id].enabled})
		return result
	func list_catalog(staff_id: String) -> Array:
		return list_skills(staff_id)
	func set_enabled(staff_id: String, id: String, enabled: bool) -> Dictionary:
		states[id].enabled = enabled
		return _changed(staff_id, id, "enable" if enabled else "pause")
	func install_skill(staff_id: String, id: String) -> Dictionary:
		states[id] = {"installed": true, "enabled": false}
		return _changed(staff_id, id, "install")
	func uninstall_skill(staff_id: String, id: String) -> Dictionary:
		states[id] = {"installed": false, "enabled": false}
		return _changed(staff_id, id, "uninstall")
	func execute(staff_id: String, id: String) -> Dictionary:
		var result := {"ok": true, "data": {"time": "09:10:20", "date": "2026-09-12", "timezone": "Test", "utc_offset_minutes": 0}}
		execution_completed.emit(staff_id, id, result)
		return result
	func _changed(staff_id: String, id: String, action: String) -> Dictionary:
		calls.append({"staff": staff_id, "id": id, "action": action})
		skill_changed.emit(staff_id, id)
		return {"ok": true}

class SampleReader:
	extends RefCounted
	var calls := 0
	var hour := 9
	func execute() -> Dictionary:
		calls += 1
		return {"ok": true, "data": {"hour": hour, "minute": 10, "second": 20, "time": "%02d:10:20" % hour, "date": "2026-09-12", "timezone": "Test", "utc_offset_minutes": 0}}

class RecordingClock:
	extends Node
	var sample: Dictionary = {}
	func apply_time(value: Dictionary) -> void:
		sample = value.duplicate(true)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var host := Control.new()
	host.position = Vector2(704, 100)
	host.size = Vector2(450, 500)
	host.theme = BookTheme.create()
	root.add_child(host)
	var page = SkillsPage.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(page)
	page.select_staff("hamster", "仓鼠")
	var multiple := MultipleSkills.new()
	page.set_runtime(multiple)
	await _settle()
	_check(_entry(page, "alpha") != null and _entry(page, "beta") != null, "每项能力独立显示在列表中")
	_check(not _details_visible(page, "alpha") and not _details_visible(page, "beta"), "默认收起每项详情")
	_check_collapsed_header(page, "alpha", "时间工具 Alpha")
	_check_collapsed_header(page, "beta", "日程工具 Beta")
	for id: String in ["alpha", "beta"]:
		_check(_button(page, id, "EnableSkill").disabled and not _button(page, id, "PauseSkill").disabled, "已启用项禁用启用按钮并可暂停：" + id)
	await _click(page, _button(page, "alpha", "SkillDetails"))
	_check(_details_visible(page, "alpha") and not _details_visible(page, "beta"), "只展开点击的项目")
	_check(_button(page, "alpha", "SkillDetails").text == "收起", "展开后的详情按钮显示收起")
	var open_alpha := _entry(page, "alpha")
	multiple.execute("hamster", "alpha")
	await _settle()
	_check(_entry(page, "alpha") == open_alpha and _details_visible(page, "alpha"), "运行结果刷新不重建列表或收起已展开的项目")
	await _click(page, _button(page, "beta", "PauseSkill"))
	_check(multiple.states.alpha.enabled and not multiple.states.beta.enabled, "直接暂停收起的 Beta 不影响 Alpha")
	_check(_details_visible(page, "alpha") and not _details_visible(page, "beta"), "列表行操作刷新后保留各项展开或收起状态")
	_check_collapsed_header(page, "beta", "日程工具 Beta")
	await _click(page, _button(page, "alpha", "PauseSkill"))
	_check(not multiple.states.alpha.enabled and not multiple.states.beta.enabled, "暂停 Alpha 绑定它自己的能力编号")
	_check(not _button(page, "alpha", "EnableSkill").disabled and _button(page, "alpha", "PauseSkill").disabled, "暂停项可以启用且不能重复暂停")
	_check(_details_visible(page, "alpha") and not _details_visible(page, "beta"), "暂停当前项后保留另一项的收起状态")
	await _click(page, _button(page, "alpha", "EnableSkill"))
	_check(multiple.states.alpha.enabled and not multiple.states.beta.enabled, "启用 Alpha 不恢复 Beta")
	var calls_before_request := multiple.calls.size()
	var alpha_rect: Rect2 = _entry(page, "alpha").get_global_rect()
	await _click(page, _button(page, "alpha", "UninstallSkill"))
	_check(page.confirmation_panel.is_visible_in_tree() and page.pending_uninstall_tool_id == "alpha" and page.pending_uninstall_staff_id == "hamster", "卸载请求先确认当前员工和工具")
	_check(page.scroll.is_visible_in_tree() and page.page_header.is_visible_in_tree() and _entry(page, "alpha").is_visible_in_tree(), "悬浮确认下方保留 MCP 标题和原列表")
	_check(_entry(page, "alpha").get_global_rect().is_equal_approx(alpha_rect), "悬浮确认不改变列表项目位置")
	_check_confirmation_bounds(page)
	_check(multiple.calls.size() == calls_before_request and multiple.states.alpha.installed, "确认前不调用卸载服务")
	await _click(page, _button(page, "alpha", "PauseSkill"))
	await _click(page, _button(page, "beta", "SkillDetails"))
	_check(multiple.calls.size() == calls_before_request and multiple.states.alpha.enabled and not _details_visible(page, "beta"), "悬浮确认阻止点击穿透到列表操作和详情")
	await _click(page, page.cancel_uninstall_button)
	_check(not page.confirmation_panel.is_visible_in_tree() and page.scroll.visible and multiple.calls.size() == calls_before_request, "取消卸载不修改安装或运行状态")
	await _click(page, _button(page, "alpha", "UninstallSkill"))
	await _click(page, page.confirm_uninstall_button)
	_check(not multiple.states.alpha.installed and multiple.states.beta.installed and not multiple.states.beta.enabled, "卸载仅删除指定项的安装状态")
	_check(_entry(page, "alpha") == null and not page.item_views.has("alpha"), "确认卸载后该项完全从 MCP 主列表移除")
	_check(page.content.find_child("InstallSkill", true, false) == null, "MCP 主列表不提供已卸载项目或原地安装按钮")
	page.confirm_uninstall_button.pressed.emit()
	await _settle()
	_check(multiple.calls.size() == calls_before_request + 1, "重复确认不会重复调用卸载")
	await _click(page, page.add_button)
	_check(page.library_panel.visible and page.library_panel.item_views.has("alpha"), "已卸载工具仍可在加号 MCP 库找到")
	await _click(page, page.library_panel.item_views.alpha.install)
	_check(multiple.states.alpha.installed and not multiple.states.alpha.enabled and not multiple.states.beta.enabled, "通过加号重装默认暂停且不改变 Beta 状态")
	_check(not _details_visible(page, "alpha"), "重装的列表项目默认收起详情")
	_check(multiple.calls.size() == 5, "每次操作仅调用一次对应服务")
	for call: Dictionary in multiple.calls:
		_check(call.staff == "hamster", "每项操作绑定当前员工")
	await _click(page, _button(page, "alpha", "SkillDetails"))
	_check(_details_visible(page, "alpha"), "重装项仍可以查看详情")
	await _click(page, _button(page, "alpha", "SkillDetails"))
	_check(not _details_visible(page, "alpha"), "展开项可以再次收起")
	_check_collapsed_header(page, "alpha", "时间工具 Alpha")
	for dimensions in [Vector2(450, 500), Vector2(334, 365)]:
		host.size = dimensions
		await _settle()
		_check_horizontal_bounds(page, host, "收起 " + str(dimensions))
		await _click(page, _button(page, "alpha", "SkillDetails"))
		_check_horizontal_bounds(page, host, "展开 " + str(dimensions))
		await _click(page, _button(page, "alpha", "SkillDetails"))

	# Use the real bundled runtime and worker to verify the UI has real effects.
	var reader := SampleReader.new()
	var runtime := Runtime.new(reader)
	var clock := RecordingClock.new()
	var worker := Timekeeper.new()
	root.add_child(clock)
	root.add_child(worker)
	worker.bind(runtime, clock)
	page.set_runtime(runtime)
	worker.set_active(true)
	await _settle()
	_check(reader.calls == 1 and int(clock.sample.get("hour", -1)) == 9, "真实运行时进入工作状态后读取并校准时钟")
	_check_collapsed_header(page, "local-time", "本地时间")
	await _click(page, _button(page, "local-time", "PauseSkill"))
	var paused_calls := reader.calls
	reader.hour = 10
	await _wait_wall_time(1.15)
	worker.sync_now()
	_check(reader.calls == paused_calls and int(clock.sample.get("hour", -1)) == 9, "暂停后跨越自动采样周期也不读取或移动时钟")
	_check(runtime.is_installed("hamster", "local-time") and not runtime.is_enabled("hamster", "local-time"), "暂停保留安装且关闭运行状态")
	await _click(page, _button(page, "local-time", "EnableSkill"))
	_check(reader.calls > paused_calls and int(clock.sample.get("hour", -1)) == 10, "启用后立即恢复真实时间采样")
	_check(not _details_visible(page, "local-time"), "直接启用和暂停不自动展开详情")
	await _click(page, _button(page, "local-time", "SkillDetails"))
	var current_time: Label = _entry(page, "local-time").find_child("CurrentTime", true, false)
	_check(current_time != null and current_time.is_visible_in_tree() and current_time.text == "10:10:20", "只有真实时间技能详情展示当前时钟读数")
	await _click(page, _button(page, "local-time", "SkillDetails"))
	await _click(page, _button(page, "local-time", "UninstallSkill"))
	_check(runtime.is_installed("hamster", "local-time") and worker.is_working(), "本地时间等待卸载确认时继续工作")
	_check_confirmation_bounds(page)
	await _click(page, page.confirm_uninstall_button)
	_check(not runtime.is_installed("hamster", "local-time") and not runtime.export_state().get("hamster", {}).has("local-time"), "卸载从真实安装状态中删除时间技能")
	_check(_entry(page, "local-time") == null and not page.item_views.has("local-time"), "本地时间与其他 MCP 一样，卸载后从主列表消失")
	_check(not worker.is_working() and runtime.is_authorized("hamster", "local-time"), "确认卸载立即停止时钟员工并保留主管授权")
	var uninstalled_calls := reader.calls
	worker.sync_now()
	_check(reader.calls == uninstalled_calls, "卸载后停止读取时间")
	reader.hour = 11
	await _click(page, page.add_button)
	_check(page.library_panel.item_views.has("local-time") and not page.library_panel.item_views["local-time"].install.disabled, "本地时间卸载后可从加号重新安装")
	await _click(page, page.library_panel.item_views["local-time"].install)
	_check(runtime.is_installed("hamster", "local-time") and not runtime.is_enabled("hamster", "local-time"), "重新安装默认暂停，等待员工选择启用")
	_check(_entry(page, "local-time") != null and not page.library_panel.visible, "从库重装后返回 MCP 列表并显示该项")
	_check(reader.calls == uninstalled_calls, "重新安装不会自动读取设备时间")
	await _click(page, _button(page, "local-time", "EnableSkill"))
	_check(reader.calls > uninstalled_calls and int(clock.sample.get("hour", -1)) == 11, "员工主动启用后使用新的时间采样")
	worker.set_active(false)
	host.queue_free()
	worker.queue_free()
	clock.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("Staff capability list test: ", "PASS" if failures.is_empty() else "FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _entry(page: Control, id: String) -> Control:
	return page.content.get_node_or_null("Skill_" + id)

func _button(page: Control, id: String, button_name: String) -> Button:
	var entry := _entry(page, id)
	var found: Button = entry.find_child(button_name, true, false) if entry != null else null
	_check(found != null, "项目 %s 包含操作 %s" % [id, button_name])
	return found

func _details_visible(page: Control, id: String) -> bool:
	var entry := _entry(page, id)
	if entry == null:
		return false
	var details: Control = entry.find_child("SkillContent", true, false)
	return details != null and details.is_visible_in_tree()

func _check_collapsed_header(page: Control, id: String, expected_name: String) -> void:
	var item := _entry(page, id)
	if item == null:
		_check(false, "收起列表包含项目 " + id)
		return
	var name_label: Label = item.find_child("SkillName", true, false)
	_check(name_label != null and name_label.is_visible_in_tree() and name_label.text == expected_name, "项目名称独立显示：" + id)
	var visible_text: Array[String] = []
	for control in item.find_children("*", "Control", true, false):
		if control.is_visible_in_tree() and (control is Label or control is Button) and not str(control.text).is_empty():
			visible_text.append(str(control.text))
	var expected_text: Array = [expected_name, "启用", "暂停", "卸载", "详情"]
	_check(visible_text == expected_text, "列表行按名称、操作、详情顺序显示，无额外状态或类型：%s %s" % [id, visible_text])

func _check_horizontal_bounds(page: Control, host: Control, context: String) -> void:
	_check(page.size.x <= host.size.x + 1.0 and page.size.y <= host.size.y + 1.0, "页面不撑大右书页 " + context)
	var bounds: Rect2 = page.scroll.get_global_rect()
	_check(page.content.size.x <= bounds.size.x + 1.0, "列表宽度不超出纸面 " + context)
	_check(not page.scroll.get_h_scroll_bar().visible, "列表不需要横向滚动 " + context)
	for node in page.content.find_children("*", "Control", true, false):
		var control: Control = node
		if control.is_visible_in_tree():
			var rect := control.get_global_rect()
			_check(rect.position.x >= bounds.position.x - 1.0 and rect.end.x <= bounds.end.x + 1.0, "项目内容不横向溢出：%s %s" % [control.name, context])

func _click(page: Control, control: Control) -> void:
	if control == null:
		_check(false, "待点击的控件存在")
		return
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await _settle()
	var center := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
	await _settle()

func _check_confirmation_bounds(page: Control) -> void:
	_check(page.confirmation_panel.is_visible_in_tree() and page.confirmation_overlay.is_visible_in_tree(), "卸载确认在全视口遮罩上悬浮显示")
	var bounds := root.get_visible_rect()
	var card: Rect2 = page.confirmation_panel.get_global_rect()
	_check(page.confirmation_overlay.get_global_rect().is_equal_approx(bounds), "遮罩覆盖整个视口")
	_check(card.get_center().distance_to(bounds.get_center()) < 1.0, "卸载确认卡片位于视口中央")
	_check(card.size.x <= minf(360.0, bounds.size.x - 32.0) + 1.0, "卸载确认保持小卡片宽度")
	for control in page.confirmation_panel.find_children("*", "Control", true, false):
		if control.is_visible_in_tree():
			var rect: Rect2 = control.get_global_rect()
			_check(rect.position.x >= bounds.position.x - 1.0 and rect.end.x <= bounds.end.x + 1.0 and rect.position.y >= bounds.position.y - 1.0 and rect.end.y <= bounds.end.y + 1.0, "悬浮确认控件不溢出视口：" + str(control.name))

func _settle() -> void:
	for frame in 4:
		await process_frame

func _wait_wall_time(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
