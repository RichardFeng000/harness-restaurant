extends Control

signal closed
signal page_changed(page_name: String)
signal staff_changed(staff_id: String, is_admin: bool)

const KitchenTheme = preload("res://frontend/ui/kitchen_theme.gd")
const BookTheme = preload("res://frontend/ui/book_theme.gd")
const BookGeometry = preload("res://frontend/ui/book_geometry.gd")
const BookOpenTransition = preload("res://frontend/ui/book_open_transition.gd")
const STAFF_PERMISSIONS_PATH := "res://database/staff_permissions.csv"
const PAGE_PORTAL := "portal"
const PAGE_CHAT := "chat"
const PAGE_KNOWLEDGE := "knowledge"
const PAGE_MEMORY := "memory"
const PAGE_MCP := "mcp"
const ADMIN_STAFF_ID := "manager"
const PAGE_SCENES := {
	PAGE_CHAT: preload("res://frontend/scenes/harness/chat_page.tscn"),
	PAGE_PORTAL: preload("res://frontend/scenes/harness/portal_page.tscn"),
	PAGE_KNOWLEDGE: preload("res://frontend/scenes/harness/knowledge_page.tscn"),
	PAGE_MEMORY: preload("res://frontend/scenes/harness/memory_page.tscn"),
	PAGE_MCP: preload("res://frontend/scenes/harness/mcp_page.tscn"),
}
const PAGE_LABELS := {
	PAGE_CHAT: "对话", PAGE_PORTAL: "门户",
	PAGE_KNOWLEDGE: "知识库", PAGE_MEMORY: "记忆", PAGE_MCP: "MCP",
}
const BOOK_TEXTURE = preload("res://frontend/assets/runtime/v4/ui/harness/harness_book_open_v2_rect_trimmed.png")
const STAFF_TEXTURES := {
	"manager": preload("res://frontend/assets/runtime/v4/sprites/staff/manager/manager_south_v2.png"),
	"cashier": preload("res://frontend/assets/runtime/v4/sprites/staff/cashier/cashier_south_v3.png"),
	"head_chef": preload("res://frontend/assets/runtime/v4/sprites/staff/head_chef/standing/head_chef_south_v1.png"),
	"sous_chef": preload("res://frontend/assets/runtime/v4/sprites/staff/sous_chef/standing/sous_chef_south_v1.png"),
	"expeditor": preload("res://frontend/assets/runtime/v4/sprites/staff/expeditor/standing/expeditor_south_v1.png"),
	"waiter": preload("res://frontend/assets/runtime/v4/sprites/staff/waiter/standing/waiter_south_v1.png"),
}
const HAMSTER_SHEET = preload("res://frontend/assets/runtime/v4/sprites/staff/hamster/walk/hamster_run_16frame_sheet_v2_aligned.png")

var open_book: TextureRect
var close_button: Button
var portal_button: Button
var chat_button: Button
var knowledge_button: Button
var memory_button: Button
var mcp_button: Button
var portal_page: Control
var chat_page: Control
var knowledge_page: Control
var memory_page: Control
var mcp_page: Control
var current_page := PAGE_CHAT
var current_staff_id := ADMIN_STAFF_ID
var staff_permissions: Dictionary = {}
var page_buttons: Dictionary = {}
var pages: Dictionary = {}
var staff_buttons: Dictionary = {}
var page_host: Control
var left_page: VBoxContainer
var right_page: VBoxContainer
var staff_grid: GridContainer
var book_title: Label
var backdrop: ColorRect
var content_ink: Control
var previous_focus: WeakRef
var skill_runtime: RefCounted
var surface: Control
var opening: Control
var is_closing := false


func _ready() -> void:
	theme = BookTheme.create()
	_load_staff_permissions()
	_build_ui()
	_select_staff(ADMIN_STAFF_ID)
	show_page(PAGE_CHAT)
	resized.connect(_resize_layout)
	_resize_layout()
	visibility_changed.connect(_visibility_changed)


