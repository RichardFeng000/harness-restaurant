extends VBoxContainer

signal account_selected(staff_id: String)

const KitchenTheme = preload("res://frontend/ui/kitchen_theme.gd")
const McpPermissionsPanel = preload("res://frontend/ui/mcp_permissions_panel.gd")
const PERMISSION_NAMES := {
	"can_chat": "对话", "can_portal": "门户", "can_knowledge": "知识库",
	"can_memory": "记忆", "can_mcp": "MCP",
}

var selected_text: Label
var search: LineEdit
var ledger: VBoxContainer
var result_count: Label
var accounts: Dictionary = {}
var selected_id := "manager"
var permissions_panel: VBoxContainer
var permission_target_id := ""
var staff_rows: Dictionary = {}
var runtime: RefCounted
var roster: VBoxContainer
var roster_title: Label


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	roster_title = KitchenTheme.label("门户", 22)
	add_child(roster_title)
	roster = VBoxContainer.new()
	roster.name = "EmployeeRoster"
	roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster.add_theme_constant_override("separation", 8)
	add_child(roster)
	selected_text = KitchenTheme.label("", 13, KitchenTheme.ACCENT)
	selected_text.name = "SelectedAccount"
	selected_text.visible = false
	roster.add_child(selected_text)
	search = LineEdit.new()
	search.name = "Search"
	search.custom_minimum_size.y = 34
	search.placeholder_text = "搜索员工…"
	search.tooltip_text = "按姓名、编号或角色搜索"
	search.add_theme_font_size_override("font_size", 13)
	search.add_theme_stylebox_override("normal", _paper_row(0.12))
	search.add_theme_stylebox_override("focus", _paper_row(0.0, KitchenTheme.ACCENT))
	search.clear_button_enabled = true
	search.text_changed.connect(_filter_accounts)
	roster.add_child(search)
	var scroll := ScrollContainer.new()
	scroll.name = "RosterScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ledger = VBoxContainer.new()
	ledger.name = "Ledger"
	ledger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ledger.add_theme_constant_override("separation", 0)
	scroll.add_child(ledger)
	roster.add_child(scroll)
	result_count = KitchenTheme.label("", 12, KitchenTheme.MUTED)
	result_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roster.add_child(result_count)
	permissions_panel = McpPermissionsPanel.new()
	permissions_panel.name = "McpPermissionsPanel"
	permissions_panel.canceled.connect(close_permissions)
	permissions_panel.permissions_requested.connect(_set_permissions)
	add_child(permissions_panel)
	permissions_panel.hide()
	_refresh()


func _paper_row(opacity: float, line_color: Color = KitchenTheme.BORDER) -> StyleBoxFlat:
	var row_style := KitchenTheme.style(Color(KitchenTheme.CREAM, opacity), 0, line_color, 6)
	row_style.set_border_width_all(0)
	row_style.border_width_bottom = 1
	return row_style


func set_accounts(records: Dictionary) -> void:
	accounts = records
	if is_node_ready():
		if not permission_target_id.is_empty() and not accounts.has(permission_target_id):
			close_permissions()
		_refresh()


func select_account(account_id: String) -> void:
	if selected_id != account_id and is_node_ready():
		close_permissions()
	selected_id = account_id
	if is_node_ready():
		_refresh()


func focus_search() -> void:
	if permissions_panel.visible:
		permissions_panel.focus_first()
	elif is_visible_in_tree():
		search.grab_focus()


func set_runtime(value: RefCounted) -> void:
	if runtime != null and runtime.skill_changed.is_connected(_on_skill_changed):
		runtime.skill_changed.disconnect(_on_skill_changed)
	if is_node_ready():
		close_permissions()
	runtime = value
	if runtime != null:
		runtime.skill_changed.connect(_on_skill_changed)
	if is_node_ready():
		_refresh()


func open_permissions(target_id: String) -> bool:
	if not is_node_ready() or selected_id != "manager" or target_id == "manager" or not accounts.has(target_id):
		return false
	if runtime == null or not runtime.has_method("list_catalog") or not runtime.has_method("set_authorized"):
		return false
	permission_target_id = target_id
	permissions_panel.set_context(target_id, str(accounts[target_id].get("display_name", target_id)))
	permissions_panel.set_entries(runtime.list_catalog(target_id))
	roster.hide()
	roster_title.hide()
	permissions_panel.show()
	permissions_panel.focus_first.call_deferred()
	return true


