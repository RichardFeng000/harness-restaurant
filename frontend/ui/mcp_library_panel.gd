extends VBoxContainer
## Shared catalog picker for every employee; authorization is managed in the portal.

signal canceled
signal install_requested(tool_id: String)

const KitchenTheme = preload("res://frontend/ui/kitchen_theme.gd")
const BookTheme = preload("res://frontend/ui/book_theme.gd")

var search: LineEdit
var content: VBoxContainer
var item_views: Dictionary = {}
var back_button: Button
var status_label: Label
var scroll: ScrollContainer
var actor_staff_id := "manager"
var entries: Array = []
var expanded_items: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var header := HBoxContainer.new()
	var title := KitchenTheme.label("MCP 库", 19, BookTheme.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	back_button = _button("返回", "LibraryBack")
	back_button.pressed.connect(func(): canceled.emit())
	header.add_child(back_button)
	add_child(header)
	search = LineEdit.new()
	search.name = "LibrarySearch"
	search.placeholder_text = "搜索 MCP…"
	search.custom_minimum_size.y = 32
	search.add_theme_font_size_override("font_size", 14)
	search.text_changed.connect(_search_changed)
	add_child(search)
	status_label = _label("", 12, KitchenTheme.ACCENT)
	status_label.name = "LibraryError"
	status_label.hide()
	add_child(status_label)
	scroll = ScrollContainer.new()
	scroll.name = "LibraryScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content = VBoxContainer.new()
	content.name = "LibraryContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	add_child(scroll)
	_rebuild()


func set_context(staff_id: String) -> void:
	var changed := actor_staff_id != staff_id
	actor_staff_id = staff_id
	if not is_node_ready():
		return
	if changed:
		search.clear()
		show_error("")
	_rebuild()


func set_entries(value: Array) -> void:
	entries = value.duplicate(true)
	if is_node_ready():
		_rebuild()


func reset_panel() -> void:
	if not is_node_ready():
		return
	search.clear()
	show_error("")
	scroll.scroll_vertical = 0
	_rebuild()
	_focus_search.call_deferred()


func show_error(message: String) -> void:
	if not is_instance_valid(status_label):
		return
	status_label.text = message
	status_label.visible = not message.is_empty()


func _search_changed(_text: String) -> void:
	scroll.scroll_vertical = 0
	_rebuild()


func _rebuild() -> void:
	item_views.clear()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var query := search.text.strip_edges().to_lower()
	for value: Variant in entries:
		if not value is Dictionary:
			continue
		var entry: Dictionary = value
		var tool_id := str(entry.get("id", ""))
		if tool_id.is_empty():
			continue
		var tool_name := str(entry.get("name", tool_id))
		if not query.is_empty() and not tool_name.to_lower().contains(query) and not tool_id.to_lower().contains(query):
			continue
		_build_item(entry)
	if item_views.is_empty():
		content.add_child(_label("暂无 MCP" if query.is_empty() else "无匹配项", 14, BookTheme.MUTED))


func _build_item(entry: Dictionary) -> void:
	var tool_id := str(entry.get("id", ""))
	var item := VBoxContainer.new()
	item.name = "Library_" + tool_id
	item.add_theme_constant_override("separation", 5)
	content.add_child(item)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var title := KitchenTheme.label(str(entry.get("name", tool_id)), 15, BookTheme.INK)
	title.name = "LibraryName"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(title)
	var installed := bool(entry.get("installed", false))
	var allowed := bool(entry.get("can_install", false))
	var install := _button("已安装" if installed else ("安装" if allowed else "未授权"), "InstallMcp")
	install.disabled = installed or not allowed
	install.pressed.connect(_request_install.bind(tool_id))
	row.add_child(install)
	var view: Dictionary = {"item": item, "name": title, "install": install}
	var details_button := _button("详情", "LibraryDetails")
	details_button.toggle_mode = true
	row.add_child(details_button)
	item.add_child(row)
	var details := VBoxContainer.new()
	details.name = "LibraryDetailsContent"
	details.add_theme_constant_override("separation", 4)
	var kind := "Skill" if str(entry.get("kind", "mcp")).to_lower() == "skill" else "MCP"
	details.add_child(_label(kind, 11, BookTheme.MUTED))
	var description := str(entry.get("description", ""))
	if not description.is_empty():
		details.add_child(_label(description, 12, BookTheme.MUTED))
	var source := str(entry.get("source", ""))
	var source_url := str(entry.get("source_url", ""))
	if not source.is_empty():
		details.add_child(_label(source, 11, BookTheme.MUTED))
	if not source_url.is_empty() and source_url != source:
		details.add_child(_label(source_url, 11, BookTheme.MUTED))
	if kind == "MCP":
		var limitation := str(entry.get("connection_limitation", "尚未接入执行"))
		if not limitation.is_empty():
			details.add_child(_label(limitation, 12, BookTheme.MUTED))
	item.add_child(details)
	view["details"] = details
	view["details_button"] = details_button
	item_views[tool_id] = view
	var expanded := bool(expanded_items.get(_expansion_key(tool_id), false))
	details.visible = expanded
	details_button.set_pressed_no_signal(expanded)
	details_button.text = "收起" if expanded else "详情"
	details_button.toggled.connect(_toggle_details.bind(tool_id))
	var separator := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = BookTheme.RULE
	line.thickness = 1
	separator.add_theme_stylebox_override("separator", line)
	item.add_child(separator)


func _request_install(tool_id: String) -> void:
	show_error("")
	install_requested.emit(tool_id)


func _toggle_details(expanded: bool, tool_id: String) -> void:
	if not item_views.has(tool_id):
		return
	expanded_items[_expansion_key(tool_id)] = expanded
	var view: Dictionary = item_views[tool_id]
	view.details.visible = expanded
	view.details_button.text = "收起" if expanded else "详情"


func _expansion_key(tool_id: String) -> String:
	return actor_staff_id + ":" + tool_id


func _focus_search() -> void:
	if is_visible_in_tree():
		search.grab_focus()


func _button(caption: String, node_name: String) -> Button:
	var result := KitchenTheme.button(caption)
	result.name = node_name
	result.custom_minimum_size.y = 30
	result.add_theme_font_size_override("font_size", 13)
	return result


func _label(value: String, font_size: int, color: Color) -> Label:
	var result := KitchenTheme.label(value, font_size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result