func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.055, 0.035, 0.02, 0.65)
	add_child(backdrop)
	surface = Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(surface)
	open_book = TextureRect.new()
	open_book.name = "OpenBookArtwork"
	open_book.texture = BOOK_TEXTURE
	open_book.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	open_book.stretch_mode = TextureRect.STRETCH_SCALE
	open_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(open_book)
	content_ink = Control.new()
	content_ink.name = "BookInk"
	content_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(content_ink)
	left_page = VBoxContainer.new()
	left_page.name = "LeftPage"
	left_page.add_theme_constant_override("separation", 10)
	content_ink.add_child(left_page)
	_build_header(left_page)
	_build_navigation(left_page)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_page.add_child(spacer)
	_build_staff_bar(left_page)
	right_page = VBoxContainer.new()
	right_page.name = "RightPage"
	right_page.add_theme_constant_override("separation", 8)
	content_ink.add_child(right_page)
	var right_header := HBoxContainer.new()
	var header_space := Control.new()
	header_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_header.add_child(header_space)
	close_button = KitchenTheme.button("×")
	close_button.name = "CloseButton"
	close_button.tooltip_text = "合上书本（Esc）"
	close_button.custom_minimum_size = Vector2(32, 32)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.add_theme_stylebox_override("normal", KitchenTheme.style(Color.TRANSPARENT, 16, Color.TRANSPARENT, 0))
	close_button.add_theme_stylebox_override("hover", KitchenTheme.style(Color(0.55, 0.28, 0.10, 0.12), 16, Color.TRANSPARENT, 0))
	close_button.add_theme_stylebox_override("pressed", KitchenTheme.style(Color(0.55, 0.28, 0.10, 0.20), 16, Color.TRANSPARENT, 0))
	close_button.pressed.connect(_close)
	right_header.add_child(close_button)
	right_page.add_child(right_header)
	page_host = Control.new()
	page_host.name = "PageHost"
	page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_page.add_child(page_host)
	for page_id: String in PAGE_SCENES:
		var page: Control = PAGE_SCENES[page_id].instantiate()
		page_host.add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pages[page_id] = page
	chat_page = pages[PAGE_CHAT]
	portal_page = pages[PAGE_PORTAL]
	knowledge_page = pages[PAGE_KNOWLEDGE]
	memory_page = pages[PAGE_MEMORY]
	mcp_page = pages[PAGE_MCP]
	mcp_page.set_runtime(skill_runtime)
	portal_page.set_runtime(skill_runtime)
	portal_page.set_accounts(staff_permissions)
	portal_page.account_selected.connect(_select_staff)
	opening = BookOpenTransition.new()
	add_child(opening)
	opening.progress_changed.connect(_opening_progress)
	opening.finished.connect(_opening_finished)
	opening.closing_finished.connect(_finish_close)


func _build_header(layout: VBoxContainer) -> void:
	book_title = KitchenTheme.label("工作簿", 26, BookTheme.INK)
	layout.add_child(book_title)
	layout.add_child(_paper_rule())


func _build_navigation(layout: VBoxContainer) -> void:
	var navigation := VBoxContainer.new()
	navigation.name = "BookContents"
	navigation.add_theme_constant_override("separation", 3)
	for page_id: String in PAGE_LABELS:
		var button := KitchenTheme.button(PAGE_LABELS[page_id])
		button.name = page_id.capitalize() + "Button"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 38
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 19)
		button.add_theme_color_override("font_pressed_color", KitchenTheme.ACCENT)
		button.add_theme_stylebox_override("normal", BookTheme.ruled(Color.TRANSPARENT, 5))
		button.add_theme_stylebox_override("hover", BookTheme.ruled(Color(0.55, 0.28, 0.10, 0.08), 5))
		var selected := BookTheme.ruled(Color(0.60, 0.29, 0.08, 0.10), 5)
		selected.border_width_left = 3
		selected.border_color = KitchenTheme.ACCENT
		button.add_theme_stylebox_override("pressed", selected)
		button.pressed.connect(show_page.bind(page_id))
		navigation.add_child(button)
		page_buttons[page_id] = button
	layout.add_child(navigation)
	portal_button = page_buttons[PAGE_PORTAL]
	chat_button = page_buttons[PAGE_CHAT]
	knowledge_button = page_buttons[PAGE_KNOWLEDGE]
	memory_button = page_buttons[PAGE_MEMORY]
	mcp_button = page_buttons[PAGE_MCP]
	mcp_button.tooltip_text = "MCP 与员工技能"


