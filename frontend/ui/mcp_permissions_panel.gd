extends VBoxContainer
## Portal-only controls; the acting manager and runtime enforce every grant.

signal canceled
signal permissions_requested(tool_id: String, authorized: bool)

const KitchenTheme = preload("res://frontend/ui/kitchen_theme.gd")
const BookTheme = preload("res://frontend/ui/book_theme.gd")

var title: Label
var content: VBoxContainer
var back_button: Button
var status_label: Label
var scroll: ScrollContainer
var item_views: Dictionary = {}
var entries: Array = []
var target_staff_id := ""
var target_name := ""


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var header := HBoxContainer.new()
	title = KitchenTheme.label("", 18, BookTheme.INK)
	title.name = "PermissionsTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title)
	back_button = KitchenTheme.button("返回")
	back_button.name = "PermissionsBack"
	back_button.custom_minimum_size.y = 32
	back_button.add_theme_font_size_override("font_size", 13)
	back_button.pressed.connect(func(): canceled.emit())
	header.add_child(back_button)
	add_child(header)
	status_label = KitchenTheme.label("", 12, KitchenTheme.ACCENT)
	status_label.name = "PermissionsError"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.hide()
	add_child(status_label)
	scroll = ScrollContainer.new()
	scroll.name = "PermissionsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content = VBoxContainer.new()
	content.name = "PermissionsContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	scroll.add_child(content)
	add_child(scroll)
	_update_title()
	_rebuild()


func set_context(staff_id: String, display_name: String) -> void:
	target_staff_id = staff_id
	target_name = display_name
	if is_node_ready():
		_update_title()
		show_error("")
		scroll.scroll_vertical = 0


func set_entries(value: Array) -> void:
	entries = value.duplicate(true)
	if not is_node_ready():
		return
	# Keep the focused checkbox in place when a grant emits a synchronous update.
	if _same_items():
		for entry: Dictionary in entries:
			var view: Dictionary = item_views[str(entry.id)]
			view.authorized.set_pressed_no_signal(bool(entry.get("authorized", false)))
		return
	_rebuild()


func show_error(message: String) -> void:
	if not is_instance_valid(status_label):
		return
	status_label.text = message
	status_label.visible = not message.is_empty()


func focus_first() -> void:
	if not is_visible_in_tree():
		return
	if item_views.is_empty():
		back_button.grab_focus()
	else:
		item_views.values()[0].authorized.grab_focus()


func _update_title() -> void:
	title.text = "%s · MCP 权限" % target_name
	title.tooltip_text = title.text


func _same_items() -> bool:
	if entries.size() != item_views.size():
		return false
	for value: Variant in entries:
		if not value is Dictionary:
			return false
		var tool_id := str(value.get("id", ""))
		if not item_views.has(tool_id) or item_views[tool_id].name.text != str(value.get("name", tool_id)):
			return false
	return true


func _rebuild() -> void:
	item_views.clear()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for value: Variant in entries:
		if not value is Dictionary or str(value.get("id", "")).is_empty():
			continue
		_build_item(value)
	if item_views.is_empty():
		content.add_child(KitchenTheme.label("暂无 MCP", 14, BookTheme.MUTED))


func _build_item(entry: Dictionary) -> void:
	var tool_id := str(entry.id)
	var item := VBoxContainer.new()
	item.name = "Permission_" + tool_id
	item.add_theme_constant_override("separation", 0)
	content.add_child(item)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var name_label := KitchenTheme.label(str(entry.get("name", tool_id)), 15, BookTheme.INK)
	name_label.name = "PermissionName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.tooltip_text = str(entry.get("description", ""))
	row.add_child(name_label)
	var authorization := _checkbox("授权", "ToolAuthorized", bool(entry.get("authorized", false)))
	row.add_child(authorization)
	item.add_child(row)
	var separator := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = BookTheme.RULE
	line.thickness = 1
	separator.add_theme_stylebox_override("separator", line)
	item.add_child(separator)
	item_views[tool_id] = {"item": item, "name": name_label, "authorized": authorization}
	authorization.toggled.connect(_permission_changed.bind(tool_id))


func _permission_changed(authorized: bool, tool_id: String) -> void:
	if not is_visible_in_tree() or target_staff_id.is_empty():
		return
	show_error("")
	permissions_requested.emit(tool_id, authorized)


func _checkbox(caption: String, node_name: String, checked: bool) -> CheckBox:
	var result := CheckBox.new()
	result.name = node_name
	result.text = caption
	result.custom_minimum_size.y = 36
	result.add_theme_font_size_override("font_size", 13)
	result.add_theme_color_override("font_color", BookTheme.INK)
	result.add_theme_color_override("font_hover_color", BookTheme.INK)
	result.add_theme_color_override("font_pressed_color", BookTheme.INK)
	result.button_pressed = checked
	return result
