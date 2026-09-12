extends VBoxContainer
## Capability management is a view of the runtime; this page never reads the clock.

const KitchenTheme = preload("res://frontend/ui/kitchen_theme.gd")
const BookTheme = preload("res://frontend/ui/book_theme.gd")
const McpLibraryPanel = preload("res://frontend/ui/mcp_library_panel.gd")
const ConfirmationModal = preload("res://frontend/ui/confirmation_modal.gd")

var runtime: RefCounted
var selected_staff_id := "manager"
var selected_staff_name := "主管"
var scroll: ScrollContainer
var content: VBoxContainer
var result_fields: Dictionary = {}
var item_views: Dictionary = {}
var expanded_items: Dictionary = {}
var add_button: Button
var page_header: HBoxContainer
var library_panel: VBoxContainer
var confirmation_overlay: Control
var confirmation_panel: PanelContainer
var confirmation_title: Label
var confirm_uninstall_button: Button
var cancel_uninstall_button: Button
var pending_uninstall_tool_id := ""
var pending_uninstall_staff_id := ""


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	page_header = HBoxContainer.new()
	var title := KitchenTheme.label("MCP", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_header.add_child(title)
	add_button = _button("＋")
	add_button.name = "AddMcp"
	add_button.custom_minimum_size = Vector2(32, 32)
	add_button.tooltip_text = "MCP 库"
	add_button.pressed.connect(show_library)
	page_header.add_child(add_button)
	add_child(page_header)
	library_panel = McpLibraryPanel.new()
	library_panel.name = "McpLibraryPanel"
	library_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(library_panel)
	library_panel.hide()
	library_panel.install_requested.connect(_install_from_library)
	library_panel.canceled.connect(cancel_library)
	_build_uninstall_confirmation()
	scroll = ScrollContainer.new()
	scroll.name = "SkillsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content = VBoxContainer.new()
	content.name = "SkillsContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	add_child(scroll)
	_rebuild()


func set_runtime(value: RefCounted) -> void:
	if is_node_ready():
		cancel_uninstall()
		cancel_library()
	if runtime != null:
		if runtime.skill_changed.is_connected(_on_skill_changed):
			runtime.skill_changed.disconnect(_on_skill_changed)
		if runtime.execution_completed.is_connected(_on_execution_completed):
			runtime.execution_completed.disconnect(_on_execution_completed)
	runtime = value
	if runtime != null:
		runtime.skill_changed.connect(_on_skill_changed)
		runtime.execution_completed.connect(_on_execution_completed)
	if is_node_ready():
		_rebuild()


func select_staff(staff_id: String, display_name: String) -> void:
	var changed := selected_staff_id != staff_id
	if changed and is_node_ready():
		cancel_uninstall()
		cancel_library()
	selected_staff_id = staff_id
	selected_staff_name = display_name
	if is_node_ready():
		_rebuild()
		if changed:
			scroll.scroll_vertical = 0


func _rebuild() -> void:
	if not pending_uninstall_tool_id.is_empty() and not _tool_is_installed(pending_uninstall_staff_id, pending_uninstall_tool_id):
		cancel_uninstall()
	add_button.disabled = runtime == null or not runtime.has_method("list_catalog") or library_panel.visible or confirmation_panel.visible
	result_fields.clear()
	item_views.clear()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	if runtime == null:
		_empty("暂不可用")
		return
	var skills: Array = runtime.list_skills(selected_staff_id)
	for entry: Dictionary in skills:
		if bool(entry.get("installed", false)):
			_build_skill(entry)
	if item_views.is_empty():
		_empty("暂无项目")

func show_library() -> void:
	if runtime == null or not runtime.has_method("list_catalog") or library_panel.visible or confirmation_panel.visible:
		return
	scroll.hide()
	page_header.hide()
	library_panel.set_context(selected_staff_id)
	library_panel.reset_panel()
	library_panel.show()
	_refresh_library()
	add_button.disabled = true

func cancel_library() -> bool:
	if not is_instance_valid(library_panel) or not library_panel.visible:
		return false
	library_panel.hide()
	page_header.show()
	scroll.show()
	add_button.disabled = runtime == null or not runtime.has_method("list_catalog")
	if is_visible_in_tree() and not add_button.disabled:
		add_button.grab_focus()
	return true

func dismiss_active_panel() -> bool:
	if cancel_uninstall():
		return true
	return cancel_library()


func _build_uninstall_confirmation() -> void:
	confirmation_overlay = ConfirmationModal.new()
	confirmation_overlay.name = "McpUninstallOverlay"
	add_child(confirmation_overlay)
	confirmation_panel = confirmation_overlay.card
	confirmation_title = confirmation_overlay.title
	cancel_uninstall_button = confirmation_overlay.cancel_button
	confirm_uninstall_button = confirmation_overlay.confirm_button
	confirmation_overlay.canceled.connect(cancel_uninstall)
	confirmation_overlay.confirmed.connect(_confirm_uninstall)


func _request_uninstall(skill_id: String) -> void:
	if runtime == null or library_panel.visible or confirmation_panel.visible or not item_views.has(skill_id):
		return
	if not _tool_is_installed(selected_staff_id, skill_id):
		return
	pending_uninstall_tool_id = skill_id
	pending_uninstall_staff_id = selected_staff_id
	confirmation_overlay.present("卸载「%s」？" % str(item_views[skill_id].name))
	add_button.disabled = true
	if is_visible_in_tree():
		cancel_uninstall_button.grab_focus()


func cancel_uninstall() -> bool:
	if not is_instance_valid(confirmation_panel) or not confirmation_panel.visible:
		return false
	var tool_id := pending_uninstall_tool_id
	pending_uninstall_tool_id = ""
	pending_uninstall_staff_id = ""
	confirmation_overlay.dismiss()
	add_button.disabled = runtime == null or not runtime.has_method("list_catalog")
	if is_visible_in_tree():
		if item_views.has(tool_id):
			_focus_action(tool_id, "UninstallSkill")
		elif not add_button.disabled:
			add_button.grab_focus()
	return true


func _confirm_uninstall() -> void:
	if not confirmation_panel.visible or pending_uninstall_tool_id.is_empty():
		return
	var staff_id := pending_uninstall_staff_id
	var tool_id := pending_uninstall_tool_id
	var valid := staff_id == selected_staff_id and _tool_is_installed(staff_id, tool_id)
	# Clear the captured action before the runtime emits synchronous change signals.
	cancel_uninstall()
	if not valid:
		return
	var result: Dictionary = runtime.uninstall_skill(staff_id, tool_id)
	_rebuild()
	if not bool(result.get("ok", false)):
		if item_views.has(tool_id):
			_set_expanded(tool_id, true)
		_show_action_result(tool_id, result)
		return
	expanded_items.erase(staff_id + ":" + tool_id)
	if is_visible_in_tree() and not add_button.disabled:
		add_button.grab_focus()


func _tool_is_installed(staff_id: String, tool_id: String) -> bool:
	if runtime == null or staff_id.is_empty() or tool_id.is_empty():
		return false
	for entry: Dictionary in runtime.list_skills(staff_id):
		if str(entry.get("id", "")) == tool_id:
			return bool(entry.get("installed", false))
	return false


func _refresh_library() -> void:
	if library_panel.visible and runtime != null and runtime.has_method("list_catalog"):
		library_panel.set_entries(runtime.list_catalog(selected_staff_id))

func _install_from_library(tool_id: String) -> void:
	if not library_panel.visible or runtime == null or library_panel.actor_staff_id != selected_staff_id:
		return
	var result: Dictionary = runtime.install_skill(selected_staff_id, tool_id)
	if not bool(result.get("ok", false)):
		library_panel.show_error(str(result.get("error", "安装失败")))
		return
	cancel_library()
	_rebuild()
	_focus_action(tool_id, "SkillDetails")
	_focus_action(tool_id, "EnableSkill")


func _build_skill(entry: Dictionary) -> void:
	var skill_id := str(entry.get("id", ""))
	var installed := bool(entry.get("installed", false))
	var enabled := installed and bool(entry.get("enabled", false))
	var item := VBoxContainer.new()
	item.name = "Skill_" + skill_id
	item.add_theme_constant_override("separation", 6)
	content.add_child(item)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	var name_label := KitchenTheme.label(str(entry.get("name", skill_id)), 16)
	name_label.name = "SkillName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(name_label)
	_build_actions(heading, skill_id, enabled, bool(entry.get("can_use", true)))
	var title := _button("详情")
	title.name = "SkillDetails"
	title.toggle_mode = true
	title.add_theme_stylebox_override("normal", KitchenTheme.style(Color.TRANSPARENT, 2, Color.TRANSPARENT, 2))
	title.add_theme_stylebox_override("pressed", KitchenTheme.style(Color.TRANSPARENT, 2, Color.TRANSPARENT, 2))
	title.tooltip_text = "展开详情"
	heading.add_child(title)
	item.add_child(heading)
	var details := VBoxContainer.new()
	details.name = "SkillContent"
	details.add_theme_constant_override("separation", 8)
	item.add_child(details)
	var metadata := HBoxContainer.new()
	var kind := "MCP" if str(entry.get("kind", "skill")) == "mcp" else "Skill"
	metadata.add_child(KitchenTheme.label(kind, 11, KitchenTheme.MUTED))
	var status := "未安装"
	if installed:
		status = "已启用" if enabled else "已暂停"
	var status_label := KitchenTheme.label(status, 12, KitchenTheme.GREEN if enabled else KitchenTheme.MUTED)
	status_label.name = "SkillStatus"
	metadata.add_child(status_label)
	if kind == "MCP":
		metadata.add_child(KitchenTheme.label("未连接", 12, KitchenTheme.MUTED))
	details.add_child(metadata)
	if kind == "MCP":
		var source := str(entry.get("source_url", ""))
		if not source.is_empty():
			details.add_child(_label(source, 12, KitchenTheme.MUTED))
	if not bool(entry.get("can_use", true)):
		details.add_child(_label("尚未获得主管授权", 12, KitchenTheme.MUTED))
	var description := _label(str(entry.get("description", "")), 12, KitchenTheme.MUTED)
	description.visible = not description.text.is_empty()
	details.add_child(description)
	var permissions := PackedStringArray(entry.get("permissions", []))
	if not permissions.is_empty():
		var permission_text := "、".join(permissions)
		if skill_id == "local-time":
			permission_text = "读取设备时间与时区"
		details.add_child(_label("权限：" + permission_text, 12, KitchenTheme.MUTED))
	if installed and skill_id == "local-time":
		_build_result(details, skill_id)
		var sync := _button("立即同步", true)
		sync.name = "ExecuteSkill"
		sync.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		sync.disabled = not enabled
		sync.pressed.connect(_execute.bind(skill_id))
		details.add_child(sync)
	var message := _label("", 12, KitchenTheme.ACCENT)
	message.name = "ActionMessage"
	message.hide()
	details.add_child(message)
	var separator := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = BookTheme.RULE
	line.thickness = 1
	separator.add_theme_stylebox_override("separator", line)
	item.add_child(separator)
	item_views[skill_id] = {"item": item, "title": title, "details": details, "message": message, "name": str(entry.get("name", skill_id))}
	title.pressed.connect(_toggle_details.bind(skill_id))
	_set_expanded(skill_id, bool(expanded_items.get(_item_key(skill_id), false)))
	_update_result(skill_id, entry.get("last_result", {}))


func _build_actions(parent: Container, skill_id: String, enabled: bool, can_use: bool) -> void:
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(actions)
	var enable := _button("启用", true)
	enable.name = "EnableSkill"
	enable.disabled = enabled or not can_use
	enable.tooltip_text = "需要主管授权" if not can_use else ""
	enable.pressed.connect(_set_enabled.bind(skill_id, true))
	actions.add_child(enable)
	var pause := _button("暂停")
	pause.name = "PauseSkill"
	pause.disabled = not enabled
	pause.pressed.connect(_set_enabled.bind(skill_id, false))
	actions.add_child(pause)
	var uninstall := _button("卸载")
	uninstall.name = "UninstallSkill"
	uninstall.pressed.connect(_request_uninstall.bind(skill_id))
	actions.add_child(uninstall)


func _build_result(details: VBoxContainer, skill_id: String) -> void:
	var reading := VBoxContainer.new()
	reading.add_theme_constant_override("separation", 4)
	details.add_child(reading)
	var time_value := KitchenTheme.label("--:--:--", 24)
	time_value.name = "CurrentTime"
	time_value.mouse_filter = Control.MOUSE_FILTER_STOP
	reading.add_child(time_value)
	var metadata := VBoxContainer.new()
	metadata.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metadata.alignment = BoxContainer.ALIGNMENT_CENTER
	metadata.add_theme_constant_override("separation", 4)
	reading.add_child(metadata)
	var date_value := _label("等待同步", 13, KitchenTheme.MUTED)
	date_value.name = "CurrentDateAndTimezone"
	metadata.add_child(date_value)
	result_fields[skill_id] = {"time": time_value, "date": date_value}


func _update_result(skill_id: String, result: Dictionary) -> void:
	if not item_views.has(skill_id) or result.is_empty():
		return
	var ok := bool(result.get("ok", false))
	if not ok:
		_show_action_result(skill_id, result)
		return
	_show_action_result(skill_id, result)
	if not result_fields.has(skill_id):
		return
	var fields: Dictionary = result_fields[skill_id]
	var data: Dictionary = result.get("data", {})
	fields.time.text = str(data.get("time", "--:--:--"))
	fields.time.tooltip_text = "来源：%s" % str(data.get("source", "设备系统时钟"))
	var offset := int(data.get("utc_offset_minutes", 0))
	var offset_text := "UTC%s%02d:%02d" % ["+" if offset >= 0 else "-", absi(offset) / 60, absi(offset) % 60]
	fields.date.text = "%s  ·  %s (%s)" % [str(data.get("date", "")), str(data.get("timezone", "本地时间")), offset_text]

func _item_key(skill_id: String) -> String:
	return selected_staff_id + ":" + skill_id

func _toggle_details(skill_id: String) -> void:
	_set_expanded(skill_id, not bool(expanded_items.get(_item_key(skill_id), false)))

func _set_expanded(skill_id: String, expanded: bool) -> void:
	expanded_items[_item_key(skill_id)] = expanded
	var view: Dictionary = item_views[skill_id]
	view.details.visible = expanded
	view.title.text = "收起" if expanded else "详情"
	view.title.tooltip_text = "收起详情" if expanded else "展开详情"
	view.title.set_pressed_no_signal(expanded)


func _on_skill_changed(staff_id: String, _skill_id: String) -> void:
	if staff_id == selected_staff_id and is_node_ready():
		_rebuild()
	if is_node_ready() and library_panel.visible and staff_id == selected_staff_id:
		_refresh_library()


func _on_execution_completed(staff_id: String, skill_id: String, result: Dictionary) -> void:
	if staff_id == selected_staff_id and is_node_ready():
		_update_result(skill_id, result)


func _set_enabled(skill_id: String, enabled: bool) -> void:
	_show_action_result(skill_id, runtime.set_enabled(selected_staff_id, skill_id, enabled))
	_focus_action(skill_id, "PauseSkill" if enabled else "EnableSkill")


func _execute(skill_id: String) -> void:
	var result: Dictionary = runtime.execute(selected_staff_id, skill_id)
	_update_result(skill_id, result)


func _show_action_result(skill_id: String, result: Dictionary) -> void:
	if not item_views.has(skill_id):
		return
	var message: Label = item_views[skill_id].message
	var ok := bool(result.get("ok", false))
	message.text = "" if ok else str(result.get("error", "操作失败，请重试"))
	message.visible = not message.text.is_empty()

func _focus_action(skill_id: String, action: String) -> void:
	if not item_views.has(skill_id):
		return
	var button: Button = item_views[skill_id].item.find_child(action, true, false)
	if button != null and button.is_visible_in_tree() and not button.disabled:
		button.grab_focus()


func _empty(title: String) -> void:
	content.add_child(_label(title, 14, KitchenTheme.MUTED))


func _label(value: String, font_size: int = 16, color: Color = KitchenTheme.INK) -> Label:
	var result := KitchenTheme.label(value, font_size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result


func _button(value: String, primary: bool = false) -> Button:
	var result := KitchenTheme.button(value)
	result.custom_minimum_size.y = 34
	result.add_theme_font_size_override("font_size", 14)
	if primary:
		result.add_theme_color_override("font_color", KitchenTheme.ACCENT)
	return result