func close_permissions() -> bool:
	if not is_node_ready() or not permissions_panel.visible:
		return false
	permissions_panel.hide()
	permission_target_id = ""
	permissions_panel.set_context("", "")
	permissions_panel.set_entries([])
	roster.show()
	roster_title.show()
	focus_search.call_deferred()
	return true


func reset_session() -> void:
	if not is_node_ready():
		return
	close_permissions()
	search.clear()


func _set_permissions(tool_id: String, authorized: bool) -> void:
	if selected_id != "manager" or not permissions_panel.visible or permission_target_id.is_empty() or permission_target_id == "manager":
		return
	if runtime == null or not runtime.has_method("set_authorized"):
		return
	var result: Dictionary = runtime.set_authorized(selected_id, permission_target_id, tool_id, authorized)
	permissions_panel.show_error("" if bool(result.get("ok", false)) else str(result.get("error", "授权失败")))
	permissions_panel.set_entries(runtime.list_catalog(permission_target_id))


func _on_skill_changed(staff_id: String, _tool_id: String) -> void:
	if is_node_ready() and permissions_panel.visible and staff_id == permission_target_id and runtime != null:
		permissions_panel.set_entries(runtime.list_catalog(permission_target_id))


func _filter_accounts(_value: String) -> void:
	_refresh()


func _refresh() -> void:
	var selected: Dictionary = accounts.get(selected_id, {})
	selected_text.text = "当前员工：%s · %s" % [selected.get("display_name", "未选择"), _role(selected)]
	staff_rows.clear()
	for child in ledger.get_children():
		ledger.remove_child(child)
		child.queue_free()
	var query := search.text.strip_edges().to_lower()
	var count := 0
	var total := 0
	for staff_id: String in accounts:
		if staff_id == "manager":
			continue
		total += 1
		var record: Dictionary = accounts[staff_id]
		var searchable := "%s %s %s %s" % [staff_id, record.get("display_name", ""), record.get("role_code", ""), _role(record)]
		if not query.is_empty() and not searchable.to_lower().contains(query):
			continue
		count += 1
		var permission_labels: PackedStringArray = []
		for permission: String in PERMISSION_NAMES:
			if bool(record.get(permission, false)):
				permission_labels.append(PERMISSION_NAMES[permission])
		var row := KitchenTheme.button("")
		row.custom_minimum_size.y = 40
		row.name = "Employee_" + staff_id
		row.set_meta("staff_id", staff_id)
		row.disabled = selected_id != "manager" or runtime == null or not runtime.has_method("set_authorized")
		row.add_theme_stylebox_override("normal", _paper_row(0.0))
		row.add_theme_stylebox_override("hover", _paper_row(0.28))
		var selected_style := _paper_row(0.18, KitchenTheme.ACCENT)
		selected_style.bg_color = Color(KitchenTheme.ACCENT, 0.07)
		row.add_theme_stylebox_override("pressed", selected_style)
		row.add_theme_stylebox_override("focus", _paper_row(0.0, KitchenTheme.ACCENT))
		row.tooltip_text = "管理%s的 MCP 权限" % str(record.get("display_name", staff_id))
		row.pressed.connect(_choose_account.bind(staff_id))
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var content := HBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 4)
		var name_line := KitchenTheme.label(str(record.get("display_name", staff_id)), 14)
		name_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_line.tooltip_text = "%s · %s\n可见工作页：%s" % [staff_id, _role(record), " · ".join(permission_labels)]
		content.add_child(name_line)
		content.add_child(KitchenTheme.label("授权", 13, KitchenTheme.ACCENT))
		margin.add_child(content)
		row.add_child(margin)
		ledger.add_child(row)
		staff_rows[staff_id] = row
	if count == 0:
		var empty := KitchenTheme.label("未找到员工", 13, KitchenTheme.MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ledger.add_child(empty)
	result_count.text = "显示 %d / %d" % [count, total]
	result_count.visible = not query.is_empty()


func _role(record: Dictionary) -> String:
	return "管理员" if str(record.get("role_code", "")) == "ADMIN" else "员工"


func _choose_account(staff_id: String) -> void:
	open_permissions(staff_id)