func _build_staff_bar(layout: VBoxContainer) -> void:
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	staff_grid = GridContainer.new()
	staff_grid.columns = 4
	staff_grid.name = "StaffAvatarBar"
	staff_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	staff_grid.add_theme_constant_override("h_separation", 8)
	staff_grid.add_theme_constant_override("v_separation", 6)
	for staff_id: String in staff_permissions:
		var record: Dictionary = staff_permissions[staff_id]
		var button := KitchenTheme.button(str(record.get("display_name", staff_id)))
		button.name = staff_id
		button.custom_minimum_size = Vector2(64, 58)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_theme_constant_override("icon_max_width", 30)
		button.add_theme_constant_override("h_separation", 2)
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_stylebox_override("normal", BookTheme.ruled(Color.TRANSPARENT, 3))
		button.add_theme_stylebox_override("hover", BookTheme.ruled(Color(0.55, 0.28, 0.10, 0.09), 3))
		button.add_theme_stylebox_override("pressed", BookTheme.ruled(Color(0.60, 0.29, 0.08, 0.17), 3))
		button.add_theme_color_override("font_pressed_color", KitchenTheme.ACCENT)
		button.tooltip_text = "切换到%s" % str(record.get("display_name", staff_id))
		if staff_id == "hamster":
			var hamster := AtlasTexture.new()
			hamster.atlas = HAMSTER_SHEET
			hamster.region = Rect2(0, 0, 314, 314)
			button.icon = hamster
		elif STAFF_TEXTURES.has(staff_id):
			button.icon = STAFF_TEXTURES[staff_id]
		button.pressed.connect(_select_staff.bind(staff_id))
		staff_grid.add_child(button)
		staff_buttons[staff_id] = button
	footer.add_child(staff_grid)
	layout.add_child(footer)


func _resize_layout() -> void:
	var spread := BookGeometry.spread_rect(size)
	open_book.position = spread.position
	open_book.size = spread.size
	var left := BookGeometry.left_page_rect(size)
	var right := BookGeometry.right_page_rect(size)
	left_page.position = left.position
	left_page.size = left.size
	right_page.position = right.position
	right_page.size = right.size
	var compact := size.y < 650
	left_page.add_theme_constant_override("separation", 5 if compact else 10)
	book_title.add_theme_font_size_override("font_size", 24 if compact else 26)
	for button: Button in page_buttons.values():
		button.custom_minimum_size.y = 30 if compact else 38
		button.add_theme_font_size_override("font_size", 16 if compact else 19)
	for button: Button in staff_buttons.values():
		button.custom_minimum_size = Vector2(56 if compact else 64, 46 if compact else 58)
		button.add_theme_constant_override("icon_max_width", 22 if compact else 30)
		button.add_theme_font_size_override("font_size", 11 if compact else 13)
	# Reapply after compact controls release their previous minimum height.
	left_page.set_deferred("size", left.size)
	right_page.set_deferred("size", right.size)

func _paper_rule() -> HSeparator:
	var separator := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = BookTheme.RULE
	line.thickness = 1
	separator.add_theme_stylebox_override("separator", line)
	return separator


func open(origin: Rect2 = Rect2()) -> void:
	if visible:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and not is_ancestor_of(focused):
		previous_focus = weakref(focused)
	show()
	move_to_front()
	open_book.modulate.a = 0.0
	content_ink.modulate.a = 0.0
	if not origin.has_area():
		origin = Rect2(size - Vector2(204, 168), Vector2(184, 148))
	opening.play(origin)
	show_page(current_page)


func close(destination: Rect2 = Rect2()) -> void:
	if not visible or is_closing:
		return
	mcp_page.dismiss_active_panel()
	portal_page.close_permissions()
	is_closing = true
	close_button.disabled = true
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	if not destination.has_area():
		destination = opening.source_rect
	if not destination.has_area():
		destination = Rect2(size - Vector2(204, 168), Vector2(184, 148))
	opening.play_close(destination)

func _finish_close() -> void:
	hide()
	if previous_focus != null:
		var target = previous_focus.get_ref()
		if is_instance_valid(target) and target is Control and target.is_visible_in_tree():
			target.grab_focus()
	closed.emit()

func _opening_progress(value: float) -> void:
	backdrop.color.a = 0.65 * smoothstep(0.0, 0.30, value)
	# Once the two leaves are flat, hand over identical artwork at full opacity.
	# Only the ink fades in, so the paper never changes brightness or position.
	open_book.modulate.a = 1.0 if value >= 0.80 else 0.0
	content_ink.modulate.a = smoothstep(0.80, 1.0, value)

func _opening_finished() -> void:
	open_book.modulate.a = 1.0
	content_ink.modulate.a = 1.0
	_focus_current_page()

func _visibility_changed() -> void:
	if not visible and is_instance_valid(opening):
		mcp_page.dismiss_active_panel()
		portal_page.close_permissions()
		opening.cancel()
		is_closing = false
		close_button.disabled = false
		open_book.modulate.a = 1.0
		content_ink.modulate.a = 1.0


func reset_session() -> void:
	mcp_page.dismiss_active_panel()
	chat_page.reset_session()
	portal_page.reset_session()
	_select_staff(ADMIN_STAFF_ID)
	show_chat()


func show_portal() -> void:
	show_page(PAGE_PORTAL)


func show_chat() -> void:
	show_page(PAGE_CHAT)


func show_knowledge() -> void:
	show_page(PAGE_KNOWLEDGE)


func show_memory() -> void:
	show_page(PAGE_MEMORY)


func show_mcp() -> void:
	show_page(PAGE_MCP)


func set_skill_runtime(runtime: RefCounted) -> void:
	skill_runtime = runtime
	if is_instance_valid(mcp_page):
		mcp_page.set_runtime(runtime)
	if is_instance_valid(portal_page):
		portal_page.set_runtime(runtime)


func _select_staff(staff_id: String) -> void:
	if not staff_permissions.has(staff_id):
		return
	current_staff_id = staff_id
	var record: Dictionary = staff_permissions[staff_id]
	var display_name := str(record.get("display_name", staff_id))
	for page_id: String in page_buttons:
		page_buttons[page_id].visible = _current_staff_can("can_" + page_id)
	for candidate_id: String in staff_buttons:
		staff_buttons[candidate_id].set_pressed_no_signal(candidate_id == staff_id)
	portal_page.select_account(staff_id)
	chat_page.select_staff(staff_id, display_name)
	mcp_page.select_staff(staff_id, display_name)
	show_page(current_page)
	staff_changed.emit(staff_id, _current_staff_is_admin())


func _current_staff_is_admin() -> bool:
	var permission: Dictionary = staff_permissions.get(current_staff_id, {})
	return str(permission.get("role_code", "")) == "ADMIN"


func _current_staff_can(permission_name: String) -> bool:
	var permission: Dictionary = staff_permissions.get(current_staff_id, {})
	return bool(permission.get(permission_name, false))


func show_page(page_name: String) -> void:
	if not pages.has(page_name) or not _current_staff_can("can_" + page_name):
		page_name = ""
		for candidate: String in pages:
			if _current_staff_can("can_" + candidate):
				page_name = candidate
				break
	if page_name != current_page:
		mcp_page.dismiss_active_panel()
		portal_page.close_permissions()
	current_page = page_name
	for candidate: String in pages:
		pages[candidate].visible = candidate == page_name
		page_buttons[candidate].set_pressed_no_signal(candidate == page_name)
	page_changed.emit(page_name)
	_focus_current_page.call_deferred()

func dismiss_active_panel() -> bool:
	if is_closing:
		return false
	if current_page == PAGE_PORTAL:
		return portal_page.close_permissions()
	return current_page == PAGE_MCP and mcp_page.dismiss_active_panel()


func _focus_current_page() -> void:
	if not is_visible_in_tree():
		return
	if is_closing or (is_instance_valid(opening) and opening.is_playing):
		return
	if current_page == PAGE_CHAT:
		chat_page.focus_input()
	elif current_page == PAGE_PORTAL:
		portal_page.focus_search()
	elif page_buttons.has(current_page):
		page_buttons[current_page].grab_focus()
	else:
		close_button.grab_focus()


func _close() -> void:
	close()


func _load_staff_permissions() -> void:
	staff_permissions.clear()
	var file := FileAccess.open(STAFF_PERMISSIONS_PATH, FileAccess.READ)
	if file == null:
		push_error("无法读取员工权限表：%s" % STAFF_PERMISSIONS_PATH)
		return
	var headers := file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty() or (row.size() == 1 and row[0].strip_edges().is_empty()):
			continue
		var record: Dictionary = {}
		for index in mini(headers.size(), row.size()):
			record[headers[index].strip_edges()] = row[index].strip_edges()
		var staff_id := str(record.get("staff_id", ""))
		if staff_id.is_empty():
			continue
		for permission: String in ["can_chat", "can_portal", "can_knowledge", "can_memory", "can_mcp"]:
			record[permission] = str(record.get(permission, "false")).to_lower() == "true"
		staff_permissions[staff_id] = record
